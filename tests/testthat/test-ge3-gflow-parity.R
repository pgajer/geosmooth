test_that("GE3 LPS R backend matches gflow reference", {
    .geosmooth.load.gflow.reference()
    X <- cbind(seq(0, 1, length.out = 28))
    y <- sin(2 * pi * X[, 1]) + 0.1 * X[, 1]
    foldid <- rep(1:4, length.out = nrow(X))
    args <- list(
        X = X,
        y = y,
        foldid = foldid,
        support.grid = c(6L, 9L),
        degree.grid = 0:1,
        kernel.grid = c("gaussian", "tricube"),
        backend = "R"
    )

    gs <- do.call(.geosmooth.ref("kernel.local.polynomial.cv"), args)
    gf <- do.call(.gflow.ref("kernel.local.polynomial.cv"), args)

    .expect.numeric.close(gs$fitted.values, gf$fitted.values)
    testthat::expect_equal(gs$selected, gf$selected, tolerance = 1e-10)
    testthat::expect_equal(gs$cv.table, gf$cv.table, tolerance = 1e-10)
})

test_that("GE3 LPS C++ backend matches gflow reference", {
    .geosmooth.load.gflow.reference()
    X <- cbind(seq(0, 1, length.out = 28), seq(0, 1, length.out = 28)^2)
    y <- cos(2 * pi * X[, 1]) + 0.2 * X[, 2]
    foldid <- rep(1:4, length.out = nrow(X))
    args <- list(
        X = X,
        y = y,
        foldid = foldid,
        support.grid = c(7L, 10L),
        degree.grid = 0:1,
        kernel.grid = "gaussian",
        backend = "cpp"
    )

    gs <- do.call(.geosmooth.ref("kernel.local.polynomial.cv"), args)
    gf <- do.call(.gflow.ref("kernel.local.polynomial.cv"), args)

    .expect.numeric.close(gs$fitted.values, gf$fitted.values, tol = 1e-9)
    testthat::expect_equal(gs$selected, gf$selected, tolerance = 1e-9)
    testthat::expect_equal(gs$cv.table, gf$cv.table, tolerance = 1e-9)
})

test_that("GE3 MALPS coordinate mode matches gflow reference", {
    .geosmooth.load.gflow.reference()
    X <- cbind(seq(0, 1, length.out = 24))
    y <- X[, 1]^2 + 0.25 * X[, 1]
    args <- list(
        X = X,
        y = y,
        degree = 1L,
        support.type = "knn",
        support.size = 8L,
        kernel = "tricube",
        support.selection = "fixed",
        coordinate.method = "coordinates"
    )

    gs <- do.call(.geosmooth.ref("fit.malps"), args)
    gf <- do.call(.gflow.ref("fit.malps"), args)

    .expect.numeric.close(gs$fitted.values, gf$fitted.values)
    testthat::expect_equal(gs$diagnostics, gf$diagnostics, tolerance = 1e-10)
})

test_that("GE3 LPL-TF coordinate and local-PCA operators match gflow", {
    .geosmooth.load.gflow.reference()
    X <- cbind(seq(0, 1, length.out = 22), seq(0, 1, length.out = 22)^2)

    coordinate.args <- list(
        X = X,
        degree = 1L,
        support.type = "knn",
        support.size = 8L,
        kernel = "gaussian",
        coordinate.method = "coordinates"
    )
    pca.args <- coordinate.args
    pca.args$coordinate.method <- "local.pca"
    pca.args$chart.dim <- 1L

    for (args in list(coordinate.args, pca.args)) {
        gs <- do.call(.geosmooth.ref("lpl.tf.operator"), args)
        gf <- do.call(.gflow.ref("lpl.tf.operator"), args)

        testthat::expect_equal(as.matrix(gs$A), as.matrix(gf$A),
                               tolerance = 1e-10)
        testthat::expect_equal(gs$row.table, gf$row.table, tolerance = 1e-10)
        testthat::expect_equal(gs$diagnostics, gf$diagnostics,
                               tolerance = 1e-10)
    }
})

test_that("GE3 SLPLiFT coordinate and local-PCA operators match gflow", {
    .geosmooth.load.gflow.reference()
    X <- cbind(seq(0, 1, length.out = 20), seq(0, 1, length.out = 20)^2)

    coordinate.args <- list(
        X = X,
        degree = 1L,
        support.type = "knn",
        support.size = 8L,
        kernel = "gaussian",
        coordinate.method = "coordinates"
    )
    pca.args <- coordinate.args
    pca.args$coordinate.method <- "local.pca"
    pca.args$chart.dim <- 1L

    for (args in list(coordinate.args, pca.args)) {
        gs <- do.call(.geosmooth.ref("slpl.tf.operator"), args)
        gf <- do.call(.gflow.ref("slpl.tf.operator"), args)

        testthat::expect_equal(as.matrix(gs$A_LPL), as.matrix(gf$A_LPL),
                               tolerance = 1e-10)
        testthat::expect_equal(as.matrix(gs$C_sync), as.matrix(gf$C_sync),
                               tolerance = 1e-10)
        testthat::expect_equal(gs$row.table, gf$row.table, tolerance = 1e-10)
        testthat::expect_equal(gs$diagnostics, gf$diagnostics,
                               tolerance = 1e-10)
    }
})

test_that("GE3 graph-geodesic bridge works when gflow reference is available", {
    .geosmooth.load.gflow.reference()
    X <- cbind(seq(0, 1, length.out = 12))
    y <- X[, 1]^2
    adj.list <- lapply(seq_len(nrow(X)), function(i) {
        out <- integer()
        if (i > 1L) out <- c(out, i - 1L)
        if (i < nrow(X)) out <- c(out, i + 1L)
        out
    })
    weight.list <- lapply(adj.list, function(ii) rep(1, length(ii)))

    fit <- .geosmooth.ref("fit.malps")(
        X = X,
        y = y,
        adj.list = adj.list,
        weight.list = weight.list,
        degree = 1L,
        support.metric = "graph.geodesic",
        support.type = "knn",
        support.size = 5L,
        kernel = "gaussian",
        support.selection = "fixed",
        coordinate.method = "coordinates"
    )

    testthat::expect_s3_class(fit, "malps")
    testthat::expect_equal(length(fit$fitted.values), nrow(X))
    testthat::expect_true(all(is.finite(fit$fitted.values)))
})

test_that("GE3 native symbols use geosmooth prefix only", {
    root <- .geosmooth.test.package.root()
    rcpp <- readLines(file.path(root, "src", "RcppExports.cpp"), warn = FALSE)
    namespace <- readLines(file.path(root, "NAMESPACE"), warn = FALSE)

    testthat::expect_true(any(grepl("_geosmooth_", rcpp)))
    testthat::expect_false(any(grepl("_gflow_", rcpp)))
    testthat::expect_false(any(grepl("_gflow_", namespace)))
})
