# =============================================================================
# test-dgp-library.R -- fidelity GATEs for the plan-conformant DGP library
#
# Asserts, per plan G-tag (lps_experimental_plan_2026-06-09.tex, sec:dgp):
#   * standard dataset-object shape/fields (non-manifold common contract);
#   * correct geometry (G3a apex curvature = 1/R; G6 realized prevalence ~ target
#     with p in [0.05, 0.95]; G7 rows sum to 1 with documented zeros; isometry,
#     torus, cylinder, sphere-cap identities);
#   * determinism (same seed -> bitwise-identical output).
# These are deterministic GATEs (spec sec:rng); no Monte-Carlo tolerances.
# =============================================================================

# ---- shared helper: standard-object structural contract --------------------

expect_standard_dataset <- function(ds, gtag, n, p, has_region = FALSE) {
  expect_s3_class(ds, "dgp_dataset")
  required <- c("dataset.id", "gtag", "n", "p", "d", "U", "Z", "X", "truth",
                "y", "sigma", "region", "seed", "params", "provenance")
  expect_true(all(required %in% names(ds)))
  expect_identical(ds$gtag, gtag)
  expect_identical(ds$n, as.integer(n))
  expect_identical(ds$p, as.integer(p))
  expect_true(is.matrix(ds$X) && nrow(ds$X) == n && ncol(ds$X) == p)
  expect_length(ds$truth, n)
  expect_length(ds$y, n)
  expect_true(is.numeric(ds$truth) && is.numeric(ds$y))
  # Z is the documented alias of U (non-manifold spec uses `Z`).
  expect_identical(ds$U, ds$Z)
  if (has_region) {
    expect_false(is.null(ds$region))
    expect_length(ds$region, n)
  }
  expect_true(is.list(ds$params))
}

# Recover the apex principal curvature of a Monge patch z = f(u1, u2) by exact
# quadratic least squares: f_xx = 2 * coef(u1^2). At the apex (grad f = 0) the
# principal curvature equals f_xx.
apex_curvature_u1 <- function(U, z) {
  u1 <- U[, 1]; u2 <- U[, 2]
  cf <- stats::coef(stats::lm(z ~ u1 + u2 + I(u1^2) + I(u2^2) + I(u1 * u2)))
  2 * unname(cf["I(u1^2)"])
}

# =============================================================================
# Shape / fields, every generator
# =============================================================================

test_that("every generator emits the standard dataset object", {
  expect_standard_dataset(dgp.g1(n = 120, seed = 1),  "G1",  120, 2)
  expect_standard_dataset(dgp.g2(n = 120, seed = 1),  "G2",  120, 3)
  expect_standard_dataset(dgp.g3a(n = 120, seed = 1), "G3a", 120, 3)
  expect_standard_dataset(dgp.g3b(n = 120, seed = 1), "G3b", 120, 3)
  expect_standard_dataset(dgp.g3c(n = 120, seed = 1), "G3c", 120, 3)
  expect_standard_dataset(dgp.g3d(n = 120, seed = 1), "G3d", 120, 3)
  expect_standard_dataset(dgp.g4(n = 120, seed = 1),  "G4",  120, 3, has_region = TRUE)
  expect_standard_dataset(dgp.g5(K = 6, m = 20, seed = 1), "G5", 120, 2, has_region = TRUE)
  expect_standard_dataset(dgp.g6(n = 120, seed = 1),  "G6",  120, 2)
  expect_standard_dataset(dgp.g7(n = 120, D = 5, seed = 1), "G7", 120, 5, has_region = TRUE)
})

# =============================================================================
# G1 -- ambient polynomial
# =============================================================================

