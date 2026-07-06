# OD-CV4 Graph Random-Walk Visit-CV Contract

Source: `/Users/pgajer/current_projects/geosmooth/dev/shared/specs/od_cv4_graph_random_walk_visit_cv_contract_2026-07-06.md`

## Purpose

OD-CV4 extends OD-level held-out-visit cross-validation to the
density-native graph random-walk workflow:

```r
fit.subject.od(method = "graph_random_walk", od.cv = "visit", ...)
```

The score is unchanged from OD-CV0 through OD-CV3.  For a subject with visits
\(x_1,\ldots,x_{n_s}\), a candidate graph random-walk setting \(\theta\), and
visit fold map \(F\), the selected setting minimizes

\[
  \mathrm{VisitCV}(\theta)
  =
  -\frac{1}{n_s}
  \sum_{r=1}^{n_s}
  \log\left\{
    \max\left(\widehat\rho^{(-F(r))}_{\theta}(x_r),
              \epsilon\right)
  \right\}.
\]

Here \(\widehat\rho^{(-F(r))}_{\theta}\) is fit from all visits not in the
held-out fold and \(\epsilon=\texttt{visit.cv.epsilon}\).

## Control Location

Graph random-walk controls live in `graph.control`, matching the direct
`fit.density.graph.random.walk()` interface.  OD-CV4 therefore takes candidate
grids from `graph.control`, not from `...`.  Passing graph random-walk candidate
grids through `...` is an error.

## Candidate Axes

The implemented OD-CV4 candidate axes are:

```text
walk.step
affinity.method
affinity.scale
affinity.epsilon
normalize
```

They are supplied through these `graph.control` entries:

```r
graph.control = list(
  walk.step.grid = ...,
  affinity.method.grid = ...,
  affinity.scale.grid = ...,
  affinity.epsilon.grid = ...,
  normalize.grid = ...
)
```

Aliases with underscores are accepted for the graph-control names that already
had underscore alternatives in the direct graph random-walk implementation.

If `walk.step.grid` is absent, OD-CV4 uses the resolved direct
`walk.steps`/`walk.step` control as the candidate grid.  A candidate
`walk.step = r` is passed to the direct graph random-walk method as

```r
walk.steps = sort(unique(c(0L, r)))
```

so the returned density is always the selected step while diagnostics still
include the zero-step origin when details are requested.

`affinity.scale = NA` in the candidate table means "use the direct method's
data-derived scale."  For `affinity.method = "inverse_length"`, affinity scale
is not used and is recorded as `NA` to avoid redundant candidate identifiers.

## Telemetry Contract

OD-CV4 returns the same visit-CV telemetry fields as the earlier OD-CV phases:

```text
visit.cv.table
visit.foldid
visit.cv.predicted.mass
diagnostics$od.visit.cv
diagnostics$od.visit.cv.selection
theta$od.cv
theta$visit.cv.score
theta$visit.cv.epsilon
```

The graph random-walk candidate table records:

```text
candidate.id
walk.step
affinity.method
affinity.scale
affinity.epsilon
normalize
visit.cv.neg.log.rho
visit.cv.mean.heldout.rho
visit.cv.nonfinite.count
visit.cv.zero.count
visit.cv.status
visit.cv.error.message
```

When `return.details = FALSE`, the full candidate table and prediction matrix
may be omitted, but the selected OD-CV metadata remains in `theta` and
`diagnostics`.

## Implemented Gate

OD-CV4 is considered implemented when:

1. `fit.subject.od(method = "graph_random_walk", od.cv = "visit", ...)`
   evaluates graph-control candidate grids and returns finite held-out visit
   scores on a smoke fixture.
2. The selected final fit records the selected `walk.step` and
   `affinity.method` consistently between `theta` and
   `diagnostics$od.visit.cv.selection`.
3. Compact `return.details = FALSE` keeps selected OD-CV metadata while
   omitting heavy candidate tables.
4. Graph random-walk candidate grids passed through `...` fail clearly, because
   graph controls belong in `graph.control`.

## Remaining Scope

OD-CV4 does not add graph-construction selection.  It assumes the graph itself
is supplied and fixed.

OD-CV4 does not add a `fit.subject.od(method = "metric_graph_lowpass")`
workflow.  Metric graph low-pass can already be normalized with
`normalize.density(fit.metric.graph.lowpass(...))`, but a first-class OD method
needs a separate API decision about response type, graph construction, spectral
cache reuse, and OD-level candidate axes.
