Please read and address:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h4_audit_2026-06-04.md`

The H4 audit accepts the opt-in `fit.lps()` implementation but corrects an
important interpretation issue: the H4 smoke run was only a wiring/diagnostic
smoke test. It must not be used to judge whether second-order local SVD charts
improve or worsen LPS performance. Your next task is therefore an expanded
dimensional test of ordinary local-PCA LPS versus second-order-local-SVD LPS.

## Task: H5 Expanded dim > 1 LPS Chart Comparison

Implement and run an evidence-building comparison between:

```r
fit.lps(
    X, y,
    coordinate.method = "local.pca",
    chart.dim = "auto",
    local.chart.method = "pca",
    ...
)
```

and

```r
fit.lps(
    X, y,
    coordinate.method = "local.pca",
    chart.dim = "auto",
    local.chart.method = "second.order.svd",
    ...
)
```

Use the same folds, support grid, degree grid, kernel grid, and responses for
both chart methods. This is a paired comparison of chart construction methods,
not a comparison of different smoothing algorithms.

## Required Small Cleanup First

Before running the expanded comparison, address the nonblocking H4 reporting
cleanup:

1. Preserve the public argument `local.chart.method`.
2. Add `local.chart.method.effective`.
3. Set `local.chart.method.effective = "none"` when
   `coordinate.method = "coordinates"`.
4. Set `local.chart.method.effective = local.chart.method` when
   `coordinate.method = "local.pca"`.
5. Ensure diagnostics summaries and report-facing text use the effective value
   where appropriate.

Add regression tests that:

- local-PCA default equals explicit `local.chart.method = "pca"` on a fixed
  seed/fold split;
- ambient-coordinate LPS reports `local.chart.method.effective = "none"`;
- second-order local-PCA LPS still returns diagnostics;
- `predict()` on a second-order fit still returns a plain numeric vector;
- ambient coordinates with `local.chart.method = "second.order.svd"` still
  hard-error.

## Primary Assets To Use

Use the existing P7 prospective synthetic suite as the primary source of
dimensional test assets:

- Geometry registry:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/config/p7_geometry_registry.csv`
- Synthetic truth registry:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/config/p7_synthetic_truth_registry.csv`
- P7 focused comparison script to inspect/reuse:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/scripts/run_p7e_kernel_chart_focused_comparison.R`
- P7 focused comparison report/tables:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/reports/p7e_kernel_chart_focused_comparison_fast_20260603/`

Also inspect these optional assets if useful:

- Dense S7 2D geometry outputs:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/validation/phase_s7_2d_geometry_outputs/s7_2d_geom_support_local12_20260531_092229/`
- S7 2D robust-selection reports:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/reports/phase_s7_2d_robust_selection/`
- VALENCIA-derived LPS scalability script:
  `/Users/pgajer/current_projects/geosmooth/scripts/k3_8_lps_valencia_scalability.R`
- VALENCIA-derived LPS scalability outputs:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/k3_8_lps_valencia_scalability_2026-06-04/`

## Minimum Dataset Coverage

Include at least:

1. flat 2D square;
2. curved 2D paraboloid;
3. curved 2D saddle;
4. flat 3D cube;
5. high-dimensional embedded 2D;
6. high-dimensional embedded 3D;
7. at least one VALENCIA-derived or P7 16S real-geometry example if runtime
   permits.

If runtime is too high, implement a bounded first pass with the first six cases,
then record exactly which 16S case remains deferred.

## Candidate Grid

Use a modest but not toy grid for the paired comparison:

- support sizes: `15, 25, 35` initially, clipped to available training size;
- degrees: `1, 2`;
- kernels: `gaussian, tricube`;
- fixed non-oracle folds from the corresponding asset when available.

If the P7 asset already materializes folds, use those folds. Do not regenerate
different folds for the two chart methods.

## Metrics To Record

For every paired case, record:

- dataset/truth identifier;
- geometry family and ambient dimension;
- sample size;
- selected support size;
- selected degree;
- selected kernel;
- selected chart dimension;
- observed CV RMSE;
- observed full-data RMSE;
- Truth RMSE;
- runtime;
- fit status;
- second-order fallback count/rate;
- fallback reason counts;
- design-rank and design-condition summaries from diagnostics.

The primary paired quantity is:

\[
\Delta =
\mathrm{TruthRMSE}_{\mathrm{second.order.svd}}
-
\mathrm{TruthRMSE}_{\mathrm{pca}}.
\]

Negative \(\Delta\) favors second-order charts. Positive \(\Delta\) favors
ordinary PCA charts.

## Report Requirements

Create:

- an HTML report with figures and concise interpretation;
- CSV tables containing all paired results and diagnostics;
- an RDS bundle containing reproducible objects needed for rerendering;
- a handoff file:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h5_expanded_eval_handoff_2026-06-04.md`;
- a short decision note:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h5_decision_note_2026-06-04.md`.

The HTML report should include:

- paired dot/segment plot of Truth RMSE for PCA versus second-order charts;
- dot plot of \(\Delta\) by dataset/truth case;
- runtime ratio plot;
- fallback diagnostic summary;
- a clear statement that H4 was only a smoke/wiring phase.

Do not claim statistical significance unless the number and diversity of paired
cases support it. If the evidence is mixed or underpowered, say so directly.

## Validation Gates

Run:

```sh
make document
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-ge1-r-smoothers.R")'
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-harlim-second-order-svd-chart.R")'
make test
git diff --check
```

Stop after H5 and wait for audit. Do not promote second-order charts to a
default and do not integrate them into MALPS, LPL-TF, SLPL-TF, or production P7
selectors during this task.
