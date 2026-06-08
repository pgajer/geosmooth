#!/usr/bin/env Rscript

pkgload::load_all(".", quiet = TRUE)

timestamp <- function() {
    format(as.POSIXct(Sys.time(), tz = "America/New_York"),
           "%Y-%m-%d %H:%M:%S %Z")
}

rmse <- function(a, b) sqrt(mean((a - b)^2))

make.datasets <- function() {
    set.seed(6106)
    x <- seq(-1, 1, length.out = 80)
    f1 <- sin(3 * x)
    X1 <- cbind(x, x + 1e-10 * rnorm(length(x)), x^2)
    y1 <- f1 + rnorm(length(x), sd = 0.03)

    set.seed(6107)
    U <- matrix(runif(100 * 2), 100, 2)
    bump <- function(center, scale, amp) {
        amp * exp(-rowSums((sweep(U, 2, center, "-"))^2) / (2 * scale^2))
    }
    f2 <- bump(c(0.3, 0.35), 0.12, 1.0) + bump(c(0.72, 0.65), 0.18, 0.7)
    X2 <- cbind(U[, 1], U[, 2], U[, 1] + U[, 2],
                U[, 1] - U[, 2] + 1e-9 * rnorm(nrow(U)))
    y2 <- f2 + rnorm(nrow(U), sd = 0.04)

    set.seed(6108)
    n <- 96
    t <- runif(n)
    on.line <- seq_len(n) <= n / 2
    X3 <- matrix(0, n, 3)
    X3[on.line, ] <- cbind(t[on.line], 0, 0)
    X3[!on.line, ] <- cbind(t[!on.line], runif(sum(!on.line)), 0)
    f3 <- sin(2 * pi * X3[, 1]) + 0.6 * X3[, 2]^2
    y3 <- f3 + rnorm(n, sd = 0.035)

    list(
        near_collinear_curve = list(X = X1, y = y1, truth = f1,
                                    chart.dim = 3L,
                                    support.grid = c(12L, 16L, 20L)),
        redundant_two_bump_surface = list(X = X2, y = y2, truth = f2,
                                          chart.dim = 3L,
                                          support.grid = c(14L, 18L, 24L)),
        mixed_line_sheet = list(X = X3, y = y3, truth = f3,
                                chart.dim = 3L,
                                support.grid = c(12L, 16L, 22L))
    )
}

settings <- list(
    weighted_qr_drop_ridge0_guarded = list(
        design.basis = "weighted.qr.drop",
        design.drop.tol = 1e-7,
        ridge.multiplier.grid = 0,
        ridge.condition.max = 1e12,
        label = "weighted.qr.drop, ridge = 0, guarded"
    ),
    weighted_qr_drop_tiny_guarded = list(
        design.basis = "weighted.qr.drop",
        design.drop.tol = 1e-7,
        ridge.multiplier.grid = c(1e-10, 1e-8),
        ridge.condition.max = 1e12,
        label = "weighted.qr.drop, tiny ridge, guarded"
    ),
    monomial_tiny_ridge_current = list(
        design.basis = "monomial",
        design.drop.tol = 1e-7,
        ridge.multiplier.grid = 1e-8,
        ridge.condition.max = Inf,
        label = "monomial, tiny ridge, current"
    )
)

fit.one <- function(dataset.id, dat, setting.id, setting) {
    foldid <- rep(seq_len(5L), length.out = length(dat$y))
    t0 <- proc.time()
    fit <- fit.lps(
        X = dat$X,
        y = dat$y,
        foldid = foldid,
        support.grid = dat$support.grid,
        degree.grid = 2L,
        kernel.grid = "tricube",
        coordinate.method = "local.pca",
        chart.dim = dat$chart.dim,
        backend = "auto",
        design.basis = setting$design.basis,
        design.drop.tol = setting$design.drop.tol,
        ridge.multiplier.grid = setting$ridge.multiplier.grid,
        ridge.condition.max = setting$ridge.condition.max,
        unstable.action = "na"
    )
    elapsed <- unname((proc.time() - t0)[["elapsed"]])
    data.frame(
        dataset = dataset.id,
        setting = setting.id,
        label = setting$label,
        n = nrow(dat$X),
        ambient.dim = ncol(dat$X),
        chart.dim = dat$chart.dim,
        selected.support = fit$selected$support.size[[1L]],
        selected.cv.rmse = fit$selected$cv.rmse.observed[[1L]],
        truth.rmse = rmse(fit$fitted.values, dat$truth),
        observed.rmse = rmse(fit$fitted.values, dat$y),
        finite.cv.candidates = sum(is.finite(fit$cv.table$cv.rmse.observed)),
        total.cv.candidates = nrow(fit$cv.table),
        elapsed.sec = elapsed,
        stringsAsFactors = FALSE
    )
}

