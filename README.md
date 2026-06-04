# geosmooth

`geosmooth` is the planned geometric smoothing and conditional expectation
package split from `gflow`.

The initial package skeleton vendors ANN and Eigen support so local-neighborhood
smoothers can become self-contained.  Public smoother APIs are not moved in GE0;
they will be migrated in later phases while keeping names and behavior stable.

Planned first payload:

- LPS, currently `kernel.local.polynomial.cv`;
- MALPS;
- LPL-TF;
- SLPLiFT / S-LPL-TF;
- SSRHE.

Focused validation:

```sh
make test
make check-fast
```
