## Resubmission

This resubmission of geosmooth 0.2.0 addresses the reported 14-minute Windows
check time, above the 10-minute limit.

The PCA/PLS vignette uses precomputed results with complete reproduction code.
All five repetitions for each of five examples, 200 result rows and five
illustration datasets are preserved and match the original computation.
Geometry examples and probability slices still execute during vignette builds.

Tests use smaller synthetic examples and shared recipe, component and instance
setup. All 846 legacy parity cases, fixed regression fixtures and numerical
tolerances are retained. No numerical implementation or exported interface
changed for this resubmission.

## Checks of the revised archive

- macOS arm64, R-devel (2026-06-24 r90190), CRAN-only dependencies and one thread:
  0 errors, 0 warnings, 0 notes; full check elapsed 244.92 seconds.
- Win-builder R-devel (2026-11-07 r90850), Windows x86_64:
  0 errors, 0 warnings, 0 notes; check time 503 seconds (8 minutes 23 seconds).
- Win-builder R-release 4.6.2 (2026-10-29 ucrt), Windows x86_64:
  0 errors, 0 warnings, 0 notes; check time 488 seconds (8 minutes 8 seconds).

Both Windows checks include tests, vignette rebuilding and the manual.
