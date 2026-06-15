# Harlim Second-Order Local SVD H2/H3 Smoke Audit

Date: 2026-06-04

Audited handoff:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_local_svd_h2h3_smoke_handoff_2026-06-04.md`

Audited files:

- `/Users/pgajer/current_projects/geosmooth/scripts/harlim_second_order_local_svd_h2h3_smoke.R`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_local_svd_h2h3_smoke_results_2026-06-04.csv`
- existing H1 implementation and unit test files touched by the Harlim work

Verdict: accepted for the next narrow opt-in LPS chart-mode experiment.

No blocking correctness issues were found in the H2/H3 smoke handoff.  The
handoff stayed within scope: it ran chart-level diagnostics only, did not alter
LPS, SLPLiFT, or package defaults, and recorded the numerical controls used.

## Findings

The submitted smoke script is deterministic and source-tree local:

- it loads `geosmooth` with `pkgload::load_all(".", quiet = TRUE)`;
- it evaluates one preselected local support at a time;
- it compares ordinary local PCA and the second-order SVD primitive by tangent
  projector error against known tangent spaces;
- it records fallback status, fallback reason, design rank, design condition,
  first/second SVD ranks, fit summaries, and elapsed time.

The results file has 55 rows and 35 columns.  The study counts are:

- `base`: 12 rows;
- `conditioning`: 5 rows;
- `support_sweep`: 35 rows;
- `weighted_zero_rows`: 3 rows.

The fallback rates reported in the handoff are reproduced:

- `base`: 0;
- `conditioning`: 0;
- `support_sweep`: 15/35 = 0.4285714;
- `weighted_zero_rows`: 0.

The fallback behavior is consistent with the H0/H1 contract in the undersized
support cases:

- support size 1 gives structured failure because ordinary fixed-dimension PCA
  fallback is not feasible;
- support size 2 gives ordinary PCA fallback for too few effective support
  rows;
- support size 3 gives ordinary PCA fallback for an underdetermined curvature
  design;
- support sizes 4, 6, 10, and 25 produce non-fallback second-order charts in
  the tested random supports.

The main qualitative conclusion is supported: on the tested flat, paraboloid,
saddle, zero-weight, and 20-dimensional embedded support cases, the
second-order chart usually reduces tangent-projector error relative to ordinary
local PCA, while preserving flat tangent spaces up to numerical precision.

## Nonblocking Notes

The support-size sweep contains one non-fallback support-size-4 case where
second-order SVD is worse than ordinary PCA:

- study: `support_sweep`;
- geometry: `paraboloid`;
- support kind: `asymmetric`;
- PCA projector error: approximately `0.4938451`;
- second-order projector error: approximately `0.6387755`;
- delta `PCA - second.order`: approximately `-0.1449304`.

This is not a blocker.  It is exactly the kind of small-support behavior that
an opt-in experiment should expose.  It does mean future reports should include
no-worse rates, worse-case deltas, and fallback rates, not only median
improvements.

The "conditioning" sweep is a conditioning-stress smoke test, but it is not yet
an ill-conditioned rejection test.  The recorded design conditions range only
from about `1.78` to `47.8` under `curvature.condition.max = 1e8`, so this
smoke does not exercise the `curvature_ill_conditioned` fallback path.

The smoke script compares tangent spaces, not smoothing performance.  It should
not be used to claim that second-order charts improve LPS, MALPS, LPL-TF, or
SLPLiFT fits until an end-to-end opt-in chart-mode run is completed.

## Validation

Commands run from `/Users/pgajer/current_projects/geosmooth`:

```sh
Rscript scripts/harlim_second_order_local_svd_h2h3_smoke.R
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-harlim-second-order-svd-chart.R")'
git diff --check
make test
```

Results:

- H2/H3 smoke rerun: completed, wrote 55 diagnostic rows, and reproduced the
  handoff fallback and median-error summaries;
- targeted Harlim test file: 26 passed, 0 failures;
- `git diff --check`: clean;
- full `make test`: 817 passed, 0 failures, 0 warnings, 9 expected skips.

## Response to Harlim Agent

Accepted.  Please proceed with **H4: Opt-In LPS Second-Order Chart-Mode
Integration and Smoke Report**.

H4 objective:

- Add an explicitly opt-in second-order local SVD chart mode for `fit.lps()`
  only.
- Do not change any defaults.
- Do not integrate into MALPS, LPL-TF, SLPLiFT, SSRHE, or P7 production runs in
  H4.
