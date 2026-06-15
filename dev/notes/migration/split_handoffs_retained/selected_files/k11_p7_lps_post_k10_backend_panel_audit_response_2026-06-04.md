# K11 Audit Response: P7 LPS Post-K10 Backend Panel

Generated: 2026-06-04 23:00:00 EDT

Responds to:

```text
/Users/pgajer/current_projects/geosmooth/split_handoffs/k11_p7_lps_post_k10_backend_panel_audit_2026-06-04.md
```

## Changes Made

### Selected-candidate parity now includes chart dimension

The K11 generator now treats the effective selected model as:

```text
(chart.dim, selected.support.size, selected.degree, selected.kernel)
```

instead of only:

```text
(selected.support.size, selected.degree, selected.kernel)
```

The regenerated delta table includes:

```text
selected.chart.dim.same
```

and all five K11 rows have `selected.same = TRUE` and
`selected.chart.dim.same = TRUE`.

### Runtime is now explicitly descriptive only

The regenerated handoff and HTML report no longer treat runtime as durable
speed evidence. They describe runtime as rerun-sensitive and dependent on
geometry, sample size, ambient dimension, selected chart dimension, and support
grid.

The current rerun has descriptive median runtime ratio:

```text
R-reference / native = 0.753476
```

so this K11 bundle supports fit/CV parity and explicit opt-in validation, not a
speed claim.

### `chart.dim = "auto"` is now stated as the real-data contract

The regenerated handoff and HTML report explicitly state that
`chart.dim = "auto"` should remain the deployable real-data contract. For real
geometries such as 16S relative-abundance data, the local dimension is unknown
and must be estimated from observed covariates rather than supplied from latent
coordinates or truth-side information.

## Regenerated Artifacts

```text
/Users/pgajer/current_projects/geosmooth/scripts/k11_p7_lps_post_k10_backend_panel.R
/Users/pgajer/current_projects/geosmooth/split_handoffs/k11_p7_lps_post_k10_backend_panel_handoff_2026-06-04.md
/Users/pgajer/current_projects/geosmooth/split_handoffs/k11_p7_lps_post_k10_backend_panel_2026-06-04/k11_p7_lps_post_k10_backend_panel.html
/Users/pgajer/current_projects/geosmooth/split_handoffs/k11_p7_lps_post_k10_backend_panel_2026-06-04/tables/k11_lps_backend_delta_summary.csv
/Users/pgajer/current_projects/geosmooth/split_handoffs/k11_p7_lps_post_k10_backend_panel_2026-06-04/tables/k11_lps_backend_summary_long.csv
/Users/pgajer/current_projects/geosmooth/split_handoffs/k11_p7_lps_post_k10_backend_panel_2026-06-04/tables/k11_lps_backend_cv_tables_long.csv
/Users/pgajer/current_projects/geosmooth/split_handoffs/k11_p7_lps_post_k10_backend_panel_2026-06-04/k11_lps_backend_results.rds
```

## Verification

Passed:

```sh
Rscript scripts/k11_p7_lps_post_k10_backend_panel.R
Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R", reporter="summary")'
Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge1-r-smoothers.R", reporter="summary")'
Rscript -e 'd<-read.csv("split_handoffs/k11_p7_lps_post_k10_backend_panel_2026-06-04/tables/k11_lps_backend_delta_summary.csv"); stopifnot(all(d$selected.same), all(d$selected.chart.dim.same))'
git diff --check
```

## Proposed Next Step: K12 Backend Policy and Auto-Dimension Contract

K12 should not promote `cpp.local.pca` to `backend = "auto"`. Instead, K12
should freeze a backend policy document and package-facing diagnostics for
local-PCA LPS:

1. Keep `chart.dim = "auto"` as the required real-data default for local-PCA
   LPS, with `auto.chart.support.metric = "both"` and
   `auto.chart.selection.metric = "operator"` in P7-style runs.
2. Keep `backend = "auto"` conservative for now.
3. Permit `backend = "cpp.local.pca"` as an explicit opt-in backend when
   `backend.used`, `chart.dim`, selected support size, selected degree,
   selected kernel, and CV score are recorded.
4. Add a small backend diagnostics helper or report table that records:
   requested backend, used backend, requested chart dimension, resolved chart
   dimension, auto-dimension support metric, auto-dimension selection metric,
   candidate count, and runtime.
5. Run any future repeated benchmark panel only as a default-policy study, not
   as a prerequisite for using explicit `cpp.local.pca`.

This keeps the real-data dimension issue clean: we estimate local dimension
from observed covariates and do not use latent or truth-side information.
