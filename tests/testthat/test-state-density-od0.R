test_that("OD0 empirical density normalizes repeated subject visits", {
    X <- matrix(seq(0, 1, length.out = 5), ncol = 1L)
    fit <- fit.subject.od(
        X = X,
        subject.index = c(1L, 2L, 2L, 5L),
        method = "empirical"
    )

    expect_s3_class(fit, "density_fit")
    expect_identical(fit$method.id, "empirical")
    expect_identical(fit$status, "ok")
    expect_equal(fit$rho, c(1, 2, 0, 0, 1) / 4, tolerance = 1e-12)
    expect_equal(fit$empirical.rho, fit$rho, tolerance = 1e-12)
    expect_equal(fit$accounting$mass, 1, tolerance = 1e-12)
    expect_equal(fit$accounting$min.rho, 0, tolerance = 1e-12)
    expect_equal(fit$subject$n.visits, 4L)
    expect_equal(fit$subject$n.unique.visited, 3L)
    expect_equal(fit$subject$max.multiplicity, 2)
    expect_equal(fit$subject$repeat.fraction, 1 / 3, tolerance = 1e-12)
})

test_that("OD0 empirical density validates inputs and control values", {
    X <- matrix(1:6, ncol = 2L)

    expect_error(
        fit.density.empirical(X, weights = c(1, -1, 2)),
        "nonnegative"
    )
    expect_error(
        fit.density.empirical(X, weights = c(0, 0, 0)),
        "positive total mass"
    )
    expect_error(
        fit.subject.od(X, subject.index = c(1L, 4L), method = "empirical"),
        "outside 1:nrow"
    )
    expect_error(
        fit.density.empirical(
            X,
            weights = c(1, 1, 1),
            density.control = list(mass.tol = -1)
        ),
        "mass.tol"
    )
})

test_that("OD0 correction helper clips and renormalizes raw density fields", {
    X <- matrix(1:4, ncol = 1L)
    out <- geosmooth:::.state.density.finalize(
        method.id = "test",
        X = X,
        fitted.raw = c(0.5, -0.1, 0.6, 0),
        density.control = list(clip.negative = TRUE, renormalize = TRUE)
    )

    expect_identical(out$status, "ok")
    expect_equal(out$rho, c(0.5, 0, 0.6, 0) / 1.1, tolerance = 1e-12)
    expect_equal(out$accounting$raw.mass, 1.0, tolerance = 1e-12)
    expect_equal(out$accounting$neg.mass, 0.1, tolerance = 1e-12)
    expect_equal(out$accounting$clip.mass, 0.1, tolerance = 1e-12)
    expect_equal(out$accounting$normalization.constant, 1.1, tolerance = 1e-12)
})

test_that("OD0 density dispatcher is restricted to density-native methods", {
    X <- matrix(seq(0, 1, length.out = 6), ncol = 1L)
    weights <- c(1, 0, 2, 0, 0, 1)

    fit <- fit.density(X = X, weights = weights, method = "empirical")
    expect_s3_class(fit, "density_fit")
    expect_equal(fit$rho, weights / sum(weights), tolerance = 1e-12)

    expect_error(
        fit.density(X = X, weights = weights, method = "lps_count"),
        "'arg' should be one of"
    )
})

test_that("OD0 normalize.density clips and normalizes numeric and fit objects", {
    X <- matrix(1:4, ncol = 1L)

    numeric.fit <- normalize.density(
        c(0.5, -0.1, 0.6, 0),
        X = X,
        density.control = list(clip.negative = TRUE, renormalize = TRUE)
    )
    expect_s3_class(numeric.fit, "density_fit")
    expect_equal(numeric.fit$rho, c(0.5, 0, 0.6, 0) / 1.1,
                 tolerance = 1e-12)
    expect_equal(numeric.fit$accounting$clip.mass, 0.1, tolerance = 1e-12)
    expect_equal(numeric.fit$empirical.rho, rep(NA_real_, 4L))

    lps.like <- list(
        method.id = "lps",
        X.eval = X,
        fitted.values = c(1, 2, 0, 1)
    )
    class(lps.like) <- c("lps", "list")
    lps.density <- normalize.density(lps.like, keep.source.fit = FALSE)
    expect_s3_class(lps.density, "density_fit")
    expect_identical(lps.density$method.id, "normalized_lps")
    expect_equal(lps.density$rho, c(1, 2, 0, 1) / 4, tolerance = 1e-12)
    expect_equal(lps.density$empirical.rho, rep(NA_real_, 4L))
    expect_identical(lps.density$diagnostics$source.class, "lps")
})

test_that("OD0 dependency precheck reports required and optional dependencies", {
    deps <- density.dependency.precheck(check.gflow = TRUE)
    expect_true(all(c("package", "symbol", "required", "available", "note") %in%
                        names(deps)))
    geosmooth.rows <- deps[deps$package == "geosmooth", , drop = FALSE]
    expect_true(all(geosmooth.rows$required))
    expect_true(all(geosmooth.rows$available))
    expect_true(any(deps$package == "gflow"))

    expect_silent(density.dependency.precheck(check.gflow = TRUE,
                                                    fail = TRUE))
})

test_that("OD0 private smoothness helpers have deterministic placeholder behavior", {
    expect_equal(
        geosmooth:::.state.density.local.maxima.count(
            values = c(1, 3, 2),
            adj.list = list(2L, c(1L, 3L), 2L)
        ),
        1L
    )
    expect_equal(
        geosmooth:::.state.density.local.maxima.count(
            values = c(0, 0, 1, 1, 0),
            adj.list = list(2L, c(1L, 3L), c(2L, 4L), c(3L, 5L), 4L)
        ),
        0L
    )

    summary <- geosmooth:::.state.density.raw.basin.summary(
        basin.assignment = c("a", "a", "b"),
        rho = c(0.2, 0.3, 0.5)
    )
    expect_equal(summary$raw.basin.size.summary$size, c(2L, 1L))
    expect_equal(summary$raw.basin.mass.summary$mass, c(0.5, 0.5),
                 tolerance = 1e-12)
})

test_that("OD0 finalize wires strict local-maxima smoothness diagnostics", {
    X <- matrix(seq(0, 1, length.out = 5), ncol = 1L)
    fit <- geosmooth:::.state.density.finalize(
        method.id = "test",
        X = X,
        fitted.raw = c(0, 0.2, 0.1, 0.5, 0.1),
        empirical.rho = rep(NA_real_, 5L)
    )
    expect_equal(fit$smoothness$n.local.maxima, 2L)

    plateau <- geosmooth:::.state.density.finalize(
        method.id = "test",
        X = X,
        fitted.raw = c(0, 0, 0, 0, 0),
        empirical.rho = rep(NA_real_, 5L)
    )
    expect_equal(plateau$smoothness$n.local.maxima, 0L)
})
