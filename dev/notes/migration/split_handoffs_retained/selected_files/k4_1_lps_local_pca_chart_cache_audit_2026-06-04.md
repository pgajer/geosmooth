# K4.1 Audit: Native Local-PCA LPS Chart Cache

Generated: 2026-06-04 17:41:08 EDT

## Scope

Audited
`split_handoffs/k4_1_lps_local_pca_chart_cache_handoff_2026-06-04.md`
and the current package changes for native local-PCA LPS chart caching.

Reviewed files:

- `split_handoffs/k4_1_lps_local_pca_chart_cache_handoff_2026-06-04.md`
- `split_handoffs/k4_1_lps_local_pca_chart_cache_2026-06-04/k4_1_lps_local_pca_chart_cache_results.csv`
- `src/kernel_local_polynomial_cv_rcpp.cpp`
- `R/kernel_local_polynomial_cv.R`
- `tests/testthat/test-ge7-lps-api.R`

## Decision

Not accepted yet. The cache idea is conceptually sound, but the current
worktree still fails the focused K4 parity test, so K4.1 cannot be accepted as
a behavior-preserving optimization.

## Blocking Findings

### P1: Focused K4 parity test still fails

The handoff reports that focused `test-ge7-lps-api.R` passed, but the current
worktree fails that test during audit.

Command run:

```sh
Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet = TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R", reporter = "summary")'
```

Observed failure:

- Test: `K4 local-PCA C++ backend uses R-compatible tie-stable supports`
- Location: `tests/testthat/test-ge7-lps-api.R:141`
- Native CV RMSE for one duplicated/tied-support candidate is `0.209551790`
  versus R reference `0.200000000`.

The original adversarial probes also still show parity gaps:

- Exact plane grid, degree 2: max absolute CV RMSE difference `0.2900137`;
  selected kernel differs.
- Duplicated-row support: max absolute CV RMSE difference `0.05334975`.

This means the native local-PCA CV table is still backend dependent on
duplicated/tied or rank-deficient local supports.

### P2: The K4.1 benchmark inherits unresolved K4 parity risk

The K4.1 benchmark still reports the same maximum absolute CV RMSE difference
versus R reference as K4: `0.020683`. This may be acceptable for a prototype
benchmark on non-adversarial embeddings, but it is not enough to show that the
cache is behavior-preserving across the parity contract.

Because K4.1 builds on the native CV path that still fails focused parity, the
speedup claim should be treated as provisional until the K4 parity blocker is
closed.

## Cache-Specific Assessment

The chart-cache key `(support.size, chart.dim)` within each fold/target appears
appropriate for ordinary PCA charts:

- The support rows and center are fixed for that fold/target/support size.
- Ordinary local-PCA chart coordinates do not depend on polynomial degree.
- Ordinary local-PCA chart coordinates do not depend on kernel weights in this
  path.
- Prediction is correctly left unchanged because prediction uses a single
  selected candidate.

No independent cache-specific correctness blocker was found. The remaining
blocker is upstream native/R parity for the local fit and tie/rank-deficient
support cases.

## Recommended Fix Before Re-Audit

Close the K4 parity blocker first:

- Reconcile native QR/least-squares fallback with R `lm.wfit()` on singular or
  duplicated local polynomial designs.
- Keep the boundary-tie recovery tests, but make them pass under focused
  `test-ge7-lps-api.R`.
- Re-run the original adversarial probes:
  exact plane grid, duplicated/tied rows, exact line, and `chart.dim = "auto"`.
- Only then re-run K4.1 benchmark and request K4.1 re-audit.

## Verification Run During Audit

- Focused `test-ge7-lps-api.R`: failed as described above.
- `git diff --check`: passed.
- Re-ran original exact-plane and duplicated-row adversarial probes.
