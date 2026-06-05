#!/usr/bin/env Rscript

if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("Package 'pkgload' is required for this smoke script.", call. = FALSE)
}

pkgload::load_all(".", quiet = TRUE)

out.dir <- file.path(getwd(), "split_handoffs")
out.csv <- file.path(
    out.dir,
    "harlim_second_order_lps_h4_smoke_results_2026-06-04.csv"
)

chart.dim <- 2L
support.grid <- c(12L, 18L)
degree.grid <- c(1L, 2L)
kernel.grid <- c("gaussian", "tricube")
cv.folds <- 3L
cv.seed <- 604L
noise.sd <- 0.02
tie.tolerance <- 1e-8

rmse <- function(x, y) {
    sqrt(mean((as.numeric(x) - as.numeric(y))^2, na.rm = TRUE))
}

orthonormal.embedding <- function(ambient.dim = 20L, seed = 90210L) {
    set.seed(seed)
    qr.Q(qr(matrix(stats::rnorm(ambient.dim * 3L), ambient.dim, 3L)))
}

grid.uv <- function(side = 7L, radius = 1) {
    grid <- expand.grid(
        u = seq(-radius, radius, length.out = side),
        v = seq(-radius, radius, length.out = side)
    )
    as.matrix(grid)
}

scenario.data <- function(scenario, Q20 = NULL) {
    uv <- grid.uv()
    u <- uv[, 1L]
    v <- uv[, 2L]
    z <- switch(
        scenario,
        flat = rep(0, length(u)),
        paraboloid = 0.75 * u^2 + 0.35 * v^2,
        saddle = 0.75 * u^2 - 0.35 * v^2,
        high_dim_embedding = 0.75 * u^2 + 0.35 * v^2,
        stop("Unknown scenario: ", scenario, call. = FALSE)
    )
    X.base <- cbind(u, v, z)
    X <- if (identical(scenario, "high_dim_embedding")) {
        X.base %*% t(Q20)
    } else {
        X.base
    }
    truth <- switch(
        scenario,
        flat = sin(1.2 * u) + 0.4 * v,
        paraboloid = sin(u) + 0.5 * v + 0.15 * u * v,
        saddle = cos(0.8 * u) - sin(0.7 * v) + 0.2 * u^2,
        high_dim_embedding = sin(u) + 0.5 * v + 0.15 * u * v
    )
    set.seed(1000L + match(
        scenario,
        c("flat", "paraboloid", "saddle", "high_dim_embedding")
    ))
    observed <- truth + stats::rnorm(length(truth), sd = noise.sd)
    list(X = X, truth = truth, observed = observed)
}

fit.lps.method <- function(X, y, method) {
    fit <- NULL
    elapsed <- system.time({
        fit <- fit.lps(
            X, y,
            support.grid = support.grid,
            degree.grid = degree.grid,
            kernel.grid = kernel.grid,
            cv.folds = cv.folds,
            cv.seed = cv.seed,
            coordinate.method = "local.pca",
            chart.dim = chart.dim,
            local.chart.method = method,
            backend = "R"
        )
    })[["elapsed"]]
    list(fit = fit, elapsed.sec = as.numeric(elapsed))
}

fallback.reasons.text <- function(summary) {
    reasons <- summary$fallback.reasons
    if (is.null(reasons) || !nrow(reasons)) return("")
    paste(
        paste0(reasons$fallback.reason, ":", reasons$count),
        collapse = ";"
    )
}

selected.value <- function(fit, name) {
    fit$selected[[name]][[1L]]
}

