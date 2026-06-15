# K5 Handoff: Native Local-PCA LPS Validation

Generated: 2026-06-04 18:26:17 EDT

## Purpose

K5 is a broader validation phase for the explicit opt-in native
`fit.lps(..., coordinate.method = "local.pca", backend =
"cpp.local.pca")` path. It does not change package defaults.

The validation script loads the checked-out source tree with
`pkgload::load_all(project.dir, quiet = TRUE)` so the report validates
the local implementation rather than an installed `geosmooth` build.

## Outputs

- HTML report: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/k5_lps_native_validation.html`
- Case results CSV: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/tables/k5_lps_native_validation_results.csv`
- Summary CSV: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/tables/k5_lps_native_validation_summary.csv`
- Candidate-difference CSV: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/tables/k5_lps_native_validation_candidate_diffs.csv`
- Warning-detail CSV: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/tables/k5_lps_native_validation_warning_candidate_diffs.csv`

## Validation Matrix

The suite covers adversarial and realistic cases:

- exact 1D line embedded in 3D;
- exact 2D plane embedded in 3D;
- duplicated/tied local supports;
- helix with `chart.dim = "auto"`;
- curved paraboloid and saddle surfaces;
- high-dimensional diagonal 2D embedding with `chart.dim = "auto"`;
- VALENCIA-derived Li/Bv homogeneous embeddings.

## Results

- Cases run: `9`.
- Successful fits: `9`.
- Strict candidate-CV parity passes: `8`.
- Strict candidate-CV warnings: `1`.
- Selected-output parity passes: `9`.
- Selected-output parity failures: `0`.
- Maximum absolute CV RMSE difference: `0.0013192`.
- Maximum relative CV RMSE difference: `0.0077545`.
- Maximum absolute fitted-value difference: `3.7748e-15`.
- Maximum absolute prediction difference: `3.5527e-15`.
- Median R/native elapsed-time speedup: `0.95726`.

## Interpretation

The native local-PCA backend preserves selected candidates, fitted values,
and predictions on this K5 suite under the explicit opt-in contract. One
exact-plane stress case has a non-selected degree-1 Gaussian candidate-CV
difference above the strict candidate-table tolerance. This should be
diagnosed before promotion beyond explicit opt-in.

The warning-detail CSV archives every strict-tolerance candidate mismatch
with candidate metadata and R/native CV values. In this run the warning
candidates are non-selected exact-plane degree-1 Gaussian candidates; the
selected candidate and selected-output predictions still match at numerical
precision.

## Recommended Next Step

K5.1 should diagnose the remaining exact-plane non-selected Gaussian
degree-1 candidate-CV drift before any default-backend promotion. K5.1
does not need to block continued explicit opt-in use, but it should be
audited before this backend is used as a strict full-CV-table replacement.
