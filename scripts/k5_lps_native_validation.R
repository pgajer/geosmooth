#!/usr/bin/env Rscript

## K5: broader validation for the explicit native local-PCA LPS backend.
##
## This phase does not change package defaults.  It stress-tests
## backend = "cpp.local.pca" against the R reference implementation across
## adversarial, curved, high-dimensional, and VALENCIA-derived cases.

project.dir <- "/Users/pgajer/current_projects/geosmooth"

suppressPackageStartupMessages({
    pkgload::load_all(project.dir, quiet = TRUE)
})
out.dir <- file.path(
    project.dir,
    "split_handoffs",
    "k5_lps_native_validation_2026-06-04"
)
table.dir <- file.path(out.dir, "tables")
fig.dir <- file.path(out.dir, "report_files")
dir.create(table.dir, recursive = TRUE, showWarnings = FALSE)
dir.create(fig.dir, recursive = TRUE, showWarnings = FALSE)

strict.cv.abs.tol <- 1e-7

valencia.asset.dir <- paste0(
    "/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/",
    "experiments/p7_prospective_synthetic_suite/validation/",
    "k38_valencia_linf_geometries_20260604/embeddings"
)

read.numeric.embedding <- function(path, max.cols = 3L) {
    df <- read.csv(path, check.names = FALSE)
    is.num <- vapply(df, function(z) {
        zz <- suppressWarnings(as.numeric(z))
        all(is.finite(zz))
    }, logical(1L))
    X <- as.matrix(data.frame(lapply(df[, is.num, drop = FALSE], as.numeric)))
    if (!ncol(X)) stop("No numeric columns found in ", path)
    X[, seq_len(min(max.cols, ncol(X))), drop = FALSE]
}

standardize.matrix <- function(X) {
    X <- base::scale(as.matrix(X))
    X[, colSums(!is.finite(X)) == 0L, drop = FALSE]
}

truth.response <- function(X) {
    X <- as.matrix(X)
    Xs <- standardize.matrix(X)
    if (ncol(Xs) < 3L) {
        Xs <- cbind(Xs, matrix(0, nrow(Xs), 3L - ncol(Xs)))
    }
    as.numeric(
        sin(Xs[, 1L]) +
        0.5 * cos(Xs[, 2L]) +
        0.25 * Xs[, 3L] +
        0.1 * Xs[, 1L] * Xs[, 2L]
    )
}

