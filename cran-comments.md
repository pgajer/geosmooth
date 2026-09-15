## Update to geosmooth 0.2.0

This is an update to geosmooth 0.1.0. It consolidates the public API and adds
an installed HTML function-guide vignette. The statistical estimators and
method-specific refit behavior are preserved.

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

This document is a preparation draft, not confirmation that the package is
ready to submit. DESCRIPTION currently requires `dgraphs (>= 0.2.1.9000)`.
On 2026-09-14 the CRAN source index provided dgraphs 0.2.0, which lacks the
required geometry and sampling imports.

A compatible dgraphs release must be available from CRAN before this update
is submitted. Version 0.3.0 is the proposed dgraphs release, subject to its
maintainer's release decision. Once it is published, update DESCRIPTION to
require the released version and repeat the final checks using repository
packages. A successful check with development dgraphs does not establish
CRAN-only dependency availability.

## Validation

The version 0.2.0 tarball was built and checked locally on 2026-09-14 using
`R_LIBS=/tmp/geosmooth-api-consolidation/library make check`, which invokes
`R CMD check geosmooth_0.2.0.tar.gz --as-cran`.

* Environment: macOS 26.6.1, aarch64-apple-darwin23, R-devel
  (2026-06-24 r90190).
* Dependency: dgraphs 0.2.1.9000 installed from the sibling development source
  into an isolated temporary library, not installed from CRAN.
* Result: 0 errors, 0 warnings, 1 NOTE. The incoming-feasibility note reports
  that only two days have passed since the last CRAN update. The previous
  insufficient-version warning is resolved by the increase to 0.2.0.
* 10,963 assertions passed, with no test failures or test warnings. The single
  source-only runner test skipped in the tarball passed separately in the
  source checkout; the exported-function/S3-method example-coverage test also
  passed there.
* Installation, S3 registration, code/documentation consistency, examples,
  vignette rebuilds, and both PDF and HTML manual checks passed. Both HTML
  vignettes appear in the installed documentation.

This validates the candidate with the development dependency only. It does
not replace final checks against released dgraphs on the supported platforms.
Plan the submission timing deliberately: the two-day interval should not be
presented as an urgent corrective release without an actual urgent issue.

Earlier numerical comparisons for the API consolidation agreed with the
previous implementations in 16 refit/matrix scenarios and seven quadratic
Hessian fitter scenarios, excluding calls and measured runtimes as appropriate.

The GitHub Actions run for the preceding code commit stopped at dependency
installation on Linux and Windows because dgraphs >= 0.2.1.9000 was unavailable:
https://github.com/pgajer/geosmooth/actions/runs/34876555004
Those failures did not exercise the package tests. Fresh Linux, Windows, and
macOS checks of the final release candidate using released dependencies are
still required; older successful platform checks are not validation of 0.2.0.

No reverse Depends, Imports, LinkingTo, or Suggests dependencies on geosmooth
were listed in the CRAN source index queried on 2026-09-14. Refresh that check
before submission and check affected downstream packages if any appear.

## Previous review fixes retained

The package retains the method references and return-value documentation
requested during the initial review, executable examples for exported functions
and registered methods, and contributor/copyright-holder attribution for ANN,
Eigen, and Spectra. Their notices remain in inst/COPYRIGHTS and inst/licenses.
The earlier compiler-warning suppression remains removed. Source-layout tests
use the shared source-tree locator and skip source-only assertions when the
necessary development files are not included in the tarball.
