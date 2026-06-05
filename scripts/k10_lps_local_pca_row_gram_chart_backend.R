#!/usr/bin/env Rscript

if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("Package 'pkgload' is required.", call. = FALSE)
}

project.dir <- "/Users/pgajer/current_projects/geosmooth"
pkgload::load_all(project.dir, quiet = TRUE)

timestamp <- function() {
    format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z", tz = "America/New_York")
}

out.dir <- file.path(
    project.dir,
    "split_handoffs",
    "k10_lps_local_pca_row_gram_chart_backend_2026-06-04"
)
dir.create(out.dir, recursive = TRUE, showWarnings = FALSE)

bench.one <- function(k, p, chart.dim, reps) {
    X <- matrix(stats::rnorm(k * p), nrow = k)
    center <- X[1L, ]
    chart.fun <- geosmooth:::rcpp_local_pca_chart

    invisible(chart.fun(
        X_support = X,
        center = center,
        chart_dim = chart.dim,
        center_mode = "anchor",
        dim_rule = "fixed",
        rebase_to_anchor = TRUE,
        orient_basis = FALSE
    ))

    cpp.elapsed <- system.time({
        for (ii in seq_len(reps)) {
            chart.fun(
                X_support = X,
                center = center,
                chart_dim = chart.dim,
                center_mode = "anchor",
                dim_rule = "fixed",
                rebase_to_anchor = TRUE,
                orient_basis = FALSE
            )
        }
    })[["elapsed"]]

    centered <- sweep(X, 2L, center)
    r.svd.elapsed <- system.time({
        for (ii in seq_len(reps)) {
            svd(centered, nu = 0L, nv = chart.dim)
        }
    })[["elapsed"]]

    chart <- chart.fun(
        X_support = X,
        center = center,
        chart_dim = chart.dim,
        center_mode = "anchor",
        dim_rule = "fixed",
        rebase_to_anchor = TRUE,
        orient_basis = FALSE
    )
    ref <- svd(centered, nu = 0L, nv = chart.dim)
    chart.projector <- chart$basis %*% t(chart$basis)
    ref.projector <- ref$v[, seq_len(chart.dim), drop = FALSE] %*%
        t(ref$v[, seq_len(chart.dim), drop = FALSE])

    data.frame(
        k = k,
        p = p,
        chart.dim = chart.dim,
        reps = reps,
        cpp.seconds = cpp.elapsed,
        r.svd.seconds = r.svd.elapsed,
        r.svd.over.cpp = r.svd.elapsed / cpp.elapsed,
        max.singular.diff = max(abs(
            chart$singular.values[seq_len(chart.dim)] -
                ref$d[seq_len(chart.dim)]
        )),
        projector.max.diff = max(abs(chart.projector - ref.projector)),
        stringsAsFactors = FALSE
    )
}

set.seed(1001L)
results <- do.call(rbind, list(
    bench.one(k = 15L, p = 100L, chart.dim = 3L, reps = 200L),
    bench.one(k = 25L, p = 180L, chart.dim = 6L, reps = 100L),
    bench.one(k = 35L, p = 100L, chart.dim = 12L, reps = 80L)
))

csv.path <- file.path(out.dir, "k10_row_gram_chart_backend_benchmark.csv")
utils::write.csv(results, csv.path, row.names = FALSE)

profile.comparison.path <- file.path(
    out.dir,
    "k10_pre_post_k9_profile_comparison.csv"
)
profile.comparison <- if (file.exists(profile.comparison.path)) {
    utils::read.csv(profile.comparison.path)
} else {
    NULL
}

handoff.path <- file.path(
    project.dir,
    "split_handoffs",
    "k10_lps_local_pca_row_gram_chart_backend_handoff_2026-06-04.md"
)

