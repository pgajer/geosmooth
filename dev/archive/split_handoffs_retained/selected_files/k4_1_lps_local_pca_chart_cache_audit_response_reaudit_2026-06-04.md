# K4.1 Re-Audit: Audit Response

Generated: 2026-06-04 17:55:27 EDT

## Scope

Re-audited
`split_handoffs/k4_1_lps_local_pca_chart_cache_audit_response_2026-06-04.md`
against the K4.1 audit findings in
`split_handoffs/k4_1_lps_local_pca_chart_cache_audit_2026-06-04.md`.

Reviewed current artifacts:

- `split_handoffs/k4_1_lps_local_pca_chart_cache_audit_response_2026-06-04.md`
- `split_handoffs/k4_1_lps_local_pca_chart_cache_handoff_2026-06-04.md`
- `split_handoffs/k4_1_lps_local_pca_chart_cache_2026-06-04/k4_1_lps_local_pca_chart_cache_results.csv`
- `src/kernel_local_polynomial_cv_rcpp.cpp`
- `tests/testthat/test-ge7-lps-api.R`
- `tests/testthat/test-ge1-r-smoothers.R`

## Decision

Accepted with one non-blocking documentation correction. The substantive K4.1
audit blockers are resolved, and K4.1 remains appropriately scoped as explicit
opt-in via `backend = "cpp.local.pca"`.

## Resolved Findings

### P1: Focused K4 parity test failure

Resolved. The focused test now passes.

Verification rerun:

- `test-ge7-lps-api.R`: passed all 40 checks.
- Exact line, chart dimension 2, degree 2:
  max CV RMSE difference `7.344726e-18`.
- Exact plane, chart dimension 2, degree 2:
  max CV RMSE difference `6.938894e-18`.
- Duplicated/tied supports:
  max CV RMSE difference `5.551115e-17`.
- `chart.dim = "auto"` random case:
  max CV RMSE difference `3.799044e-16`.

The selected support, degree, kernel, and chart dimension matched in the
adversarial cases.

### P2: Benchmark inherited unresolved parity risk

Resolved for the K4.1 benchmarked cases. The regenerated CSV reports:

- maximum absolute CV RMSE difference `4.198014e-09`;
- maximum relative CV RMSE difference `4.239539e-11`;
- maximum absolute fitted-value difference `4.218847e-15`;
- identical selected candidates in all four benchmark cases.

## Non-Blocking Documentation Issue

The audit response text has stale speedup medians:

- It reports median R / cached-C++ speedup `8.0484`, while the current CSV and
  refreshed handoff imply `7.6167`.
- It reports median cached-C++ / prior-K4-C++ speedup `1.0739`, while the
  current CSV and refreshed handoff imply `1.0917`.

This does not affect the acceptance decision because the parity/fitted-value
claims are correct and the handoff has the current speedup numbers. The audit
response should be updated for consistency before final archival or human
review.

## Verification Run During Re-Audit

- `Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet = TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R", reporter = "summary")'`
- `Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet = TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge1-r-smoothers.R", reporter = "summary")'`
- Manual adversarial parity probes for exact line, exact plane, duplicated
  supports, and `chart.dim = "auto"`.
- `make test`: passed with `[ FAIL 0 | WARN 0 | SKIP 9 | PASS 878 ]`.
- `git diff --check`: passed.

## Recommended Next Step

Update the two stale speedup numbers in the response text if that document will
be retained as an archival handoff artifact, then proceed to K5 broader native
LPS validation.
