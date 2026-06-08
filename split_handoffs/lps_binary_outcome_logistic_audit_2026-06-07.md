# LPS Binary Logistic Outcome Audit

Generated: 2026-06-07

Auditor: Codex

Audited handoff:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_logistic_handoff_2026-06-07.md`

Primary implementation files inspected:

- `/Users/pgajer/current_projects/geosmooth/R/lps.R`
- `/Users/pgajer/current_projects/geosmooth/man/fit.lps.Rd`
- `/Users/pgajer/current_projects/geosmooth/man/predict.lps.Rd`
- `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R`
- `/Users/pgajer/current_projects/geosmooth/scripts/run_lps_binary_outcome_smoke.R`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_smoke_2026-06-07/lps_binary_outcome_smoke_report.html`

## Verdict

`accepted for first logistic binary smoke use; not yet accepted for broader binary experiment grids`

The new `outcome.family = "binomial"` path is statistically distinct from the earlier `outcome.family = "bernoulli"` Brier-risk path. The implementation uses local weighted logistic IRLS, selects candidates by observed CV log loss, forces binomial fits onto the R backend, and documents the current probability-scale prediction contract.

Before broad binary experiments, the implementation needs a fail-fast contract for all-failed CV grids and better visibility into local logistic solve failures/fallbacks. Without those, large experiment sweeps can silently produce selected fits whose CV log loss is `NA` and whose fitted values are all `NA`, or can report a "logistic" fit that is partially driven by unreported local event-rate fallbacks.

## Blocking Findings For Broader Experiments

1. All-failed binomial candidate grids can return a selected fit with `NA` log loss and all-`NA` fitted values instead of failing.

   The binomial score column is `cv.logloss.observed` (`R/lps.R:709-714`), and candidate selection uses `.klp.select.best.idx()` (`R/lps.R:725-752`). If every log-loss score is non-finite, `.klp.select.best.idx()` falls through to ordering and returns a row rather than stopping (`R/lps.R:731-739`). I reproduced this with `outcome.family = "binomial"`, `support.grid = 2`, `degree.grid = 2`, `design.basis = "monomial"`, and `unstable.action = "na"`: the fit completed with `cv.logloss.observed = NA` and all final fitted values `NA`.

   This is tolerable only as an internal edge case. For broad binary experiment grids, the fit should stop with an informative error when the selected score column has no finite candidate, or should return a clearly marked failed fit object that experiment scripts cannot confuse with a valid method result.

2. Logistic solve failures and local event-rate fallbacks are invisible in the fitted object and smoke report.

   The logistic local solve returns status information internally (`R/lps.R:1479-1614`), but `.klp.fit.logistic.prob.design()` discards that status and returns only the final prediction or fallback (`R/lps.R:1462-1476`). With `unstable.action = "mean"`, failed local logistic solves are replaced by clipped local weighted event rates (`R/lps.R:1452-1458`) without any count or warning. The smoke report states that probabilities are finite, but it does not report how many local predictions came from IRLS convergence versus fallback.

   Before interpreting large binary comparisons, record at least per-fit counts of logistic solves attempted, converged, failed by status, and fallback predictions. The smoke report should include those counts for both CV and final prediction if practical.

## Non-Blocking Findings

1. The API choice `predict.lps(type = "raw")` returning probabilities for binomial mode is acceptable for now, but should remain explicitly documented as a probability-scale raw value.

   The current docs say that `type = "raw"` returns unmodified least-squares predictions for Bernoulli mode and fitted probabilities for binomial mode (`man/predict.lps.Rd:14-19`). That is coherent with the current object contract (`R/lps.R:87-102`, `R/lps.R:347-358`). A future `type = "link"` should be added if downstream diagnostics need fitted logits.

