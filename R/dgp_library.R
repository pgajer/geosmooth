# =============================================================================
# dgp_library.R -- Plan-conformant data-generating processes (DGP library)
#
# Contract: LPS Tiers 1-4, Amendment 1 (consolidate the DGP library).
#   dev/methods/lps/audit_contracts/lps_tiers1to4_contract_2026-06-11.md
# Frozen science spec (the EXACT G1-G7 definitions matched here): see
#   dev/methods/lps/specs/lps_experimental_plan_2026-06-09.tex
#   (section \label{sec:dgp}).
# Standard dataset-object common contract: see
#   dev/notes/migration/split_handoffs_retained/selected_files/
#   lps_local_auto_nonmanifold_dataset_specs_2026-06-05.md
#
# This module exposes ONE exported generator per plan G-tag. Each generator
# returns the standard dataset object (see `.dgp.dataset`) and materializes the
# plan's exact parametrization -- not a hand-rolled variant. Existing assets are
# CONSOLIDATED (the geometry math is vendored with provenance below), not forked.
#
# Provenance of vendored / adapted code (read, then vendored for self-containment
# instead of fragile cross-repo source()):
#   * quadform graph embedding math (`.dgp.quadform.*`) is adapted from
#       ~/current_projects/gflow/R/quadform_geodesics.R
#       (`.quadform.signs`, `.validate.quadform.coefficients`, `.quadform.value`,
#        `quadform.embed`). The heavy geodesic-distance machinery of
#        `quadform.sample.dataset()` is intentionally NOT vendored: the plan's
#        G3a/G3d only need the graph embedding F(u)=(u, q(u)).
#   * the flat / quadform dataset skeleton and the seed-then-noise discipline
#       follow ~/current_projects/trend_filtering/development/ssrhe_hessian_energy/
#       ssrhe_order3_l1_validation_helpers.R
#       (`make.flat.dataset`, `make.quadform.dataset`, `make.random`, `add.noise`).
#   * the G6 prevalence-offset solve (uniroot on the mean expit) follows
#       geosmooth scripts/lps_binary_gm_ff_helpers.R (`probability.profile`),
#       reduced to the plan's exact G6 definition.
#   * geosmooth `2d_curved_paraboloid` / `2d_curved_saddle` blocks
#       (scripts/lps_binary_gm_ff_helpers.R `make.geometry`) are the geosmooth-
#       local provenance for the paraboloid/saddle embeddings; the plan G3a/G3d
#       parametrizations differ (disk vs LHS square; explicit curvature knob;
#       torus for G3d) and are implemented to spec here.
#
# RNG discipline (spec sec:rng): every generator draws its geometry/latent
# immediately after `set.seed(seed)`, and draws response noise immediately after
# `set.seed(seed + .DGP.NOISE.OFFSET)`. A generator is therefore a pure function
# of its arguments: same seed -> bitwise-identical output (asserted by the
# determinism tests). Replicate r of a study uses `seed = s0 + r` (caller's job).
# =============================================================================

# Offsets that separate independent random streams within one generator. Kept
# stable so registry checksums are reproducible. Do not change without re-freezing
# the registry.
.DGP.NOISE.OFFSET <- 900000L   # response-noise stream (matches vendored helpers)
.DGP.FRAME.OFFSET <- 500000L   # G2 random-frame stream

# -----------------------------------------------------------------------------
# Standard dataset object
# -----------------------------------------------------------------------------

#' Construct a standard DGP dataset object
#'
#' Internal constructor for the standard dataset object consumed by every
#' Tiers 1-4 STUDY. The field set is the common contract from the non-manifold
#' dataset spec (intrinsic `U`/`Z`, observed `X`, noiseless `truth`, noisy `y`,
#' `sigma`, `seed`, region labels) plus provenance.
#'
#' @param dataset.id Character scalar identifier.
#' @param gtag Character scalar plan G-tag (e.g. "G3a").
#' @param geometry.family Character scalar, human-readable family.
#' @param X Numeric matrix, observed ambient coordinates (n x p).
#' @param truth Numeric length-n vector, noiseless `f` (for G6, the probability).
#' @param y Numeric length-n vector, noisy response (for G6, the Bernoulli draw).
#' @param sigma Numeric noise standard deviation (`NA_real_` for binary G6).
#' @param seed Integer seed that materializes this object.
#' @param U Numeric matrix or `NULL`, intrinsic / latent coordinates.
#' @param region Character/factor length-n region labels or `NULL`.
#' @param params Named list of generator parameters.
#' @param d Integer intrinsic dimension or `NA_integer_` when it varies by region.
#' @param provenance Named list of binding / provenance facts.
#' @return A list of class `"dgp_dataset"`.
#' @keywords internal
.dgp.dataset <- function(dataset.id, gtag, geometry.family, X, truth, y, sigma,
                         seed, U = NULL, region = NULL, params = list(),
                         d = NA_integer_, provenance = list()) {
  X <- as.matrix(X)
  storage.mode(X) <- "double"
  n <- nrow(X)
  stopifnot(length(truth) == n, length(y) == n)
  if (!is.null(U)) {
    U <- as.matrix(U)
    storage.mode(U) <- "double"
    stopifnot(nrow(U) == n)
  }
  if (!is.null(region)) {
    region <- as.character(region)
    stopifnot(length(region) == n)
  }
  obj <- list(
    dataset.id = as.character(dataset.id),
    gtag = as.character(gtag),
    geometry.family = as.character(geometry.family),
    n = as.integer(n),
    p = as.integer(ncol(X)),
    d = as.integer(d),
    U = U,
    Z = U,                       # alias: non-manifold spec uses `Z` for latent
    X = X,
    truth = as.numeric(truth),
    y = as.numeric(y),
    sigma = as.numeric(sigma),
    region = region,
    seed = as.integer(seed),
    params = params,
    provenance = utils::modifyList(
      list(gtag = as.character(gtag),
           plan.ref = "lps_experimental_plan_2026-06-09.tex:sec:dgp",
           geosmooth.version = tryCatch(
             as.character(utils::packageVersion("geosmooth")),
             error = function(e) NA_character_)),
      provenance)
  )
  class(obj) <- c("dgp_dataset", "list")
  obj
}

