Resubmission of geosmooth 0.2.1 addressing Windows checktime. Windows tests
use at most two workers, share setup and group comparisons; all reference
cases and tolerances are retained. The fixes for constant covariates and
predict/tail imports remain.

Full Windows R-devel (2026-11-11 r90876) check: 373 seconds, 0 errors,
0 warnings, 1 NOTE. Full macOS ARM64 check passed. Notes on the short update
interval reflect CRAN's correction request. BLIS and Linux ARM64 checks
have 0 errors/warnings and three container notes each: compiler flags,
stripped symbol inspection and optional V8.