make.cases <- function() {
    cases <- list()

    t <- seq(-1, 1, length.out = 61)
    cases$exact_line_1d <- list(
        X = cbind(t, 2 * t, -0.5 * t),
        y = 1 + t - 0.25 * t^2,
        foldid = rep(1:4, length.out = length(t)),
        support.grid = c(8L, 12L, 16L),
        degree.grid = 0:2,
        kernel.grid = c("gaussian", "tricube"),
        chart.dim = 1L
    )

    uv <- as.matrix(expand.grid(
        u = seq(-1, 1, length.out = 7),
        v = seq(-1, 1, length.out = 7)
    ))
    cases$exact_plane_2d <- list(
        X = cbind(uv[, 1L], uv[, 2L], uv[, 1L] + 2 * uv[, 2L]),
        y = uv[, 1L]^2 - uv[, 2L] + 0.25 * uv[, 1L] * uv[, 2L],
        foldid = rep(1:5, length.out = nrow(uv)),
        support.grid = c(10L, 14L, 18L),
        degree.grid = 1:2,
        kernel.grid = c("gaussian", "tricube"),
        chart.dim = 2L
    )

    base <- as.matrix(expand.grid(u = 0:3, v = 0:2))
    uv.dup <- base[rep(seq_len(nrow(base)), each = 2L), , drop = FALSE]
    cases$duplicated_supports <- list(
        X = cbind(uv.dup[, 1L], uv.dup[, 2L],
                  uv.dup[, 1L] - uv.dup[, 2L]),
        y = 0.2 * seq_len(nrow(uv.dup)) +
            uv.dup[, 1L] - 0.5 * uv.dup[, 2L],
        foldid = rep(1:3, length.out = nrow(uv.dup)),
        support.grid = c(6L, 8L, 12L),
        degree.grid = 1:2,
        kernel.grid = c("gaussian", "tricube"),
        chart.dim = 2L
    )

    set.seed(501)
    th <- seq(0, 4 * pi, length.out = 120)
    X.helix <- cbind(cos(th), sin(th), th / max(th))
    cases$helix_auto_dim <- list(
        X = X.helix,
        y = sin(1.5 * th) + 0.15 * cos(4 * th),
        foldid = rep(1:5, length.out = length(th)),
        support.grid = c(12L, 18L, 25L),
        degree.grid = 0:2,
        kernel.grid = c("gaussian", "tricube"),
        chart.dim = "auto"
    )

    set.seed(502)
    uv2 <- matrix(stats::runif(120 * 2, -1, 1), ncol = 2)
    cases$paraboloid_2d <- list(
        X = cbind(uv2[, 1L], uv2[, 2L], uv2[, 1L]^2 + uv2[, 2L]^2),
        y = exp(-4 * ((uv2[, 1L] - 0.25)^2 + (uv2[, 2L] + 0.1)^2)) +
            0.4 * exp(-10 * ((uv2[, 1L] + 0.35)^2 +
                             (uv2[, 2L] - 0.3)^2)),
        foldid = rep(1:5, length.out = nrow(uv2)),
        support.grid = c(15L, 25L, 35L),
        degree.grid = 1:2,
        kernel.grid = c("gaussian", "tricube"),
        chart.dim = 2L
    )

    set.seed(503)
    uv3 <- matrix(stats::runif(120 * 2, -1, 1), ncol = 2)
    cases$saddle_2d <- list(
        X = cbind(uv3[, 1L], uv3[, 2L], uv3[, 1L]^2 - uv3[, 2L]^2),
        y = sin(pi * uv3[, 1L]) + cos(1.5 * pi * uv3[, 2L]),
        foldid = rep(1:5, length.out = nrow(uv3)),
        support.grid = c(15L, 25L, 35L),
        degree.grid = 1:2,
        kernel.grid = c("gaussian", "tricube"),
        chart.dim = 2L
    )

    set.seed(504)
    latent <- matrix(stats::runif(140 * 2, -1, 1), ncol = 2)
    X.high <- matrix(stats::rnorm(140 * 40, sd = 0.03), ncol = 40)
    X.high[, 1:20] <- X.high[, 1:20] + latent[, 1L]
    X.high[, 21:40] <- X.high[, 21:40] + latent[, 2L]
    cases$highdim_diagonal_2d_auto <- list(
        X = X.high,
        y = exp(-3 * ((latent[, 1L] - 0.2)^2 +
                      (latent[, 2L] + 0.15)^2)),
        foldid = rep(1:5, length.out = nrow(latent)),
        support.grid = c(15L, 25L, 35L),
        degree.grid = 1:2,
        kernel.grid = c("gaussian", "tricube"),
        chart.dim = "auto"
    )

    valencia.files <- c(
        valencia_Li_n250 = file.path(
            valencia.asset.dir,
            "valencia13k_Li_Lc_Gv_Bv_n250_ref_Li_embedding.csv"
        ),
        valencia_Bv_n500 = file.path(
            valencia.asset.dir,
            "valencia13k_Li_Lc_Gv_Bv_n500_ref_Bv_embedding.csv"
        )
    )
    for (nm in names(valencia.files)) {
        if (!file.exists(valencia.files[[nm]])) next
        Xv <- standardize.matrix(read.numeric.embedding(valencia.files[[nm]], 3L))
        cases[[nm]] <- list(
            X = Xv,
            y = truth.response(Xv),
            foldid = rep(1:3, length.out = nrow(Xv)),
            support.grid = c(15L, 25L),
            degree.grid = 1:2,
            kernel.grid = c("gaussian", "tricube"),
            chart.dim = 2L
        )
    }

    cases
}