#' Print a standard DGP dataset object
#'
#' @param x A `dgp_dataset`.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @method print dgp_dataset
#' @export
print.dgp_dataset <- function(x, ...) {
  cat(sprintf("<dgp_dataset> %s  [%s: %s]\n", x$dataset.id, x$gtag,
              x$geometry.family))
  cat(sprintf("  n=%d  p=%d  d=%s  sigma=%s  seed=%d\n",
              x$n, x$p, ifelse(is.na(x$d), "varies", as.character(x$d)),
              ifelse(is.na(x$sigma), "NA(binary)", format(x$sigma)), x$seed))
  if (!is.null(x$region)) {
    tb <- table(x$region)
    cat("  regions: ", paste(sprintf("%s=%d", names(tb), as.integer(tb)),
                             collapse = ", "), "\n", sep = "")
  }
  invisible(x)
}

# -----------------------------------------------------------------------------
# Vendored geometry math (adapted from gflow/R/quadform_geodesics.R)
# -----------------------------------------------------------------------------

# Signs of the quadratic form: +1 on the first `index.k` axes, -1 after.
.dgp.quadform.signs <- function(p, index.k) {
  stopifnot(index.k >= 0L, index.k <= p)
  c(rep.int(1, index.k), rep.int(-1, p - index.k))
}

# Graph embedding F(u) = (u, q(u)) with q(u) = sum_i s_i c_i u_i^2.
# Last column named "q". Adapted from `quadform.embed` / `.quadform.value`.
.dgp.quadform.embed <- function(U, index.k, coefficients) {
  U <- as.matrix(U)
  signs <- .dgp.quadform.signs(ncol(U), index.k)
  stopifnot(length(coefficients) == ncol(U), all(is.finite(coefficients)))
  q <- as.numeric((U^2) %*% (signs * coefficients))
  cbind(U, q = q)
}

# -----------------------------------------------------------------------------
# Shared latent / truth / noise helpers
# -----------------------------------------------------------------------------

# Uniform sample on the disk of radius rho0 in R^2 (exact, n points), via the
# radial transform r = rho0 sqrt(u), theta = 2 pi v. Caller sets the seed.
.dgp.sample.disk <- function(n, rho0) {
  u <- stats::runif(n)
  v <- stats::runif(n)
  r <- rho0 * sqrt(u)
  theta <- 2 * pi * v
  cbind(r * cos(theta), r * sin(theta))
}

# A fixed random orthonormal frame Q in R^{D x d} (orthonormal columns), via QR
# of a Gaussian matrix. Caller sets the seed.
.dgp.orthonormal.frame <- function(D, d) {
  M <- matrix(stats::rnorm(D * d), nrow = D, ncol = d)
  qr.Q(qr(M))[, seq_len(d), drop = FALSE]
}

# Plan G1 default truth: the explicit degree-2 polynomial in 2 variables,
#   f(x) = 0.5 + 1.0 x1 - 0.7 x2 + 0.4 x1^2 + 0.3 x1 x2 - 0.6 x2^2.
# (spec sec:dgp, G1, D=2 p=2). Used by G1 (in x) and G2 (in intrinsic u).
.dgp.poly2.plan <- c(b0 = 0.5, b1 = 1.0, b2 = -0.7,
                     b11 = 0.4, b12 = 0.3, b22 = -0.6)
.dgp.truth.poly2 <- function(U, coef = .dgp.poly2.plan) {
  x1 <- U[, 1]; x2 <- U[, 2]
  as.numeric(coef["b0"] + coef["b1"] * x1 + coef["b2"] * x2 +
               coef["b11"] * x1^2 + coef["b12"] * x1 * x2 + coef["b22"] * x2^2)
}

# Add homoskedastic Gaussian noise on its own seed stream. sigma == 0 returns
# truth unchanged (noiseless), with no draw consumed.
.dgp.add.gaussian.noise <- function(truth, sigma, seed) {
  if (is.na(sigma) || sigma == 0) return(as.numeric(truth))
  set.seed(seed + .DGP.NOISE.OFFSET)
  as.numeric(truth) + stats::rnorm(length(truth), sd = sigma)
}

# Resolve a "linear" vs "smooth" intrinsic truth on 2-D latent coordinates.
#   f_lin(u)   = u1                       (isolates curvature bias; spec G3a)
#   f_smooth(u)= sin(pi u1) cos(pi u2)
.dgp.truth.intrinsic2 <- function(U, truth = c("smooth", "linear")) {
  truth <- match.arg(truth)
  if (identical(truth, "linear")) return(as.numeric(U[, 1]))
  as.numeric(sin(pi * U[, 1]) * cos(pi * U[, 2]))
}

# =============================================================================
# G1 -- ambient polynomial
# =============================================================================

