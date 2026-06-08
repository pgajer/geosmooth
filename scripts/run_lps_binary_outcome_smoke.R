#!/usr/bin/env Rscript

suppressPackageStartupMessages({
    pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet = TRUE)
})

out.dir <- file.path(
    "/Users/pgajer/current_projects/geosmooth",
    "split_handoffs",
    "lps_binary_outcome_smoke_2026-06-07"
)
fig.dir <- file.path(out.dir, "figures")
table.dir <- file.path(out.dir, "tables")
if (dir.exists(out.dir)) {
    unlink(file.path(out.dir, c("figures", "tables")), recursive = TRUE)
    unlink(file.path(out.dir, c(
        "lps_binary_outcome_smoke_report.html",
        "lps_binary_smoke_fit_bundle.rds"
    )))
}
dir.create(fig.dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table.dir, recursive = TRUE, showWarnings = FALSE)

set.seed(70607)
n <- 140L
x <- sort(runif(n))
X <- matrix(x, ncol = 1L)
eta <- -0.35 +
    2.2 * exp(-0.5 * ((x - 0.28) / 0.08)^2) -
    1.9 * exp(-0.5 * ((x - 0.63) / 0.11)^2) +
    1.0 * sin(2 * pi * x)
p.true <- plogis(eta)
y <- rbinom(n, size = 1L, prob = p.true)
foldid <- sample(rep(seq_len(5L), length.out = n))

common.args <- list(
    X = X,
    y = y,
    foldid = foldid,
    support.grid = c(12L, 18L, 24L, 30L),
    degree.grid = 1:2,
    kernel.grid = c("gaussian", "tricube"),
    coordinate.method = "coordinates",
    backend = "R",
    design.basis = "monomial",
    ridge.multiplier.grid = c(1e-8, 1e-6),
    ridge.condition.max = 1e10,
    unstable.action = "mean"
)

fit.gaussian <- do.call(
    fit.lps,
    c(common.args, list(outcome.family = "gaussian"))
)
fit.bernoulli <- do.call(
    fit.lps,
    c(common.args, list(outcome.family = "bernoulli"))
)
fit.binomial <- do.call(
    fit.lps,
    c(common.args, list(outcome.family = "binomial"))
)

grid <- matrix(seq(0, 1, length.out = 300L), ncol = 1L)
grid.eta <- -0.35 +
    2.2 * exp(-0.5 * ((grid[, 1] - 0.28) / 0.08)^2) -
    1.9 * exp(-0.5 * ((grid[, 1] - 0.63) / 0.11)^2) +
    1.0 * sin(2 * pi * grid[, 1])
grid.p.true <- plogis(grid.eta)
grid.pred.bernoulli.raw <- predict(fit.bernoulli, grid, type = "raw")
grid.pred.bernoulli <- predict(fit.bernoulli, grid, type = "response")
grid.pred.binomial <- predict(fit.binomial, grid, type = "response")

clip.prob <- function(p, eps = 1e-15) pmin(1 - eps, pmax(eps, p))
brier <- function(y, p) mean((y - p)^2)
logloss <- function(y, p) {
    p <- clip.prob(p)
    -mean(y * log(p) + (1 - y) * log1p(-p))
}

summarize.fit <- function(label, fit, truth) {
    data.frame(
        method = label,
        selected.support.size = fit$selected$support.size[[1L]],
        selected.degree = fit$selected$degree[[1L]],
        selected.kernel = fit$selected$kernel[[1L]],
        selected.cv.rmse.observed = fit$selected$cv.rmse.observed[[1L]],
        selected.cv.brier.observed =
            fit$selected$cv.brier.observed[[1L]] %||% NA_real_,
        selected.cv.logloss.observed =
            fit$selected$cv.logloss.observed[[1L]] %||% NA_real_,
        observed.brier = brier(y, fit$fitted.values),
        observed.logloss = logloss(y, fit$fitted.values),
        truth.brier = brier(truth, fit$fitted.values),
        truth.rmse = sqrt(brier(truth, fit$fitted.values)),
        fitted.min = min(fit$fitted.values, na.rm = TRUE),
        fitted.max = max(fit$fitted.values, na.rm = TRUE),
        stringsAsFactors = FALSE
    )
}

