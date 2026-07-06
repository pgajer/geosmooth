# OD-CV3 LPS-Family Outer Visit-CV Contract

Source: `/Users/pgajer/current_projects/geosmooth/dev/shared/specs/od_cv3_lps_outer_visit_cv_contract_2026-07-06.md`

## Purpose

OD-CV3 extends the OD-level visit cross-validation contract to the LPS-family
subject-occupation density workflows:

- `method = "lps_count"`;
- `method = "lps_logistic_binary"`;
- `method = "ps_lps_count"`.

The goal is to choose deployable smoother parameters by the same subject-visit
held-out score used in OD-CV0 through OD-CV2:

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

Here \(x_r\) is the state visited at subject visit \(r\), \(F(r)\) is its visit
fold, \(\widehat\rho^{(-F(r))}_{\theta}\) is the normalized OD estimate fit
without visits in that fold, and \(\epsilon=\texttt{visit.cv.epsilon}\) is the
positive log-score floor.

## Non-Nesting Rule

OD-CV3 deliberately treats the LPS-family source smoothers as fixed-candidate
engines inside the outer OD visit-CV loop.  Each outer candidate is passed to
the source smoother as a scalar local model configuration.

For LPS methods, this means each OD candidate uses singleton source grids:

```text
support.grid = support.size
degree.grid = degree
kernel.grid = kernel
bandwidth.multiplier.grid = bandwidth.multiplier
chart.dim = chart.dim
```

For PS-LPS, this means each OD candidate uses scalar local settings and a
singleton synchronization grid:

```text
support.size = support.size
degree = degree
kernel = kernel
lambda.sync.grid = lambda.sync
lambda.sync.search = "grid"
local.candidate.search = "full"
chart.dim = chart.dim
```

The source fit may still produce a one-row source CV table as part of its
existing implementation, but OD-CV3 does not allow multi-candidate row-level
selection inside each held-out-visit fold.  The selected candidate is the
candidate minimizing the OD visit-CV score.

## Candidate Axes

For `method = "lps_count"` and `method = "lps_logistic_binary"`, OD-CV3
candidates are the Cartesian product of:

```text
support.size
degree
kernel
bandwidth.multiplier
chart.dim
```

The method-specific response is fixed by the method:

- `lps_count` uses normalized count mass with
  `fit.lps(..., outcome.family = "gaussian")`;
- `lps_logistic_binary` uses a binary visit indicator with
  `fit.lps(..., outcome.family = "bernoulli")`, then clips and normalizes the
  resulting probability field.

For `method = "ps_lps_count"`, OD-CV3 candidates are the Cartesian product of:

```text
support.size
degree
kernel
lambda.sync
chart.dim
```

The `lambda.sync` axis comes from the user-supplied `lambda.sync.grid`.

## Chart-Dimension Policy

The `chart.dim.grid` argument follows the OD-CV2 convention.  Candidate tables
record:

- `chart.dim`, with stable labels `"NULL"`, positive integer labels such as
  `"1"`, `"auto"`, and `"local.auto"`;
- `chart.dim.rank`, the deterministic order used for tie-breaking.

For `ps_lps_count`, either `chart.dim` or `chart.dim.grid` must be supplied,
because `fit.ps.lps()` requires an explicit chart-dimension policy.

## Telemetry Contract

OD-CV3 returns the same outer-visit telemetry fields as OD-CV0 through OD-CV2:

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

When `return.details = FALSE`, the full candidate table and prediction matrix
may be omitted, but the selected OD-CV metadata remains in `theta` and
`diagnostics`.

## Implemented Gate

OD-CV3 is considered implemented when:

1. `fit.subject.od(method = "lps_count", od.cv = "visit", ...)` evaluates the
   OD candidate grid, returns finite held-out visit scores on a smoke fixture,
   and normalizes the selected source fit to total mass one.
2. `fit.subject.od(method = "lps_logistic_binary", od.cv = "visit", ...)`
   preserves the Bernoulli LPS OD workflow and evaluates its OD candidate grid.
3. `fit.subject.od(method = "ps_lps_count", od.cv = "visit", ...)` evaluates
   singleton PS-LPS candidates, including `lambda.sync` values, under the OD
   visit-CV score.
4. `ps_lps_count` fails clearly when OD visit CV is requested without
   `chart.dim` or `chart.dim.grid`.

## Remaining Scope

OD-CV3 does not add outer OD visit CV for graph random-walk or metric graph
low-pass densities.  Those belong to OD-CV4 because they need a graph-scale and
walk/filter-scale candidate contract.

OD-CV3 does not implement nested row-level CV inside each outer OD candidate.
If nested selection is needed later, it should be added with an explicit
argument and telemetry contract rather than hidden behind the existing source
method grids.