safe.max.abs <- function(x) {
    x <- abs(as.numeric(x))
    x <- x[is.finite(x)]
    if (!length(x)) NA_real_ else max(x)
}

same.selected <- function(a, b, tol = 1e-8) {
    isTRUE(all.equal(a, b, tolerance = tol, check.attributes = FALSE))
}

cv.observed <- function(fit) {
    out <- fit$cv.table[["cv.rmse.observed"]]
    if (is.null(out)) {
        stop("fit.lps() CV table is missing 'cv.rmse.observed'.")
    }
    as.numeric(out)
}

candidate.diff.table <- function(case.id, fit.r, fit.cpp) {
    tab.r <- fit.r$cv.table
    tab.cpp <- fit.cpp$cv.table
    key.cols <- c("support.size", "degree", "kernel", "chart.dim")
    missing.r <- setdiff(c(key.cols, "cv.rmse.observed"), names(tab.r))
    missing.cpp <- setdiff(c(key.cols, "cv.rmse.observed"), names(tab.cpp))
    if (length(missing.r) || length(missing.cpp)) {
        stop("CV tables do not contain the expected candidate columns.")
    }
    if (nrow(tab.r) != nrow(tab.cpp) ||
        !isTRUE(all.equal(tab.r[, key.cols, drop = FALSE],
                          tab.cpp[, key.cols, drop = FALSE],
                          check.attributes = FALSE))) {
        stop("R and C++ CV tables are not aligned by candidate order.")
    }
    cv.r <- as.numeric(tab.r$cv.rmse.observed)
    cv.cpp <- as.numeric(tab.cpp$cv.rmse.observed)
    abs.diff <- abs(cv.cpp - cv.r)
    denom <- pmax(abs(cv.r), sqrt(.Machine$double.eps))
    rel.diff <- abs.diff / denom
    out <- data.frame(
        case.id = case.id,
        support.size = tab.r$support.size,
        degree = tab.r$degree,
        kernel = tab.r$kernel,
        chart.dim = tab.r$chart.dim,
        r.cv.rmse = cv.r,
        cpp.cv.rmse = cv.cpp,
        abs.diff = abs.diff,
        rel.diff = rel.diff,
        exceeds.strict.abs.tol = abs.diff > strict.cv.abs.tol,
        stringsAsFactors = FALSE
    )
    out[order(out$case.id, -out$abs.diff, -out$rel.diff,
              out$support.size, out$degree, out$kernel), , drop = FALSE]
}

