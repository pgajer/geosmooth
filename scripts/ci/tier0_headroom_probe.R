#!/usr/bin/env Rscript
# =============================================================================
# Tier-0 realized-error / determinism / backend-parity probe
#
# The committed tests only assert `err < tol` (pass/fail). They do not expose
# HOW MUCH headroom there is, whether the result is deterministic, or whether
# the C++ backend agrees with R. This probe captures all three WITHOUT editing
# the committed tests: it re-runs the same case loops (same seeds, same order)
# and records the realized quantities.
#
# It reuses the EXACT committed helper functions by sourcing the test file with
# `test_that` shadowed to a no-op, so only the top-level helper definitions take
# effect and none of the assertions run here.
#
# Usage: Rscript scripts/ci/tier0_headroom_probe.R <OUT_DIR>
# Env:   LPS_NATIVE_BACKEND  native backend token (default: cpp)
# =============================================================================
args   <- commandArgs(trailingOnly = TRUE)
OUT    <- if (length(args) >= 1L) args[[1L]] else "."
NATIVE <- Sys.getenv("LPS_NATIVE_BACKEND", "cpp")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

suppressMessages(pkgload::load_all(".", quiet = TRUE))

# Reuse committed helpers without executing any test_that() body:
test_that <- function(...) invisible(NULL)          # shadow
suppressWarnings(source("tests/testthat/test-lps-tier0-correctness.R", local = TRUE))

kernels <- c("gaussian", "tricube", "epanechnikov", "triangular")
bases   <- c("orthogonal.polynomial.drop", "monomial", "weighted.qr", "weighted.qr.drop")
tol_for <- function(basis) if (identical(basis, "monomial")) 1e-6 else 1e-8

# ---- E0.1 ambient: realized reproduction error + headroom --------------------
# Mirrors the committed test's seed, case order, frozen sample size, and
# compact-kernel boundary support-size floor, so
# the realized errors correspond to the actual gated cases.
set.seed(9101)
cases <- expand.grid(ambient.dim = c(2L, 3L), degree = c(1L, 2L),
                     kernel = kernels, basis = bases, stringsAsFactors = FALSE)
rows <- vector("list", nrow(cases))
for (ii in seq_len(nrow(cases))) {
    cc <- cases[ii, ]
    n  <- 200L
    X  <- matrix(stats::runif(n * cc$ambient.dim, -1, 1), ncol = cc$ambient.dim)
    y  <- tier0.polynomial.truth(X, cc$degree)
    ncols   <- tier0.poly.column.count(cc$ambient.dim, cc$degree)
    support <- min(n - 1L, max(15L, 3L * ncols))
    fit <- tier0.reproduction.fit(X, y, support, cc$degree, cc$kernel, cc$basis)
    err <- max(abs(fit$fitted.values - y), na.rm = TRUE)
    tol <- tol_for(cc$basis)
    rows[[ii]] <- data.frame(
        gate = "E0.1.ambient", ambient.dim = cc$ambient.dim, degree = cc$degree,
        kernel = cc$kernel, basis = cc$basis,
        realized_err = err, tol = tol, headroom_ratio = tol / err,
        any_na = anyNA(fit$fitted.values),
        pass = (err < tol) && !anyNA(fit$fitted.values),
        stringsAsFactors = FALSE)
}
e01 <- do.call(rbind, rows)
write.csv(e01, file.path(OUT, "headroom_e01_ambient.csv"), row.names = FALSE)

# ---- E0.2 ambient: linear-smoother identity + df residuals -------------------
set.seed(9103)
n <- 36L
X <- matrix(stats::runif(2L * n, -1, 1), ncol = 2L)
S <- tier0.extract.smoother.matrix(X)
y1 <- stats::rnorm(n); y2 <- stats::rnorm(n); y3 <- 0.6 * y1 - 1.4 * y2
f1 <- tier0.fixed.lps.fit(X, y1)$fitted.values
f2 <- tier0.fixed.lps.fit(X, y2)$fitted.values
f3 <- tier0.fixed.lps.fit(X, y3)$fitted.values
id_res  <- max(abs(drop(S %*% y1) - f1), abs(drop(S %*% y2) - f2), abs(drop(S %*% y3) - f3))
lin_res <- max(abs(f3 - (0.6 * f1 - 1.4 * f2)))
tr      <- sum(diag(S))
df_bump <- sum(vapply(seq_len(n), function(j) {
    yb <- y1; yb[[j]] <- yb[[j]] + 1
    tier0.fixed.lps.fit(X, yb)$fitted.values[[j]] - f1[[j]]
}, numeric(1L)))
e02 <- data.frame(
    gate = "E0.2.ambient", identity_residual = id_res, linearity_residual = lin_res,
    trace_S = tr, df_bump = df_bump, df_residual = abs(tr - df_bump),
    assert_tol = 1e-10,
    pass = (id_res < 1e-10) && (lin_res < 1e-10) && (abs(tr - df_bump) < 1e-10) &&
           is.finite(tr) && (tr > 0),
    stringsAsFactors = FALSE)
