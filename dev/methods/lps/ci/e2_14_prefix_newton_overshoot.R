# E2.14 — pre-fix motivating case: plain-Newton IRLS deviance overshoot
# under near-separation.
#
# This script documents the PRE-FIX behavior of the local logistic solver
# on the E2.14 GATE fixture (tests/testthat/test-lps-binary-separation.R).
# It replicates the update equations of .klp.solve.local.logistic as they
# stood at the pre-change commit b86b796 (plain Newton/IRLS: every step
# accepted unconditionally, no deviance control) and records the deviance
# trajectory. It exists because the pre-fix solver had no trace hooks, so
# the defect cannot be demonstrated by calling deleted code; the replica
# mirrors R/lps.R@b86b796 lines 1681-1723 for a singleton rho = 0 with the
# orthogonal design basis.
#
# Run:    Rscript dev/methods/lps/ci/e2_14_prefix_newton_overshoot.R
# Output: dev/methods/lps/runs/tier2/e2_14_prefix_newton_overshoot.csv (per-iteration deviance
#         of the plain-Newton iteration on the near-separable fixture) and
#         a console summary of both fixture arms.
#
# Expected (measured at b86b796, BLAS-dependent only in the last digits):
#   near-separable arm:  deviance INCREASES by ~4.9e2 at step 2, ~8
#                        increases > 1e-8 in 50 iterations, no convergence.
#   exactly-separable arm: monotone decrease, no convergence in 50
#                        iterations (the MLE does not exist), no NaN.
#
# No RNG anywhere: the fixture and the iteration are fully deterministic.

suppressMessages(pkgload::load_all(".", quiet = TRUE))

e214.fixture <- function(flip = TRUE) {
    z <- c(seq(-0.20, -0.04, by = 0.02), 6)
    y <- as.numeric(z > 0)
    if (flip) {
        y[[2L]] <- 1
    }
    weights <- geosmooth:::.klp.kernel.weights(abs(z), "gaussian")
    list(design = cbind(1, z), y = y, weights = weights,
         prediction.row = matrix(c(1, 0), nrow = 1L))
}

# Plain-Newton replica of the pre-fix solver internals (rho = 0, orthogonal
# basis). Returns the per-iteration deviance of every ACCEPTED iterate,
# where pre-fix every Newton candidate was accepted.
prefix.plain.newton <- function(fx, max.iter = 50L, tolerance = 1e-7) {
    transformed <- geosmooth:::.klp.orthogonal.polynomial.transform(
        design = fx$design,
        weights = fx$weights,
        prediction.rows = fx$prediction.row,
        design.drop.tol = 1e-8
    )
    stopifnot(isTRUE(transformed$ok))
    X <- transformed$design
    y <- fx$y
    w <- fx$weights
    deviance.at <- function(beta) {
        eta <- pmax(-35, pmin(35, as.numeric(X %*% beta)))
        mu <- stats::plogis(eta)
        -2 * sum(w * (y * log(mu) + (1 - y) * log1p(-mu)))
    }
    ybar <- stats::weighted.mean(y, w)
    ybar <- min(1 - 1e-6, max(1e-6, ybar))
    beta <- c(stats::qlogis(ybar), rep(0, ncol(X) - 1L))
    trace <- deviance.at(beta)
    converged <- FALSE
    for (iter in seq_len(max.iter)) {
        eta <- as.numeric(X %*% beta)
        mu <- stats::plogis(pmax(-35, pmin(35, eta)))
        variance <- pmax(mu * (1 - mu), 1e-8)
        ww <- w * variance
        zz <- eta + (y - mu) / variance
        xw <- X * sqrt(ww)
        beta.new <- tryCatch(
            as.numeric(solve(crossprod(xw), crossprod(xw, zz * sqrt(ww)))),
            error = function(e) rep(NA_real_, ncol(X))
        )
        if (any(!is.finite(beta.new))) {
            break
        }
        step.converged <- max(abs(beta.new - beta)) <
            tolerance * (1 + max(abs(beta)))
        beta <- beta.new
        trace <- c(trace, deviance.at(beta))
        if (step.converged) {
            converged <- TRUE
            break
        }
    }
    list(trace = trace, converged = converged, beta = beta)
}

summarize.arm <- function(label, run) {
    increases <- diff(run$trace)
    cat(sprintf(
        paste0("%s: iterations=%d converged=%s max.deviance.increase=%.6e ",
               "n.increases.gt.1e-8=%d any.nan=%s\n"),
        label, length(run$trace) - 1L, run$converged,
        max(increases), sum(increases > 1e-8), anyNA(run$trace)
    ))
}

near <- prefix.plain.newton(e214.fixture(flip = TRUE))
exact <- prefix.plain.newton(e214.fixture(flip = FALSE))

cat("E2.14 pre-fix plain-Newton replication (R/lps.R@b86b796 semantics)\n")
summarize.arm("near-separable  (one flipped label)", near)
summarize.arm("exactly-separable (no flipped label)", exact)

dir.create("reports", showWarnings = FALSE)
utils::write.csv(
    data.frame(
        iteration = seq_along(near$trace) - 1L,
        deviance = near$trace
    ),
    "dev/methods/lps/runs/tier2/e2_14_prefix_newton_overshoot.csv",
    row.names = FALSE
)
cat("wrote dev/methods/lps/runs/tier2/e2_14_prefix_newton_overshoot.csv\n")

# Post-fix contrast on the actual solver (for the record; the GATE in
# tests/testthat/test-lps-binary-separation.R asserts these properties):
solved <- geosmooth:::.klp.solve.local.logistic(
    design = e214.fixture(TRUE)$design,
    y = e214.fixture(TRUE)$y,
    weights = e214.fixture(TRUE)$weights,
    design.basis = "orthogonal.polynomial.drop",
    design.drop.tol = 1e-8,
    ridge.multiplier.grid = 0,
    ridge.condition.max = Inf,
    prediction.row = e214.fixture(TRUE)$prediction.row
)
cat(sprintf(
    paste0("post-fix solver on near-separable arm: status=%s converged=%s ",
           "iterations=%s step.halvings=%s max.deviance.increase=%.6e ",
           "prediction=%.6f\n"),
    solved$status, isTRUE(solved$converged),
    solved$iterations, solved$step.halvings,
    max(diff(solved$deviance.trace)), solved$prediction[[1L]]
))
