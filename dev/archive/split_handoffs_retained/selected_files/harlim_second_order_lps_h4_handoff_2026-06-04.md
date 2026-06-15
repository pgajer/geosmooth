# H4 Handoff: Opt-In LPS Second-Order Chart-Mode Integration

Date: 2026-06-04

## Scope Completed

Implemented opt-in `fit.lps(..., local.chart.method = c("pca", "second.order.svd"))`
for `coordinate.method = "local.pca"` only.

Default behavior is preserved:

- `local.chart.method` defaults to `"pca"`.
- Existing ambient-coordinate LPS behavior remains unchanged.
- Existing local-PCA LPS calls that omit `local.chart.method` continue through
  the ordinary `rcpp_local_pca_chart()` path.
- `backend = "cpp"` remains restricted to `coordinate.method = "coordinates"`.
- `coordinate.method = "coordinates"` with
  `local.chart.method = "second.order.svd"` now fails with a hard error.

Second-order behavior:

- The LPS local-coordinate path dispatches to
  `rcpp_local_second_order_svd_chart()` when requested.
- The second-order path uses the same support, center, fixed chart dimension,
  anchor centering, kernel weights, anchor rebase, and no orientation as the
  existing local chart conventions.
- CV and final prediction both use the requested chart method consistently.
- For second-order charts, CV builds charts per candidate/kernel because the
  curvature correction is weighted by the candidate kernel weights.

## Modified Files

H4 files changed or added:

- `R/kernel_local_polynomial_cv.R`
- `man/fit.lps.Rd`
- `tests/testthat/test-ge1-r-smoothers.R`
- `scripts/harlim_second_order_lps_h4_smoke.R`
- `split_handoffs/harlim_second_order_lps_h4_smoke_results_2026-06-04.csv`
- `split_handoffs/harlim_second_order_lps_h4_handoff_2026-06-04.md`

Note: the working tree also still contains earlier H0-H3 second-order chart
implementation, audit, smoke, and generated export files from prior tasks.
Those are dependencies for this H4 integration but were not the new H4 surface.

## Diagnostics Surface

For `local.chart.method = "second.order.svd"`, the returned LPS fit includes:

- `local.chart.method`
- `local.chart.diagnostics`
- `local.chart.diagnostics.summary`

The summary reports:

- selected chart method
- number of final fitted charts
- fallback count/rate
- fallback reason counts
- whether any chart used ordinary PCA fallback
- whether any structured failure occurred
- min/median/max design rank
- median/max design condition

For default PCA fits, `local.chart.diagnostics.summary` is present with zero
fallbacks and no per-chart diagnostic rows.

## Focused Tests Added

Added focused tests in `tests/testthat/test-ge1-r-smoothers.R` for:

- default local-PCA LPS remains `"pca"`
- valid opt-in second-order LPS fit with diagnostics
- ambient coordinates plus second-order chart method errors
- flat-plane second-order LPS fitted values match PCA closely

Existing local-PCA tests continue to pass.

## H4 Smoke Results

Smoke script:

```sh
Rscript scripts/harlim_second_order_lps_h4_smoke.R
```

Output CSV:

`split_handoffs/harlim_second_order_lps_h4_smoke_results_2026-06-04.csv`

Smoke cases used 49 points, `chart.dim = 2`, `support.grid = 12;18`,
`degree.grid = 1;2`, `kernel.grid = gaussian;tricube`, `cv.folds = 3`, and
fixed `cv.seed = 604`.

Truth-RMSE comparison, where delta is `second.order.svd - pca`:

| scenario | PCA RMSE truth | second-order RMSE truth | delta | outcome |
| --- | ---: | ---: | ---: | --- |
| flat | 0.01330783 | 0.01330783 | 0.00000000 | tied |
| paraboloid | 0.00941450 | 0.01251837 | 0.00310387 | worse |
| saddle | 0.01473892 | 0.01454797 | -0.00019095 | better |
| high_dim_embedding | 0.01151417 | 0.01534101 | 0.00382684 | worse |

Summary:

- outcome counts: 1 better, 1 tied, 2 worse
- median truth-RMSE delta: `+0.001551936`
- worst truth-RMSE delta: `+0.003826843`
- median fallback rate: `0`
- max fallback rate: `0`
- fallback reasons: none observed
- median design condition by case: 1.510839 to 1.723083
- max design condition by case: 2.289411 to 4.069477

Caution retained from H2/H3: second-order local SVD can be worse on small or
ill-conditioned supports. H4 keeps the path opt-in.

## Validation

Passed:

```sh
make document
Rscript scripts/harlim_second_order_lps_h4_smoke.R
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-harlim-second-order-svd-chart.R")'
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-ge1-r-smoothers.R")'
make test
git diff --check
```

`make test` result:

- failures: 0
- warnings: 0
- skips: 9 existing gflow-reference parity skips
- passes: 833

## Recommendation

Accept H4 as an opt-in integration if the auditor agrees that mixed smoke
accuracy is acceptable for an experimental chart method. Do not promote
`second.order.svd` to default behavior. The next work should wait for audit and
then either broaden opt-in LPS smoke coverage or proceed to a similarly guarded
integration only if the audit requests it.

Stop here and wait for audit.
