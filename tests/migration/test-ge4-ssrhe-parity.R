test_that("GE4 SSRHE fixed-k operator matches gflow reference", {
    .geosmooth.load.gflow.reference()
    skip_if_not_installed("Matrix")

    X <- as.matrix(expand.grid(x = seq(0, 1, length.out = 4),
                               y = seq(0, 1, length.out = 4)))
    args <- list(
        X = X,
        k = 10L,
        tangent.dim = 2L,
        stabilizer = TRUE,
        return.local.diagnostics = FALSE
    )

    gs <- do.call(.geosmooth.ref("ssrhe.hessian.operator"), args)
    gf <- do.call(.gflow.ref("ssrhe.hessian.operator"), args)

    testthat::expect_equal(as.matrix(gs$A), as.matrix(gf$A),
                           tolerance = 1e-10)
    testthat::expect_equal(as.matrix(gs$B), as.matrix(gf$B),
                           tolerance = 1e-10)
    testthat::expect_equal(as.matrix(gs$BS), as.matrix(gf$BS),
                           tolerance = 1e-10)
    testthat::expect_equal(gs$row.table, gf$row.table, tolerance = 1e-10)
    testthat::expect_equal(gs$diagnostics, gf$diagnostics,
                           tolerance = 1e-10)
})

test_that("GE4 SSRHE L2 fit matches gflow reference", {
    .geosmooth.load.gflow.reference()
    skip_if_not_installed("Matrix")

    X <- as.matrix(expand.grid(x = seq(0, 1, length.out = 4),
                               y = seq(0, 1, length.out = 4)))
    y <- sin(2 * pi * X[, 1]) + 0.25 * X[, 2]^2
    args <- list(
        X = X,
        y = y,
        k = 10L,
        tangent.dim = 2L,
        lambda1 = 0.2,
        lambda2 = 0.03,
        stabilizer = TRUE,
        return.local.diagnostics = FALSE
    )

    gs <- do.call(.geosmooth.ref("fit.ssrhe.hessian.regression"), args)
    gf <- do.call(.gflow.ref("fit.ssrhe.hessian.regression"), args)

    testthat::expect_equal(gs$fitted.values, gf$fitted.values,
                           tolerance = 1e-10)
    testthat::expect_equal(gs$residuals, gf$residuals, tolerance = 1e-10)
    testthat::expect_equal(gs$energies, gf$energies, tolerance = 1e-10)
    testthat::expect_equal(gs$lambda, gf$lambda, tolerance = 1e-10)
})

test_that("GE4 SSRHE L1 ADMM fit matches gflow reference", {
    .geosmooth.load.gflow.reference()
    skip_if_not_installed("Matrix")

    X <- as.matrix(expand.grid(x = seq(0, 1, length.out = 4),
                               y = seq(0, 1, length.out = 4)))
    y <- sin(2 * pi * X[, 1]) + 0.25 * X[, 2]^2
    args <- list(
        X = X,
        y = y,
        k = 10L,
        tangent.dim = 2L,
        lambda.grid = 0.04,
        lambda.selection = "fixed",
        solver = "admm",
        row.scaling = "l2",
        admm.maxiter = 1000L,
        return.local.diagnostics = FALSE
    )

    gs <- do.call(.geosmooth.ref("fit.ssrhe.hessian.l1.regression"), args)
    gf <- do.call(.gflow.ref("fit.ssrhe.hessian.l1.regression"), args)

    testthat::expect_equal(gs$fitted.values, gf$fitted.values,
                           tolerance = 1e-10)
    testthat::expect_equal(gs$residuals, gf$residuals, tolerance = 1e-10)
    testthat::expect_equal(gs$lambda, gf$lambda, tolerance = 1e-10)
    testthat::expect_equal(gs$diagnostics, gf$diagnostics,
                           tolerance = 1e-10)
})