- Preserve existing ordinary local-PCA behavior bit-for-bit when the new option
  is not requested.

Required H4 API design:

1. Add a new user-facing argument to `fit.lps()`:

   ```r
   local.chart.method = c("pca", "second.order.svd")
   ```

2. The argument applies only when `coordinate.method = "local.pca"`.
3. Default must be `"pca"`.
4. If `coordinate.method = "coordinates"`, then requesting
   `local.chart.method = "second.order.svd"` must be a clear hard error,
   because no local chart is being constructed.
5. Keep `backend = "cpp"` restricted to `coordinate.method = "coordinates"` as
   it is now.  The first H4 second-order path may use the existing R-loop LPS
   local-PCA path.

Required H4 implementation:

1. Extend the internal LPS local-coordinate path, currently centered around
   `.klp.local.coordinates()`, so it can dispatch to either:

   - `rcpp_local_pca_chart(...)`; or
   - `rcpp_local_second_order_svd_chart(...)`.

2. For the second-order path, pass the same support, center, fixed
   `chart.dim`, anchor centering, weights, rebase, and orientation controls as
   the current local-PCA path wherever applicable.
3. Surface second-order chart diagnostics in the returned `fit.lps()` object:

   - selected chart method;
   - per-anchor or aggregate fallback count;
   - fallback reasons;
   - aggregate design-rank/design-condition summaries;
   - a flag indicating whether any fitted point used ordinary PCA fallback or
     structured failure.

4. If collecting full per-anchor diagnostics is too heavy for the first
   implementation, return a compact summary and provide an internal option for
   detailed diagnostics in the smoke script.  Do not silently drop fallback
   information.
5. Ensure prediction and CV both use the requested chart method consistently.
6. Ensure existing tests for `fit.lps(coordinate.method = "local.pca")` still
   pass without modification of expected behavior under the default
   `local.chart.method = "pca"`.

Required H4 tests:

1. Add focused unit tests showing:

   - default `fit.lps()` behavior remains ordinary PCA;
   - requesting `local.chart.method = "second.order.svd"` with
     `coordinate.method = "local.pca"` produces a valid `"lps"` object;
   - requesting `local.chart.method = "second.order.svd"` with
     `coordinate.method = "coordinates"` errors clearly;
   - fallback diagnostics are present in the returned object when the
     second-order path is requested;
   - a flat-plane example gives fitted values close to the ordinary PCA chart
     path, within a conservative tolerance.

2. Do not add brittle expectations that second-order must always outperform PCA
   in prediction error.

Required H4 smoke report:

1. Create a script under `scripts/`, for example:

   ```text
   scripts/harlim_second_order_lps_h4_smoke.R
   ```

2. Use small deterministic synthetic examples:

   - flat plane;
   - paraboloid;
   - saddle;
   - one high-dimensional orthonormal embedding of a curved surface.

3. Compare `fit.lps()` with:

   - `coordinate.method = "local.pca", local.chart.method = "pca"`;
   - `coordinate.method = "local.pca", local.chart.method = "second.order.svd"`.

4. Record, at minimum:

   - RMSE against truth;
   - observed RMSE;
   - selected support size, degree, kernel, and chart dimension;
   - chart fallback rate and fallback reasons for the second-order run;
   - runtime;
   - whether second-order was better, tied, or worse than PCA on each example.

5. The smoke report must explicitly include the caution learned from H2/H3:
   second-order charts can be worse on some small asymmetric supports, so H4
   should report worse cases rather than hiding them behind medians.

Required H4 validation:

Run, from `/Users/pgajer/current_projects/geosmooth`:

```sh
Rscript scripts/harlim_second_order_lps_h4_smoke.R
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-harlim-second-order-svd-chart.R")'
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-ge1-r-smoothers.R")'
make test
git diff --check
```

Required H4 handoff:

- Create
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h4_handoff_2026-06-04.md`.
- List all modified R, C++/Rcpp, test, script, and generated documentation
  files.
- State exactly how `fit.lps()` defaults are preserved.
- Summarize the smoke results with both median and worst-case deltas.
- Summarize fallback rates and fallback reasons.
- State whether H4 recommends:
  1. stopping at chart diagnostics,
  2. expanding LPS experiments, or
  3. proposing a later MALPS/LPL/SLPLiFT integration contract.
- Stop after H4 and wait for audit before starting H5.
