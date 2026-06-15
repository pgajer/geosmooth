# K4.1 Audit Response: Native Local-PCA LPS Chart Cache

Generated: 2026-06-04 17:49:02 EDT

## Audit Addressed

- Audit: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k4_1_lps_local_pca_chart_cache_audit_2026-06-04.md`
- Revised handoff: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k4_1_lps_local_pca_chart_cache_handoff_2026-06-04.md`
- Revised benchmark report: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k4_1_lps_local_pca_chart_cache_2026-06-04/k4_1_lps_local_pca_chart_cache.html`
- Revised benchmark CSV: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k4_1_lps_local_pca_chart_cache_2026-06-04/k4_1_lps_local_pca_chart_cache_results.csv`

## Changes Made

The audit correctly identified that K4.1 still inherited an unresolved K4
native/R parity issue in singular, tied, or ill-conditioned local polynomial
designs.

The native weighted local-polynomial solve in
`src/kernel_local_polynomial_cv_rcpp.cpp` now uses this order:

1. A rank-aware Eigen column-pivoted QR solve with tolerance `1e-7`.
2. If the QR solve is rank-deficient or non-finite, an R-compatible fallback
   through `stats::lm.wfit()`.
3. If both fail, the existing SPD normal-equation solve is retained as a final
   numeric fallback before falling back to the weighted mean.

This keeps the fast native path for ordinary full-rank local designs while
matching the R reference path on the rank-deficient cases that determine the
auditor's parity tests.

## Audit Finding Responses

### P1: Focused K4 parity test still fails

Resolved.

The exact command from the audit now passes:

```sh
Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet = TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R", reporter = "summary")'
```

Result: `test-ge7-lps-api.R` passed all 40 checks.

Additional adversarial probes also passed:

- exact plane grid, degree 2:
  max absolute CV difference `5.25739518209e-16`;
- duplicated/tied rows:
  max absolute CV difference `3.05311331772e-16`;
- exact line:
  max absolute CV difference `1.63064006742e-16`;
- `chart.dim = "auto"`:
  max absolute CV difference `1.08767161944e-15`.

All four probes selected the same candidate and matched fitted values to
machine precision.

### P2: K4.1 benchmark inherits unresolved K4 parity risk

Resolved for the benchmarked cases.

After the solver patch, the K4.1 benchmark was regenerated. The maximum
absolute CV RMSE difference versus the R reference is now `4.198e-09`, down
from the audited `0.020683`. The maximum relative CV RMSE difference is
`4.2395e-11`, and the maximum absolute fitted-value difference is
`4.2188e-15`. The R and native paths selected identical candidates in all four
benchmark cases.

The measured speedup is slightly smaller because the native path now avoids the
less stable normal-equation-first solve:

- median R / cached-C++ speedup: `7.6167`;
- median cached-C++ / prior-K4-C++ speedup: `1.0917`.

The cache still gives the intended chart-build reuse factor of `4` on this
benchmark grid.

## Validation

- `R CMD INSTALL --preclean /Users/pgajer/current_projects/geosmooth`: passed.
- Focused `test-ge7-lps-api.R`: passed.
- Focused `test-ge1-r-smoothers.R`: passed.
- Adversarial parity probes: passed.
- `Rscript scripts/k4_1_lps_local_pca_chart_cache_benchmark.R`: passed and
  regenerated the CSV, HTML, and handoff.
- `make test`: passed with 878 passing checks, 9 expected split-era skips, and
  no failures or warnings.

## Recommended Next Step

Request K4.1 re-audit. If accepted, proceed to K5 broader native LPS validation
covering equivalence, stress cases, and performance on larger local-PCA LPS
workloads.