datasets <- make.datasets()
rows <- list()
rr <- 0L
for (dataset.id in names(datasets)) {
    for (setting.id in names(settings)) {
        rr <- rr + 1L
        rows[[rr]] <- fit.one(dataset.id, datasets[[dataset.id]],
                              setting.id, settings[[setting.id]])
    }
}
results <- do.call(rbind, rows)

out.dir <- file.path(
    "split_handoffs",
    paste0("lps_design_basis_guarded_ridge_", format(Sys.Date(), "%Y-%m-%d"))
)
dir.create(out.dir, recursive = TRUE, showWarnings = FALSE)
csv.path <- file.path(out.dir, "lps_design_basis_guarded_ridge_results.csv")
write.csv(results, csv.path, row.names = FALSE)

html.escape <- function(x) {
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    gsub(">", "&gt;", x, fixed = TRUE)
}

fmt <- function(x, digits = 4) {
    ifelse(is.finite(x), formatC(x, format = "fg", digits = digits), "Inf")
}

table.html <- function(df) {
    header <- paste0("<tr>", paste0("<th>", html.escape(names(df)), "</th>",
                                   collapse = ""), "</tr>")
    body <- apply(df, 1, function(row) {
        paste0("<tr>", paste0("<td>", html.escape(row), "</td>", collapse = ""),
               "</tr>")
    })
    paste0("<table>", header, paste(body, collapse = "\n"), "</table>")
}

plot.svg <- function(results) {
    datasets <- unique(results$dataset)
    settings <- unique(results$setting)
    labels <- setNames(
        c("QR drop, ridge 0", "QR drop, tiny", "Monomial, tiny"),
        settings
    )
    w <- 920
    h <- 430
    ml <- 170
    mr <- 30
    mt <- 35
    mb <- 65
    ymax <- max(results$truth.rmse[is.finite(results$truth.rmse)]) * 1.15
    ymap <- function(y) h - mb - (y / ymax) * (h - mt - mb)
    xslots <- seq(ml, w - mr, length.out = length(datasets))
    offsets <- seq(-45, 45, length.out = length(settings))
    colors <- c("#0072B2", "#009E73", "#D55E00")
    names(colors) <- settings
    parts <- c(
        sprintf('<svg viewBox="0 0 %d %d" role="img" aria-label="Truth RMSE comparison">', w, h),
        '<line x1="170" y1="365" x2="890" y2="365" stroke="#333"/>',
        '<line x1="170" y1="35" x2="170" y2="365" stroke="#333"/>'
    )
    ticks <- pretty(c(0, ymax), n = 5)
    ticks <- ticks[ticks >= 0 & ticks <= ymax]
    for (tk in ticks) {
        yy <- ymap(tk)
        parts <- c(parts,
                   sprintf('<line x1="165" y1="%.1f" x2="890" y2="%.1f" stroke="#ddd"/>', yy, yy),
                   sprintf('<text x="155" y="%.1f" text-anchor="end" font-size="12">%.3f</text>', yy + 4, tk))
    }
    for (ii in seq_along(datasets)) {
        ds <- datasets[[ii]]
        parts <- c(parts,
                   sprintf('<text x="%.1f" y="400" text-anchor="middle" font-size="12">%s</text>',
                           xslots[[ii]], html.escape(ds)))
        for (jj in seq_along(settings)) {
            st <- settings[[jj]]
            row <- results[results$dataset == ds & results$setting == st, ]
            xx <- xslots[[ii]] + offsets[[jj]]
            if (is.finite(row$truth.rmse)) {
                yy <- ymap(row$truth.rmse)
                parts <- c(parts,
                           sprintf('<line x1="%.1f" y1="365" x2="%.1f" y2="%.1f" stroke="#aaa"/>',
                                   xx, xx, yy),
                           sprintf('<circle cx="%.1f" cy="%.1f" r="5" fill="%s"><title>%s: Truth RMSE %s</title></circle>',
                                   xx, yy, colors[[st]], html.escape(labels[[st]]),
                                   fmt(row$truth.rmse)))
            } else {
                parts <- c(parts,
                           sprintf('<line x1="%.1f" y1="355" x2="%.1f" y2="375" stroke="%s" stroke-width="2"/>',
                                   xx - 6, xx + 6, colors[[st]]),
                           sprintf('<line x1="%.1f" y1="375" x2="%.1f" y2="355" stroke="%s" stroke-width="2"><title>%s: unstable/no finite CV candidates</title></line>',
                                   xx - 6, xx + 6, colors[[st]],
                                   html.escape(labels[[st]])))
            }
        }
    }
    lx <- 650
    ly <- 45
    for (jj in seq_along(settings)) {
        st <- settings[[jj]]
        parts <- c(parts,
                   sprintf('<circle cx="%d" cy="%d" r="5" fill="%s"/>',
                           lx, ly + 20 * (jj - 1), colors[[st]]),
                   sprintf('<text x="%d" y="%d" font-size="12">%s</text>',
                           lx + 12, ly + 4 + 20 * (jj - 1),
                           html.escape(labels[[st]])))
    }
    c(parts, "</svg>")
}