#' G1 -- ambient polynomial dataset
#'
#' Plan G1 (spec sec:dgp). Ambient \eqn{D\in\{2,3\}}; \eqn{X_i \sim
#' \mathrm{Unif}([-1,1]^D)}; truth a fixed polynomial of degree `p`. For the
#' pinned default \eqn{D=2, p=2} the truth is the plan's explicit polynomial
#' \eqn{f(x)=0.5+1.0x_1-0.7x_2+0.4x_1^2+0.3x_1x_2-0.6x_2^2}. Noiseless unless
#' `sigma > 0`. Intrinsic coordinates equal the ambient coordinates (`U = X`).
#'
#' @param n Positive integer sample size.
#' @param D Ambient dimension (2 or 3). Only `D = 2` carries the plan's pinned
#'   default polynomial; for `D = 3` supply `poly.coef`.
#' @param degree Polynomial degree `p` (informational; the pinned truth is the
#'   plan's degree-2 polynomial).
#' @param sigma Noise standard deviation. Default `0` (noiseless, as in the plan).
#' @param poly.coef Optional named coefficient vector overriding the default
#'   `b0,b1,b2,b11,b12,b22`. Required when `D = 3`.
#' @param seed Integer seed.
#' @return A `dgp_dataset` (see `.dgp.dataset`).
#' @export
dgp.g1 <- function(n = 600L, D = 2L, degree = 2L, sigma = 0,
                   poly.coef = NULL, seed = 1L) {
  D <- as.integer(D)
  stopifnot(D %in% c(2L, 3L), n >= 1L)
  set.seed(seed)
  X <- matrix(stats::runif(n * D, -1, 1), ncol = D)
  if (D == 2L) {
    coef <- if (is.null(poly.coef)) .dgp.poly2.plan else poly.coef
    truth <- .dgp.truth.poly2(X, coef)
  } else {
    if (is.null(poly.coef)) {
      stop("dgp.g1: D = 3 has no plan-pinned polynomial; supply poly.coef ",
           "(named b0,b1,b2,b3,b11,b12,b13,b22,b23,b33).", call. = FALSE)
    }
    co <- poly.coef
    x1 <- X[, 1]; x2 <- X[, 2]; x3 <- X[, 3]
    truth <- as.numeric(co["b0"] + co["b1"]*x1 + co["b2"]*x2 + co["b3"]*x3 +
                          co["b11"]*x1^2 + co["b12"]*x1*x2 + co["b13"]*x1*x3 +
                          co["b22"]*x2^2 + co["b23"]*x2*x3 + co["b33"]*x3^2)
  }
  y <- .dgp.add.gaussian.noise(truth, sigma, seed)
  .dgp.dataset(
    dataset.id = sprintf("G1-D%d-n%d-s%g-seed%d", D, n, sigma, seed),
    gtag = "G1", geometry.family = sprintf("%dD ambient polynomial", D),
    X = X, truth = truth, y = y, sigma = sigma, seed = seed,
    U = X, d = D,
    params = list(D = D, degree = as.integer(degree), sigma = sigma,
                  poly.coef = if (D == 2L && is.null(poly.coef)) .dgp.poly2.plan
                  else poly.coef),
    provenance = list(generator = "dgp.g1",
                      bound.to = "make.flat.dataset (ssrhe helpers) + plan polynomial truth"))
}

# =============================================================================
# G2 -- flat embedded subspace
# =============================================================================

#' G2 -- flat embedded subspace dataset
#'
#' Plan G2 (spec sec:dgp). Intrinsic `d`, ambient `D > d`. Latent
#' \eqn{u_i \sim \mathrm{Unif}([-1,1]^d)}; a fixed random orthonormal
#' \eqn{Q \in \mathbb{R}^{D\times d}} (seed recorded); \eqn{X_i = Q u_i}. Truth a
#' degree-`p` polynomial in the intrinsic `u` (the plan's degree-2 polynomial for
#' `d = 2`). The embedding is a linear isometry, so a degree-`p` chart fit
#' reproduces `f` exactly.
#'
#' @param n Positive integer sample size.
#' @param d Intrinsic dimension (default 2; the pinned polynomial truth needs `d = 2`).
#' @param D Ambient dimension, `D > d` (default 3).
#' @param sigma Noise standard deviation. Default `0`.
#' @param seed Integer seed for the latent draw and noise.
#' @param frame.seed Integer seed for the orthonormal frame `Q` (recorded in
#'   `params$Q` and `params$frame.seed`). Default `seed + .DGP.FRAME.OFFSET`.
#' @param poly.coef Optional named coefficient override (needs `d = 2`).
#' @return A `dgp_dataset`; `U` holds the intrinsic `u`, `params$Q` the frame.
#' @export
dgp.g2 <- function(n = 600L, d = 2L, D = 3L, sigma = 0, seed = 1L,
                   frame.seed = NULL, poly.coef = NULL) {
  d <- as.integer(d); D <- as.integer(D)
  stopifnot(D > d, d >= 1L, n >= 1L)
  if (d != 2L && is.null(poly.coef)) {
    stop("dgp.g2: only d = 2 carries the plan-pinned polynomial; supply ",
         "poly.coef for other d.", call. = FALSE)
  }
  if (is.null(frame.seed)) frame.seed <- seed + .DGP.FRAME.OFFSET
  set.seed(as.integer(frame.seed))
  Q <- .dgp.orthonormal.frame(D, d)
  set.seed(seed)
  U <- matrix(stats::runif(n * d, -1, 1), ncol = d)
  X <- U %*% t(Q)
  coef <- if (is.null(poly.coef)) .dgp.poly2.plan else poly.coef
  truth <- .dgp.truth.poly2(U, coef)
  y <- .dgp.add.gaussian.noise(truth, sigma, seed)
  .dgp.dataset(
    dataset.id = sprintf("G2-d%d-D%d-n%d-s%g-seed%d", d, D, n, sigma, seed),
    gtag = "G2", geometry.family = sprintf("%d-D flat subspace in R^%d", d, D),
    X = X, truth = truth, y = y, sigma = sigma, seed = seed,
    U = U, d = d,
    params = list(d = d, D = D, sigma = sigma, frame.seed = as.integer(frame.seed),
                  Q = Q, poly.coef = coef),
    provenance = list(generator = "dgp.g2",
                      bound.to = "flat helper + fixed random orthonormal frame Q"))
}