2. The focused binomial test covers the happy path but not key failure/stability cases.

   The test checks log-loss selection, probability ranges, raw/response prediction equivalence, `backend = "auto"` routing to R, and explicit native-backend rejection (`tests/testthat/test-ge7-lps-api.R:149-221`). Additional tests should cover:

   - all-failed candidate grid fails clearly;
   - separated or quasi-separated local neighborhoods;
   - single-class binomial input warning behavior;
   - `X.eval` external-grid diagnostics for binomial mode;
   - local-PCA binomial fits;
   - a small intercept-only or full-support comparison against `glm(..., family = binomial())`.

3. The smoke report is useful as a first sanity check, but it should not yet be used as evidence of method robustness.

   The smoke script uses one 1D nonlinear binary example and reports a modest truth-RMSE advantage for logistic LPS (`scripts/run_lps_binary_outcome_smoke.R:24-72`, `scripts/run_lps_binary_outcome_smoke.R:80-107`). This is appropriate for smoke validation. It is not enough to support performance claims, especially without fallback/convergence telemetry.

## Audit Questions

1. Statistical contract clarity:

   Accepted. `bernoulli` is the numeric conditional-expectation/Brier path, while `binomial` is the local logistic likelihood path. The handoff, `fit.lps()` docs, and smoke report all make this distinction.

2. Observed CV log loss as the default binomial selection score:

   Accepted. For a logistic-likelihood binary smoother, observed CV log loss is the right default primary score. The implementation computes `cv.logloss.observed` from cross-validated probability predictions (`R/lps.R:940-950`) and selects on it (`R/lps.R:233-236`, `R/lps.R:709-714`).

3. R-only backend policy:

   Accepted for the initial logistic mode. `backend = "auto"` routes binomial fits to R, and native backends error explicitly (`R/lps.R:180-187`). The focused test covers this policy (`tests/testthat/test-ge7-lps-api.R:189-220`).

4. IRLS convergence, ridge, and fallback guards:

   Partially accepted. The IRLS path has finite-value checks, condition-number guards, ridge multiplier search, iteration limit, and failure statuses (`R/lps.R:1479-1614`). However, status telemetry is discarded at prediction level, and all-failed candidate grids do not fail fast. These are the main required follow-ups before broad experiments.

5. `predict.lps(type = "raw")` for binomial:

   Accepted for now. Returning probabilities for both `raw` and `response` in binomial mode avoids exposing an uncommitted link-scale API. Add `type = "link"` later if fitted logits become useful for diagnostics, calibration, or logistic-specific reports.

6. Additional tests before wider binary experiments:

   Required before broad sweeps: all-failed grid behavior, separation/quasi-separation, all-zero/all-one responses, external `X.eval`, local-PCA binomial fits, and a small known comparison against `glm()`.

## Verification Performed

- Read the logistic handoff and the prior Bernoulli audit response.
- Inspected implementation, generated docs, focused tests, and smoke script.
- Checked `NAMESPACE` contains `S3method(predict,lps)`.
- Ran focused API tests:

```bash
cd /Users/pgajer/current_projects/geosmooth
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-ge7-lps-api.R")'
```

Result: 167 passed, 0 failed, 0 warnings, 0 skipped.

- Re-ran the binary smoke script:

```bash
cd /Users/pgajer/current_projects/geosmooth
Rscript scripts/run_lps_binary_outcome_smoke.R
```

Result: completed and regenerated the smoke HTML/report artifacts.

- Ran a local-PCA binomial smoke probe; it returned finite probabilities and selected finite log loss.
- Ran an all-zero binomial probe; it warned upstream when not suppressed and returned near-zero probabilities.
- Ran an all-failed grid probe and confirmed the selected-fit `NA` behavior described above.
- Ran whitespace hygiene:

```bash
cd /Users/pgajer/current_projects/geosmooth
git diff --check -- R/lps.R man/fit.lps.Rd man/predict.lps.Rd tests/testthat/test-ge7-lps-api.R scripts/run_lps_binary_outcome_smoke.R
```

Result: clean.

I did not run `make test`, `make check-fast`, or the full package test suite because the handoff reports active background S3R compute and the requested audit is focused on the new binary logistic path.