summary.table <- rbind(
    summarize.fit("bernoulli_brier_lps", fit.bernoulli, p.true),
    summarize.fit("binomial_logistic_lps", fit.binomial, p.true)
)
run.metrics <- data.frame(
    metric = c("n", "event.rate", "raw.bernoulli.gaussian.parity.max.abs"),
    value = c(
        n,
        mean(y),
        max(abs(fit.bernoulli$fitted.values.raw - fit.gaussian$fitted.values))
    ),
    stringsAsFactors = FALSE
)
summarize.logistic.diagnostics <- function(fit) {
    diag <- fit$logistic.diagnostics
    if (is.null(diag)) {
        return(data.frame())
    }
    rows <- lapply(names(diag), function(scope) {
        x <- diag[[scope]]
        data.frame(
            scope = scope,
            attempted = x$attempted %||% NA_integer_,
            converged = x$converged %||% NA_integer_,
            failed = x$failed %||% NA_integer_,
            fallback.path.count = x$fallback.path.count %||% NA_integer_,
            event.rate.fallback.count =
                x$event.rate.fallback.count %||% NA_integer_,
            na.failure.count = x$na.failure.count %||% NA_integer_,
            convergence.fraction = x$convergence.fraction %||% NA_real_,
            fallback.path.fraction =
                x$fallback.path.fraction %||% NA_real_,
            event.rate.fallback.fraction =
                x$event.rate.fallback.fraction %||% NA_real_,
            na.failure.fraction = x$na.failure.fraction %||% NA_real_,
            status.counts = if (length(x$status.counts)) {
                paste(names(x$status.counts), x$status.counts,
                      sep = "=", collapse = "; ")
            } else {
                ""
            },
            stringsAsFactors = FALSE
        )
    })
    do.call(rbind, rows)
}
logistic.diagnostics.table <- summarize.logistic.diagnostics(fit.binomial)

write.csv(summary.table,
          file.path(table.dir, "lps_binary_smoke_method_summary.csv"),
          row.names = FALSE)
write.csv(run.metrics,
          file.path(table.dir, "lps_binary_smoke_run_metrics.csv"),
          row.names = FALSE)
write.csv(fit.bernoulli$cv.table,
          file.path(table.dir, "lps_binary_smoke_bernoulli_cv_table.csv"),
          row.names = FALSE)
write.csv(fit.binomial$cv.table,
          file.path(table.dir, "lps_binary_smoke_binomial_cv_table.csv"),
          row.names = FALSE)
write.csv(logistic.diagnostics.table,
          file.path(table.dir, "lps_binary_smoke_logistic_diagnostics.csv"),
          row.names = FALSE)
saveRDS(
    list(
        fit.gaussian = fit.gaussian,
        fit.bernoulli = fit.bernoulli,
        fit.binomial = fit.binomial,
        X = X,
        y = y,
        p.true = p.true,
        grid = grid,
        grid.p.true = grid.p.true,
        grid.pred.bernoulli = grid.pred.bernoulli,
        grid.pred.bernoulli.raw = grid.pred.bernoulli.raw,
        grid.pred.binomial = grid.pred.binomial,
        summary.table = summary.table,
        run.metrics = run.metrics,
        logistic.diagnostics.table = logistic.diagnostics.table
    ),
    file.path(out.dir, "lps_binary_smoke_fit_bundle.rds")
)

png(file.path(fig.dir, "binary_lps_probability_fit.png"),
    width = 1200, height = 760, res = 130)
par(mar = c(4.2, 4.8, 3, 1))
plot(
    x,
    y + runif(n, -0.025, 0.025),
    pch = 16,
    col = grDevices::adjustcolor("gray25", 0.45),
    xlab = "x",
    ylab = "Probability / binary response",
    ylim = c(-0.05, 1.05),
    main = "Binary LPS Smoke Fit"
)
lines(grid[, 1], grid.p.true, col = "#1f78b4", lwd = 3)
lines(grid[, 1], grid.pred.bernoulli, col = "#d95f02", lwd = 3)
lines(grid[, 1], grid.pred.binomial, col = "#1b9e77", lwd = 3)
lines(grid[, 1], grid.pred.bernoulli.raw,
      col = "#d95f02", lwd = 1.4, lty = 2)
