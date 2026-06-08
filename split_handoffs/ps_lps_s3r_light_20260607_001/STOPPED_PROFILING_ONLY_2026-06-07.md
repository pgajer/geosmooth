# S3R-light stopped: profiling-only run

Date: 2026-06-07

This S3R-light run was stopped intentionally after audit identified a paired-design seed mismatch.  It should be treated as smoke/profiling only, not as valid paired evidence comparing `PS-LPS screened` against `PS-LPS full`.

Reason:

- Full and screened arms did not consistently share the same response and fold seeds within intended `(dataset, repetition, chart.dim)` pairs.
- Therefore `screened - full` Truth RMSE deltas are confounded by different noisy responses and CV folds.

The run may still be used for rough runtime/profiling observations and worker robustness notes.

Relevant audit and response:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_2026-06-07.md`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_response_2026-06-07.md`
