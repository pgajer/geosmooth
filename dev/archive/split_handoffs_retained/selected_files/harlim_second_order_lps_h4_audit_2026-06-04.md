# Audit: H4 Opt-In LPS Second-Order Chart Integration

Date: 2026-06-04

Audited handoff:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h4_handoff_2026-06-04.md`

## Verdict

Accepted as an experimental, opt-in LPS chart-mode integration.

The implementation satisfies the main H4 contract:

- `fit.lps()` keeps ordinary PCA as the default local chart method.
- `local.chart.method = "second.order.svd"` is available only for
  `coordinate.method = "local.pca"`.
- Ambient-coordinate LPS rejects the second-order chart option.
- CV and final prediction both route through the requested chart method.
- Final second-order fits expose compact chart diagnostics.
- The H4 smoke run validates wiring and diagnostics only. It is not a
  performance study and should not be used to judge whether second-order charts
  improve or worsen LPS accuracy.

## Blocking Issues

None.

## Nonblocking Issues

### 1. Ambient-coordinate reporting still carries a nominal chart method

`fit.lps()` now stores `local.chart.method` for all fits. For
`coordinate.method = "coordinates"`, this field will normally be `"pca"` even
though no local chart is constructed. This does not appear to change numerical
behavior, and `print.lps()` only displays the chart method for local-PCA fits.
Still, for downstream reports it would be cleaner to distinguish the requested
chart method from the effective chart method, or to suppress chart diagnostics
for ambient-coordinate fits.

Suggested cleanup:

- Keep `local.chart.method` as the requested argument.
- Add `local.chart.method.effective = "none"` when
  `coordinate.method = "coordinates"`.
- Keep `local.chart.method.effective = local.chart.method` when
  `coordinate.method = "local.pca"`.
- Use the effective field in diagnostics summaries and reporting text.

This is not a blocker because the second-order option is correctly rejected for
ambient-coordinate fits and no ambient-coordinate numerical path is changed.

## Validation Repeated During Audit

Commands run in `/Users/pgajer/current_projects/geosmooth`:

```sh
Rscript scripts/harlim_second_order_lps_h4_smoke.R
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-harlim-second-order-svd-chart.R")'
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-ge1-r-smoothers.R")'
Rscript - <<'RS'
pkgload::load_all('/Users/pgajer/current_projects/geosmooth', quiet = TRUE)
set.seed(44)
X <- cbind(seq(0, 1, length.out = 20), sin(seq(0, 1, length.out = 20)))
y <- X[,1]^2 + 0.1 * X[,2]
foldid <- rep(1:5, length.out = nrow(X))
a <- fit.lps(X, y, foldid = foldid, support.grid = c(8L, 10L),
             degree.grid = 1L, kernel.grid = 'gaussian',
             coordinate.method = 'local.pca', chart.dim = 1L, backend = 'R')
b <- fit.lps(X, y, foldid = foldid, support.grid = c(8L, 10L),
             degree.grid = 1L, kernel.grid = 'gaussian',
             coordinate.method = 'local.pca', chart.dim = 1L,
             local.chart.method = 'pca', backend = 'R')
cat('default_method=', a$local.chart.method, '\n', sep='')
cat('default_equals_explicit_pca=',
    isTRUE(all.equal(a$fitted.values, b$fitted.values, tolerance = 1e-12)),
    '\n', sep='')
cat('predict_length=', length(predict(a, X[1:2,,drop=FALSE])), '\n', sep='')
err <- try(fit.lps(X, y, support.grid = 8L, degree.grid = 1L,
                   kernel.grid = 'gaussian',
                   coordinate.method = 'coordinates',
                   local.chart.method = 'second.order.svd',
                   backend = 'R'), silent = TRUE)
