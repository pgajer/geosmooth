# PS-LPS C7 Solve/Search Decision Handoff

Build time: 2026-06-05 19:48:08 EDT

## Scope

C7 is a diagnostic decision phase after the C6 cache-aware profile audit.  It
uses repeated timings on the frozen `FB14 local.auto` stress case to separate:

- setup cost;
- isolated cached full-data solve cost;
- layer timing inside the cached solve;
- full end-to-end `fit.ps.lps()` cost as the number of positive
  `lambda.sync` candidates grows.

The purpose is to decide whether the next engineering phase should prioritize
low-level sparse-solver optimization or a smarter lambda-search policy.

## New Script and Report

- `scripts/profile_ps_lps_c7_decision.R`

Generated report:

- `split_handoffs/ps_lps_cache_backend_2026-06-05/c7_solve_search_decision_2026-06-05/ps_lps_c7_solve_search_decision_report.html`

Generated tables:

- `tables/ps_lps_c7_setup_timing.csv`
- `tables/ps_lps_c7_micro_raw.csv`
- `tables/ps_lps_c7_micro_summary.csv`
- `tables/ps_lps_c7_layer_raw.csv`
- `tables/ps_lps_c7_layer_summary.csv`
- `tables/ps_lps_c7_end_to_end_raw.csv`
- `tables/ps_lps_c7_end_to_end_summary.csv`

Generated figures:

- `figures/ps_lps_c7_end_to_end_grid_size.png`
- `figures/ps_lps_c7_micro_per_lambda.png`
- `figures/ps_lps_c7_layer_timing.png`

## Design

The stress case is:

- `FB14`, `SYN-RANK-BLOCKS-N600-P100`;
- `chart_dim_rule = local.auto`;
- `support.size = 35`;
- `degree = 2`;
- `kernel = gaussian`;
- `lambda.ridge = 1e-8`;
- `sync.neighbor.size = 3`.

Repeated timing design:

- isolated cached full-data solve grids: sizes `1, 3, 7, 11`, five repeats;
- layer timing grid: seven positive lambdas, five repeats;
- full end-to-end `fit.ps.lps()` grids: sizes `1, 3, 7`, three repeats.

## Main Results

Setup timings:

| Phase | Elapsed sec |
|---|---:|
| prepare frames | 1.453 |
| prepare sync rows | 0.036 |
| prepare full component cache | 0.310 |
| prepare fold component caches | 1.278 |

Isolated cached full-data solve medians:

| Grid size | Median sec | IQR sec | Median sec per lambda |
|---:|---:|---:|---:|
| 1 | 0.415 | 0.030 | 0.415 |
| 3 | 1.194 | 0.006 | 0.398 |
| 7 | 2.792 | 0.071 | 0.399 |
| 11 | 4.459 | 0.120 | 0.405 |

End-to-end cache-aware `fit.ps.lps()` medians:

| Grid size | Median sec | IQR sec | Median sec per lambda |
|---:|---:|---:|---:|
| 1 | 5.094 | 0.176 | 5.094 |
| 3 | 8.645 | 0.085 | 2.882 |
| 7 | 15.664 | 0.428 | 2.238 |

A simple linear fit to median end-to-end timings estimates about `1.761`
seconds per additional positive `lambda.sync` candidate on this stress case.
A simple linear fit to isolated cached full-data solves estimates about `0.404`
seconds per additional positive lambda.

Layer timing medians were stable across `lambda.sync`:

- normal-matrix combination: about `0.039` to `0.042` sec;
- full solve wall time: about `0.227` to `0.230` sec;
- reported ridge-normal formation: about `0.031` to `0.035` sec;
- reported `Matrix::solve`: about `0.187` to `0.189` sec;
- diagnostics: about `0.007` sec.

## Interpretation

The strongest conclusion is that the remaining cost is approximately linear in
the number of positive `lambda.sync` candidates.  On this stress case, skipping
one lambda candidate saves meaningful time in the exported fitter path.

The low-level solve layer still matters.  In an isolated full-data solve, the
largest reported component is `Matrix::solve`, around `0.188` sec per lambda,
and normal-matrix combination plus ridge-normal formation is around
`0.07` sec per lambda.  That said, even a substantial low-level speedup would
only improve every solve by a fraction of a second, while a smarter search
policy can skip whole fold/diagnostic/final solve bundles.

## Recommendation

Proceed next to a search-policy prototype rather than invasive sparse-solver
work.

Recommended next phase:

**C8: PS-LPS lambda-search policy prototype.**

C8 should implement a small internal search runner that uses the C5 component
cache and compares:

1. full grid search;
2. a coarse-to-refine bracketed search over `log10(lambda.sync)`;
3. optional local refinement around the best coarse candidate;
4. a conservative guard policy that always includes a few boundary candidates
   and `lambda.sync = 0` when requested.

C8 should evaluate whether the search policy recovers the same selected
candidate or nearly the same CV RMSE with fewer positive lambda solves.  The
primary metric should be candidate count and elapsed time reduction, with CV
RMSE regret relative to full grid as the correctness guard.
