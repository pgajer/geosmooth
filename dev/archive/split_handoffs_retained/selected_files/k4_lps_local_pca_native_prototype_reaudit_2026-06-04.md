# K4 Re-Audit: Native Local-PCA LPS Backend Prototype Audit Response

Generated: 2026-06-04 15:09:34 EDT

## Scope

Re-audited
`split_handoffs/k4_lps_local_pca_native_prototype_audit_response_2026-06-04.md`
against the original K4 audit findings.

Reviewed current changes in:

- `R/kernel_local_polynomial_cv.R`
- `src/kernel_local_polynomial_cv_rcpp.cpp`
- `tests/testthat/test-ge7-lps-api.R`
- `split_handoffs/k4_lps_local_pca_native_prototype_audit_response_2026-06-04.md`

## Decision

Not accepted yet. The response makes the right first step, but P1 is not fully
resolved and the focused K4 regression test currently fails.

## Blocking Finding

### P1: Sorting the ANN-returned neighbor list does not fully match R tie-stable supports

The response sorts native ANN neighbor results by
`(distance, original row index)` after ANN search. This fixes ties only among
neighbors that ANN already returned. It does not fix ties at the kth-neighbor
boundary, where ANN may omit a lower-row tied point that the R reference path
would include after sorting all rows by `order(d, seq_along(d))`.

Observed during re-audit:

- The focused K4 test file fails:
  `testthat::test_file("tests/testthat/test-ge7-lps-api.R")`.
- Failure occurs in the new duplicated/tied support regression test:
  one candidate has native CV RMSE `0.209551790` versus R `0.200000000`.
- The original adversarial duplicated-row probe still shows a max absolute CV
  difference of `0.1326749`.
- The original exact plane grid probe still shows a max absolute CV difference
  of `0.2900137` and selected kernel mismatch.

This means the candidate CV table and selected candidate can still be backend
dependent on exact/symmetric/tied supports.

Recommended implementation fix:

- After ANN returns a provisional k-neighbor result, compute the kth squared
  distance.
- Scan the full training index set for rows with distance less than that kth
  value, plus all rows tied at that kth value under an explicit tolerance.
- Sort that recovered candidate set by `(distance, original row index)`.
- Slice the first k rows from this tie-complete sorted set.
- Apply the same helper in ambient CV, ambient prediction, local-PCA CV, and
  local-PCA prediction.

This preserves the ANN speed path when there is no boundary tie, while making
the exact-tie contract match the R reference path.

## Non-Blocking Notes

- The deterministic CV selection tolerance in `fit.lps()` is reasonable as a
  dust-level tie-breaker, but it cannot substitute for support parity. The
  observed duplicated-support failure is much larger than numerical dust.
- The QR fallback is directionally appropriate for singular local polynomial
  designs, but it should be validated after neighbor support parity is fixed.
- `backend = "auto"` still remains unchanged, which is correct.

## Verification Run During Re-Audit

- `Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet = TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R", reporter = "summary")'`
  failed in the new K4 tie-stable support test.
- `git diff --check` passed.
- Re-ran the original exact-line, exact-plane, duplicated-row, and
  `chart.dim = "auto"` parity probes.

## Required Follow-Up

Fix boundary-tie recovery in the native neighbor path, rerun the focused K4
tests, and re-run the original adversarial probes before requesting another
re-audit.