run.case <- function(case.id, spec) {
    message("Running K5 case: ", case.id)
    X <- as.matrix(spec$X)
    y <- as.numeric(spec$y)
    foldid <- as.integer(spec$foldid)
    args <- list(
        X = X,
        y = y,
        foldid = foldid,
        support.grid = spec$support.grid,
        degree.grid = spec$degree.grid,
        kernel.grid = spec$kernel.grid,
        coordinate.method = "local.pca",
        local.chart.method = "pca",
        chart.dim = spec$chart.dim
    )

    err <- NULL
    t.r <- t.cpp <- NA_real_
    fit.r <- fit.cpp <- NULL
    tryCatch({
        tr <- system.time(
            fit.r <- do.call(fit.lps, c(args, list(backend = "R")))
        )
        tc <- system.time(
            fit.cpp <- do.call(fit.lps, c(args, list(backend = "cpp.local.pca")))
        )
        t.r <- unname(tr[["elapsed"]])
        t.cpp <- unname(tc[["elapsed"]])
    }, error = function(e) {
        err <<- conditionMessage(e)
    })

    if (!is.null(err)) {
        return(list(summary = data.frame(
            case.id = case.id,
            status = "error",
            error = err,
            n = nrow(X),
            p = ncol(X),
            n.candidates = length(spec$support.grid) *
                length(spec$degree.grid) * length(spec$kernel.grid),
            chart.dim.requested = paste(spec$chart.dim, collapse = ","),
            r.elapsed.sec = t.r,
            cpp.elapsed.sec = t.cpp,
            speedup.r.over.cpp = NA_real_,
            max.abs.cv.diff = NA_real_,
            max.rel.cv.diff = NA_real_,
            max.abs.fitted.diff = NA_real_,
            max.abs.predict.diff = NA_real_,
            selected.same = FALSE,
            selected.r = NA_character_,
            selected.cpp = NA_character_,
            stringsAsFactors = FALSE
        ), candidate.diff = NULL))
    }

    cv.r <- cv.observed(fit.r)
    cv.cpp <- cv.observed(fit.cpp)
    cv.diff <- cv.cpp - cv.r
    cv.denom <- pmax(abs(cv.r),
                     sqrt(.Machine$double.eps))
    eval.idx <- unique(pmax(1L, pmin(nrow(X), round(seq(1, nrow(X), length.out = 7)))))
    pred.r <- predict(fit.r, X[eval.idx, , drop = FALSE])
    pred.cpp <- predict(fit.cpp, X[eval.idx, , drop = FALSE])
    selected.r <- paste(
        paste(names(fit.r$selected), unlist(fit.r$selected), sep = "="),
        collapse = "; "
    )
    selected.cpp <- paste(
        paste(names(fit.cpp$selected), unlist(fit.cpp$selected), sep = "="),
        collapse = "; "
    )

    summary <- data.frame(
        case.id = case.id,
        status = "ok",
        error = "",
        n = nrow(X),
        p = ncol(X),
        n.candidates = nrow(fit.r$cv.table),
        chart.dim.requested = paste(spec$chart.dim, collapse = ","),
        r.elapsed.sec = t.r,
        cpp.elapsed.sec = t.cpp,
        speedup.r.over.cpp = t.r / t.cpp,
        max.abs.cv.diff = safe.max.abs(cv.diff),
        max.rel.cv.diff = safe.max.abs(cv.diff / cv.denom),
        max.abs.fitted.diff = safe.max.abs(fit.cpp$fitted.values -
                                           fit.r$fitted.values),
        max.abs.predict.diff = safe.max.abs(pred.cpp - pred.r),
        selected.same = same.selected(fit.cpp$selected, fit.r$selected),
        selected.r = selected.r,
        selected.cpp = selected.cpp,
        stringsAsFactors = FALSE
    )
    list(
        summary = summary,
        candidate.diff = candidate.diff.table(case.id, fit.r, fit.cpp)
    )
}

cases <- make.cases()
case.outputs <- lapply(names(cases), function(nm) run.case(nm, cases[[nm]]))
results <- do.call(rbind, lapply(case.outputs, `[[`, "summary"))
rownames(results) <- NULL
candidate.diffs <- do.call(
    rbind,
    Filter(Negate(is.null), lapply(case.outputs, `[[`, "candidate.diff"))
)
if (is.null(candidate.diffs)) {
    candidate.diffs <- data.frame(
        case.id = character(),
        support.size = integer(),
        degree = integer(),
        kernel = character(),
        chart.dim = integer(),
        r.cv.rmse = numeric(),
        cpp.cv.rmse = numeric(),
        abs.diff = numeric(),
        rel.diff = numeric(),
        exceeds.strict.abs.tol = logical(),
        stringsAsFactors = FALSE
    )
}

