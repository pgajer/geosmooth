test_that("GE7 fit.lps is the canonical LPS entry point", {
    X <- matrix(seq(0, 1, length.out = 24), ncol = 1L)
    y <- sin(2 * pi * X[, 1])
    foldid <- rep(1:3, length.out = nrow(X))

    fit <- fit.lps(
        X = X,
        y = y,
        foldid = foldid,
        support.grid = c(6L, 8L),
        degree.grid = 0:1,
        kernel.grid = "gaussian",
        backend = "R"
    )

    expect_s3_class(fit, "lps")
    expect_identical(class(fit)[[1L]], "lps")
    expect_false(inherits(fit, "kernel.local.polynomial.cv"))
    expect_identical(fit$method.id, "lps")
    expect_identical(fit$method.label, "LPS")
    expect_identical(fit$method.family, "local_polynomial_smoother")
    expect_equal(length(predict(fit, X[1:4, , drop = FALSE])), 4L)
    expect_match(capture.output(print(fit))[[1L]], "LPS")
})

test_that("GE8 removes the old kernel.local.polynomial.cv API", {
    expect_false(exists(
        "kernel.local.polynomial.cv",
        envir = asNamespace("geosmooth"),
        inherits = FALSE
    ))
    expect_false(exists(
        "predict.kernel.local.polynomial.cv",
        envir = asNamespace("geosmooth"),
        inherits = FALSE
    ))
    expect_false(exists(
        "print.kernel.local.polynomial.cv",
        envir = asNamespace("geosmooth"),
        inherits = FALSE
    ))
})

test_that("K4 local-PCA LPS C++ backend matches R reference path", {
    set.seed(41)
    t <- seq(0, 1, length.out = 36)
    X <- cbind(t, t^2, sin(2 * pi * t))
    y <- sin(3 * pi * t) + 0.15 * cos(7 * pi * t)
    foldid <- rep(1:4, length.out = nrow(X))

    common.args <- list(
        X = X,
        y = y,
        foldid = foldid,
        support.grid = c(12L, 14L),
        degree.grid = 0:2,
        kernel.grid = c("gaussian", "tricube"),
        coordinate.method = "local.pca",
        local.chart.method = "pca",
        chart.dim = 2L
    )

    fit.r <- do.call(fit.lps, c(common.args, list(backend = "R")))
    fit.cpp <- do.call(fit.lps, c(common.args, list(backend = "cpp.local.pca")))

    expect_equal(fit.cpp$backend.used, "cpp.local.pca")
    expect_equal(
        fit.cpp$cv.table$cv.rmse.observed,
        fit.r$cv.table$cv.rmse.observed,
        tolerance = 1e-8
    )
    expect_equal(fit.cpp$selected, fit.r$selected, tolerance = 1e-8)
    expect_equal(fit.cpp$fitted.values, fit.r$fitted.values, tolerance = 1e-8)

    newdata <- X[c(3L, 11L, 23L), , drop = FALSE]
    expect_equal(
        predict(fit.cpp, newdata),
        predict(fit.r, newdata),
        tolerance = 1e-8
    )
})

test_that("K4 local-PCA C++ backend is explicit and narrow", {
    X <- matrix(seq(0, 1, length.out = 20), ncol = 1L)
    y <- X[, 1]^2
    foldid <- rep(1:2, length.out = nrow(X))

    expect_error(
        fit.lps(
            X,
            y,
            foldid = foldid,
            coordinate.method = "coordinates",
            backend = "cpp.local.pca"
        ),
        "requires coordinate.method = 'local.pca'"
    )
    expect_error(
        fit.lps(
            X,
            y,
            foldid = foldid,
            coordinate.method = "local.pca",
            local.chart.method = "second.order.svd",
            chart.dim = 1L,
            backend = "cpp.local.pca"
        ),
        "requires coordinate.method = 'local.pca'"
    )

    fit.auto <- fit.lps(
        X,
        y,
        foldid = foldid,
        coordinate.method = "local.pca",
        chart.dim = 1L,
        backend = "auto"
    )
    expect_equal(fit.auto$backend.used, "R")
})

