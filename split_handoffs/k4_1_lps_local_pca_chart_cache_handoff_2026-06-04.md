# K4.1 Handoff: Native Local-PCA LPS Chart Cache

Generated: 2026-06-04 17:48:11 EDT

## Outputs

- HTML report: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k4_1_lps_local_pca_chart_cache_2026-06-04/k4_1_lps_local_pca_chart_cache.html`
- Results CSV: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k4_1_lps_local_pca_chart_cache_2026-06-04/k4_1_lps_local_pca_chart_cache_results.csv`

## Change

K4.1 caches the local PCA chart coordinates inside 
`rcpp_kernel_local_polynomial_cv_local_pca()` for each fold/target and 
`(support.size, chart.dim)` pair. Candidates that differ only by degree or 
kernel now reuse the same chart coordinates.

The audit-response patch also changes the native weighted local-polynomial 
solve order to use rank-aware QR before falling back to 
`stats::lm.wfit()` for R-compatible rank-deficient cases. This avoids the 
normal-equation drift that previously showed up in singular, tied, or 
ill-conditioned local designs.

The prediction backend is unchanged because production prediction uses a 
single selected candidate and therefore does not have candidate-level chart 
reuse to exploit.

## Benchmark Summary

- Benchmark cases: `4`.
- Candidate chart-build reuse factor in this benchmark: `4`.
- Median R / cached-C++ elapsed-time speedup: `7.6167`.
- Median cached-C++ / prior-K4-C++ speedup: `1.0917`.
- Maximum absolute CV RMSE difference vs R reference: `4.198e-09`.
- Maximum relative CV RMSE difference vs R reference: `4.2395e-11`.
- Maximum absolute fitted-value difference vs R reference: `4.2188e-15`.

## Validation

- `R CMD INSTALL --preclean /Users/pgajer/current_projects/geosmooth`: passed.
- Focused `test-ge7-lps-api.R`: passed.
- Focused `test-ge1-r-smoothers.R`: passed.
- Adversarial parity probes passed for exact plane grid, duplicated rows, 
  exact line, and `chart.dim = "auto"` cases.
- `make test`: passed with 878 passing checks, 9 expected split-era skips, 
  and no failures or warnings.
- `git diff --check`: passed after this handoff was written.

## Recommended Next Step

Ask for K4.1 audit. If accepted, proceed to K5 validation: broader 
equivalence, stress, and performance checks for the optimized LPS backend 
before promoting the native local-PCA path beyond explicit opt-in.
