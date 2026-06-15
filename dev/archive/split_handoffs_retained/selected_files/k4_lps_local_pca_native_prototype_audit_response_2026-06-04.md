# K4 Audit Response: Native Local-PCA LPS Backend Prototype

Generated: 2026-06-04 16:13:55 EDT

## Scope

This response addresses the audit comments in
`split_handoffs/k4_lps_local_pca_native_prototype_audit_2026-06-04.md`
and the re-audit blocker in
`split_handoffs/k4_lps_local_pca_native_prototype_reaudit_2026-06-04.md`.

## Response Summary

The P1 tie-neighborhood parity issue has been addressed. The native support
construction now recovers kth-neighbor boundary ties before support slicing.
The resulting native neighbor lists follow the same contract as the R reference
path:

\[
  (\hbox{distance to target},\ \hbox{original row index}).
\]

For each query, ANN still provides the provisional neighbor scale. The native
helper then takes the kth squared distance, scans the full training row set for
all rows below or tied at that distance, sorts the recovered candidate set by
`(distance, original row index)`, and slices the first `k` rows. This fixes the
specific re-audit concern where ANN could omit a lower-row tied point at the
kth-neighbor boundary.

The implementation also adds a QR least-squares fallback when the native
normal-equation Cholesky solve encounters a singular local polynomial design.
This matches the R reference behavior more closely on duplicated or low-rank
local supports, where `lm.wfit()` can still return a finite intercept rather
than immediately falling back to a weighted mean.

The P2 scope warning is accepted unchanged. The native backend remains explicit:

```r
fit.lps(..., coordinate.method = "local.pca",
        local.chart.method = "pca",
        backend = "cpp.local.pca")
```

`backend = "auto"` still routes local-PCA LPS to the R reference path.

## Changes Made

- Added native tie-complete neighbor recovery in
  `src/kernel_local_polynomial_cv_rcpp.cpp`.
- Applied the tie-complete support construction in:
  - ambient native CV,
  - ambient native prediction,
  - local-PCA native CV,
  - local-PCA native prediction.
- Added a native QR fallback after Cholesky failure for weighted local
  polynomial fits, before falling back to the weighted mean.
- Added regression coverage in `tests/testthat/test-ge7-lps-api.R` for:
  - an exact symmetric plane grid embedded in 3D,
  - duplicated/tied local supports.
- Added an internal native neighbor probe and regression coverage showing that
  raw ANN tie order is not the package contract; the geosmooth tie-complete
  helper matches the R reference order on cardinal-point, duplicated-row, and
  grid tie examples.
- Added a tiny deterministic CV selection tolerance in `fit.lps()` so
  candidates whose CV RMSE differs only by numerical dust are selected by the
  documented simple-model tie-breakers rather than backend-dependent
  floating-point crumbs.
- Reran and refreshed the K4 benchmark assets:
  - `split_handoffs/k4_lps_local_pca_native_prototype_2026-06-04/k4_lps_local_pca_native_prototype.html`
  - `split_handoffs/k4_lps_local_pca_native_prototype_2026-06-04/k4_lps_local_pca_native_prototype_results.csv`
  - `split_handoffs/k4_lps_local_pca_native_prototype_handoff_2026-06-04.md`

## Validation

- `R CMD INSTALL --preclean /Users/pgajer/current_projects/geosmooth`: passed.
- Focused `test-ge7-lps-api.R`: passed.
- Explicit adversarial probes passed with matching selected candidates:
  - exact line: max absolute CV RMSE difference `2.09e-15`;
  - exact plane: max absolute CV RMSE difference `4.76e-14`;
  - duplicated rows: max absolute CV RMSE difference `1.53e-14`;
  - `chart.dim = "auto"`: max absolute CV RMSE difference `3.66e-09`.
- Raw ANN tie-order probe on this machine showed arbitrary tied-neighbor order:
  - four cardinal points, `k = 2`: raw rows `2, 3`, tie-complete/reference rows
    `1, 2`;
  - duplicated line, `k = 3`: raw rows `4, 3, 5`, tie-complete/reference rows
    `3, 4, 1`;
  - centered 3x3 grid, `k = 4`: raw rows `5, 6, 2, 8`,
    tie-complete/reference rows `5, 2, 4, 6`.
- `make test`: passed with 863 passes and the existing 9 expected split-era
  gflow-parity skips.
- `git diff --check`: passed.

## Remaining Scope Boundary

K4 remains a native prototype, not a promotion decision. The current evidence
supports explicit opt-in use of `backend = "cpp.local.pca"` for ordinary PCA
charts. It does not yet justify changing `backend = "auto"`.

## Recommended Next Step

Request re-audit of K4. If accepted, proceed to K4.1: reuse cached local PCA
charts across candidates that share the same fold, target, support size, and
chart dimension, then rerun the larger K3.9 local-PCA acceleration benchmark
with `backend = "cpp.local.pca"`.
