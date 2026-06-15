# Harlim Second-Order Local SVD H1 Handoff

Date: 2026-06-04

## Scope

Implemented the minimal H1 prototype for an experimental Harlim-style
second-order local SVD chart primitive in `geosmooth`.

This is intentionally isolated from the existing plain local PCA primitive and
from production smoothing paths.  No changes were made to
`compute_local_pca_chart()`, `rcpp_local_pca_chart()`, LPS defaults, or P7
behavior.

## Files Changed

- `inst/include/geosmooth/local_second_order_svd_charts.h`
- `src/local_second_order_svd_charts.cpp`
- `src/local_second_order_svd_charts_rcpp.cpp`
- `R/RcppExports.R`
- `src/RcppExports.cpp`
- `man/rcpp_local_second_order_svd_chart.Rd`
- `tests/testthat/test-harlim-second-order-svd-chart.R`
- `split_handoffs/harlim_second_order_local_svd_handoff_2026-06-04.md`

## Functions Added

- C++ core:
  `geosmooth::compute_local_second_order_svd_chart(...)`
- Rcpp internal entry point:
  `rcpp_local_second_order_svd_chart(...)`

No public high-level R wrapper was added.

## Algorithm Implemented

The implementation follows the revised H0 contract:

- center the supplied local support using `center.mode = "anchor"` or `"mean"`;
- sanitize optional weights by treating nonfinite or nonpositive entries as
  zero;
- run a first weighted SVD on the centered local support;
- form preliminary tangent coordinates `rho.tangent = C T0`;
- construct the exact quadratic design with square columns first and doubled
  cross terms second;
- solve `A Y ~= 2 C` by SVD least squares;
- subtract the fitted curvature displacement `0.5 A Y`;
- run a second weighted SVD on the corrected residual;
- return final coordinates from the original support relative to the requested
  coordinate origin.

The rank rule is scale-relative:

```text
cutoff = rank.tolerance * max(nrow(M), ncol(M)) * sigma_max
```

with `rank.absolute.tolerance` used only as a zero-scale guard.

## Deviations From H0

- Ridge fallback is not implemented for H1.  Passing nonzero
  `curvature_ridge` is rejected, so the default path remains paper-faithful
  and auditable.
- `normal.basis` is returned as `NULL`; the H1 algorithm does not need an
  explicit normal complement.
- No optional R wrapper `.local.second.order.svd.chart()` was added.

## Fallback Behavior

The primitive records fallback explicitly through `fallback.used`,
`fallback.reason`, `primary.failure.reason`, and
`curvature.diagnostics$plain.pca.fallback.feasible`.

If ordinary fixed-`m` PCA fallback is feasible, it returns a plain PCA chart
using the same support, center, dimension, center mode, weights, rebase flag,
and orientation flag.

If ordinary PCA fallback is not feasible, it returns a structured failure
object with:

- `fallback.reason = "plain_pca_fallback_not_feasible"`;
- the original cause in `primary.failure.reason`;
- `NA` chart matrices for `coordinates`, `basis`, and `preliminary.basis`.

## Tests Added

`tests/testthat/test-harlim-second-order-svd-chart.R` covers:

- flat affine plane agreement with ordinary PCA by comparing tangent projectors;
- near-zero curvature fit on a symmetric flat support;
- exact square-plus-doubled-cross monomial ordering;
- small local coordinate scale, exercising the scale-relative rank rule;
- noiseless 1D parabola correction and no-worse tangent projector error than
  plain PCA;
- structured failure for too-few support rows;
- structured failure for all-zero effective weights.

All basis comparisons use projection matrices or projector errors, not raw
signed basis columns.

## Validation

Commands run from `/Users/pgajer/current_projects/geosmooth`:

```sh
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-harlim-second-order-svd-chart.R")'
make document
make test
make check-fast
make clean
```

Outcomes:

- Targeted H1 test file: 26 passed, 0 failures, 0 warnings, 0 skips.
- `make document`: completed and generated
  `man/rcpp_local_second_order_svd_chart.Rd`.
- `make test`: 817 passed, 0 failures, 0 warnings, 9 expected parity skips.
- `make check-fast`: exited successfully with 2 WARNINGs and 2 NOTEs.
  - WARNING: CRAN incoming feasibility for dev version and non-mainstream
    dependencies (`dgraphs`, `grip`, `gflow`).
  - WARNING: pre-existing undocumented print methods.
  - NOTE: unable to verify current time.
  - NOTE: pre-existing foreign `.Call` to `gflow`.
- `make clean`: removed local build products and check artifacts.

## Readiness

The primitive is ready for H2/H3 chart-diagnostic smoke tests on controlled
geometries.  It is not ready for LPS integration or P7 production use.

Recommended next step: run H2-style comparative diagnostics on flat, parabolic,
saddle, and high-dimensional embedded supports, focusing on tangent-projector
error, fallback rates, and runtime against ordinary local PCA.
