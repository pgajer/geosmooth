# LPS Binary Logistic Audit Response Re-audit

Generated: 2026-06-07

Auditor: Codex

Re-audited response:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_logistic_audit_response_2026-06-07.md`

Original audit:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_logistic_audit_2026-06-07.md`

Primary implementation files inspected:

- `/Users/pgajer/current_projects/geosmooth/R/lps.R`
- `/Users/pgajer/current_projects/geosmooth/man/fit.lps.Rd`
- `/Users/pgajer/current_projects/geosmooth/man/predict.lps.Rd`
- `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R`
- `/Users/pgajer/current_projects/geosmooth/scripts/run_lps_binary_outcome_smoke.R`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_smoke_2026-06-07/lps_binary_outcome_smoke_report.html`

## Verdict

`accepted for broader binary experiment grids`

The two blocking findings from the prior audit have been resolved:

1. all-failed candidate grids now fail fast instead of returning a selected row with non-finite binomial log loss;
2. binomial LPS now exposes local logistic solve telemetry for both CV prediction generation and final selected fitting.

## Blocking Findings

None.

## Resolved Findings

1. All-failed binomial candidate grids now fail fast.

   `.klp.select.best.idx()` now stops when the requested selection score has no finite value (`R/lps.R:796-809`). I reproduced the prior failure case with a deliberately underdetermined binomial grid and `unstable.action = "na"`; it now errors with:

```text
No candidate has a finite selection score in 'cv.logloss.observed'.  Check local-design conditioning, support sizes, degree, backend, and unstable.action.
```

   The focused test suite also includes this regression case (`tests/testthat/test-ge7-lps-api.R:278-291`).

2. Logistic solve telemetry is now recorded and reported.

   `fit.lps()` creates separate telemetry environments for CV and final fitting and stores summaries in `fit$logistic.diagnostics` for binomial fits. The telemetry records attempted solves, converged solves, fallback counts, convergence/fallback fractions, and status counts (`R/lps.R:713-765`, `R/lps.R:1516-1567`). The focused tests assert telemetry presence and positive attempt counts (`tests/testthat/test-ge7-lps-api.R:181-185`, `tests/testthat/test-ge7-lps-api.R:257-259`).

   The regenerated smoke report now includes a "Logistic Solve Diagnostics" table, and the companion CSV reports:

```text
cv:    attempted 2240, converged 2012, failed 228, fallback 228
final: attempted 140,  converged 140,  failed 0,   fallback 0
```

   This resolves the prior concern that broad runs could silently mix converged local logistic predictions with unreported local event-rate fallbacks.

## Non-Blocking Notes

1. The `fallback` counter is best read as "fallback path used", not always "event-rate prediction emitted".

   In `.klp.fit.logistic.prob.design()`, the fallback path records `fallback = TRUE` before checking `unstable.action`; with `unstable.action = "na"` it returns `NA_real_`, while with `unstable.action = "mean"` it returns a clipped local weighted event rate (`R/lps.R:1532-1543`). Current broad smoke use appears to rely on `unstable.action = "mean"`, so this does not block launch. For later public reporting, consider splitting this into `fallback.path.count`, `event.rate.fallback.count`, and `na.failure.count`, or document the current interpretation.

2. Full package QA remains deferred.

   The focused API tests and smoke script passed, but I did not run `make test`, `make check-fast`, or `make check`. This is acceptable for the focused audit response, given the active background workload noted in the handoff, but broader package promotion should still get a fuller QA pass.

## Verification Performed

- Re-read the audit response and inspected the relevant implementation, docs, tests, smoke script, and regenerated smoke report assets.
- Confirmed the smoke report contains a logistic diagnostics section and that `tables/lps_binary_smoke_logistic_diagnostics.csv` contains CV/final telemetry rows.
- Re-ran the focused API test:

```bash
cd /Users/pgajer/current_projects/geosmooth
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-ge7-lps-api.R")'
```

Result: 182 passed, 0 failed, 0 warnings, 0 skipped.

- Reproduced the prior all-failed grid case and confirmed it now errors instead of returning an invalid selected fit.
- Ran a binomial telemetry consistency probe and confirmed attempted counts equal converged plus failed counts for both CV and final fitting.
- Re-ran the binary smoke script:

```bash
cd /Users/pgajer/current_projects/geosmooth
Rscript scripts/run_lps_binary_outcome_smoke.R
```

Result: completed and regenerated the smoke HTML/report artifacts.

- Ran whitespace hygiene:

```bash
cd /Users/pgajer/current_projects/geosmooth
git diff --check -- R/lps.R man/fit.lps.Rd man/predict.lps.Rd tests/testthat/test-ge7-lps-api.R scripts/run_lps_binary_outcome_smoke.R
```

Result: clean.
