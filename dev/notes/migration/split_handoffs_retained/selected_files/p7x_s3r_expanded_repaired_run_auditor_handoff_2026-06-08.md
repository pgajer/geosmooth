# P7X / S3R-Expanded Repaired Run Auditor Handoff

Generated: 2026-06-08

This handoff asks the auditor to review the S3R-expanded PS-LPS full-versus-screened
support-search run after the screened-failure repair pass. The user referred to
this as the S3R-extended run; in the file assets this is the 20-repetition
S3R-expanded run.

The audit should answer whether the repaired run and report are now sound enough
to use as evidence for the screened PS-LPS support-search policy.

## Authoritative Repaired Assets

Use this merged repaired bundle as the authoritative run for final S3R-expanded
interpretation:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001`

Primary repaired HTML report:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001/reports/ps_lps_s3r_expanded_repaired_results_report.html`

Primary repaired tables:

- Merged task manifest:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001/task_manifest.csv`
- Merged task status:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001/tables/task_status.csv`
- Merged task summary:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001/tables/task_summary.csv`
- Full-versus-screened paired results:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001/tables/full_vs_screened_pairs.csv`
- Local candidate details:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001/tables/local_candidate_details.csv`
- Paired summary by chart rule:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001/tables/paired_summary_by_chart_rule.csv`
- Paired summary by dataset:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001/tables/paired_summary_by_dataset.csv`
- Candidate inclusion diagnostics:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001/tables/candidate_inclusion_diagnostics.csv`
- Repair merge provenance:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001/REPAIR_MERGE_PROVENANCE.md`

The original pre-repair run remains here:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_20260607_001`

The screened-only repair bundle is here:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_screened_repair_guarded_20260608_001`

The original run was not overwritten. The repaired merged bundle preserves the
original full-search rows and originally successful screened rows, and replaces
only the artifact paths for the originally failed screened rows with the repaired
screened-task artifacts.

## Repair Bundle

The screened-only repair bundle reran exactly the 51 screened-policy rows that
had non-ok status in the original expanded run.

Repair bundle provenance:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_screened_repair_guarded_20260608_001/REPAIR_PROVENANCE.md`

Repair task manifest:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_screened_repair_guarded_20260608_001/task_manifest.csv`

Repair task status:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_screened_repair_guarded_20260608_001/tables/task_status.csv`

Repair scope by dataset:

```text
LA-D2-RAW-N500              1 task
LA-D2-HC-TOP1-N500          3 tasks
LA-D3-RAW-N500              7 tasks
SYN-SIMPLEX-FACES-N600     40 tasks
```

Repair accounting:

```text
screened ok: 51
screened non-ok: 0
```

Important audit point: the repair-task rows preserved the original S3R-expanded
method settings, including `backend_variant = "monomial_tiny_ridge"` and
`design_basis = "monomial"`. The repair did not silently change the scientific
comparison to a different PS-LPS backend. The repaired source changes the
screened prefilter failure path so ill-conditioned degree-2 LPS screening uses a
guarded orthogonal-polynomial/drop solver and degree-1 fallback before declaring
`lps_screen_failed`.

## Original Versus Repaired Accounting

Original S3R-expanded task status:

```text
full      ok: 560
screened  ok: 509
screened  error: 51
```

Screened-only repair status:

```text
screened ok: 51
```

Merged repaired task status:

```text
full      ok: 560
screened  ok: 560
```

Merged repaired paired accounting:

```text
planned pairs: 560
complete pairs: 560
```

The audit should verify that the repaired merged report uses the full planned
denominator and no longer presents the pre-repair 509-complete-pair denominator
as the final result.

## Experimental Design

S3R-expanded compares two PS-LPS support-search policies:

- `full`: evaluate the full support-size grid.
- `screened`: first use the screened support-selection policy, then evaluate
  PS-LPS on the retained support candidates.

The paired unit is:

```text
(dataset_id, repetition, chart_dim_rule)
```

Each pair contains exactly one `full` row and one `screened` row with the same
dataset, repetition, chart-dimension rule, response seed, fold seed, and fixed
method settings except for support-search policy.

Factors:

- 14 frozen P7X first-batch datasets;
- 20 repetitions;
- 2 chart-dimension rules: `auto`, `local.auto`;
- 2 search policies: `full`, `screened`.

Planned tasks:

```text
14 * 20 * 2 * 2 = 1120
```

Planned paired comparisons:

```text
14 * 20 * 2 = 560
```

Fixed method settings from the original manifest:

- method: `ps_lps`;
- backend variant: `monomial_tiny_ridge`;
- design basis: `monomial`;
- ridge multiplier: `1e-8`;
- ridge condition cap: `Inf`;
- kernel: `tricube`;
- degree: `2`;
- support grid: `15:35`;
- lambda grid: `0, 0.001, 0.01, 0.1, 1, 10`;
- lambda search: `guarded`;
- screened local-candidate search control:
  `top.n=8; max.candidates=12; neighbor.radius=1; guard.support.quantiles=0|0.5|1`.

## Main Repaired Results To Audit

The paired accuracy contrast is:

```text
delta Truth RMSE = Truth RMSE(screened) - Truth RMSE(full).
```

Negative values favor screened support search; positive values favor full search.

By chart-dimension rule:

| chart rule | planned pairs | complete pairs | mean delta Truth RMSE | 95% CI low | 95% CI high | median delta Truth RMSE | median screened/full runtime | median screened candidates | median full candidates |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `auto` | 280 | 280 | 0.0006577171 | 0.0000458099 | 0.0012696243 | 0 | 0.3684665 | 6 | 21 |
| `local.auto` | 280 | 280 | -0.0000194990 | -0.0002979636 | 0.0002589655 | 0 | 0.4456354 | 4 | 21 |

