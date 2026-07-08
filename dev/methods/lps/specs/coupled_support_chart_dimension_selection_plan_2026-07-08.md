# Coupled Support-Size x Chart-Dimension Selection Plan

Source path:
`~/current_projects/geosmooth/dev/methods/lps/specs/coupled_support_chart_dimension_selection_plan_2026-07-08.md`

## Purpose

This is a good time to start a coupled support-size and chart-dimension
selection pass.  The immediate reason is practical: geosmooth now has a
PCA-coordinate reuse path that can build one local PCA chart at the largest
numeric chart dimension requested for a fixed support size and then reuse the
leading columns for smaller chart dimensions.  That makes a sparse
`support.size x chart.dim` search much less wasteful than it was before.
This statement is about the local geometry work: PCA, support extraction, and
chart-coordinate construction.  It does not mean that every downstream solve is
amortized.  In particular, PS-LPS still has a per-candidate synchronized system
solve whose size grows with the number of local polynomial coefficients.  The
reuse layer helps PS-LPS most when geometry dominates; it helps much less when a
large chart dimension makes the synchronized solve dominate.  This is why the
coupled selector must keep high-dimensional guard candidates bounded and rare.

The statistical reason is stronger.  In local-chart smoothers, the support size
`k` and chart dimension `d` are not independent tuning parameters.  The support
size controls the scale at which the local neighborhood is viewed, and the
dimension controls how much of that neighborhood is treated as signal-bearing
geometry.  A large `k` may justify a larger `d`; a small `k` may require a
smaller `d` for stable local polynomial fitting.  Searching these axes
separately can therefore select pairs that are individually plausible but
jointly poor.

The first target is an engineering-safe, auditable selector layer for LPS-type
methods:

- `fit.lps()`;
- `fit.ps.lps()`;
- `fit.chart.kernel()`;
- `fit.local.likelihood()`;
- OD-level wrappers through `fit.subject.od()`.

The first implementation should not change default scientific conclusions.  It
should add an explicit experimental selection mode that can be compared against
the existing one-dimensional grids.

## Current Starting Point

The PCA-coordinate reuse optimization currently covers numeric chart-dimension
grids for fixed support sizes in OD-level visit CV paths.  The relevant assets
are:

- implementation: `~/current_projects/geosmooth/R/state_density.R`;
- tests: `~/current_projects/geosmooth/tests/testthat/test-state-density-odcv3-lps-outer-visit-cv.R`;
- implementation handoff:
  `~/current_projects/geosmooth/dev/methods/ps_lps/handoffs/phase/ps_lps_pca_coordinate_reuse_optimization_handoff_2026-07-08.md`;
- audit:
  `~/current_projects/geosmooth/dev/methods/ps_lps/audits/pca_coordinate_reuse/ps_lps_pca_coordinate_reuse_audit_2026-07-08.md`.

The important implementation rule is:

- LPS and PS-LPS can reuse the native support objects directly when their model
  uses the same ambient support distances and kernel weights.
- Chart-kernel and local-likelihood methods can reuse support indices and
  max-dimension PCA coordinates, but must recompute chart-space distances and
  kernel weights after slicing the coordinates to the candidate dimension.

This distinction must remain part of every coupled-selector implementation.

## Selection Object

For an anchor point `x_i`, a support size `k`, and chart dimension `d`, the local
chart is constructed from

```text
U_i(k) = {x_i and its k - 1 nearest neighbors}.
```

For `coordinate.method = "local.pca"`, the centered support matrix is projected
onto its first `d` principal directions.  A candidate is a tuple

```text
theta = (k, d, kernel, degree, bandwidth.multiplier, ridge policy, method-specific parameters).
```

This plan focuses only on the coupled `(k, d)` portion.  Other axes should be
held fixed or searched over a very small guard set during the first pass.

The first reusable cache key should be

```text
(support.size, kernel, max.numeric.chart.dim)
```

for methods whose support weights depend on the same kernel used by the native
support object.  For chart-kernel and local-likelihood methods, the safer key is

```text
(support.size, max.numeric.chart.dim)
```

because the model-specific kernel weights are recomputed from sliced chart
coordinates.

## Feasibility Rule

The coupled selector must record infeasible `(k,d)` candidates explicitly, and
it needs one deterministic rule for doing so.  For a local polynomial of degree
`g` in `d` chart coordinates, the full monomial feature count, including the
intercept, is

```text
q(d, g) = choose(d + g, g).
```

