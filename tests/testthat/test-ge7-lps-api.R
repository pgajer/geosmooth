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
    expect_s3_class(fit, "kernel.local.polynomial.cv")
    expect_identical(class(fit)[[1L]], "lps")
    expect_identical(fit$method.id, "lps")
    expect_identical(fit$method.label, "LPS")
    expect_identical(fit$method.family, "local_polynomial_smoother")
    expect_equal(length(predict(fit, X[1:4, , drop = FALSE])), 4L)
    expect_match(capture.output(print(fit))[[1L]], "LPS")
})

test_that("GE7 kernel.local.polynomial.cv remains a compatibility alias", {
    X <- cbind(seq(0, 1, length.out = 22),
               seq(0, 1, length.out = 22)^2)
    y <- cos(2 * pi * X[, 1]) + 0.1 * X[, 2]
    foldid <- rep(1:4, length.out = nrow(X))
    args <- list(
        X = X,
        y = y,
        foldid = foldid,
        support.grid = c(7L, 9L),
        degree.grid = 0:1,
        kernel.grid = c("gaussian", "tricube"),
        backend = "R"
    )

    canonical <- do.call(fit.lps, args)
    legacy.fun <- get(
        "kernel.local.polynomial.cv",
        envir = asNamespace("geosmooth"),
        inherits = FALSE
    )
    legacy <- do.call(legacy.fun, args)

    expect_s3_class(legacy, "lps")
    expect_s3_class(legacy, "kernel.local.polynomial.cv")
    expect_equal(legacy$selected, canonical$selected)
    expect_equal(legacy$cv.table, canonical$cv.table)
    expect_equal(legacy$fitted.values, canonical$fitted.values)
    expect_equal(
        predict.kernel.local.polynomial.cv(legacy, X[1:3, , drop = FALSE]),
        predict.lps(canonical, X[1:3, , drop = FALSE])
    )
})
