# P7X / S3R Audit Response Plan Audit Response Re-Audit

Auditor: Codex
Date: 2026-06-07 15:52:53 EDT

Scope:

- Response under audit:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_response_plan_audit_response_2026-06-07.md`
- Prior plan audit:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_response_plan_audit_2026-06-07.md`
- Corrected QA run:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_manifest_qa_20260607_001`
- Patched scripts:
  `/Users/pgajer/current_projects/geosmooth/scripts/prepare_ps_lps_s3r_light_run.R`
  `/Users/pgajer/current_projects/geosmooth/scripts/run_ps_lps_s3r_light_task.R`
  `/Users/pgajer/current_projects/geosmooth/scripts/merge_ps_lps_s3r_light_run.R`
  `/Users/pgajer/current_projects/geosmooth/scripts/launch_ps_lps_s3r_light_run.py`

## Verdict

Mostly accepted, with one remaining launch-blocking polish item.

The response successfully turns the earlier plan-audit clarifications into
working artifacts for the seed contract, manifest-backed task/pair accounting,
candidate-key diagnostics, and pre-launch QA. The corrected QA manifest and
one-pair smoke test are strong enough to show that the main pairing blocker has
been fixed.

Before launching the full corrected S3R-light run, patch the timeout status
taxonomy so timeout rows are represented as `status = "timeout"` rather than
only as `status = "error"` with `error_class = "task_timeout_..."`.

## Checks Passed

### Seed and pre-launch QA

The corrected QA run has:

- 168 manifest rows;
- 84 planned pairs;
- exactly one `full` and one `screened` arm per pair;
- 84 seed-matched pairs;
- zero seed-mismatched pairs;
- `qa_passed: TRUE` in `PRELAUNCH_QA_SUMMARY.txt`.

The manifest now contains:

- `pair_id`;
- `pair_seed_base`;
- `pair_fold_seed`;
- `pair_response_seed`;
- worker-facing `fold_seed`;
- worker-facing `response_seed`.

The seed formula is explicit and does not depend on `search_policy`.

### Manifest-backed task and pair tables

The corrected merge output is manifest-backed:

- `task_status.csv` has 168 rows, one per planned task.
- `full_vs_screened_pairs.csv` has 84 rows, one per planned pair.
- The smoke run correctly reports 166 `not_started` tasks and 2 `ok` tasks.
- Pair accounting keeps incomplete pairs visible instead of silently dropping
  them.

### Candidate inclusion diagnostics

The worker and merger now record:

- `selected_candidate_key`;
- `evaluated_candidate_keys`;
- `local_candidate_details.csv`;
- `screened_evaluated_supports`;
- `full_support_in_screened_evaluated_supports`;
- `full_candidate_key`;
- `full_candidate_key_in_screened_evaluated_candidates`;
- `support_match`;
- `lambda_match`.

For the smoke pair, both support-level and candidate-key inclusion are `TRUE`.

### Report structure

The corrected HTML preview contains:

- Design Contract And Seed Validation;
- Task Accounting;
- Pair Accounting;
- Candidate Inclusion Diagnostics;
- Limitations;
- the invalid-old-run warning text.

This is sufficient as a corrected S3R-light report skeleton. The completed full
run report should add the richer accuracy/runtime visuals expected for the
decision audit.

## Remaining Finding

### P2. Timeout is not yet a distinct task status

The prior plan audit required the manifest-backed status taxonomy to distinguish
`timeout` from generic `error`. The response claims this distinction is now
implemented, but the code path still records timeout as an error status:

- `/Users/pgajer/current_projects/geosmooth/scripts/launch_ps_lps_s3r_light_run.py`
  writes timed-out workers with `status = "error"` and
  `error_class = "task_timeout_<seconds>s"`.
- `/Users/pgajer/current_projects/geosmooth/scripts/merge_ps_lps_s3r_light_run.R`
  preserves `status` from the status JSON and does not map timeout error
  classes to `status = "timeout"`.
- The corrected HTML preview does not contain a timeout status definition.

Required fix before the corrected full S3R-light launch:

- Either make the launcher write `status = "timeout"` for timeout kills, or
  make the merger map `error_class` matching `task_timeout_*` to
  `status = "timeout"`.
- Update the HTML task-status explanation to define `timeout`.
- Keep the original `error_class` field, because the exact timeout threshold is
  still useful.

This is a narrow accounting fix, not a seed-design blocker.

## Recommendation

Patch the timeout status taxonomy, regenerate the QA manifest/report preview,
and then proceed to the corrected full S3R-light run. After the run completes,
perform the planned report re-audit before using S3R-light results to decide
whether S3R-expanded should run.

## Verification Performed

- Parsed the three patched R scripts successfully.
- Checked `git diff --check` for the patched scripts and handoffs; no
  whitespace errors were reported.
- Verified corrected manifest seed matching directly from
  `task_manifest.csv`.
- Verified row counts and key columns in `task_status.csv`,
  `full_vs_screened_pairs.csv`, and `local_candidate_details.csv`.
- Verified the corrected HTML preview contains the expected sections and old-run
  invalidity warning.
