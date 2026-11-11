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

## Test environment

macOS ARM64, R-devel (2026-06-24 r90190), released CRAN dependencies,
clean user Makevars and one numerical thread:
0 errors, 0 warnings, 1 NOTE.

The freshly built source tarball was checked with R CMD check --as-cran.
All 9,810 assertions passed, with two expected skips for a source-only runner
and the two-process comparison under the single-core check setting.
Examples, vignette rebuilding, compiled-code checks and PDF/HTML manuals passed.

## Note

"Days since last update: 1". This update addresses the CRAN correction request
of 2026-11-11, which asks for correction before 2026-12-02.
