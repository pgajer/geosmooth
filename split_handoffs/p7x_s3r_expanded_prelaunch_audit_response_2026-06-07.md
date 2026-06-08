# P7X / S3R-expanded Pre-launch Audit Response

Generated: 2026-06-07

Response to audit:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_expanded_prelaunch_audit_2026-06-07.md`

Updated pre-launch handoff:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_expanded_prelaunch_handoff_2026-06-07.md`

Generated expanded manifest bundle, not launched:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_20260607_001`

## Summary

The audit correctly identified a blocking arithmetic/accounting error in the
pre-launch handoff: it stated the 10-repetition task and pair counts while
describing a 20-repetition run. That blocker has been fixed. The corrected
20-repetition design has:

```text
14 datasets * 20 repetitions * 2 chart rules * 2 search policies = 1120 tasks
14 datasets * 20 repetitions * 2 chart rules = 560 full/screened pairs
```

The merge/report script has also been generalized so the expanded monitoring
report does not claim S3R-light, 168 tasks, or 84 pairs.

## Changes Made

### 1. Corrected the pre-launch handoff accounting

File:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_expanded_prelaunch_handoff_2026-06-07.md`

Changes:

- Replaced `560 tasks` with `1120 tasks` for the 20-repetition design.
- Replaced `280 pairs` with `560 pairs`.
- Updated the runtime estimate line to read:

```text
S3R-expanded, 20 repetitions, 1120 tasks, 10 workers: expected about
9.5--11 hours in practice.
```

- Updated the required manifest-level QA section to require exactly 1120
  planned tasks and 560 planned pairs.
- Updated auditor question 3 to ask whether 1120 tasks and 560 pairs are
  correct.
- Added a generated-manifest section pointing to the actual manifest and QA
  files created after the correction.

### 2. Generalized the preparer labeling

File:

`/Users/pgajer/current_projects/geosmooth/scripts/prepare_ps_lps_s3r_light_run.R`

Changes:

- Added a `run.label` derived from `run_id`.
- If the run id contains `expanded`, generated QA and run-config text now say
  `S3R-expanded`.
- The generated manifest for this run now reports:

```text
S3R-expanded manifest pre-launch QA
planned_tasks: 1120
planned_pairs: 560
seed_matched_pairs: 560
mismatched_pairs: 0
qa_passed: TRUE
```

### 3. Generalized the merge/report script

File:

`/Users/pgajer/current_projects/geosmooth/scripts/merge_ps_lps_s3r_light_run.R`

Changes:

- Added run-label detection from `run_config.csv` / `run_id`.
- Report title is now data-driven:
  `PS-LPS S3R-expanded Full vs Screened Support Search` for expanded runs.
- Expanded runs write:

```text
reports/ps_lps_s3r_expanded_report.html
reports/figures_s3r_expanded/
```

- Removed hardcoded HTML claims of `168 tasks` and `84 pairs`.
- The report callout now uses actual manifest/status/pair counts:
  successful tasks, planned tasks, complete pairs, planned pairs, nonfinite
  fits, errors, and timeouts.
- Added generated CSV summaries for expanded reporting:
  - `paired_summary_by_dataset.csv`
  - `paired_summary_by_geometry_family.csv`
  - `paired_summary_by_repetition_subset.csv`
- Added corresponding HTML sections:
  - interim repetitions 1--10 versus all available repetitions;
  - summary by dataset;
  - summary by geometry family;
  - expanded-policy decision text for expanded runs.
- Kept candidate counts derived from `local_candidate_details.csv`, preserving
  the corrected S3R-light accounting rule.

## Manifest Generated For Re-audit

Command run:

```bash
cd /Users/pgajer/current_projects/geosmooth
Rscript scripts/prepare_ps_lps_s3r_light_run.R \
  --repo=/Users/pgajer/current_projects/geosmooth \
  --run_id=ps_lps_s3r_expanded_seedmatched_20260607_001 \
  --n_reps=20 \
  --n_workers=10 \
  --task_timeout_sec=7200 \
  --base_seed=20260607
```

Output:

```text
Prepared S3R-expanded PS-LPS full-versus-screened run
Run directory: /Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_20260607_001
Tasks: 1120
Workers: 10
Task timeout sec: 7200
```

Pre-launch QA:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_20260607_001/PRELAUNCH_QA_SUMMARY.txt`

```text
planned_tasks: 1120
planned_pairs: 560
seed_matched_pairs: 560
mismatched_pairs: 0
qa_passed: TRUE
```

The run has not been launched.

## Monitoring/Report Dry Run

Command run:

```bash
cd /Users/pgajer/current_projects/geosmooth
Rscript scripts/merge_ps_lps_s3r_light_run.R \
  --run_dir=/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_20260607_001
```

Output:

```text
Merged S3R-expanded run
Task rows: 1120
Summary rows: 0
Pair rows: 560
Complete pairs: 0
Report: /Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_20260607_001/reports/ps_lps_s3r_expanded_report.html
```

This is the expected pre-launch monitoring state: the manifest exists, no tasks
have been started, and the report is able to account for 1120 not-yet-completed
tasks without S3R-light task-count language.

## Regression Check On Corrected S3R-light

The generalized merge/report script was also run on the accepted corrected
S3R-light bundle:

```bash
Rscript scripts/merge_ps_lps_s3r_light_run.R \
  --run_dir=/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_20260607_002
```

It completed successfully and preserved the accepted S3R-light accounting:

```text
Merged S3R-light run
Task rows: 168
Summary rows: 168
Pair rows: 84
Complete pairs: 84
```

## Requested Re-audit

Please re-audit:

1. the updated pre-launch handoff;
2. the generated 1120-task / 560-pair manifest;
3. the generated manifest QA files;
4. the generalized expanded monitoring report in its pre-launch state;
5. the fact that the run has not yet been launched.

Requested output:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_expanded_prelaunch_audit_response_reaudit_2026-06-07.md`

Please state one of:

- `accepted for launch`;
- `accepted for launch after minor nonblocking edits`;
- `blocked pending changes`.

