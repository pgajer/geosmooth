# geosmooth GE2 Native LPS and Local-PCA Handoff

Generated: 2026-06-03

## Scope

GE2 moves the native C++ backend for LPS coordinate-mode CV/prediction and the
shared local-PCA chart backend from `gflow` into `geosmooth`.

This phase replaces the GE1 deferred-native guards for:

- `kernel.local.polynomial.cv(..., backend = "cpp")`
- coordinate-mode LPS prediction through the C++ backend
- `coordinate.method = "local.pca"` in LPS R-backend fits
- `coordinate.method = "local.pca"` in `lpl.tf.operator`

## Native Files Added

- `src/kernel_local_polynomial_cv_rcpp.cpp`
- `src/local_pca_charts.cpp`
- `src/local_pca_charts_rcpp.cpp`
- `inst/include/geosmooth/local_pca_charts.h`
- generated `src/RcppExports.cpp`
- generated `R/RcppExports.R`

The local-PCA backend namespace and include guard were renamed from `gflow` to
`geosmooth`.  Generated native symbols use the `_geosmooth_*` prefix.
Geosmooth-owned reusable headers live under `inst/include/geosmooth/`; `src/`
contains implementation `.cpp` files and vendored compiled ANN sources only.

## Native Registration

The GE0 manual `src/init.c` scaffold was removed.  All native entry points now
go through `Rcpp::compileAttributes()` and the generated
`R_init_geosmooth()` registration in `src/RcppExports.cpp`.

## Tests Added/Updated

GE2 extends the focused smoke tests to cover:

- LPS coordinate C++ backend fit and prediction;
- LPS local-PCA chart path;
- LPL-TF local-PCA operator path;
- unsupported `backend = "cpp"` with local-PCA LPS still fails
  informatively.

## Deliberate Deferrals

GE2 does not move:

- SSRHE public/native backend;
- graph-geodesic native/graph infrastructure;
- compatibility wrappers back in `gflow`;
- public API renames such as `kernel.local.polynomial`.

Those remain GE4/GE5 or post-split API cleanup tasks.

## Validation

Passed:

- `make document`
- `make test`
- `make check-fast`

`make test` passed 29 focused tests.  `make check-fast` reports only the
expected new-development-package NOTE for `gflow` in `Suggests`.

## Next Phase

GE3 should bring up stronger parity/smoke coverage for LPL-TF, SLPLiFT, and
MALPS after the native local-PCA backend is available, and decide whether any
additional R helpers should move before GE4 SSRHE.
