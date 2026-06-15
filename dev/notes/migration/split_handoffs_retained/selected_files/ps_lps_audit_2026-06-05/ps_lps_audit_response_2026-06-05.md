# PS-LPS First Implementation Audit Response 2026-06-05

This response addresses the blocking audit report:

`~/current_projects/geosmooth/split_handoffs/ps_lps_audit_2026-06-05/ps_lps_first_implementation_audit_2026-06-05.md`

## Summary

The audit was correct. The original PS-LPS prototype mixed two effects:

1. prediction synchronization through `lambda.sync`; and
2. an unconditional numerical ridge in the sparse normal-equation solve.

That made the original `lambda.sync = 0` comparison non-nested relative to
ordinary LPS, and it made the first report too favorable to interpret as a
clean synchronization effect.

The implementation now exposes and reports the ridge explicitly through
`lambda.ridge`. The refined comparison separates ordinary LPS, independent
ridge-stabilized LPS, and synchronized ridge-stabilized PS-LPS.

## Implementation Changes

Implemented in:

`~/current_projects/geosmooth/R/ps_lps.R`

Changes:

- Added public argument `lambda.ridge`, defaulting to `1e-8`.
- Added explicit `lambda.ridge`, `ridge.min`, `ridge.median`, and `ridge.max`
  diagnostics.
- Added a `lambda.sync == 0` independent-solve path.
- With `lambda.ridge = 0`, the independent path uses unregularized local
  weighted least squares.
- With `lambda.ridge > 0`, the independent path uses the same ridge policy as
  the coupled PS-LPS solve.
- Synchronization diagnostics are now computed for every fitted coefficient
  vector whenever overlap rows exist, including `lambda.sync = 0`.
- Added preferred diagnostic name `mean.sync.squared.disagreement`.
- Retained `mean.sync.disagreement` only as a compatibility alias equal to the
  squared-disagreement diagnostic.

## Test Changes

Added:

`~/current_projects/geosmooth/tests/testthat/test-ps-lps.R`

The focused tests cover:

- normalized product overlap-weight mass per synchronized chart pair;
- zero-ridge, zero-sync nesting against ordinary LPS full-data fitted values;
- positive-ridge, zero-sync nesting against the independent ridge-LPS solver
  path;
- nonzero synchronization energy and nonzero mean squared overlap
  disagreement at `lambda.sync = 0` when charts disagree.

Validation command:

```bash
cd /Users/pgajer/current_projects/geosmooth
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-ps-lps.R")'
```

Result: 9 passed, 0 failed, 0 warnings, 0 skips.

## Refined Experiment

Added and ran:

`~/current_projects/geosmooth/scripts/run_ps_lps_first_batch_refined_experiment.R`

Generated report:

`~/current_projects/geosmooth/split_handoffs/ps_lps_first_batch_refined_experiment_2026-06-05/ps_lps_first_batch_refined_experiment_report.html`

The refined experiment compares:

- ordinary `LPS auto`;
- `ridge-LPS auto`;
- `PS-LPS auto`;
- ordinary `LPS local.auto`;
- `ridge-LPS local.auto`;
- `PS-LPS local.auto`.

All ridge-LPS and PS-LPS rows use `lambda.ridge = 1e-8`.
Ridge-LPS is defined as the matched `lambda.sync = 0` baseline.
PS-LPS uses `lambda.sync.grid = {0, 0.1, 1}`.

All 84 method--dataset rows completed successfully.

Headline refined results:

- best method counts:
  - `PS-LPS local.auto`: 8 datasets;
  - `PS-LPS auto`: 5 datasets;
  - `ridge-LPS local.auto`: 1 dataset;
  - ordinary LPS variants: 0 datasets;
  - `ridge-LPS auto`: 0 datasets.
- median Truth RMSE:
  - `PS-LPS local.auto`: 0.04048;
  - `PS-LPS auto`: 0.04517;
  - `ridge-LPS local.auto`: 0.04868;
  - `LPS local.auto`: 0.05755;
  - `ridge-LPS auto`: 0.05752;
  - `LPS auto`: 0.06978.

Median Truth-RMSE deltas:

- `ridge-LPS auto` versus ordinary `LPS auto`: -0.00651;
- `ridge-LPS local.auto` versus ordinary `LPS local.auto`: -0.00638;
- `PS-LPS auto` versus ordinary `LPS auto`: -0.02437;
- `PS-LPS local.auto` versus ordinary `LPS local.auto`: -0.02190;
- `PS-LPS auto` versus `ridge-LPS auto`: -0.01048;
- `PS-LPS local.auto` versus `ridge-LPS local.auto`: -0.00865.

Interpretation:

The original favorable PS-LPS result was partly a ridge-stabilization effect,
but not only a ridge effect. In the refined first-batch experiment, positive
prediction synchronization still improves over the matched ridge-LPS baseline
in median Truth RMSE.

## Documentation Updates

Updated:

- `~/current_projects/geosmooth/split_handoffs/lps_prediction_synchronized_design_2026-06-05/lps_prediction_synchronized_design.tex`
- `~/current_projects/geosmooth/split_handoffs/ps_lps_progress_2026-06-05/ps_lps_progress_report.tex`

The design note now distinguishes:

- ordinary nesting: `lambda.ridge = 0`, `lambda.sync = 0`;
- ridge-stabilized nesting: `lambda.ridge > 0`, `lambda.sync = 0`.

The progress report now records the blocked audit, the response, the refined
experiment, and the matched ridge-LPS interpretation.

## Residual Risks

- The current PS-LPS implementation is still an R prototype.
- The positive synchronization grid `{0, 0.1, 1}` is small.
- The ridge scale has not yet been stress-tested.
- The CV protocol remains transductive in covariates; this is intentional, but
  should remain explicit in reports.
- The next validation should re-audit the refined implementation/report before
  using the first-batch result as a basis for broader claims.

## Requested Re-Audit Questions

Please re-audit the implementation and refined experiment with special attention
to:

1. whether the explicit ridge-stabilized contract resolves the original
   lambda-zero interpretation problem;
2. whether the zero-ridge, zero-sync test is sufficient for ordinary-LPS
   nesting at the fixed-chart full-data level;
3. whether ridge-LPS is now the correct baseline for interpreting the
   ridge-stabilized PS-LPS results;
4. whether the synchronization-energy and mean squared disagreement diagnostics
   are now correctly computed and reported for `lambda.sync = 0`;
5. whether the refined report makes a sufficiently cautious claim, namely that
   PS-LPS improves over matched ridge-LPS in this first-batch experiment, not
   that synchronization has been validated generally.