test_that("K4 local-PCA C++ backend uses R-compatible tie-stable supports", {
    compare.backends <- function(X, y, foldid, support.grid,
                                 degree.grid, kernel.grid) {
        common.args <- list(
            X = X,
            y = y,
            foldid = foldid,
            support.grid = support.grid,
            degree.grid = degree.grid,
            kernel.grid = kernel.grid,
            coordinate.method = "local.pca",
            local.chart.method = "pca",
            chart.dim = 2L
        )
        fit.r <- do.call(fit.lps, c(common.args, list(backend = "R")))
        fit.cpp <- do.call(
            fit.lps,
            c(common.args, list(backend = "cpp.local.pca"))
        )
        expect_equal(
            fit.cpp$cv.table$cv.rmse.observed,
            fit.r$cv.table$cv.rmse.observed,
            tolerance = 1e-8
        )
        expect_equal(fit.cpp$selected, fit.r$selected, tolerance = 1e-8)
        expect_equal(fit.cpp$fitted.values, fit.r$fitted.values,
                     tolerance = 1e-8)
    }

    uv <- as.matrix(expand.grid(
        u = seq(-1, 1, length.out = 5),
        v = seq(-1, 1, length.out = 5)
    ))
    X.grid <- cbind(uv[, 1], uv[, 2], uv[, 1] + 2 * uv[, 2])
    y.grid <- uv[, 1]^2 - uv[, 2] + 0.25 * uv[, 1] * uv[, 2]
    compare.backends(
        X = X.grid,
        y = y.grid,
        foldid = rep(1:5, length.out = nrow(X.grid)),
        support.grid = c(10L, 12L),
        degree.grid = 2L,
        kernel.grid = c("gaussian", "tricube")
    )

    base <- as.matrix(expand.grid(u = 0:2, v = 0:1))
    uv.dup <- base[rep(seq_len(nrow(base)), each = 2L), , drop = FALSE]
    X.dup <- cbind(uv.dup[, 1], uv.dup[, 2], uv.dup[, 1] - uv.dup[, 2])
    y.dup <- 0.2 * seq_len(nrow(X.dup)) + uv.dup[, 1] - 0.5 * uv.dup[, 2]
    compare.backends(
        X = X.dup,
        y = y.dup,
        foldid = rep(1:3, length.out = nrow(X.dup)),
        support.grid = c(6L, 8L),
        degree.grid = 1:2,
        kernel.grid = c("gaussian", "tricube")
    )
})

test_that("K4 native neighbor probe repairs raw ANN tie order", {
    check.probe <- function(X, center, k) {
        probe <- geosmooth:::rcpp_kernel_local_polynomial_neighbor_probe(
            X = X,
            center = center,
            k = k
        )
        d <- rowSums((X - matrix(center, nrow(X), ncol(X), byrow = TRUE))^2)
        reference <- order(d, seq_along(d))[seq_len(k)]

        expect_equal(probe$reference.row, reference)
        expect_equal(probe$tie.complete.row, reference)
        expect_equal(probe$tie.complete.squared.distance, d[reference])
        expect_length(probe$raw.row, k)
        expect_length(probe$raw.squared.distance, k)
    }

    cardinal <- matrix(c(
        -1, 0,
         1, 0,
         0, -1,
         0, 1
    ), ncol = 2, byrow = TRUE)
    check.probe(cardinal, center = c(0, 0), k = 2L)

    duplicated <- rbind(
        c(0, 0), c(0, 0),
        c(1, 0), c(1, 0),
        c(2, 0), c(2, 0)
    )
    check.probe(duplicated, center = c(1, 0), k = 3L)

    grid <- as.matrix(expand.grid(u = -1:1, v = -1:1))
    check.probe(grid, center = c(0, 0), k = 4L)
})

test_that("K12 LPS backend diagnostics expose conservative backend policy", {
    X <- matrix(seq(0, 1, length.out = 24), ncol = 1L)
    y <- sin(2 * pi * X[, 1])
    foldid <- rep(1:4, length.out = nrow(X))

    ambient <- fit.lps(
        X = X,
        y = y,
        foldid = foldid,
        support.grid = c(6L, 8L),
        degree.grid = 0:1,
        kernel.grid = "gaussian",
        coordinate.method = "coordinates",
        backend = "auto"
    )
    ambient.diag <- lps.backend.diagnostics(ambient)

    expect_s3_class(ambient.diag, "data.frame")
    expect_equal(nrow(ambient.diag), 1L)
    expect_equal(ambient.diag$backend.requested, "auto")
    expect_equal(ambient.diag$backend.used, "cpp")
    expect_equal(ambient.diag$backend.auto.policy, "auto_coordinates_cpp")
    expect_equal(ambient.diag$requested.chart.dim, "NULL")
    expect_equal(ambient.diag$resolved.chart.dim, ncol(X))
    expect_false(ambient.diag$chart.dim.auto)
    expect_false(ambient.diag$local.pca.real.data.contract)
    expect_equal(ambient.diag$candidate.count, nrow(ambient$cv.table))
})

