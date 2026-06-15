# =============================================================================
# E4.1 headroom/determinism probe (execution-artifact addendum)
#
# Recomputes the Part A gate's realized quantities so the auditor can see the
# margins, not just a pass/fail line:
#   - max |S_analytic - S_probe| over the two gate fixtures (the implemented
#     analytic extraction vs the independent column-by-column public-API
#     probe, the E0.2 protocol), with headroom vs the 1e-10 gate tolerance;
#   - |df - tr(S_probe)|, max |variance - sigma0^2 * rowSums(S_probe^2)|,
#     |sigma.hat^2 - RSS/(n - tr S_probe)|, max |S %*% y - fitted|;
#   - determinism: a repeated analytic extraction must be bitwise identical.
#
# This file mirrors the gate fixtures of
# tests/testthat/test-lps-tier4-uncertainty.R (same seeds, same configuration)
# WITHOUT testthat; the testthat gate remains the authority. Output: one CSV
# row per fixture in the bundle directory plus a single summary line on
# stdout (consumed by the manifest).
#
# Usage: Rscript dev/methods/lps/ci/e4_1_headroom_probe.R <out_dir>
# =============================================================================

suppressMessages(pkgload::load_all(".", quiet = TRUE))

out.dir <- commandArgs(trailingOnly = TRUE)
if (length(out.dir) != 1L) stop("usage: e4_1_headroom_probe.R <out_dir>")

gate.tol <- 1e-10

probe.fixed.fit <- function(X, y, coordinate.method, chart.dim) {
    fit.lps(
        X = X, y = y,
        foldid = rep(1:2, length.out = nrow(X)),
        support.grid = 18L, degree.grid = 1L, kernel.grid = "tricube",
        coordinate.method = coordinate.method, chart.dim = chart.dim,
        local.chart.method = "pca", backend = "R",
        design.basis = "orthogonal.polynomial.drop",
        ridge.multiplier.grid = 0, ridge.condition.max = Inf,
        unstable.action = "na"
    )
}

probe.column.smoother <- function(X, coordinate.method, chart.dim) {
    n <- nrow(X)
    S <- matrix(NA_real_, n, n)
    for (j in seq_len(n)) {
        e.j <- numeric(n)
        e.j[[j]] <- 1
        S[, j] <- probe.fixed.fit(X, e.j, coordinate.method,
                                  chart.dim)$fitted.values
    }
    S
}

probe.case <- function(label, X, y, coordinate.method, chart.dim, sigma0) {
    fit <- probe.fixed.fit(X, y, coordinate.method, chart.dim)
    S.probe <- probe.column.smoother(X, coordinate.method, chart.dim)
    S.impl <- lps.smoother.matrix(fit)
    S.impl.again <- lps.smoother.matrix(fit)
    band <- lps.pointwise.band(fit, sigma = sigma0)
    band.plugin <- lps.pointwise.band(fit)
    n <- nrow(X)
    df.ref <- sum(diag(S.probe))
    rss.ref <- sum((y - fit$fitted.values.raw)^2)
    max.S.diff <- max(abs(S.impl - S.probe))
    data.frame(
        fixture = label,
        n = n,
        max.abs.S.diff = max.S.diff,
        headroom.S = gate.tol / max.S.diff,
        abs.df.diff = abs(band$df - df.ref),
        max.abs.variance.diff =
            max(abs(band$variance - sigma0^2 * rowSums(S.probe^2))),
        abs.sigma.hat.sq.diff =
            abs(band.plugin$sigma.hat^2 - rss.ref / (n - df.ref)),
        max.abs.identity.diff =
            max(abs(as.numeric(S.impl %*% y) - fit$fitted.values.raw)),
        determinism.max.abs.diff = max(abs(S.impl - S.impl.again)),
        df = band$df,
        sigma0 = sigma0,
        sigma.hat = band.plugin$sigma.hat,
        gate.tol = gate.tol
    )
}

set.seed(9401)
n1 <- 42L
X1 <- matrix(stats::runif(2L * n1, -1, 1), ncol = 2L)
y1 <- stats::rnorm(n1)
row1 <- probe.case("ambient.coordinates.D2", X1, y1, "coordinates", NULL,
                   sigma0 = 0.37)

set.seed(9402)
u <- matrix(stats::runif(2L * 34L, -1, 1), ncol = 2L)
X2 <- cbind(u[, 1L], u[, 2L],
            0.25 * u[, 1L]^2 + 0.15 * u[, 2L]^2 - 0.1 * u[, 1L] * u[, 2L])
set.seed(9403)
y2 <- stats::rnorm(34L)
row2 <- probe.case("local.pca.chart2.D3", X2, y2, "local.pca", 2L,
                   sigma0 = 0.37)

probe <- rbind(row1, row2)
utils::write.csv(probe, file.path(out.dir, "e4_1_probe.csv"),
                 row.names = FALSE)
print(probe, row.names = FALSE)

ok <- all(probe$max.abs.S.diff < gate.tol,
          probe$abs.df.diff < gate.tol,
          probe$max.abs.variance.diff < gate.tol,
          probe$abs.sigma.hat.sq.diff < gate.tol,
          probe$max.abs.identity.diff < gate.tol,
          probe$determinism.max.abs.diff == 0)
cat(sprintf(
    "e4_1_probe: %s max_S_diff=%.3e min_headroom=%.1fx determinism=%s\n",
    if (ok) "ok" else "FAIL",
    max(probe$max.abs.S.diff),
    min(probe$headroom.S),
    format(max(probe$determinism.max.abs.diff))
))
quit(status = if (ok) 0L else 1L)
