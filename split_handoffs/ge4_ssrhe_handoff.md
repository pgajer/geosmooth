# geosmooth GE4 SSRHE Handoff

Date: 2026-06-03

## Scope

GE4 moves the SSRHE public/native backend from `gflow` into `geosmooth`.
This completes the initially planned public smoother set for the split:
LPS, MALPS, LPL-TF, SLPLiFT / S-LPL-TF, and SSRHE.

The migrated SSRHE payload includes:

- `ssrhe.hessian.operator()`
- `ssrhe.support.grid()`
- `fit.ssrhe.hessian.regression()`
- `refit.ssrhe.hessian.regression()`
- `fit.ssrhe.hessian.regression.cv()`
- `fit.ssrhe.hessian.regression.gcv()`
- `fit.ssrhe.hessian.l1.regression()`
- `refit.ssrhe.hessian.l1.regression()`
- S3 print methods for SSRHE operator, L2, CV, GCV, refit, and L1 objects

The native SSRHE operator backend was moved to `src/ssrhe_hessian_energy.cpp`
with a package-local Rcpp registration wrapper,
`rcpp_ssrhe_hessian_operator()`.  The legacy GE1 private
`R/ssrhe_l1_helpers.R` subset was removed because the full SSRHE file now owns
the same helper namespace.

## Split Adjustments

The migration preserves SSRHE behavior while changing package plumbing:

- Native calls now go through `_geosmooth_rcpp_ssrhe_hessian_operator`.
- Local PCA chart calls use the shared `geosmooth::compute_local_pca_chart()`
  backend in `inst/include/geosmooth/local_pca_charts.h`.
- S3 print methods are explicitly registered in `NAMESPACE`.
- Adaptive-radius support construction remains bridged through local `gflow`
  via `.geosmooth.gflow.bridge("create.rknn.graph")`.

The adaptive-radius bridge is intentional for GE4.  Graph construction and
graph-distance infrastructure have not yet moved into `geosmooth`.

## Added Coverage

GE4 adds two focused test layers:

- `test-ge4-ssrhe-hessian-energy.R`: package-local SSRHE smoke, algebra,
  fitting, CV, GCV, L1, ADMM, order-3, supplied-neighborhood, and
  adaptive-radius coverage.
- `test-ge4-ssrhe-parity.R`: compact source-level parity checks against the
  local split-era `gflow` source for the fixed-k SSRHE operator, L2 fit, and
  L1 ADMM fit.

The GE3 parity helper now requires split-era SSRHE reference functions when
running source-level parity tests against local `gflow`.

## Validation

Validation commands run from `/Users/pgajer/current_projects/geosmooth`:

```sh
make document
make test
make check-fast
```

Observed results:

- `make document`: regenerated Rcpp attributes, NAMESPACE, and Rd files.
- `make test`: 322 passed assertions, 0 failures, 0 warnings, 0 skips.
- `make check-fast`: completed with 1 NOTE.

The `R CMD check` NOTE is the expected early-development package status:
new submission/development version and `gflow` listed as a non-mainstream
suggested package.

## Deferred Work

GE4 deliberately leaves the following work for later phases:

- Move graph construction and graph-distance infrastructure out of the
  temporary `gflow` bridge.
- Decide whether SSRHE-related graph/adaptive-radius examples should remain in
  `geosmooth` or live in downstream workflow packages.
- API cleanup, including possible post-split renaming of `.cv` functions.
- Broader performance profiling after the package split is stable.

## Recommended Next Step

Run `make check-fast`.  If it passes, GE5 should focus on graph infrastructure
and bridge retirement, or on API naming cleanup if graph movement is deferred.