All repetitions:

```text
complete pairs: 560
mean delta Truth RMSE: 0.0003191090
95% CI: [-0.0000179059, 0.0006561239]
median delta Truth RMSE: 0
median screened/full runtime ratio: 0.4379457
```

Candidate inclusion diagnostics:

| chart rule | diagnostic | rate |
|---|---|---:|
| `auto` | full support in screened supports | 0.5000000 |
| `auto` | full candidate key in screened candidates | 0.5000000 |
| `auto` | selected support match | 0.5000000 |
| `auto` | selected lambda match | 0.8071429 |
| `local.auto` | full support in screened supports | 0.4607143 |
| `local.auto` | full candidate key in screened candidates | 0.4607143 |
| `local.auto` | selected support match | 0.4607143 |
| `local.auto` | selected lambda match | 0.8107143 |

Task elapsed-time quantiles:

| search policy | median | 90% | 95% | 99% |
|---|---:|---:|---:|---:|
| `full` | 65.6310 | 702.5686 | 2361.9130 | 2873.9660 |
| `screened` | 37.8505 | 497.7016 | 1799.9644 | 2253.7391 |

## Implementation And Documentation Changes To Audit

The relevant source changes are in:

- `/Users/pgajer/current_projects/geosmooth/R/ps_lps.R`
- `/Users/pgajer/current_projects/geosmooth/R/lps.R`
- `/Users/pgajer/current_projects/geosmooth/scripts/run_ps_lps_s3r_light_task.R`
- `/Users/pgajer/current_projects/geosmooth/scripts/merge_ps_lps_s3r_light_run.R`
- `/Users/pgajer/current_projects/geosmooth/scripts/prepare_ps_lps_s3r_light_run.R`
- `/Users/pgajer/current_projects/geosmooth/scripts/render_ps_lps_s3r_expanded_results_report.R`
- `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ps-lps.R`
- `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R`

The key implementation repair is:

1. Screened PS-LPS support prefilter failures no longer abort because a local
   degree-2 monomial screen becomes ill-conditioned.
2. The LPS screening path uses a guarded solver:
   - `design.basis = "orthogonal.polynomial.drop"`;
   - ridge grid includes `0`, `1e-10`, and `1e-8`;
   - finite condition cap defaults to `1e12` for screening if the caller
     supplied `Inf`;
   - degree-1 fallback is attempted when the primary degree-2 screen cannot
     produce finite scores.
3. If the guarded screen still cannot produce finite candidates, the task is
   classified as an LPS-screen failure instead of crashing the whole run.
4. Failed screened tasks save enough telemetry/candidate information to support
   postmortem grouping.
5. The polished report renderer is now parameterized by `--run_dir`,
   `--report_name`, `--source_run_dir`, and `--repair_run_dir`, so the repaired
   report can be generated without overwriting the original report path.

Documentation/reporting changes to audit:

- the repaired report includes repair provenance near the top;
- it explicitly states that all 560 full rows and all 560 screened rows are
  now `ok`;
- it uses the full 560-pair denominator;
- it no longer claims that `SYN-SIMPLEX-FACES-N600` is absent from dataset-level
  figures;
- Figure 6 is now described as zero screened-policy errors in the repaired
  bundle;
- the recommended next step asks for audit of the repaired bundle rather than
  asking to patch the old failure paths again.

## Validation Already Run

The following focused validation was run before this handoff:

```text
make document
testthat::test_file("tests/testthat/test-ps-lps.R")        # 128 passed
testthat::test_file("tests/testthat/test-ge7-lps-api.R")   # 192 passed
testthat::test_file("tests/testthat/test-ge1-r-smoothers.R") # 53 passed
```

Repair/merge/report validation:

```text
screened repair run: 51 / 51 ok
merged repaired run: 560 full ok, 560 screened ok
merged complete pairs: 560 / 560
git diff --check: clean
```

Do not infer that full `make test`, `make check-fast`, or `make check` was run
for this specific handoff. They were not run after the final repaired report
generation.

## Specific Audit Questions

Please audit the repaired S3R-expanded run with attention to the following.

1. Does the repaired merged bundle correctly preserve the original full-search
   and originally successful screened rows while replacing only the 51 originally
   failed screened rows with repaired artifacts?

2. Do the repaired screened-task manifest rows preserve the original scientific
   comparison settings, especially `backend_variant = "monomial_tiny_ridge"`
   and `design_basis = "monomial"`, rather than silently changing the backend
   of only the repaired rows?

3. Does the guarded LPS screening repair in `R/ps_lps.R` solve the screened
   prefilter failure mode without masking genuine nonfinite or numerical
   failures as successful fits?

4. Are the new screening telemetry fields sufficient for future failures to be
   grouped and diagnosed?

5. Does the repaired report follow the HTML report guidelines well enough:
   stated main questions, formulas/definitions, numbered figure captions,
   interpretation paragraphs, compact visible tables, and linked full artifacts?

6. Does the report correctly use all 560 complete seed-matched pairs and avoid
   stale pre-repair language about 51 failures or missing datasets?

7. Are the accuracy and runtime conclusions supported by the repaired tables?
   In particular, is it fair to say that screened PS-LPS is nearly identical in
   median Truth RMSE while using fewer support candidates and less runtime?

8. Is it now reasonable to promote screened PS-LPS as the routine experimental
   support-search policy, with full-grid search retained as a validation or
   reference mode? If not, specify exactly what additional evidence or code
   changes are required.

## Requested Auditor Output

Please write an audit report in:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_expanded_repaired_run_audit_2026-06-08.md`

Please include:

- verdict: accepted / accepted with minor comments / blocked;
- any correctness blockers;
- any report/documentation blockers;
- any residual implementation risks;
- recommended next step for PS-LPS support-search policy.
