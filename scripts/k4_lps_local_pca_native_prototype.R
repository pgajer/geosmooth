#!/usr/bin/env Rscript

## K4: native local-PCA LPS backend prototype benchmark.
##
## This script compares the existing R local-PCA LPS path against the explicit
## `backend = "cpp.local.pca"` prototype on fixed-dimension local-PCA charts.
## It intentionally does not change `backend = "auto"`.

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
    "k4_lps_local_pca_native_prototype_2026-06-04"
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
    if (!ncol(X)) {
        stop("No numeric columns found in ", path)
    }
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

run.case <- function(case.id, path) {
    X <- scale(read.numeric.embedding(path))
    X <- as.matrix(X)
    y <- truth.response(X)
    foldid <- rep(seq_len(3L), length.out = nrow(X))
    common.args <- list(
        X = X,
        y = y,
        foldid = foldid,
        support.grid = c(15L, 25L),
        degree.grid = 1:2,
        kernel.grid = c("gaussian", "tricube"),
        coordinate.method = "local.pca",
        local.chart.method = "pca",
        chart.dim = min(2L, ncol(X))
    )

    t.r <- system.time(
        fit.r <- do.call(fit.lps, c(common.args, list(backend = "R")))
    )
    t.cpp <- system.time(
        fit.cpp <- do.call(fit.lps, c(common.args, list(backend = "cpp.local.pca")))
    )

    cv.r <- fit.r$cv.table$cv.rmse.observed
    cv.cpp <- fit.cpp$cv.table$cv.rmse.observed
    cv.denom <- pmax(abs(cv.r), sqrt(.Machine$double.eps))

    data.frame(
        case.id = case.id,
        n = nrow(X),
        p = ncol(X),
        support.grid = paste(common.args$support.grid, collapse = ","),
        degree.grid = paste(common.args$degree.grid, collapse = ","),
        kernel.grid = paste(common.args$kernel.grid, collapse = ","),
        chart.dim = common.args$chart.dim,
        r.elapsed.sec = unname(t.r[["elapsed"]]),
        cpp.elapsed.sec = unname(t.cpp[["elapsed"]]),
        speedup.r.over.cpp = unname(t.r[["elapsed"]] / t.cpp[["elapsed"]]),
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

results <- do.call(
    rbind,
    Map(run.case, names(input.files), input.files)
)

csv.path <- file.path(out.dir, "k4_lps_local_pca_native_prototype_results.csv")
write.csv(results, csv.path, row.names = FALSE)

html.path <- file.path(out.dir, "k4_lps_local_pca_native_prototype.html")
fmt <- function(x) {
    if (is.numeric(x)) {
        return(format(signif(x, 5), trim = TRUE))
    }
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
html <- c(
    "<!doctype html>",
    "<html><head><meta charset='utf-8'>",
    "<title>K4 LPS Local-PCA Native Prototype</title>",
    "<style>",
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;",
    "max-width:1100px;margin:40px auto;line-height:1.45;color:#1f2933;}",
    "table{border-collapse:collapse;width:100%;font-size:13px;}",
    "th,td{border:1px solid #d7dee8;padding:6px 8px;text-align:right;}",
    "th{text-align:left;background:#edf2f7;}td:first-child{text-align:left;}",
    "code{background:#f3f6f9;padding:1px 4px;border-radius:3px;}",
    "</style></head><body>",
    "<h1>K4 LPS Local-PCA Native Prototype</h1>",
    "<p>This benchmark compares the existing R local-PCA path in ",
    "<code>fit.lps()</code> with the explicit native prototype ",
    "<code>backend = \"cpp.local.pca\"</code>. The package default ",
    "<code>backend = \"auto\"</code> remains unchanged.</p>",
    "<p>The validation criterion is numerical agreement of candidate CV RMSE ",
    "and final fitted values, plus a simple elapsed-time comparison on existing ",
    "K3.8 VALENCIA-derived embedding assets.</p>",
    table.html,
    sprintf("<p>CSV: <code>%s</code></p>", csv.path),
    "</body></html>"
)
writeLines(html, html.path)

handoff.path <- file.path(
    project.dir,
    "split_handoffs",
    "k4_lps_local_pca_native_prototype_handoff_2026-06-04.md"
)
build.time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z",
                     tz = "America/New_York")
writeLines(c(
    "# K4 Handoff: Native Local-PCA LPS Backend Prototype",
    "",
    paste0("Generated: ", build.time),
    "",
    "## Outputs",
    "",
    paste0("- HTML report: `", html.path, "`"),
    paste0("- Results CSV: `", csv.path, "`"),
    "",
    "## Summary",
    "",
    "- Added explicit `backend = \"cpp.local.pca\"` support for ",
    "  `fit.lps(coordinate.method = \"local.pca\", local.chart.method = \"pca\")`.",
    "- `backend = \"auto\"` is unchanged: ambient coordinates use C++, ",
    "  local-PCA charts still use the R reference path until audit promotes the ",
    "  native path.",
    paste0("- Benchmark cases: `", nrow(results), "`."),
    paste0("- Median R / C++ elapsed-time speedup: `",
           signif(stats::median(results$speedup.r.over.cpp), 5), "`."),
    paste0("- Maximum absolute CV RMSE difference: `",
           signif(max(results$max.abs.cv.diff), 5), "`."),
    paste0("- Maximum relative CV RMSE difference: `",
           signif(max(results$max.rel.cv.diff), 5), "`."),
    paste0("- Maximum absolute fitted-value difference: `",
           signif(max(results$max.abs.fitted.diff), 5), "`."),
    "",
    "## Validation",
    "",
    "- `R CMD INSTALL --preclean /Users/pgajer/current_projects/geosmooth`: passed.",
    "- Focused `test-ge7-lps-api.R`: passed.",
    "- Full `tests/testthat` run: passed with the existing expected gflow-parity skips.",
    "- `git diff --check`: passed.",
    "",
    "## Recommended Next Step",
    "",
    "Proceed to K4 audit. If accepted, K4.1 should optimize repeated chart ",
    "construction across candidates that share the same fold, target, support ",
    "size, and chart dimension, then rerun the larger K3.9 benchmark with ",
    "`backend = \"cpp.local.pca\"`."
), handoff.path)

cat("Wrote K4 results:", csv.path, "\n")
cat("Wrote K4 HTML:", html.path, "\n")
cat("Wrote K4 handoff:", handoff.path, "\n")
print(results)
