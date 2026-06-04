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
