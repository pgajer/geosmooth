# P7X / S3R Audit Response Plan Audit Response

Date: 2026-06-07

Response to:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_response_plan_audit_2026-06-07.md`

## Summary

Accepted and addressed.

The audit accepted the corrective plan but required implementation-level
clarifications before the corrected S3R-light run.  I patched the S3R-light
preparer, worker, merger/report script, and response-plan handoff so the
clarifications are now executable contract items rather than prose-only
intentions.

No corrected full S3R-light run was launched in this response.  I only created
and validated a seed-matched pre-launch QA manifest and ran one small
full/screened pair smoke test to verify the corrected worker/merger path.

## Changes Made

### 1. Explicit seed formula and pre-launch QA gate

Patched:

`/Users/pgajer/current_projects/geosmooth/scripts/prepare_ps_lps_s3r_light_run.R`

The preparer now:

- defines `pair_id = (dataset_id, repetition, chart_dim_rule)`;
- computes pair seeds before iterating over `search_policy`;
- uses explicit intermediate seed variables:
  `dataset_seed_component`, `repetition_seed_component`,
  `chart_seed_component`, `pair_seed_base`, `pair_fold_seed`, and
  `pair_response_seed`;
- excludes `search_policy` from every seed component;
- writes `pair_seed_base`, `pair_fold_seed`, `pair_response_seed`,
  `fold_seed`, and `response_seed` to every task row;
- writes pre-launch QA artifacts:
  - `manifest_qa_summary.csv`
  - `manifest_pair_qa.csv`
  - `manifest_balance_qa.csv`
  - `PRELAUNCH_QA_SUMMARY.txt`
- fails fast if manifest QA fails;
- makes the generated launcher refuse to run unless
  `PRELAUNCH_QA_SUMMARY.txt` records `qa_passed: TRUE`.

Validation artifact:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_manifest_qa_20260607_001/PRELAUNCH_QA_SUMMARY.txt`

Observed:

- planned tasks: 168
- planned pairs: 84
- seed-matched pairs: 84
- mismatched pairs: 0
- QA passed: TRUE

### 2. Candidate identity diagnostics

Patched:

`/Users/pgajer/current_projects/geosmooth/scripts/run_ps_lps_s3r_light_task.R`

The worker now preserves pair metadata and writes:

- `pair_id`
- `pair_seed_base`
- `pair_response_seed`
- `pair_fold_seed`
- `selected_candidate_key`
- `evaluated_candidate_keys`

The candidate key is:

```text
support.size | degree | kernel
```

The synchronized penalty is kept separate and compared through `lambda_match`.

### 3. Manifest-backed status and pair tables

Patched:

`/Users/pgajer/current_projects/geosmooth/scripts/merge_ps_lps_s3r_light_run.R`

The merger now:

- starts from the task manifest, not from successful results;
- writes one `task_status.csv` row per planned task;
- distinguishes `not_started`, `running`, `ok`, `nonfinite_fit`, `error`,
  `timeout`, and `missing_or_corrupt_status`;
- builds one `full_vs_screened_pairs.csv` row per planned pair;
- keeps incomplete pairs visible through:
  - `full_status`
  - `screened_status`
  - `pair_status`
  - `pair_complete`
  - `pair_exclusion_reason`
- computes accuracy deltas only for complete `ok/ok` pairs;
- writes `local_candidate_details.csv`;
- reports:
  - `full_support_in_screened_evaluated_supports`
  - `full_candidate_key`
  - `screened_evaluated_candidate_keys`
  - `full_candidate_key_in_screened_evaluated_candidates`
  - `support_match`
  - `lambda_match`

### 4. Response plan clarified

Patched:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_response_2026-06-07.md`

The handoff now states the explicit seed formula, candidate-key definition,
status taxonomy, pre-launch QA artifacts, and exact invalid-run warning text.

## Smoke Validation

I created a seed-matched QA run directory:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_manifest_qa_20260607_001`

I first ran the merger before launching workers.  It produced:

- 168 `not_started` task rows;
- 84 incomplete planned pair rows;
- all planned pairs had `response_seed_match = TRUE` and
  `fold_seed_match = TRUE`.

Then I ran one full/screened pair:

- `s3r_0001__LA_D1_RAW_N500__r01__auto__full`
- `s3r_0002__LA_D1_RAW_N500__r01__auto__screened`

The merger then reported:

- 166 `not_started` tasks;
- 2 `ok` tasks;
- 84 planned pair rows;
- 1 complete pair;
- the complete pair had:
  - `response_seed_match = TRUE`
  - `fold_seed_match = TRUE`
  - `full_candidate_key_in_screened_evaluated_candidates = TRUE`
  - `full_support_in_screened_evaluated_supports = TRUE`
  - `support_match = TRUE`
  - `lambda_match = TRUE`

Corrected report preview:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_manifest_qa_20260607_001/reports/ps_lps_s3r_light_report.html`

## Verification Commands

```bash
Rscript -e 'parse("scripts/prepare_ps_lps_s3r_light_run.R"); parse("scripts/run_ps_lps_s3r_light_task.R"); parse("scripts/merge_ps_lps_s3r_light_run.R"); cat("parsed\n")'

git diff --check -- \
  scripts/prepare_ps_lps_s3r_light_run.R \
  scripts/run_ps_lps_s3r_light_task.R \
  scripts/merge_ps_lps_s3r_light_run.R \
  split_handoffs/p7x_s3r_audit_response_2026-06-07.md

Rscript scripts/prepare_ps_lps_s3r_light_run.R \
  --run_id=ps_lps_s3r_light_seedmatched_manifest_qa_20260607_001 \
  --n_workers=1 \
  --task_timeout_sec=7200

Rscript scripts/merge_ps_lps_s3r_light_run.R \
  --run_dir=/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_manifest_qa_20260607_001

Rscript scripts/run_ps_lps_s3r_light_task.R \
  --task_manifest=/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_manifest_qa_20260607_001/task_manifest.csv \
  --task_id=s3r_0001__LA_D1_RAW_N500__r01__auto__full

Rscript scripts/run_ps_lps_s3r_light_task.R \
  --task_manifest=/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_manifest_qa_20260607_001/task_manifest.csv \
  --task_id=s3r_0002__LA_D1_RAW_N500__r01__auto__screened
```

## Remaining Gate Before Corrected S3R-light Launch

The implementation-level audit comments are addressed.  The next recommended
step is an auditor recheck of:

1. the corrected manifest seed contract;
2. the pre-launch QA artifacts;
3. the manifest-backed task and pair tables;
4. the candidate inclusion diagnostics;
5. the corrected report structure.

After that recheck, the corrected full S3R-light run can be launched.  The
S3R-expanded run remains blocked until corrected S3R-light completes and passes
report re-audit.
