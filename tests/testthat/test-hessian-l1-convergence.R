test_that("scale-aware ADMM preserves a constant on a large derivative operator", {
    X <- as.matrix(expand.grid(x = seq(0, .01, length.out = 5),
                               y = seq(0, .01, length.out = 5)))
    fit <- fit.ssrhe.hessian.l1.regression(
        X, rep(2, nrow(X)), k = 14L, tangent.dim = 2L, derivative.order = 3L,
        lambda.grid = 1e-8, lambda.selection = "fixed", solver = "admm"
    )
    expect_true(fit$solver$converged)
    expect_lt(max(abs(fit$fitted.values - 2)), 1e-5)
    expect_lt(fit$objective, 1e-8)
    d <- fit$solver$admm[[1L]]
    expect_lte(d$stationarity.residual, d$dual.tolerance)
    expect_lte(d$primal.residual, d$primal.tolerance)

    # The old diagonal ridge falsely declared this one-step result converged.
    expect_warning(incomplete <- refit(
        fit, solver = "admm", admm.rho = 1, admm.maxiter = 1L,
        admm.adaptive.rho = FALSE
    ), "did not converge")
    expect_false(incomplete$solver$converged)
    expect_output(print(incomplete), "NOT CONVERGED")
})

test_that("ADMM agrees with an independent path at the original objective", {
    skip_if_not_installed("genlasso")
    X <- as.matrix(expand.grid(x = seq(0, 1, length.out = 5),
                               y = seq(0, 1, length.out = 5)))
    y <- sin(2 * pi * X[, 1]) + .25 * X[, 2]^2
    fit <- fit.ssrhe.hessian.l1.regression(
        X, y, k = 12L, tangent.dim = 2L, lambda.grid = .01,
        lambda.selection = "fixed", solver = "admm",
        admm.abstol = 1e-6, admm.reltol = 1e-5
    )
    path <- genlasso::genlasso(y, D = as.matrix(fit$operator$A), svd = TRUE)
    reference <- as.vector(stats::coef(path, lambda = .01)$beta)
    objective <- function(b) .5 * sum((b - y)^2) +
        .01 * sum(abs(fit$operator$A %*% b))
    expect_true(fit$solver$converged)
    expect_lt(sqrt(mean((fit$fitted.values - reference)^2)), 1e-3)
    expect_lt(abs(objective(fit$fitted.values) - objective(reference)), 1e-4)
    expect_equal(fit$objective, objective(fit$fitted.values))
})

test_that("CV retains failed ADMM folds and refuses incomplete selection", {
    X <- matrix(seq(0, 1, length.out = 18), ncol = 1)
    y <- sin(2 * pi * X[, 1])
    args <- list(X = X, y = y, k = 6L, tangent.dim = 1L,
                 lambda.grid = c(.01, .05), lambda.selection = "cv",
                 nfolds = 3L, solver = "admm")
    err <- tryCatch(do.call(fit.ssrhe.hessian.l1.regression,
                            c(args, list(admm.maxiter = 1L))), error = identity)
    expect_s3_class(err, "ssrhe_l1_cv_error")
    expect_true(all(err$fold.status == "iteration_limit"))
    expect_true(all(is.na(err$fold.errors)))
    expect_equal(unname(err$n.successful.folds), c(0L, 0L))
    expect_length(err$fold.diagnostics, 3L)

    fit <- do.call(fit.ssrhe.hessian.l1.regression, args)
    expect_true(fit$solver$converged)
    expect_true(all(fit$cv$fold.converged[, fit$cv$selected.idx]))
    expect_true(fit$cv$eligible[fit$cv$selected.idx])
    expect_true(all(fit$cv$n.successful.folds[fit$cv$eligible] == 3L))
})

test_that("one failed fold disqualifies a candidate under both selection rules", {
    original <- .ssrhe.hessian.l1.admm.grid
    calls <- 0L
    testthat::local_mocked_bindings(
        .ssrhe.hessian.l1.admm.grid = function(...) {
            result <- original(...)
            calls <<- calls + 1L
            if (calls %% 3L == 1L) {
                info <- attr(result, "admm")
                info[[1L]]$converged <- FALSE
                info[[1L]]$status <- "iteration_limit"
                attr(result, "admm") <- info
            }
            result
        }
    )
    X <- matrix(seq(0, 1, length.out = 18), ncol = 1)
    y <- sin(2 * pi * X[, 1])
    D <- ssrhe.hessian.operator(X, k = 6L, tangent.dim = 1L)$A
    args <- list(solver = "admm", admm.rho = NULL, admm.maxiter = 2000L,
                 admm.abstol = 1e-4, admm.reltol = 1e-3,
                 admm.adaptive.rho = TRUE)
    for (selection in c("min", "one.se")) {
        cv <- .ssrhe.hessian.l1.cv(y, rep(1, 18), D, c(.01, .05),
                                  rep(1:3, 6), "mse", selection, args)
        expect_identical(unname(cv$eligible), c(FALSE, TRUE))
        expect_equal(unname(cv$n.successful.folds), c(2L, 3L))
        expect_equal(unname(cv$selected.idx), 2L)
        expect_identical(unname(cv$mean.error[1L]), Inf)
    }
})

