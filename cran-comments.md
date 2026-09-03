## Resubmission

This is the second resubmission of the initial CRAN release of `geosmooth`.

CRAN review on 2026-08-31 requested method references in `DESCRIPTION`, a
missing return-value description for `fit.subject.od()`, executable examples
instead of `\\dontrun{}`, and complete contributor and copyright-holder roles
in `Authors@R`. We made the following changes:

* Added references for the package's geometric-regression, local-polynomial,
  graph-trend-filtering, and Hessian-energy methods to `DESCRIPTION` and the
  corresponding function help pages.
* Documented the class, structure, and interpretation of the value returned by
  `fit.subject.od()`.
* Replaced all four `\\dontrun{}` blocks with short, self-contained examples
  that run during `R CMD check`.
* Added the contributors and copyright holders of the vendored Eigen, Spectra,
  and ANN libraries to `Authors@R` with `ctb` and/or `cph` roles. The upstream
  notices and license details remain in `inst/COPYRIGHTS` and `inst/licenses`.

An internal CRAN-submission checklist audit on 2026-09-03 identified several
release-readiness issues before any duplicate upload was made. We made the
following additional cleanup changes:

* Removed a forced-included Eigen configuration header that suppressed a GCC
  diagnostic; the package now checks without compiler-warning suppression.
* Moved agent-only audits, handoffs, prompts, work orders, and intermediate
  review products out of the public package repository and into the local
  private Codex notes tree.
* Retired stale development-phase DGP registry material from `inst/` into the
  non-shipped development archive, leaving the shipped synthetic registry as
  the canonical dataset registry.
* Added Rd entries and executable examples for registered S3 methods, removed
  unexplained development-phase labels from user-facing help, and strengthened
  the source-tree guardrail used by package QA tests.

The automated CRAN incoming pretests on 2026-08-21 reported test errors on
Windows and Debian. Two source-layout tests searched upward from the process
working directory and stopped when the package source root was unavailable.
They now use a shared source-tree locator based on `testthat::test_path()` and
skip their source-only assertions when no source tree is present. Both tests
still run and pass in a source checkout. No package behavior was changed by
this fix.

## Submission

`geosmooth` imports `dgraphs (>= 0.1.0)`. On 2026-08-19, the CRAN submission
team confirmed that version 0.1.0 of `dgraphs` was on its way to CRAN. Version
0.1.0 was present in the CRAN source index on 2026-08-20 and was installed from
a CRAN mirror into a new library for the local release check. The external
checks below also resolved the dependency from their standard repositories.

## Test environments

* local: macOS 26.6.1, aarch64-apple-darwin23, R-devel (2026-06-24 r90190)
* initial-candidate GitHub Actions: Ubuntu with R-release, R-devel, and
  R-oldrel; macOS Intel with R-release; Windows with R-release
  (https://github.com/pgajer/geosmooth/actions/runs/32424082905)
* initial-candidate R-hub: Linux with R-devel and Windows with R-devel
  (https://github.com/r-hub2/useful-whitefish-geosmooth/actions/runs/32424539662)

The initial-candidate GitHub Actions matrix and both R-hub jobs reported
`Status: OK`. The subsequent CRAN pretests identified only the two
installed-test path errors described above.

## Local R CMD check results

The exact source tarball was checked locally with `R CMD check --as-cran`:

* 0 errors | 0 warnings | 1 expected note (`New submission`)
* 10,872 tests passed, one source-tree-only runner test was intentionally
  skipped, and no tests failed or warned

The acceptance and scientific-validation suites are intentionally excluded
from installed-package CRAN checks because they are substantially more
expensive than package QA. They remain available through the package's opt-in
development targets. The complete `make test-all` suite also passed locally
with only intentional dependency/platform skips.

## Notes

The package includes vendored ANN, Eigen, and Spectra headers. Their copyright
and license information is recorded in `inst/COPYRIGHTS` and `inst/licenses`.