Before any rank-dropping or orthogonalization, the local design should have
more observations than columns.  The initial feasibility rule should be

```text
k >= q(d, g) + design.margin,
```

where `design.margin` is an explicit nonnegative integer, with recommended
default `design.margin = 2`.  This is a prefit screening rule, not a replacement
for numerical rank and condition checks.  A candidate can pass this rule and
still be marked unstable later if the realized weighted design is rank-deficient
or ill-conditioned.

For a fixed `k` and degree `g`, define

```text
d_feasible.max(k, g)
  =
  max {d >= 1 : choose(d + g, g) + design.margin <= k}.
```

If the set is empty, the candidate family for that `k` and `g` should be marked
infeasible.  This precise rule replaces vague references to a design margin in
later sections.

The count `q(d,g)` is intentionally the full pre-drop monomial count.  This is a
conservative prefit screen.  It does not assume the final fitted basis will keep
all columns: guarded orthogonal or rank-dropping backends may retain fewer
columns after seeing the weighted local design, but the candidate generator
should screen on the largest possible column count before fitting.

## Full-Grid Reference And Sparse Coupled Grid

A full Cartesian product such as

```text
k in 15:35, d in 1:8
```

should be the reference candidate set for method evaluation whenever it is
computationally feasible.  This full grid should be interpreted as an empirical
candidate oracle, not as the routine deployable selector.  It answers the
question: if compute were not the constraint, which `(k,d)` pair would the
method choose under the same outer-evaluation or truth-evaluation target?

The full Cartesian reference should be run on all feasible small and medium
benchmark cells and on calibrated subsets of large 16S-style or high-dimensional
cells.  Sparse coupled selectors should then be judged by how closely they
approximate this reference in outer-heldout or truth-facing performance, and by
how much runtime and candidate-count reduction they buy.  A sparse selector is
not validated merely because it produces a good-looking inner CV score.

For routine or large-scale use, the production-oriented selector can use a
sparse coupled grid with explicit guard candidates, but only after it has been
benchmarked against the full Cartesian reference.

Recommended first sparse grid:

1. Choose a small support skeleton:

   ```text
   K0 = {k_min, k_mid, k_max}
   ```

   clipped to the available sample size and method constraints.  For OD/P7X
   style examples, this might be `{15, 25, 35}` or quantile-spaced values from
   the broader grid.

2. Choose a small dimension skeleton:

   ```text
   D0(k, g) = {1, 2, d_auto.clipped(k, g), d_hi(k, g)}
   ```

   where `d_auto.raw(k)` is the current global auto estimate at that support
   size, and

   ```text
   d_hi(k, g) = min(chart.dim.max, p, d_feasible.max(k, g)).
   ```

   Here `chart.dim.max` is not a universal statistical cap and should not be
   hard-coded to a small number such as 6.  It is an explicit experiment or
   caller-supplied budget for the candidate family being tested.  For example,
   a fast smoke run may set `chart.dim.max = 6`, while a broader validation run
   may set `chart.dim.max` to the largest dimension in the requested
   `chart.dim.grid`, or even to `d_feasible.max(k,g)` if the goal is to audit
   all feasible dimensions.  The important rule is not that the high guard is
   6; the rule is that the maximum dimension used for a reuse group must be
   explicit, recorded, and controlled by the experiment design.

   The auto seed must not be allowed to raise the maximum reused PCA dimension
   beyond this explicit candidate-family bound.  Therefore the numeric auto seed
   used in the sparse grid is

   ```text
   d_auto.clipped(k, g) = min(d_auto.raw(k), d_hi(k, g)).
   ```

   Telemetry must record both `d_auto.raw(k)` and `d_auto.clipped(k,g)`, with a
   boolean column such as `chart.dim.seed.clipped`.  This protects high-
   dimensional noisy examples where global auto dimension can over-select badly
   and would otherwise force every candidate in the support group to build PCA
   coordinates at a dimension that was not actually requested by the sparse-grid
   design.

3. Evaluate the sparse Cartesian skeleton

   ```text
   K0 x D0(k, g),
   ```

   where `D0(k,g)` is support- and degree-specific because auto dimension,
   feasibility, and the feature count can depend on both `k` and `g`.  The PCA
   reuse group itself remains degree-independent: when several degrees share
   the same support group, the cached local PCA coordinates should be built at
   the maximum feasible numeric `d` required across those degrees.

