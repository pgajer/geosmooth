# HTML Report Style Audit Response

Worker: Codex
Date: 2026-06-07

Responds to:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/lps_ps_lps_backend_broader_p7x_html_report_style_audit_2026-06-07.md`

Regenerated report:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/reports/lps_ps_lps_backend_broader_p7x_comparison.html`

Generator patched:

`/Users/pgajer/current_projects/geosmooth/scripts/merge_lps_ps_lps_backend_broader_p7x_run.R`

## Changes Made

1. Replaced the crowded all-arms Truth RMSE plot with readable method-split figures:
   - LPS selected Truth RMSE by dataset.
   - PS-LPS selected Truth RMSE by dataset.
   - Distance from the in-method/chart best successful Truth RMSE.

2. Added fit-status accounting before score interpretation:
   - status counts;
   - arm coverage with `planned`, `ok`, `nonfinite_fit`, `error`, and `missing`;
   - regenerated `coverage_by_arm.csv` so it now counts all planned tasks, not only completed result rows.

3. Removed the large compact result table from the report body.
   Full raw tables are linked as audit artifacts instead.

4. Added a dedicated runtime and timeout section:
   - defines `elapsed_sec`;
   - includes runtime by arm on a log-scaled axis;
   - includes runtime by dataset;
   - includes the slowest rows;
   - explicitly labels the eight `worker_exit_-15` rows as manually killed long-tail tasks;
   - states that a strict 5400-second timeout would also have killed several successful guarded/drop PS-LPS rows.

5. Added a variable dictionary defining:
   - Truth RMSE;
   - selected CV RMSE;
   - Observed RMSE;
   - `ok`;
   - `nonfinite_fit`;
   - `error`;
   - `missing`;
   - `finite_cv_candidates`;
   - `total_cv_candidates`;
   - `elapsed_sec`.

6. Added Results Summary, What We Learned, and Recommendation sections.
   The report now directly states the main methodological takeaways:
   - `orthogonal_drop_adaptive_tiny` is the strongest LPS robustness candidate;
   - routine `weighted_qr_drop_tiny` should be dropped from broad comparisons or isolated as profiling-only;
   - PS-LPS guarded/drop variants need hard timeout controls before deployable accuracy claims;
   - the next comparison should focus on `monomial_tiny_ridge` versus `orthogonal_drop_adaptive_tiny`.

7. Added a reproducibility appendix linking:
   - `run_config.csv`;
   - `task_manifest.csv`;
   - `combined_results.csv`;
   - `task_status.csv`;
   - `coverage_by_arm.csv`;
   - `best_by_dataset.csv`;
   - `logs/python_launcher.log`;
   - the launcher, worker, and merge/report scripts.

## Validation

- Regenerated the report from precomputed artifacts with:

```sh
Rscript /Users/pgajer/current_projects/geosmooth/scripts/merge_lps_ps_lps_backend_broader_p7x_run.R --run_dir=/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001
```

- Confirmed the old `Compact Result Table` and `Truth RMSE Overview` sections are absent.
- Confirmed the regenerated report has the required top-level sections:
  Purpose, Run Design, Fit Status, Accuracy, Runtime, Discussion, Linked Artifacts, and Reproducibility.
- Confirmed `git diff --check` passes in `/Users/pgajer/current_projects/geosmooth`.

## Residual Notes

This response addresses report presentation and auditability. It does not rerun
the experiment. The underlying methodological limitation remains: the current
run has eight manually killed rows and several successful rows above 5400
seconds, so future backend policy should be based on a cleaner run with a hard
task timeout from the start.
