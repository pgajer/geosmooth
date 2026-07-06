# OD3 Local-Likelihood Implementation Plan

Source: `/Users/pgajer/current_projects/geosmooth/dev/shared/specs/od3_local_likelihood_implementation_plan_2026-07-06.md`

## Purpose

This document specifies the implementation plan for the OD3 local-likelihood
prototype in `geosmooth`.  The chart-kernel OD3 prototype is already in place
as `fit.chart.kernel()` plus `normalize.density()`.  The local-likelihood path
should now be implemented only after preserving the same package design rule:
the model-layer function is `fit.local.likelihood()`, and density conversion is
performed explicitly by `normalize.density()`.

The first implementation should be narrow.  It should estimate a nonnegative
local density or intensity field from a sparse subject-occupation mass vector.
It should not attempt to implement a full family of Gaussian, Bernoulli, and
binomial local-likelihood regressions in the first pass.  Those extensions can
be considered after the density/intensity branch passes the OD gates.

## Statistical Target

Let

```text
X = {x_1, ..., x_N} subset R^p
```

be the pooled state-space support.  A subject contributes a nonnegative
occupation mass vector

```text
y_i >= 0,    sum_i y_i > 0,
```

usually the empirical subject occupation mass

```text
y_i = rho0_i^s = #{subject visits at x_i} / n_s.
```

For each evaluation point `x_u`, choose a local support

```text
U_u = {indices of the k nearest source points to x_u},
```

build local chart coordinates

```text
z_ui = psi_u(x_i) - psi_u(x_u),    i in U_u,
```

and define kernel responsibility weights

```text
r_ui = K_h(||z_ui||).
```

Let `q_i > 0` denote optional quadrature or reference-measure weights.  The
first local-likelihood model should use an exponential tilt over the local
chart:

```text
p_u(i; beta_u)
  =
  q_i r_ui exp{phi_u(z_ui)^T beta_u}
  /
  Z_u(beta_u),

Z_u(beta_u)
  =
  sum_{j in U_u} q_j r_uj exp{phi_u(z_uj)^T beta_u}.
```

The local feature map `phi_u` must not contain an intercept.  An intercept is
not identifiable because it cancels in `Z_u(beta_u)`.  With degree zero there
are no free parameters and the local model is locally uniform with respect to
`q_i r_ui`.

Let

```text
M_u = sum_{i in U_u} r_ui y_i
```

be the local kernel-weighted subject mass.  The local log likelihood, with a
ridge penalty on the identifiable coefficients, is

```text
ell_u(beta_u)
  =
  sum_{i in U_u} r_ui y_i phi_u(z_ui)^T beta_u
  -
  M_u log Z_u(beta_u)
  -
  (lambda.ridge / 2) ||beta_u||_2^2.
```

The raw fitted field at the evaluation point should be the local intensity

```text
f_hat(x_u)
  =
  M_u
  exp{phi_u(0)^T beta_u}
  /
  Z_u(beta_u).
```

The multiplication by `M_u` is important.  Without it, every local support with
at least one subject visit would return a density normalized to one inside that
support and would largely ignore whether the subject actually occupies that
region.  With the `M_u` factor, supports with little or no subject mass produce
little or no fitted intensity before global density normalization.

After evaluating `f_hat(x_u)` for all rows of `X.eval`, call
`normalize.density()` to clip, renormalize, preserve `empirical.rho`, and attach
the usual OD accounting diagnostics.

## Public API

Add a model-layer function:

```r
fit.local.likelihood(
  X,
  y,
  X.eval = NULL,
  support.size = min(15L, nrow(X)),
  degree = 1L,
  kernel = c("gaussian", "tricube", "epanechnikov", "triangular"),
  bandwidth.multiplier = 1,
  coordinate.method = c("coordinates", "local.pca"),
  chart.dim = NULL,
  quadrature.weights = NULL,
  lambda.ridge = 1e-8,
  min.local.mass = sqrt(.Machine$double.eps),
  min.nonzero.mass = 1L,
  fallback = c("degree0", "zero", "chart_kernel", "na"),
  optimizer = c("newton", "optim"),
  max.iter = 50L,
  tol = 1e-8,
  return.details = TRUE
)
```

The returned object should have class `c("local_likelihood", "list")` and at
least these fields:

