Build timestamp: 2026-06-07 21:56:53 EDT

This note records the small telemetry-name refinement requested after:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_logistic_audit_response_reaudit_2026-06-07.md`

## Change

The previous binomial LPS telemetry field

```r
fallback
```

was ambiguous because the fallback path can either emit a clipped local
weighted event-rate prediction or return `NA`, depending on
`unstable.action`.

The telemetry summary now reports:

- `fallback.path.count`: number of local logistic predictions that used the
  fallback branch;
- `event.rate.fallback.count`: number of fallback predictions that emitted a
  clipped local weighted event-rate probability;
- `na.failure.count`: number of fallback predictions that emitted `NA`.

The corresponding fractions are also reported:

- `fallback.path.fraction`;
- `event.rate.fallback.fraction`;
- `na.failure.fraction`.

## Smoke Report Update

The smoke report was regenerated:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_smoke_2026-06-07/lps_binary_outcome_smoke_report.html`

The logistic diagnostics CSV now has the split columns:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_smoke_2026-06-07/tables/lps_binary_smoke_logistic_diagnostics.csv`

For the current smoke run:

- CV: `2240` attempted, `2012` converged, `228` fallback paths,
  `228` event-rate fallbacks, `0` NA failures.
- Final selected fit: `140` attempted, `140` converged, `0` fallback paths,
  `0` event-rate fallbacks, `0` NA failures.

## Validation

The following commands passed:

```sh
make document
Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R")'
Rscript scripts/run_lps_binary_outcome_smoke.R
git diff --check -- R/lps.R man/fit.lps.Rd tests/testthat/test-ge7-lps-api.R scripts/run_lps_binary_outcome_smoke.R
```

The focused test file passed with 190 expectations.

Note: an earlier parallel attempt ran `make document` and the focused test at
the same time, which temporarily exposed missing native registration during
`pkgload`.  The sequential rerun passed; the transient failure was not caused by
the telemetry refinement.

