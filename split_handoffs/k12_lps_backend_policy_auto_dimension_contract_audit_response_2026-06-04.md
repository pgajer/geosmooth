# K12 audit response: LPS backend policy and auto-dimension contract

Generated: 2026-06-05 00:05:02 EDT

## Summary

The K12 audit blockers were addressed.

K12 now keeps the public backend-policy diagnostic helper, but tightens its
deployable real-data contract flag so that it certifies only the ordinary
local-PCA chart path.  The experimental second-order local SVD chart path is
still reported explicitly by `lps.backend.diagnostics()`, but it no longer
satisfies `local.pca.real.data.contract`.

The roxygen-generated state was also reconciled.  The two internal Rcpp
diagnostic wrappers that had generated public-looking `.Rd` files are now
marked `@noRd`, and the unrelated print-method roxygen tags were corrected so
`make document` regenerates S3 method registrations rather than exporting
`print.*` functions.

Re-audit follow-up: the broad graph-boundary, dgraphs, migration-test-policy,
and native harmonic smoother changes are no longer treated as part of the
narrow K12 acceptance claim.  They are tracked separately under DG10bcd/DG10e
and audited in
`/Users/pgajer/current_projects/trend_filtering/development/package_split_audit/dg10bcd_dg10e_geosmooth_bridge_harmonic_audit_2026-06-05.md`.
K12's package-facing claim remains limited to the LPS backend policy and
auto-dimension diagnostic contract.

## Changes made

### Contract predicate tightened

Updated:

```text
R/kernel_local_polynomial_cv.R
```

The predicate for `local.pca.real.data.contract` now requires:

```r
coordinate.method == "local.pca"
local.chart.method.effective == "pca"
chart.dim.auto == TRUE
auto.chart.support.metric == "both"
auto.chart.selection.metric == "operator"
```

This excludes:

- ambient-coordinate LPS;
- fixed-dimension local-PCA LPS;
- explicit native local-PCA opt-in with fixed `chart.dim`; and
- experimental `local.chart.method = "second.order.svd"` fits.

### Regression test added

Updated:

```text
tests/testthat/test-ge7-lps-api.R
```

Added a K12 regression test that fits:

```r
fit.lps(
    coordinate.method = "local.pca",
    local.chart.method = "second.order.svd",
    chart.dim = "auto",
    auto.chart.support.metric = "both",
    auto.chart.selection.metric = "operator",
    backend = "auto"
)
```

and verifies:

```r
local.chart.method.effective == "second.order.svd"
chart.dim.auto == TRUE
local.pca.real.data.contract == FALSE
```

### Roxygen drift reconciled

Updated:

```text
src/kernel_local_polynomial_cv_rcpp.cpp
R/RcppExports.R
R/graph_trend_filtering.R
R/pttf_fit.R
R/pttf_operator.R
R/transported_graph_hessian.R
NAMESPACE
```

The internal C++ diagnostic wrappers:

```text
rcpp_kernel_local_polynomial_cv_local_pca_profile()
rcpp_kernel_local_polynomial_neighbor_probe()
```

are now documented with `@noRd`, so `make document` deletes the accidental
generated files:

```text
man/rcpp_kernel_local_polynomial_cv_local_pca_profile.Rd
man/rcpp_kernel_local_polynomial_neighbor_probe.Rd
```

The print methods for graph trend filtering, PTTF, and transported graph
Hessian objects now have explicit `@method print ...` tags.  After
`make document`, `NAMESPACE` keeps these as S3 methods and the only K12
namespace addition is:

```text
export(lps.backend.diagnostics)
```

### Re-audit documentation drift fixed

Updated:

```text
src/harmonic_smoothing_native.cpp
R/RcppExports.R
Makefile
```

The re-audit noted that the new internal harmonic native wrappers had generated
manual pages.  Both internal wrappers are now marked `@noRd`:

```text
rcpp_perform_harmonic_smoothing()
rcpp_harmonic_smoother()
```

After `make document`, roxygen deletes:

```text
man/rcpp_perform_harmonic_smoothing.Rd
man/rcpp_harmonic_smoother.Rd
```

The re-audit also noted that moved parity tests needed an explicit test target.
The `Makefile` now has:

```sh
make test-migration
```

which runs:

```sh
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_dir("tests/migration")'
```

This makes the migration/parity suite opt-in but visible, rather than hidden by
the ordinary `make test` target.

## Validation

Passed:

```sh
make document
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-ge7-lps-api.R", reporter = "summary")'
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-graph-trend-filtering.R")'
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_dir("tests/testthat")'
make test-migration
git diff --check
```

The focused GE7 test completed with no failures.  The focused graph trend
filtering test completed with no failures.  The ordinary `tests/testthat`
suite completed with no failures:

```text
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 921 ]
```

The explicit migration suite remains opt-in and currently reports historical
gflow-reference skips rather than ordinary-package failures:

```text
[ FAIL 0 | WARN 0 | SKIP 9 | PASS 13 ]
```

## Full-test status

The two previously observed ordinary-test blockers are resolved:

1. The installed `dgraphs` package was refreshed from
   `/Users/pgajer/current_projects/dgraphs`; its installed `NAMESPACE` now
   exports `shortest.path`, and `dgraphs::shortest.path()` resolves from the
   active R library.  A `dgraphs` regression test was added in
   `tests/testthat/test-namespace-exports.R` to check that
   `shortest.path`, `create.path.graph`, and `get.shortest.path` remain
   exported.
2. The ordinary graph trend filtering test no longer depends on the removed
   DG10 migration helper `fit_ssrhe_graph_trend_filtering_case()`.  The
   package-local test path uses `make_ssrhe_like_graph_trend_case()` and calls
   `dgraphs::create.rknn.graph()` directly.  The old helper name remains only
   in `tests/migration/test-graph-trend-filtering-gflow-fixtures.R`, where it
   belongs as a migration/parity fixture.

## Residual recommendation

K12 is ready for re-audit from the backend-policy perspective.  The ordinary
`tests/testthat` suite is no longer blocked by the DG10 graph-split issues
listed in the original audit response.

The broader DG10 split work should be accepted or revised through its own
handoffs/audits, not through K12.  In particular, DG10f should next clean up the
remaining direct dgraphs contract and installed self-containment checks, as
specified in the DG10bcd/DG10e audit.
