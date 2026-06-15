# K10 Pre/Post K9 Profile Comparison Provenance

Generated: 2026-06-04

This note documents the provenance of:

```text
/Users/pgajer/current_projects/geosmooth/split_handoffs/k10_lps_local_pca_row_gram_chart_backend_2026-06-04/k10_pre_post_k9_profile_comparison.csv
```

The CSV is a small manually assembled audit table comparing the same K9 phase
profile rows before and after K10.

The **pre-K10** values were copied from the K9 profile artifacts saved before
the row-Gram local-PCA chart backend was installed. During K10 work these
pre-K10 artifacts were preserved under:

```text
/tmp/geosmooth_k9_pre_k10
```

The **post-K10** values were copied from the regenerated K9 profile summary:

```text
/Users/pgajer/current_projects/geosmooth/split_handoffs/k9_lps_local_pca_native_phase_profile_2026-06-04/tables/k9_profile_summary.csv
```

The compared rows are matched by `dataset.id`, `truth.id`,
`geometry.family`, `n`, and `ambient.dimension`.  The reported speedup columns
are simple ratios:

```text
cpp_fit_speedup = cpp.fit.elapsed.seconds.pre_k10 /
                  cpp.fit.elapsed.seconds.post_k10

cpp_cv_speedup = cpp.cv.unprofiled.seconds.pre_k10 /
                 cpp.cv.unprofiled.seconds.post_k10

chart_build_speedup = seconds.pre_k10 / seconds.post_k10
```

This table is therefore a durable provenance note for the K10 speedup claim,
but it is not a standalone regeneration script.  If K9 is rerun again under a
new backend, a future phase should either archive the old K9 outputs in-repo or
replace this note with a small generator that takes explicit pre/post K9 table
paths.
