# K8 P7 LPS Native Opt-In Panel Comparison Handoff

## Scope

K8 extends the K7 one-dataset preflight to a deliberately mixed P7 panel.  The
question is narrow:

```text
Can the P7 local-PCA LPS wrapper use backend = "cpp.local.pca" explicitly
without changing the selected candidate, fitted values, or truth error relative
to the current backend = "auto" reference path?
```

This is not a default-promotion test.  The native backend remains an explicitly
requested experimental backend.

## Script and Outputs

Script:

```text
/Users/pgajer/current_projects/geosmooth/scripts/k8_p7_lps_backend_panel_comparison.R
```

Output directory:

```text
/Users/pgajer/current_projects/geosmooth/split_handoffs/k8_p7_lps_backend_panel_comparison_2026-06-04
```

Main report:

```text
/Users/pgajer/current_projects/geosmooth/split_handoffs/k8_p7_lps_backend_panel_comparison_2026-06-04/k8_p7_lps_backend_panel_comparison.html
```

Key tables:

```text
/Users/pgajer/current_projects/geosmooth/split_handoffs/k8_p7_lps_backend_panel_comparison_2026-06-04/tables/k8_dataset_panel.csv
/Users/pgajer/current_projects/geosmooth/split_handoffs/k8_p7_lps_backend_panel_comparison_2026-06-04/tables/k8_lps_backend_delta_summary.csv
/Users/pgajer/current_projects/geosmooth/split_handoffs/k8_p7_lps_backend_panel_comparison_2026-06-04/tables/k8_lps_backend_summary_long.csv
/Users/pgajer/current_projects/geosmooth/split_handoffs/k8_p7_lps_backend_panel_comparison_2026-06-04/tables/k8_lps_backend_cv_tables_long.csv
```

Machine-readable bundle:

```text
/Users/pgajer/current_projects/geosmooth/split_handoffs/k8_p7_lps_backend_panel_comparison_2026-06-04/k8_lps_backend_results.rds
```

## Panel

The controlled panel used the full P7 baseline LPS grid.  It included:

- one 1D controlled example;
- one flat 2D example;
- two curved 2D examples;
- one 3D example;
- three high-dimensional noisy/diagonal embeddings;
- one real-geometry 16S smoke example on a reduced LPS grid.

The real-geometry 16S row used a reduced grid because the point of K8 is backend
equivalence, not a full P7 performance campaign.

## Results

Run command:

```sh
Rscript scripts/k8_p7_lps_backend_panel_comparison.R
```

Summary:

| dataset | status | selected same | max CV-RMSE delta | max fitted delta | truth-RMSE delta | speedup auto/cpp |
|---|---|---:|---:|---:|---:|---:|
| 1D two Gaussian | safe machine precision | yes | 1.11e-16 | 2.22e-15 | 2.08e-17 | 13.45 |
| 2D square anisotropic Gaussian | safe machine precision | yes | 3.33e-16 | 2.22e-15 | 0 | 2.62 |
| 2D paraboloid | safe machine precision | yes | 2.78e-16 | 4.44e-15 | 0 | 2.68 |
| 2D saddle | safe machine precision | yes | 2.22e-16 | 2.66e-15 | 2.78e-17 | 2.62 |
| 3D four Gaussian | safe machine precision | yes | 3.89e-16 | 2.66e-15 | 0 | 3.02 |
| high-dimensional 1D embedding | numeric drift, selected stable | yes | 4.60e-06 | 5.33e-15 | 1.67e-16 | 0.95 |
| high-dimensional 2D embedding | safe machine precision | yes | 2.22e-16 | 3.55e-15 | 1.39e-17 | 1.43 |
| high-dimensional 3D embedding | safe machine precision | yes | 1.39e-15 | 3.55e-15 | 1.39e-17 | 1.39 |
| 16S graph Gaussian smoke | safe machine precision | yes | 5.47e-09 | 4.66e-15 | -2.78e-17 | 0.60 |

The only non-machine-precision candidate-table difference occurred in the
high-dimensional 1D embedding row.  The selected candidate, selected fitted
values, and selected truth RMSE were nevertheless stable to numerical precision.

## Interpretation

K8 supports a practical conclusion:

- the explicit native local-PCA LPS backend is selection-stable on this P7 panel;
- the selected fitted functions match the R reference path to numerical
  precision;
- the candidate CV table is usually machine-identical, with one small numerical
  drift case that did not affect selection or truth error.

Runtime is not uniformly better:

- native is much faster for the small 1D controlled example;
- native is about 2.6x--3.0x faster on low-dimensional 2D/3D controlled examples;
- native is only modestly faster on high-dimensional 2D/3D embeddings;
- native is slightly slower on the high-dimensional 1D row;
- native is slower in the reduced 16S smoke row.

This pattern argues against blindly promoting `backend = "cpp.local.pca"` to the
default `backend = "auto"` path.  It should remain available as an explicit
backend for controlled experiments and larger profiling runs.

## Recommendation

Do not promote the native backend to `backend = "auto"` yet.

Use this backend explicitly when we need controlled comparisons or when profiling
shows a clear local gain:

```text
backend = "cpp.local.pca"
```

The next kernel-optimization step should not be another broad P7 science run.
It should be a targeted profiling/engineering step that explains why the native
path is slower on high-dimensional and 16S cases.  In particular, K9 should
separate:

- neighbor search cost;
- local PCA chart construction cost;
- local design/QR solve cost;
- R-to-C++ data marshalling cost;
- candidate-grid loop overhead.

Only after that profiling pass should we decide whether to optimize the native
path further, add a size/dimension-dependent backend chooser, or keep the native
path as a controlled experimental option.

## Validation

Passed:

```sh
Rscript scripts/k8_p7_lps_backend_panel_comparison.R
git diff --check
```

`git diff --check` passed in:

- `/Users/pgajer/current_projects/geosmooth`
- `/Users/pgajer/current_projects/trend_filtering`

No generated native build artifacts remained under `geosmooth/src`.