# =============================================================================
# G3a -- paraboloid (known curvature)
# =============================================================================

#' G3a -- paraboloid with known curvature
#'
#' Plan G3a (spec sec:dgp). \eqn{d=2, D=3}. \eqn{u \sim \mathrm{Unif}} on the disk
#' of radius \eqn{\rho_0 = 1}; \eqn{X = (u_1, u_2, (u_1^2+u_2^2)/(2R))}. The
#' principal curvature at the apex is \eqn{\kappa = 1/R}; `R` is the curvature
#' knob. Truth options: `f_lin(u) = u1` (intrinsic-linear, isolates curvature
#' bias) and `f_smooth(u) = sin(pi u1) cos(pi u2)`.
#'
#' The height column is built with the vendored quadform embedding using
#' `index.k = 2` and `coefficients = c(1/(2R), 1/(2R))`, so
#' \eqn{q(u) = (u_1^2+u_2^2)/(2R)} exactly.
#'
#' @param n Positive integer sample size.
#' @param R Curvature knob (apex principal curvature is `1/R`). Default 1.
#' @param truth `"smooth"` or `"linear"`.
#' @param sigma Noise standard deviation. Default `0.1`.
#' @param rho0 Disk radius. Default 1 (the plan value).
#' @param seed Integer seed.
#' @return A `dgp_dataset`; `U` holds the disk latent `u`.
#' @export
dgp.g3a <- function(n = 600L, R = 1, truth = c("smooth", "linear"),
                    sigma = 0.1, rho0 = 1, seed = 1L) {
  truth.kind <- match.arg(truth)
  stopifnot(R > 0, rho0 > 0, n >= 1L)
  set.seed(seed)
  U <- .dgp.sample.disk(n, rho0)
  X <- .dgp.quadform.embed(U, index.k = 2L,
                           coefficients = c(1 / (2 * R), 1 / (2 * R)))
  colnames(X) <- c("x1", "x2", "x3")
  truth.vec <- .dgp.truth.intrinsic2(U, truth.kind)
  y <- .dgp.add.gaussian.noise(truth.vec, sigma, seed)
  .dgp.dataset(
    dataset.id = sprintf("G3a-R%g-%s-n%d-s%g-seed%d", R, truth.kind, n, sigma, seed),
    gtag = "G3a", geometry.family = "paraboloid (known curvature)",
    X = X, truth = truth.vec, y = y, sigma = sigma, seed = seed,
    U = U, d = 2L,
    params = list(R = R, kappa = 1 / R, rho0 = rho0, truth = truth.kind,
                  sigma = sigma),
    provenance = list(generator = "dgp.g3a",
                      bound.to = "quadform.embed (gflow) + 2d_curved_paraboloid (geosmooth); plan disk + curvature knob"))
}

# =============================================================================
# G3b -- sphere cap (constant curvature)
# =============================================================================

#' G3b -- sphere cap with constant curvature
#'
#' Plan G3b (spec sec:dgp). \eqn{d=2, D=3}. A cap of a sphere of radius `R`:
#' latent \eqn{u \sim \mathrm{Unif}} on the planar disk \eqn{\lVert u\rVert \le
#' \rho_0 < R}, with \eqn{X = (u_1, u_2, R - \sqrt{R^2 - \lVert u\rVert^2})}.
#' Constant Gaussian curvature \eqn{1/R^2}. Truth options as in G3a.
#'
#' @param n Positive integer sample size.
#' @param R Sphere radius (`rho0 < R` required). Default 2.
#' @param rho0 Disk radius of the cap footprint. Default 1.
#' @param truth `"smooth"` or `"linear"`.
#' @param sigma Noise standard deviation. Default `0.1`.
#' @param seed Integer seed.
#' @return A `dgp_dataset`; `U` holds the disk latent `u`.
#' @export
dgp.g3b <- function(n = 600L, R = 2, rho0 = 1, truth = c("smooth", "linear"),
                    sigma = 0.1, seed = 1L) {
  truth.kind <- match.arg(truth)
  stopifnot(R > 0, rho0 > 0, rho0 < R, n >= 1L)
  set.seed(seed)
  U <- .dgp.sample.disk(n, rho0)
  rr <- rowSums(U^2)
  height <- R - sqrt(R^2 - rr)
  X <- cbind(U, x3 = height)
  colnames(X) <- c("x1", "x2", "x3")
  truth.vec <- .dgp.truth.intrinsic2(U, truth.kind)
  y <- .dgp.add.gaussian.noise(truth.vec, sigma, seed)
  .dgp.dataset(
    dataset.id = sprintf("G3b-R%g-rho%g-%s-n%d-s%g-seed%d", R, rho0, truth.kind,
                         n, sigma, seed),
    gtag = "G3b", geometry.family = "sphere cap (constant curvature)",
    X = X, truth = truth.vec, y = y, sigma = sigma, seed = seed,
    U = U, d = 2L,
    params = list(R = R, rho0 = rho0, gaussian.curvature = 1 / R^2,
                  truth = truth.kind, sigma = sigma),
    provenance = list(generator = "dgp.g3b",
                      bound.to = "explicit sphere-cap embedding (plan G3b)"))
}

