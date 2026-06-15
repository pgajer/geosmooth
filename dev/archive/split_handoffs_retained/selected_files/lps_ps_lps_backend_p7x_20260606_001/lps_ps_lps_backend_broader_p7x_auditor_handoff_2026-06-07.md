Please audit the broader P7X-style LPS / PS-LPS backend comparison run.

## Assets To Review

- Run directory:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001`
- HTML report:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/reports/lps_ps_lps_backend_broader_p7x_comparison.html`
- Combined results:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/tables/combined_results.csv`
- Task status table:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/tables/task_status.csv`
- Coverage by arm:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/tables/coverage_by_arm.csv`
- Best row per dataset:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/tables/best_by_dataset.csv`
- Launcher log:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/logs/python_launcher.log`

## Run Scope

This was the broader follow-up to the focused design-basis backend comparison.
It used the 14 frozen first-batch non-manifold/P7X-style assets from:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_local_auto_nonmanifold_first_batch_2026-06-05/asset_manifest.csv`

Task grid:

- 14 datasets;
- `chart.dim = "auto"` and `chart.dim = "local.auto"`;
- `method = lps` and `method = ps_lps`;
- backend variants:
  - `monomial_tiny_ridge`;
  - `weighted_qr_drop_tiny`;
  - `orthogonal_drop_adaptive_tiny`;
- support grid `15:35`;
- degree grid `2`;
- kernel grid `tricube`.

Total tasks: 168.

The run used 14 local workers on a 16-logical-core machine. Each task ran in
its own R process with separate status, result, and log files.

## Final Status

Final task counts:

- `ok`: 122
- `nonfinite_fit`: 38
- `error`: 8

The 8 error rows were manually terminated after the final long tail exceeded a
practical 90-minute wall-time cap. The generated task statuses record these as
`worker_exit_-15`; the launcher has since been patched so future runs can
record explicit `task_timeout_<seconds>s` statuses automatically.

The timeout rows were:

- `LA-13K-SUB-N500`, PS-LPS auto weighted-QR
- `LA-13K-SUB-N500`, PS-LPS auto orthogonal
- `LA-13K-SUB-N500`, PS-LPS local.auto weighted-QR
- `LA-13K-SUB-N500`, PS-LPS local.auto orthogonal
- `SYN-RANK-BLOCKS-N600-P100`, PS-LPS auto weighted-QR
- `SYN-RANK-BLOCKS-N600-P100`, PS-LPS auto orthogonal
- `SYN-RANK-BLOCKS-N600-P100`, PS-LPS local.auto weighted-QR
- `SYN-RANK-BLOCKS-N600-P100`, PS-LPS local.auto orthogonal

## Proposed Audit Questions

1. Does the run answer the intended broader backend question, or should a
   second run be restricted to `monomial_tiny_ridge` versus
   `orthogonal_drop_adaptive_tiny` after dropping `weighted_qr_drop_tiny`?

2. Are the `nonfinite_fit` rows concentrated in LPS monomial/weighted-QR as
   expected from the focused comparison, or do they reveal a new status
   propagation issue?

3. Are the timeout/error rows best interpreted as backend infeasibility for
   routine P7X comparisons, or should they be rerun with a reduced support grid
   before drawing that operational conclusion?

4. Does `orthogonal_drop_adaptive_tiny` remain a credible candidate backend
   after adding `chart.dim = "local.auto"` and support grid `15:35`, despite
   the long-tail PS-LPS timeouts?

5. Does the HTML report state enough about the main run design, Truth RMSE,
   nonfinite rows, and timeout/error rows for an auditor to trust the summary?

6. Should future supervisors use a hard per-task timeout by default, and is
   90 minutes appropriate for n=500-600 P7X-style fixtures?

Please write the audit report in this same run directory with a timestamped
name such as:

`lps_ps_lps_backend_broader_p7x_audit_2026-06-07.md`
