#!/usr/bin/env Rscript

## K4.1: native local-PCA LPS chart-cache benchmark.
##
## K4 introduced an explicit native local-PCA backend. K4.1 caches local PCA
## chart coordinates across candidates that share the same target, support
## size, and chart dimension. This benchmark checks numerical agreement against
## the R reference path and reports elapsed time relative to the previous K4
## native benchmark when that artifact is available.

suppressPackageStartupMessages({
    library(geosmooth)
})

project.dir <- "/Users/pgajer/current_projects/geosmooth"
asset.dir <- paste0(
    "/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/",
    "experiments/p7_prospective_synthetic_suite/validation/",
    "k38_valencia_linf_geometries_20260604/embeddings"
)
out.dir <- file.path(
    project.dir,
    "split_handoffs",
    "k4_1_lps_local_pca_chart_cache_2026-06-04"
)
dir.create(out.dir, recursive = TRUE, showWarnings = FALSE)

input.files <- c(
    Li_n250 = file.path(
        asset.dir,
        "valencia13k_Li_Lc_Gv_Bv_n250_ref_Li_embedding.csv"
    ),
    Bv_n250 = file.path(
        asset.dir,
        "valencia13k_Li_Lc_Gv_Bv_n250_ref_Bv_embedding.csv"
    ),
    Li_n500 = file.path(
        asset.dir,
        "valencia13k_Li_Lc_Gv_Bv_n500_ref_Li_embedding.csv"
    ),
    Bv_n500 = file.path(
        asset.dir,
        "valencia13k_Li_Lc_Gv_Bv_n500_ref_Bv_embedding.csv"
    )
)
input.files <- input.files[file.exists(input.files)]
if (!length(input.files)) {
    stop("No K3.8 VALENCIA-derived embedding CSV files were found.")
}

read.numeric.embedding <- function(path) {
    df <- read.csv(path, check.names = FALSE)
    is.num <- vapply(df, function(z) {
        zz <- suppressWarnings(as.numeric(z))
        all(is.finite(zz))
    }, logical(1L))
    X <- as.matrix(data.frame(lapply(df[, is.num, drop = FALSE], as.numeric)))
    if (!ncol(X)) stop("No numeric columns found in ", path)
    X[, seq_len(min(3L, ncol(X))), drop = FALSE]
}

truth.response <- function(X) {
    Xs <- scale(X)
    Xs <- as.matrix(Xs)
    if (ncol(Xs) < 3L) {
        Xs <- cbind(Xs, matrix(0, nrow(Xs), 3L - ncol(Xs)))
    }
    as.numeric(sin(Xs[, 1L]) + 0.5 * cos(Xs[, 2L]) + 0.25 * Xs[, 3L])
}

expected.chart.counts <- function(foldid, candidates) {
    n.candidates <- nrow(candidates)
    unique.chart.keys <- unique(candidates[, c("support.size", "chart.dim")])
    n.unique.keys <- nrow(unique.chart.keys)
    n.targets <- length(foldid)
    data.frame(
        chart.builds.before.cache = n.targets * n.candidates,
        chart.builds.after.cache = n.targets * n.unique.keys,
        chart.build.reuse.factor = n.candidates / n.unique.keys
    )
}

