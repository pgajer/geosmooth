# P7X / S3R-light Corrected Run Auditor Handoff

Generated: 2026-06-07

This handoff asks the auditor to review the corrected seed-matched S3R-light
run for PS-LPS full versus screened support search. The purpose is to decide
whether the corrected S3R-light evidence is sound enough to use as a smoke /
profiling result and whether the proposed S3R-expanded run can proceed.

## Authoritative Corrected Run

Use this run directory as the authoritative corrected S3R-light run:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_20260607_002`

Primary report:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_20260607_002/reports/ps_lps_s3r_light_report.html`

Important tables:

- Task manifest:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_20260607_002/task_manifest.csv`
- Pre-launch QA summary:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_20260607_002/PRELAUNCH_QA_SUMMARY.txt`
- Manifest QA summary:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_20260607_002/manifest_qa_summary.csv`
- Task status:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_20260607_002/tables/task_status.csv`
- Task summary:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_20260607_002/tables/task_summary.csv`
- Full-versus-screened paired results:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_20260607_002/tables/full_vs_screened_pairs.csv`
- Local candidate details:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_20260607_002/tables/local_candidate_details.csv`
- Paired summary by chart rule:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_20260607_002/tables/paired_summary_by_chart_rule.csv`
- Candidate inclusion diagnostics:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_20260607_002/tables/candidate_inclusion_diagnostics.csv`

Figures are under:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_20260607_002/reports/figures_s3r_light`

## Do Not Use The Earlier Flawed Run For Paired Accuracy Claims

The earlier S3R-light run was stopped because the full and screened arms were
not response/fold seed matched. It may be useful only as a smoke/profiling
artifact, not as evidence about full-versus-screened accuracy:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_20260607_001`

Its smoke/profiling report is:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_20260607_001/reports/ps_lps_s3r_light_smoke_profiling_report.html`

Please explicitly confirm that the corrected audit uses
`ps_lps_s3r_light_seedmatched_20260607_002`, not the stopped flawed run.

## Prior Audit Chain

The corrected run followed this audit chain:

- Initial S3R audit:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_2026-06-07.md`
- Audit response plan:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_response_2026-06-07.md`
- Response-plan audit:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_response_plan_audit_2026-06-07.md`
- Response-plan audit response:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_response_plan_audit_response_2026-06-07.md`
- Timeout taxonomy re-audit:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_response_plan_audit_response_reaudit_2026-06-07.md`
- Timeout taxonomy response:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_response_plan_audit_response_reaudit_response_2026-06-07.md`
- Final pre-launch re-audit:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_response_plan_audit_response_reaudit_response_reaudit_2026-06-07.md`

The final pre-launch re-audit accepted launch after timeout statuses were made
explicit and seed-matched manifest QA passed.

## Run Design

S3R-light compares two PS-LPS support-search policies:

- `full`: evaluate the full support grid.
- `screened`: use a screened subset of local support candidates, then run the
  same guarded lambda search on the screened candidate set.

Fixed settings:

- method: `ps_lps`
- backend variant: `monomial_tiny_ridge`
- design basis: `monomial`
- ridge multiplier: `1e-8`
- kernel: `tricube`
- degree: `2`
- support grid: `15:35`
- lambda grid: `0, 0.001, 0.01, 0.1, 1, 10`
- lambda search: `guarded`
- chart-dimension rules: `auto`, `local.auto`
- screened support-search control:
  `top.n=8; max.candidates=12; neighbor.radius=1; guard.support.quantiles=0|0.5|1`

Experimental factors:

- frozen first-batch P7X datasets: 14
- repetitions per dataset: 3
- chart-dimension rules: 2
- search policies: 2

Planned task count:

```text
14 * 3 * 2 * 2 = 168
```

Planned paired comparisons:

```text
14 * 3 * 2 = 84
```

Each pair compares `full` versus `screened` under the same dataset, repetition,
chart-dimension rule, response seed, and fold seed.

## Pre-launch QA

The pre-launch QA summary states:

```text
planned_tasks: 168
planned_pairs: 84
seed_matched_pairs: 84
mismatched_pairs: 0
qa_passed: TRUE
```

The manifest QA also checks that:

- each pair has exactly two arms;
- each pair has one `full` arm and one `screened` arm;
- response seeds match within every pair;
- fold seeds match within every pair;
- asset paths are present;
- source hashes are well formed;
- dataset, repetition, chart-rule, and search-policy counts are balanced.

## Execution Summary

The corrected run completed successfully.

Observed status:

```text
tasks ok: 168
errors: 0
timeouts: 0
nonfinite: 0
missing results: 0
complete paired rows: 84
seed mismatches: 0
```

The launcher and worker scripts used one-task-per-worker status/result files so
that a single task failure would not halt the run. In this corrected run, no
task failures were observed.

## Main Results To Audit

The paired quantity is:

```text
delta Truth RMSE = Truth RMSE(screened) - Truth RMSE(full).
```

Thus negative values favor screened search, positive values favor full search,
and values near zero indicate practically matched fits.

Overall across 84 complete pairs:

- median delta Truth RMSE: `0`
- mean delta Truth RMSE: approximately `0.00211`
- median screened/full runtime ratio: approximately `0.3796`
- median screened/full candidate-count ratio: approximately `0.1905`

By chart-dimension rule:

| chart rule | complete pairs | mean delta Truth RMSE | 95% CI low | 95% CI high | median delta Truth RMSE | median runtime ratio | median screened candidates | median full candidates | support inclusion rate |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `auto` | 42 | 0.0039435652 | 0.0003388079 | 0.0075483225 | 0 | 0.3177872 | 4.5 | 21 | 0.3809524 |
| `local.auto` | 42 | 0.0002780636 | -0.0002039349 | 0.0007600620 | 0 | 0.4146456 | 4.0 | 21 | 0.3095238 |

Interpretation to audit:

- `screened` usually reaches essentially the same synthetic Truth RMSE as
  `full`, especially under `local.auto`.
- `screened` is substantially faster in this light run, using about 38% of full
  runtime overall.
- The speedup is consistent with the corrected candidate-count diagnostic:
  screened evaluates a median of about 4 candidates versus 21 for full.
- The exact full-selected support/candidate is often not included in the
  screened candidate set, but the selected Truth RMSE is usually nearly
  unchanged. This means support-search screening may be adequate for routine
  use, but the inclusion diagnostic should be interpreted alongside accuracy,
  not as a correctness gate by itself.

## Candidate-count And Inclusion Correction To Audit Carefully

There was a post-run bookkeeping issue in the worker summary: the original
worker-level summary counted all top-level support rows because it checked the
wrong column name. The local candidate detail table uses
`local.candidate.status`, not `candidate.status`.

The report and merged tables have been regenerated so that candidate counts and
candidate-inclusion diagnostics are recomputed from:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_20260607_002/tables/local_candidate_details.csv`

