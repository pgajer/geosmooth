# K3.9 Handoff: Local-PCA LPS Acceleration Audit

Date: 2026-06-04

## Outputs

- HTML report: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k3_9_lps_local_pca_acceleration_audit_2026-06-04/k3_9_lps_local_pca_acceleration_audit.html`
- End-to-end fit CSV: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k3_9_lps_local_pca_acceleration_audit_2026-06-04/k3_9_end_to_end_fit_results.csv`
- Timing breakdown CSV: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k3_9_lps_local_pca_acceleration_audit_2026-06-04/k3_9_local_pca_cv_timing_breakdown.csv`
- Operation counts CSV: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k3_9_lps_local_pca_acceleration_audit_2026-06-04/k3_9_local_pca_cv_operation_counts.csv`
- RDS bundle: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k3_9_lps_local_pca_acceleration_audit_2026-06-04/k3_9_lps_local_pca_acceleration_bundle.rds`

## Summary

- Median local-PCA / ambient runtime ratio: `9.058`.
- End-to-end fits succeeded for `12` of `12` method/dataset/sample-size runs.
- Instrumented replay case: `depth3_top` at n = `250`, using `120` held-out target locations.
- Instrumented local-PCA replay total seconds: `0.335`.
- Largest timed phase: `local_chart` (`0.163 sec, 48.66% of total).
- Chart-dimension resolution share: `32.84%`; weighted-fit share: `16.72%`.

## Recommendation

Implement a native local-PCA LPS backend. The C++ backend should reuse ANN fold trees, call compute_local_pca_chart() for local charts, and reuse the existing C++ weighted local-polynomial normal-equation solver. This is higher leverage than R-level micro-optimizing because the measured work occurs inside per-target/per-support loops.

## Precise Next Step

Proceed to **K4: native local-PCA LPS backend prototype**.

K4 should implement a narrow C++ backend for
`fit.lps(coordinate.method = 'local.pca', local.chart.method = 'pca')`.
It should not include second-order charts, MALPS, LPL-TF, or SLPL-TF.
The backend should:

1. Reuse ANN trees per CV fold for nearest-neighbor searches.
2. Reuse `geosmooth::compute_local_pca_chart()` for local chart coordinates.
3. Reuse the C++ weighted local-polynomial normal-equation code already
   used by ambient LPS.
4. Match the existing R local-PCA path numerically on fixed small tests.
5. Keep `backend = 'auto'` unchanged until parity and speed are audited.

Validation gates for K4:

- targeted numerical parity tests against the current R local-PCA path;
- K3.9 benchmark rerun showing speedup;
- `make test`;
- `git diff --check`.
