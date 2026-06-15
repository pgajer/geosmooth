# K3.8 LPS VALENCIA Scalability Plan

Date: 2026-06-04

## Objective

K3.8 is a focused scalability and geometry-sensitivity benchmark for the
`geosmooth::fit.lps()` local polynomial smoother (LPS) on realistic
VALENCIA-derived compositional geometries.  It is not a broad SLPLiFT
performance study and it does not evaluate the experimental Harlim
second-order chart mode.

The question is:

> How does LPS runtime and prediction quality behave on small-to-moderate
> 16S-derived compositional geometries, and does ordinary local-PCA chart mode
> help or hurt relative to ambient-coordinate LPS?

## Phase K3.8a: Freeze Benchmark Dataset Families

Use existing `linf` package assets and the local VALENCIA 13k source matrix.

Dataset families:

1. `rel4`: bundled 1,000-sample Li/Lc/Gv/Bv composition from
   `linf::valencia_linf_hypercube_1k`.
2. `hypercube_Li`: hypercube embedding of `rel4` with `Li` as reference.
3. `hypercube_Gv`: hypercube embedding of `rel4` with `Gv` as reference.
4. `depth2_top`: full VALENCIA 13k projected to the unique taxa appearing in
   the top depth-2 merged DCST labels from
   `linf::valencia13k_dcst_depth2_merged`.
5. `depth3_top`: full VALENCIA 13k projected to the unique taxa appearing in
   the top depth-3 merged DCST labels from
   `linf::valencia13k_dcst_depth3_merged`.

Initial sample sizes:

- `n = 250`;
- `n = 500`.

Sampling is deterministic and stratified when a dominant-component label is
available.  Otherwise the script uses a fixed random seed and source-row order.

## Phase K3.8b: Synthetic Truth and LPS Benchmark

For each frozen geometry, define a smooth non-spiky synthetic response as a
mixture of Gaussian bumps in the observed benchmark coordinates:

```text
f(x) = sum_j a_j exp(-||x - c_j||^2 / (2 sigma_j^2)).
```

Centers are selected deterministically from robust principal-component score
quantiles.  Noise is Gaussian with standard deviation `0.10 * sd(f)`.

Compare two deployable LPS modes:

1. Ambient-coordinate LPS:

   ```r
   coordinate.method = "coordinates"
   backend = "cpp"
   ```

2. Ordinary local-PCA LPS:

   ```r
   coordinate.method = "local.pca"
   chart.dim = "auto"
   local.chart.method = "pca"
   backend = "R"
   ```

Candidate grid for the first bounded run:

- `support.grid = c(15, 25, 35)`;
- `degree.grid = c(1, 2)`;
- `kernel.grid = c("gaussian", "tricube")`;
- `cv.folds = 3`.

Metrics:

- runtime seconds;
- selected support size, degree, kernel, chart dimension;
- observed RMSE;
- truth RMSE;
- CV RMSE;
- failure status and error message;
- local-PCA auto-dimension diagnostics when available.

## Phase K3.8c: Report and Optimization Targets

Generate:

- CSV results;
- serialized result bundle;
- HTML report with readable dot plots and compact tables.

Report questions:

1. Which geometry/mode combinations are slowest?
2. Does local-PCA LPS improve truth RMSE on these VALENCIA-derived geometries?
3. Does local-PCA LPS select plausible chart dimensions?
4. Are failures or degenerate selections present?
5. Which optimization target is most justified next:
   kNN reuse, chart caching, C++ local-PCA chart integration, weighted least
   squares cleanup, or parallel batching?

## Deliberate Non-Goals

- Do not use the Harlim second-order SVD chart in K3.8.
- Do not compare SLPLiFT, MALPS, LPL-TF, graph trend filtering, or SSRHE.
- Do not use dense grid oracle references.
- Do not run an overnight-scale experiment until the first K3.8 bounded report
  identifies the bottleneck.

## Expected Outputs

Under:

```text
split_handoffs/k3_8_lps_valencia_scalability_2026-06-04/
```

create:

- `k3_8_lps_valencia_scalability_results.csv`;
- `k3_8_lps_valencia_scalability_bundle.rds`;
- `k3_8_lps_valencia_scalability_report.html`;
- `k3_8_lps_valencia_scalability_report_files/` for report figures.

The script should be rerunnable from the package root:

```sh
Rscript scripts/k3_8_lps_valencia_scalability.R
```
