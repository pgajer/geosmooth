#include <Rcpp.h>

#include <algorithm>
#include <cmath>
#include <limits>
#include <unordered_set>
#include <vector>

using Rcpp::IntegerVector;
using Rcpp::List;
using Rcpp::Named;
using Rcpp::NumericVector;

namespace {

std::vector<std::vector<int>> parse_adj_list(const List& adj_list) {
    const int n = adj_list.size();
    std::vector<std::vector<int>> adj(static_cast<size_t>(n));

    for (int i = 0; i < n; ++i) {
        IntegerVector neighbors(adj_list[i]);
        adj[static_cast<size_t>(i)].reserve(static_cast<size_t>(neighbors.size()));
        for (int k = 0; k < neighbors.size(); ++k) {
            const int v = neighbors[k];
            if (v == NA_INTEGER || v < 0 || v >= n) {
                Rcpp::stop("adj.list contains an out-of-range 0-based index.");
            }
            adj[static_cast<size_t>(i)].push_back(v);
        }
    }

    return adj;
}

std::vector<std::vector<double>> parse_weight_list(const List& weight_list, int n) {
    if (weight_list.size() != n) {
        Rcpp::stop("weight.list must have the same length as adj.list.");
    }

    std::vector<std::vector<double>> weights(static_cast<size_t>(n));
    for (int i = 0; i < n; ++i) {
        NumericVector w(weight_list[i]);
        weights[static_cast<size_t>(i)].reserve(static_cast<size_t>(w.size()));
        for (int k = 0; k < w.size(); ++k) {
            const double wk = w[k];
            if (!std::isfinite(wk) || wk <= 0.0) {
                Rcpp::stop("weight.list entries must be finite positive values.");
            }
            weights[static_cast<size_t>(i)].push_back(wk);
        }
    }

    return weights;
}

std::unordered_set<int> parse_region_vertices(const IntegerVector& region_vertices, int n) {
    std::unordered_set<int> region;
    region.reserve(static_cast<size_t>(region_vertices.size()));

    for (int i = 0; i < region_vertices.size(); ++i) {
        const int v_r = region_vertices[i];
        if (v_r == NA_INTEGER || v_r < 1 || v_r > n) {
            Rcpp::stop("region.vertices contains an out-of-range 1-based index.");
        }
        region.insert(v_r - 1);
    }

    return region;
}

} // namespace

//' Native graph harmonic smoothing backend
//'
//' Internal C++ backend for `perform.harmonic.smoothing()`.
//'
//' @keywords internal
// [[Rcpp::export]]
List rcpp_perform_harmonic_smoothing(
        const List& adj_list,
        const List& weight_list,
        const NumericVector& values,
        const IntegerVector& region_vertices,
        const int max_iterations,
        const double tolerance) {
    const int n = adj_list.size();
    if (values.size() != n) {
        Rcpp::stop("values must have the same length as adj.list.");
    }
    if (max_iterations <= 0) {
        Rcpp::stop("max.iterations must be a positive integer.");
    }
    if (!std::isfinite(tolerance) || tolerance <= 0.0) {
        Rcpp::stop("tolerance must be a finite positive scalar.");
    }

    std::vector<std::vector<int>> adj = parse_adj_list(adj_list);
    std::vector<std::vector<double>> weights = parse_weight_list(weight_list, n);
    for (int i = 0; i < n; ++i) {
        if (adj[static_cast<size_t>(i)].size() != weights[static_cast<size_t>(i)].size()) {
            Rcpp::stop("adj.list and weight.list entries must have matching lengths.");
        }
    }

    std::vector<double> f(values.begin(), values.end());
    std::unordered_set<int> region = parse_region_vertices(region_vertices, n);

    std::unordered_set<int> boundary;
    boundary.reserve(region.size());
    for (const int v : region) {
        const std::vector<int>& nbrs = adj[static_cast<size_t>(v)];
        for (const int u : nbrs) {
            if (region.count(u) == 0) {
                boundary.insert(v);
                break;
            }
        }
    }

    std::unordered_set<int> interior;
    interior.reserve(region.size());
    for (const int v : region) {
        if (boundary.count(v) == 0) {
            interior.insert(v);
        }
    }

    std::vector<double> max_change;
    std::vector<double> max_residual;
    max_change.reserve(static_cast<size_t>(max_iterations));
    max_residual.reserve(static_cast<size_t>(max_iterations));

    bool converged = false;
    int num_iterations = 0;

    if (!boundary.empty() && !interior.empty()) {
        const double eps = 1e-10;
        std::vector<double> next_f = f;

        auto weighted_average = [&](int v, const std::vector<double>& current, double& wsum) {
            double sum = 0.0;
            wsum = 0.0;
            const std::vector<int>& nbrs = adj[static_cast<size_t>(v)];
            const std::vector<double>& ws = weights[static_cast<size_t>(v)];
            for (size_t k = 0; k < nbrs.size(); ++k) {
                const int u = nbrs[k];
                if (region.count(u) == 0) {
                    continue;
                }
                const double conductance = 1.0 / (ws[k] + eps);
                sum += conductance * current[static_cast<size_t>(u)];
                wsum += conductance;
            }
            return wsum > 0.0 ? sum / wsum : current[static_cast<size_t>(v)];
        };

        for (int iter = 0; iter < max_iterations; ++iter) {
            double iter_change = 0.0;
            for (const int v : interior) {
                double wsum = 0.0;
                const double proposed = weighted_average(v, f, wsum);
                const double change = std::abs(proposed - f[static_cast<size_t>(v)]);
                iter_change = std::max(iter_change, change);
                next_f[static_cast<size_t>(v)] = proposed;
            }

            for (const int v : interior) {
                f[static_cast<size_t>(v)] = next_f[static_cast<size_t>(v)];
            }

            double iter_residual = 0.0;
            for (const int v : interior) {
                double wsum = 0.0;
                const double avg = weighted_average(v, f, wsum);
                if (wsum > 0.0) {
                    iter_residual = std::max(
                        iter_residual,
                        std::abs(f[static_cast<size_t>(v)] - avg)
                    );
                }
            }

            max_change.push_back(iter_change);
            max_residual.push_back(iter_residual);
            num_iterations = iter + 1;

            if (iter_change < tolerance && iter_residual < tolerance) {
                converged = true;
                break;
            }
        }
    }

    NumericVector harmonic_predictions(n);
    for (int i = 0; i < n; ++i) {
        harmonic_predictions[i] = f[static_cast<size_t>(i)];
    }

    return List::create(
        Named("harmonic_predictions") = harmonic_predictions,
        Named("converged") = converged,
        Named("num_region") = static_cast<int>(region.size()),
        Named("num_boundary") = static_cast<int>(boundary.size()),
        Named("num_interior") = static_cast<int>(interior.size()),
        Named("num_iterations") = num_iterations,
        Named("max_change") = NumericVector(max_change.begin(), max_change.end()),
        Named("max_residual") = NumericVector(max_residual.begin(), max_residual.end())
    );
}
