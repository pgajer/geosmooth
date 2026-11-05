assessment_fixture <- function() {
    fit.logistic.trend.filtering(seq(0, 1, length.out = 60),
        rep(c(0, 1, 0, 1, 1), 12), c(Inf, .01),
        backend = "banded", curve.ridge = .1)
}

test_that("the statistic and inclusive randomization p-value reproduce independently", {
    fit <- assessment_fixture()
    a <- assess.logistic.trend.filtering(fit, permutations = 9,
        inner.folds = 3, outer.folds = 3, seed = 42)
    expect_identical(a$status, "complete")
    loglik <- sum(dbinom(fit$y, 1, fitted(a$fit), log = TRUE))
    null <- sum(dbinom(fit$y, 1, mean(fit$y), log = TRUE))
    expect_equal(a$statistic, max(0, 2*(loglik-null)), tolerance = 1e-10)
    statistics <- vapply(a$seeds$permutations, function(seed) {
        set.seed(seed)
        y <- fit$y[sample.int(length(fit$y))]
        refit <- fit.logistic.trend.filtering(fit$x, y, fit$lambda,
            backend = fit$backend, curve.ridge = fit$curve.ridge,
            lambda.selection = "cv", foldid = a$folds$tuning, control = fit$control)
        max(0, 2*sum(dbinom(y, 1, fitted(refit), log = TRUE) -
                     dbinom(y, 1, mean(y), log = TRUE)))
    }, numeric(1))
    expect_equal(a$permutations$statistic, statistics, tolerance = 1e-10)
    tolerance <- a$permutation.summary$comparison.tolerance
    expected <- (1 + sum(statistics >= a$statistic-tolerance))/10
    expect_equal(a$p.value, expected)
    expect_equal(unname(a$p.value.bounds), rep(expected, 2))
    expect_gte(a$p.value, .1)
    expect_true(all(vapply(a$permutation.diagnostics, function(x)
        nrow(x$cv.table) == length(fit$lambda) && length(x$cv.fold.status) == 3,
        logical(1))))
    expect_output(print(a), "Permutation p-value")
    expect_invisible(print(a))
})

test_that("nested CV uses training-only baselines, tuning and transformations", {
    fit <- assessment_fixture()
    a <- assess.logistic.trend.filtering(fit, permutations = 1,
        inner.folds = 3, outer.folds = 3, seed = 42)
    p <- a$prediction$predictions
    expect_identical(a$prediction$status, "complete")
    expect_equal(a$prediction$scores$log.loss[2],
                 -mean(dbinom(fit$y, 1, p$probability, log = TRUE)), tolerance = 1e-10)
    expect_equal(a$prediction$scores$brier[2], mean((fit$y-p$probability)^2))
    expect_equal(unname(a$prediction$improvement),
        c(mean(p$constant.log.loss-p$log.loss), mean(p$constant.brier-p$brier)))
    for (k in 1:3) {
        train <- a$folds$outer != k
        expect_equal(unique(p$constant.probability[!train]), mean(fit$y[train]))
        inner <- a$folds$inner[[k]]
        expect_identical(as.integer(names(inner)), which(train))
        ff <- fit.logistic.trend.filtering(fit$x[train], fit$y[train], fit$lambda,
            lambda.selection = "cv", foldid = unname(inner), backend = fit$backend,
            curve.ridge = fit$curve.ridge, control = fit$control)
        expect_equal(as.numeric(predict(ff, fit$x[!train])), p$probability[!train], tolerance = 1e-10)
        expect_equal(ff$cv.table, a$prediction$diagnostics[[k]]$cv.table)
        expect_equal(range(fit$x[train]), a$prediction$diagnostics[[k]]$training.range)
    }
    held <- a$folds$outer == 1
    changed <- fit
    changed$y[held] <- 1-changed$y[held]
    # Even a stored, outcome-dependent fit fold assignment is ignored.
    changed$foldid <- changed$y + 1L
    b <- assess.logistic.trend.filtering(changed, permutations = 1,
        inner.folds = 3, outer.folds = 3, seed = 42)
    expect_identical(a$folds, b$folds)
    expect_equal(p$eta[held], b$prediction$predictions$eta[held], tolerance = 1e-12)
    expect_equal(a$prediction$diagnostics[[1]], b$prediction$diagnostics[[1]])
})

