make.od3.path.graph <- function(n) {
    adj <- vector("list", n)
    wt <- vector("list", n)
    for (i in seq_len(n - 1L)) {
        j <- i + 1L
        adj[[i]] <- c(adj[[i]], j)
        wt[[i]] <- c(wt[[i]], 1)
        adj[[j]] <- c(adj[[j]], i)
        wt[[j]] <- c(wt[[j]], 1)
    }
    list(
        adj.list = lapply(adj, as.integer),
        weight.list = lapply(wt, as.double)
    )
}

test_that("OD3 fit.chart.kernel returns a finite fitted field", {
    X <- matrix(seq(0, 1, length.out = 21), ncol = 1L)
    y <- c(rep(0, 5), 0.2, 0.5, 1, 0.4, rep(0, 12))

    fit <- fit.chart.kernel(
        X = X,
        y = y,
        support.size = 7L,
        kernel = "gaussian",
        coordinate.method = "coordinates"
    )

    expect_s3_class(fit, "chart_kernel")
    expect_identical(fit$method.id, "chart_kernel")
    expect_length(fit$fitted.values, nrow(X))
    expect_true(all(is.finite(fit$fitted.values)))
    expect_true(all(fit$fitted.values >= 0))
    expect_identical(fit$selected$support.size, 7L)
    expect_identical(fit$selected$kernel, "gaussian")
    expect_identical(fit$diagnostics$denominator.floor.count, 0L)
    expect_true(is.data.frame(fit$diagnostics$per.eval))
})

test_that("OD3 chart-kernel fit normalizes through density accounting", {
    X <- matrix(seq(0, 1, length.out = 25), ncol = 1L)
    subject.index <- c(3L, 5L, 8L, 8L, 14L, 21L, 24L)
    weights <- tabulate(subject.index, nbins = nrow(X))
    empirical <- weights / sum(weights)
    graph <- make.od3.path.graph(nrow(X))

    fit <- fit.chart.kernel(
        X = X,
        y = empirical,
        support.size = 9L,
        kernel = "tricube",
        coordinate.method = "coordinates"
    )
    fit$empirical.rho <- empirical
    density <- normalize.density(
        fit,
        X = X,
        adj.list = graph$adj.list,
        keep.source.fit = FALSE
    )

    expect_s3_class(density, "density_fit")
    expect_identical(density$status, "ok")
    expect_identical(density$method.id, "normalized_chart_kernel")
    expect_equal(sum(density$rho), 1, tolerance = 1e-12)
    expect_true(all(density$rho >= -1e-12))
    expect_equal(density$empirical.rho, empirical, tolerance = 1e-12)
    expect_true(is.finite(density$smoothness$n.local.maxima))
    expect_identical(density$diagnostics$source.class, "chart_kernel")
})

test_that("OD3 subject wrapper dispatches chart_kernel workflow", {
    n <- 28L
    X <- cbind(seq(0, 1, length.out = n),
               sin(seq(0, 2 * pi, length.out = n)))
    subject.index <- c(2L, 4L, 7L, 13L, 13L, 18L, 24L, 27L)
    graph <- make.od3.path.graph(n)

    fit <- fit.subject.od(
        X = X,
        subject.index = subject.index,
        method = "chart_kernel",
        graph = graph,
        support.size = 9L,
        kernel = "gaussian",
        coordinate.method = "local.pca",
        chart.dim = 1L
    )

    expect_s3_class(fit, "density_fit")
    expect_identical(fit$status, "ok")
    expect_identical(fit$method.id, "chart_kernel")
    expect_equal(sum(fit$rho), 1, tolerance = 1e-12)
    expect_equal(fit$empirical.rho, tabulate(subject.index, nbins = n) /
                     length(subject.index), tolerance = 1e-12)
    expect_identical(fit$diagnostics$source.method, "fit.chart.kernel")
    expect_identical(fit$diagnostics$response.summary$type,
                     "normalized_count_mass")
    expect_identical(fit$diagnostics$selection$coordinate.method, "local.pca")
    expect_true(is.finite(fit$smoothness$n.local.maxima))
    expect_equal(fit$subject$max.multiplicity, 2)
})

test_that("OD3 chart-kernel validates density-relevant inputs", {
    X <- cbind(seq(0, 1, length.out = 6), 0)

    expect_error(
        fit.chart.kernel(X = X, y = c(1, 2, 3)),
        "length nrow"
    )
    expect_error(
        fit.chart.kernel(X = X, y = rep(1, 6), quadrature.weights = rep(0, 6)),
        "positive finite"
    )
    expect_error(
        fit.subject.od(
            X = X,
            subject.index = c(1L, 3L),
            method = "chart_kernel",
            y = rep(0, nrow(X))
        ),
        "reserved argument"
    )
})

