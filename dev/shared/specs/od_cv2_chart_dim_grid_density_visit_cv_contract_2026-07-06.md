# OD-CV2 Chart-Dimension Grid and Density Visit-CV Contract

Source: `/Users/pgajer/current_projects/geosmooth/dev/shared/specs/od_cv2_chart_dim_grid_density_visit_cv_contract_2026-07-06.md`

## Purpose

OD-CV2 extends the OD-level visit cross-validation contract introduced in
OD-CV0 and OD-CV1.  OD-CV0 added held-out-visit selection for chart-kernel and
Bernoulli local-likelihood subject-occupation density workflows.  OD-CV1 made
global and local automatic chart-dimension policies available to the direct
chart methods and preserved those policies through OD visit CV when the policy
was fixed in advance.

OD-CV2 makes two changes.

First, chart dimension can now be a candidate axis in OD-level visit CV for
chart methods.  A caller may compare fixed integer chart dimensions,
`chart.dim = "auto"`, and `chart.dim = "local.auto"` under the same held-out
negative-log-occupation score.

Second, OD-level visit CV now supports
`method = "local_likelihood_density"`, not only
`method = "local_likelihood_bernoulli"`.

## Public Use

The OD-CV2 path is reached through `fit.subject.od()`:

```r
fit.subject.od(
    X,
    subject.index,
    method = "chart_kernel",
    od.cv = "visit",
    support.grid = c(15L, 25L),
    kernel.grid = c("gaussian", "tricube"),
    chart.dim.grid = c("1", "auto", "local.auto"),
    coordinate.method = "local.pca"
)
```

The same `chart.dim.grid` argument is available for
`method = "local_likelihood_density"` and
`method = "local_likelihood_bernoulli"` when `od.cv = "visit"`.

Each chart-dimension candidate is represented in `fit$visit.cv.table` by two
columns:

- `chart.dim`: stable label for the candidate.  The allowed labels are
  `"NULL"`, a positive integer written as a character string, `"auto"`, and
  `"local.auto"`.
- `chart.dim.rank`: deterministic candidate-order rank used only for
  tie-breaking and auditing.

The selected candidate row is stored in
`fit$diagnostics$od.visit.cv.selection`.

## Candidate Axes

For `method = "chart_kernel"`, OD-CV2 candidates are the Cartesian product of

```text
support.size
kernel
bandwidth.multiplier
chart.dim
```

where the first three axes are inherited from OD-CV0 and `chart.dim` is the new
OD-CV2 axis.

For `method = "local_likelihood_density"` and
`method = "local_likelihood_bernoulli"`, OD-CV2 candidates are the Cartesian
product of

```text
support.size
degree
kernel
bandwidth.multiplier
lambda.ridge
chart.dim
```

The density and Bernoulli branches share the same candidate-grid machinery.
They differ only in the local likelihood family used inside the method fit.

## Selection Score

For a candidate \(\theta\), OD visit CV fits the method on all visits outside a
held-out visit fold and then records the fitted occupation mass assigned to the
held-out visit locations.  The selected score is

\[
  \mathrm{VisitCV}(\theta)
  =
  -\frac{1}{n_s}
  \sum_{r=1}^{n_s}
  \log\left\{
    \max\left(\widehat\rho^{(-F(r))}_{\theta}(x_r),
              \epsilon\right)
  \right\},
\]

where \(x_r\) is the state visited at subject visit \(r\), \(F(r)\) is its
visit fold, \(\widehat\rho^{(-F(r))}_{\theta}\) is the density fit without the
visits in that fold, and \(\epsilon=\texttt{visit.cv.epsilon}\) is the positive
log-score floor.

Ties use the shared chart-CV deterministic rule: smaller support size, smaller
degree when applicable, earlier chart-dimension candidate rank, lexicographic
kernel label, smaller bandwidth multiplier, smaller ridge, then score.

## Implemented Gate

The OD-CV2 implementation is considered in place when:

1. `fit.subject.od(method = "chart_kernel", od.cv = "visit",
   chart.dim.grid = ...)` produces a finite visit-CV table with one row per
   candidate chart dimension crossed with the inherited chart-kernel axes.
2. `fit.subject.od(method = "local_likelihood_density", od.cv = "visit",
   chart.dim.grid = ...)` runs through the same visit-CV contract and returns a
   normalized density.
3. `fit.subject.od(method = "local_likelihood_bernoulli", od.cv = "visit",
   chart.dim.grid = ...)` continues to pass the OD-CV0 telemetry contract while
   adding the new chart-dimension candidate axis.
4. Candidate tables record `chart.dim` and `chart.dim.rank`, and the selected
   row is stored in `diagnostics$od.visit.cv.selection`.

## Remaining Scope

OD-CV2 does not add OD visit CV for LPS or PS-LPS methods.  OD-CV3 later adds
outer OD visit CV for those methods using scalar source-smoother candidates;
see `dev/shared/specs/od_cv3_lps_outer_visit_cv_contract_2026-07-06.md`.

OD-CV2 also does not make chart-dimension grids part of direct row-level CV
inside `fit.chart.kernel()` or `fit.local.likelihood()`.  The new grid axis is
an OD-level visit-CV feature of `fit.subject.od()`.