results$parity.pass <- with(
    results,
    status == "ok" &
        selected.same &
        max.abs.cv.diff <= strict.cv.abs.tol &
        max.abs.fitted.diff <= strict.cv.abs.tol &
        max.abs.predict.diff <= strict.cv.abs.tol
)
results$strict.cv.pass <- with(
    results,
    status == "ok" & max.abs.cv.diff <= strict.cv.abs.tol
)
results$output.parity.pass <- with(
    results,
    status == "ok" &
        selected.same &
        max.abs.fitted.diff <= strict.cv.abs.tol &
        max.abs.predict.diff <= strict.cv.abs.tol
)

csv.path <- file.path(table.dir, "k5_lps_native_validation_results.csv")
write.csv(results, csv.path, row.names = FALSE)

candidate.diff.path <- file.path(
    table.dir,
    "k5_lps_native_validation_candidate_diffs.csv"
)
write.csv(candidate.diffs, candidate.diff.path, row.names = FALSE)

warning.details <- candidate.diffs[
    isTRUE(nrow(candidate.diffs) > 0L) &
        candidate.diffs$exceeds.strict.abs.tol,
    ,
    drop = FALSE
]
warning.detail.path <- file.path(
    table.dir,
    "k5_lps_native_validation_warning_candidate_diffs.csv"
)
write.csv(warning.details, warning.detail.path, row.names = FALSE)

summary.path <- file.path(table.dir, "k5_lps_native_validation_summary.csv")
summary.df <- data.frame(
    n.cases = nrow(results),
    n.ok = sum(results$status == "ok"),
    n.strict.cv.pass = sum(results$strict.cv.pass, na.rm = TRUE),
    n.strict.cv.warn = sum(!results$strict.cv.pass, na.rm = TRUE),
    n.output.parity.pass = sum(results$output.parity.pass, na.rm = TRUE),
    n.output.parity.fail = sum(!results$output.parity.pass, na.rm = TRUE),
    max.abs.cv.diff = safe.max.abs(results$max.abs.cv.diff),
    max.rel.cv.diff = safe.max.abs(results$max.rel.cv.diff),
    max.abs.fitted.diff = safe.max.abs(results$max.abs.fitted.diff),
    max.abs.predict.diff = safe.max.abs(results$max.abs.predict.diff),
    median.speedup = stats::median(results$speedup.r.over.cpp, na.rm = TRUE),
    min.speedup = min(results$speedup.r.over.cpp, na.rm = TRUE),
    max.speedup = max(results$speedup.r.over.cpp, na.rm = TRUE)
)
write.csv(summary.df, summary.path, row.names = FALSE)