test_that("G1 truth is the plan's exact degree-2 polynomial; X in [-1,1]^2", {
  ds <- dgp.g1(n = 500, D = 2, sigma = 0, seed = 3)
  x1 <- ds$X[, 1]; x2 <- ds$X[, 2]
  f <- 0.5 + 1.0 * x1 - 0.7 * x2 + 0.4 * x1^2 + 0.3 * x1 * x2 - 0.6 * x2^2
  expect_equal(ds$truth, f, tolerance = 1e-12)
  expect_true(all(ds$X >= -1 & ds$X <= 1))
  # noiseless by default
  expect_equal(ds$y, ds$truth, tolerance = 1e-12)
  # D = 3 without a polynomial is an explicit error, not a silent guess
  expect_error(dgp.g1(n = 10, D = 3, seed = 1), "poly.coef")
})

# =============================================================================
# G2 -- flat embedded subspace (linear isometry)
# =============================================================================

test_that("G2 frame is orthonormal and the embedding is a linear isometry", {
  ds <- dgp.g2(n = 200, d = 2, D = 3, sigma = 0, seed = 5)
  Q <- ds$params$Q
  expect_equal(crossprod(Q), diag(2), tolerance = 1e-10)        # Q^T Q = I
  expect_equal(ds$X, ds$U %*% t(Q), tolerance = 1e-12)          # X = U Q^T
  # linear isometry: pairwise distances preserved between U and X
  sub <- 1:40
  expect_equal(as.matrix(dist(ds$U[sub, ])),
               as.matrix(dist(ds$X[sub, ])), tolerance = 1e-10)
  # truth is the plan polynomial in the intrinsic u
  u1 <- ds$U[, 1]; u2 <- ds$U[, 2]
  f <- 0.5 + 1.0 * u1 - 0.7 * u2 + 0.4 * u1^2 + 0.3 * u1 * u2 - 0.6 * u2^2
  expect_equal(ds$truth, f, tolerance = 1e-12)
})

# =============================================================================
# G3a -- paraboloid: apex principal curvature = 1/R
# =============================================================================

test_that("G3a height is (u1^2+u2^2)/(2R) and apex curvature = 1/R", {
  for (R in c(1, 2, 4, 8)) {
    ds <- dgp.g3a(n = 1500, R = R, truth = "linear", sigma = 0, seed = 10 + R)
    u1 <- ds$U[, 1]; u2 <- ds$U[, 2]
    expect_equal(ds$X[, 3], (u1^2 + u2^2) / (2 * R), tolerance = 1e-12)
    expect_equal(apex_curvature_u1(ds$U, ds$X[, 3]), 1 / R, tolerance = 1e-6)
    expect_equal(ds$params$kappa, 1 / R, tolerance = 1e-12)
    # disk footprint of radius rho0 = 1
    expect_true(max(sqrt(u1^2 + u2^2)) <= 1 + 1e-12)
    # f_lin = u1 exactly
    expect_equal(ds$truth, u1, tolerance = 1e-12)
  }
  # smooth truth option
  ds2 <- dgp.g3a(n = 100, truth = "smooth", sigma = 0, seed = 1)
  expect_equal(ds2$truth, sin(pi * ds2$U[, 1]) * cos(pi * ds2$U[, 2]),
               tolerance = 1e-12)
})

# =============================================================================
# G3b -- sphere cap: constant Gaussian curvature 1/R^2, cap identity
# =============================================================================

test_that("G3b lies on the sphere cap with constant curvature 1/R^2", {
  R <- 3; rho0 <- 1
  ds <- dgp.g3b(n = 800, R = R, rho0 = rho0, sigma = 0, seed = 7)
  u1 <- ds$U[, 1]; u2 <- ds$U[, 2]; z <- ds$X[, 3]
  rr <- u1^2 + u2^2
  expect_equal(z, R - sqrt(R^2 - rr), tolerance = 1e-12)
  # points sit on the sphere of radius R centred at (0,0,R): x1^2+x2^2+(z-R)^2=R^2
  expect_equal(u1^2 + u2^2 + (z - R)^2, rep(R^2, length(z)), tolerance = 1e-10)
  expect_equal(ds$params$gaussian.curvature, 1 / R^2, tolerance = 1e-12)
  expect_true(max(sqrt(rr)) <= rho0 + 1e-12 && rho0 < R)
  expect_error(dgp.g3b(n = 10, R = 1, rho0 = 2, seed = 1))   # rho0 < R required
})