test_that("random state is preserved and predictive assessment does not alter the test", {
    fit <- assessment_fixture()
    set.seed(912)
    previous <- .Random.seed
    a <- assess.logistic.trend.filtering(fit, permutations = 3,
        inner.folds = 3, outer.folds = 3, seed = 42)
    expect_identical(.Random.seed, previous)
    b <- assess.logistic.trend.filtering(fit, permutations = 3,
        inner.folds = 3, seed = 42, predictive = FALSE)
    expect_identical(.Random.seed, previous)
    expect_identical(a$permutations, b$permutations)
    expect_identical(a$p.value, b$p.value)
    expect_null(b$prediction)
    expect_null(b$folds$outer)
    expect_identical(a, assess.logistic.trend.filtering(fit, permutations = 3,
        inner.folds = 3, outer.folds = 3, seed = 42))
    local({
        on.exit(assign(".Random.seed", previous, envir = .GlobalEnv))
        rm(".Random.seed", envir = .GlobalEnv)
        invisible(assess.logistic.trend.filtering(fit, permutations = 1,
            inner.folds = 3, seed = 42, predictive = FALSE))
        expect_false(exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
    })
})

test_that("failed randomizations and outer fits are retained without selective scoring", {
    fit <- fit.logistic.trend.filtering(seq(0, 1, length.out = 12),
        rep(c(0, 0, 0, 1), 3), c(Inf, .01), backend = "banded", curve.ridge = .1)
    expect_warning(a <- assess.logistic.trend.filtering(fit, permutations = 39,
        inner.folds = 3, outer.folds = 3, seed = 42), "failed fits")
    expect_identical(a$status, "incomplete_permutations")
    expect_true(is.na(a$p.value))
    expect_gt(a$permutation.summary$failed, 0)
    expect_equal(nrow(a$permutations), 39)
    r <- sum(a$permutations$statistic >= a$statistic -
             a$permutation.summary$comparison.tolerance, na.rm = TRUE)
    missing <- sum(!is.finite(a$permutations$statistic))
    expect_equal(unname(a$p.value.bounds), c(1+r, 1+r+missing)/40)
    expect_identical(a$prediction$status, "incomplete")
    expect_true(all(is.na(a$prediction$improvement)))
    expect_true(all(is.na(a$prediction$scores[2, c("log.loss", "brier")])))
    expect_equal(nrow(a$prediction$predictions), 12)
    expect_true(any(vapply(a$permutation.diagnostics, function(x)
        any(x$cv.fold.status != "complete"), logical(1))))
    broken <- assessment_fixture()
    broken$control$max.iterations <- 1L
    a <- assess.logistic.trend.filtering(broken, permutations = 2,
        inner.folds = 3, seed = 42, predictive = FALSE, warn = FALSE)
    expect_identical(a$status, "observed_fit_failed")
    expect_true(is.na(a$p.value))
    expect_true(all(is.na(a$p.value.bounds)))
})

test_that("unsupported nulls and malformed controls are rejected", {
    fit <- assessment_fixture()
    for (field in c("weights", "y", "covariates", "offset")) {
        changed <- fit
        changed[[field]] <- switch(field, weights = rep(2, 60), y = rep(.5, 60),
            covariates = matrix(fit$x), offset = rep(.1, 60))
        expect_error(assess.logistic.trend.filtering(changed, permutations = 1), "independent binary")
    }
    changed <- fit; changed$offset.used <- TRUE
    expect_error(assess.logistic.trend.filtering(changed, permutations = 1), "no offset")
    expect_error(assess.logistic.trend.filtering(NULL), "object")
    for (value in list(0, -1, NA_real_, Inf, 1.5, c(1,2), "2"))
        expect_error(assess.logistic.trend.filtering(fit, permutations = value), "permutations")
    expect_error(assess.logistic.trend.filtering(fit, inner.folds = 1), "inner.folds")
    expect_error(assess.logistic.trend.filtering(fit, outer.folds = 100), "Fold counts")
    expect_error(assess.logistic.trend.filtering(fit, predictive = NA), "predictive")
    expect_error(assess.logistic.trend.filtering(fit, seed = -1), "seed")
    changed <- fit; changed$x <- c(0, 1, 2, rep(3, 57))
    expect_error(assess.logistic.trend.filtering(changed, permutations = 1,
        inner.folds = 2, outer.folds = 60), "four distinct")
})

test_that("enumeration of a small conditional null gives conservative exact rejection rates", {
    # Under the constant Bernoulli null, all 70 labelings with four events among
    # eight independent observations are equally probable. This enumerates the
    # complete conditional null, rather than relying on a noisy simulation.
    x <- seq(0, 1, length.out = 8)
    labels <- combn(8, 4)
    statistics <- apply(labels, 2, function(events) {
        y <- numeric(8); y[events] <- 1
        fit <- fit.logistic.trend.filtering(x, y, c(Inf, .01),
            backend = "banded", curve.ridge = .5)
        a <- assess.logistic.trend.filtering(fit, permutations = 1,
            inner.folds = 8, seed = 17, predictive = FALSE, warn = FALSE)
        expect_identical(a$status, "complete")
        a$statistic
    })
    exact.p <- vapply(statistics, function(observed)
        mean(statistics >= observed-1e-10*max(1, abs(observed))), numeric(1))
    expect_true(all(is.finite(statistics)))
    for (alpha in c(.01, .05, .1, .2)) expect_lte(mean(exact.p <= alpha), alpha)
})

test_that("assessment agrees between dense and banded objectives", {
    banded <- assessment_fixture()
    dense <- fit.logistic.trend.filtering(banded$x, banded$y, banded$lambda,
        backend = "dense", curve.ridge = banded$curve.ridge)
    a <- assess.logistic.trend.filtering(banded, permutations = 9,
        inner.folds = 3, outer.folds = 3, seed = 42)
    b <- assess.logistic.trend.filtering(dense, permutations = 9,
        inner.folds = 3, outer.folds = 3, seed = 42)
    expect_identical(a$status, "complete")
    expect_identical(b$status, "complete")
    expect_identical(a$folds, b$folds)
    expect_equal(a$statistic, b$statistic, tolerance = 2e-6)
    expect_equal(a$permutations$statistic, b$permutations$statistic, tolerance = 2e-6)
    expect_equal(a$p.value, b$p.value)
    expect_equal(a$prediction$predictions$probability,
                 b$prediction$predictions$probability, tolerance = 2e-6)
    expect_equal(a$prediction$improvement, b$prediction$improvement, tolerance = 2e-6)
})
