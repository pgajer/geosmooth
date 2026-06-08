Build timestamp: 2026-06-07 21:17:59 EDT

Please audit the new principled binary-outcome LPS implementation.

## Scope

This handoff covers the addition of

```r
outcome.family = "binomial"
```

to `fit.lps()`.  The new mode fits local weighted logistic polynomial models
and uses observed CV log loss for candidate selection.  It is intentionally
separate from the previously implemented

```r
outcome.family = "bernoulli"
```

mode, which treats the binary response as a numeric conditional expectation,
clips fitted values to `[0, 1]`, and selects by Brier risk.

## Main files changed

- `/Users/pgajer/current_projects/geosmooth/R/lps.R`
- `/Users/pgajer/current_projects/geosmooth/man/fit.lps.Rd`
- `/Users/pgajer/current_projects/geosmooth/man/predict.lps.Rd`
- `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R`
- `/Users/pgajer/current_projects/geosmooth/scripts/run_lps_binary_outcome_smoke.R`

## Implementation summary

The binomial mode:

- validates that `y` contains only `0` and `1`;
- uses the R backend for now, including when `backend = "auto"`;
- fails explicitly for currently unsupported native backends;
- fits each local chart with weighted logistic IRLS;
- uses the existing guarded local-design options where applicable, including
  `design.basis`, `design.drop.tol`, `ridge.multiplier.grid`,
  `ridge.condition.max`, and `unstable.action`;
- falls back to the clipped local weighted event rate only when the guarded
  logistic solve is not usable and `unstable.action = "mean"`;
- records `cv.logloss.observed`, `cv.brier.observed`, and `cv.rmse.observed`
  in the CV table;
- selects the candidate with smallest observed CV log loss;
- returns response-scale probabilities in both `fitted.values` and
  `fitted.values.raw`;
- keeps `predict.lps(type = "response")` and `predict.lps(type = "raw")`
  explicit for both binary modes.

## Smoke report

The smoke report is:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_smoke_2026-06-07/lps_binary_outcome_smoke_report.html`

Supporting assets:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_smoke_2026-06-07/tables/lps_binary_smoke_method_summary.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_smoke_2026-06-07/tables/lps_binary_smoke_run_metrics.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_smoke_2026-06-07/tables/lps_binary_smoke_bernoulli_cv_table.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_smoke_2026-06-07/tables/lps_binary_smoke_binomial_cv_table.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_smoke_2026-06-07/lps_binary_smoke_fit_bundle.rds`

In this one nonlinear binary smoke example, both binary modes selected
support size 30, degree 1, and Gaussian kernel.  The Brier-mode LPS had
synthetic truth RMSE about `0.0872`; logistic LPS had synthetic truth RMSE about
`0.0756`.  This is only a smoke result, not a broad performance claim.

## Validation run

The following commands passed:

```sh
make document
Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R")'
Rscript scripts/run_lps_binary_outcome_smoke.R
git diff --check
```

Focused `test-ge7-lps-api.R` passed with 167 expectations.  A full package test
run was intentionally not launched in this handoff because the longer S3R
expanded run is still the active background compute workload.

## Audit questions

1. Is the statistical contract clear enough: `bernoulli` is Brier-mode numeric
   conditional expectation, while `binomial` is local logistic likelihood?
2. Is observed CV log loss the right default selection score for
   `outcome.family = "binomial"`?
3. Is the R-only backend policy acceptable for the initial logistic mode, with
   explicit native-backend errors?
4. Are the IRLS convergence, ridge, and fallback behaviors sufficiently guarded
   for a first implementation?
5. Should `predict.lps(type = "raw")` for binomial continue returning
   probabilities, or should a future API add `type = "link"` for fitted logits?
6. Before wider binary experiments, what additional tests should be required:
   separation cases, all-zero/all-one warnings, external `X.eval`, local-PCA
   charts, or comparison against `glm()` in very small known examples?