# =============================================================================
# G3c -- helix on the unit cylinder
# =============================================================================

test_that("G3c is a helix: x1^2+x2^2 = 1 and x3 = c t", {
  cc <- 0.3
  ds <- dgp.g3c(n = 400, c = cc, sigma = 0, seed = 2)
  t <- ds$U[, 1]
  expect_equal(ds$X[, 1]^2 + ds$X[, 2]^2, rep(1, ds$n), tolerance = 1e-12)
  expect_equal(ds$X[, 3], cc * t, tolerance = 1e-12)
  expect_true(all(t >= 0 & t < 2 * pi))
})

# =============================================================================
# G3d -- torus patch identity
# =============================================================================

test_that("G3d lies on the torus (sqrt(x1^2+x2^2)-R1)^2 + x3^2 = R2^2", {
  R1 <- 1; R2 <- 0.35
  ds <- dgp.g3d(n = 600, R1 = R1, R2 = R2, sigma = 0, seed = 4)
  rho <- sqrt(ds$X[, 1]^2 + ds$X[, 2]^2)
  expect_equal((rho - R1)^2 + ds$X[, 3]^2, rep(R2^2, ds$n), tolerance = 1e-12)
  # angles drawn on the sub-rectangle (no wrap-around)
  expect_true(all(ds$U[, 1] >= -pi/2 & ds$U[, 1] <= pi/2))
  expect_true(all(ds$U[, 2] >= -pi/2 & ds$U[, 2] <= pi/2))
})

# =============================================================================
# G4 -- stratified / varying dimension
# =============================================================================

test_that("G4 has a 1-D stratum A and a 2-D stratum B with correct structure", {
  ds <- dgp.g4(n = 400, fracA = 0.5, eta = 0.02, sigma = 0, seed = 6)
  expect_setequal(unique(ds$region), c("A", "B"))
  A <- ds$region == "A"; B <- ds$region == "B"
  # stratum B lies in the z = 0 plane
  expect_true(all(abs(ds$X[B, 3]) < 1e-12))
  # stratum A is the segment t in [-1,0] thickened transversally by eta (small)
  expect_true(all(ds$X[A, 1] >= -1 - 1e-9 & ds$X[A, 1] <= 0 + 1e-9))
  expect_lt(stats::sd(ds$X[A, 2]), 0.2)   # transverse spread ~ eta, not O(1)
  expect_identical(ds$params$dim.by.region, c(A = 1L, B = 2L))
})

# =============================================================================
# G5 -- clustered / repeated measures
# =============================================================================

test_that("G5 has n=K*m, exact ICC, and truth excludes the random effect", {
  K <- 30; m <- 25; rho <- 0.6; sigma <- 0.1
  ds <- dgp.g5(K = K, m = m, rho = rho, sigma = sigma, seed = 8)
  expect_identical(ds$n, as.integer(K * m))
  tau <- ds$params$tau
  expect_equal(tau^2 / (tau^2 + sigma^2), rho, tolerance = 1e-12)
  # truth is g(x) only (random effect b_k lives in params, added into y)
  g <- sin(pi * ds$X[, 1]) * cos(pi * ds$X[, 2])
  expect_equal(ds$truth, g, tolerance = 1e-12)
  expect_length(ds$params$b, K)
  expect_length(unique(ds$region), K)
})

# =============================================================================
# G6 -- binary surface: prevalence and clipping
# =============================================================================

test_that("G6 realizes the target prevalence with p in [0.05,0.95]", {
  ds <- dgp.g6(n = 4000, prevalence = 0.4, seed = 11)
  expect_true(all(ds$truth >= 0.05 - 1e-12 & ds$truth <= 0.95 + 1e-12))
  expect_lt(abs(mean(ds$truth) - 0.4), 0.03)         # realized ~ target
  expect_true(all(ds$y %in% c(0L, 1L)))
  expect_true(is.na(ds$sigma))                        # binary: no sd
  # a second target
  ds2 <- dgp.g6(n = 4000, prevalence = 0.6, seed = 12)
  expect_lt(abs(mean(ds2$truth) - 0.6), 0.03)
})

