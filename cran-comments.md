## Submission

This is the initial CRAN submission of `geosmooth`.

`geosmooth` imports `dgraphs (>= 0.1.0)`. On 2026-08-19, the CRAN submission
team confirmed that version 0.1.0 of `dgraphs` was on its way to CRAN. Version
0.1.0 was present in the CRAN source index on 2026-08-20 and was installed from
a CRAN mirror into a new library for the local release check. Platform binary
availability will be confirmed by the external checks below.

## Test environments

* local: macOS 26.6.1, aarch64-apple-darwin23, R-devel (2026-06-24 r90190)
* GitHub Actions: Ubuntu, macOS, and Windows with R-release; Ubuntu with
  R-devel and R-oldrel (pending)
* win-builder: R-devel (pending)
* R-hub: Linux and an additional non-Linux platform (pending)

## Local R CMD check results

The exact source tarball was checked locally with `R CMD check --as-cran`:

* 0 errors | 0 warnings | 2 notes
* 12,298 tests passed, 4 tests were intentionally skipped, and no tests warned

The first note records that this is a new submission. The second reports that
the local HTML Tidy installation is too old for HTML-manual validation; the
HTML manual was nevertheless built successfully. External check results will
be added before submission.

## Notes

The package includes vendored ANN, Eigen, and Spectra headers. Their copyright
and license information is recorded in `inst/COPYRIGHTS` and `inst/licenses`.
