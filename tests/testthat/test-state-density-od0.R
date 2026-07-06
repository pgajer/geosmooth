test_that("OD0 empirical state density normalizes repeated subject visits", {
    X <- matrix(seq(0, 1, length.out = 5), ncol = 1L)
    fit <- fit.subject.od(
        X = X,
        subject.index = c(1L, 2L, 2L, 5L),
        method = "empirical"
    )

    expect_s3_class(fit, "state_density_fit")
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

test_that("OD0 empirical state density validates inputs and control values", {
    X <- matrix(1:6, ncol = 2L)

    expect_error(
        fit.state.density.empirical(X, weights = c(1, -1, 2)),
        "nonnegative"
    )
    expect_error(
        fit.state.density.empirical(X, weights = c(0, 0, 0)),
        "positive total mass"
    )
    expect_error(
        fit.subject.od(X, subject.index = c(1L, 4L), method = "empirical"),
        "outside 1:nrow"
    )
    expect_error(
        fit.state.density.empirical(
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

test_that("OD0 dedicated method stubs return structured deferred results", {
    X <- matrix(seq(0, 1, length.out = 6), ncol = 1L)
    weights <- c(1, 0, 2, 0, 0, 1)
    methods <- c(
        "graph_random_walk", "graph_heat_kernel", "lps_count",
        "ps_lps_count", "chart_kernel", "local_likelihood"
    )

    for (method in methods) {
        fit <- fit.state.density(X = X, weights = weights, method = method)
        expect_s3_class(fit, "state_density_fit")
        expect_identical(fit$status, "not_implemented")
        expect_equal(length(fit$rho), nrow(X))
        expect_true(all(is.na(fit$rho)))
        expect_equal(fit$empirical.rho, weights / sum(weights),
                     tolerance = 1e-12)
        expect_match(fit$warnings, "not implemented")
    }

    logistic <- fit.state.density(
        X = X,
        method = "lps_logistic_binary",
        binary = c(1, 0, 1, 0, 0, 1)
    )
    expect_identical(logistic$status, "not_implemented")
    expect_equal(logistic$empirical.rho, c(1, 0, 1, 0, 0, 1) / 3,
                 tolerance = 1e-12)
})

test_that("OD0 dependency precheck reports required and optional dependencies", {
    deps <- state.density.dependency.precheck(check.gflow = TRUE)
    expect_true(all(c("package", "symbol", "required", "available", "note") %in%
                        names(deps)))
    geosmooth.rows <- deps[deps$package == "geosmooth", , drop = FALSE]
    expect_true(all(geosmooth.rows$required))
    expect_true(all(geosmooth.rows$available))
    expect_true(any(deps$package == "gflow"))

    expect_silent(state.density.dependency.precheck(check.gflow = TRUE,
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

    summary <- geosmooth:::.state.density.raw.basin.summary(
        basin.assignment = c("a", "a", "b"),
        rho = c(0.2, 0.3, 0.5)
    )
    expect_equal(summary$raw.basin.size.summary$size, c(2L, 1L))
    expect_equal(summary$raw.basin.mass.summary$mass, c(0.5, 0.5),
                 tolerance = 1e-12)
})