# =============================================================================
# G7 -- compositional / structural zeros
# =============================================================================

test_that("G7 rows sum to 1 with exact documented structural zeros", {
  ds <- dgp.g7(n = 300, D = 5, zero.fraction = 0.5, zero.parts = 5, seed = 5)
  expect_equal(rowSums(ds$X), rep(1, ds$n), tolerance = 1e-12)
  zr <- ds$region == "zero"
  expect_true(all(ds$X[zr, 5] == 0))                 # exact zeros, the doc'd part
  expect_true(all(ds$X[!zr, 5] > 0))                 # interior keeps all parts
  expect_equal(sum(zr), ds$params$n.zero)
  # a multi-part zero pattern
  ds2 <- dgp.g7(n = 200, D = 6, zero.parts = c(5L, 6L), zero.fraction = 0.3,
                seed = 9)
  expect_equal(rowSums(ds2$X), rep(1, ds2$n), tolerance = 1e-12)
  zr2 <- ds2$region == "zero"
  expect_true(all(ds2$X[zr2, c(5, 6)] == 0))
})

# =============================================================================
# Determinism -- same seed -> bitwise-identical output (spec sec:rng)
# =============================================================================

test_that("every generator is deterministic for a fixed seed", {
  calls <- list(
    G1  = function() dgp.g1(n = 100, seed = 4),
    G2  = function() dgp.g2(n = 100, seed = 4),
    G3a = function() dgp.g3a(n = 100, seed = 4),
    G3b = function() dgp.g3b(n = 100, seed = 4),
    G3c = function() dgp.g3c(n = 100, seed = 4),
    G3d = function() dgp.g3d(n = 100, seed = 4),
    G4  = function() dgp.g4(n = 100, seed = 4),
    G5  = function() dgp.g5(K = 5, m = 20, seed = 4),
    G6  = function() dgp.g6(n = 100, seed = 4),
    G7  = function() dgp.g7(n = 100, seed = 4))
  for (tag in names(calls)) {
    a <- calls[[tag]](); b <- calls[[tag]]()
    expect_identical(a$X, b$X, info = tag)
    expect_identical(a$truth, b$truth, info = tag)
    expect_identical(a$y, b$y, info = tag)
    expect_identical(a$U, b$U, info = tag)
    expect_identical(a$region, b$region, info = tag)
  }
})

test_that("different seeds produce different draws", {
  a <- dgp.g3a(n = 200, seed = 1)
  b <- dgp.g3a(n = 200, seed = 2)
  expect_false(isTRUE(all.equal(a$X, b$X)))
  expect_false(isTRUE(all.equal(a$y, b$y)))
})

# =============================================================================
# Materialization round-trip and content checksum
# =============================================================================

test_that("dgp.materialize round-trips the direct generator call", {
  args <- list(n = 200, R = 2, truth = "linear", sigma = 0, seed = 1)
  direct <- dgp.g3a(n = 200, R = 2, truth = "linear", sigma = 0, seed = 1)
  via <- dgp.materialize("G3a", args)
  expect_identical(direct$X, via$X)
  expect_identical(direct$truth, via$truth)
  expect_identical(direct$y, via$y)
  expect_error(dgp.materialize("G9", list()), "Unknown G-tag")
})

test_that("dgp.content.sha256 is reproducible and seed-sensitive", {
  skip_if_not_installed("digest")
  s1 <- dgp.content.sha256(dgp.g3a(n = 200, seed = 1))
  s2 <- dgp.content.sha256(dgp.g3a(n = 200, seed = 1))
  s3 <- dgp.content.sha256(dgp.g3a(n = 200, seed = 2))
  expect_identical(s1, s2)
  expect_false(identical(s1, s3))
  expect_match(s1, "^[0-9a-f]{64}$")
})
