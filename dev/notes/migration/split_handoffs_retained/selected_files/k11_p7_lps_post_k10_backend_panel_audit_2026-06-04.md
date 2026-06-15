# K11 Audit: P7 LPS Post-K10 Backend Panel

Audited: 2026-06-04 22:48:00 EDT

## Verdict

Accepted for the stated K11 scope: the regenerated K11 panel supports
`backend = "cpp.local.pca"` as an explicit opt-in backend on the focused P7
high-dimensional and deterministic 16S-style rows.  It does not support
promoting the native backend to `backend = "auto"`.

## Findings

### P3: Selected-candidate parity should include `chart.dim`

The K11 script records `chart.dim`, but the `selected.same` predicate compares
only `selected.support.size`, `selected.degree`, and `selected.kernel`
(`/Users/pgajer/current_projects/geosmooth/scripts/k11_p7_lps_post_k10_backend_panel.R:278`).
Because K11 uses `chart.dim = "auto"`, selected chart dimension is part of the
effective selected model and should be included in future selected-parity
status checks.  I manually verified the regenerated outputs and the selected
chart dimensions match for all five rows: 25, 2, 3, 5, and 6 for both
backends, so this is not a blocker for the current bundle.

### P3: Runtime should be treated as descriptive only

Regenerating the K11 bundle reproduced fit/CV parity, but did not reproduce
the originally submitted speedup direction.  The refreshed handoff now reports
median runtime ratio R/native `0.754279`, meaning the native path was slower
on this audit rerun.  This reinforces the handoff's "do not promote to auto"
recommendation.  K11 is acceptable as a parity and explicit-opt-in validation,
but its runtime panel should not be used as evidence of a durable speed win.

## Artifact Checks

Regenerated:

- `/Users/pgajer/current_projects/geosmooth/scripts/k11_p7_lps_post_k10_backend_panel.R`

Refreshed K11 outputs:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/k11_p7_lps_post_k10_backend_panel_handoff_2026-06-04.md`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/k11_p7_lps_post_k10_backend_panel_2026-06-04/k11_p7_lps_post_k10_backend_panel.html`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/k11_p7_lps_post_k10_backend_panel_2026-06-04/tables/k11_lps_backend_delta_summary.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/k11_p7_lps_post_k10_backend_panel_2026-06-04/tables/k11_lps_backend_summary_long.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/k11_p7_lps_post_k10_backend_panel_2026-06-04/tables/k11_lps_backend_cv_tables_long.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/k11_p7_lps_post_k10_backend_panel_2026-06-04/k11_lps_backend_results.rds`

Post-rerun summary:

- Delta rows: 5.
- `backend = "auto"` resolved to `backend.used = "R"` for all five rows.
- `backend = "cpp.local.pca"` resolved to `backend.used = "cpp.local.pca"`
  for all five rows.
- Full grid was present for every dataset/backend pair: support sizes `15:35`,
  degrees `{1, 2}`, kernels `{gaussian, tricube}`, 84 candidates per row.
- All selected candidates matched.
- Maximum absolute CV-RMSE table delta: `2.145876e-06`.
- Maximum absolute fitted-value delta: `4.662937e-15`.
- Maximum absolute Truth-RMSE delta: `8.326673e-17`.
- Status counts: 3 `cv_numeric_drift_selected_stable`, 2
  `safe_machine_precision`.

Selected rows after regeneration:

| Row | n | p | chart dim | selected support | degree | kernel |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| HD1 latent two Gaussian | 200 | 100 | 25 | 34 | 1 | gaussian |
| HD2 latent three Gaussian | 400 | 100 | 2 | 27 | 2 | tricube |
| HD3 latent four Gaussian | 600 | 99 | 3 | 29 | 2 | tricube |
| 16S subset n250 | 250 | 178 | 5 | 33 | 1 | gaussian |
| 16S subset n500 | 500 | 178 | 6 | 33 | 1 | gaussian |

## Verification

Passed:

```sh
Rscript scripts/k11_p7_lps_post_k10_backend_panel.R
Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R", reporter="summary")'
Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge1-r-smoothers.R", reporter="summary")'
make test
git diff --check
```

`make test` result: 0 failures, 0 warnings, 9 expected skips, 883 passes.

Compiled test artifacts under `src/` were removed after verification.

## Recommendation

Proceed with explicit opt-in use of `backend = "cpp.local.pca"` where K11-style
metadata records the requested and used backend.  Do not change `backend =
"auto"` yet.  Before any default-policy promotion, add selected `chart.dim` to
the status predicate and run a repeated benchmark panel broad enough to support
a stable size/dimension/backend-selection rule.
