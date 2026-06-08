# LPS Minimal Bernoulli Outcome Audit

Generated: 2026-06-07

Auditor: Codex

Audited handoff:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_minimal_bernoulli_handoff_2026-06-07.md`

Related design note:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_binary_outcome_design_note_2026-06-07.md`

Primary implementation files inspected:

- `/Users/pgajer/current_projects/geosmooth/R/lps.R`
- `/Users/pgajer/current_projects/geosmooth/man/fit.lps.Rd`
- `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R`

## Verdict

`accepted for minimal binary-outcome smoke use with non-blocking follow-up`

The implementation correctly adds an opt-in Bernoulli mode for estimating the binary conditional expectation under squared-error/Brier-risk semantics. It does not claim or implement logistic likelihood fitting, keeps the existing least-squares smoother machinery, preserves raw least-squares predictions, clips response-scale probabilities to `[0, 1]`, and adds Brier/log-loss diagnostics.

This is ready for first binary smoke experiments when fits use the default in-sample `X.eval = X` path, or when out-of-sample prediction diagnostics are not interpreted as training Brier/log-loss diagnostics.

## Blocking Findings

None.

## Non-Blocking Findings

1. `probability.diagnostics` silently reports `NA` Brier/log-loss when `X.eval` has a different row count than the training response.

   In `fit.lps()`, `X.eval` may be any finite matrix with matching column count (`R/lps.R:123-126`). The stored `fitted.raw` and `fitted.response` are predictions at `X.eval` (`R/lps.R:254-267`), but `.klp.brier()` and `.klp.logloss()` return `NA` when prediction length differs from `length(y)` (`R/lps.R:591-604`). I confirmed this behavior with a small Bernoulli fit using a 30-row training set and 10-row `X.eval`.

   This does not corrupt predictions, and it is acceptable for the current minimal smoke path if `X.eval` defaults to `X`. Before treating these diagnostics as a stable public contract, either compute probability diagnostics on training-row fitted predictions independently of `X.eval`, or document that Brier/log-loss diagnostics are only defined when `length(X.eval) == length(y)`. Add a regression test for whichever contract is chosen.

2. The Rd value/API documentation is too terse for the new Bernoulli object contract.

   The `outcome.family` argument is documented clearly (`man/fit.lps.Rd:113-118`), but the `\value{}` section still only says the object has "fitted values" and a CV table (`man/fit.lps.Rd:120-125`). It does not explicitly define:

   - `fitted.values` as response-scale predictions, clipped for Bernoulli;
   - `fitted.values.raw` as the un-clipped least-squares predictions;
   - `probability.diagnostics`;
   - `cv.table$cv.brier.observed`;
   - `predict.lps(type = "response")` versus `predict.lps(type = "raw")`.

   This is not a launch blocker for internal experiments, but it should be fixed before relying on this as user-facing package documentation.

3. Test coverage is adequate for the first patch, but should add a few contract-locking cases.

   The focused test confirms validation, raw Gaussian parity, Brier column construction, clipping, finite in-sample diagnostics, and raw/response prediction behavior for supplied `newdata` (`tests/testthat/test-ge7-lps-api.R:26-97`). Recommended additions:

   - `predict(bernoulli, type = "raw")` equals `fitted.values.raw` when `newdata = NULL`;
   - `predict(bernoulli, type = "response")` equals `fitted.values` when `newdata = NULL`;
   - Gaussian `predict(type = "raw")` equals Gaussian response predictions;
   - single-class Bernoulli input warns, not errors, and returns a coherent object;
   - the chosen `X.eval` diagnostics contract is tested.

## Audit Questions

1. Brier versus logistic semantics:

   Accepted. The implementation is a squared-error/Brier conditional-expectation mode, not a logistic likelihood mode. The argument documentation correctly says Bernoulli mode keeps the same local least-squares fitting core and targets `Pr(Y = 1 | X)` (`man/fit.lps.Rd:113-118`). The design note also frames logistic fitting as a later phase.

2. Object contract:

   Accepted with documentation follow-up. `fit.lps()` stores `fitted.values` as clipped response-scale predictions, `fitted.values.raw` as raw least-squares predictions, `outcome.family`, and `probability.diagnostics` (`R/lps.R:281-316`). This is internally coherent.

3. `predict.lps()` API:

   Accepted. `predict.lps(type = c("response", "raw"))` is a reasonable minimal interface (`R/lps.R:324-330`). For Bernoulli, `response` clips and `raw` preserves the unscaled least-squares prediction. For Gaussian, both scales are identical.

4. Selection on RMSE versus Brier:

   Accepted. Selecting by observed RMSE is equivalent to selecting by observed Brier because `cv.brier.observed = cv.rmse.observed^2` (`R/lps.R:638-644`). The monotone transformation preserves candidate ordering. The report/documentation should state this explicitly so readers do not interpret RMSE selection as a Gaussian-only objective.

5. Probability diagnostics:

   Sufficient for the minimal mode. The diagnostics expose raw/clipped ranges, counts/fractions outside `[0, 1]`, clipped/raw Brier, and clipped log loss (`R/lps.R:606-635`). For future reports, include the denominator `n` or make sure the denominator is inferable from the fitted object.

6. Compatibility risks:

   Low. The default `outcome.family = "gaussian"` preserves ordinary behavior (`R/lps.R:90-114`). Bernoulli clipping is opt-in. The main compatibility risk is documentation: downstream internal code must know to use `fitted.values.raw` or `predict(type = "raw")` if it needs the raw linear smoother output.

7. Test adequacy:

   Adequate for this minimal implementation, with the additional cases listed above recommended before broadening use.

8. Single-class warning versus error:

   Accepted. For this Brier-risk conditional-expectation mode, a single-class binary response can still be fit as a numeric smoother, and warning is the right severity (`R/lps.R:570-574`). A later logistic backend may need stronger separation/identifiability guards.

9. Backend diagnostics:

   Accepted. `lps.backend.diagnostics()` records `outcome.family` and selected Brier diagnostics for Bernoulli fits (`R/lps.R:499`, `R/lps.R:542-543`). Full probability diagnostics can remain on the fitted object.

10. Readiness for binary smoke experiments:

   Accepted for in-sample/default-`X.eval` smoke experiments. If the smoke design evaluates on external `X.eval` grids and wants Brier/log-loss for those predictions, the experiment script must provide matching labels or the implementation must add explicit training-row probability diagnostics.

11. Next steps toward PS-LPS/logistic:

   Keep this minimal Brier mode as the baseline binary smoother. For PS-LPS/logistic phases, audit separately for likelihood definition, local separation handling, ridge/penalty scale, probability clipping only for reporting, log-loss CV policy, and calibration diagnostics.

## Verification Performed

- Read the Bernoulli handoff and binary outcome design note.
- Inspected the implementation diff in `R/lps.R`, `man/fit.lps.Rd`, and `tests/testthat/test-ge7-lps-api.R`.
- Ran focused tests:

```bash
cd /Users/pgajer/current_projects/geosmooth
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-ge7-lps-api.R")'
```

Result: 138 passed, 0 failed, 0 warnings, 0 skipped.

- Ran an explicit Bernoulli `X.eval` row-count mismatch probe and confirmed diagnostics Brier/log-loss become `NA`.
- Ran whitespace hygiene:

```bash
cd /Users/pgajer/current_projects/geosmooth
git diff --check -- R/lps.R man/fit.lps.Rd tests/testthat/test-ge7-lps-api.R
```

Result: clean.

I did not run the full package test suite for this audit; the handoff reported that the full suite is currently load-heavy, and the focused API test covers the Bernoulli changes directly.
