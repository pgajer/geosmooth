# OD-CV0 Visit-Level Selection Contract

Source: `/Users/pgajer/current_projects/geosmooth/dev/shared/specs/od_cv0_visit_cv_selection_contract_2026-07-06.md`

## Purpose

This document freezes the first package-facing contract for occupation-density
parameter selection in `fit.subject.od()`.  The contract is deliberately narrow:
it defines how subject visits are held out, how candidate occupation densities
are scored, what telemetry must be recorded, and which OD methods currently
implement the contract.  Later OD-CV phases can add more methods and more
candidate axes without changing the meaning of the score recorded here.

The core principle is that OD selection should be evaluated at the level of the
subject's observed visits, not only at the level of pooled state-space rows.
For a subject with visits

```text
v_1, ..., v_m in {1, ..., nrow(X)},
```

an OD-level CV split holds out some of these visits, fits a density from the
remaining visits, and asks how much probability mass the fitted density assigns
to the held-out visits.

## Public API Contract

The public entry point is:

```r
fit.subject.od(
  X,
  subject.index,
  method = ...,
  od.cv = c("none", "visit"),
  visit.foldid = NULL,
  visit.cv.folds = 5L,
  visit.cv.seed = 1L,
  visit.cv.epsilon = 1e-15,
  ...
)
```

`od.cv = "none"` preserves the direct historical workflow.  The subject visits
are converted into a mass or binary response, the chosen method is fit once,
and the result is normalized as needed.

`od.cv = "visit"` activates OD-level visit cross-validation.  In this mode
`visit.foldid` is the fold vector.  Its length must equal
`length(subject.index)`, because it assigns folds to visits, not to rows of
`X`.  Row-level `foldid` must not be passed through `...` in this mode.  If
row-level CV is needed later, it must be made explicit as a nested selection
mode so the user can see that two CV layers are active.

## Visit-Level Score

For a candidate parameter setting theta and fold f, let

```text
I_f = {r : visit.foldid_r = f}
```

be the held-out visit positions and let

```text
T_f = {r : visit.foldid_r != f}
```

be the training visit positions.  The training subject index is

```text
subject.index[T_f].
```

The candidate method is fit on the training visits only.  This produces a
normalized density

```text
rho_hat_theta^(-f)(i) >= 0,
sum_i rho_hat_theta^(-f)(i) = 1.
```

The held-out score is the average negative log mass assigned to held-out visits:

```text
visit.cv.neg.log.rho(theta)
  =
  - (1 / m) sum_{r=1}^m
      log max{ rho_hat_theta^(-fold(r))( subject.index_r ),
               visit.cv.epsilon }.
```

Repeated visits are counted repeatedly.  This is intentional: if the same state
is visited several times, the held-out criterion treats those visits as several
observations from the subject's occupation process.  The consequence is that
OD-CV0 is a visit-level holdout, not a unique-state holdout.  If two visits map
to the same row of `X` and those visits are split across folds, the held-out
visit's state row can still receive empirical mass through the duplicate visit
that remains in the training folds.  This makes the score optimistic for
frequently revisited states.  That behavior is part of the OD-CV0 contract; a
future grouped-state or subject-blocked criterion would need a separate
explicit mode.

The selected candidate is the finite candidate with the smallest
`visit.cv.neg.log.rho`.  Ties use the common deterministic package rule: smaller
support, smaller degree where present, kernel name order, smaller bandwidth
multiplier, smaller ridge, then score.

## Required Telemetry

When `od.cv = "visit"` and `return.details = TRUE`, the returned object must
contain:

```r
fit$visit.cv.table
fit$visit.foldid
fit$visit.cv.predicted.mass
```

The candidate table must contain these columns:

```text
candidate.id
visit.cv.neg.log.rho
visit.cv.mean.heldout.rho
visit.cv.nonfinite.count
visit.cv.zero.count
visit.cv.status
visit.cv.error.message
```

`visit.cv.mean.heldout.rho` is reported only for candidates whose held-out
prediction vector is fully finite.  Failed candidates report `NA` in this
column so that a partial finite mean is not mistaken for a valid candidate
summary.

Candidate-parameter columns are method-specific.  For example,
`chart_kernel` records `support.size`, `kernel`, and
`bandwidth.multiplier`.  `local_likelihood_bernoulli` additionally records
`degree` and `lambda.ridge`.

The returned diagnostics must contain:

```r
fit$diagnostics$od.visit.cv
fit$diagnostics$od.visit.cv.selection
```

The selection object must identify the score column, selected candidate ID,
number of visits, number of folds, and epsilon floor.

When `return.details = FALSE`, the full candidate table and prediction matrix
may be omitted, but the selected final fit must still record that OD visit CV
was used through `theta$od.cv` and `diagnostics$od.visit.cv`.

## OD-CV0 Method Coverage

As of OD-CV0, `od.cv = "visit"` is implemented for:

- `method = "chart_kernel"`;
- `method = "local_likelihood_bernoulli"`.

It is intentionally not yet implemented for:

- `empirical`, where parameter selection is not meaningful;
- `graph_random_walk`, which needs a separate graph-scale and walk-scale
  candidate contract;
- `lps_count`, `lps_logistic_binary`, and `ps_lps_count`, which already have
  row-level or method-internal selection but still need an explicit outer
  OD-visit selection contract;
- `local_likelihood_density`, which needs density-branch candidate selection.

Unsupported methods must fail clearly when called with `od.cv = "visit"` rather
than silently reverting to row-level CV or direct fitting.

OD-CV2 later extends this coverage to `method = "local_likelihood_density"`;
see
`dev/shared/specs/od_cv2_chart_dim_grid_density_visit_cv_contract_2026-07-06.md`.

## Candidate Axes Frozen In OD-CV0

For `chart_kernel`, the OD-level candidate axes are:

```text
support.grid
kernel.grid
bandwidth.multiplier.grid
```

For `local_likelihood_bernoulli`, the OD-level candidate axes are:

```text
support.grid
degree.grid
kernel.grid
bandwidth.multiplier.grid
lambda.ridge.grid
```

The OD-CV0 contract does not include `chart.dim` as a candidate axis.  OD-CV1
adds deployable `chart.dim = "auto"` and `"local.auto"` policies for
chart-kernel and local-likelihood fits, but still holds the requested
chart-dimension policy fixed while OD visit CV searches the OD-CV0 axes.
OD-CV2 then adds `chart.dim.grid` as an OD-level candidate axis.

## Known Gaps For Later OD-CV Phases

OD-CV2 extends OD visit CV for chart methods so chart-dimension policies and
fixed dimensions can be included as candidate axes, and it adds selection for
`local_likelihood_density`.

OD-CV3 adds outer OD visit CV for LPS and PS-LPS workflows without silently
nesting row-level multi-candidate selection.  Each outer candidate is passed to
the source smoother as a scalar local model configuration; see
`dev/shared/specs/od_cv3_lps_outer_visit_cv_contract_2026-07-06.md`.

OD-CV4 adds OD visit CV for graph random-walk occupation densities over walk
step, affinity rule, affinity scale, affinity epsilon, and normalization policy;
see
`dev/shared/specs/od_cv4_graph_random_walk_visit_cv_contract_2026-07-06.md`.
Graph-construction scale remains outside OD-CV4 because OD-CV4 assumes a fixed
supplied graph.

OD-CV5 runs a small all-method smoke benchmark with a uniform OD-level
selection report; see
`dev/shared/specs/od_cv5_all_method_smoke_benchmark_contract_2026-07-06.md`.