cat('ambient_second_order_errors=', inherits(err, 'try-error'), '\n', sep='')
RS
make test
git diff --check
```

Observed results:

- H4 smoke script completed and reproduced the four-row mixed outcome summary.
- Harlim second-order chart test: 26 passed, 0 failures.
- GE1 smoother test: 37 passed, 0 failures.
- Default local-PCA LPS matched explicit `local.chart.method = "pca"` exactly
  on the fixed probe.
- `predict.lps()` returned an ordinary prediction vector.
- Ambient coordinates plus `local.chart.method = "second.order.svd"` errored
  as intended.
- Full `make test`: 833 passed, 0 failures, 0 warnings, 9 expected skips.
- `git diff --check`: clean.

## Interpretation Of H4 Smoke Results

The H4 smoke results should be interpreted only as an implementation and
diagnostic check:

- the opt-in `fit.lps()` argument is wired;
- ordinary PCA remains the default path;
- ambient-coordinate fits reject second-order charts;
- second-order local-PCA fits return finite fitted values and diagnostics;
- flat-plane behavior agrees with the PCA path in the focused regression test.

The four-row smoke comparison is too small and too deliberately narrow to make
any accuracy claim about second-order local SVD charts. In particular, it cannot
support a statement that second-order charts improve LPS, worsen LPS, or should
be abandoned as an LPS option.

Any performance recommendation requires an expanded dim > 1 evaluation using
the already materialized synthetic-geometry and real-geometry test
infrastructure.

## Precise Next Step

Assign **H5: Expanded dim > 1 LPS chart comparison** to the Harlim agent.

H5 should be an evidence-building evaluation phase, not a default-changing
phase. It should compare ordinary local-PCA LPS and second-order-local-SVD LPS
on existing dim > 1 assets. It should not integrate second-order charts into
MALPS, LPL-TF, SLPL-TF, or production P7 selectors.

Required H5 tasks:

1. Add the small reporting cleanup from this audit.
   - Preserve the public argument `local.chart.method`.
   - Add `local.chart.method.effective`.
   - Set it to `"none"` for `coordinate.method = "coordinates"`.
   - Set it to the requested chart method for `coordinate.method = "local.pca"`.
   - Ensure diagnostics summaries and any report-facing text use the effective
     value where appropriate.

2. Add regression tests for unchanged defaults.
   - A local-PCA `fit.lps()` call omitting `local.chart.method` must match the
     same call with `local.chart.method = "pca"` on a fixed seed/fold split.
   - An ambient-coordinate `fit.lps()` call must continue to use the same
     numerical path and must report `local.chart.method.effective = "none"`.
   - A second-order local-PCA fit must still return diagnostics and `predict()`
     must still return a plain numeric vector.
   - Ambient coordinates with `local.chart.method = "second.order.svd"` must
     continue to hard-error.

3. Run an expanded dim > 1 comparison using existing assets.
   - Primary asset registry:
     `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/config/p7_geometry_registry.csv`
   - Primary truth registry:
     `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/config/p7_synthetic_truth_registry.csv`
   - Useful P7 script to inspect/reuse:
     `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/scripts/run_p7e_kernel_chart_focused_comparison.R`
   - Useful P7 report/table assets:
     `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/reports/p7e_kernel_chart_focused_comparison_fast_20260603/`
   - Optional dense 2D reference assets:
     `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/validation/phase_s7_2d_geometry_outputs/s7_2d_geom_support_local12_20260531_092229/`
   - Optional generated 2D robust-selection reports:
     `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/reports/phase_s7_2d_robust_selection/`
   - Optional VALENCIA-derived LPS scalability scripts/assets:
     `/Users/pgajer/current_projects/geosmooth/scripts/k3_8_lps_valencia_scalability.R`
     and
     `/Users/pgajer/current_projects/geosmooth/split_handoffs/k3_8_lps_valencia_scalability_2026-06-04/`

4. The expanded comparison should include at minimum:
   - flat 2D square;
   - curved 2D paraboloid;
   - curved 2D saddle;
   - flat 3D cube;
   - high-dimensional embedded 2D;
   - high-dimensional embedded 3D;
   - at least one VALENCIA-derived or P7 16S real-geometry example if runtime
     permits.

5. For each dataset/truth/noise case, fit both:
   - `fit.lps(..., coordinate.method = "local.pca", chart.dim = "auto",
     local.chart.method = "pca")`;
   - `fit.lps(..., coordinate.method = "local.pca", chart.dim = "auto",
     local.chart.method = "second.order.svd")`.

6. Use the same non-oracle CV folds, support grid, degree grid, and kernel grid
   for both chart methods. Record:
   - Truth RMSE;
   - observed RMSE;
   - CV RMSE;
   - selected support size, degree, kernel, and chart dimension;
   - runtime;
   - second-order fallback diagnostics;
   - any numerical failures.

7. Produce an HTML report and a handoff.
   - Handoff path:
     `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h5_expanded_eval_handoff_2026-06-04.md`
   - The report should use paired deltas:
     \[
       \Delta = \mathrm{TruthRMSE}_{\mathrm{second.order.svd}}
              - \mathrm{TruthRMSE}_{\mathrm{pca}}.
     \]
     Negative values favor second-order charts; positive values favor ordinary
     PCA charts.
   - The report should not claim significance unless the number and diversity
     of paired cases justify it.

8. Only after H5 should the project decide whether to:
   - keep second-order charts as a diagnostic/experimental option only;
   - run a larger study;
   - or consider broader integration.

9. Write a compact H5 decision note.
   - Path:
     `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h5_decision_note_2026-06-04.md`
   - The note should separate implementation readiness from accuracy evidence.
   - It should explicitly state that H4 alone was only a smoke/wiring phase.

10. Validation gates for H5:
   - `make document`
   - `Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-ge1-r-smoothers.R")'`
   - `Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-harlim-second-order-svd-chart.R")'`
   - `make test`
   - `git diff --check`

After H5, make the next recommendation from the expanded paired evidence, not
from the H4 smoke run.
