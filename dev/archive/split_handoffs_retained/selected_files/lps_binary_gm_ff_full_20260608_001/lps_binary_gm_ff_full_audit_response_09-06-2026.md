# LPS Binary GM/FF Full Run: Audit Response

Date: 09-06-2026
Run ID: `lps_binary_gm_ff_full_20260608_001`
Report: `~/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_full_20260608_001/reports/lps_binary_gm_ff_full_report.html`

## Summary

The auditor comments were accepted. The report has been revised so that it no
longer presents the run as a clean binary-family comparison. It now separates:

1. the valid deployable-policy comparison by probability Truth RMSE and runtime;
2. the invalid/missing fallback telemetry for local logistic fits;
3. the asymmetric candidate-selection metrics;
4. the geometry-specific reversal hidden by the pooled median; and
5. the difference between pair-level summaries and scenario-clustered summaries.

## Changes Made

### Worker Telemetry Patch

Patched:

`~/current_projects/geosmooth/scripts/run_lps_binary_gm_ff_task.R`

The worker now records the actual logistic diagnostic field names emitted by
`fit.lps()`, including:

- `logistic_cv_attempted`
- `logistic_cv_converged`
- `logistic_cv_failed`
- `logistic_cv_fallback_path_count`
- `logistic_cv_event_rate_fallback_count`
- `logistic_cv_fallback_path_fraction`
- `logistic_cv_event_rate_fallback_fraction`
- and the corresponding `logistic_final_*` fields.

The old compatibility columns
`logistic_cv_fallback_event_rate` and
`logistic_final_fallback_event_rate` are retained and filled from
`event.rate.fallback.fraction` in future runs.

This patch does not retroactively recover fallback telemetry for the cached
full run. The cached result rows still have all-`NA` legacy fallback columns.

### HTML Report Patch

Patched and regenerated:

`~/current_projects/geosmooth/scripts/render_lps_binary_gm_ff_report.R`

`~/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_full_20260608_001/reports/lps_binary_gm_ff_full_report.html`

The report now includes a **Data-Validity Notes Before Interpretation** section
that explicitly states:

- fallback telemetry is missing for this cached run;
- the current comparison is a deployed-policy comparison, not a clean fitting
  family comparison under a shared selection score;
- observed log loss is a full-data final-fit diagnostic, not a held-out
  validation diagnostic;
- pair-level intervals are descriptive and scenario-clustered summaries should
  be used for broad cross-scenario claims.

The report also now states the geometry interaction explicitly: logistic LPS
wins all 720 matched pairs on `1d_highdim_pad100`, while Bernoulli/Brier LPS
dominates the 3D geometries.

### Integer Count Formatting Fix

The prior HTML showed stale-looking `10,000` values in count tables. The
underlying manifest count was not 10,000; the renderer used significant-digit
formatting with `digits = 0`, which rounded integer counts incorrectly. The
table formatter now uses integer formatting for `digits = 0`.

### Observed Log-Loss Figure Removed

The previous observed-log-loss scatter was removed from the main report because
the cached `observed_logloss` field is computed on full-data final fitted
values:

```r
observed_logloss = logloss.score(pred, y)
```

with `pred <- fit$fitted.values`.

This is not fold-held-out log loss and should not be used as a validation
diagnostic.

### Auditor Handout Updated

Patched:

`~/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_full_20260608_001/lps_binary_gm_ff_full_auditor_handout_09-06-2026.md`

The handout now asks the auditor to explicitly review fallback telemetry,
selection-score asymmetry, geometry reversal, scenario-clustered uncertainty,
and observed-log-loss scope.

## New Derived Tables

The regenerated report writes these additional audit tables:

- `tables/binary_gm_ff_overall_clustered_delta_summary.csv`
- `tables/binary_gm_ff_chart_clustered_delta_summary.csv`
- `tables/binary_gm_ff_geometry_clustered_delta_summary.csv`
- `tables/binary_gm_ff_fallback_telemetry_validity.csv`
- `tables/binary_gm_ff_selection_metric_summary.csv`

## Validation

Checks performed after patching:

- `Rscript scripts/render_lps_binary_gm_ff_report.R --run_dir=...` completed.
- The report now has exactly five visible figure captions.
- The figure directory contains exactly five referenced PNG figures.
- No `10,000`, `10000`, `Figure 6`, or `Observed Binary Loss` stale report
  references remain.
- `git diff --check` passed for the touched worker, renderer, and handout.

## Remaining Scientific Limitations

The current cached run should not be used to conclude that local logistic
fitting is intrinsically worse than Bernoulli/Brier fitting. Before making that
claim, the next run should:

1. use the patched telemetry fields;
2. store held-out log-loss diagnostics if log loss is interpreted as validation;
3. compare both binary families under shared selection metrics, such as
   Brier-selected and log-loss-selected versions of both methods;
4. continue reporting geometry-stratified results rather than only pooled
   summaries.
