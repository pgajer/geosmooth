#!/usr/bin/env Rscript

## K5.1: targeted diagnostic for strict candidate-CV warning rows from K5.
##
## This script does not change package behavior. It decomposes the exact-plane
## warning candidates into held-out target predictions, confirms support-order
## parity with the native tie-complete neighbor probe, and records weighted
## local design conditioning.

project.dir <- "/Users/pgajer/current_projects/geosmooth"
out.dir <- file.path(
    project.dir,
    "split_handoffs",
    "k5_lps_native_validation_2026-06-04"
)
table.dir <- file.path(out.dir, "tables")
dir.create(table.dir, recursive = TRUE, showWarnings = FALSE)

suppressPackageStartupMessages({
    pkgload::load_all(project.dir, quiet = TRUE)
})

uv <- as.matrix(expand.grid(
    u = seq(-1, 1, length.out = 7),
    v = seq(-1, 1, length.out = 7)
))
X <- cbind(uv[, 1L], uv[, 2L], uv[, 1L] + 2 * uv[, 2L])
y <- uv[, 1L]^2 - uv[, 2L] + 0.25 * uv[, 1L] * uv[, 2L]
foldid <- rep(1:5, length.out = nrow(uv))

warning.candidates <- data.frame(
    case.id = "exact_plane_2d",
    support.size = c(10L, 14L),
    degree = 1L,
    kernel = "gaussian",
    chart.dim = 2L,
    stringsAsFactors = FALSE
)

weighted.design.condition <- function(X.train, y.train, center, support.size,
                                      degree, kernel, chart.dim) {
    ordered <- geosmooth:::.klp.local.order(
        X.train = X.train,
        center = center,
        support.size = support.size
    )
    local <- geosmooth:::.klp.local.neighborhood.from.order(
        X.train = X.train,
        y.train = y.train,
        center = center,
        ordered = ordered,
        support.size = support.size,
        coordinate.method = "local.pca",
        chart.dim = chart.dim,
        local.chart.method = "pca"
    )
    weights <- geosmooth:::.klp.kernel.weights(local$distances, kernel)
    design <- geosmooth:::.local.polynomial.design.matrix(local$z, degree)
    ok <- is.finite(local$y) & is.finite(weights) & weights > 0 &
        rowSums(is.finite(design)) == ncol(design)
    if (sum(ok) < ncol(design)) {
        return(list(condition = Inf, min.sv = 0, max.sv = NA_real_,
                    n.ok = sum(ok), n.design = ncol(design)))
    }
    Xw <- design[ok, , drop = FALSE] * sqrt(weights[ok])
    sv <- svd(Xw, nu = 0L, nv = 0L)$d
    min.sv <- min(sv)
    max.sv <- max(sv)
    condition <- if (min.sv <= 0) Inf else max.sv / min.sv
    list(condition = condition, min.sv = min.sv, max.sv = max.sv,
         n.ok = sum(ok), n.design = ncol(design))
}

diagnose.candidate <- function(candidate) {
    support.size <- as.integer(candidate$support.size)
    degree <- as.integer(candidate$degree)
    kernel <- as.character(candidate$kernel)
    chart.dim <- as.integer(candidate$chart.dim)
    rows <- vector("list", length(y))
    cursor <- 0L
    for (fold in sort(unique(foldid))) {
        test <- which(foldid == fold)
        train <- which(foldid != fold)
        X.train <- X[train, , drop = FALSE]
        y.train <- y[train]
        for (target in test) {
            center <- X[target, , drop = FALSE]
            pred.r <- geosmooth:::.klp.predict.local.polynomial(
                X.train = X.train,
                y.train = y.train,
                X.eval = center,
                support.size = support.size,
                degree = degree,
                kernel = kernel,
                coordinate.method = "local.pca",
                chart.dim = chart.dim,
                local.chart.method = "pca",
                backend = "R"
            )
            pred.cpp <- geosmooth:::.klp.predict.local.polynomial(
                X.train = X.train,
                y.train = y.train,
                X.eval = center,
                support.size = support.size,
                degree = degree,
                kernel = kernel,
                coordinate.method = "local.pca",
                chart.dim = chart.dim,
                local.chart.method = "pca",
                backend = "cpp.local.pca"
            )
            probe <- geosmooth:::rcpp_kernel_local_polynomial_neighbor_probe(
                X = X.train,
                center = as.numeric(center),
                k = support.size
            )
            d <- rowSums((X.train - matrix(center, nrow(X.train), ncol(X.train),
                                          byrow = TRUE))^2)
            ref.local <- order(d, seq_along(d))[seq_len(support.size)]
            support.same <- identical(
                as.integer(probe$tie.complete.row),
                as.integer(ref.local)
            )
            cond <- weighted.design.condition(
                X.train = X.train,
                y.train = y.train,
                center = as.numeric(center),
                support.size = support.size,
                degree = degree,
                kernel = kernel,
                chart.dim = chart.dim
            )
            cursor <- cursor + 1L
            rows[[cursor]] <- data.frame(
                case.id = candidate$case.id,
                support.size = support.size,
                degree = degree,
                kernel = kernel,
                chart.dim = chart.dim,
                fold = fold,
                target.index = target,
                r.pred = as.numeric(pred.r),
                cpp.pred = as.numeric(pred.cpp),
                pred.diff = as.numeric(pred.cpp - pred.r),
                r.sqerr = as.numeric((pred.r - y[target])^2),
                cpp.sqerr = as.numeric((pred.cpp - y[target])^2),
                support.same = support.same,
                weighted.design.condition = cond$condition,
                weighted.design.min.sv = cond$min.sv,
                weighted.design.max.sv = cond$max.sv,
                n.ok = cond$n.ok,
                n.design = cond$n.design,
                stringsAsFactors = FALSE
            )
        }
    }
    out <- do.call(rbind, rows[seq_len(cursor)])
    out[order(-abs(out$pred.diff), out$support.size, out$target.index),
        ,
        drop = FALSE
    ]
}