# =============================================================================
# G3c -- 1-D curve (helix)
# =============================================================================

#' G3c -- 1-D helix
#'
#' Plan G3c (spec sec:dgp). \eqn{d=1, D=3}. Helix
#' \eqn{X(t) = (\cos t, \sin t, c\, t)}, \eqn{t \sim \mathrm{Unif}[0, 2\pi)}.
#' The plan fixes no truth for G3c; the documented default is `f(t) = sin(t)`.
#'
#' @param n Positive integer sample size.
#' @param c Helix pitch. Default 0.2.
#' @param truth.fn Function of the intrinsic `t` giving the noiseless truth.
#'   Default `sin`.
#' @param sigma Noise standard deviation. Default `0.1`.
#' @param seed Integer seed.
#' @return A `dgp_dataset`; `U` holds the intrinsic `t`.
#' @export
dgp.g3c <- function(n = 600L, c = 0.2, truth.fn = sin, sigma = 0.1, seed = 1L) {
  stopifnot(n >= 1L)
  set.seed(seed)
  t <- stats::runif(n, 0, 2 * pi)
  X <- cbind(x1 = cos(t), x2 = sin(t), x3 = c * t)
  truth.vec <- as.numeric(truth.fn(t))
  y <- .dgp.add.gaussian.noise(truth.vec, sigma, seed)
  .dgp.dataset(
    dataset.id = sprintf("G3c-c%g-n%d-s%g-seed%d", c, n, sigma, seed),
    gtag = "G3c", geometry.family = "1-D helix",
    X = X, truth = truth.vec, y = y, sigma = sigma, seed = seed,
    U = matrix(t, ncol = 1L), d = 1L,
    params = list(c = c, sigma = sigma, truth = "sin(t) [default]"),
    provenance = list(generator = "dgp.g3c",
                      bound.to = "explicit helix (plan G3c); truth default sin(t)"))
}

# =============================================================================
# G3d -- torus patch
# =============================================================================

#' G3d -- torus patch
#'
#' Plan G3d (spec sec:dgp). \eqn{d=2, D=3}, standard torus with radii
#' \eqn{(R_1, R_2)}, latent angles on a sub-rectangle to avoid wrap-around:
#' \eqn{X = ((R_1 + R_2 \cos v)\cos u, (R_1 + R_2 \cos v)\sin u, R_2 \sin v)} with
#' \eqn{(u, v)} uniform on `u.range` x `v.range`. Truth options as in G3a, on the
#' intrinsic angles `(u, v)`.
#'
#' @param n Positive integer sample size.
#' @param R1 Major (centre-tube) radius. Default 1.
#' @param R2 Minor (tube) radius. Default 0.35.
#' @param u.range,v.range Length-2 angle ranges (sub-rectangle, avoid wrap).
#'   Defaults `c(-pi/2, pi/2)`.
#' @param truth `"smooth"` or `"linear"` on the intrinsic angles.
#' @param sigma Noise standard deviation. Default `0.1`.
#' @param seed Integer seed.
#' @return A `dgp_dataset`; `U` holds the intrinsic angles `(u, v)`.
#' @export
dgp.g3d <- function(n = 600L, R1 = 1, R2 = 0.35,
                    u.range = c(-pi / 2, pi / 2), v.range = c(-pi / 2, pi / 2),
                    truth = c("smooth", "linear"), sigma = 0.1, seed = 1L) {
  truth.kind <- match.arg(truth)
  stopifnot(R1 > 0, R2 > 0, R2 < R1, n >= 1L,
            length(u.range) == 2L, length(v.range) == 2L)
  set.seed(seed)
  u <- stats::runif(n, u.range[1], u.range[2])
  v <- stats::runif(n, v.range[1], v.range[2])
  U <- cbind(u = u, v = v)
  X <- cbind(
    x1 = (R1 + R2 * cos(v)) * cos(u),
    x2 = (R1 + R2 * cos(v)) * sin(u),
    x3 = R2 * sin(v))
  truth.vec <- .dgp.truth.intrinsic2(U, truth.kind)
  y <- .dgp.add.gaussian.noise(truth.vec, sigma, seed)
  .dgp.dataset(
    dataset.id = sprintf("G3d-R1_%g-R2_%g-%s-n%d-s%g-seed%d", R1, R2, truth.kind,
                         n, sigma, seed),
    gtag = "G3d", geometry.family = "torus patch",
    X = X, truth = truth.vec, y = y, sigma = sigma, seed = seed,
    U = U, d = 2L,
    params = list(R1 = R1, R2 = R2, u.range = u.range, v.range = v.range,
                  truth = truth.kind, sigma = sigma),
    provenance = list(generator = "dgp.g3d",
                      bound.to = "explicit torus patch (plan G3d); 2d_curved_saddle is geosmooth provenance"))
}

# =============================================================================
# G4 -- stratified / varying dimension
# =============================================================================