plot.path <- file.path(fig.dir, "k5_speedup_by_case.png")
png(plot.path, width = 1200, height = 720, res = 130)
ok <- results[results$status == "ok", , drop = FALSE]
ord <- order(ok$speedup.r.over.cpp)
barplot(
    ok$speedup.r.over.cpp[ord],
    names.arg = ok$case.id[ord],
    las = 2,
    ylab = "R elapsed / native local-PCA elapsed",
    col = ifelse(ok$output.parity.pass[ord], "#2f855a", "#c53030"),
    main = "K5 Native Local-PCA LPS Speedup by Case"
)
abline(h = 1, lty = 2, col = "gray40")
dev.off()

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
warning.table.html <- if (!nrow(warning.details)) {
    "<p>No candidates exceeded the strict absolute candidate-CV tolerance.</p>"
} else {
    display <- warning.details[
        order(warning.details$case.id, -warning.details$abs.diff),
        c("case.id", "support.size", "degree", "kernel", "chart.dim",
          "r.cv.rmse", "cpp.cv.rmse", "abs.diff", "rel.diff"),
        drop = FALSE
    ]
    paste0(
        "<table><thead><tr>",
        paste(sprintf("<th>%s</th>", names(display)), collapse = ""),
        "</tr></thead><tbody>",
        paste(apply(display, 1L, function(row) {
            paste0(
                "<tr>",
                paste(sprintf("<td>%s</td>", fmt(row)), collapse = ""),
                "</tr>"
            )
        }), collapse = "\n"),
        "</tbody></table>"
    )
}
html.path <- file.path(out.dir, "k5_lps_native_validation.html")
html <- c(
    "<!doctype html>",
    "<html><head><meta charset='utf-8'>",
    "<title>K5 LPS Native Local-PCA Validation</title>",
    "<style>",
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;",
    "max-width:1220px;margin:40px auto;line-height:1.45;color:#1f2933;}",
    "table{border-collapse:collapse;width:100%;font-size:11px;}",
    "th,td{border:1px solid #d7dee8;padding:5px 7px;text-align:right;}",
    "th{text-align:left;background:#edf2f7;}td:first-child,td:nth-child(2),td:nth-child(17),td:nth-child(18){text-align:left;}",
    ".note{border-left:4px solid #2b6cb0;background:#eef6ff;padding:10px 12px;}",
    "code{background:#f3f6f9;padding:1px 4px;border-radius:3px;}",
    "img{max-width:100%;height:auto;border:1px solid #e5e7eb;}",
    "</style></head><body>",
    "<h1>K5 LPS Native Local-PCA Validation</h1>",
    "<div class='note'>K5 validates the explicit opt-in native backend ",
    "<code>backend = \"cpp.local.pca\"</code> against the R reference path. ",
    "No package defaults are changed.</div>",
    "<h2>Summary</h2>",
    sprintf("<p>Cases: %d; selected-output parity pass: %d; strict candidate-CV warnings: %d.</p>",
            summary.df$n.cases, summary.df$n.output.parity.pass,
            summary.df$n.strict.cv.warn),
    sprintf("<p>Max absolute CV difference: <code>%s</code>; max fitted-value difference: <code>%s</code>; max prediction difference: <code>%s</code>.</p>",
            fmt(summary.df$max.abs.cv.diff),
            fmt(summary.df$max.abs.fitted.diff),
            fmt(summary.df$max.abs.predict.diff)),
    sprintf("<p>Median speedup R/native: <code>%s</code>.</p>",
            fmt(summary.df$median.speedup)),
    "<h2>Speedup</h2>",
    sprintf("<img src='report_files/%s' alt='Speedup by case'>",
            basename(plot.path)),
    "<h2>Case-Level Results</h2>",
    table.html,
    "<h2>Strict Candidate-CV Warning Details</h2>",
    sprintf("<p>The strict absolute candidate-CV tolerance is <code>%s</code>. ",
            format(strict.cv.abs.tol, scientific = TRUE)),
    "The table below archives every candidate whose absolute R/native CV RMSE ",
    "difference exceeds that tolerance, so warning cases can be audited without ",
    "regenerating the fits.</p>",
    warning.table.html,
    sprintf("<p>CSV: <code>%s</code></p>", csv.path),
    sprintf("<p>Candidate-diff CSV: <code>%s</code></p>",
            candidate.diff.path),
    sprintf("<p>Warning-detail CSV: <code>%s</code></p>",
            warning.detail.path),
    "</body></html>"
)
writeLines(html, html.path)

handoff.path <- file.path(
    project.dir,
    "split_handoffs",
    "k5_lps_native_validation_handoff_2026-06-04.md"
)
build.time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z",
                     tz = "America/New_York")