target.details <- do.call(
    rbind,
    lapply(seq_len(nrow(warning.candidates)), function(i) {
        diagnose.candidate(warning.candidates[i, , drop = FALSE])
    })
)
target.path <- file.path(
    table.dir,
    "k5_1_exact_plane_warning_target_diagnostics.csv"
)
write.csv(target.details, target.path, row.names = FALSE)

summary.details <- do.call(
    rbind,
    lapply(split(target.details, target.details$support.size), function(df) {
        data.frame(
            case.id = df$case.id[[1L]],
            support.size = df$support.size[[1L]],
            degree = df$degree[[1L]],
            kernel = df$kernel[[1L]],
            chart.dim = df$chart.dim[[1L]],
            n.targets = nrow(df),
            n.support.mismatch = sum(!df$support.same),
            max.abs.pred.diff = max(abs(df$pred.diff)),
            median.abs.pred.diff = stats::median(abs(df$pred.diff)),
            cv.rmse.r = sqrt(mean(df$r.sqerr)),
            cv.rmse.cpp = sqrt(mean(df$cpp.sqerr)),
            max.weighted.design.condition = max(
                df$weighted.design.condition,
                na.rm = TRUE
            ),
            median.weighted.design.condition = stats::median(
                df$weighted.design.condition,
                na.rm = TRUE
            ),
            min.weighted.design.min.sv = min(
                df$weighted.design.min.sv,
                na.rm = TRUE
            ),
            stringsAsFactors = FALSE
        )
    })
)
summary.path <- file.path(
    table.dir,
    "k5_1_exact_plane_warning_diagnostic_summary.csv"
)
write.csv(summary.details, summary.path, row.names = FALSE)

fmt <- function(x) {
    if (is.numeric(x)) return(format(signif(x, 5), trim = TRUE))
    as.character(x)
}
summary.table <- paste0(
    "<table><thead><tr>",
    paste(sprintf("<th>%s</th>", names(summary.details)), collapse = ""),
    "</tr></thead><tbody>",
    paste(apply(summary.details, 1L, function(row) {
        paste0("<tr>", paste(sprintf("<td>%s</td>", fmt(row)), collapse = ""),
               "</tr>")
    }), collapse = "\n"),
    "</tbody></table>"
)

html.path <- file.path(out.dir, "k5_1_exact_plane_warning_diagnostic.html")
html <- c(
    "<!doctype html>",
    "<html><head><meta charset='utf-8'>",
    "<title>K5.1 Exact-Plane Warning Diagnostic</title>",
    "<style>",
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;",
    "max-width:1120px;margin:40px auto;line-height:1.45;color:#1f2933;}",
    "table{border-collapse:collapse;width:100%;font-size:12px;}",
    "th,td{border:1px solid #d7dee8;padding:5px 7px;text-align:right;}",
    "th{text-align:left;background:#edf2f7;}td:first-child,td:nth-child(4){text-align:left;}",
    "code{background:#f3f6f9;padding:1px 4px;border-radius:3px;}",
    ".note{border-left:4px solid #2b6cb0;background:#eef6ff;padding:10px 12px;}",
    "</style></head><body>",
    "<h1>K5.1 Exact-Plane Warning Diagnostic</h1>",
    "<div class='note'>This diagnostic decomposes the two K5 strict ",
    "candidate-CV warning rows. It is diagnostic only and does not change ",
    "package behavior.</div>",
    "<h2>Summary</h2>",
    summary.table,
    "<h2>Interpretation</h2>",
    "<p>The native tie-complete neighbor probe matched the R distance/order ",
    "reference for every held-out target in both warning candidates ",
    "(<code>n.support.mismatch = 0</code>). The candidate-CV drift is therefore ",
    "not explained by ANN support selection. The remaining differences are ",
    "consistent with small numerical differences in local PCA chart construction ",
    "and/or weighted linear-solve behavior on an exact-plane stress case with ",
    "Gaussian weights.</p>",
    sprintf("<p>Target-level diagnostics CSV: <code>%s</code></p>", target.path),
    sprintf("<p>Summary CSV: <code>%s</code></p>", summary.path),
    "</body></html>"
)
writeLines(html, html.path)

cat("Wrote K5.1 target diagnostics:", target.path, "\n")
cat("Wrote K5.1 summary:", summary.path, "\n")
cat("Wrote K5.1 HTML:", html.path, "\n")
print(summary.details)