#' G4 -- stratified / varying-dimension dataset
#'
#' Plan G4 (spec sec:dgp). Two glued strata sharing a boundary: stratum A is a
#' 1-D segment \eqn{\{(t,0,0): t \in [-1,0]\}} thickened by transverse Gaussian
#' noise `eta`; stratum B is a 2-D patch
#' \eqn{\{(s_1, s_2, 0): s_1 \in [0,1], s_2 \in [-0.5, 0.5]\}}. True local
#' intrinsic dimension is 1 on A and 2 on B. Used to verify a dimension
#' stabilizer does not blur the true boundary. The plan fixes no truth; the
#' documented default is the smooth ridge `f(x) = sin(pi * x1)`.
#'
#' @param n Positive integer sample size.
#' @param fracA Fraction of points on stratum A. Default 0.5.
#' @param eta Transverse-noise sd thickening stratum A. Default 0.02.
#' @param truth.fn Function of the ambient `X` matrix giving the noiseless truth.
#'   Default `function(X) sin(pi * X[, 1])`.
#' @param sigma Response-noise standard deviation. Default `0.1`.
#' @param seed Integer seed.
#' @return A `dgp_dataset` with `region` in \{"A","B"\}; `U` holds the intrinsic
#'   coordinate (`t` in column 1 for A, `(s1, s2)` for B; A's column 2 is `NA`).
#' @export
dgp.g4 <- function(n = 600L, fracA = 0.5, eta = 0.02,
                   truth.fn = function(X) sin(pi * X[, 1]),
                   sigma = 0.1, seed = 1L) {
  stopifnot(n >= 2L, fracA > 0, fracA < 1, eta >= 0)
  nA <- max(1L, round(fracA * n))
  nB <- n - nA
  set.seed(seed)
  # Stratum A: 1-D segment t in [-1, 0], thickened transversally by eta.
  tA <- stats::runif(nA, -1, 0)
  A <- cbind(tA, stats::rnorm(nA, sd = eta), stats::rnorm(nA, sd = eta))
  # Stratum B: 2-D patch in the z = 0 plane.
  s1 <- stats::runif(nB, 0, 1)
  s2 <- stats::runif(nB, -0.5, 0.5)
  B <- cbind(s1, s2, 0)
  X <- rbind(A, B)
  colnames(X) <- c("x1", "x2", "x3")
  region <- c(rep("A", nA), rep("B", nB))
  U <- rbind(cbind(tA, NA_real_), cbind(s1, s2))
  truth.vec <- as.numeric(truth.fn(X))
  y <- .dgp.add.gaussian.noise(truth.vec, sigma, seed)
  .dgp.dataset(
    dataset.id = sprintf("G4-n%d-fracA%g-eta%g-s%g-seed%d", n, fracA, eta,
                         sigma, seed),
    gtag = "G4", geometry.family = "stratified 1-D segment + 2-D patch",
    X = X, truth = truth.vec, y = y, sigma = sigma, seed = seed,
    U = U, region = region, d = NA_integer_,
    params = list(fracA = fracA, nA = nA, nB = nB, eta = eta, sigma = sigma,
                  dim.by.region = c(A = 1L, B = 2L),
                  truth = "sin(pi*x1) [default]"),
    provenance = list(generator = "dgp.g4",
                      bound.to = "explicit glued strata (plan G4); SYN-TWO-PLANES family is the FB provenance"))
}

# =============================================================================
# G5 -- clustered / repeated measures
# =============================================================================

#' G5 -- clustered / repeated-measures dataset
#'
#' Plan G5 (spec sec:dgp). `K` clusters; centres \eqn{c_k \sim
#' \mathrm{Unif}([-1,1]^2)}; within a cluster, `m` points \eqn{x = c_k + \zeta},
#' \eqn{\zeta \sim N(0, \sigma_x^2 I)}. Response \eqn{y = g(x) + b_k +
#' \varepsilon}, \eqn{b_k \sim N(0, \tau^2)}, \eqn{\varepsilon \sim N(0,
#' \sigma^2)}, intra-class correlation \eqn{\rho = \tau^2/(\tau^2 + \sigma^2)}.
#' Used for grouped-CV validity. `truth` is the fixed mean \eqn{g(x)}; the random
#' effect `b_k` is recorded in `params$b` and is part of the dependence
#' structure, not the truth.
#'
#' @param K Number of clusters. Default 40.
#' @param m Points per cluster. Default 20 (so `n = K * m`).
#' @param sigma.x Within-cluster spread `sigma_x`. Default 0.05.
#' @param rho Intra-class correlation in \[0, 1). Default 0.6.
#' @param sigma Residual sd `sigma` (with `rho`, fixes `tau`). Default 0.1.
#' @param g Mean function of the ambient `x` matrix. Default the plan-style
#'   smooth `function(x) sin(pi * x[, 1]) * cos(pi * x[, 2])`.
#' @param seed Integer seed.
#' @return A `dgp_dataset` with `region` = cluster id; `U` holds the ambient `x`.
#' @export
dgp.g5 <- function(K = 40L, m = 20L, sigma.x = 0.05, rho = 0.6, sigma = 0.1,
                   g = function(x) sin(pi * x[, 1]) * cos(pi * x[, 2]),
                   seed = 1L) {
  K <- as.integer(K); m <- as.integer(m)
  stopifnot(K >= 1L, m >= 1L, sigma.x >= 0, rho >= 0, rho < 1, sigma > 0)
  n <- K * m
  tau <- sqrt(rho * sigma^2 / (1 - rho))     # rho = tau^2 / (tau^2 + sigma^2)
  set.seed(seed)
  centres <- matrix(stats::runif(K * 2L, -1, 1), ncol = 2L)
  cluster <- rep(seq_len(K), each = m)
  zeta <- matrix(stats::rnorm(n * 2L, sd = sigma.x), ncol = 2L)
  X <- centres[cluster, , drop = FALSE] + zeta
  colnames(X) <- c("x1", "x2")
  truth.vec <- as.numeric(g(X))
  # Response noise stream: cluster random effects then residuals.
  set.seed(seed + .DGP.NOISE.OFFSET)
  b <- stats::rnorm(K, sd = tau)
  eps <- stats::rnorm(n, sd = sigma)
  y <- truth.vec + b[cluster] + eps
  .dgp.dataset(
    dataset.id = sprintf("G5-K%d-m%d-rho%g-s%g-seed%d", K, m, rho, sigma, seed),
    gtag = "G5", geometry.family = "clustered / repeated measures",
    X = X, truth = truth.vec, y = y, sigma = sigma, seed = seed,
    U = X, region = as.character(cluster), d = 2L,
    params = list(K = K, m = m, sigma.x = sigma.x, rho = rho, sigma = sigma,
                  tau = tau, b = b, cluster = cluster,
                  truth = "sin(pi*x1)cos(pi*x2) [default g]"),
    provenance = list(generator = "dgp.g5",
                      bound.to = "SYN-DISK-CLUSTERS family + plan repeated-measures noise model"))
}

