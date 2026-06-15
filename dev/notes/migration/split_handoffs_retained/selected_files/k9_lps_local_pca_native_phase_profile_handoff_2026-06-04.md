# K9 Handoff: LPS Local-PCA Native Phase Profile

## Scope

K9 profiles the explicit `backend = "cpp.local.pca"` path for
`fit.lps(coordinate.method = "local.pca")`.  It does not change
package defaults.

## Script and Outputs

Script: `/Users/pgajer/current_projects/geosmooth/scripts/k9_lps_local_pca_native_phase_profile.R`

Output directory: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k9_lps_local_pca_native_phase_profile_2026-06-04`

HTML report: `/Users/pgajer/current_projects/geosmooth/split_handoffs/k9_lps_local_pca_native_phase_profile_2026-06-04/k9_lps_local_pca_native_phase_profile.html`

## Key Result

The native profiler decomposes CV time into fold partitioning, ANN tree
construction, ANN search, deterministic tie recovery, neighbor extraction,
kernel weights, local PCA chart construction, local polynomial solves,
accumulation, and RMSE assembly.

The profile validates that the profiled native RMSE values match the
unprofiled native CV backend to the tolerance recorded in
`tables/k9_profile_summary.csv`.

The phase table supports the chart-construction conclusion only with the
intended qualification.  `chart_build` dominates the hard
high-dimensional and deterministic 16S profiling rows, while the ordinary
controlled 1D row is dominated by `local_solve`:

- `p7d_1d_two_gaussian_v1`: top phase `local_solve` (85.01%); `chart_build` share 12.41%; sample policy `full_dataset` with n = 200.
- `p7d_hd1_latent_two_gaussian_v1`: top phase `chart_build` (66.32%); `chart_build` share 66.32%; sample policy `full_dataset` with n = 200.
- `p7d_hd3_latent_four_gaussian_v1`: top phase `chart_build` (73.19%); `chart_build` share 73.19%; sample policy `full_dataset` with n = 600.
- `p7d_16s_graph_gaussian_farthest3_v1`: top phase `chart_build` (62.93%); `chart_build` share 62.93%; sample policy `deterministic_16s_subset_n500` with n = 500.

The full 16S row was intentionally not profiled after an initial attempt
ran too long.  The final K9 report uses a deterministic 16S subset of
500 rows, labeled `deterministic_16s_subset_n500`, so that row is a
profiling stress case rather than a P7 performance result.

## Recommendation

K9 shows that chart_build is the dominant native phase on the hard high-dimensional and 16S profiling rows. ANN search and deterministic tie recovery are measurable but not the primary bottleneck. The next optimization should therefore target local PCA chart construction: avoid redundant SVD work across support sizes and chart dimensions where possible, consider prefix/nested-support reuse, and only then optimize the local polynomial solve path. Do not promote cpp.local.pca to backend = 'auto' until this chart-construction bottleneck is addressed or a size/dimension-dependent backend chooser is justified.

Do not promote `cpp.local.pca` to `backend = "auto"` yet.  The next
optimization should target local PCA chart construction on the hard rows,
not the whole LPS pipeline blindly.  K9 is also not a broad speedup result:
native end-to-end elapsed time was slower than the R path on three of the
four profiled rows.

## Validation

Run:

```sh
Rscript scripts/k9_lps_local_pca_native_phase_profile.R
git diff --check
```