test_that("CV rejects an incomplete selected full-data fit", {
    original <- .ssrhe.hessian.l1.admm.grid
    calls <- 0L
    testthat::local_mocked_bindings(
        .ssrhe.hessian.l1.admm.grid = function(...) {
            result <- original(...)
            calls <<- calls + 1L
            if (calls == 4L) {
                info <- attr(result, "admm")
                for (i in seq_along(info)) {
                    info[[i]]$converged <- FALSE
                    info[[i]]$status <- "iteration_limit"
                }
                attr(result, "admm") <- info
            }
            result
        }
    )
    X <- matrix(seq(0, 1, length.out = 18), ncol = 1)
    expect_error(fit.ssrhe.hessian.l1.regression(
        X, sin(2 * pi * X[, 1]), k = 6L, tangent.dim = 1L,
        lambda.grid = c(.01, .05), lambda.selection = "cv",
        nfolds = 3L, solver = "admm"
    ), "selected Hessian L1 ADMM fit did not converge")
})

test_that("row-scaled objective and weighted missing-label fits remain explicit", {
    X <- matrix(seq(0, 1, length.out = 20), ncol = 1)
    y <- 1 + X[, 1]
    y[c(3, 8, 14)] <- NA_real_
    fit <- fit.ssrhe.hessian.l1.regression(
        X, y, k = 7L, tangent.dim = 1L, weights = seq(.5, 2, length.out = 20),
        lambda.grid = .05, lambda.selection = "fixed", solver = "admm",
        row.scaling = "l2", admm.abstol = 1e-7, admm.reltol = 1e-6
    )
    expect_true(fit$solver$converged)
    expect_lt(max(abs(fit$fitted.values - (1 + X[, 1]))), 1e-3)
    expect_true(all(is.na(fit$residuals[c(3, 8, 14)])))
    A <- fit$operator$A
    norms <- sqrt(Matrix::rowSums(A^2))
    scaled <- Matrix::Diagonal(x = ifelse(norms > 0, 1 / norms, 1)) %*% A
    expected <- fit$energies$data.loss + .05 * sum(abs(scaled %*% fit$fitted.values))
    expect_equal(fit$objective, expected)
    expect_equal(fit$energies$hessian.l1, sum(abs(A %*% fit$fitted.values)))
    expect_error(refit(fit, solver = "admm", admm.adaptive.rho = 1), "TRUE or FALSE")
})

test_that("genlasso retains its warnings without asserting ADMM convergence", {
    skip_if_not_installed("genlasso")
    X <- matrix(seq(0, 1, length.out = 12), ncol = 1)
    y <- X[, 1]^2
    y[3L] <- NA_real_
    fit <- fit.ssrhe.hessian.l1.regression(
        X, y, k = 6L, tangent.dim = 1L, lambda.grid = .05,
        lambda.selection = "fixed", solver = "genlasso"
    )
    expect_identical(fit$solver$status, "path_available")
    expect_true(is.na(fit$solver$converged))
    expect_true(any(grepl("ridge", fit$solver$warnings)))
})

test_that("automatic fallback uses the guarded ADMM solver and preserves its reason", {
    skip_if_not_installed("genlasso")
    testthat::local_mocked_bindings(
        .fit.ssrhe.hessian.l1.path = function(...) stop("injected path failure")
    )
    X <- matrix(seq(0, 1, length.out = 18), ncol = 1)
    fit <- fit.ssrhe.hessian.l1.regression(
        X, sin(2 * pi * X[, 1]), k = 6L, tangent.dim = 1L,
        lambda.grid = .05, lambda.selection = "fixed", solver = "auto"
    )
    expect_identical(fit$solver$backend, "admm_fallback")
    expect_true(fit$solver$converged)
    expect_identical(fit$solver$path.error, "injected path failure")
    fixed.rho <- refit(fit, solver = "admm", admm.rho = .01,
                       admm.adaptive.rho = FALSE)
    expect_true(fixed.rho$solver$converged)
    expect_equal(fixed.rho$solver$admm[[1L]]$rho.initial, .01)
    expect_identical(fixed.rho$solver$admm[[1L]]$rho.updates, 0L)
})