4. Around the best few skeleton candidates, evaluate local neighbors:

   ```text
   k in {k_best - h, k_best, k_best + h},
   d in {d_best - 1, d_best, d_best + 1},
   ```

   with clipping and feasibility guards.  The first implementation may use
   `h = 2` for a tiny smoke run, but this should not be a fixed rule.  The
   support-radius refinement width should scale with the spacing of the support
   skeleton.  For example, if adjacent skeleton values differ by `gap`, use a
   first refinement width near `ceiling(gap / 2)` or add a second refinement
   round when the selected support lies between widely separated skeleton
   points.  This prevents a sparse skeleton such as `{15,25,35}` from leaving
   the middle of each interval essentially unexplored.

5. Add guard candidates that deliberately test whether the selected pair is
   boundary-driven:

   ```text
   (k_min, d_best), (k_max, d_best), (k_best, 1), (k_best, d_hi).
   ```

The output should record both the planned candidates and the candidates that
were actually evaluated after clipping and feasibility checks.

## Relationship To `auto` And `local.auto`

The first coupled selector should focus on numeric chart dimensions because that
is where max-dimension PCA-coordinate reuse is most direct.

However, the selector should not ignore existing auto policies.  Instead:

- `chart.dim = "auto"` should be allowed as a seed generator that proposes
  `d_auto.raw(k)` for each support size.  The evaluated numeric seed must be
  `d_auto.clipped(k,g) = min(d_auto.raw(k), d_hi(k,g))`, not the raw auto value.
  This is a cost-control rule, not an argument that the true dimension is
  bounded by a small universal constant.  If the experiment is designed to test
  dimensions up to 12, then `chart.dim.max = 12`; if it is designed to test all
  feasible dimensions, then `chart.dim.max` should be set accordingly.
- `chart.dim = "local.auto"` should be treated as a separate policy, not mixed
  into the same numeric `d` grid in the first implementation.

The reason is that `local.auto` produces a vector of dimensions, one per anchor.
That does not fit the same cache contract as a scalar numeric `d`, although it
may still benefit from a future max-local-dimension cache that builds one chart
per anchor at that anchor's maximum needed local dimension and slices it to the
anchor-specific selected dimension.

The first report should compare:

- existing `auto`;
- existing `local.auto`;
- sparse coupled numeric `(k, d)` selector seeded by `auto`;
- optionally, full grid on small examples as an oracle reference.

## Proposed Phases

### CSD0: Contract And Candidate Schema

Define an internal candidate-table schema for coupled `(k, d)` selection.

Required columns:

- `candidate.id`;
- `stage` (`skeleton`, `local_refine`, `guard`, `full_reference`);
- `support.size`;
- `chart.dim`;
- `chart.dim.source` (`numeric`, `auto_seed`, `guard`, `manual`);
- `chart.dim.raw`;
- `chart.dim.clipped`;
- `chart.dim.seed.clipped`;
- `chart.dim.max`;
- `kernel`;
- `degree`;
- `bandwidth.multiplier`;
- `design.ncol`;
- `design.margin`;
- `feasible`;
- `skip.reason`;
- `reuse.key`;
- `score`;
- `elapsed.sec`.

Deliverables:

- private candidate-construction helper;
- unit tests showing duplicate candidates are removed deterministically;
- unit tests showing `d_auto.raw(k)` is clipped to `d_hi(k,g)` and cannot raise
  the reused maximum PCA dimension above `chart.dim.max`;
- unit tests showing infeasible `(k, d)` pairs are recorded rather than silently
  discarded.

### CSD1: Reuse-Aware Evaluation Backend

Generalize the current OD visit-CV reuse helpers so a candidate evaluator can
request all candidates for a fixed `(support.size, kernel)` group and evaluate
them using one max-dimension PCA construction.

This should be a candidate-generation and evaluation layer feeding the existing
OD-CV chart-dimension machinery, not a parallel selection implementation.  OD-CV
already exposes `chart.dim.grid` as a candidate axis; the coupled selector should
construct a smaller, staged candidate table and pass those candidates through
the same cached scalar-candidate evaluator wherever possible.

The grouping helper should not split reuse groups by `degree`, because the PCA
coordinates are degree-independent.  Degree affects the local design matrix and
feasibility rule, but not the local PCA support coordinates themselves.

Deliverables:

- helper that groups numeric chart-dimension candidates by reusable cache key;
- tests proving the native local-PCA support builder is called once per support
  group rather than once per `(k, d)` candidate;
