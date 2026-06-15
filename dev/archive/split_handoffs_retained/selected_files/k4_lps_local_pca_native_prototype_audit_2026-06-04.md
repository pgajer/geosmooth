# K4 Audit: Native Local-PCA LPS Backend Prototype

Generated: 2026-06-04 14:33:23 EDT

## Scope

Audited the K4 implementation and handoff for the explicit
`fit.lps(..., coordinate.method = "local.pca", local.chart.method = "pca",
backend = "cpp.local.pca")` native prototype.

Reviewed artifacts:

- `split_handoffs/k4_lps_local_pca_native_prototype_handoff_2026-06-04.md`
- `split_handoffs/k4_lps_local_pca_native_prototype_2026-06-04/k4_lps_local_pca_native_prototype.html`
- `split_handoffs/k4_lps_local_pca_native_prototype_2026-06-04/k4_lps_local_pca_native_prototype_results.csv`
- `scripts/k4_lps_local_pca_native_prototype.R`
- `R/kernel_local_polynomial_cv.R`
- `src/kernel_local_polynomial_cv_rcpp.cpp`
- `tests/testthat/test-ge7-lps-api.R`
- `tests/testthat/test-ge1-r-smoothers.R`

## Decision

K4 is acceptable as an explicit native prototype backend. It should not be
promoted to `backend = "auto"` until the tie-neighborhood parity issue below is
resolved or the contract explicitly excludes exact ties/symmetric supports from
strict candidate-selection parity.

## Findings

### P1: CV candidate selection can diverge on exact ties or symmetric supports

The R reference path stabilizes nearest-neighbor ties with row order through
`order(d, seq_along(d))`. The native local-PCA path uses ANN search output
directly and does not apply the same secondary row-order tie break before
forming supports. This means candidate CV RMSEs and selected candidates can
diverge on exact grids, duplicated rows, or other symmetric neighborhoods.

Observed adversarial checks:

- Exact 2D plane grid in 3D, degree 2, support sizes 10 and 12:
  max absolute CV RMSE difference `0.3766418`; selected kernel changed.
- Duplicated/tied 2D point cloud:
  max absolute CV RMSE difference `0.09282758`; selected support changed from
  `6` to `8`.
- Random no-tie local-PCA examples remained tight, with CV differences around
  numerical noise.

Relevant code:

- R tie-stable ordering: `R/kernel_local_polynomial_cv.R`, `.klp.local.order()`
  and prediction ordering use `order(d, seq_along(d))`.
- Native ordering: `src/kernel_local_polynomial_cv_rcpp.cpp` uses
  `AnnTree::search()` output directly for CV and prediction.
- Existing K4 parity test covers one smooth, non-tied curve-like example, so it
  does not exercise this failure mode.

Recommended fix before promotion:

- Sort ANN neighbor results by `(distance, original row index)` before slicing
  supports in both native CV and native prediction, or document that strict
  parity is only guaranteed when neighbor distances are unique.
- Add regression tests for a symmetric grid and duplicated-row case with
  candidate table and selected-candidate parity.

### P2: The report is too narrow for a promotion decision

The HTML report and CSV are useful for the K4 prototype claim, but they only
cover four VALENCIA-derived embedding cases with `support.grid = c(15, 25)`,
`degree.grid = 1:2`, `kernel.grid = c("gaussian", "tricube")`, and
`chart.dim = 2`. They do not include tied-neighborhood, exact-grid,
`chart.dim = "auto"`, duplicated-row, or low-rank support cases.

This is fine for a prototype benchmark, but insufficient evidence for changing
`backend = "auto"` or calling the native backend behavior-preserving across the
ordinary local-PCA LPS API.

## Positive Checks

- `backend = "auto"` remains unchanged for local-PCA and still resolves to the
  R reference path.
- The new `backend = "cpp.local.pca"` scope guard rejects ambient coordinates
  and `local.chart.method = "second.order.svd"`.
- The native backend reuses the shared C++ local-PCA chart constructor rather
  than creating a separate chart definition.
- Random no-tie local-PCA checks, including `chart.dim = "auto"`, matched the
  R path to numerical precision in this audit.
- Focused K4 `test-ge7-lps-api.R` passed.
- `git diff --check` passed.

## Verification Run During Audit

- `Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet = TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R", reporter = "summary")'`
- `git diff --check`
- Additional adversarial R/C++ parity probes for exact line, exact plane grid,
  duplicated/tied rows, random plane, random line, curved line, and
  `chart.dim = "auto"`.

## Recommended Next Step

Keep K4 as an opt-in prototype. Before K4.1 optimization or auto-backend
promotion, add tie-stable native neighbor ordering and regression tests for the
adversarial parity cases above.