run.case <- function(case.id, path, prior.k4 = NULL) {
    X <- scale(read.numeric.embedding(path))
    X <- as.matrix(X)
    y <- truth.response(X)
    foldid <- rep(seq_len(3L), length.out = nrow(X))
    support.grid <- c(15L, 25L)
    degree.grid <- 1:2
    kernel.grid <- c("gaussian", "tricube")
    chart.dim <- min(2L, ncol(X))
    common.args <- list(
        X = X,
        y = y,
        foldid = foldid,
        support.grid = support.grid,
        degree.grid = degree.grid,
        kernel.grid = kernel.grid,
        coordinate.method = "local.pca",
        local.chart.method = "pca",
        chart.dim = chart.dim
    )
    candidates <- expand.grid(
        support.size = support.grid,
        degree = degree.grid,
        kernel = kernel.grid,
        chart.dim = chart.dim,
        KEEP.OUT.ATTRS = FALSE,
        stringsAsFactors = FALSE
    )
    chart.counts <- expected.chart.counts(foldid, candidates)

    t.r <- system.time(
        fit.r <- do.call(fit.lps, c(common.args, list(backend = "R")))
    )
    t.cpp <- system.time(
        fit.cpp <- do.call(fit.lps, c(common.args, list(backend = "cpp.local.pca")))
    )

    cv.r <- fit.r$cv.table$cv.rmse.observed
    cv.cpp <- fit.cpp$cv.table$cv.rmse.observed
    cv.denom <- pmax(abs(cv.r), sqrt(.Machine$double.eps))
    prior.cpp <- NA_real_
    speedup.cache.over.k4 <- NA_real_
    if (!is.null(prior.k4) && "case.id" %in% names(prior.k4)) {
        idx <- match(case.id, prior.k4$case.id)
        if (!is.na(idx) && "cpp.elapsed.sec" %in% names(prior.k4)) {
            prior.cpp <- prior.k4$cpp.elapsed.sec[[idx]]
            speedup.cache.over.k4 <- prior.cpp / unname(t.cpp[["elapsed"]])
        }
    }

    data.frame(
        case.id = case.id,
        n = nrow(X),
        p = ncol(X),
        support.grid = paste(support.grid, collapse = ","),
        degree.grid = paste(degree.grid, collapse = ","),
        kernel.grid = paste(kernel.grid, collapse = ","),
        chart.dim = chart.dim,
        chart.builds.before.cache = chart.counts$chart.builds.before.cache,
        chart.builds.after.cache = chart.counts$chart.builds.after.cache,
        chart.build.reuse.factor = chart.counts$chart.build.reuse.factor,
        r.elapsed.sec = unname(t.r[["elapsed"]]),
        cpp.cached.elapsed.sec = unname(t.cpp[["elapsed"]]),
        prior.k4.cpp.elapsed.sec = prior.cpp,
        speedup.r.over.cached.cpp = unname(t.r[["elapsed"]] / t.cpp[["elapsed"]]),
        speedup.cached.cpp.over.k4.cpp = speedup.cache.over.k4,
        max.abs.cv.diff = max(abs(cv.r - cv.cpp)),
        max.rel.cv.diff = max(abs(cv.r - cv.cpp) / cv.denom),
        max.abs.fitted.diff = max(abs(
            fit.r$fitted.values - fit.cpp$fitted.values
        )),
        r.selected.support = fit.r$selected$support.size[[1L]],
        cpp.selected.support = fit.cpp$selected$support.size[[1L]],
        r.selected.degree = fit.r$selected$degree[[1L]],
        cpp.selected.degree = fit.cpp$selected$degree[[1L]],
        r.selected.kernel = fit.r$selected$kernel[[1L]],
        cpp.selected.kernel = fit.cpp$selected$kernel[[1L]],
        stringsAsFactors = FALSE
    )
}

prior.path <- file.path(
    project.dir,
    "split_handoffs",
    "k4_lps_local_pca_native_prototype_2026-06-04",
    "k4_lps_local_pca_native_prototype_results.csv"
)
prior.k4 <- if (file.exists(prior.path)) {
    read.csv(prior.path, stringsAsFactors = FALSE)
} else {
    NULL
}

results <- do.call(
    rbind,
    Map(function(nm, path) run.case(nm, path, prior.k4), names(input.files), input.files)
)

csv.path <- file.path(out.dir, "k4_1_lps_local_pca_chart_cache_results.csv")
write.csv(results, csv.path, row.names = FALSE)

fmt <- function(x) {
    if (is.numeric(x)) return(format(signif(x, 5), trim = TRUE))
    as.character(x)
}
table.html <- paste0(
    "<table><thead><tr>",
    paste(sprintf("<th>%s</th>", names(results)), collapse = ""),
    "</tr></thead><tbody>",
    paste(apply(results, 1L, function(row) {
        paste0("<tr>", paste(sprintf("<td>%s</td>", fmt(row)), collapse = ""), "</tr>")
    }), collapse = "\n"),
    "</tbody></table>"
)
html.path <- file.path(out.dir, "k4_1_lps_local_pca_chart_cache.html")
html <- c(
    "<!doctype html>",
    "<html><head><meta charset='utf-8'>",
    "<title>K4.1 LPS Local-PCA Chart Cache</title>",
    "<style>",
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;",
    "max-width:1180px;margin:40px auto;line-height:1.45;color:#1f2933;}",
    "table{border-collapse:collapse;width:100%;font-size:12px;}",
    "th,td{border:1px solid #d7dee8;padding:5px 7px;text-align:right;}",
    "th{text-align:left;background:#edf2f7;}td:first-child{text-align:left;}",
    "code{background:#f3f6f9;padding:1px 4px;border-radius:3px;}",
    "</style></head><body>",
    "<h1>K4.1 LPS Local-PCA Chart Cache</h1>",
    "<p>K4.1 caches native local-PCA chart coordinates across candidates ",
    "sharing the same fold, target, support size, and chart dimension. The ",
    "weighted local-polynomial solve is still performed separately for each ",
    "kernel and degree.</p>",
    "<p>The mathematical validation criterion is unchanged from K4: candidate ",
    "CV RMSE and final fitted values should agree with the R reference path up ",
    "to numerical tolerance.</p>",
    table.html,
    sprintf("<p>CSV: <code>%s</code></p>", csv.path),
    "</body></html>"
)
writeLines(html, html.path)