- parity tests showing cached and uncached evaluation produce the same scores
  across dimensions, kernels, degrees, and at least one deliberately
  rank-deficient or near-rank-deficient support.

### CSD2: LPS And OD LPS Integration

Add an experimental selector mode to LPS/OD LPS paths.

Possible API name:

```r
coupled.selection = c("none", "sparse_kd")
```

or, if this is exposed only through CV:

```r
selection.strategy = c("grid", "sparse_kd")
```

The naming should follow existing function conventions at implementation time.

Deliverables:

- `fit.lps()` support if the existing public API can absorb it cleanly;
- `fit.subject.od(method = "lps_count")`;
- `fit.subject.od(method = "lps_logistic_binary")`;
- telemetry recording planned/evaluated candidates and reuse counts.

### CSD3: Chart-Kernel And Local-Likelihood Integration

Apply the same sparse coupled candidate strategy to:

- `fit.chart.kernel()`;
- `fit.local.likelihood(likelihood.family = "density")`;
- `fit.local.likelihood(likelihood.family = "bernoulli")`;
- OD wrappers for `chart_kernel`, `local_likelihood_density`, and
  `local_likelihood_bernoulli`.

The evaluator must reuse PCA coordinates but recompute chart-space distances and
kernel weights after slicing to the candidate dimension.  The adaptive bandwidth
must also be recomputed after slicing, because chart-kernel and local-likelihood
bandwidths are functions of the chart-space distance distribution.

Deliverables:

- implementation;
- parity tests against ordinary scalar-candidate loops;
- call-count tests for max-dimension PCA reuse.

### CSD4: PS-LPS Integration

Add the same sparse coupled support-size and dimension selector to PS-LPS.
This phase should wait until CSD1-CSD3 settle because PS-LPS has the most
expensive solve path and the largest interaction with lambda search.

PCA-coordinate reuse does not reuse the PS-LPS synchronized normal matrix or its
factorization across different chart dimensions.  The synchronized solve is
per-candidate and its size increases with

```text
n x q(d, g),
```

where `q(d,g) = choose(d+g,g)` is the local polynomial coefficient count per
anchor.  Therefore PS-LPS sparse-grid cost is governed not only by the number of
unique PCA builds, but also by the number of high-`d` synchronized solves.  This
is the main reason CSD4 should use a small bounded dimension grid and refine
`lambda.sync` only for a few promising `(k,d)` pairs.

Required policy decision:

- either select `(k, d)` first and then search `lambda.sync`;
- or include `lambda.sync` in the local refinement stage only.

Recommended first version:

1. Use sparse coupled `(k, d)` selection with `lambda.sync` fixed at a small
   guard grid such as `{0, lambda_default}`.
2. Refine `lambda.sync` only for the top few `(k, d)` pairs.

Deliverables:

- implementation;
- profiling on the OD4-expanded/P7X-style cells used in recent optimization
  work;
- report separating support/PCA time, system assembly time, solve time, and
  score time.

### CSD5: Evaluation Report

Run a focused comparison before changing defaults.

Minimum report questions:

1. Does sparse coupled `(k, d)` recover the best or near-best full-grid
   candidate on every benchmark cell where the full Cartesian grid is feasible?
2. When the full grid is too expensive for the complete cell, does the sparse
   selector recover the full-grid behavior on a calibrated subset?
3. Does it reduce runtime and candidate count relative to the full grid?
4. Does it improve over independent or one-axis selection under the same outer
   or truth-facing metric?
5. Does it behave differently on homogeneous-manifold examples versus
   heterogeneous/non-manifold examples?
6. Does it change selected support sizes in a biologically interpretable way for
   OD-style examples?

The report must not compare selection strategies by the inner CV score each
strategy optimized.  That would favor broader searches simply because they have
more chances to find a low noisy validation score.  Instead, CSD5 must use a
strategy-level outer evaluation:

1. For each dataset and outer split, hold out an outer evaluation fold that is
   not used by any selector.
2. Within the remaining data, run each selection arm using identical inner
   folds and the same inner scoring rule.
3. Refit each selected candidate on the outer-training data.
4. Score all selected fits on the same outer fold using the same held-out
   metric.
5. Aggregate paired outer scores across folds, datasets, and repetitions.

