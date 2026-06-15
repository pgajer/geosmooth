# Harlim Second-Order Local SVD H0 Contract

Date: 2026-06-04

## Scope

This contract specifies an experimental second-order local SVD chart primitive
for `geosmooth`.  It is a separate internal primitive from the existing plain
local PCA chart.  It must not change `compute_local_pca_chart()`,
`rcpp_local_pca_chart()`, LPS defaults, or any production P7 behavior.

The intended implementation target is a local chart constructor, not a
neighborhood search routine.  The caller supplies one already-selected local
support around one anchor.  The primitive returns local coordinates, a final
tangent basis, and diagnostics that make fallback and curvature fitting
auditable.

## Inputs

Required inputs:

- `X_support`: finite numeric matrix with `K` rows and ambient dimension `n`.
  Row `i` is the support point `x_i`.
- `center`: finite numeric vector of length `n`.  In the Harlim et al. setting
  this is the anchor point `x`.  The paper-faithful path is
  `center.mode = "anchor"`.
- `chart.dim`: fixed tangent dimension `m`.  The H1 prototype should accept
  `1 <= m <= n`.  If `m == n`, the method should fall back to ordinary local
  PCA, because there is no ambient normal space to correct.  If `m > n`, the
  input dimension is invalid and should be a hard error.
- `center.mode`: either `"anchor"` or `"mean"`.
  - `"anchor"` uses `center` as the SVD and Taylor-expansion base point.
  - `"mean"` uses the unweighted column mean of `X_support` as the SVD base
    point, matching the existing plain local PCA convention.  This is a
    pragmatic chart option, not covered by the Harlim theory.

Optional controls:

- `weights`: optional vector of length `K`.  Missing weights mean all ones.
  Nonfinite or nonpositive weights are treated as zero for fitting and rank
  checks, matching the existing plain local PCA backend; the returned
  coordinates still contain one row per input support point.
- `rank.tolerance`: nonnegative SVD rank cutoff multiplier.  Recommended
  default: `sqrt(.Machine$double.eps)` on the R side, or
  `sqrt(std::numeric_limits<double>::epsilon())` in C++.
- `rank.absolute.tolerance`: nonnegative absolute zero-scale threshold for
  singular values.  Recommended initial default: `0`, so rank decisions are
  relative to local matrix scale except for exactly zero matrices.  This
  parameter is only a zero-scale guard, not an absolute floor for ordinary rank
  cutoffs.
- `eigen.tolerance`: reserved for future automatic dimension selection.  The
  H1 prototype should use fixed `chart.dim`; if automatic selection is later
  added, it should select from the first SVD and then re-run all feasibility
  checks for the selected dimension.
- `curvature.condition.max`: maximum accepted spectral condition number for
  the weighted quadratic curvature design.  Recommended initial default:
  `1e8` when solving by SVD or QR.
- `curvature.ridge`: ridge parameter for an explicitly requested ridge
  fallback.  Recommended initial default: `0`.  With the default, rank-deficient
  or ill-conditioned curvature fits fall back to plain local PCA instead of
  returning a regularized second-order chart.
- `min.curvature.support`: optional lower bound on the number of positive-weight
  support rows.  The effective minimum is
  `max(min.curvature.support, m + 1, q + 1)`, where
  `q = m * (m + 1) / 2` is the number of quadratic curvature columns.
- `rebase.to.anchor`: if `TRUE`, final coordinates are computed from
  `X_support - center`.  If `FALSE`, final coordinates are computed from the SVD
  base point.  Recommended default: `TRUE`, matching the existing local PCA
  chart path used by LPS.
- `orient.basis`: if `TRUE`, orient final tangent-basis columns with the same
  deterministic largest-loading sign rule as the plain local PCA helper.  This
  is only for reproducibility of returned columns; tests must compare
  projection matrices or subspaces.

Invalid matrix dimensions, nonfinite `X_support`, nonfinite `center`, or a
wrong-length `weights` vector should be hard errors.  Numerical degeneracy
inside a well-formed local support should be reported as ordinary local PCA
fallback when that fallback is feasible, or as a structured failure object when
no fixed-`m` chart can be computed.

## Outputs

The primitive should return a list or C++ result object with these fields.

- `coordinates`: `K x m` matrix of final local coordinates.  If ordinary PCA
  fallback occurs, these are the ordinary local PCA coordinates under the same
  centering, dimension, weights, rebase, and orientation controls.  If
  structured failure occurs, this is an `NA` matrix with `K` rows and `m`
  columns.
