## Update to geosmooth 0.2.0

This is an update to geosmooth 0.1.0. It consolidates the public API and adds
an installed HTML function-guide vignette. Method-specific refit behavior is preserved. This update also corrects
Hessian L1 numerical reliability and the fixed-smoother LPS noise-variance
denominator, with migration details and a legacy variance option in NEWS.

The update removes 35 exported names and adds two S3 generics:

* The 25 transitional geometry and sampling re-exports are replaced by calls
  to the corresponding functions in dgraphs.
* The separate quadratic Hessian CV and GCV fitters are replaced by
  `fit.ssrhe.hessian.regression()` with explicit selection modes and controls.
* Six refit entry points are replaced by `refit(object, y, ...)`.
* The LPS and MALPS matrix extractors are replaced by
  `smoother.matrix(object, ...)`.

NEWS, function help, and the function-guide vignette explain migration,
including argument-name changes and method-specific restrictions. Former help
aliases remain available. The synthetic-datasets vignette now uses the
geometry and sampling API owned by dgraphs.

## Dependency release prerequisite

This is a preparation draft, not a ready-to-submit declaration. DESCRIPTION
requires `dgraphs (>= 0.2.1.9000)`; the CRAN source index still supplied 0.2.0
on 2026-09-15. That version lacks required geometry and sampling imports.
The separate CRAN-only dependency gate correctly fails on this requirement.

Development checks explicitly use published dgraphs revision
22c0f2b7b1c53af5aabf1f19e6c390ce343d87fe (0.2.1.9000). geosmooth also supports
the new dgraph representation and public accessors in committed development
revision ea745a04a55a9926ac044c9de70109e04e705dae. Its dependency adapters and
examples have been tested against both; the active sibling checkout was not
used as a reproducibility claim.

Current R-devel adds a fourth RNGkind setting. The pinned dgraphs validator
rejects its valid synthetic RNG-state headers. That dependency fix must be
integrated and tested on current R-devel. The local R-devel revision below
predates that change and cannot establish its resolution.

After a compatible dgraphs release is on CRAN, require its actual released
version and repeat the final platform and CRAN-only checks without development
overrides. Do not submit geosmooth before those checks succeed.

## Validation

The source tarball was built and checked on 2026-09-15 with
`R_LIBS=/tmp/geosmooth-pinned-dependency/library make check`, invoking
`R CMD check geosmooth_0.2.0.tar.gz --as-cran`.

* Environment: macOS 26.6.1, aarch64-apple-darwin23, R-devel
  (2026-06-24 r90190).
* Result: 0 errors, 0 warnings, 1 NOTE: “Days since last update: 3.”
* 11,248 assertions passed with no test warnings. The source-only runner test,
  excluded from source tarballs, passed separately in the checkout.
* Installation, code/documentation and S3 consistency, examples, both rebuilt
  vignettes, and PDF/HTML manual checks passed. A final documentation-only check
  and focused accessor checks cover the subsequent wording and harmonic-accessor
  example clarification.
* Read-only documentation checks resolve help for all 60 exports and 95 S3
  registrations, find both installed vignettes with embedded labeled figures,
  and check internal links across 178 generated website HTML pages. Negative
  fixtures verify detection of missing catalog/help entries and a stale appendix.
* Numerical tests use independent dual bounds, known zero-objective solutions,
  and an independent residual-operator calculation. A private 10,000-replicate
  calibration assessed LPS variance and pointwise coverage under constant,
  affine, and curved signals; the help retains the observed bias limitations.

A separate isolated `R CMD check --no-manual` against dgraphs ea745a0
completed with Status: OK and 11,231 assertions passed, no warnings, and five
source-only skips (the checkout was not discoverable from its temporary check
location). Its examples and vignette rebuilds passed. The main check above and
separate source-runner test cover those source-only checks.

This is development-dependency validation, not CRAN-only release validation.
Final platform checks using released dependencies are still required. The
development-dependency matrix for f7db6c3 (GitHub Actions run 35034345110)
passed on Linux release/oldrel-1, Windows release and macOS Intel release:
each reported Status: OK and 11,250 assertions passed, no test warnings, and
one source-only skip. Current R-devel stopped during the synthetic vignette
rebuild on the dependency RNG-state issue above, before running package tests.
The subsequent change in 67452ab only corrects a README mathematical label;
its website deployment passed and the public result was inspected. Package
code and tests are unchanged from the checked revision.

No reverse Depends, Imports, LinkingTo, or Suggests dependencies were listed
for geosmooth in the CRAN source index refreshed on 2026-09-15. Refresh this
again immediately before submission. Retain the short-release-interval NOTE
and assess submission timing after the dependency release; this draft does
not assert maintainer or CRAN approval.

## Previous review fixes retained

The package retains the method references and return-value documentation
requested during the initial review, executable examples for exported functions
and registered methods, and contributor/copyright-holder attribution for ANN,
Eigen, and Spectra. Their notices remain in inst/COPYRIGHTS and inst/licenses.
The earlier compiler-warning suppression remains removed. Source-layout tests
use the shared source-tree locator and skip source-only assertions when the
necessary development files are not included in the tarball.
