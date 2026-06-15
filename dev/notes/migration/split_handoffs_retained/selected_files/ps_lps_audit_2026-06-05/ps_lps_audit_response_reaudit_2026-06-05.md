# PS-LPS Audit Response Re-Audit 2026-06-05

## Verdict

Accepted with minor issues.

The response resolves the two blocking issues from
`ps_lps_first_implementation_audit_2026-06-05.md`:

1. The implementation now distinguishes ordinary nesting
   (`lambda.ridge = 0`, `lambda.sync = 0`) from ridge-stabilized nesting
   (`lambda.ridge > 0`, `lambda.sync = 0`).
2. Synchronization-energy diagnostics are now computed for all fitted
   coefficient vectors, including `lambda.sync = 0`.

The refined experiment also uses the correct matched baseline: ridge-LPS is
the `lambda.sync = 0` case under the same positive ridge policy used by the
ridge-stabilized PS-LPS fits.

## Checks Performed

- Read the audit response:
  `split_handoffs/ps_lps_audit_2026-06-05/ps_lps_audit_response_2026-06-05.md`.
- Inspected current implementation:
  `R/ps_lps.R`.
- Inspected focused tests:
  `tests/testthat/test-ps-lps.R`.
- Inspected refined experiment runner:
  `scripts/run_ps_lps_first_batch_refined_experiment.R`.
- Ran focused tests:

```bash
Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ps-lps.R")'
```

Result: 9 passed, 0 failed, 0 warnings, 0 skips.

- Ran cached refined report regeneration:

```bash
cd /Users/pgajer/current_projects/geosmooth
Rscript scripts/run_ps_lps_first_batch_refined_experiment.R
```

Result: completed and wrote
`split_handoffs/ps_lps_first_batch_refined_experiment_2026-06-05/ps_lps_first_batch_refined_experiment_report.html`.
`PS_LPS_FORCE` was not set, so existing RDS results were reused where present.

- Spot-checked frozen first-batch parity for FB01, FB06, and FB14, both
  `auto` and `local.auto`:
  `lambda.ridge = 0`, `lambda.sync = 0` matched ordinary LPS predictions
  exactly in all six checks, including vector chart dimensions for
  `local.auto`.

## Requested Re-Audit Questions

### 1. Does the explicit ridge-stabilized contract resolve the original lambda-zero interpretation problem?

Yes.

The original ambiguity was that `lambda.sync = 0` was presented as ordinary
LPS while the solver still imposed a ridge. The new contract makes the two
nested references explicit:

- ordinary LPS nesting: `lambda.ridge = 0`, `lambda.sync = 0`;
- ridge-LPS nesting: `lambda.ridge > 0`, `lambda.sync = 0`.

The implementation follows this contract. `fit.ps.lps()` now exposes
`lambda.ridge`, and `.ps.lps.solve()` dispatches `lambda.sync == 0` to an
independent chart-solve path. With `lambda.ridge = 0`, that path uses
unregularized `lm.wfit`; with `lambda.ridge > 0`, it uses the same
scale-relative ridge policy as the matched ridge-LPS baseline.

### 2. Is the zero-ridge, zero-sync test sufficient for ordinary-LPS nesting at the fixed-chart full-data level?

Yes for the stated fixed-chart full-data gate, with one minor hardening
recommendation.

The focused test checks scalar fixed-chart parity against ordinary `fit.lps()`.
I also spot-checked frozen assets for both scalar `auto` and vector
`local.auto` chart dimensions:

| Batch | Rule | Max absolute difference | RMSE difference | Sync energy at lambda zero |
|---|---:|---:|---:|---:|
| FB01 | auto | 0 | 0 | 5.7273 |
| FB01 | local.auto | 0 | 0 | 7.7108 |
| FB06 | auto | 0 | 0 | 13.2787 |
| FB06 | local.auto | 0 | 0 | 32.6271 |
| FB14 | auto | 0 | 0 | 41.7516 |
| FB14 | local.auto | 0 | 0 | 46.9182 |

Minor recommendation: add a permanent test for the vector-chart
`local.auto`-style path, because the first report used both scalar and
per-anchor chart dimensions.

### 3. Is ridge-LPS now the correct baseline for interpreting ridge-stabilized PS-LPS?

Yes.

For any comparison where PS-LPS uses `lambda.ridge = 1e-8`, the correct nested
baseline is ridge-LPS with the same fixed support, kernel, degree, chart rule,
and `lambda.ridge = 1e-8`, but `lambda.sync = 0`.

The refined experiment implements this: `ridge_auto` and `ridge_local_auto`
call `fit.ps.lps()` with `lambda.sync.grid = 0`, while the PS variants use the
same `lambda.ridge` and tune only `lambda.sync`.

Ordinary LPS remains useful as a secondary reference, but not as the direct
baseline for isolating the synchronization effect.

### 4. Are synchronization energy and mean squared disagreement now correctly computed and reported for `lambda.sync = 0`?

Yes.

The diagnostic loop in `.ps.lps.diagnostics()` now runs whenever sync rows
exist, independent of `lambda.sync`. The preferred diagnostic name
`mean.sync.squared.disagreement` is present, and the old
`mean.sync.disagreement` is retained as an alias.

The frozen spot checks above show nonzero `sync.energy` at
`lambda.sync = 0`, which is the expected behavior: at zero synchronization,
the disagreement is diagnostic but not penalized.

### 5. Does the refined report make a sufficiently cautious claim?

Mostly yes.

The refined report explicitly states that the first report confounded ordinary
LPS, independent ridge-stabilized LPS, and synchronized PS-LPS. It also says
that the production comparison should be read against matched ridge-LPS, not
only against ordinary LPS.

The refined tables support the cautious claim:

- best-method counts:
  - `PS-LPS auto`: 5 datasets;
  - `PS-LPS local.auto`: 8 datasets;
  - `ridge-LPS local.auto`: 1 dataset;
  - ordinary LPS variants: 0 datasets;
  - `ridge-LPS auto`: 0 datasets.
- median Truth-RMSE deltas:
  - `PS-LPS auto` versus `ridge-LPS auto`: `-0.01048`;
  - `PS-LPS local.auto` versus `ridge-LPS local.auto`: `-0.00865`.
- PS-LPS improves over the matched ridge-LPS baseline on 13 of 14 datasets for
  each PS variant.

Minor recommendation: when summarizing the refined result in prose, say
"median improvement over matched ridge-LPS, with 13/14 dataset-wise wins for
each PS variant" rather than implying a universal win.

## Minor Issues / Recommended Follow-Ups

1. Add a permanent `local.auto`-style vector-chart parity test for
   `lambda.ridge = 0`, `lambda.sync = 0`.
2. In the refined report/progress note, make the dataset-wise caveat explicit:
   PS-LPS improves over matched ridge-LPS in median and on 13/14 datasets for
   each PS variant, not on every dataset.
3. Keep the normal-equation ridge path marked as prototype until ridge-scale
   sensitivity and a larger lambda grid are tested.
4. If future reports expose `mean.sync.disagreement`, label it clearly as a
   squared disagreement alias or omit it in favor of
   `mean.sync.squared.disagreement`.

## Recommendation

Proceed to the next validation step. The original audit blockers are resolved
for the refined contract. The next work should expand lambda/ridge sensitivity
and add the vector-chart nesting regression test before relying on the
first-batch result for broader claims.
