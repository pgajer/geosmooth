## Update to geosmooth 0.2.1

This updates the published geosmooth 0.2.0. It corrects the constant-covariate
validation failure identified in the CRAN notification of 2026-11-11:
exactly constant columns are rejected before weighted centering, independently
of BLAS rounding. It also declares the stats::predict() and utils::tail()
imports used by trend-filtering helpers.

The update includes projection-pursuit trend filtering for Gaussian and
binomial responses, with fixed or learned projections and cross-validation,
and refreshed function documentation and vignettes. The PCA/PLS comparison
uses stored results with their complete reproduction script; all 200 result
rows and five illustration datasets match the previous computation.
Its source is preserved with LF line endings across Git checkouts so that
Windows builds retain the exact stored-result checksum.

## Test environments

GitHub Actions checks of the final package source:

- Linux x86-64, R-devel (2026-11-10 r90874): 0 errors, 0 warnings, 0 notes.
- Linux x86-64, R 4.6.2 (2026-10-29): 0 errors, 0 warnings, 0 notes.
- Linux x86-64, R 4.5.3 (2026-03-11): 0 errors, 0 warnings, 0 notes.
- macOS Intel, R 4.6.2 (2026-10-29): 0 errors, 0 warnings, 0 notes.
- Windows x86-64 UCRT, R 4.6.2 (2026-10-29): 0 errors, 0 warnings, 0 notes.

These CI checks built and checked source tarballs with --as-cran --no-manual.
They included examples, tests and vignette rebuilding; CRAN incoming queries
were disabled in CI. Linux and macOS passed 10,150 assertions, with one
source-only skip. Windows passed 10,149 assertions, with the additional
expected skip of the Unix-only parallelism comparison.

The exact upload archive also passed a full local R CMD check --as-cran on
macOS ARM64, R-devel (2026-06-24 r90190), with released CRAN dependencies,
clean user Makevars and one numerical thread: 0 errors, 0 warnings, 1 NOTE.
It passed 10,149 assertions, with two expected skips for the source-only runner
and the two-process comparison under the single-core setting. Compiled-code
checks, examples, rebuilt vignettes and PDF/HTML manuals passed.

The CRAN-only dependency gate passed. No reverse dependencies were listed in
the CRAN source index on 2026-11-11.

## Note

The local NOTE is "Days since last update: 1". This update addresses the CRAN
correction request of 2026-11-11, which asks for correction before 2026-12-02.
