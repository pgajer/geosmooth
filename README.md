# geosmooth

`geosmooth` is the planned geometric smoothing and conditional expectation
package split from `gflow`.

The initial package skeleton vendors ANN and Eigen support so local-neighborhood
smoothers can become self-contained.

Current split status:

- GE0 created the package skeleton and native support scaffold.
- GE1 moved the R-level LPS, MALPS, LPL-TF, and SLPLiFT APIs.
- GE2 moved the C++ LPS and local-PCA chart backends.
- GE4 will move the SSRHE public/native backend.

Current public payload:

- LPS, currently `kernel.local.polynomial.cv`
- MALPS
- LPL-TF
- SLPLiFT / S-LPL-TF

Native support currently includes:

- C++ coordinate backend for LPS CV and prediction
- C++ shared local-PCA chart backend

Focused validation:

```sh
make test
make check-fast
```
