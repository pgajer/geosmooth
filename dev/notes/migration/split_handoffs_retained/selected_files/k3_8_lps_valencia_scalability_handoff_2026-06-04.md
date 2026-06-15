# K3.8 LPS VALENCIA Scalability Handoff

Date: 2026-06-04

## Scope

Implemented and executed the first bounded K3.8 benchmark:

- VALENCIA-derived 16S compositional geometries;
- LPS only;
- ambient-coordinate LPS versus ordinary local-PCA LPS;
- no Harlim second-order chart mode;
- no SLPLiFT/MALPS/LPL/SSRHE comparisons.

This run is intended to identify whether local-PCA LPS is worth optimizing and
where the bottleneck appears, not to make final method-performance claims.

## Files Added

- `split_handoffs/k3_8_lps_valencia_scalability_plan_2026-06-04.md`
- `scripts/k3_8_lps_valencia_scalability.R`
- `split_handoffs/k3_8_lps_valencia_scalability_2026-06-04/k3_8_lps_valencia_scalability_results.csv`
- `split_handoffs/k3_8_lps_valencia_scalability_2026-06-04/k3_8_lps_valencia_scalability_bundle.rds`
- `split_handoffs/k3_8_lps_valencia_scalability_2026-06-04/k3_8_lps_valencia_scalability_report.html`
- report figure files under
  `split_handoffs/k3_8_lps_valencia_scalability_2026-06-04/k3_8_lps_valencia_scalability_report_files/`

## Design

Datasets:

- `rel4`: bundled Li/Lc/Gv/Bv 4D composition;
- `hypercube_Li`: Li-reference hypercube embedding;
- `hypercube_Gv`: Gv-reference hypercube embedding;
- `depth2_top`: VALENCIA source projected to taxa appearing in the top 8
  depth-2 merged DCST labels;
- `depth3_top`: VALENCIA source projected to taxa appearing in the top 10
  depth-3 merged DCST labels.

Sample sizes:

- `n = 250`;
- `n = 500`.

Candidate grid:

- `support.grid = c(15, 25, 35)`;
- `degree.grid = c(1, 2)`;
- `kernel.grid = c("gaussian", "tricube")`;
- `cv.folds = 3`.

Methods:

- `ambient_cpp`: `coordinate.method = "coordinates"`, `backend = "cpp"`;
- `local_pca_auto`: `coordinate.method = "local.pca"`,
  `chart.dim = "auto"`, `local.chart.method = "pca"`, `backend = "R"`.

Synthetic truth:

- deterministic Gaussian-mixture truth functions in each benchmark coordinate
  system;
- Gaussian noise with `sd = 0.10 * sd(f)`.

## Results

All 20 fits succeeded.

Runtime summary:

- ambient-coordinate C++ LPS median runtime: `0.0525` seconds;
- local-PCA auto-chart LPS median runtime: `0.5900` seconds;
- median runtime ratio, local-PCA over ambient: `9.64x`.

Truth RMSE summary:

- ambient-coordinate median Truth RMSE: `0.05566`;
- local-PCA auto-chart median Truth RMSE: `0.04767`;
- local-PCA had lower Truth RMSE in 5 of 10 paired dataset/sample-size cases.

Largest local-PCA improvements:

- `hypercube_Gv`, `n = 250`: delta `-0.09486`;
- `depth3_top`, `n = 250`: delta `-0.05731`;
- `depth2_top`, `n = 250`: delta `-0.02716`.

Largest local-PCA losses:

- `hypercube_Gv`, `n = 500`: delta `+0.03926`;
- `depth3_top`, `n = 500`: delta `+0.03311`.

Interpretation:

- local-PCA LPS can help on some VALENCIA-derived geometries, especially in
  lower-n runs and some hypercube/DCST-derived coordinates;
- it is not uniformly better;
- the current local-PCA path is roughly an order of magnitude slower than the
  ambient C++ path even on small benchmark sizes;
- if local-PCA is retained as a serious candidate, the next engineering target
  should be accelerating and/or caching the local chart path.

## Validation

Commands run from `/Users/pgajer/current_projects/geosmooth`:

```sh
Rscript scripts/k3_8_lps_valencia_scalability.R
git diff --check
```

Results:

- K3.8 script completed and wrote CSV/RDS/HTML outputs;
- all 20 fits succeeded;
- `git diff --check`: clean.

## Recommended Next Step

Proceed with **K3.9: Local-PCA LPS Acceleration Audit** before expanding the
benchmark grid.

Specific K3.9 tasks:

1. Profile `local_pca_auto` LPS on the slowest K3.8 case:
   `depth3_top`, `n = 500`.
2. Split runtime into:
   - neighbor search and support ordering;
   - local PCA chart construction;
   - design matrix construction;
   - weighted least squares solve;
   - CV overhead versus final full-data fit.
3. Determine whether the fastest improvement is:
   - C++ local-PCA chart construction inside the LPS prediction loop;
   - caching local charts/design matrices across candidate degrees/kernels;
   - kNN/support reuse across candidates and CV folds;
   - parallelization over evaluation points or CV folds.
4. Only after K3.9, decide whether K3.10 should run `n = 1000` and/or a wider
   VALENCIA depth-2/depth-3 dataset family.