```r
list(
  method.id = "local_likelihood",
  X = X,
  X.eval = X.eval,
  y = y,
  fitted.values = numeric(nrow(X.eval)),
  selected = list(...),
  quadrature.weights = quadrature.weights,
  diagnostics = list(...),
  empirical.rho = optional_empirical_reference,
  call = match.call()
)
```

Do not add `fit.density.local.likelihood()`.  The intended workflow is:

```r
fit <- fit.local.likelihood(X, y = empirical.mass, ...)
rho <- normalize.density(fit, density.control = list())
```

Only after direct model tests pass should `fit.subject.od()` expose

```r
method = "local_likelihood"
```

as a convenience workflow that constructs the subject mass vector, calls
`fit.local.likelihood()`, and then calls `normalize.density()`.

## Implementation Phases

### OD3-LL0: Contract and Helper Skeleton

Create `R/local_likelihood.R` with validators and private helpers.  Reuse or
factor the chart-kernel helper logic when practical, but do not change
`fit.chart.kernel()` semantics.

Required helpers:

- input validation for `X`, `X.eval`, `y`, `quadrature.weights`, and local
  control scalars;
- support construction by nearest neighbors in ambient `X`;
- local coordinate construction using `"coordinates"` and `"local.pca"`;
- kernel-weight construction using the same kernel definitions as LPS and
  chart-kernel;
- degree-0, degree-1, and degree-2 feature construction without intercept;
- stable `logsumexp` evaluation for `Z_u(beta)`;
- local likelihood objective, gradient, and Hessian for the density/intensity
  branch.

Acceptance tests:

- invalid `y`, invalid quadrature weights, invalid support size, and invalid
  `chart.dim` fail with clear messages;
- degree-0 local likelihood has a closed-form output and does not call an
  optimizer;
- all helper outputs are finite on a small 1D fixture.

### OD3-LL1: Local Optimizer and Sparse-Subject Safeguards

Implement the per-evaluation local solve.  The recommended first backend is
Newton with ridge-stabilized Hessian and step-halving.  If this is too much for
the first implementation, use `stats::optim(..., method = "BFGS")` with the
same objective and gradient, but keep the optimizer choice recorded.

Sparse-subject safeguards are mandatory.  For each evaluation point, compute:

```text
M_u = sum_i r_ui y_i,
n_u^+ = #{i in U_u : y_i > 0 and r_ui > 0}.
```

If `M_u < min.local.mass` or `n_u^+ < min.nonzero.mass`, the local solve must
not silently fail.  It must take a declared fallback path and record it in
per-evaluation diagnostics.  Recommended default:

```text
fallback = "zero"
```

for zero or nearly-zero local mass, because the subject has no local occupation
evidence there.  `fallback = "degree0"` is acceptable when `M_u` is positive
but the higher-degree fit is underidentified.  `fallback = "chart_kernel"` may
be useful later, but it should not be the first default because it mixes two
methods unless explicitly reported.

Per-evaluation diagnostics must include:

- `status`, one of `ok`, `zero_mass_fallback`, `degree0_fallback`,
  `chart_kernel_fallback`, `optimizer_failed`, `nonfinite_fit`;
- `M.local`;
- `n.nonzero.local`;
- `support.size`;
- `effective.support`;
- `chart.dim`;
- `degree.requested`;
- `degree.used`;
- `lambda.ridge`;
- `iterations`;
- `objective`;
- `gradient.norm`;
- `normalization.constant`;
- `raw.fitted`;
- `fallback.used`.

Acceptance tests:

- zero local mass returns finite zero fitted values with
  `status = "zero_mass_fallback"`;
- underidentified degree-2 cases fall back to degree 0 when requested;
- optimizer failures are surfaced in diagnostics and never produce hidden
  `NA` values in `fitted.values`.

### OD3-LL2: Public `fit.local.likelihood()`

Expose the public function after LL0 and LL1 helpers pass.  The function should
loop over evaluation points, fit local likelihoods, and return a fitted object
with `fitted.values`.

The first version may be R-only.  Do not add a C++ backend until correctness,
diagnostics, and sparse-subject behavior are audited.

Acceptance tests:

- direct 1D fit returns finite nonnegative `fitted.values`;
- direct dimension-greater-than-one fit works with `coordinate.method =
  "local.pca"`;
- `normalize.density(fit)` returns a `density_fit` with `status = "ok"`,
  mass one, no negative density, and preserved `empirical.rho` if the fit
  carries one;
