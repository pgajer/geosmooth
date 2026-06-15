# K4.1 Re-Audit: Native Local-PCA LPS Chart Cache

Generated: 2026-06-04 17:52:19 EDT

## Scope

Re-audited
`split_handoffs/k4_1_lps_local_pca_chart_cache_handoff_2026-06-04.md`
after the K4/K4.1 audit blockers were addressed.

Reviewed current changes in:

- `R/kernel_local_polynomial_cv.R`
- `src/kernel_local_polynomial_cv_rcpp.cpp`
- `tests/testthat/test-ge7-lps-api.R`
- `tests/testthat/test-ge1-r-smoothers.R`
- `split_handoffs/k4_1_lps_local_pca_chart_cache_2026-06-04/k4_1_lps_local_pca_chart_cache_results.csv`

## Decision

Accepted for explicit opt-in K4.1 use. The native local-PCA backend remains a
prototype behind `backend = "cpp.local.pca"` and should still go through K5
broader validation before any `backend = "auto"` promotion.

## Resolved Prior Blockers

### K4 native/R parity blocker

The prior duplicated/tied support failure is resolved in the current worktree.

Checks rerun during re-audit:

- Focused `test-ge7-lps-api.R`: passed.
- Exact line, chart dimension 2, degree 2:
  max CV RMSE difference `7.344726e-18`.
- Exact plane grid, chart dimension 2, degree 2:
  max CV RMSE difference `6.938894e-18`.
- Duplicated/tied supports:
  max CV RMSE difference `5.551115e-17`.
- Random `chart.dim = "auto"` case:
  max CV RMSE difference `3.799044e-16`.

The implemented fix now includes boundary-tie recovery plus an R-compatible
rank-deficient fallback path for local weighted polynomial fits.

### K4.1 chart-cache behavior

The cache key `(support.size, chart.dim)` is appropriate within each
fold/target for ordinary local-PCA charts because the chart coordinates depend
on the support rows, center, and chart dimension, but not on polynomial degree
or kernel. Prediction remains unchanged, which is appropriate because
prediction uses a single selected candidate.

An additional candidate-order invariance probe found zero CV difference after
permuting support, degree, and kernel grid order.

## Remaining Scope Notes

- `backend = "auto"` still routes local-PCA LPS through the R reference path.
  This is correct for K4.1.
- The R-compatible fallback calls `stats::lm.wfit()` from native code on
  rank-deficient cases. This is acceptable for the prototype and for parity,
  but K5 should include stress/performance cases with many rank-deficient local
  designs so the fallback frequency and cost are visible.
- The benchmark now shows numerical parity with R on the VALENCIA-derived
  cases: maximum absolute CV RMSE difference `4.198e-09` and maximum absolute
  fitted-value difference `4.2188e-15`.

## Verification Run During Re-Audit

- `Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet = TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R", reporter = "summary")'`
- `Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet = TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge1-r-smoothers.R", reporter = "summary")'`
- `make test`
- `git diff --check`
- Manual adversarial parity probes for exact line, exact plane, duplicated
  supports, and `chart.dim = "auto"`.
- Manual candidate-order invariance probe for the cached native CV backend.

## Recommended Next Step

Proceed to K5 validation: broaden equivalence, stress, and performance testing
for `backend = "cpp.local.pca"` before considering promotion beyond explicit
opt-in use.
