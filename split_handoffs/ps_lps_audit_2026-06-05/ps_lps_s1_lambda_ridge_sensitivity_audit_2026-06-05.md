# PS-LPS-S1 Lambda/Ridge Sensitivity Audit 2026-06-05

## Verdict

Accepted with minor issues.

The S1 experiment correctly enumerates the intended frozen first-batch
lambda/ridge grid, uses the matched `lambda.sync = 0` baseline at the same
ridge scale, and reports the main numerical caveats honestly. The generated
tables support the stated conclusion: selected PS-LPS improves over matched
independent baselines in median Truth RMSE across all tested ridge scales and
both chart rules.

There are no blocking issues. The main nonblocking issue is a figure-labeling
bug: the plotting helper rounds `log10(lambda)` and therefore merges distinct
lambda values in figure labels, for example `0.01` and `0.03`. The CSV tables
and numerical summaries are correct, but the figures should be regenerated
with exact labels before broader circulation.

## Checks Performed

- Read the S1 audit handoff:
  `split_handoffs/ps_lps_audit_2026-06-05/ps_lps_s1_lambda_ridge_sensitivity_audit_handoff_2026-06-05.md`.
- Inspected S1 runner:
  `scripts/run_ps_lps_s1_lambda_ridge_sensitivity.R`.
- Inspected generated tables under:
  `split_handoffs/ps_lps_s1_lambda_ridge_sensitivity_2026-06-05/tables/`.
- Inspected progress report source:
  `split_handoffs/ps_lps_progress_2026-06-05/ps_lps_progress_report.tex`.
- Checked progress-report PDF text with `pdftotext`; the PDF contains the S1
  section and the expected 896-row, boundary-selection, and next-grid wording.
- Regenerated the S1 report from cached block results:

```bash
cd /Users/pgajer/current_projects/geosmooth
Rscript scripts/run_ps_lps_s1_lambda_ridge_sensitivity.R
```

I did not set `PS_LPS_FORCE`, so this was a cached regeneration. I also did not
set `PS_LPS_S1_WORKERS`, so my audit run used the default one worker; the
script supports the reported four-worker execution path.

## Gate 1: S1 Scheduler and Cache Correctness

Status: passes.

The scheduler enumerates:

- 14 frozen first-batch datasets;
- two chart rules: `auto` and `local.auto`;
- four ridge values: `0`, `1e-10`, `1e-8`, `1e-6`;
- eight synchronization values: `0`, `0.01`, `0.03`, `0.1`, `0.3`, `1`, `3`, `10`.

This yields 112 cached blocks and 896 candidate rows. The cache path is unique
per dataset, chart rule, and ridge value:

```text
<batch>__<dataset>__<rule>__ridge_<ridge>.rds
```

Each block contains all eight `lambda.sync` candidates for that fixed
dataset/rule/ridge combination. Therefore `parallel::mclapply()` cannot cause
two workers to write the same result path unless the task grid itself contains
duplicates; the generated candidate table had no duplicate
dataset/rule/ridge/sync keys.

Aggregation uses the returned block objects, including cached objects when
present, and writes candidate, selected, delta, and summary tables from the
same object list.

## Gate 2: Matched-Baseline Logic

Status: passes.

The matched baseline table is built from candidate rows with
`lambda_sync == 0` and `status == "ok"`, keyed by:

- `batch_id`;
- `dataset_id`;
- `chart_dim_rule`;
- `lambda_ridge`.

The selected table is merged against that baseline on the same keys, and the
reported delta is computed as:

```r
selected.truth_rmse - baseline.truth_rmse
```

This is the requested matched baseline: same dataset, chart rule, ridge scale,
support size, degree, kernel, and chart construction. Support, degree, and
kernel are fixed within each block from the corresponding ordinary LPS result.

## Gate 3: Chart-Dimension Reuse

Status: passes.

For `chart_dim_rule = "auto"`, the script uses the scalar selected chart
dimension:

```r
lps.result$selected$chart.dim[[1L]]
```

For `chart_dim_rule = "local.auto"`, it uses the per-anchor vector
`lps.result$chart_dim_by_eval`, with a fallback to
`lps.result$chart.dim.by.eval` for older object naming. If neither exists,
`.ps.lps.prepare.chart.dim()` will fail rather than silently using an invalid
dimension object.

The script uses synthetic truth only after fitting, to compute `truth_rmse`.
It does not use truth or latent dimensions to choose charts, lambda values, or
model parameters.

## Gate 4: Zero-Ridge and Fallback-Ridge Interpretation

Status: passes, with caveat correctly documented.

Requested `lambda.ridge = 0` rows are useful as a stress test of the
unregularized path. They should not be described as uniformly exact
unregularized solves because the coupled positive-sync normal-equation solve
can fall back to a numerical ridge when the unregularized solve fails.

The progress report states this accurately: zero-ridge rows are included, but
the solver used its internal fallback ridge on a small number of zero-ridge
candidate solves, and those rows should not be called uniformly exact
unregularized normal-equation solves.

The generated tables confirm the handoff counts:

- zero-ridge candidate rows with `ridge_max > 0`: 35;
- selected zero-ridge rows with `ridge_max > 0`: 5.

The five selected fallback rows are all at positive synchronization and all
have negative Truth-RMSE deltas against the matched zero-sync baseline. This
means the zero-ridge subgroup is partly a fallback-ridge stress result, but it
does not undermine the main ridge-stabilized interpretation because the
positive-ridge groups also show negative median deltas.

