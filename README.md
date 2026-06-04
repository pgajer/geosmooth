# geosmooth

`geosmooth` is the geometric smoothing and conditional expectation package
split from `gflow`.  It collects local-polynomial and geometry-aware smoothers
that can be used on ordinary coordinate data, point-cloud embeddings, and, when
`gflow` graph objects are supplied, graph-geodesic supports.

The package is still in early development, but the current public surface is
usable for local experiments and for the S-LPL-TF / SLPLiFT synthetic benchmark
workflows.

## Quick Start

```r
library(geosmooth)

set.seed(1)
x <- seq(0, 1, length.out = 60)
X <- cbind(x = x)
y <- sin(2 * pi * x) + rnorm(length(x), sd = 0.08)
foldid <- rep(1:5, length.out = length(y))

lps.fit <- fit.lps(
    X = X,
    y = y,
    foldid = foldid,
    support.grid = c(8L, 12L, 16L),
    degree.grid = 0:1,
    kernel.grid = c("gaussian", "tricube")
)

head(predict(lps.fit))
```

`fit.lps()` is the canonical local polynomial smoother (LPS) entry point.  It
selects support size, local polynomial degree, and kernel by cross-validation.

## Method Map

Current public payload:

- **LPS**: local polynomial smoother, `fit.lps()`.
  Use this as the direct local-regression baseline.  It predicts by fitting a
  local polynomial around each evaluation point.

- **MALPS**: model-averaged local polynomial smoother, `fit.malps()`.
  Use this when you want many local polynomial fits around observed anchors and
  an averaged prediction surface.

- **LPL-TF**: local polynomial lifting trend filtering, `fit.lpl.tf()` and
  `lpl.tf.operator()`.
  Use this when the local polynomial residual operator should be regularized by
  an \(\ell_1\) trend-filtering penalty.

- **SLPLiFT / S-LPL-TF**: synchronized local polynomial lifting trend
  filtering, `fit.slpl.tf()` and `slpl.tf.operator()`.
  Use this when you want LPL-TF plus a quadratic synchronization penalty across
  overlapping local predictions.

- **SSRHE**: SSRHE-style Hessian-energy smoothing,
  `fit.ssrhe.hessian.regression()` and
  `fit.ssrhe.hessian.l1.regression()`.
  Use this as a Hessian-energy comparator with fixed-k, supplied, or
  graph-derived adaptive-radius neighborhoods.

## Basic Examples

### LPS

```r
lps.fit <- fit.lps(
    X = X,
    y = y,
    foldid = foldid,
    support.grid = c(8L, 12L),
    degree.grid = 0:1,
    kernel.grid = "gaussian"
)

lps.pred <- predict(lps.fit, X)
```

### MALPS

```r
malps.fit <- fit.malps(
    X = X,
    y = y,
    degree = 1L,
    support.type = "knn",
    support.size = 12L,
    kernel = "tricube",
    support.selection = "fixed",
    coordinate.method = "coordinates"
)
```

### LPL-TF and SLPLiFT Operators

```r
lpl.op <- lpl.tf.operator(
    X = X,
    degree = 1L,
    support.type = "knn",
    support.size = 12L,
    kernel = "gaussian",
    coordinate.method = "coordinates"
)

slpl.op <- slpl.tf.operator(
    X = X,
    degree = 1L,
    support.type = "knn",
    support.size = 12L,
    kernel = "gaussian",
    coordinate.method = "coordinates"
)
```

Fitting LPL-TF and SLPLiFT currently uses the optional `genlasso` dependency.

```r
if (requireNamespace("genlasso", quietly = TRUE)) {
    lpl.fit <- fit.lpl.tf(
        y = y,
        operator = lpl.op,
        lambda = 0.1,
        lambda.selection = "fixed"
    )

    slpl.fit <- fit.slpl.tf(
        y = y,
        operator = slpl.op,
        lambda1 = 0.1,
        lambda2 = 0.01,
        lambda.selection = "fixed"
    )
}
```

### SSRHE Hessian-Energy Regression

```r
grid <- expand.grid(x = seq(0, 1, length.out = 5),
                    y = seq(0, 1, length.out = 5))
X2 <- as.matrix(grid)
y2 <- sin(2 * pi * X2[, 1]) + 0.25 * X2[, 2]

ssrhe.fit <- fit.ssrhe.hessian.regression(
    X = X2,
    y = y2,
    k = 12L,
    tangent.dim = 2L,
    lambda1 = 0.05,
    return.local.diagnostics = FALSE
)
```

The same runnable code is available in
`inst/examples/geosmooth_quickstart.R`.

## Graph Dependency Boundary

`geosmooth` owns smoother APIs and package-local coordinate/fixed-k paths.
Graph construction remains owned by `gflow`.

That means:

- Coordinate LPS, coordinate MALPS, coordinate LPL-TF/SLPLiFT, fixed-k SSRHE,
  and supplied-neighborhood SSRHE are package-local `geosmooth` paths.
- Graph-dependent paths, including graph-geodesic MALPS/LPL-TF/SLPLiFT
  supports and SSRHE adaptive-radius neighborhoods, deliberately bridge to a
  compatible `gflow` installation.
- `geosmooth` does not currently export graph construction functions such as
  rKNN graph builders.

Native support currently includes:

- C++ coordinate backend for LPS CV and prediction
- C++ shared local-PCA chart backend
- C++ SSRHE Hessian-energy operator backend

## Split Status

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
  objects.
- GE8 removed the short-lived `kernel.local.polynomial.cv()` compatibility
  alias so downstream scripts migrate to the new LPS name immediately.
- GE9 added user-facing docs and runnable quick-start examples.

## Validation

Focused validation:

```sh
make test
make check-fast
```