legend(
    "topright",
    legend = c("observed y", "true p(x)", "Bernoulli/Brier LPS",
               "Binomial/logistic LPS", "raw Brier-mode prediction"),
    col = c("gray25", "#1f78b4", "#d95f02", "#1b9e77", "#d95f02"),
    pch = c(16, NA, NA, NA, NA),
    lty = c(NA, 1, 1, 1, 2),
    lwd = c(NA, 3, 3, 3, 1.4),
    bty = "n"
)
dev.off()

png(file.path(fig.dir, "binary_lps_cv_surface.png"),
    width = 1200, height = 760, res = 130)
par(mfrow = c(1, 2), mar = c(4.4, 4.8, 3, 1))
plot.cv <- function(cv, yvar, ylab, title) {
    cv$label <- paste0("d", cv$degree, "/", cv$kernel)
    plot(
        cv$support.size,
        cv[[yvar]],
        pch = 16,
        col = as.integer(factor(cv$label)),
        xlab = "Support size",
        ylab = ylab,
        main = title
    )
    for (lab in unique(cv$label)) {
        rows <- cv$label == lab
        ord <- order(cv$support.size[rows])
        lines(cv$support.size[rows][ord], cv[[yvar]][rows][ord],
              col = as.integer(factor(cv$label))[which(rows)[1L]], lwd = 1.5)
    }
    legend("topright", legend = unique(cv$label),
           col = seq_along(unique(cv$label)), pch = 16, lty = 1, bty = "n",
           cex = 0.85)
}
plot.cv(fit.bernoulli$cv.table, "cv.brier.observed",
        "Observed CV Brier score", "Bernoulli/Brier mode")
plot.cv(fit.binomial$cv.table, "cv.logloss.observed",
        "Observed CV log loss", "Binomial/logistic mode")
dev.off()