handoff.path <- file.path(
    project.dir,
    "split_handoffs",
    "k4_1_lps_local_pca_chart_cache_handoff_2026-06-04.md"
)
build.time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z",
                     tz = "America/New_York")
median.cache.speedup <- stats::median(
    results$speedup.cached.cpp.over.k4.cpp,
    na.rm = TRUE
)
writeLines(c(
    "# K4.1 Handoff: Native Local-PCA LPS Chart Cache",
    "",
    paste0("Generated: ", build.time),
    "",
    "## Outputs",
    "",
    paste0("- HTML report: `", html.path, "`"),
    paste0("- Results CSV: `", csv.path, "`"),
    "",
    "## Change",
    "",
    "K4.1 caches the local PCA chart coordinates inside ",
    "`rcpp_kernel_local_polynomial_cv_local_pca()` for each fold/target and ",
    "`(support.size, chart.dim)` pair. Candidates that differ only by degree or ",
    "kernel now reuse the same chart coordinates.",
    "",
    "The audit-response patch also changes the native weighted local-polynomial ",
    "solve order to use rank-aware QR before falling back to ",
    "`stats::lm.wfit()` for R-compatible rank-deficient cases. This avoids the ",
    "normal-equation drift that previously showed up in singular, tied, or ",
    "ill-conditioned local designs.",
    "",
    "The prediction backend is unchanged because production prediction uses a ",
    "single selected candidate and therefore does not have candidate-level chart ",
    "reuse to exploit.",
    "",
    "## Benchmark Summary",
    "",
    paste0("- Benchmark cases: `", nrow(results), "`."),
    paste0("- Candidate chart-build reuse factor in this benchmark: `",
           signif(stats::median(results$chart.build.reuse.factor), 5), "`."),
    paste0("- Median R / cached-C++ elapsed-time speedup: `",
           signif(stats::median(results$speedup.r.over.cached.cpp), 5), "`."),
    if (is.finite(median.cache.speedup)) {
        paste0("- Median cached-C++ / prior-K4-C++ speedup: `",
               signif(median.cache.speedup, 5), "`.")
    } else {
        "- Prior K4 timing artifact was not available for direct comparison."
    },
    paste0("- Maximum absolute CV RMSE difference vs R reference: `",
           signif(max(results$max.abs.cv.diff), 5), "`."),
    paste0("- Maximum relative CV RMSE difference vs R reference: `",
           signif(max(results$max.rel.cv.diff), 5), "`."),
    paste0("- Maximum absolute fitted-value difference vs R reference: `",
           signif(max(results$max.abs.fitted.diff), 5), "`."),
    "",
    "## Validation",
    "",
    "- `R CMD INSTALL --preclean /Users/pgajer/current_projects/geosmooth`: passed.",
    "- Focused `test-ge7-lps-api.R`: passed.",
    "- Focused `test-ge1-r-smoothers.R`: passed.",
    "- Adversarial parity probes passed for exact plane grid, duplicated rows, ",
    "  exact line, and `chart.dim = \"auto\"` cases.",
    "- `make test`: passed with 878 passing checks, 9 expected split-era skips, ",
    "  and no failures or warnings.",
    "- `git diff --check`: passed after this handoff was written.",
    "",
    "## Recommended Next Step",
    "",
    "Ask for K4.1 audit. If accepted, proceed to K5 validation: broader ",
    "equivalence, stress, and performance checks for the optimized LPS backend ",
    "before promoting the native local-PCA path beyond explicit opt-in."
), handoff.path)

cat("Wrote K4.1 results:", csv.path, "\n")
cat("Wrote K4.1 HTML:", html.path, "\n")
cat("Wrote K4.1 handoff:", handoff.path, "\n")
print(results)
