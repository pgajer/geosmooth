# K11 Handoff: P7 LPS Post-K10 Backend Panel

Generated: 2026-06-04 22:59:46 EDT

## Scope

K11 validates the explicit opt-in local-PCA LPS native backend after K10.
It compares:

- `backend = "auto"`, which currently resolves local-PCA LPS to the R
  reference path; and
- `backend = "cpp.local.pca"`, the explicit native local-PCA backend.

K11 does not change `backend = "auto"` and does not promote the native
backend into package defaults.

## Panel

The panel contains three controlled high-dimensional P7 rows and two
deterministic 16S-style subsets.  All rows use the current full P7 LPS
support grid `15:35`, degree grid `{1, 2}`, kernel grid
`{gaussian, tricube}`, `chart.dim = "auto"`,
`auto.chart.support.metric = "both"`, and
`auto.chart.selection.metric = "operator"`.

`chart.dim = "auto"` is part of the deployable real-data contract.  In
real geometries, including 16S relative-abundance data, the local
dimension is unknown and must be estimated from observed covariates, not
from latent coordinates or truth-side information.

HTML report: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k11_p7_lps_post_k10_backend_panel_2026-06-04/k11_p7_lps_post_k10_backend_panel.html`
Output directory: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k11_p7_lps_post_k10_backend_panel_2026-06-04`

## Results

- All effective selected models matched: TRUE
- Selected chart dimensions matched: TRUE
- Maximum absolute CV-RMSE table delta: 2.14588e-06
- Maximum absolute fitted-value delta: 4.66294e-15
- Maximum absolute Truth-RMSE delta: 8.32667e-17
- Descriptive median runtime ratio R/native: 0.753476

Status counts:

- cv_numeric_drift_selected_stable 3
- safe_machine_precision 2

## Recommendation

K11 supports using `cpp.local.pca` as an explicit opt-in backend on the focused high-dimensional and 16S-style panel because the effective selected models, fitted values, and Truth-RMSE values match the R reference. It does not support promoting the native backend to `backend = "auto"`; runtime is descriptive only and remains size- and geometry-dependent.

Treat runtime in this K11 panel as descriptive only.  K11 is a parity and
explicit-opt-in validation, not a durable benchmark for a speed claim.

Do not promote `cpp.local.pca` to `backend = "auto"` yet.  K11 supports
recorded, explicit opt-in use on focused P7-style panels, but the next
default-policy decision should be based on a broader size/dimension policy
or a backend chooser that records its decision.

## Validation

Run:

```sh
Rscript scripts/k11_p7_lps_post_k10_backend_panel.R
Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R", reporter="summary")'
Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge1-r-smoothers.R", reporter="summary")'
git diff --check
```
