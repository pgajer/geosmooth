# OD-CV1 Chart-Dimension Auto Contract

Date: 2026-07-06

## Purpose

OD-CV1 closes the first chart-dimension gap left by OD-CV0.  The goal is not
yet to make chart dimension a candidate axis in OD visit cross-validation.  The
goal is narrower and package-facing:

- `fit.chart.kernel()` accepts `chart.dim = "auto"` and
  `chart.dim = "local.auto"` when `coordinate.method = "local.pca"`;
- `fit.local.likelihood()` accepts the same two policies for both
  `likelihood.family = "density"` and `likelihood.family = "bernoulli"`;
- `fit.subject.od(method = "chart_kernel", od.cv = "visit", ...)` and
  `fit.subject.od(method = "local_likelihood_bernoulli", od.cv = "visit",
  ...)` preserve those policies through the OD-level visit-CV refit path.

This makes the OD chart methods consistent with the deployable local-PCA
dimension policies already used by LPS and PS-LPS.

## Policy Definitions

For `coordinate.method = "local.pca"`, `chart.dim` now has four accepted forms
in the chart-kernel and local-likelihood methods.

`NULL` keeps the historical default:

```text
resolved chart dim = min(ncol(X), support.size - 1),
```

with a lower bound of one.

A positive integer requests a fixed chart dimension, clipped to the feasible
range:

```text
1 <= resolved chart dim <= min(ncol(X), support.size).
```

`"auto"` estimates one global chart dimension from the observed covariate matrix
`X` and the requested support size.  The implementation delegates to the shared
local-PCA auto-dimension diagnostics used by LPS.  No response values,
subject-visit indicators, held-out fold labels, or truth quantities are used.

`"local.auto"` estimates a local chart dimension separately for each evaluation
anchor.  The fitted object records:

- the requested policy in `selected$requested.chart.dim`;
- the resolved summary dimension in `selected$chart.dim`;
- the per-evaluation dimensions in `diagnostics$per.eval$chart.dim` when
  `return.details = TRUE`.

For `coordinate.method = "coordinates"`, `chart.dim` remains ignored.  The
methods warn when a non-`NULL` value is supplied and use the ambient coordinate
dimension.

## Auto-Dimension Metrics

The two methods now accept:

```r
auto.chart.support.metric = c("coordinates", "operator", "both")
auto.chart.selection.metric = c("coordinates", "operator")
```

For OD-CV1, the operator metric is explicitly coordinate-backed because these
methods do not yet construct a separate operator distance.  This mirrors the
current LPS/PS-LPS input-only dimension machinery without inventing a
method-specific graph or truth-dependent support metric.

## Selection Scope

OD-CV1 does not add `chart.dim` to the candidate grid.  If the user supplies
`chart.dim = "auto"` or `"local.auto"` together with OD visit CV, every
candidate is evaluated under that same dimension policy.  The OD-CV selected
candidate is still selected over the existing axes:

- chart-kernel: support size, kernel, bandwidth multiplier;
- Bernoulli local likelihood: support size, degree, kernel, bandwidth
  multiplier, ridge penalty.

Adding explicit chart-dimension policy grids belongs to OD-CV2.

## Validation Contract

The OD-CV1 regression tests must show that:

- direct `fit.chart.kernel(..., chart.dim = "auto")` succeeds and records
  global-auto metadata;
- direct `fit.local.likelihood(..., chart.dim = "local.auto")` succeeds and
  records per-evaluation dimensions;
- `fit.subject.od(method = "chart_kernel", od.cv = "visit", chart.dim =
  "auto")` succeeds and preserves the requested policy after the final refit;
- `fit.subject.od(method = "local_likelihood_bernoulli", od.cv = "visit",
  chart.dim = "local.auto")` succeeds and preserves the requested policy after
  the final refit.

All tests use observed `X` only for auto-dimension decisions.

## Remaining Gap

OD-CV1 is a deployability patch, not a full tuning patch.  OD-CV2 should decide
whether chart-dimension policy itself should become a candidate axis, for
example comparing fixed integer dimensions, `"auto"`, and `"local.auto"` under
the same OD visit-CV score.