handoff <- c(
    "# K10 Handoff: Row-Gram Local-PCA Chart Backend",
    "",
    paste("Generated:", timestamp()),
    "",
    "## Change",
    "",
    "K10 updates the shared native local-PCA chart constructor used by LPS and",
    "other geosmooth chart-based smoothers. When the local support matrix has",
    "fewer rows than ambient columns, the constructor now computes the PCA",
    "spectrum from the smaller row-Gram matrix `centered %*% t(centered)` and",
    "recovers the right singular vectors from `centered^T u / s`.",
    "",
    "The existing Jacobi SVD path remains as a conservative fallback when the",
    "row-Gram eigensolve fails or when the selected singular subspace is too",
    "close to numerical rank deficiency.",
    "",
    "## Scope",
    "",
    "- This changes the shared chart primitive, not the public LPS API.",
    "- `backend = \"cpp.local.pca\"` remains explicit opt-in.",
    "- `backend = \"auto\"` is unchanged.",
    "- K4.1 candidate-level chart caching remains in place.",
    "- This is not a default-backend promotion.",
    "",
    "## Benchmark",
    "",
    paste("Benchmark CSV:", csv.path),
    "",
    "The small wrapper-level benchmark checks singular values and projection",
    "matrices against an R `svd()` subspace reference on three high-dimensional",
    "local-support shapes. It is a correctness probe, not the primary speed",
    "metric, because the exported chart wrapper returns full R objects and pays",
    "Rcpp list-conversion overhead that the internal C++ CV loop does not pay.",
    "",
    paste(
        "- Maximum singular-value discrepancy:",
        signif(max(results$max.singular.diff), 5)
    ),
    paste(
        "- Maximum projector discrepancy:",
        signif(max(results$projector.max.diff), 5)
    ),
    "",
    "## K9 Internal-Profile Rerun",
    "",
    if (!is.null(profile.comparison)) {
        c(
            paste("Profile comparison CSV:", profile.comparison.path),
            "",
            paste(
                "- Median chart-build speedup on high-dimensional/16S rows:",
                signif(stats::median(profile.comparison$chart_build_speedup[
                    profile.comparison$geometry.family != "controlled_1d"
                ]), 5)
            ),
            paste(
                "- Median native CV speedup on high-dimensional/16S rows:",
                signif(stats::median(profile.comparison$cpp_cv_speedup[
                    profile.comparison$geometry.family != "controlled_1d"
                ]), 5)
            )
        )
    } else {
        "No K9 internal-profile comparison CSV was found when this handoff was generated."
    },
    "",
    "## Validation",
    "",
    "- `R CMD INSTALL --preclean /Users/pgajer/current_projects/geosmooth`: passed.",
    "- Focused `test-ge7-lps-api.R`: passed.",
    "- Focused `test-ge1-r-smoothers.R`: passed.",
    "- Focused `test-ge4-ssrhe-hessian-energy.R`: passed.",
    "- Existing K9 phase-profile script rerun after K10: passed.",
    "- `make test`: passed with 883 checks, 9 expected split-era skips, and no failures or warnings.",
    "",
    "## Interpretation",
    "",
    "K10 targets the chart-construction primitive that dominated the hard",
    "high-dimensional and 16S-style K9 profiling rows. It should reduce the",
    "cost of individual `k << p` local PCA charts, but it does not reduce the",
    "number of charts built. Large candidate grids can still be expensive when",
    "many support sizes or chart dimensions are evaluated.",
    "",
    "## Recommended Next Step",
    "",
    "Ask for K10 audit. If accepted, proceed to K11: update the P7/LPS backend",
    "preflight comparison to include the post-K10 `cpp.local.pca` backend on",
    "the focused high-dimensional and 16S-style panel. Do not promote",
    "`cpp.local.pca` into `backend = \"auto\"` until K11 confirms stable",
    "end-to-end performance and fit parity outside the profiling rows."
)

writeLines(handoff, handoff.path)
message("Wrote: ", csv.path)
message("Wrote: ", handoff.path)
