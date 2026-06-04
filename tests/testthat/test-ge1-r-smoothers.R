test_that("GE1 LPS coordinate R backend fits and predicts", {
    set.seed(11)
    X <- matrix(seq(0, 1, length.out = 24), ncol = 1)
    y <- sin(2 * pi * X[, 1]) + stats::rnorm(nrow(X), sd = 0.02)

    fit <- kernel.local.polynomial.cv(
        X, y,
        support.grid = c(6L, 8L),
        degree.grid = 0:1,
        kernel.grid = "gaussian",
        cv.folds = 3L,
        backend = "R"
    )

    expect_s3_class(fit, "kernel.local.polynomial.cv")
    expect_equal(length(fit$fitted.values), nrow(X))
    expect_true(all(is.finite(fit$fitted.values)))
    expect_equal(length(predict(fit, X[1:3, , drop = FALSE])), 3L)
})

test_that("GE2 LPS coordinate C++ backend fits and predicts", {
    set.seed(12)
    X <- matrix(seq(0, 1, length.out = 24), ncol = 1)
    y <- cos(2 * pi * X[, 1]) + stats::rnorm(nrow(X), sd = 0.02)

    fit <- kernel.local.polynomial.cv(
        X, y,
        support.grid = c(6L, 8L),
        degree.grid = 0:1,
        kernel.grid = "gaussian",
        cv.folds = 3L,
        backend = "cpp"
    )

    expect_s3_class(fit, "kernel.local.polynomial.cv")
    expect_identical(fit$backend.used, "cpp")
    expect_equal(length(fit$fitted.values), nrow(X))
    expect_true(all(is.finite(fit$fitted.values)))
    expect_equal(length(predict(fit, X[1:3, , drop = FALSE])), 3L)
})

test_that("GE2 local PCA chart backend supports LPS and LPL-TF", {
    X <- cbind(seq(0, 1, length.out = 18), seq(0, 1, length.out = 18)^2)
    y <- sin(2 * pi * X[, 1])

    fit <- kernel.local.polynomial.cv(
        X, y,
        support.grid = 8L,
        degree.grid = 1L,
        kernel.grid = "gaussian",
        cv.folds = 3L,
        coordinate.method = "local.pca",
        chart.dim = 1L,
        backend = "R"
    )
    lpl <- lpl.tf.operator(
        X,
        degree = 1L,
        support.type = "knn",
        support.size = 8L,
        kernel = "gaussian",
        coordinate.method = "local.pca",
        chart.dim = 1L
    )

    expect_s3_class(fit, "kernel.local.polynomial.cv")
    expect_identical(fit$coordinate.method, "local.pca")
    expect_s3_class(lpl, "lpl_tf_operator")
    expect_equal(ncol(lpl$A), nrow(X))
})

test_that("GE1 MALPS coordinate fit works", {
    X <- cbind(seq(0, 1, length.out = 20))
    y <- X[, 1]^2

    fit <- fit.malps(
        X, y,
        degree = 1L,
        support.type = "knn",
        support.size = 7L,
        kernel = "tricube",
        support.selection = "fixed",
        coordinate.method = "coordinates"
    )

    expect_s3_class(fit, "malps")
    expect_equal(length(fit$fitted.values), nrow(X))
    expect_true(all(is.finite(fit$fitted.values)))
})

test_that("GE1 LPL-TF and SLPLiFT coordinate operators build", {
    X <- cbind(seq(0, 1, length.out = 18))

    lpl <- lpl.tf.operator(
        X,
        degree = 1L,
        support.type = "knn",
        support.size = 7L,
        kernel = "gaussian",
        coordinate.method = "coordinates"
    )
    slpl <- slpl.tf.operator(
        X,
        degree = 1L,
        support.type = "knn",
        support.size = 7L,
        kernel = "gaussian",
        coordinate.method = "coordinates"
    )

    expect_s3_class(lpl, "lpl_tf_operator")
    expect_s3_class(slpl, "slpl_tf_operator")
    expect_equal(ncol(lpl$A), nrow(X))
    expect_equal(ncol(slpl$A_LPL), nrow(X))
})

test_that("GE2 unsupported native combinations fail informatively", {
    X <- cbind(seq(0, 1, length.out = 12))
    y <- X[, 1]

    expect_error(
        kernel.local.polynomial.cv(
            X, y,
            support.grid = 5L,
            degree.grid = 1L,
            kernel.grid = "gaussian",
            coordinate.method = "local.pca",
            chart.dim = 1L,
            backend = "cpp"
        ),
        "currently supports only"
    )
})