evaluate.scenario <- function(scenario, Q20) {
    dat <- scenario.data(scenario, Q20)
    pca <- fit.lps.method(dat$X, dat$observed, "pca")
    second <- fit.lps.method(dat$X, dat$observed, "second.order.svd")
    pca.fit <- pca$fit
    second.fit <- second$fit
    summary <- second.fit$local.chart.diagnostics.summary

    pca.rmse.truth <- rmse(pca.fit$fitted.values, dat$truth)
    second.rmse.truth <- rmse(second.fit$fitted.values, dat$truth)
    pca.rmse.observed <- rmse(pca.fit$fitted.values, dat$observed)
    second.rmse.observed <- rmse(second.fit$fitted.values, dat$observed)
    delta.truth <- second.rmse.truth - pca.rmse.truth
    outcome <- if (delta.truth < -tie.tolerance) {
        "better"
    } else if (delta.truth > tie.tolerance) {
        "worse"
    } else {
        "tied"
    }

    data.frame(
        scenario = scenario,
        n = nrow(dat$X),
        ambient.dim = ncol(dat$X),
        chart.dim = chart.dim,
        support.grid = paste(support.grid, collapse = ";"),
        degree.grid = paste(degree.grid, collapse = ";"),
        kernel.grid = paste(kernel.grid, collapse = ";"),
        cv.folds = cv.folds,
        cv.seed = cv.seed,
        noise.sd = noise.sd,
        pca.rmse.truth = pca.rmse.truth,
        second.rmse.truth = second.rmse.truth,
        delta.rmse.truth = delta.truth,
        pca.rmse.observed = pca.rmse.observed,
        second.rmse.observed = second.rmse.observed,
        delta.rmse.observed = second.rmse.observed - pca.rmse.observed,
        outcome.truth = outcome,
        pca.selected.support = selected.value(pca.fit, "support.size"),
        pca.selected.degree = selected.value(pca.fit, "degree"),
        pca.selected.kernel = selected.value(pca.fit, "kernel"),
        pca.selected.chart.dim = selected.value(pca.fit, "chart.dim"),
        second.selected.support = selected.value(second.fit, "support.size"),
        second.selected.degree = selected.value(second.fit, "degree"),
        second.selected.kernel = selected.value(second.fit, "kernel"),
        second.selected.chart.dim = selected.value(second.fit, "chart.dim"),
        pca.elapsed.sec = pca$elapsed.sec,
        second.elapsed.sec = second$elapsed.sec,
        second.fallback.count = summary$fallback.count,
        second.fallback.rate = summary$fallback.rate,
        second.fallback.reasons = fallback.reasons.text(summary),
        second.any.pca.fallback.used = summary$any.pca.fallback.used,
        second.any.structured.failure = summary$any.structured.failure,
        second.min.design.rank = summary$min.design.rank,
        second.median.design.rank = summary$median.design.rank,
        second.max.design.rank = summary$max.design.rank,
        second.median.design.condition = summary$median.design.condition,
        second.max.design.condition = summary$max.design.condition,
        caution = paste(
            "H2/H3 smoke showed second-order local SVD can be worse",
            "on small or ill-conditioned supports; this H4 path is opt-in."
        ),
        stringsAsFactors = FALSE
    )
}

Q20 <- orthonormal.embedding(20L)
scenarios <- c("flat", "paraboloid", "saddle", "high_dim_embedding")
results <- do.call(rbind, lapply(scenarios, evaluate.scenario, Q20 = Q20))

utils::write.csv(results, out.csv, row.names = FALSE)

cat("Wrote:", out.csv, "\n")
cat("Rows:", nrow(results), "\n")
cat(
    "Caution: H2/H3 smoke showed second-order local SVD can be worse ",
    "on small or ill-conditioned supports; this H4 path is opt-in.\n",
    sep = ""
)
cat("Outcome counts by truth RMSE:\n")
print(table(results$outcome.truth))
cat("Median truth RMSE delta (second - PCA):",
    stats::median(results$delta.rmse.truth), "\n")
cat("Worst truth RMSE delta (second - PCA):",
    max(results$delta.rmse.truth), "\n")
cat("Fallback rates:\n")
print(results[, c("scenario", "second.fallback.rate",
                  "second.fallback.reasons")], row.names = FALSE)

invisible(results)