Please audit that:

1. `screened_candidates_evaluated` and `full_candidates_evaluated` in
   `full_vs_screened_pairs.csv` are derived from local-candidate detail rows,
   not from the stale worker summary;
2. Figure 3 in the HTML report uses the corrected candidate-count ratio;
3. Figure 4 uses the corrected inclusion diagnostics;
4. the report text explains that, because degree and kernel are fixed in
   S3R-light, the candidate key is effectively the selected support size plus
   fixed degree/kernel.

## Report Style And Figure QA

The final HTML report was regenerated after the candidate-count correction. It
is intended to follow:

- `/Users/pgajer/.codex/notes/agent_instructions/reports/html_report_style_guide.md`
- `/Users/pgajer/.codex/notes/agent_instructions/reports/report_figure_table_qc.md`

Please audit the report for:

- clear statement of the main questions;
- explicit formulas/definitions for Truth RMSE, delta Truth RMSE, runtime ratio,
  and candidate-count ratio;
- visible and numbered figure captions;
- figure labels and legends that do not overlap;
- explanations of Figure 3 and Figure 4 that make the speedup mechanism clear;
- no excessive tables in the main report body;
- no claims that exceed the light-run evidence.

## Requested Audit Questions

Please answer these questions explicitly.

1. Does the corrected run use a valid seed-matched full-versus-screened paired
   design?
2. Are all 168 planned tasks accounted for, and are all 84 planned pairs
   complete?
3. Are failure, timeout, nonfinite, and missing-result statuses explicit enough
   for this run and for future repeated runs?
4. Are the candidate-count and inclusion diagnostics now computed correctly from
   local candidate details?
5. Is the report interpretation of Figure 3 correct: screened is faster mainly
   because it evaluates far fewer local support candidates?
6. Is the report interpretation of Figure 4 correct: exact full-selected
   candidate inclusion is modest, but the accuracy delta is usually near zero?
7. Does S3R-light support using screened PS-LPS as the routine run policy, or
   should it be treated only as a smoke/profiling result pending S3R-expanded?
8. If S3R-expanded should proceed, should it use 10 repetitions, 20
   repetitions, or another design?
9. Are there any remaining blockers before S3R-expanded launch?

## Suggested Auditor Output

Please write the audit to:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_light_corrected_run_audit_2026-06-07.md`

If the verdict is accepted with comments, please specify whether the next step
is:

1. launch S3R-expanded;
2. revise S3R-light report/bookkeeping first;
3. modify the screened policy before S3R-expanded; or
4. keep screened search experimental and return to profiling/algorithm work.
