# K12 Handoff: LPS Backend Policy and Auto-Dimension Contract

Generated: 2026-06-04 23:24:21 EDT

## Scope

K12 freezes the current LPS backend policy and makes it inspectable from fitted
objects.  It does not promote the native local-PCA backend to
`backend = "auto"`.

K12 responds to the K11 conclusion:

- `backend = "cpp.local.pca"` is validated enough for explicit opt-in use on
  focused P7-style panels;
- `backend = "auto"` should remain conservative until a broader
  size/dimension/default-policy study justifies promotion; and
- `chart.dim = "auto"` is the deployable real-data contract for local-PCA LPS,
  because real data do not expose latent dimension.

## Backend Policy Frozen in K12

For `fit.lps()`:

1. `coordinate.method = "coordinates", backend = "auto"` resolves to
   `backend.used = "cpp"`.
2. `coordinate.method = "local.pca", backend = "auto"` resolves to
   `backend.used = "R"`.
3. `backend = "cpp.local.pca"` remains an explicit opt-in backend and requires
   `coordinate.method = "local.pca"` and `local.chart.method = "pca"`.
4. `backend = "cpp.local.pca"` is not promoted into the default `auto` path in
   K12.

This policy keeps the local-PCA native backend available for controlled P7
experiments while avoiding an un-audited default backend switch.

## Auto-Dimension Contract Frozen in K12

For deployable real-data local-PCA LPS runs, the contract is:

```r
coordinate.method = "local.pca"
chart.dim = "auto"
auto.chart.support.metric = "both"
auto.chart.selection.metric = "operator"
```

For LPS itself, supports are coordinate-based, so the operator-support
auto-dimension diagnostic is currently equivalent to the coordinate-support
diagnostic.  The fields are still recorded because P7, LPL-TF, and S-LPL-TF
need one shared manifest schema.

The important non-oracle rule is unchanged: chart dimension must be estimated
from observed covariates only, not from latent coordinates, truth functions, or
synthetic-data metadata.

## Package Changes

Added:

```text
R/kernel_local_polynomial_cv.R
man/lps.backend.diagnostics.Rd
```

Updated:

```text
NAMESPACE
tests/testthat/test-ge7-lps-api.R
```

## New Public Helper

K12 adds:

```r
lps.backend.diagnostics(object)
```

The helper returns one row per fitted LPS object and records:

- method id;
- coordinate method;
- requested and effective local chart method;
- requested backend;
- used backend;
- backend policy label;
- requested chart dimension;
- resolved chart dimension;
- whether chart dimension was auto-estimated;
- auto-dimension support and selection metrics;
- selected support size, degree, kernel, and observed CV RMSE;
- candidate count; and
- whether the fit satisfies the local-PCA real-data auto-dimension contract.

This gives P7 and future reports a stable package-facing way to record backend
and chart-dimension decisions without relying on ad hoc report code.

## Focused Validation

Passed:

```sh
make document
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-ge7-lps-api.R", reporter = "summary")'
make test
Rscript -e 'pkgload::load_all(".", quiet=TRUE); X <- matrix(seq(0,1,length.out=20), ncol=1); y <- X[,1]^2; fit <- fit.lps(X,y,foldid=rep(1:4,length.out=20),support.grid=6L,degree.grid=1L,kernel.grid="gaussian",backend="auto"); print(lps.backend.diagnostics(fit))'
git diff --check
```

`make test` result: 0 failures, 0 warnings, 9 expected migration-reference
skips, and 909 passes.

The focused tests verify:

1. ambient-coordinate `backend = "auto"` reports `backend.used = "cpp"`;
2. local-PCA `backend = "auto"` reports `backend.used = "R"`;
3. P7-style `chart.dim = "auto"`, `auto.chart.support.metric = "both"`,
   and `auto.chart.selection.metric = "operator"` are recorded as satisfying
   the real-data local-PCA contract; and
4. explicit `backend = "cpp.local.pca"` is reported as explicit native opt-in,
   not as an auto-backend policy.

## Recommendation

Use `lps.backend.diagnostics()` in P7 report generation and method manifests
whenever LPS is included.  Future default-policy work should compare repeated
runtime and numerical-stability panels, but K12 is complete for the current
policy contract: explicit opt-in native local-PCA is allowed, conservative
`backend = "auto"` remains unchanged, and real-data local-PCA dimension
selection uses `chart.dim = "auto"`.
