# K5.1 Handoff: Exact-Plane Candidate-CV Warning Diagnostic

Generated: 2026-06-04 18:55:00 EDT

## Purpose

K5.1 addresses the K5 audit request to archive warning-case candidate details and diagnose the remaining exact-plane candidate-CV drift before any `backend = "auto"` promotion or strict full-CV-table replacement claim.

This phase does not change package defaults or smoother behavior.

## Files Changed

- `/Users/pgajer/current_projects/geosmooth/scripts/k5_lps_native_validation.R`
- `/Users/pgajer/current_projects/geosmooth/scripts/k5_1_lps_native_warning_diagnostic.R`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_handoff_2026-06-04.md`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/k5_lps_native_validation.html`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/k5_1_exact_plane_warning_diagnostic.html`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/tables/k5_lps_native_validation_results.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/tables/k5_lps_native_validation_summary.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/tables/k5_lps_native_validation_candidate_diffs.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/tables/k5_lps_native_validation_warning_candidate_diffs.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/tables/k5_1_exact_plane_warning_target_diagnostics.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/tables/k5_1_exact_plane_warning_diagnostic_summary.csv`

## Audit Comment Responses

### Candidate-table warning details are now archived

The K5 validation script now writes:

- full candidate-difference table:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/tables/k5_lps_native_validation_candidate_diffs.csv`
- strict warning-only table:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/tables/k5_lps_native_validation_warning_candidate_diffs.csv`

The warning-only table records:

- `case.id`
- `support.size`
- `degree`
- `kernel`
- `chart.dim`
- R CV RMSE
- native C++ CV RMSE
- absolute difference
- relative difference

The K5 HTML report now includes a visible "Strict Candidate-CV Warning Details" section.

### K5 now validates the checked-out source tree

The K5 validation script now loads local source with:

```r
pkgload::load_all(project.dir, quiet = TRUE)
```

This avoids accidental validation of an installed `geosmooth` build.

### Exact-plane warning was diagnosed

The K5.1 diagnostic decomposes the two strict warning candidates into held-out target predictions and checks native tie-complete supports against the R distance/order reference.

Diagnostic outputs:

- HTML:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/k5_1_exact_plane_warning_diagnostic.html`
- target-level CSV:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/tables/k5_1_exact_plane_warning_target_diagnostics.csv`
- summary CSV:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/tables/k5_1_exact_plane_warning_diagnostic_summary.csv`

Summary:

| support.size | degree | kernel | targets | support mismatches | R CV RMSE | C++ CV RMSE | max abs target pred diff |
|---:|---:|---|---:|---:|---:|---:|---:|
| 10 | 1 | gaussian | 49 | 0 | 0.1701263 | 0.1714455 | 0.0793421 |
| 14 | 1 | gaussian | 49 | 0 | 0.2300301 | 0.2289378 | 0.0409030 |

The weighted local design condition numbers are modest in the warning rows, with maximum condition values around `5.3`. Therefore the warning is not explained by ANN/tie support mismatch and is not an obvious ill-conditioning failure. It is best classified as a sparse target-level R/native weighted-linear-solve/local-chart numerical mismatch on an exact-plane stress case.

## Current Decision

K5 remains accepted for explicit opt-in validation:

```r
fit.lps(..., coordinate.method = "local.pca", backend = "cpp.local.pca")
```

The native local-PCA backend should still not be promoted into `backend = "auto"` and should not be claimed as a strict full-CV-table replacement for the R backend until the exact-plane degree-1 Gaussian mismatch is either eliminated or explicitly accepted as a documented numerical difference.

Selected-output parity remains clean across the K5 suite.

## Validation Commands

Run from `/Users/pgajer/current_projects/geosmooth`:

```sh
Rscript scripts/k5_lps_native_validation.R
Rscript scripts/k5_1_lps_native_warning_diagnostic.R
git diff --check
```

Focused package tests should also be rerun before audit:

```sh
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-ge7-lps-api.R", reporter = "summary")'
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-ge1-r-smoothers.R", reporter = "summary")'
```

## Recommended Next Step

Request audit of K5.1. If accepted, proceed to **K6 only as explicit opt-in prospective-script integration**, not default promotion.

The K6 task should:

1. keep `backend = "auto"` unchanged;
2. add an explicit prospective-run option for `fit.lps(..., backend = "cpp.local.pca")`;
3. record backend used in every LPS result artifact;
4. keep the R backend as the reference path for any strict CV-table equivalence claim;
5. include a warning in K6 handoff that exact-plane degree-1 Gaussian candidate-table parity is not yet exact.

If default promotion is desired later, create a separate K6.1 or K7 task that specifically resolves the remaining weighted-linear-solve/local-chart numerical mismatch.
