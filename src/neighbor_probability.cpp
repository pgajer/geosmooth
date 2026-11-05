#include <Rcpp.h>
#include <algorithm>
#include <cmath>
#include <vector>
using namespace Rcpp;

namespace {
struct Neighbor { double distance; int row; };
}

// One row of workspace per query; no all-pairs coordinate distance matrix.
// [[Rcpp::export]]
List rcpp_neighbor_probability(const NumericMatrix& X,
                               const NumericMatrix& query,
                               const NumericMatrix& distance,
                               const NumericVector& y,
                               const IntegerVector& train,
                               const IntegerVector& group,
                               const IntegerVector& query_group,
                               const IntegerVector& priority,
                               const IntegerVector& sizes,
                               int method, int metric, bool precomputed,
                               bool diagnostics) {
    const int n = y.size(), nq = query_group.size(), nk = sizes.size();
    if (group.size() != n || priority.size() != n ||
        method < 0 || method > 2 || metric < 0 || metric > 1 || nk < 1)
        stop("Invalid native neighbor arguments.");
    if (precomputed) {
        if (distance.nrow() != nq || distance.ncol() != n)
            stop("Invalid query-by-training distance dimensions.");
    } else if (X.nrow() != n || query.nrow() != nq ||
               X.ncol() != query.ncol() || X.ncol() < 1)
        stop("Invalid coordinate dimensions.");
    for (int j = 0; j < nk; ++j)
        if (sizes[j] < (method == 2 ? 2 : 1) ||
            (j > 0 && sizes[j] <= sizes[j-1]))
            stop("Native sizes must be increasing positive integers.");
    int ng = 0;
    for (int j = 0; j < n; ++j) {
        if (group[j] < 1 || group[j] > n || priority[j] < 0 || priority[j] >= n)
            stop("Invalid native group or priority.");
        ng = std::max(ng, group[j]);
    }
    for (int j : train)
        if (j < 0 || j >= n || !R_finite(y[j]) || (y[j] != 0 && y[j] != 1))
            stop("Native training rows must have binary observed labels.");
    for (int g : query_group)
        if (g < 0 || g > ng) stop("Invalid native query group.");

    NumericMatrix probability(nq, nk);
    std::fill(probability.begin(), probability.end(), NA_REAL);
    IntegerMatrix neighbors(diagnostics ? nq : 0, diagnostics ? nk : 0);
    IntegerMatrix cases(diagnostics ? nq : 0, diagnostics ? nk : 0);
    NumericMatrix radius(diagnostics ? nq : 0, diagnostics ? nk : 0);
    IntegerMatrix ties(diagnostics ? nq : 0, diagnostics ? nk : 0);
    LogicalMatrix split(diagnostics ? nq : 0, diagnostics ? nk : 0);
    if (diagnostics) {
        std::fill(neighbors.begin(), neighbors.end(), NA_INTEGER);
        std::fill(cases.begin(), cases.end(), NA_INTEGER);
        std::fill(radius.begin(), radius.end(), NA_REAL);
        std::fill(ties.begin(), ties.end(), NA_INTEGER);
        std::fill(split.begin(), split.end(), NA_LOGICAL);
    }
    IntegerVector available(nq), positive(nq);
    std::vector<Neighbor> ordered;
    ordered.reserve(train.size());
    std::vector<int> seen(ng + 1);
    for (int q = 0; q < nq; ++q) {
        checkUserInterrupt();
        ordered.clear();
        for (int j : train) {
            if (query_group[q] > 0 && group[j] == query_group[q]) continue;
            double d = 0;
            if (precomputed) {
                d = distance(q, j);
                if (ISNAN(d) || d < 0) stop("Invalid native distance.");
                if (!R_finite(d)) continue; // Unreachable vertex.
            } else {
                for (int c = 0; c < X.ncol(); ++c) {
                    const double delta = query(q,c) - X(j,c);
                    if (metric == 0) d += delta * delta;
                    else d = std::max(d, std::abs(delta));
                }
                if (metric == 0) d = std::sqrt(d);
                if (!R_finite(d)) stop("Coordinate distance overflow.");
            }
            ordered.push_back({d,j});
        }
        std::sort(ordered.begin(), ordered.end(), [&](const Neighbor& a, const Neighbor& b) {
            if (a.distance != b.distance) return a.distance < b.distance;
            return priority[a.row] < priority[b.row];
        });
        // The closest answering visit represents each participant. Its outcome
        // never influences which visit is selected.
        std::fill(seen.begin(), seen.end(), 0);
        size_t keep = 0;
        for (size_t j = 0; j < ordered.size(); ++j) {
            const int g = group[ordered[j].row];
            if (!seen[g]) { seen[g] = 1; ordered[keep++] = ordered[j]; }
        }
        ordered.resize(keep);
        available[q] = ordered.size();
        std::vector<int> cumulative(ordered.size()), stops;
        int count = 0;
        for (size_t j = 0; j < ordered.size(); ++j) {
            if (y[ordered[j].row] == 1) { ++count; stops.push_back(j+1); }
            cumulative[j] = count;
        }
        positive[q] = count;
        for (int z = 0; z < nk; ++z) {
            const int k = sizes[z];
            if ((method == 0 && k > available[q]) || (method != 0 && k > count)) continue;
            const int t = method == 0 ? k : stops[k-1];
            probability(q,z) = method == 2 ? double(k-1)/(t-1) :
                double(cumulative[t-1])/t;
            if (!diagnostics) continue;
            neighbors(q,z) = t;
            cases(q,z) = cumulative[t-1];
            const double rad = ordered[t-1].distance;
            radius(q,z) = rad;
            int shell = 0; bool outside = false;
            for (size_t j = 0; j < ordered.size(); ++j)
                if (std::abs(ordered[j].distance - rad) <= 1e-12) {
                    ++shell; if (int(j) >= t) outside = true;
                }
            ties(q,z) = shell;
            split(q,z) = outside;
        }
    }
    return List::create(_["probability"] = probability,
                        _["neighbors"] = neighbors, _["cases"] = cases,
                        _["radius"] = radius, _["boundary.ties"] = ties,
                        _["split.tie"] = split, _["available.people"] = available,
                        _["available.cases"] = positive);
}