- `basis`: `n x m` final orthonormal tangent basis.  If ordinary PCA fallback
  occurs, this is the ordinary local PCA basis.  If structured failure occurs,
  this is an `NA` matrix with `n` rows and `m` columns.
- `preliminary.basis`: `n x m` first-SVD tangent basis, when the first SVD
  succeeds.  This can equal `basis` under ordinary PCA fallback and should be
  `NA` under structured failure if no preliminary basis was available.
- `normal.basis`: optional.  The minimal H1 prototype need not compute a full
  normal frame.  If a future implementation computes one, it must state whether
  it is a complete `n x (n - m)` orthonormal complement or only the trailing
  right-singular-vector columns available from a thin SVD.
- `first.singular.values`: singular values from the weighted first SVD.
- `second.singular.values`: singular values from the weighted second SVD of the
  curvature-corrected residual.  Empty or `NA` when fallback occurs before the
  second SVD.
- `chart.dim`: selected tangent dimension.  For H1 this is the fixed input `m`.
- `curvature.coefficients`: `q x n` matrix `Y_hat`, when an unregularized or
  ridge curvature fit is accepted.  Empty or `NULL` under fallback before the
  curvature fit.
- `curvature.monomials`: table with one row per curvature design column,
  including `component`, `a`, `b`, and `multiplier`, where `a <= b` and
  `multiplier` is `1` for squares and `2` for cross terms.
- `curvature.diagnostics`: one-row record containing at least:
  `effective.support`, `quadratic.ncol`, `design.rank`, `design.condition`,
  `fit.method`, `ridge.lambda`, `fit.residual.frobenius`,
  `curvature.fitted.frobenius`, `corrected.residual.frobenius`,
  `first.rank`, `second.rank`, `plain.pca.fallback.feasible`,
  `primary.failure.reason`, and `status`.
- `fallback.used`: logical.
- `fallback.reason`: `"none"` when `fallback.used = FALSE`; otherwise one
  explicit reason such as `"chart_dim_not_less_than_ambient_dim"`,
  `"too_few_effective_support"`, `"first_svd_rank_deficient"`,
  `"curvature_under_determined"`, `"curvature_rank_deficient"`,
  `"curvature_ill_conditioned"`, `"curvature_solve_failure"`,
  `"second_svd_failure"`, `"second_svd_rank_deficient"`, or
  `"plain_pca_fallback_not_feasible"`.

The return object should make fallback impossible to miss.  A failed
second-order fit must never be returned as a successful second-order chart.
For a well-formed input where neither second-order SVD nor fixed-`m` ordinary
PCA fallback is feasible, return a structured failure object instead of raising
a numerical error: set `fallback.used = TRUE`,
`fallback.reason = "plain_pca_fallback_not_feasible"`, preserve the original
reason in `primary.failure.reason`, and fill chart fields such as
`coordinates`, `basis`, and `preliminary.basis` with `NA` matrices of the
requested dimensions where those dimensions are known.  Invalid input remains a
hard error.

## Mathematical Algorithm

All formulas below use row-oriented matrices, matching the current
`geosmooth` implementation style.  This is the transpose convention of Harlim,
Jiang, and Peoples, who write the local difference matrix as `n x K`.

### 1. Center the Local Data

Let `c_svd` be the base point:

- if `center.mode = "anchor"`, `c_svd = center`;
- if `center.mode = "mean"`, `c_svd = colMeans(X_support)`.

Define the centered local data matrix

```text
C[i, ] = X_support[i, ] - c_svd,       C in R^{K x n}.
```

Let `w_i` be the sanitized nonnegative weights.  Let `W_sqrt` denote the
diagonal matrix with entries `sqrt(w_i)`.  The effective support size is
`K_eff = #{i : w_i > 0}`.

### 2. First Weighted SVD

Compute the first SVD

```text
W_sqrt C = U1 S1 V1^T.
```

Let `T0 = V1[, 1:m]` be the preliminary tangent basis.  Its columns are the
row-oriented equivalent of Harlim et al.'s first-order local SVD tangent vectors
`t_tilde_1, ..., t_tilde_m`.

Feasibility checks:

- `K_eff >= m + 1`;
- `1 <= m < n`;
- the weighted centered matrix has numerical rank at least `m`.

