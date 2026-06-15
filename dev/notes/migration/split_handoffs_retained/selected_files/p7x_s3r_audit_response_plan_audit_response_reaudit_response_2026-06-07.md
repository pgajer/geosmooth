# P7X / S3R Audit Response Plan Re-Audit Response

Date: 2026-06-07

Response to:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_response_plan_audit_response_reaudit_2026-06-07.md`

## Summary

Accepted and addressed.

The re-audit found one remaining launch-blocking polish item: timeout rows had
to be represented as `status = "timeout"` rather than only as
`status = "error"` with `error_class = "task_timeout_*"`.

I patched both the launcher and merger so this status taxonomy is now enforced
for new runs and backward-tolerant for any legacy timeout status files.

## Changes Made

### Launcher timeout status

Patched:

`/Users/pgajer/current_projects/geosmooth/scripts/launch_ps_lps_s3r_light_run.py`

The launcher now writes timed-out workers with:

```text
status = "timeout"
error_class = "task_timeout_<seconds>s"
```

The exact timeout threshold is still preserved in `error_class`.

### Merger timeout normalization

Patched:

`/Users/pgajer/current_projects/geosmooth/scripts/merge_ps_lps_s3r_light_run.R`

The merger now normalizes any row with:

```text
error_class = task_timeout_*
```

to:

```text
status = "timeout"
```

This means old launcher outputs that wrote `status = "error"` can still be
accounted for correctly.

### HTML status definition

The corrected S3R-light HTML report now defines `timeout` in the Task Accounting
section:

```text
timeout means the worker exceeded the task timeout; the exact threshold remains
in error_class.
```

Regenerated preview:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_manifest_qa_20260607_001/reports/ps_lps_s3r_light_report.html`

## Verification

Commands run:

```bash
python3 -m py_compile scripts/launch_ps_lps_s3r_light_run.py

Rscript -e 'invisible(parse("scripts/merge_ps_lps_s3r_light_run.R")); cat("parsed\n")'

Rscript scripts/merge_ps_lps_s3r_light_run.R \
  --run_dir=/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_manifest_qa_20260607_001
```

I also ran a synthetic timeout-accounting smoke test using a copied manifest
with one fake status file:

```text
status = "error"
error_class = "task_timeout_1s"
```

The merger output correctly counted it as:

```text
timeout: 1
not_started: 167
```

The temporary smoke directory was removed after the check.

## Recommendation

The timeout taxonomy blocker is addressed.  The corrected full S3R-light run can
proceed after the auditor confirms this narrow re-audit response, with the same
post-run report re-audit gate before any S3R-expanded run.