- `return.details = FALSE` suppresses large per-evaluation diagnostics but
  still returns enough summary telemetry to audit fallback counts.

### OD3-LL3: OD Wrapper Integration

Only after LL2 passes, add `method = "local_likelihood"` to `fit.subject.od()`.
The wrapper should:

1. construct the empirical subject mass;
2. call `fit.local.likelihood(X = X, y = empirical, ...)`;
3. attach `empirical.rho` to the fit;
4. call `normalize.density(..., method.id = "local_likelihood")`;
5. decorate the OD object with source method, response summary, selected
   controls, local-likelihood telemetry, and subject metadata.

Acceptance tests:

- `fit.subject.od(method = "local_likelihood")` passes in 1D;
- the same method passes in dimension greater than one with an explicit graph
  or smoothness adjacency supplied for local-maxima diagnostics;
- reserved arguments such as `X` and `y` are rejected in the OD wrapper;
- the wrapper records fallback counts and does not silently mark a heavily
  fallback-dominated fit as ordinary.

### OD3-LL4: Comparison Smoke Tests

Run a small smoke comparison against:

- `fit.chart.kernel()` plus `normalize.density()`;
- `fit.subject.od(method = "lps_count")`;
- `fit.subject.od(method = "chart_kernel")`.

Use the same support size, kernel, coordinate method, and chart dimension where
possible.  The purpose is not to declare a winner.  The purpose is to verify
that local likelihood is numerically sane, has interpretable fallback behavior,
and does not create pathological density fields from sparse subject masses.

Required smoke outputs:

- mass and nonnegativity accounting;
- fallback fraction by dataset;
- number of local maxima and local-maxima reason;
- effective support summaries;
- simple `L1` distance from empirical mass for sanity, not as a performance
  claim;
- visual or tabular comparison of raw fitted fields in one 1D example.

### OD3-LL5: Audit Handoff

After implementation and tests, generate an auditor handoff under
`split_handoffs/` following
`/Users/pgajer/.codex/notes/workflows/agent_handoff_requirements.md`.

The handoff must explicitly state:

- whether local likelihood is admitted into broad OD benchmarking;
- fallback rates in the smoke tests;
- whether any local likelihood output depended on chart-kernel fallback;
- whether only the density/intensity branch was implemented;
- which extensions remain unimplemented.

## Admission Gates For Broad Benchmarking

Local likelihood must not enter OD4 or broader EOT benchmarks until all of the
following are true:

1. Direct `fit.local.likelihood()` tests pass in 1D and dimension greater than
   one.
2. `normalize.density(fit.local.likelihood(...))` passes mass, nonnegativity,
   finite-output, and empirical-reference accounting tests.
3. `fit.subject.od(method = "local_likelihood")` passes 1D and dimension
   greater-than-one smoke tests.
4. Fallback statuses are explicit and summarized.
5. Fallback-dominated fits are surfaced with a warning or diagnostic flag.
6. The method does not silently produce `NA`, `NaN`, `Inf`, or negative raw
   density values.
7. The implementation has an auditor handoff and audit response.

## Deferred Extensions

The following should remain out of the first OD3 local-likelihood phase:

- Gaussian local-likelihood regression;
- Bernoulli or binomial local-likelihood regression;
- support-grid or bandwidth-grid selection;
- C++ backend;
- integration into large OD4 benchmarks;
- using local likelihood as a default OD estimator;
- local-likelihood variants over landmarks rather than all data points.

These are reasonable later directions, but implementing them before the
density/intensity branch is audited would make the sparse-subject failure modes
too hard to interpret.

## Recommended First Implementation Decision

The recommended first implementation is:

```text
family: density/intensity only
degree: 0 and 1 first; degree 2 only after degree 1 passes
coordinate.method: coordinates and local.pca
fallback default: zero for zero local mass; degree0 for underidentified fits
optimizer: Newton with ridge and step-halving, or BFGS if Newton is deferred
wrapper: add fit.subject.od(method = "local_likelihood") only after direct tests pass
benchmark status: excluded from broad benchmarks until audited
```

This keeps OD3-local-likelihood mathematically honest: it is a local
exponential-family density/intensity prototype for sparse subject occupation,
not a general-purpose replacement for LPS, PS-LPS, or chart-kernel smoothing.