# =============================================================================
# G6 -- binary surface
# =============================================================================

#' G6 -- binary surface (prevalence-controlled)
#'
#' Plan G6 (spec sec:dgp). Smooth bounded log-odds \eqn{\eta(x)} with offset
#' \eqn{\alpha} chosen so \eqn{E[p]} hits a target prevalence;
#' \eqn{p(x) = \mathrm{expit}(\alpha + \eta(x))} clipped to \eqn{[0.05, 0.95]};
#' \eqn{Y_i \sim \mathrm{Bernoulli}(p(x_i))}. Default
#' \eqn{\eta(x) = 1.5 \sin(\pi x_1)} on \eqn{x \in [-1,1]^2}. `truth` is the
#' clipped probability `p`; `y` is the Bernoulli draw; `sigma` is `NA`.
#'
#' `alpha` is solved by `uniroot` so that the mean *unclipped* expit equals the
#' target (the plan's literal mean-probability target); the realized clipped mean
#' is recorded in `params$realized.prevalence`.
#'
#' @param n Positive integer sample size.
#' @param prevalence Target prevalence in (0.05, 0.95). Default 0.5.
#' @param eta.fn Log-odds shape, a function of the ambient `x` matrix. Default
#'   `function(x) 1.5 * sin(pi * x[, 1])`.
#' @param clip Length-2 probability clip. Default `c(0.05, 0.95)`.
#' @param seed Integer seed.
#' @return A `dgp_dataset`; `truth` is `p`, `y` is the Bernoulli draw.
#' @export
dgp.g6 <- function(n = 600L, prevalence = 0.5,
                   eta.fn = function(x) 1.5 * sin(pi * x[, 1]),
                   clip = c(0.05, 0.95), seed = 1L) {
  stopifnot(n >= 1L, length(clip) == 2L, clip[1] < clip[2],
            prevalence > clip[1], prevalence < clip[2])
  set.seed(seed)
  X <- matrix(stats::runif(n * 2L, -1, 1), ncol = 2L)
  colnames(X) <- c("x1", "x2")
  eta <- as.numeric(eta.fn(X))
  mean.p <- function(alpha) mean(stats::plogis(alpha + eta))
  alpha <- stats::uniroot(function(a) mean.p(a) - prevalence,
                          interval = c(-50, 50))$root
  p <- pmin(clip[2], pmax(clip[1], stats::plogis(alpha + eta)))
  set.seed(seed + .DGP.NOISE.OFFSET)
  y <- stats::rbinom(n, size = 1L, prob = p)
  .dgp.dataset(
    dataset.id = sprintf("G6-prev%g-n%d-seed%d", prevalence, n, seed),
    gtag = "G6", geometry.family = "binary surface",
    X = X, truth = p, y = y, sigma = NA_real_, seed = seed,
    U = X, d = 2L,
    params = list(prevalence = prevalence, alpha = alpha, clip = clip,
                  realized.prevalence = mean(p), realized.rate = mean(y),
                  eta = "1.5*sin(pi*x1) [default]"),
    provenance = list(generator = "dgp.g6",
                      bound.to = "probability.profile (lps_binary_gm_ff_helpers) reduced to plan G6"))
}

# =============================================================================
# G7 -- compositional / structural zeros
# =============================================================================