test_that("K12 local-PCA diagnostics record auto-dimension contract", {
    t <- seq(0, 1, length.out = 32)
    X <- cbind(t, t^2, sin(2 * pi * t))
    y <- cos(2 * pi * t)
    foldid <- rep(1:4, length.out = nrow(X))

    fit <- fit.lps(
        X = X,
        y = y,
        foldid = foldid,
        support.grid = c(10L, 12L),
        degree.grid = 1L,
        kernel.grid = "tricube",
        coordinate.method = "local.pca",
        chart.dim = "auto",
        auto.chart.support.metric = "both",
        auto.chart.selection.metric = "operator",
        backend = "auto"
    )
    diag <- lps.backend.diagnostics(fit)

    expect_equal(diag$backend.requested, "auto")
    expect_equal(diag$backend.used, "R")
    expect_equal(diag$backend.auto.policy, "auto_local_pca_R_reference")
    expect_equal(diag$requested.chart.dim, "auto")
    expect_true(diag$chart.dim.auto)
    expect_equal(diag$auto.chart.support.metric, "both")
    expect_equal(diag$auto.chart.selection.metric, "operator")
    expect_equal(diag$auto.chart.support.metric.selected, "coordinates")
    expect_true(is.finite(diag$resolved.chart.dim))
    expect_true(diag$local.pca.real.data.contract)
})

test_that("LPS supports opt-in per-anchor local auto chart dimensions", {
    t <- seq(0, 1, length.out = 40)
    X <- cbind(t, t^2, sin(2 * pi * t), 0.02 * cos(5 * pi * t))
    y <- sin(3 * pi * t)
    foldid <- rep(1:4, length.out = nrow(X))

    fit <- fit.lps(
        X = X,
        y = y,
        foldid = foldid,
        support.grid = c(10L, 14L),
        degree.grid = 1:2,
        kernel.grid = "gaussian",
        coordinate.method = "local.pca",
        chart.dim = "local.auto",
        auto.chart.support.metric = "both",
        auto.chart.selection.metric = "operator",
        backend = "auto"
    )
    diag <- lps.backend.diagnostics(fit)

    expect_s3_class(fit, "lps")
    expect_equal(fit$backend.used, "R")
    expect_true(fit$auto.chart.dim)
    expect_true(fit$auto.chart.dim.local)
    expect_equal(fit$chart.dim.mode, "local.auto")
    expect_length(fit$chart.dim.by.eval, nrow(X))
    expect_true(all(fit$chart.dim.by.eval >= 1L))
    expect_true(all(fit$chart.dim.by.eval <= ncol(X)))
    expect_true(is.finite(fit$chart.dim))
    expect_equal(diag$requested.chart.dim, "local.auto")
    expect_true(diag$chart.dim.auto)
    expect_true(diag$chart.dim.local.auto)
    expect_equal(diag$chart.dim.mode, "local.auto")
    expect_equal(diag$chart.dim.by.eval.n, nrow(X))
    expect_true(diag$local.pca.real.data.contract)
    expect_equal(length(predict(fit, X[1:5, , drop = FALSE])), 5L)
})

test_that("LPS local auto chart dimensions stay on the R local-PCA path", {
    X <- cbind(seq(0, 1, length.out = 24), seq(0, 1, length.out = 24)^2)
    y <- X[, 1]
    foldid <- rep(1:3, length.out = nrow(X))

    expect_error(
        fit.lps(
            X,
            y,
            foldid = foldid,
            coordinate.method = "coordinates",
            chart.dim = "local.auto",
            backend = "R"
        ),
        "requires coordinate.method = 'local.pca'"
    )
    expect_error(
        fit.lps(
            X,
            y,
            foldid = foldid,
            coordinate.method = "local.pca",
            chart.dim = "local.auto",
            backend = "cpp.local.pca"
        ),
        "currently uses the R local-PCA backend"
    )
    expect_error(
        fit.lps(
            X,
            y,
            foldid = foldid,
            coordinate.method = "local.pca",
            chart.dim = "local.auto",
            local.chart.method = "second.order.svd",
            backend = "auto"
        ),
        "currently supports only local.chart.method = 'pca'"
    )
})

