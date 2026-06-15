# K4 Handoff: Native Local-PCA LPS Backend Prototype

Generated: 2026-06-04 16:14:33 EDT

## Outputs

- HTML report: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k4_lps_local_pca_native_prototype_2026-06-04/k4_lps_local_pca_native_prototype.html`
- Results CSV: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k4_lps_local_pca_native_prototype_2026-06-04/k4_lps_local_pca_native_prototype_results.csv`

## Summary

- Added explicit `backend = "cpp.local.pca"` support for
  `fit.lps(coordinate.method = "local.pca", local.chart.method = "pca")`.
- `backend = "auto"` is unchanged: ambient coordinates use C++,
  local-PCA charts still use the R reference path until audit promotes the
  native path.
- Benchmark cases: `4`.
- Median R / C++ elapsed-time speedup: `7.4942`.
- Maximum absolute CV RMSE difference: `0.020683`.
- Maximum relative CV RMSE difference: `0.00022642`.
- Maximum absolute fitted-value difference: `4.9189e-11`.

## Validation

- `R CMD INSTALL --preclean /Users/pgajer/current_projects/geosmooth`: passed.
- Focused `test-ge7-lps-api.R`: passed.
- Full `tests/testthat` run: passed with the existing expected gflow-parity skips.
- `git diff --check`: passed.

## Recommended Next Step

Proceed to K4 audit. If accepted, K4.1 should optimize repeated chart
construction across candidates that share the same fold, target, support
size, and chart dimension, then rerun the larger K3.9 benchmark with
`backend = "cpp.local.pca"`.
