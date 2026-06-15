# K6 P7 LPS Native Opt-In Integration Handoff

## Scope

K6 integrates the native local-PCA LPS backend into the P7 prospective-run
scripts as an explicit opt-in path. It does not change package defaults and does
not promote the native backend to `backend = "auto"`.

The intended use is:

```sh
Rscript run_p7e_prospective_orchestrator.R \
  --mode=... \
  --lps-local-pca-backend=cpp.local.pca
```

The option applies only to local-PCA LPS methods. Ambient-coordinate LPS methods
continue to use the package default `backend = "auto"` path.

## Files Changed

- `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/scripts/p7_baseline_fitters.R`
- `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/scripts/run_p7e_prospective_orchestrator.R`
- `/Users/pgajer/current_projects/geosmooth/scripts/k6_p7_lps_backend_integration_smoke.R`

## Implementation Details

The P7 LPS wrapper now accepts a `backend` argument and forwards it directly to
`geosmooth::fit.lps()`.

The P7e orchestrator now accepts:

```sh
--lps-local-pca-backend=auto|R|cpp.local.pca
```

with default:

```r
lps.local.pca.backend = "auto"
```

The helper `p7e.lps.backend(cfg, use.local.pca)` ensures that
`cpp.local.pca` is only routed to local-PCA LPS methods. For non-local-PCA LPS,
the backend remains `auto`.

Selected-parameter metadata now records:

- `local.chart.method`
- `local.chart.method.effective`
- `backend.requested`
- `backend.used`

This makes each P7 LPS result artifact auditable for whether it used the R
reference backend or the native local-PCA backend.

## Validation

Run from `/Users/pgajer/current_projects/geosmooth`:

```sh
Rscript scripts/k6_p7_lps_backend_integration_smoke.R
```

Result:

```text
K6 P7 LPS backend integration smoke passed.
```

The smoke check verifies:

- local-PCA LPS with `backend = "auto"` still uses `backend.used = "R"`;
- local-PCA LPS with `backend = "cpp.local.pca"` uses
  `backend.used = "cpp.local.pca"`;
- ambient-coordinate LPS with `backend = "auto"` still uses
  `backend.used = "cpp"`;
- the P7e orchestrator file parses after the new CLI option is added.

Focused geosmooth LPS API tests:

```sh
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-ge7-lps-api.R", reporter = "summary")'
```

Result:

```text
ge7-lps-api: ........................................
DONE
```

Repository hygiene:

```sh
git diff --check
```

passed in both:

- `/Users/pgajer/current_projects/geosmooth`
- `/Users/pgajer/current_projects/trend_filtering`

Generated native artifacts were cleaned with `make clean` in `geosmooth`.

## Important Caveat

K6 does not resolve the K5.1 warning. The native local-PCA backend has clean
selected-output smoke behavior, but the exact-plane diagnostic still found
non-selected degree-1 Gaussian candidate-CV drift between the R and native
candidate tables. Therefore:

- `backend = "auto"` remains unchanged;
- R remains the strict local-PCA LPS reference backend;
- `cpp.local.pca` is suitable only as an explicit prospective-run experiment;
- P7 reports using this option must disclose `backend.used`.

## Recommended Next Step

Proceed to K7 as a controlled prospective-comparison run:

1. run a small P7e preflight with `--lps-local-pca-backend=cpp.local.pca`;
2. confirm LPS artifacts record `backend.used = "cpp.local.pca"` for local-PCA
   LPS and `backend.used = "cpp"` for ambient LPS;
3. compare wall time and selected Truth RMSE against the same preflight with
   `--lps-local-pca-backend=auto`;
4. only if the preflight is clean, use the native backend for a larger
   prospective run, while keeping the R-backend run as the audit reference.