display <- results
display$selected.cv.rmse <- fmt(display$selected.cv.rmse)
display$truth.rmse <- fmt(display$truth.rmse)
display$observed.rmse <- fmt(display$observed.rmse)
display$elapsed.sec <- fmt(display$elapsed.sec, 3)

html.path <- file.path(out.dir, "lps_design_basis_guarded_ridge_comparison.html")
html <- c(
    "<!doctype html>",
    "<html><head><meta charset='utf-8'>",
    "<title>LPS Design Basis Guarded Ridge Comparison</title>",
    "<script src='https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js'></script>",
    "<style>",
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;max-width:1100px;margin:36px auto;line-height:1.45;color:#1f2933}",
    "h1,h2{line-height:1.15} table{border-collapse:collapse;width:100%;font-size:13px} th,td{border:1px solid #d8dee4;padding:6px 8px;text-align:left} th{background:#f3f4f6} .meta{color:#59636e;font-size:14px}.note{background:#f8fafc;border-left:4px solid #547aa5;padding:10px 14px}",
    "</style></head><body>",
    "<h1>LPS Design Basis Guarded Ridge Comparison</h1>",
    sprintf("<p class='meta'>Report build: %s. Result CSV: <code>%s</code>.</p>",
            timestamp(), csv.path),
    "<h2>Purpose</h2>",
    "<p>This smoke comparison checks the new local polynomial numerical backend in three configurations requested for LPS: weighted QR with rank-deficient columns dropped and no ridge, weighted QR with column dropping plus a tiny ridge grid, and the current monomial design with a tiny ridge.</p>",
    "<p>The guarded configurations first drop columns that are rank-deficient in the weighted local design, then use the smallest ridge multiplier in the supplied grid that satisfies the condition-number cap (set to 1e12 in this smoke comparison). Candidates whose local fits cannot satisfy the cap are assigned non-finite validation error so support and degree selection can avoid them.</p>",
    "<p>The main score here is synthetic Truth RMSE, \\(\\sqrt{n^{-1}\\sum_i (\\hat f_i-f_i)^2}\\). CV RMSE is the observed fold score used to select a candidate; Truth RMSE is shown only because these are synthetic tests.</p>",
    "<h2>Truth RMSE By Dataset</h2>",
    paste(plot.svg(results), collapse = "\n"),
    "<p class='note'>Cross marks indicate a configuration for which all candidate CV scores were non-finite after the guard. In this stress panel, zero-ridge weighted-QR/drop is too strict, while weighted-QR/drop plus a tiny ridge grid agrees numerically with the monomial tiny-ridge reference on the repairable candidates.</p>",
    "<h2>Result Table</h2>",
    table.html(display[, c("dataset", "label", "selected.support",
                          "selected.cv.rmse", "truth.rmse", "observed.rmse",
                          "finite.cv.candidates", "total.cv.candidates",
                          "elapsed.sec")]),
    "<h2>Interpretation</h2>",
    "<p>The comparison exercises the intended engineering behavior: <code>weighted.qr.drop</code> can make rank-deficient local degree-two designs estimable before ridge is considered, while the tiny-ridge variant gives the guard a second repair mechanism. The monomial path remains the compatibility baseline, but it does not distinguish true column redundancy from ordinary ill-conditioning.</p>",
    "<p>This is not a performance claim for P7X-scale experiments. It is a focused numerical smoke test showing that the new API paths run, select finite candidates when the guarded problem is repairable, and expose unstable candidates through non-finite CV scores.</p>",
    "<h2>Reproducibility</h2>",
    "<p>Regenerate with <code>Rscript scripts/lps_design_basis_guarded_ridge_comparison.R</code> from the geosmooth repository root.</p>",
    "</body></html>"
)
writeLines(html, html.path)
message("Wrote ", html.path)