test_that("K12 local-PCA contract excludes experimental second-order charts", {
    t <- seq(-1, 1, length.out = 36)
    X <- cbind(t, t^2, sin(pi * t))
    y <- t^2 + 0.1 * sin(3 * pi * t)
    foldid <- rep(1:4, length.out = nrow(X))

    fit <- fit.lps(
        X = X,
        y = y,
        foldid = foldid,
        support.grid = 14L,
        degree.grid = 1L,
        kernel.grid = "gaussian",
        coordinate.method = "local.pca",
        local.chart.method = "second.order.svd",
        chart.dim = "auto",
        auto.chart.support.metric = "both",
        auto.chart.selection.metric = "operator",
        backend = "auto"
    )
    diag <- lps.backend.diagnostics(fit)

    expect_equal(diag$local.chart.method.effective, "second.order.svd")
    expect_equal(diag$backend.auto.policy, "auto_local_pca_R_reference")
    expect_true(diag$chart.dim.auto)
    expect_false(diag$local.pca.real.data.contract)
})

test_that("K12 explicit local-PCA native opt-in is reported as opt-in", {
    t <- seq(0, 1, length.out = 28)
    X <- cbind(t, t^2)
    y <- t + 0.2 * t^2
    foldid <- rep(1:4, length.out = nrow(X))

    fit <- fit.lps(
        X = X,
        y = y,
        foldid = foldid,
        support.grid = 10L,
        degree.grid = 1L,
        kernel.grid = "gaussian",
        coordinate.method = "local.pca",
        chart.dim = 1L,
        backend = "cpp.local.pca"
    )
    diag <- lps.backend.diagnostics(fit)

    expect_equal(diag$backend.requested, "cpp.local.pca")
    expect_equal(diag$backend.used, "cpp.local.pca")
    expect_equal(
        diag$backend.auto.policy,
        "explicit_local_pca_native_opt_in"
    )
    expect_equal(diag$requested.chart.dim, "1")
    expect_false(diag$chart.dim.auto)
    expect_false(diag$local.pca.real.data.contract)
})

test_that("K10 row-Gram local PCA chart matches the SVD subspace", {
    set.seed(104)
    X <- matrix(rnorm(8L * 60L), nrow = 8L)
    center <- X[1L, ]
    chart <- geosmooth:::rcpp_local_pca_chart(
        X_support = X,
        center = center,
        chart_dim = 3L,
        center_mode = "anchor",
        dim_rule = "fixed",
        rebase_to_anchor = TRUE,
        orient_basis = FALSE
    )

    centered <- sweep(X, 2L, center)
    ref <- svd(centered, nu = 0L, nv = 3L)
    expect_equal(
        chart$singular.values[1:3],
        ref$d[1:3],
        tolerance = 1e-8
    )
    chart.projector <- chart$basis %*% t(chart$basis)
    ref.projector <- ref$v[, 1:3, drop = FALSE] %*%
        t(ref$v[, 1:3, drop = FALSE])
    expect_equal(chart.projector, ref.projector, tolerance = 1e-8)
})

test_that("K10 high-dimensional local-PCA LPS retains R/native parity", {
    set.seed(105)
    latent <- cbind(
        seq(-1, 1, length.out = 45L),
        sin(seq(-1, 1, length.out = 45L) * pi)
    )
    noise <- matrix(rnorm(45L * 58L, sd = 0.02), nrow = 45L)
    X <- cbind(latent, noise)
    y <- latent[, 1]^2 + 0.5 * latent[, 2]
    foldid <- rep(1:5, length.out = nrow(X))
    common.args <- list(
        X = X,
        y = y,
        foldid = foldid,
        support.grid = c(12L, 15L),
        degree.grid = 1:2,
        kernel.grid = c("gaussian", "tricube"),
        coordinate.method = "local.pca",
        local.chart.method = "pca",
        chart.dim = 3L
    )

    fit.r <- do.call(fit.lps, c(common.args, list(backend = "R")))
    fit.cpp <- do.call(fit.lps, c(common.args, list(backend = "cpp.local.pca")))

    expect_equal(
        fit.cpp$cv.table$cv.rmse.observed,
        fit.r$cv.table$cv.rmse.observed,
        tolerance = 1e-8
    )
    expect_equal(fit.cpp$selected, fit.r$selected, tolerance = 1e-8)
    expect_equal(fit.cpp$fitted.values, fit.r$fitted.values, tolerance = 1e-8)
})