#' G7 -- compositional dataset with structural zeros
#'
#' Plan G7 (spec sec:dgp). \eqn{X_i} a `D`-part composition: draw
#' \eqn{\mathrm{Dirichlet}(\boldsymbol\alpha)}, set a documented subset of parts
#' to exact `0`, renormalize to the simplex. Used to characterize behaviour on
#' 16S-like inputs. A documented `zero.fraction` of rows have the parts in
#' `zero.parts` forced to exactly 0 before renormalization (the deterministic,
#' auditable structural-zero pattern). Rows sum to 1 by construction.
#'
#' The plan fixes no truth for G7; the documented default is the smooth
#' \eqn{f(x) = \sin(\pi x_1) + 0.5 x_2} on the first two parts.
#'
#' @param n Positive integer sample size.
#' @param D Number of compositional parts. Default 5.
#' @param alpha Dirichlet concentration (length `D` or scalar). Default `1`.
#' @param zero.fraction Fraction of rows carrying structural zeros. Default 0.5.
#' @param zero.parts Integer part indices forced to 0 in the zeroed rows.
#'   Default `D` (the last part).
#' @param truth.fn Function of the composition matrix giving the noiseless truth.
#'   Default `function(X) sin(pi * X[, 1]) + 0.5 * X[, 2]`.
#' @param sigma Response-noise standard deviation. Default `0.1`.
#' @param seed Integer seed.
#' @return A `dgp_dataset` with `region` in \{"zero","interior"\}; `X` is the
#'   composition (rows sum to 1).
#' @export
dgp.g7 <- function(n = 600L, D = 5L, alpha = 1, zero.fraction = 0.5,
                   zero.parts = NULL,
                   truth.fn = function(X) sin(pi * X[, 1]) + 0.5 * X[, 2],
                   sigma = 0.1, seed = 1L) {
  D <- as.integer(D)
  stopifnot(D >= 2L, n >= 1L, zero.fraction >= 0, zero.fraction <= 1)
  if (length(alpha) == 1L) alpha <- rep(alpha, D)
  stopifnot(length(alpha) == D, all(alpha > 0))
  if (is.null(zero.parts)) zero.parts <- D
  zero.parts <- as.integer(zero.parts)
  stopifnot(all(zero.parts >= 1L), all(zero.parts <= D),
            length(zero.parts) < D)
  set.seed(seed)
  # Dirichlet(alpha) via normalized Gammas.
  G <- matrix(stats::rgamma(n * D, shape = rep(alpha, each = n)), nrow = n)
  comp <- G / rowSums(G)
  nzero <- round(zero.fraction * n)
  zero.idx <- if (nzero > 0L) seq_len(nzero) else integer(0)
  if (length(zero.idx) > 0L) {
    comp[zero.idx, zero.parts] <- 0
    comp[zero.idx, ] <- comp[zero.idx, , drop = FALSE] /
      rowSums(comp[zero.idx, , drop = FALSE])
  }
  colnames(comp) <- paste0("p", seq_len(D))
  region <- rep("interior", n)
  region[zero.idx] <- "zero"
  truth.vec <- as.numeric(truth.fn(comp))
  y <- .dgp.add.gaussian.noise(truth.vec, sigma, seed)
  .dgp.dataset(
    dataset.id = sprintf("G7-D%d-zf%g-n%d-s%g-seed%d", D, zero.fraction, n,
                         sigma, seed),
    gtag = "G7", geometry.family = "compositional / structural zeros",
    X = comp, truth = truth.vec, y = y, sigma = sigma, seed = seed,
    U = NULL, region = region, d = NA_integer_,
    params = list(D = D, alpha = alpha, zero.fraction = zero.fraction,
                  zero.parts = zero.parts, n.zero = length(zero.idx),
                  sigma = sigma, truth = "sin(pi*p1)+0.5*p2 [default]"),
    provenance = list(generator = "dgp.g7",
                      bound.to = "plan Dirichlet-with-zeros; LA-*/SYN-SIMPLEX-FACES are the FB real/synthetic provenance"))
}

# -----------------------------------------------------------------------------
# Registry support
# -----------------------------------------------------------------------------

# Map a G-tag to its generator (used by the registry builder / materializer).
.dgp.generators <- function() {
  list(G1 = dgp.g1, G2 = dgp.g2, G3a = dgp.g3a, G3b = dgp.g3b, G3c = dgp.g3c,
       G3d = dgp.g3d, G4 = dgp.g4, G5 = dgp.g5, G6 = dgp.g6, G7 = dgp.g7)
}

#' Materialize a registry row's dataset object
#'
#' Calls the G-tag generator with the recorded argument list. Used by the
#' registry builder and by an auditor to regenerate a canonical dataset from its
#' frozen parameters.
#'
#' @param gtag Character G-tag.
#' @param args Named list of generator arguments.
#' @return A `dgp_dataset`.
#' @export
dgp.materialize <- function(gtag, args = list()) {
  gens <- .dgp.generators()
  if (is.null(gens[[gtag]])) stop("Unknown G-tag: ", gtag, call. = FALSE)
  do.call(gens[[gtag]], args)
}

# Canonical, reproducible content payload of a dataset object: the fields that
# define the materialized data, in a FIXED order, excluding environment-derived
# provenance (package version etc.). The SHA-256 is taken over this payload so an
# auditor can recompute it independently with `dgp.content.sha256()`.
.dgp.content <- function(ds) {
  list(
    dataset.id = ds$dataset.id,
    gtag = ds$gtag,
    n = ds$n, p = ds$p, d = ds$d,
    seed = ds$seed,
    sigma = ds$sigma,
    U = ds$U,
    X = ds$X,
    truth = ds$truth,
    y = ds$y,
    region = ds$region
  )
}

#' SHA-256 of a dataset object's reproducible content
#'
#' Computes a SHA-256 over the canonical content payload (`.dgp.content`): the
#' materialized `U`, `X`, `truth`, `y`, `region`, and the scalar identifiers.
#' Environment-derived provenance (package version) is excluded so the checksum
#' depends only on the data. Requires the `digest` package.
#'
#' @param ds A `dgp_dataset`.
#' @return A length-1 character SHA-256 hex string.
#' @export
dgp.content.sha256 <- function(ds) {
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("dgp.content.sha256 requires the 'digest' package.", call. = FALSE)
  }
  digest::digest(.dgp.content(ds), algo = "sha256", serialize = TRUE)
}
