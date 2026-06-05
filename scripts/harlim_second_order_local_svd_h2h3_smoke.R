#!/usr/bin/env Rscript

if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("Package 'pkgload' is required for this smoke script.", call. = FALSE)
}

pkgload::load_all(".", quiet = TRUE)

out.dir <- file.path(getwd(), "split_handoffs")
out.csv <- file.path(
    out.dir,
    "harlim_second_order_local_svd_h2h3_smoke_results_2026-06-04.csv"
)

rank.tolerance <- sqrt(.Machine$double.eps)
rank.absolute.tolerance <- 0
curvature.condition.max <- 1e8
center.mode <- "anchor"
chart.dim <- 2L

projector <- function(basis) {
    basis %*% t(basis)
}

projector.error <- function(basis, oracle) {
    if (is.null(basis) || any(!is.finite(basis))) return(NA_real_)
    sqrt(sum((projector(basis) - projector(oracle))^2))
}

orthonormal.embedding <- function(ambient.dim = 20L, seed = 90210L) {
    set.seed(seed)
    qr.Q(qr(matrix(stats::rnorm(ambient.dim * 3L), ambient.dim, 3L)))
}

embed.base <- function(base, high.dim = FALSE, Q = NULL) {
    if (!high.dim) return(base)
    base %*% t(Q)
}

make.uv <- function(kind, n, radius, seed, line.noise = NULL) {
    if (identical(kind, "symmetric")) {
        side <- ceiling(sqrt(n))
        grid <- expand.grid(
            u = seq(-radius, radius, length.out = side),
            v = seq(-radius, radius, length.out = side)
        )
        uv <- as.matrix(grid[seq_len(n), , drop = FALSE])
        uv[1L, ] <- 0
        return(uv)
    }

    set.seed(seed)
    if (identical(kind, "near.line")) {
        u <- c(0, stats::runif(n - 1L, -radius, radius))
        v <- c(0, line.noise * stats::runif(n - 1L, -radius, radius))
        return(cbind(u, v))
    }

    if (identical(kind, "asymmetric")) {
        u <- c(0, stats::runif(n - 1L, -0.25 * radius, radius))
        v <- c(0, stats::runif(n - 1L, -radius, 0.55 * radius))
        return(cbind(u, v))
    }

    stop("Unknown support kind: ", kind, call. = FALSE)
}

make.base.geometry <- function(uv, geometry) {
    u <- uv[, 1L]
    v <- uv[, 2L]
    z <- switch(
        geometry,
        flat = rep(0, length(u)),
        paraboloid = 0.75 * u^2 + 0.35 * v^2,
        saddle = 0.75 * u^2 - 0.35 * v^2,
        stop("Unknown geometry: ", geometry, call. = FALSE)
    )
    cbind(u, v, z)
}

make.weights <- function(n, weight.mode) {
    if (identical(weight.mode, "none")) return(NULL)
    if (identical(weight.mode, "zero.rows")) {
        w <- rep(1, n)
        if (n > 4L) {
            zero.ids <- unique(as.integer(round(seq(2, n, length.out = 4L))))
            w[zero.ids] <- 0
        }
        return(w)
    }
    stop("Unknown weight mode: ", weight.mode, call. = FALSE)
}