On synthetic examples with known truth, report truth-facing accuracy as an
additional target.  For OD-style synthetic density examples, this means scoring
against the known subject-occupation density or known generated visit law when
available.  On continuous-outcome examples, this means reporting truth RMSE or
the analogous truth-risk measure.  The full-grid reference should be defined on
the outer target or truth target, not merely as the lowest inner-CV score.

The full Cartesian reference should use the same feasible candidate universe
that the sparse selector is trying to approximate.  For the first evaluation
suite, the default reference grid should be

```text
k in 15:35,
d in 1:8,
```

after feasibility filtering by `q(d,g) + design.margin <= k` and any explicit
experiment-level `chart.dim.max`.  The report must record the planned full grid,
the feasible full grid, and any candidates skipped for numerical or timeout
reasons.  If the full grid cannot be completed for a large cell, the report
should mark that cell as full-grid-incomplete and provide the calibrated subset
used to estimate sparse-selector regret.

All strategy arms must use matched outer folds, matched inner folds, and the
same held-out metric.  The comparison arms should include:

- existing `auto`;
- existing `local.auto`;
- independent or one-axis support/dimension selection, when available;
- sparse coupled numeric `(k,d)`;
- full Cartesian `(k,d)` reference on every example or calibrated subset where
  it is computationally feasible.

The report should follow:

- `/Users/pgajer/.codex/notes/agent_instructions/reports/html_report_style_guide.md`;
- `/Users/pgajer/.codex/notes/agent_instructions/reports/report_figure_table_qc.md`.

Figures should include:

- score surface over evaluated `(k, d)` candidates;
- selected `(k, d)` over datasets;
- runtime versus outer-target regret or truth-target regret;
- full-grid regret when a full-grid outer/truth reference is available;
- sparse-miss diagnostics: where the sparse selector's choice sits relative to
  the full-grid winner on the `(k,d)` surface;
- reuse accounting: planned candidates, unique PCA builds, avoided PCA builds.

## Acceptance Criteria

Before this direction can be used routinely, the implementation should satisfy:

1. Cached and uncached scalar-candidate evaluation agree to numerical tolerance.
2. Numeric chart-dimension grids call the local PCA builder once per reusable
   support group, not once per dimension.
3. Skipped candidates are visible in telemetry with reasons.
4. `auto` and `local.auto` are not silently conflated with numeric
   chart-dimension grids.
5. Raw global-auto dimension seeds are clipped by the explicit `chart.dim.max`
   and feasibility rule before they enter any numeric reuse group, and telemetry
   records every clipped seed.
6. The first report includes full Cartesian `(k,d)` references on all feasible
   small and medium benchmark cells, using at least the planned grid
   `k in 15:35, d in 1:8` after feasibility filtering.  Large cells that cannot
   complete the full grid must include a calibrated full-grid subset and be
   labeled as incomplete rather than silently treated as validated.
7. Strategy comparisons use matched outer folds or known-truth targets; they do
   not use each arm's optimized inner CV score as the primary evidence of
   superiority.
8. No default method behavior changes until an auditor accepts the focused
   comparison report.

## Risks And Design Constraints

The main statistical risk is that sparse grids can miss narrow optima in `(k,d)`.
This is why guard candidates and full Cartesian reference grids are required
wherever feasible.  Sparse-grid misses are not failures by themselves, but they
must be visible: the report should show how far the sparse selected candidate is
from the full-grid winner in support size, chart dimension, outer/truth score,
and runtime.

The main engineering risk is accidentally reusing quantities that are not
semantically shared.  In particular, chart-kernel and local-likelihood methods
must not reuse kernel weights computed from ambient distances when the model
definition uses chart-space distances.

The main API risk is overloading `chart.dim = "auto"` and
`chart.dim = "local.auto"`.  Numeric coupled grids, global auto seeds, and local
auto dimension vectors should remain visibly distinct in both user-facing
arguments and telemetry.

The main runtime risk is allowing an uncapped `auto` seed to become the maximum
numeric dimension in a reuse group.  This would make the cache build a large
PCA basis for every candidate in that support group and, for PS-LPS, would also
force expensive high-dimensional synchronized solves.  The
`d_auto.clipped(k,g)` rule is therefore a runtime guard as well as a
statistical guard.

## Recommended Next Action

Proceed with CSD0 and CSD1 first.  These phases are small enough to audit, and
they create the reusable candidate schema and cache grouping that all later
method integrations need.  Do not start with PS-LPS; it is the most expensive
and has additional lambda-search interactions that would make the first audit
needlessly tangled.
