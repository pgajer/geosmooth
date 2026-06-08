# LPS Minimal Bernoulli Outcome Audit Response

Date: 2026-06-07

Audit addressed:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_minimal_bernoulli_audit_2026-06-07.md`

## Summary

The audit verdict was:

`accepted for minimal binary-outcome smoke use with non-blocking follow-up`

I addressed the non-blocking follow-up items and ran a first binary-outcome
smoke test.

## Changes Made

### 1. Probability diagnostics contract for external `X.eval`

The audit noted that Brier/log-loss diagnostics silently became `NA` when
`X.eval` had a different row count than the training response.

The chosen contract is now explicit:

- range and clipping diagnostics always describe the fitted predictions that
  were actually produced;
- Brier/log-loss diagnostics are labeled-response diagnostics and are defined
  only when the prediction vector has the same length as `y`;
- external/unlabeled `X.eval` predictions report
  `diagnostic.scope = "unlabeled_eval_predictions"` and keep Brier/log-loss as
  `NA`.

Fields added to `probability.diagnostics`:

- `diagnostic.scope`;
- `n.labels`;
- `n.predictions`;
- `brier.denominator`.

### 2. Rd/API documentation

The `fit.lps()` value documentation now explicitly records the Bernoulli object
contract:

- `fitted.values` are response-scale values and are clipped probabilities for
  Bernoulli mode;
- `fitted.values.raw` are un-clipped least-squares conditional-expectation
  estimates;
- `cv.table$cv.brier.observed = cv.table$cv.rmse.observed^2`;
- `probability.diagnostics` records raw/clipped ranges, out-of-range fractions,
  and Brier/log-loss diagnostics;
- Brier/log-loss diagnostics require prediction length equal to the training
  response length.

A new generated `predict.lps` Rd page documents:

```r
predict.lps(type = c("response", "raw"))
```

where `response` returns clipped Bernoulli probabilities and `raw` returns
unmodified local least-squares predictions.

### 3. Contract-locking tests

The focused Bernoulli test now covers:

- `predict(bernoulli, type = "raw") == fitted.values.raw` when `newdata = NULL`;
- `predict(bernoulli, type = "response") == fitted.values` when
  `newdata = NULL`;
- Gaussian `predict(type = "raw") == predict(type = "response")`;
- single-class Bernoulli input warns and returns a coherent fit;
- external `X.eval` gets `diagnostic.scope = "unlabeled_eval_predictions"` and
  `NA` Brier/log-loss diagnostics.

## Smoke Test

A first binary-outcome smoke test was added and run.

Script:

`/Users/pgajer/current_projects/geosmooth/scripts/run_lps_binary_outcome_smoke.R`

Report:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_smoke_2026-06-07/lps_binary_outcome_smoke_report.html`

Tables:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_smoke_2026-06-07/tables/lps_binary_smoke_metrics.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_smoke_2026-06-07/tables/lps_binary_smoke_cv_table.csv`

Fit bundle:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_smoke_2026-06-07/lps_binary_smoke_fit_bundle.rds`

Smoke design:

- one-dimensional covariate \(x\in[0,1]\);
- nonlinear probability curve \(p(x)=\Pr(Y=1\mid X=x)\);
- binary observations \(Y_i\sim\operatorname{Bernoulli}(p(x_i))\);
- LPS Bernoulli mode with support, degree, and kernel selected by CV;
- ordinary Gaussian-mode LPS on the same `0/1` responses as a raw-prediction
  parity check.

Key smoke metrics:

- `n = 140`;
- event rate: `0.392857`;
- selected support size: `30`;
- selected degree: `1`;
- selected kernel: `gaussian`;
- selected observed CV RMSE: `0.416131`;
- selected observed CV Brier: `0.173165`;
- observed clipped Brier: `0.155701`;
- observed clipped log loss: `0.474046`;
- truth Brier against the synthetic probability curve: `0.007605`;
- truth RMSE against the synthetic probability curve: `0.087208`;
- raw prediction range: `[0.035141, 0.856628]`;
- fraction raw below zero: `0`;
- fraction raw above one: `0`;
- max absolute raw-prediction difference between Bernoulli mode and Gaussian
  mode on the same `0/1` data: `0`.

## Validation Run

```sh
cd /Users/pgajer/current_projects/geosmooth
make document
Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R")'
Rscript scripts/run_lps_binary_outcome_smoke.R
git diff --check
```

The focused API test passed after the patch.  The smoke script completed and
wrote the report above.

Full `make test` has still not been run because the S3R-expanded run is under
way.

## Current Recommendation

The minimal Bernoulli/Brier LPS mode is ready for small binary-outcome smoke
experiments, especially with default in-sample `X.eval = X` when Brier/log-loss
diagnostics are interpreted.

Next useful step: design a binary PS-LPS smoke path that starts from this same
Brier-risk interpretation before attempting a true logistic/likelihood-based
LPS.