If any check fails, use the fallback procedure in the numerical safeguards
section.  That procedure returns ordinary local PCA only when fixed-`m` plain
PCA is feasible; otherwise it returns a structured failure object.

### 3. Preliminary Tangent Coordinates

Compute unweighted preliminary tangent coordinates from the same centered
matrix:

```text
Rho = C T0,       Rho in R^{K x m}.
```

Row `i` contains `rho_tilde_i`.  These are preliminary tangent-coordinate
estimates of the geodesic normal coordinates at the base point.  They are not
ambient normal coordinates.  The curvature fit below estimates the ambient
quadratic departure from this preliminary tangent parameterization.

### 4. Quadratic Curvature Design

Let

```text
q = m * (m + 1) / 2.
```

Build `A in R^{K x q}` from all unique degree-2 monomials in `Rho`.
Use the Harlim et al. scaling:

1. square columns first: `rho_1^2, ..., rho_m^2`;
2. cross columns second in lexicographic order:
   `2 rho_1 rho_2, 2 rho_1 rho_3, ..., 2 rho_{m-1} rho_m`.

Each row of the coefficient matrix `Y` corresponds to one symmetric Hessian
component of the embedding in ambient coordinates.

### 5. Curvature Least Squares

The paper's ideal equation is

```text
A Y = 2 C - 2 R + O(rho^3),
```

where `R` is the unknown tangent residual.  The implementable estimator follows
Harlim et al. Step 3 and solves

```text
A Y_hat ~= 2 C
```

by weighted least squares:

```text
Y_hat = argmin_Y || W_sqrt (A Y - 2 C) ||_F^2.
```

The default H1 solver should be an SVD or rank-revealing QR least-squares solve,
not normal equations.  Let `A_w = W_sqrt A`.  The unregularized fit is accepted
only if:

- `K_eff >= max(m + 1, q + 1, min.curvature.support)`;
- `rank(A_w) = q` under `rank.tolerance`;
- `condition(A_w) <= curvature.condition.max`;
- all fitted values and coefficients are finite.

With `curvature.ridge = 0`, failure of these checks means using the fallback
procedure.  Ridge regularization is not part of the default first
implementation.  If a future H1 implementation exposes opt-in ridge fallback,
it must use

```text
lambda = curvature.ridge * sigma_max(A_w)^2
Y_hat = (A_w^T A_w + lambda I)^{-1} A_w^T W_sqrt (2 C),
```

record `fit.method = "ridge"`, record `ridge.lambda`, and avoid claiming
paper-faithful second-order behavior for that fit.

### 6. Curvature-Corrected Residual

Define the fitted quadratic ambient displacement and corrected residual as

```text
Q_hat = 0.5 A Y_hat,
C2 = C - Q_hat.
```

Harlim et al. write the second SVD using `2 C - A Y_hat`; using `C2` instead
only rescales all second singular values by a factor of `1/2` and leaves the
final tangent basis unchanged.  The H1 diagnostics should state that
`second.singular.values` are singular values of `W_sqrt C2`.

### 7. Second Weighted SVD and Final Basis

Compute

```text
W_sqrt C2 = U2 S2 V2^T.
```

Let `T2 = V2[, 1:m]`.  Accept the second-order chart only if the second SVD
succeeds, all returned values are finite, and the numerical rank of
`W_sqrt C2` is at least `m`.  Otherwise use the fallback procedure with an
explicit reason.

If `orient.basis = TRUE`, orient the columns of `T2` using the deterministic
largest-absolute-loading sign convention.  This changes only signs, not the
subspace.

### 8. Final Coordinates

Let

```text
c_coord = center     if rebase.to.anchor = TRUE,
          c_svd      otherwise.
```

Return final local coordinates

```text
Z = (X_support - c_coord) T2.
```

The coordinates are not weighted.  Weights affect basis estimation and the
curvature fit, but returned coordinates remain coordinates for the original
support rows.

## Numerical Safeguards and Fallback Policy

When a second-order check fails, the primitive should first decide whether the
ordinary local PCA chart backend can produce a fixed-`m` fallback chart using
the same input support, center, fixed dimension, center mode, weights, rebase
flag, and orientation flag.

Plain PCA fallback is feasible only when all of the following hold:

- `1 <= m <= min(K, n)`;
- `X_support` has positive dimensions and finite entries;
- `center` is finite and has length `n`;
- if `weights` are supplied, the sanitized weights contain at least one
  positive entry;