write.csv(e02, file.path(OUT, "headroom_e02_ambient.csv"), row.names = FALSE)

# ---- Determinism: identical config fit twice should match to ~machine eps ----
d1 <- tier0.fixed.lps.fit(X, y1)$fitted.values
d2 <- tier0.fixed.lps.fit(X, y1)$fitted.values
det_max <- max(abs(d1 - d2))

# ---- Backend parity: R vs native, same (X, y, config). Best-effort. ----------
parity <- tryCatch({
    set.seed(424242)
    np <- 70L
    dg <- 1L
    ker <- "tricube"
    # Both native tokens (cpp, cpp.local.pca) require design.basis="monomial",
    # ridge.multiplier.grid=0, and ridge.condition.max=Inf (see .klp.resolve.backend
    # in R/lps.R); any other basis or a finite ridge cap forces the R backend, so
    # the parity check would never actually exercise C++.
    bas <- "monomial"
    if (identical(NATIVE, "cpp.local.pca")) {
        intrinsic.dim <- 2L
        ambient.dim <- 4L
        U <- matrix(stats::runif(np * intrinsic.dim, -1, 1),
                    ncol = intrinsic.dim)
        Q <- tier0.orthonormal.frame(
            ambient.dim = ambient.dim,
            intrinsic.dim = intrinsic.dim,
            seed = 424243L
        )
        Xp <- U %*% t(Q)
        yp <- sin(1.3 * U[, 1L]) + 0.4 * U[, 2L]^2 +
            stats::rnorm(np, sd = 0.03)
        sup <- min(np - 1L, max(12L, 4L * tier0.poly.column.count(intrinsic.dim, dg)))
        one <- function(be) fit.lps(
            X = Xp, y = yp, foldid = rep(1:2, length.out = np),
            support.grid = sup, degree.grid = dg, kernel.grid = ker,
            coordinate.method = "local.pca", chart.dim = intrinsic.dim,
            local.chart.method = "pca",
            backend = be, design.basis = bas, ridge.multiplier.grid = 0,
            ridge.condition.max = Inf, unstable.action = "na")$fitted.values
    } else {
        ad <- 2L
        Xp <- matrix(stats::runif(np * ad, -1, 1), ncol = ad)
        yp <- sin(1.3 * Xp[, 1L]) + 0.4 * Xp[, 2L]^2 +
            stats::rnorm(np, sd = 0.03)
        sup <- min(np - 1L, max(12L, 4L * tier0.poly.column.count(ad, dg)))
        one <- function(be) fit.lps(
            X = Xp, y = yp, foldid = rep(1:2, length.out = np),
            support.grid = sup, degree.grid = dg, kernel.grid = ker,
            coordinate.method = "coordinates", local.chart.method = "pca",
            backend = be, design.basis = bas, ridge.multiplier.grid = 0,
            ridge.condition.max = Inf, unstable.action = "na")$fitted.values
    }
    data.frame(native_backend = NATIVE, status = "ok",
               max_abs_diff = max(abs(one("R") - one(NATIVE))),
               stringsAsFactors = FALSE)
}, error = function(e) data.frame(
    native_backend = NATIVE, status = paste0("unavailable: ", conditionMessage(e)),
    max_abs_diff = NA_real_, stringsAsFactors = FALSE))
write.csv(parity, file.path(OUT, "backend_parity.csv"), row.names = FALSE)

# ---- Summary -----------------------------------------------------------------
summ <- data.frame(
    e01_n = nrow(e01), e01_all_pass = all(e01$pass),
    e01_max_err = max(e01$realized_err), e01_min_headroom = min(e01$headroom_ratio),
    e02_pass = e02$pass, e02_identity_residual = e02$identity_residual,
    e02_df_residual = e02$df_residual, determinism_max_diff = det_max,
    parity_status = parity$status, parity_max_abs_diff = parity$max_abs_diff,
    stringsAsFactors = FALSE)
write.csv(summ, file.path(OUT, "headroom_summary.csv"), row.names = FALSE)

cat(sprintf(
    "E0.1 n=%d all_pass=%s max_err=%.3e min_headroom=%.1fx | E0.2 pass=%s id_res=%.3e df_res=%.3e | determinism=%.3e | parity=%s\n",
    nrow(e01), all(e01$pass), max(e01$realized_err), min(e01$headroom_ratio),
    e02$pass, e02$identity_residual, e02$df_residual, det_max, parity$status))

# Non-zero exit if any probed property is out of tolerance (auditor still rules)
ok <- all(e01$pass) && isTRUE(e02$pass) && det_max < 1e-12
quit(status = if (ok) 0L else 1L)
