Build timestamp: 2026-06-07 21:39:21 EDT

This note responds to:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_logistic_audit_2026-06-07.md`

## Summary

I addressed both blocking findings for broader binary experiments:

1. all-failed CV candidate grids now fail fast instead of selecting an invalid
   row with non-finite score;
2. binomial LPS now records local logistic solve telemetry for CV and final
   fitting.

The binary smoke report has been regenerated and now includes the requested
logistic solve diagnostics.

## Changes Made

### All-Failed Candidate Grid Guard

`fit.lps()` now stops when the selection score column has no finite value.
For binomial LPS this means a grid with no finite `cv.logloss.observed` cannot
return a nominal selected fit.

The error is:

```text
No candidate has a finite selection score in '<score column>'.
```

This is implemented in:

`/Users/pgajer/current_projects/geosmooth/R/lps.R`

and covered in:

`/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R`

### Logistic Telemetry

Binomial LPS now records a `logistic.diagnostics` object with separate `cv`
and `final` entries.  Each entry reports:

- attempted local logistic solves;
- converged solves;
- failed solves;
- event-rate fallbacks;
- convergence and fallback fractions;
- status counts.

The telemetry is active only for `outcome.family = "binomial"`.

### Smoke Report Update

The smoke report now contains a dedicated "Logistic Solve Diagnostics" section:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_smoke_2026-06-07/lps_binary_outcome_smoke_report.html`

The diagnostics table is also written as:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_smoke_2026-06-07/tables/lps_binary_smoke_logistic_diagnostics.csv`

For the regenerated smoke run:

- CV local solves: 2240 attempted, 2012 converged, 228 fallback.
- Final selected fit: 140 attempted, 140 converged, 0 fallback.

This means the selected final logistic fit in the smoke report is not using
event-rate fallback predictions.

## Additional Test Coverage Added

The focused LPS API test now covers:

- binomial log-loss selection;
- `backend = "auto"` routing to the R backend;
- explicit native backend rejection for binomial mode;
- all-failed grid fail-fast behavior;
- local-PCA binomial smoke behavior;
- external `X.eval` binomial probability diagnostics;
- single-class binomial input warning behavior;
- logistic telemetry presence and positive solve counts.

## Validation

The following commands passed:

```sh
make document
Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R")'
Rscript scripts/run_lps_binary_outcome_smoke.R
git diff --check -- R/lps.R man/fit.lps.Rd man/predict.lps.Rd tests/testthat/test-ge7-lps-api.R scripts/run_lps_binary_outcome_smoke.R
```

The focused test file passed with 182 expectations.

I did not run full `make test` or `make check-fast` because the active request
was to address the focused logistic audit and rerun the smoke test, and the
larger S3R-expanded workload remains the background compute priority.