test_that("OD3 local-likelihood density returns finite nonnegative values", {
    X <- matrix(seq(0, 1, length.out = 31), ncol = 1L)
    y <- dnorm(X[, 1], mean = 0.45, sd = 0.14)
    y <- y / sum(y)

    fit <- fit.local.likelihood(
        X = X,
        y = y,
        likelihood.family = "density",
        support.size = 11L,
        degree = 1L,
        kernel = "gaussian",
        coordinate.method = "coordinates",
        optimizer = "optim"
    )

    expect_s3_class(fit, "local_likelihood")
    expect_identical(fit$method.id, "local_likelihood")
    expect_identical(fit$likelihood.family, "density")
    expect_length(fit$fitted.values, nrow(X))
    expect_true(all(is.finite(fit$fitted.values)))
    expect_true(all(fit$fitted.values >= 0))
    expect_true(is.data.frame(fit$diagnostics$per.eval))
    expect_equal(fit$diagnostics$fallback.fraction, 0, tolerance = 1e-12)
})

test_that("OD3 local-likelihood density normalizes through density accounting", {
    X <- matrix(seq(0, 1, length.out = 27), ncol = 1L)
    subject.index <- c(4L, 8L, 8L, 12L, 17L, 21L, 24L)
    empirical <- tabulate(subject.index, nbins = nrow(X)) / length(subject.index)
    graph <- make.od3.path.graph(nrow(X))

    fit <- fit.local.likelihood(
        X = X,
        y = empirical,
        likelihood.family = "density",
        support.size = 9L,
        degree = 0L,
        kernel = "tricube",
        coordinate.method = "coordinates"
    )
    fit$empirical.rho <- empirical
    density <- normalize.density(
        fit,
        X = X,
        adj.list = graph$adj.list,
        keep.source.fit = FALSE
    )

    expect_s3_class(density, "density_fit")
    expect_identical(density$status, "ok")
    expect_identical(density$method.id, "normalized_local_likelihood")
    expect_equal(sum(density$rho), 1, tolerance = 1e-12)
    expect_true(all(is.finite(density$rho)))
    expect_true(all(density$rho >= -1e-12))
    expect_equal(density$empirical.rho, empirical, tolerance = 1e-12)
    expect_true(is.finite(density$smoothness$n.local.maxima))
    expect_identical(density$diagnostics$source.class, "local_likelihood")
})

test_that("OD3 local-likelihood supports local PCA charts in dimension greater than one", {
    theta <- seq(0, 2 * pi, length.out = 36)
    X <- cbind(cos(theta), sin(theta), 0.15 * cos(2 * theta))
    y <- exp(-8 * (sin(theta) - 0.2)^2)
    y <- y / sum(y)

    fit <- fit.local.likelihood(
        X = X,
        y = y,
        likelihood.family = "density",
        support.size = 9L,
        degree = 1L,
        kernel = "gaussian",
        coordinate.method = "local.pca",
        chart.dim = 2L,
        optimizer = "optim"
    )

    expect_s3_class(fit, "local_likelihood")
    expect_true(all(is.finite(fit$fitted.values)))
    expect_true(all(fit$fitted.values >= 0))
    expect_true(all(fit$diagnostics$per.eval$chart.dim == 2L))
})

test_that("OD3 local-likelihood surfaces sparse-mass fallbacks", {
    X <- matrix(seq(0, 1, length.out = 30), ncol = 1L)
    y <- numeric(nrow(X))
    y[seq_len(3L)] <- c(0.3, 0.4, 0.3)

    fit <- fit.local.likelihood(
        X = X,
        y = y,
        likelihood.family = "density",
        support.size = 5L,
        degree = 1L,
        kernel = "tricube",
        coordinate.method = "coordinates",
        min.local.mass = sqrt(.Machine$double.eps)
    )

    expect_true(any(fit$diagnostics$per.eval$status == "zero_mass_fallback"))
    expect_true(all(is.finite(fit$fitted.values)))
    expect_true(all(fit$fitted.values >= 0))
    expect_gt(fit$diagnostics$fallback.count, 0)
})

test_that("OD3 local-likelihood reserves Bernoulli branch explicitly", {
    X <- matrix(seq(0, 1, length.out = 10), ncol = 1L)
    y <- rep(c(0, 1), length.out = nrow(X))

    expect_error(
        fit.local.likelihood(
            X = X,
            y = y,
            likelihood.family = "bernoulli"
        ),
        "reserved but not implemented"
    )
})
