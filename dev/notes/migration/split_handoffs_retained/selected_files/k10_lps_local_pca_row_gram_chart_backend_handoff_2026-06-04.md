# K10 Handoff: Row-Gram Local-PCA Chart Backend

Generated: 2026-06-04 22:02:19 EDT

## Change

K10 updates the shared native local-PCA chart constructor used by LPS and
other geosmooth chart-based smoothers. When the local support matrix has
fewer rows than ambient columns, the constructor now computes the PCA
spectrum from the smaller row-Gram matrix `centered %*% t(centered)` and
recovers the right singular vectors from `centered^T u / s`.

The existing Jacobi SVD path remains as a conservative fallback when the
row-Gram eigensolve fails or when the selected singular subspace is too
close to numerical rank deficiency.

## Scope

- This changes the shared chart primitive, not the public LPS API.
- `backend = "cpp.local.pca"` remains explicit opt-in.
- `backend = "auto"` is unchanged.
- K4.1 candidate-level chart caching remains in place.
- This is not a default-backend promotion.

## Benchmark

Benchmark CSV: /Users/pgajer/current_projects/geosmooth/split_handoffs/k10_lps_local_pca_row_gram_chart_backend_2026-06-04/k10_row_gram_chart_backend_benchmark.csv

The small wrapper-level benchmark checks singular values and projection
matrices against an R `svd()` subspace reference on three high-dimensional
local-support shapes. It is a correctness probe, not the primary speed
metric, because the exported chart wrapper returns full R objects and pays
Rcpp list-conversion overhead that the internal C++ CV loop does not pay.

- Maximum singular-value discrepancy: 4.2633e-14
- Maximum projector discrepancy: 5.2666e-15

## K9 Internal-Profile Rerun

Profile comparison CSV: /Users/pgajer/current_projects/geosmooth/split_handoffs/k10_lps_local_pca_row_gram_chart_backend_2026-06-04/k10_pre_post_k9_profile_comparison.csv

- Median chart-build speedup on high-dimensional/16S rows: 3.9946
- Median native CV speedup on high-dimensional/16S rows: 2.8064

## Validation

- `R CMD INSTALL --preclean /Users/pgajer/current_projects/geosmooth`: passed.
- Focused `test-ge7-lps-api.R`: passed.
- Focused `test-ge1-r-smoothers.R`: passed.
- Focused `test-ge4-ssrhe-hessian-energy.R`: passed.
- Existing K9 phase-profile script rerun after K10: passed.
- `make test`: passed with 883 checks, 9 expected split-era skips, and no failures or warnings.

## Interpretation

K10 targets the chart-construction primitive that dominated the hard
high-dimensional and 16S-style K9 profiling rows. It should reduce the
cost of individual `k << p` local PCA charts, but it does not reduce the
number of charts built. Large candidate grids can still be expensive when
many support sizes or chart dimensions are evaluated.

## Recommended Next Step

Ask for K10 audit. If accepted, proceed to K11: update the P7/LPS backend
preflight comparison to include the post-K10 `cpp.local.pca` backend on
the focused high-dimensional and 16S-style panel. Do not promote
`cpp.local.pca` into `backend = "auto"` until K11 confirms stable
end-to-end performance and fit parity outside the profiling rows.
