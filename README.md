# geosmooth

`geosmooth` is the planned geometric smoothing and conditional expectation
package split from `gflow`.

The initial package skeleton vendors ANN and Eigen support so local-neighborhood
smoothers can become self-contained.

Current split status:

- GE0 created the package skeleton and native support scaffold.
- GE1 moved the R-level LPS, MALPS, LPL-TF, and SLPLiFT APIs.
- GE2 moved the C++ LPS and local-PCA chart backends.
- GE3 added source-level parity and smoke coverage against split-era `gflow`.
- GE4 moved the SSRHE public/native backend.
- GE5 formalized the graph dependency boundary: graph construction and
  graph-geodesic helper utilities remain owned by `gflow`.
- GE6 started private helper cleanup by giving the shared local-polynomial
  design helper a MALPS-independent name while retaining compatibility shims.
- GE7 introduced the public LPS naming layer: `fit.lps()` returns `"lps"`
  objects, while `kernel.local.polynomial.cv()` remains a compatibility alias.

Current public payload:

- LPS / local polynomial smoother, with canonical entry point `fit.lps()`
  and compatibility alias `kernel.local.polynomial.cv()`
- MALPS
- LPL-TF
- SLPLiFT / S-LPL-TF
- SSRHE Hessian-energy L2 and L1 regression

Native support currently includes:

- C++ coordinate backend for LPS CV and prediction
- C++ shared local-PCA chart backend
- C++ SSRHE Hessian-energy operator backend

Graph dependency boundary:

- `geosmooth` owns smoother APIs and package-local coordinate/fixed-k paths.
- `gflow` remains the owner of graph construction and graph-geodesic utilities,
  including rKNN graph construction.
- Graph-dependent paths in `geosmooth`, such as graph-geodesic MALPS/LPL-TF
  supports and SSRHE adaptive-radius neighborhoods, deliberately bridge to
  `gflow` at runtime.

Focused validation:

```sh
make test
make check-fast
```