Reporting `ridge_median` and `ridge_max` is sufficient for this S1 audit. A
future solver report should add an explicit fallback flag/count per candidate
for easier filtering.

## Gate 5: Boundary Synchronization Selection

Status: passes; limitation is real.

The progress report correctly treats boundary selection as the main limitation.
Median selected `lambda.sync` is 10 for both chart rules at all ridge scales.
Most selected rows are at the upper boundary:

- `auto`: 49 of 56 selected rows at `lambda.sync = 10`;
- `local.auto`: 48 of 56 selected rows at `lambda.sync = 10`.

S1 is still meaningful: even within the tested range, synchronization improves
over matched independent baselines in median Truth RMSE across all ridge
scales. But the result does not identify a stable optimum. The next run should
extend above 10 before prospective validation.

Recommended next synchronization grid:

```text
0, 0.01, 0.03, 0.1, 0.3, 1, 3, 10, 30, 100
```

If 100 is again frequently selected, add a smaller follow-up at:

```text
30, 100, 300
```

At larger synchronization values, record numerical diagnostics carefully:

- finite fitted values and CV scores;
- `ridge_max` and fallback counts;
- condition/failure warnings from the coupled solve;
- synchronization energy and mean squared disagreement;
- whether Truth RMSE/CV profiles plateau, improve, or deteriorate.

## Gate 6: Reported Summary Correctness

Status: tables pass; figures need label fix.

Generated table checks:

- candidate rows: 896;
- selected rows: 112;
- delta rows: 112;
- summary rows: 8;
- all candidate rows have status `ok`;
- no duplicate dataset/rule/ridge/sync candidate keys;
- no nonfinite Truth RMSE values among `ok` candidate rows.

The reported medians and win counts match
`ps_lps_s1_summary_by_rule_ridge.csv`:

| Chart rule | lambda.ridge | Median delta | Wins |
|---|---:|---:|---:|
| auto | 0 | -0.022237333 | 12/14 |
| local.auto | 0 | -0.015230739 | 13/14 |
| auto | 1e-10 | -0.013191778 | 12/14 |
| local.auto | 1e-10 | -0.011044088 | 12/14 |
| auto | 1e-8 | -0.015233782 | 12/14 |
| local.auto | 1e-8 | -0.010947594 | 12/14 |
| auto | 1e-6 | -0.014251938 | 12/14 |
| local.auto | 1e-6 | -0.010574720 | 12/14 |

Median selected `lambda.sync` is 10 for every chart-rule/ridge group.

Nonblocking figure issue: `log.label()` rounds `log10(lambda)`, so distinct
grid values are merged in figure labels:

| lambda.sync | plotted label |
|---:|---:|
| 0.01 | 1e-2 |
| 0.03 | 1e-2 |
| 0.1 | 1e-1 |
| 0.3 | 1e-1 |
| 1 | 1e0 |
| 3 | 1e0 |

This affects the visual auditability of the selected-scale and candidate
profile figures. Use exact labels such as `0.01`, `0.03`, `0.1`, `0.3`, `1`,
`3`, `10` and regenerate the figures/report.

Because all candidate rows are `ok`, no figure is hiding failed/non-finite
rows in this run.

## Gate 7: Statistical Interpretation

Status: agree, with one wording refinement.

I agree with the intended conclusion:

> S1 supports prediction synchronization as useful on this frozen first-batch
> suite because median Truth-RMSE improvements over matched independent
> baselines appear across ridge scales, but the selected synchronization
> strength is often at the upper grid boundary, so the synchronization search
> range should be extended before prospective validation.

I would revise "often" to "usually" or "predominantly" because selected
`lambda.sync = 10` occurs in 97 of 112 selected rows. The claim should remain
limited to this frozen first-batch suite and should not be described as a
prospective validation result.

## Gate 8: Progress Report Accuracy

Status: passes.

The S1 section in `ps_lps_progress_report.tex` is accurate, readable, and
appropriately cautious. It reports:

- 896 candidate rows;
- all rows `ok`;
- the zero-ridge fallback caveat;
- the median delta/win table;
- median selected `lambda.sync = 10`;
- the need to extend the synchronization grid before prospective validation.

The PDF text contains the same S1 section and key statements. I did not see
overstated claims in the progress report.

## Gate 9: Next-Step Recommendation

Recommended path: run S2 as an extended synchronization-grid sensitivity study
on the same frozen suite before prospective validation.

Use the same matched-baseline design and ridge grid, but extend
`lambda.sync` above 10:

```text
0, 0.01, 0.03, 0.1, 0.3, 1, 3, 10, 30, 100
```

Keep the full 14-dataset suite if runtime remains manageable from cache/block
execution. If runtime becomes a problem, first run a diagnostic subset with:

- datasets where S1 selected `lambda.sync = 10`;
- datasets where requested zero-ridge positive-sync solves triggered fallback;
- both chart rules.

Do not proceed to a prospective experiment until S2 shows either an interior
or plateauing synchronization range, or at least shows that larger
`lambda.sync` values do not create numerical instability or reverse the
S1 signal.

## Blocking Issues

None.

## Nonblocking Issues and Fixes

1. Fix `log.label()` so figure labels do not collapse distinct lambda values.
2. Add an explicit fallback flag/count per candidate row, in addition to
   `ridge_median` and `ridge_max`.
3. Consider adding a selected-row summary that reports the number and fraction
   of boundary selections by chart rule and ridge scale.
4. Continue to label zero-ridge positive-sync rows with fallback ridge as
   stress-test rows, not uniformly exact unregularized solves.