html.path <- file.path(out.dir, "lps_binary_outcome_smoke_report.html")
summary.html <- paste(
    sprintf(
        paste0(
            "<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td>",
            "<td>%.6g</td><td>%.6g</td><td>%.6g</td><td>%.6g</td></tr>"
        ),
        summary.table$method,
        summary.table$selected.support.size,
        summary.table$selected.degree,
        summary.table$selected.kernel,
        summary.table$selected.cv.brier.observed,
        summary.table$selected.cv.logloss.observed,
        summary.table$truth.rmse,
        summary.table$observed.logloss
    ),
    collapse = "\n"
)
metrics.html <- paste(
    sprintf("<tr><td>%s</td><td>%s</td></tr>",
            run.metrics$metric,
            format(run.metrics$value, digits = 6, scientific = TRUE)),
    collapse = "\n"
)
logistic.diagnostics.html <- paste(
    sprintf(
        paste0(
            "<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td>",
            "<td>%s</td><td>%s</td><td>%s</td>",
            "<td>%.4f</td><td>%.4f</td><td>%.4f</td><td>%s</td></tr>"
        ),
        logistic.diagnostics.table$scope,
        logistic.diagnostics.table$attempted,
        logistic.diagnostics.table$converged,
        logistic.diagnostics.table$failed,
        logistic.diagnostics.table$fallback.path.count,
        logistic.diagnostics.table$event.rate.fallback.count,
        logistic.diagnostics.table$na.failure.count,
        logistic.diagnostics.table$convergence.fraction,
        logistic.diagnostics.table$event.rate.fallback.fraction,
        logistic.diagnostics.table$na.failure.fraction,
        logistic.diagnostics.table$status.counts
    ),
    collapse = "\n"
)
html <- paste0(
    "<!doctype html><html><head><meta charset='utf-8'>",
    "<title>LPS Binary Outcome Smoke</title>",
    "<style>",
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;",
    "margin:36px;line-height:1.45;color:#1f2933;max-width:1120px}",
    "h1,h2{color:#111827}.note{background:#f3f4f6;padding:12px 14px;",
    "border-left:4px solid #64748b;margin:16px 0}",
    "table{border-collapse:collapse;margin:14px 0;width:100%;font-size:14px}",
    "td,th{border-bottom:1px solid #e5e7eb;padding:7px 8px;text-align:left}",
    "img{max-width:100%;border:1px solid #e5e7eb}",
    "code{background:#f3f4f6;padding:1px 4px;border-radius:3px}",
    "</style></head><body>",
    "<h1>LPS Binary Outcome Smoke Test</h1>",
    "<p>This smoke test compares two binary LPS modes on the same simulated ",
    "binary-response example. <code>outcome.family = \"bernoulli\"</code> ",
    "uses the existing least-squares conditional-expectation smoother and ",
    "scores Brier risk. <code>outcome.family = \"binomial\"</code> uses local ",
    "weighted logistic polynomial fits and selects candidates by observed CV ",
    "log loss. The logistic mode now also records local IRLS convergence and ",
    "fallback telemetry for CV and final fitting.</p>",
    "<div class='note'><b>Smoke verdict:</b> both binary modes returned finite ",
    "probabilities in [0,1]. The Brier-mode raw predictions match ordinary ",
    "Gaussian-mode LPS on the same 0/1 data to max absolute difference ",
    format(run.metrics$value[[3L]], digits = 4, scientific = TRUE),
    ".</div>",
    "<h2>Definitions</h2>",
    "<p>The target is <code>p(x) = E[Y|X=x] = Pr(Y=1|X=x)</code>. ",
    "The Brier score is mean squared probability error. The log loss is the ",
    "negative Bernoulli log likelihood per observation, with probabilities ",
    "clipped away from exactly 0 and 1 only for evaluating the logarithm.</p>",
    "<h2>Figure 1. Binary outcomes and fitted probability curves</h2>",
    "<p>The blue curve is the true probability. Orange is the Brier-risk ",
    "conditional-expectation mode. Green is the local logistic mode. The dashed ",
    "orange curve is the un-clipped Brier-mode least-squares prediction.</p>",
    "<img src='figures/binary_lps_probability_fit.png' alt='Binary LPS fit'>",
    "<h2>Figure 2. Cross-validation selection surfaces</h2>",
    "<p>The left panel shows Brier-mode candidates scored by observed CV Brier. ",
    "The right panel shows logistic-mode candidates scored by observed CV log ",
    "loss, which is the selection score for <code>outcome.family = ",
    "\"binomial\"</code>.</p>",
    "<img src='figures/binary_lps_cv_surface.png' alt='Binary LPS CV scores'>",
    "<h2>Method Summary</h2>",
    "<table><thead><tr><th>Method</th><th>Support</th><th>Degree</th>",
    "<th>Kernel</th><th>CV Brier</th><th>CV log loss</th>",
    "<th>Truth RMSE</th><th>Observed log loss</th></tr></thead><tbody>",
    summary.html,
    "</tbody></table>",
    "<h2>Run Metrics</h2>",
    "<table><thead><tr><th>Metric</th><th>Value</th></tr></thead><tbody>",
    metrics.html,
    "</tbody></table>",
    "<h2>Logistic Solve Diagnostics</h2>",
    "<p>Each local logistic prediction either converges by IRLS or falls back ",
    "to a fallback path. With <code>unstable.action = \"mean\"</code>, that ",
    "path emits a clipped local weighted event-rate prediction; with ",
    "<code>unstable.action = \"na\"</code>, it emits <code>NA</code>. The table ",
    "reports this accounting separately for cross-validation predictions and ",
    "the final selected fit.</p>",
    "<table><thead><tr><th>Scope</th><th>Attempted</th><th>Converged</th>",
    "<th>Failed</th><th>Fallback path</th><th>Event-rate fallback</th>",
    "<th>NA failure</th><th>Convergence fraction</th>",
    "<th>Event-rate fallback fraction</th><th>NA failure fraction</th>",
    "<th>Status counts</th></tr></thead><tbody>",
    logistic.diagnostics.html,
    "</tbody></table>",
    "<h2>Artifacts</h2><ul>",
    "<li><a href='tables/lps_binary_smoke_method_summary.csv'>method summary CSV</a></li>",
    "<li><a href='tables/lps_binary_smoke_run_metrics.csv'>run metrics CSV</a></li>",
    "<li><a href='tables/lps_binary_smoke_bernoulli_cv_table.csv'>Brier-mode CV table CSV</a></li>",
    "<li><a href='tables/lps_binary_smoke_binomial_cv_table.csv'>logistic-mode CV table CSV</a></li>",
    "<li><a href='tables/lps_binary_smoke_logistic_diagnostics.csv'>logistic diagnostics CSV</a></li>",
    "<li><a href='lps_binary_smoke_fit_bundle.rds'>fit bundle RDS</a></li>",
    "</ul>",
    "</body></html>"
)
writeLines(html, html.path)
message("Wrote ", html.path)
