// Computational core: no R-level callbacks, Python, checkpointing or file I/O.
#include "quadform_geodesics_solver.h"
#include <Rcpp.h>
#include <R_ext/Applic.h>
#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <list>
#include <map>
#include <random>
#include <unordered_map>
#include <vector>

namespace qgn {
using Clock = std::chrono::steady_clock;
const double inf = std::numeric_limits<double>::infinity();
struct Stop { std::string reason; };
double sum(const std::vector<double>& x) {
  double s = 0, c = 0;
  for (double v : x) { double t = s + v;
    c += std::abs(s) >= std::abs(v) ? (s - t) + v : (v - t) + s; s = t; }
  return s + c;
}
double norm(const Point& x) {
  double m = std::max(std::abs(x[0]), std::abs(x[1]));
  if (m == 0) return 0;
  double a = x[0] / m, b = x[1] / m;
  return m * std::sqrt(static_cast<double>(static_cast<long double>(a*a) + b*b));
}
Point minus(const Point& a, const Point& b) { return {{a[0]-b[0], a[1]-b[1]}}; }
std::string key(const Point& p) {
  static const char* hex = "0123456789abcdef";
  std::string out = "00000002";
  for (double v : p) { uint64_t bits; std::memcpy(&bits, &v, 8);
    for (int j = 7; j >= 0; --j) { unsigned b = (bits >> (8*j)) & 255;
      out += hex[b >> 4]; out += hex[b & 15]; } }
  return out;
}
std::string edgekey(Point a, Point b) {
  std::string ka = key(a), kb = key(b);
  return ka < kb ? ka + ":" + kb : kb + ":" + ka;
}
std::string pathkey(const Path& p) {
  std::string s; for (const auto& u : p) { if (!s.empty()) s += "/"; s += key(u); } return s;
}
uint64_t mix(uint64_t x) {
  x += UINT64_C(0x9e3779b97f4a7c15);
  x = (x ^ (x >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
  x = (x ^ (x >> 27)) * UINT64_C(0x94d049bb133111eb);
  return x ^ (x >> 31);
}
struct Streams {
  std::mt19937_64 candidates, order, orientation;
  explicit Streams(uint64_t seed) : candidates(mix(seed)), order(mix(seed + UINT64_C(4294967296))),
    orientation(mix(seed + UINT64_C(8589934592))) {}
  static double uniform(std::mt19937_64& g) { return (g() >> 11) * (1.0/9007199254740992.0); }
};
bool Domain::inside(const Point& p) const {
  if (!std::isfinite(p[0]) || !std::isfinite(p[1])) return false;
  return disk ? norm(minus(p, center)) <= radius :
    p[0] >= lower[0] && p[0] <= upper[0] && p[1] >= lower[1] && p[1] <= upper[1];
}
struct CacheEntry {
  Measure values[2]; bool present[2] = {false, false}; std::list<std::string>::iterator position;
};
struct Tangent { Point h; double alpha, beta; bool finite = true; };
void speeds(double* t, int n, void* ptr) {
  Tangent& z = *static_cast<Tangent*>(ptr);
  for (int i = 0; i < n; ++i) {
    double v = z.alpha + z.beta*t[i];
    double m = std::max(std::max(std::abs(z.h[0]), std::abs(z.h[1])), std::abs(v));
    if (!std::isfinite(v) || !std::isfinite(m)) { z.finite = false; t[i] = 0; continue; }
    if (m == 0) { t[i] = 0; continue; }
    double a = z.h[0]/m, b = z.h[1]/m, c = v/m;
    t[i] = m * std::sqrt(static_cast<double>(static_cast<long double>(a*a) + b*b + c*c));
    if (!std::isfinite(t[i])) { z.finite = false; t[i] = 0; }
  }
}
using Batch = std::map<std::string, Measure>;
using Edges = std::map<std::string, std::pair<Point, Point>>;
class Solver {
public:
  Config c; Domain domain; std::array<double,4> A; Streams rng; Counters counts;
  Path path, initial; std::vector<Measure> segments; std::vector<int> ids;
  std::vector<Event> events; int dropped = 0, epoch = 0, completed_epochs = 0, next_id = 1;
  double rho = 0, initial_length = std::numeric_limits<double>::quiet_NaN(), initial_error = std::numeric_limits<double>::quiet_NaN();
  bool initialized = false, reversed = false;
  std::string termination = "epoch_limit";
  Clock::time_point start;
  std::unordered_map<std::string, CacheEntry> cache; std::list<std::string> lru;
  Solver(Config config, Domain d, std::array<double,4> a, uint64_t seed) :
    c(config), domain(d), A(a), rng(seed), start(Clock::now()) {}
  double seconds() const { return std::chrono::duration<double>(Clock::now()-start).count(); }
  void poll() {
    if (seconds() >= c.max_seconds) throw Stop{"time_limit"};
    Rcpp::checkUserInterrupt();
  }
  Measure integrate(Point a, Point b, bool tighter) {
    poll(); if (counts.calls >= c.max_edges) throw Stop{"edge_limit"};
    ++counts.calls; Measure out;
    if (a == b) return out;
    if (key(b) < key(a)) std::swap(a,b);
    Tangent z; z.h = minus(b,a);
    Point Ah = {{A[0]*z.h[0]+A[1]*z.h[1], A[2]*z.h[0]+A[3]*z.h[1]}};
    z.alpha = 2 * static_cast<double>(static_cast<long double>(a[0]*Ah[0]) + a[1]*Ah[1]);
    z.beta = 2 * static_cast<double>(static_cast<long double>(z.h[0]*Ah[0]) + z.h[1]*Ah[1]);
    if (!std::isfinite(z.alpha) || !std::isfinite(z.beta)) { out.ok = false; return out; }
    double lo = 0, hi = 1, factor = tighter ? .01 : 1;
    double absolute = 1e-12*c.scale*factor, relative = 1e-10*factor;
    int evaluations = 0, status = 0, limit = 1000, lenw = 4000, last = 0;
    int iwork[1000]; double work[4000];
    // QUADPACK through R's public compiled API, with a C++ integrand, not an R closure.
    Rdqags(speeds, &z, &lo, &hi, &absolute, &relative, &out.length, &out.error,
      &evaluations, &status, &limit, &lenw, &last, iwork, work);
    counts.evaluations += evaluations;
    out.ok = status == 0 && z.finite && std::isfinite(out.length) && out.length > 0 &&
      std::isfinite(out.error) && out.error >= 0;
    poll(); return out;
  }
  Measure edge(Point a, Point b, bool tighter) {
    poll(); ++counts.requests; std::string k = edgekey(a,b);
    auto it = cache.find(k); int level = tighter ? 1 : 0;
    if (it != cache.end()) {
      lru.splice(lru.begin(), lru, it->second.position);
      CacheEntry& e = it->second;
      if (!tighter && e.present[1] && e.values[1].ok) { ++counts.hits; return e.values[1]; }
      if (e.present[level]) { ++counts.hits; return e.values[level]; }
    }
    Measure out = integrate(a,b,tighter);
    if (c.cache_edges == 0) return out;
    if (it == cache.end()) {
      if (cache.size() >= static_cast<size_t>(c.cache_edges)) {
        cache.erase(lru.back()); lru.pop_back(); ++counts.evictions;
      }
      lru.push_front(k); CacheEntry entry; entry.position = lru.begin();
      it = cache.emplace(k,entry).first;
    }
    it->second.values[level] = out; it->second.present[level] = true; return out;
  }
  static void add(Edges& edges, Point a, Point b) {
    if (key(b) < key(a)) std::swap(a,b); edges.emplace(edgekey(a,b),std::make_pair(a,b));
  }
  static void addpath(Edges& edges, const Path& p) {
    for (size_t i = 1; i < p.size(); ++i) add(edges,p[i-1],p[i]);
  }
  Batch batch(const Edges& edges, bool tighter, bool& ok) {
    Batch out; ok = true;
    for (const auto& e : edges) { Measure m = edge(e.second.first,e.second.second,tighter);
      ok = ok && m.ok; out.emplace(e.first,m); }
    return out;
  }
  static std::vector<Measure> records(const Path& p, const Batch& b) {
    std::vector<Measure> out;
    for (size_t i = 1; i < p.size(); ++i) out.push_back(b.at(edgekey(p[i-1],p[i])));
    return out;
  }
  static Measure measure(const std::vector<Measure>& r) {
    std::vector<double> lengths, errors; Measure out;
    for (const auto& m : r) { lengths.push_back(m.length); errors.push_back(m.error); out.ok &= m.ok; }
    out.length = sum(lengths); out.error = sum(errors);
    out.ok = out.ok && std::isfinite(out.length) && std::isfinite(out.error); return out;
  }
  void record(const std::string& kind, double decrease = std::numeric_limits<double>::quiet_NaN(), double required = std::numeric_limits<double>::quiet_NaN(),
              const std::vector<int>& order = {}) {
    if (!c.trace) return;
    if (events.size() >= static_cast<size_t>(c.trace_limit)) { ++dropped; return; }
    Measure m = measure(segments);
    events.push_back(Event{kind,epoch,path,order,ids,m.length,m.error,decrease,required});
  }
  void initialize(Point from, Point to) {
    reversed = c.random_orientation && Streams::uniform(rng.orientation) < .5;
    if (reversed) std::swap(from,to);
    Measure total = edge(from,to,true);
    if (!total.ok) throw Stop{"initialization_numerical_failure"};
    path = {from,to}; segments = {total}; ids = {1,2}; next_id = 3;
    record("direct_path");
    if (from == to) { initialized = true; initial = path;
      initial_length = total.length; initial_error = total.error; return; }
    bool reverse = key(to) < key(from); Point a = reverse ? to : from, b = reverse ? from : to;
    Path proposed = {a};
    double tolerance = 1e-10*c.scale + 1e-8*total.length/c.initial_edges;
    double roundoff = 64*std::numeric_limits<double>::epsilon()*std::max(c.scale,total.length);
    for (int j = 1; j < c.initial_edges; ++j) {
      double fraction = static_cast<double>(j)/c.initial_edges, lo = 0, hi = 1;
      bool resolved = false;
      for (int k = 0; k < 64; ++k) {
        double t = lo+(hi-lo)/2;
        if (t == lo || t == hi) break;
        Point p = {{a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])}};
        if (!domain.inside(p)) throw Stop{"initialization_unrepresentable"};
        Measure m = edge(a,p,true);
        if (!m.ok) throw Stop{"initialization_numerical_failure"};
        if (std::abs(m.length-fraction*total.length)+m.error+fraction*total.error+roundoff <= tolerance) {
          proposed.push_back(p); resolved = true; break;
        }
        if (m.length < fraction*total.length) lo = t; else hi = t;
      }
      if (!resolved) throw Stop{"initialization_unresolved"};
    }
    proposed.push_back(b); if (reverse) std::reverse(proposed.begin(),proposed.end());
    Edges edges; addpath(edges,proposed); bool ok;
    Batch values = batch(edges,true,ok);
    if (!ok) throw Stop{"initialization_numerical_failure"};
    auto r = records(proposed,values); Measure m = measure(r);
    for (int i = 0; i < c.initial_edges; ++i) {
      if (proposed[i] == proposed[i+1] ||
          std::abs(r[i].length-total.length/c.initial_edges)+r[i].error+total.error/c.initial_edges >
            2*tolerance+roundoff) throw Stop{"initialization_spacing_failure"};
    }
    if (!m.ok || std::abs(m.length-total.length) > m.error+total.error+(c.initial_edges+1)*roundoff)
      throw Stop{"initialization_additivity_failure"};
    path = proposed; segments = r; ids.clear(); next_id = 1;
    for (size_t i = 0; i < path.size(); ++i) ids.push_back(next_id++);
    for (size_t i = 1; i < path.size(); ++i) rho = std::max(rho,norm(minus(path[i],path[i-1])));
    initialized = true; initial = path; initial_length = m.length; initial_error = m.error;
    record("initializer");
  }
  bool sample(const Point& anchor, double radius, Path& candidates) {
    if (!std::isfinite(radius) || radius <= 0) { ++counts.shortfalls; return false; }
    std::map<std::string,Point> unique;
    for (int j = 0; j < c.candidates; ++j) {
      bool accepted = false;
      for (int attempt = 0; attempt < c.rejection_cap; ++attempt) {
        poll(); ++counts.attempts;
        double angle = 2*std::acos(-1.0)*Streams::uniform(rng.candidates);
        double r = radius*std::sqrt(Streams::uniform(rng.candidates)); counts.candidate_draws += 2;
        Point p = {{anchor[0]+r*std::cos(angle),anchor[1]+r*std::sin(angle)}};
        if (domain.inside(p)) { unique.emplace(key(p),p); accepted = true; break; }
      }
      if (!accepted) { ++counts.shortfalls; return false; }
    }
    for (const auto& v : unique) candidates.push_back(v.second); return true;
  }
  Path shortest(const Path& vertices, const Batch& values, const Point& from, const Point& to) {
    size_t n = vertices.size(), start_index = 0, target = 0;
    std::vector<std::string> keys; for (const auto& p : vertices) keys.push_back(key(p));
    for (size_t i = 0; i < n; ++i) {
      if (keys[i] == key(from)) start_index = i; if (keys[i] == key(to)) target = i;
    }
    std::vector<double> dist(n,inf); std::vector<bool> done(n,false);
    std::vector<std::vector<double>> weights(n); std::vector<Path> paths(n);
    std::vector<std::string> pathkeys(n);
    dist[start_index] = 0; paths[start_index] = {from}; pathkeys[start_index] = key(from);
    for (size_t step = 0; step < n; ++step) {
      poll(); size_t u = n;
      for (size_t v = 0; v < n; ++v) if (!done[v] && std::isfinite(dist[v]) &&
          (u == n || dist[v] < dist[u] || (dist[v] == dist[u] && pathkeys[v] < pathkeys[u]))) u = v;
      if (u == n) break; if (u == target) return paths[u]; done[u] = true;
      for (size_t v = 0; v < n; ++v) if (!done[v] && vertices[u] != vertices[v]) {
        double w = values.at(edgekey(vertices[u],vertices[v])).length; if (w == 0) continue;
        auto proposed_weights = weights[u]; proposed_weights.push_back(w); double d = sum(proposed_weights);
        std::string pk = pathkeys[u]+"/"+keys[v];
        if (d < dist[v] || (d == dist[v] && pk < pathkeys[v])) {
          dist[v] = d; weights[v] = proposed_weights; paths[v] = paths[u];
          paths[v].push_back(vertices[v]); pathkeys[v] = pk;
        }
      }
    }
    return {};
  }
  void window(int i) {
    ++counts.visits; int lo = i-1, hi = i+1;
    if (c.neighborhood == "fixed_span") {
      lo = hi = i; double left = 0, right = 0;
      while (lo > 0 && left < rho) { left += norm(minus(path[lo],path[lo-1])); --lo; }
      while (hi+1 < static_cast<int>(path.size()) && right < rho) {
        right += norm(minus(path[hi+1],path[hi])); ++hi; }
    }
    double radius = c.neighborhood == "neighbors" ?
      std::max(norm(minus(path[i],path[lo])),norm(minus(path[i],path[hi]))) : rho;
    Path old(path.begin()+lo,path.begin()+hi+1), candidates;
    if (!sample(path[i],radius,candidates)) return;
    Edges edges; addpath(edges,old); std::vector<Path> alternatives;
    Path vertices;
    if (c.graph) {
      std::map<std::string,Point> unique;
      for (auto p : old) unique.emplace(key(p),p);
      for (auto p : candidates) unique.emplace(key(p),p);
      for (const auto& p : unique) vertices.push_back(p.second);
      for (size_t j = 0; j < vertices.size(); ++j) {
        poll(); for (size_t k = j+1; k < vertices.size(); ++k)
          if (vertices[j] != vertices[k]) add(edges,vertices[j],vertices[k]);
      }
    } else {
      alternatives.push_back({old.front(),old.back()});
      for (auto p : candidates) if (p != old.front() && p != old.back())
        alternatives.push_back({old.front(),p,old.back()});
      for (const auto& p : alternatives) addpath(edges,p);
    }
    bool tighter = false, ok; Batch values = batch(edges,false,ok);
    if (!ok) { tighter = true; values = batch(edges,true,ok); }
    if (!ok) { ++counts.failures; return; }
    Path best; Measure previous, chosen; double delta = 0, required = 0;
    for (;;) {
      previous = measure(records(old,values)); best = old; chosen = previous;
      if (c.graph) {
        Path p = shortest(vertices,values,old.front(),old.back());
        if (!p.empty()) { Measure m = measure(records(p,values));
          if (m.length < chosen.length) { best = p; chosen = m; } }
      } else {
        bool incumbent = true;
        for (const auto& p : alternatives) { Measure m = measure(records(p,values));
          if (m.length < chosen.length || (!incumbent && m.length == chosen.length && pathkey(p) < pathkey(best))) {
            best = p; chosen = m; incumbent = false; }
        }
      }
      double margin = 1e-12*c.scale + 1e-10*previous.length;
      delta = previous.length-chosen.length; required = margin+previous.error+chosen.error;
      if (!(previous.ok && chosen.ok)) { ++counts.failures; return; }
      if (delta > margin && delta <= required && !tighter) {
        tighter = true; values = batch(edges,true,ok);
        if (!ok) { ++counts.failures; return; } continue;
      }
      break;
    }
    if (!(delta > required)) return;
    if (path.size() - old.size() + best.size() > static_cast<size_t>(c.max_vertices)) {
      ++counts.vertex_rejections; return;
    }
    Path proposed(path.begin(),path.begin()+lo); proposed.insert(proposed.end(),best.begin(),best.end());
    proposed.insert(proposed.end(),path.begin()+hi+1,path.end());
    auto middle = records(best,values);
    std::vector<Measure> new_segments(segments.begin(),segments.begin()+lo);
    new_segments.insert(new_segments.end(),middle.begin(),middle.end());
    new_segments.insert(new_segments.end(),segments.begin()+hi,segments.end());
    if (!measure(new_segments).ok) { ++counts.failures; return; }
    std::vector<int> new_ids(ids.begin(),ids.begin()+lo); int new_next_id = next_id;
    for (const auto& p : best) {
      int id = 0; for (int j = lo; j <= hi; ++j) if (key(path[j]) == key(p)) { id = ids[j]; break; }
      new_ids.push_back(id == 0 ? new_next_id++ : id);
    }
    new_ids.insert(new_ids.end(),ids.begin()+hi+1,ids.end());
    poll(); path.swap(proposed); segments.swap(new_segments); ids.swap(new_ids); next_id = new_next_id;
    ++counts.accepted; record("replacement",delta,required);
  }
  void solve(Point from, Point to) {
    try {
      initialize(from,to); if (from == to) { termination = "identity"; return; }
      int plateau = 0;
      for (epoch = 1; epoch <= c.max_epochs; ++epoch) {
        poll(); std::vector<int> order(ids.begin()+1,ids.end()-1);
        for (size_t k = order.size(); k > 1; --k) {
          uint64_t limit = (UINT64_C(4294967296)/k)*k; bool accepted = false;
          for (int attempt = 0; attempt < c.rejection_cap; ++attempt) {
            poll(); ++counts.order_draws;
            uint64_t x = static_cast<uint64_t>(Streams::uniform(rng.order)*4294967296.0);
            if (x < limit) { std::swap(order[k-1],order[x%k]); accepted = true; break; }
          }
          if (!accepted) throw Stop{"order_sampling_failure"};
        }
        record("epoch_order",std::numeric_limits<double>::quiet_NaN(),std::numeric_limits<double>::quiet_NaN(),order); double start_length = measure(segments).length;
        for (int id : order) {
          poll(); auto it = std::find(ids.begin(),ids.end(),id);
          if (it != ids.end() && it != ids.begin() && it+1 != ids.end()) window(it-ids.begin());
        }
        double decrease = (start_length-measure(segments).length)/std::max(start_length,1e-12*c.scale);
        ++completed_epochs; record("epoch_end"); plateau = decrease < 1e-5 ? plateau+1 : 0;
        if (plateau >= c.plateau_epochs) { termination = "local_stagnation"; break; }
      }
    } catch (const Stop& s) { termination = s.reason; }
  }
};
Result solve(const Config& config, const Domain& domain, const std::array<double,4>& A,
             std::uint64_t seed, const Point& from, const Point& to) {
  Solver s(config,domain,A,seed);
  s.solve(from,to);
  Result result;
  result.measure = Solver::measure(s.segments);
  result.counts = s.counts;
  result.initialized = s.initialized; result.reversed = s.reversed;
  result.dropped = s.dropped; result.completed_epochs = s.completed_epochs;
  result.initial_length = s.initial_length; result.initial_error = s.initial_error;
  result.rho = s.rho; result.elapsed_seconds = s.seconds();
  result.cache_entries = s.cache.size(); result.termination = s.termination;
  result.path = std::move(s.path); result.initial = std::move(s.initial);
  result.events = std::move(s.events);
  return result;
}

std::array<std::vector<double>,2> reference_uniforms(std::uint64_t seed, int n) {
  Streams streams(seed);
  std::array<std::vector<double>,2> out;
  out[0].resize(n); out[1].resize(n);
  for (int i = 0; i < n; ++i) {
    out[0][i] = Streams::uniform(streams.candidates);
    out[1][i] = Streams::uniform(streams.order);
  }
  return out;
}
} // namespace qgn