evaluate.case <- function(study, geometry, support.kind, n.support,
                          high.dim = FALSE, weight.mode = "none",
                          seed = 1L, radius = 0.5,
                          line.noise = NA_real_, Q = NULL) {
    uv <- make.uv(
        kind = support.kind,
        n = n.support,
        radius = radius,
        seed = seed,
        line.noise = if (is.na(line.noise)) NULL else line.noise
    )
    X.base <- make.base.geometry(uv, geometry)
    X <- embed.base(X.base, high.dim = high.dim, Q = Q)
    center <- rep(0, ncol(X))
    oracle <- if (high.dim) Q[, 1:2, drop = FALSE] else diag(3)[, 1:2]
    weights <- make.weights(nrow(X), weight.mode)

    pca <- NULL
    pca.error.message <- NA_character_
    pca.feasible <- chart.dim <= min(nrow(X), ncol(X))
    pca.elapsed <- NA_real_
    if (pca.feasible) {
        pca.elapsed <- system.time({
            pca <- tryCatch(
                rcpp_local_pca_chart(
                    X_support = X,
                    center = center,
                    chart_dim = chart.dim,
                    center_mode = center.mode,
                    dim_rule = "fixed",
                    weights = weights
                ),
                error = function(e) {
                    pca.error.message <<- conditionMessage(e)
                    NULL
                }
            )
        })[["elapsed"]]
    } else {
        pca.error.message <- "plain_pca_comparator_not_feasible"
    }
    pca.projector.error <- if (is.null(pca)) {
        NA_real_
    } else {
        projector.error(pca$basis, oracle)
    }

    second <- NULL
    second.elapsed <- system.time({
        second <- rcpp_local_second_order_svd_chart(
            X_support = X,
            center = center,
            chart_dim = chart.dim,
            center_mode = center.mode,
            weights = weights,
            rank_tolerance = rank.tolerance,
            rank_absolute_tolerance = rank.absolute.tolerance,
            curvature_condition_max = curvature.condition.max
        )
    })[["elapsed"]]
    diag <- second$curvature.diagnostics
    second.projector.error <- projector.error(second$basis, oracle)

    data.frame(
        study = study,
        geometry = geometry,
        support.kind = support.kind,
        ambient.dim = ncol(X),
        support.size = nrow(X),
        high.dim = high.dim,
        weight.mode = weight.mode,
        seed = seed,
        radius = radius,
        line.noise = line.noise,
        center.mode = center.mode,
        chart.dim = chart.dim,
        rank.tolerance = rank.tolerance,
        rank.absolute.tolerance = rank.absolute.tolerance,
        curvature.condition.max = curvature.condition.max,
        pca.projector.error = pca.projector.error,
        second.projector.error = second.projector.error,
        projector.error.delta = pca.projector.error - second.projector.error,
        pca.elapsed.sec = as.numeric(pca.elapsed),
        second.elapsed.sec = as.numeric(second.elapsed),
        fallback.used = isTRUE(second$fallback.used),
        fallback.reason = second$fallback.reason,
        primary.failure.reason = second$primary.failure.reason,
        plain.pca.fallback.feasible = diag$plain.pca.fallback.feasible,
        effective.support = diag$effective.support,
        design.rank = diag$design.rank,
        quadratic.ncol = diag$quadratic.ncol,
        design.condition = diag$design.condition,
        first.rank = diag$first.rank,
        second.rank = diag$second.rank,
        fit.method = diag$fit.method,
        fit.residual.frobenius = diag$fit.residual.frobenius,
        curvature.fitted.frobenius = diag$curvature.fitted.frobenius,
        corrected.residual.frobenius = diag$corrected.residual.frobenius,
        pca.error.message = pca.error.message,
        stringsAsFactors = FALSE
    )
}

Q20 <- orthonormal.embedding(20L)

base.cases <- expand.grid(
    geometry = c("flat", "paraboloid", "saddle"),
    support.kind = c("symmetric", "asymmetric"),
    high.dim = c(FALSE, TRUE),
    stringsAsFactors = FALSE
)

rows <- list()
ii <- 1L
for (rr in seq_len(nrow(base.cases))) {
    rows[[ii]] <- evaluate.case(
        study = "base",
        geometry = base.cases$geometry[[rr]],
        support.kind = base.cases$support.kind[[rr]],
        n.support = 25L,
        high.dim = base.cases$high.dim[[rr]],
        weight.mode = "none",
        seed = 100L + rr,
        Q = Q20
    )
    ii <- ii + 1L
}

for (geometry in c("flat", "paraboloid", "saddle")) {
    rows[[ii]] <- evaluate.case(
        study = "weighted_zero_rows",
        geometry = geometry,
        support.kind = "asymmetric",
        n.support = 25L,
        high.dim = FALSE,
        weight.mode = "zero.rows",
        seed = 300L + ii,
        Q = Q20
    )
    ii <- ii + 1L
}

for (n.support in c(1L, 2L, 3L, 4L, 6L, 10L, 25L)) {
    for (seed in 1:5) {
        rows[[ii]] <- evaluate.case(
            study = "support_sweep",
            geometry = "paraboloid",
            support.kind = "asymmetric",
            n.support = n.support,
            high.dim = FALSE,
            weight.mode = "none",
            seed = 500L + 10L * n.support + seed,
            Q = Q20
        )
        ii <- ii + 1L
    }
}

for (line.noise in c(1, 1e-1, 1e-2, 1e-4, 1e-6)) {
    rows[[ii]] <- evaluate.case(
        study = "conditioning",
        geometry = "paraboloid",
        support.kind = "near.line",
        n.support = 25L,
        high.dim = FALSE,
        weight.mode = "none",
        seed = 800L + ii,
        line.noise = line.noise,
        Q = Q20
    )
    ii <- ii + 1L
}

results <- do.call(rbind, rows)
utils::write.csv(results, out.csv, row.names = FALSE)

summary.by.study <- aggregate(
    cbind(
        pca.projector.error,
        second.projector.error,
        projector.error.delta,
        second.elapsed.sec
    ) ~ study,
    data = results,
    FUN = function(x) stats::median(x, na.rm = TRUE)
)
fallback.by.study <- aggregate(
    fallback.used ~ study,
    data = results,
    FUN = function(x) mean(x, na.rm = TRUE)
)

cat("Wrote:", out.csv, "\n")
cat("Rows:", nrow(results), "\n")
cat("Fallback rate by study:\n")
print(fallback.by.study, row.names = FALSE)
cat("Median metrics by study:\n")
print(summary.by.study, row.names = FALSE)

invisible(results)
