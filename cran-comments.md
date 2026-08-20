## Submission

This is the initial CRAN submission of `geosmooth`.

`geosmooth` imports `dgraphs (>= 0.1.0)`. On 2026-08-19, the CRAN submission
team confirmed that version 0.1.0 of `dgraphs` was on its way to CRAN. Version
0.1.0 was present in the CRAN source index on 2026-08-20 and was installed from
a CRAN mirror into a new library for the local release check. The external
checks below also resolved the dependency from their standard repositories.

## Test environments

* local: macOS 26.6.1, aarch64-apple-darwin23, R-devel (2026-06-24 r90190)
* GitHub Actions: Ubuntu with R-release, R-devel, and R-oldrel; macOS Intel
  with R-release; Windows with R-release
  (https://github.com/pgajer/geosmooth/actions/runs/32424082905)
* R-hub: Linux with R-devel and Windows with R-devel
  (https://github.com/r-hub2/useful-whitefish-geosmooth/actions/runs/32424539662)

The GitHub Actions matrix and both R-hub jobs reported `Status: OK`.
Win-builder was unavailable when checked on 2026-08-20: repeated HTTPS
connections to the upload service timed out before a job could be created.

## Local R CMD check results

The exact source tarball was checked locally with `R CMD check --as-cran`:

* 0 errors | 0 warnings | 0 notes (`Status: OK`)
* 11,140 tests passed, one source-tree-only runner test was intentionally
  skipped, and no tests failed or warned

The acceptance and scientific-validation suites are intentionally excluded
from installed-package CRAN checks because they are substantially more
expensive than package QA. They remain available through the package's opt-in
development targets. The complete `make test-all` suite also passed locally
with only intentional dependency/platform skips.

## Notes

The package includes vendored ANN, Eigen, and Spectra headers. Their copyright
and license information is recorded in `inst/COPYRIGHTS` and `inst/licenses`.