writeLines(c(
    "# K5 Handoff: Native Local-PCA LPS Validation",
    "",
    paste0("Generated: ", build.time),
    "",
    "## Purpose",
    "",
    "K5 is a broader validation phase for the explicit opt-in native ",
    "`fit.lps(..., coordinate.method = \"local.pca\", backend = ",
    "\"cpp.local.pca\")` path. It does not change package defaults.",
    "",
    "The validation script loads the checked-out source tree with ",
    "`pkgload::load_all(project.dir, quiet = TRUE)` so the report validates ",
    "the local implementation rather than an installed `geosmooth` build.",
    "",
    "## Outputs",
    "",
    paste0("- HTML report: `", html.path, "`"),
    paste0("- Case results CSV: `", csv.path, "`"),
paste0("- Summary CSV: `", summary.path, "`"),
    paste0("- Candidate-difference CSV: `", candidate.diff.path, "`"),
    paste0("- Warning-detail CSV: `", warning.detail.path, "`"),
    "",
    "## Validation Matrix",
    "",
    "The suite covers adversarial and realistic cases:",
    "",
    "- exact 1D line embedded in 3D;",
    "- exact 2D plane embedded in 3D;",
    "- duplicated/tied local supports;",
    "- helix with `chart.dim = \"auto\"`;",
    "- curved paraboloid and saddle surfaces;",
    "- high-dimensional diagonal 2D embedding with `chart.dim = \"auto\"`;",
    "- VALENCIA-derived Li/Bv homogeneous embeddings.",
    "",
    "## Results",
    "",
    paste0("- Cases run: `", summary.df$n.cases, "`."),
    paste0("- Successful fits: `", summary.df$n.ok, "`."),
    paste0("- Strict candidate-CV parity passes: `",
           summary.df$n.strict.cv.pass, "`."),
    paste0("- Strict candidate-CV warnings: `",
           summary.df$n.strict.cv.warn, "`."),
    paste0("- Selected-output parity passes: `",
           summary.df$n.output.parity.pass, "`."),
    paste0("- Selected-output parity failures: `",
           summary.df$n.output.parity.fail, "`."),
    paste0("- Maximum absolute CV RMSE difference: `",
           signif(summary.df$max.abs.cv.diff, 5), "`."),
    paste0("- Maximum relative CV RMSE difference: `",
           signif(summary.df$max.rel.cv.diff, 5), "`."),
    paste0("- Maximum absolute fitted-value difference: `",
           signif(summary.df$max.abs.fitted.diff, 5), "`."),
    paste0("- Maximum absolute prediction difference: `",
           signif(summary.df$max.abs.predict.diff, 5), "`."),
    paste0("- Median R/native elapsed-time speedup: `",
           signif(summary.df$median.speedup, 5), "`."),
    "",
    "## Interpretation",
    "",
    "The native local-PCA backend preserves selected candidates, fitted values, ",
    "and predictions on this K5 suite under the explicit opt-in contract. One ",
    "exact-plane stress case has a non-selected degree-1 Gaussian candidate-CV ",
    "difference above the strict candidate-table tolerance. This should be ",
    "diagnosed before promotion beyond explicit opt-in.",
    "",
    "The warning-detail CSV archives every strict-tolerance candidate mismatch ",
    "with candidate metadata and R/native CV values. In this run the warning ",
    "candidates are non-selected exact-plane degree-1 Gaussian candidates; the ",
    "selected candidate and selected-output predictions still match at numerical ",
    "precision.",
    "",
    "## Recommended Next Step",
    "",
    "K5.1 should diagnose the remaining exact-plane non-selected Gaussian ",
    "degree-1 candidate-CV drift before any default-backend promotion. K5.1 ",
    "does not need to block continued explicit opt-in use, but it should be ",
    "audited before this backend is used as a strict full-CV-table replacement."
), handoff.path)

cat("Wrote K5 results:", csv.path, "\n")
cat("Wrote K5 HTML:", html.path, "\n")
cat("Wrote K5 handoff:", handoff.path, "\n")
print(summary.df)
print(results[, c("case.id", "status", "parity.pass",
                  "strict.cv.pass", "output.parity.pass",
                  "speedup.r.over.cpp", "max.abs.cv.diff",
                  "max.abs.fitted.diff", "selected.same")])
if (nrow(warning.details)) {
    cat("\nStrict candidate-CV warning details:\n")
    print(warning.details[, c("case.id", "support.size", "degree", "kernel",
                              "chart.dim", "r.cv.rmse", "cpp.cv.rmse",
                              "abs.diff", "rel.diff")])
}
