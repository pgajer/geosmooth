# E2.13 — pre-change reference fits for the S A2 backward-compat GATE
#
# Generates full-precision reference values of DEFAULT-configuration fits
# (default ridge grid c(0, 1e-10, 1e-8), default design.basis
# "orthogonal.polynomial.drop", default ridge.condition.max 1e12, R
# backend) on two deterministic fixtures (gaussian and bernoulli -- the two
# families whose solves go through the WLS ridge E2.13 touches). The E2.13
# GATE (tests/testthat/test-lps-ridge-alignment.R) asserts that post-change
# fits with the default ridge.shrinkage.target = "zero" reproduce these
# values EXACTLY (17-significant-digit round trip, which is lossless for
# doubles), pinning that the default path is bit-for-bit unchanged -- the
# pin that protects Tier-0 and E1.9 (S G4 resolution,
# project_briefs/lps_g4_ridge_resolution_2026-06-12.md).
#
# DISCIPLINE: run this script ONLY on a tree whose R/lps.R predates the
# E2.13 source change. The generating commit is recorded inside the output.
# Reference file: reports/e2_13_reference_fits.csv (committed).
#
# Run from the package root:
#   Rscript validation/e2_13_pin_reference_fits.R

suppressMessages(pkgload::load_all(".", quiet = TRUE))

git.head <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)

# Fixture G1-style (plan S sec:dgp G1): D = 2, n = 150, degree-2 truth,
# mild noise sd 0.1 (the same fixture family the E2.13 GATE uses).
make.g1 <- function(n = 150L, seed = 1301L, noise.sd = 0.1) {
    set.seed(seed)
    X <- matrix(stats::runif(n * 2L, -1, 1), ncol = 2L)
    truth <- 0.5 + 1.0 * X[, 1L] - 0.7 * X[, 2L] + 0.4 * X[, 1L]^2 +
        0.3 * X[, 1L] * X[, 2L] - 0.6 * X[, 2L]^2
    y <- truth + stats::rnorm(n, sd = noise.sd)
    list(X = X, y = y, truth = truth)
}

g <- make.g1()
fit.gaussian <- fit.lps(
    X = g$X, y = g$y, foldid = rep(1:5, length.out = 150L),
    support.grid = c(20L, 30L), degree.grid = c(0L, 1L),
    kernel.grid = "gaussian", coordinate.method = "coordinates",
    backend = "R"
    # everything else at package defaults: design.basis
    # "orthogonal.polynomial.drop", ridge.multiplier.grid c(0,1e-10,1e-8),
    # ridge.condition.max 1e12, unstable.action "na",
    # outcome.family "gaussian"
)

set.seed(1302L)
p <- pmin(pmax(stats::plogis(2 * g$X[, 1L]), 0.05), 0.95)
y.bin <- stats::rbinom(150L, 1L, p)
fit.bernoulli <- fit.lps(
    X = g$X, y = y.bin, foldid = rep(1:5, length.out = 150L),
    support.grid = c(20L, 30L), degree.grid = c(0L, 1L),
    kernel.grid = "gaussian", coordinate.method = "coordinates",
    backend = "R", outcome.family = "bernoulli"
)

rows <- rbind(
    data.frame(family = "gaussian", quantity = "fitted",
               index = seq_along(fit.gaussian$fitted.values),
               value17 = sprintf("%.17g", fit.gaussian$fitted.values)),
    data.frame(family = "gaussian", quantity = "cv.rmse.observed",
               index = seq_len(nrow(fit.gaussian$cv.table)),
               value17 = sprintf("%.17g",
                                 fit.gaussian$cv.table$cv.rmse.observed)),
    data.frame(family = "bernoulli", quantity = "fitted",
               index = seq_along(fit.bernoulli$fitted.values),
               value17 = sprintf("%.17g", fit.bernoulli$fitted.values)),
    data.frame(family = "bernoulli", quantity = "cv.brier.observed",
               index = seq_len(nrow(fit.bernoulli$cv.table)),
               value17 = sprintf("%.17g",
                                 fit.bernoulli$cv.table$cv.brier.observed))
)
rows$generated.at.commit <- git.head

dir.create("reports", showWarnings = FALSE)
utils::write.csv(rows, "reports/e2_13_reference_fits.csv",
                 row.names = FALSE)
cat("wrote reports/e2_13_reference_fits.csv at commit", git.head, "\n")
cat("selected (gaussian): support", fit.gaussian$selected$support.size,
    "degree", fit.gaussian$selected$degree, "\n")
cat("selected (bernoulli): support", fit.bernoulli$selected$support.size,
    "degree", fit.bernoulli$selected$degree, "\n")
