# K5 Audit: Native Local-PCA LPS Validation

Generated: 2026-06-04

## Scope

Audited `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_handoff_2026-06-04.md` and the generated validation artifacts under `/Users/pgajer/current_projects/geosmooth/split_handoffs/k5_lps_native_validation_2026-06-04/`.

K5 is treated as a validation gate for the explicit opt-in `fit.lps(..., coordinate.method = "local.pca", backend = "cpp.local.pca")` backend. It is not a default-backend promotion gate.

## Decision

Accepted for the explicit opt-in K5 validation handoff.

Do not promote the native local-PCA backend into `backend = "auto"` or treat it as a full candidate-table drop-in replacement until K5.1 resolves or formally explains the remaining exact-plane candidate-CV drift.

## Findings

### P1: Candidate-table parity is not clean on the exact-plane stress case

The handoff reports one strict candidate-CV warning, with max absolute CV RMSE difference `0.0013192` and max relative difference `0.0077545`. The HTML report identifies the affected case as `exact_plane_2d`, while selected-output parity remains true.

An independent rerun of the exact-plane case reproduced the drift. The largest mismatches are:

| support.size | degree | kernel | R CV RMSE | C++ CV RMSE | abs diff | rel diff |
|---:|---:|---|---:|---:|---:|---:|
| 10 | 1 | gaussian | 0.1701262748435049 | 0.1714455140258026 | 0.0013192391822977 | 0.0077544705161576 |
| 14 | 1 | gaussian | 0.2300300775841360 | 0.2289377574441653 | 0.0010923201399707 | 0.0047485970158453 |

The selected candidate is still identical in both backends: `support.size=10; degree=2; kernel=gaussian; chart.dim=2`, with fitted and prediction differences at numerical precision. This is therefore not a blocker for accepting K5 as an explicit opt-in validation report, but it is a blocker for promotion beyond explicit opt-in and for using the native backend as a strict full-CV-table replacement.

### P2: Warning-case candidate details are not archived in the report artifacts

The generated CSV and HTML preserve per-case maxima and selected candidates, but they do not archive the per-candidate R/C++ CV table differences for warning cases. The handoff correctly states that the issue is a non-selected degree-1 Gaussian exact-plane candidate, but that claim currently requires regenerating the fits or running an external probe.

K5.1 should add a warning-detail CSV and corresponding HTML section containing at least `case.id`, `support.size`, `degree`, `kernel`, `chart.dim`, R CV RMSE, C++ CV RMSE, absolute difference, and relative difference for any candidate exceeding the strict tolerance.

## Non-Blocking Notes

- The K5 validation matrix is appropriate for this phase: exact line, exact plane, tied supports, curved 2D surfaces, auto chart dimension, high-dimensional embedding, and VALENCIA-derived embeddings.
- The report correctly preserves the explicit opt-in contract and states that package defaults are unchanged.
- The exact-line case has a relative CV difference around `1.04e-08`, but the absolute difference is `1.56e-16`; this is harmless denominator inflation near zero and passes the strict absolute gate.

## Verification

Commands run from `/Users/pgajer/current_projects/geosmooth`:

- `Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R", reporter="summary")'`
- `Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge1-r-smoothers.R", reporter="summary")'`
- `make test`
- `git diff --check`
- Independent exact-plane candidate-difference probe comparing `backend = "R"` and `backend = "cpp.local.pca"`.

Results:

- `test-ge7-lps-api.R`: passed.
- `test-ge1-r-smoothers.R`: passed.
- `make test`: passed with `878` passes, `9` existing gflow-parity skips, `0` failures, and `0` warnings.
- `git diff --check`: passed.

## Required Next Step

Proceed to K5.1 before K6/default promotion work: diagnose the exact-plane degree-1 Gaussian candidate-CV drift, decide whether it is acceptable conditioning/tie behavior or a remaining R/native support/solve mismatch, and archive warning-case candidate details in the validation report.