- the current plain local-PCA backend can be called without violating its fixed
  dimension rule.

If plain PCA fallback is feasible, fallback should occur for:

- `m == n`;
- too few positive-weight support rows for the first SVD;
- first weighted SVD rank below `m`;
- `K_eff < q + 1` or `K_eff < min.curvature.support`;
- weighted curvature design rank below `q`;
- weighted curvature design condition above `curvature.condition.max`;
- nonfinite curvature coefficients or fitted residuals;
- second weighted SVD failure;
- second weighted SVD rank below `m`.

If plain PCA fallback is not feasible, the primitive should return the
structured failure object described in the outputs section with
`fallback.reason = "plain_pca_fallback_not_feasible"`.  The original reason
that triggered fallback should be recorded separately as
`primary.failure.reason`.  Examples include `K < m`, all-zero effective weights
when the contract requires weighted fallback using the same weights, or a
support whose dimensions make a fixed-`m` thin-SVD result impossible.

Hard errors should be reserved for invalid inputs that cannot be interpreted
safely, such as nonfinite coordinates, wrong-length center or weights, `m < 1`,
`m > n`, and unsupported string options.

Recommended rank cutoff for a matrix `M` with singular values `s`:

```text
sigma_max = max(s)
if sigma_max <= rank.absolute.tolerance:
    rank = 0
else:
    cutoff = rank.tolerance * max(nrow(M), ncol(M)) * sigma_max
    rank = number of s_j > cutoff
```

This rule is intentionally relative to the local matrix scale.  Small
neighborhood radii are expected in local manifold methods and should not be
declared rank deficient solely because their coordinates have small absolute
units.

Recommended condition estimate:

```text
condition = sigma_max / sigma_min_kept
```

where `sigma_min_kept` is the smallest singular value above the rank cutoff.

## Relationship to Harlim et al.

Faithful elements:

- first ordinary local SVD to obtain a preliminary tangent frame;
- preliminary tangent coordinates `rho_tilde_i = (x_i - center)^T t_tilde`;
- quadratic design with squared terms and doubled cross terms;
- least-squares solve of `A_tilde Y = 2D^T` in the paper's notation;
- subtraction of the fitted quadratic curvature term before a second SVD;
- final tangent projector represented by the span of the leading second-SVD
  right singular vectors.

Pragmatic simplifications:

- the primitive receives a support; it does not choose K-nearest neighbors or a
  radius neighborhood internally;
- `chart.dim` is fixed for H1 rather than estimated from a spectral rule;
- row-oriented matrices are used to match existing `geosmooth` code;
- optional weights are a package extension, not part of the cited theory;
- `center.mode = "mean"` is supported only for consistency with the current
  local PCA primitive and is not paper-faithful;
- default unstable curvature fits fall back to ordinary local PCA rather than
  attempting to rescue the fit silently;
- the minimal prototype need not compute or return a full normal basis.

Assumptions not guaranteed in finite noisy data:

- the support points may not be sampled uniformly in a geodesic ball;
- the first-SVD tangent coordinates may be poor under noise, boundary
  asymmetry, or high curvature;
- the quadratic design may be rank deficient or ill-conditioned even when
  `K_eff > q`;
- the Harlim error rate assumes smooth noiseless manifold samples and spectral
  gap conditions that the primitive cannot verify from one local support.

## H1 Audit Checklist

The first implementation should be judged against this contract by checking:

- plain local PCA behavior is unchanged;
- the second-order primitive is separate and internal;
- `rho` coordinates are tangent coordinates, not normal coordinates;
- the quadratic design uses exactly the documented square and doubled-cross
  columns;
- weights row-scale the first SVD, curvature fit, and second SVD, but not the
  returned coordinates;
- every non-success path records `fallback.used` and `fallback.reason`;
- too-few-row and all-zero-effective-weight cases deterministically return
  either a feasible plain-PCA fallback or the structured
  `"plain_pca_fallback_not_feasible"` object specified above;
- tests compare bases by projection matrices or subspace distances, not raw
  signed columns.

## Recommendation

Ready for a minimal H1 prototype only.

The default unweighted, anchor-centered, fixed-dimension algorithm is precise
enough to implement and audit.  The prototype should remain explicitly
experimental because weighted fits, mean centering, ridge regularization, noisy
supports, and automatic dimension selection are pragmatic extensions beyond the
paper's theoretical contract.
