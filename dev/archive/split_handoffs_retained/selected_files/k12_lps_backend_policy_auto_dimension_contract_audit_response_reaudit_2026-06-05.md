# K12 Audit Response Re-Audit: LPS Backend Policy and Auto-Dimension Contract

Audited: 2026-06-05 00:11:15 EDT

## Verdict

Accepted for the narrow K12 backend-policy and auto-dimension diagnostic
contract.

The previous K12 blockers are resolved:

1. `local.pca.real.data.contract` now certifies only the ordinary
   `local.chart.method = "pca"` local-PCA path, so the experimental
   `second.order.svd` chart path is explicitly excluded.
2. Roxygen output is now reconciled for the accidental internal native-wrapper
   docs noted in prior audits.  After `make document`, only
   `man/lps.backend.diagnostics.Rd` appears among the K12 diagnostic docs; the
   accidental internal LPS and harmonic native `.Rd` pages do not regenerate.
3. The migration/parity tests that were moved out of ordinary `make test` are
   now visible through an explicit `make test-migration` target.
4. The broader graph-boundary, `dgraphs`, and harmonic-native changes are no
   longer claimed as part of K12 acceptance; they are covered separately by the
   DG10bcd/DG10e audit.

## Findings

No K12-blocking findings remain.

## Checks

### Contract Predicate

Direct probe:

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

Result:

```text
local.chart.method.effective = second.order.svd
backend.auto.policy = auto_local_pca_R_reference
chart.dim.auto = TRUE
local.pca.real.data.contract = FALSE
```

This matches the intended deployable local-PCA contract.

### Generated Documentation

After `make document`, the only matching K12 diagnostic manual page is:

```text
man/lps.backend.diagnostics.Rd
```

The previously accidental pages do not appear:

```text
man/rcpp_kernel_local_polynomial_cv_local_pca_profile.Rd
man/rcpp_kernel_local_polynomial_neighbor_probe.Rd
man/rcpp_perform_harmonic_smoothing.Rd
man/rcpp_harmonic_smoother.Rd
```

### Migration Test Visibility

`Makefile` now includes:

```make
test-migration:
	Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_dir("tests/migration")'
```

That resolves the earlier audit concern that migration parity checks had been
moved out of ordinary QA without a visible target.

## Verification

Passed:

```sh
make document
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-ge7-lps-api.R", reporter = "summary")'
make test
make test-migration
make check-fast
git diff --check
```

Results:

- Focused GE7 test: passed.
- Ordinary `make test`: `0` failures, `0` warnings, `0` skips, `921` passes.
- `make test-migration`: `0` failures, `0` warnings, `9` historical
  gflow-reference skips, `13` passes.
- `make check-fast`: completed with `1 WARNING`, `1 NOTE`.
  The warning is the expected development-package/non-mainstream dependency
  warning; the note is the existing non-standard top-level `scripts`
  directory.

Compiled objects, shared libraries, the package tarball, and `geosmooth.Rcheck`
were removed after verification.

## Residuals

The broad graph-boundary and native harmonic changes remain outside this K12
verdict.  They are accepted by the separate DG10bcd/DG10e audit at:

```text
/Users/pgajer/current_projects/trend_filtering/development/package_split_audit/dg10bcd_dg10e_geosmooth_bridge_harmonic_audit_2026-06-05.md
```

Any further cleanup of the direct `dgraphs` contract, installed
self-containment, or native naming residue should proceed through the DG10f and
DG10g follow-up tracks, not through K12.
