# K12 Audit: LPS Backend Policy and Auto-Dimension Contract

Audited: 2026-06-04 23:55:00 EDT

## Verdict

Not accepted yet.  The backend-policy diagnostics are useful and the advertised
tests pass, but K12 has two blockers before it should be treated as a frozen
contract:

1. The `local.pca.real.data.contract` flag is too permissive and currently
   accepts the experimental second-order SVD chart path.
2. The submitted/generated package state is not reproducible from
   `make document`; rerunning documentation changes `NAMESPACE` beyond the K12
   helper export and generates two additional `.Rd` files not listed in the
   handoff.

## Findings

### P1: `local.pca.real.data.contract` accepts experimental second-order charts

`lps.backend.diagnostics()` defines the real-data contract only as
`coordinate.method == "local.pca"`, `chart.dim = "auto"`,
`auto.chart.support.metric = "both"`, and
`auto.chart.selection.metric = "operator"`
(`/Users/pgajer/current_projects/geosmooth/R/kernel_local_polynomial_cv.R:320`).
It does not require `local.chart.method.effective == "pca"`.

As a result, this fit is reported as contract-compliant:

```r
fit.lps(
    X, y,
    coordinate.method = "local.pca",
    local.chart.method = "second.order.svd",
    chart.dim = "auto",
    auto.chart.support.metric = "both",
    auto.chart.selection.metric = "operator",
    backend = "auto"
)
```

Observed diagnostic:

```text
local.chart.method.effective = second.order.svd
backend.auto.policy = auto_local_pca_R_reference
chart.dim.auto = TRUE
local.pca.real.data.contract = TRUE
```

That is too broad for a flag intended to certify the deployable local-PCA LPS
contract.  The second-order SVD chart path is experimental and should not be
silently labeled as satisfying the local-PCA real-data contract.  Tighten the
predicate to require the ordinary PCA chart path, and add a regression test
that `local.chart.method = "second.order.svd"` returns
`local.pca.real.data.contract = FALSE`.

### P1: `make document` produces unaccounted generated-file drift

The handoff lists only these generated/package changes:

- `R/kernel_local_polynomial_cv.R`
- `man/lps.backend.diagnostics.Rd`
- `NAMESPACE`
- `tests/testthat/test-ge7-lps-api.R`

After rerunning `make document`, the working tree shows additional generated
drift:

- `man/rcpp_kernel_local_polynomial_cv_local_pca_profile.Rd`
- `man/rcpp_kernel_local_polynomial_neighbor_probe.Rd`
- `NAMESPACE` changes that remove several `S3method(print, ...)` registrations
  and replace them with exported `print.*` functions.

This means the submitted K12 bundle is not self-consistent with the stated
documentation-generation gate.  Either the extra generated files and NAMESPACE
changes must be intentionally included, or the roxygen tags should be corrected
so `make document` regenerates only the intended K12 changes.  Do not freeze
the contract while `make document` causes unexplained NAMESPACE/S3 registration
drift.

## Non-Blocking Notes

- The helper correctly reports the main backend policy in smoke checks:
  ambient-coordinate `backend = "auto"` resolves to `backend.used = "cpp"`;
  local-PCA `backend = "auto"` resolves to `backend.used = "R"`; explicit
  `backend = "cpp.local.pca"` is labeled as explicit native opt-in.
- The helper handles absent auto-dimension diagnostics without crashing,
  returning `NA` diagnostic fields for ambient and fixed-dimension fits.
- The reported `auto.chart.support.metric.selected` is `"coordinates"` for the
  LPS `both`/`operator` smoke case, which is consistent with the current LPS
  equivalence of operator and coordinate supports.  The requested metrics are
  still separately recorded.

## Verification

Passed:

```sh
make document
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-ge7-lps-api.R", reporter = "summary")'
make test
git diff --check
```

`make test` result: 0 failures, 0 warnings, 9 expected migration-reference
skips, and 909 passes.

Additional audit probes:

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE); ...; lps.backend.diagnostics(second_order_svd_fit)'
Rscript -e 'pkgload::load_all(".", quiet=TRUE); ...; lps.backend.diagnostics(ambient_fit_without_auto_diagnostics)'
```

Compiled test artifacts under `src/` were removed after verification.

## Required Fixes

1. Restrict `local.pca.real.data.contract` to the ordinary PCA chart path,
   likely by requiring `local.chart.method.effective == "pca"` in addition to
   the current fields.
2. Add a focused GE7 regression test proving `local.chart.method =
   "second.order.svd"` does not satisfy the real-data local-PCA contract.
3. Reconcile roxygen output: rerun `make document`, then either include the
   generated `.Rd`/NAMESPACE changes intentionally or fix the roxygen tags so
   generated files match the intended K12 surface.
4. Rerun the focused GE7 test, `make test`, and `git diff --check`.
