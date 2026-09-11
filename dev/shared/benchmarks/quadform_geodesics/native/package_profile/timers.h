#ifndef QGP_TIMERS_H
#define QGP_TIMERS_H
#include <Rcpp.h>
#include <array>
#include <chrono>

namespace qgp {
enum Category { boundary, core, setup, initialization, sampling, construction,
  batch, cache, integration, shortest, records, tracing, scheduling, window,
  keys, polling, count };
const char* names[count] = {"Rcpp input/output", "Core setup/cleanup", "Solver and random-stream setup",
  "Initialization", "Candidate sampling", "Local graph/proposal construction",
  "Edge-batch bookkeeping", "Edge cache/lookup", "Numerical integration",
  "Shortest-path search", "Path length lookup", "Trace recording", "Epoch scheduling",
  "Replacement decisions", "Coordinate keys", "Limit/interrupt checks"};
struct Scope;
struct Timers {
  bool enabled = false, fine = false, testing = false;
  double test_time = 0;
  Scope* top = nullptr;
  std::array<double,count> inclusive{}, exclusive{}, calls{};
};
inline Timers& timers() { static Timers t; return t; }
inline double now() {
  if (timers().testing) return timers().test_time;
  return std::chrono::duration<double>(std::chrono::steady_clock::now().time_since_epoch()).count();
}
struct Scope {
  bool on; Category id; double start = 0, children = 0; Scope* parent = nullptr;
  explicit Scope(Category category) : on(timers().enabled && (category < keys || timers().fine)), id(category) {
    if (!on) return;
    start = now(); parent = timers().top; timers().top = this; ++timers().calls[id];
  }
  void finish() {
    if (!on) return;
    double elapsed = now()-start;
    timers().inclusive[id] += elapsed; timers().exclusive[id] += elapsed-children;
    if (parent) parent->children += elapsed;
    timers().top = parent; on = false;
  }
  ~Scope() { finish(); }
  Scope(const Scope&) = delete;
  Scope& operator=(const Scope&) = delete;
};
inline Rcpp::DataFrame metrics() {
  Rcpp::CharacterVector labels(count);
  for (int i=0; i<count; ++i) labels[i] = names[i];
  return Rcpp::DataFrame::create(Rcpp::_ ["component"] = labels,
    Rcpp::_ ["exclusive_seconds"] = timers().exclusive,
    Rcpp::_ ["inclusive_seconds"] = timers().inclusive,
    Rcpp::_ ["calls"] = timers().calls);
}
}
#endif
