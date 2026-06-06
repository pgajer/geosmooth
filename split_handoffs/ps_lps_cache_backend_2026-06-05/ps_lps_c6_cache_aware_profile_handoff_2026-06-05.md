# PS-LPS C6 Cache-Aware Profile Handoff

Build time: 2026-06-05 19:33:27 EDT

## Scope

C6 profiles the cache-aware exported `fit.ps.lps()` path introduced in C5 and
compares it against a reconstructed direct tuning loop that calls
`.ps.lps.solve()` for every fold, full-data diagnostic solve, and final fit.

The goal is to answer two questions:

1. Does the component-cache backend improve an end-to-end exported fitter path?
2. After C5, what is the next bottleneck?

## New Script and Report

- `scripts/profile_ps_lps_cache_aware_c6.R`

Generated report:

- `split_handoffs/ps_lps_cache_backend_2026-06-05/c6_cache_aware_profile_2026-06-05/ps_lps_c6_cache_aware_profile_report.html`

Generated tables:

- `tables/ps_lps_c6_timing_summary.csv`
- `tables/ps_lps_c6_cv_parity.csv`
- `tables/ps_lps_c6_cache_final_solve_timings.csv`
- `tables/ps_lps_c6_Rprof_by_total_top100.csv`

Generated figures:

- `figures/ps_lps_c6_elapsed_comparison.png`
- `figures/ps_lps_c6_speedup.png`
- `figures/ps_lps_c6_rprof_top_total.png`

## Profile Cases

C6 uses frozen first-batch non-manifold/local-dimension assets:

- `FB01`, `LA-D1-RAW-N500`, `chart_dim_rule = auto`;
- `FB09`, `LA-13K-SUB-N500`, `chart_dim_rule = auto`;
- `FB14`, `SYN-RANK-BLOCKS-N600-P100`, `chart_dim_rule = local.auto`.

Each case is profiled under two lambda grids:

- `mixed_4`: `c(0, 0.1, 1, 10)`;
- `positive_7`: `c(0.01, 0.03, 0.1, 0.3, 1, 3, 10)`.

The direct loop and cache-aware fitter use the same support size, degree,
kernel, folds, chart dimensions, `lambda.ridge = 1e-8`, and
`sync.neighbor.size = 3`.

## Main Results

The cache-aware fitter matched the direct loop to numerical precision:

- maximum CV RMSE delta ranged from approximately `9.4e-15` to `6.5e-13`,
  except the high-dimensional `FB09` case where the maximum delta was still only
  about `4.9e-9`;
- maximum final fitted-value delta was about `4e-13` to `5.3e-13`;
- selected `lambda.sync` matched in every profiled case.

End-to-end speedups:

| Case | Grid | Direct sec | Cache sec | Speedup |
|---|---:|---:|---:|---:|
| FB01 auto | mixed_4 | 2.767 | 0.663 | 4.17 |
| FB01 auto | positive_7 | 5.804 | 0.862 | 6.73 |
| FB09 auto | mixed_4 | 2.127 | 1.286 | 1.65 |
| FB09 auto | positive_7 | 3.937 | 1.858 | 2.12 |
| FB14 local.auto | mixed_4 | 13.522 | 10.118 | 1.34 |
| FB14 local.auto | positive_7 | 28.224 | 17.051 | 1.66 |

## Bottleneck Interpretation

The cache backend clearly helps end to end, especially when the lambda grid is
larger.  The C5/C6 cache design is therefore validated.

The Rprof target was `FB14 local.auto` with the seven-positive-lambda grid.  The
dominant sampled functions were:

- `.ps.lps.solve.component.cached`;
- `.ps.lps.solve.normal.cached`;
- `Matrix::solve`;
- `Cholesky`;
- sparse matrix arithmetic/conversion around forming the normal matrix.

This means the main bottleneck has moved away from triplet assembly and
crossproduct recomputation and toward sparse normal-matrix combination and
factorization/solve.

## Recommendation

C6 does not suggest that more triplet-assembly work is the best next step.

Recommended next phase:

**C7: solve-path and search-policy decision phase.**

Suggested C7 tasks:

1. run one larger candidate-grid profile using the cache-aware path to estimate
   the cost per additional positive `lambda.sync`;
2. prototype one solve-path improvement, such as avoiding repeated sparse-class
   conversions when forming
   `C_data + lambda.sync * C_sync + rho I`;
3. compare that expected gain with a smarter lambda-search policy that reduces
   the number of solves;
4. decide whether PS-LPS should next invest in low-level sparse solver
   optimization or in a practical candidate-search strategy.

