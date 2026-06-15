# PS-LPS C11 Policy-Readiness Handoff

Build time: 2026-06-05 22:03:00 EDT

## Scope

C11 evaluated whether the C10 guarded `lambda.sync` search policy is ready to
use as the PS-LPS policy in the next prospective experiment campaign.

This was a policy-readiness analysis phase. It did not change package source or
the default `fit.ps.lps()` behavior. The package-facing default remains exact
grid search unless the caller explicitly requests

```r
lambda.sync.search = "guarded"
```

## Assets

- Script:
  `/Users/pgajer/current_projects/geosmooth/scripts/profile_ps_lps_c11_policy_readiness.R`
- HTML report:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/c11_policy_readiness_2026-06-05/ps_lps_c11_policy_readiness_report.html`
- Policy metrics:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/c11_policy_readiness_2026-06-05/tables/ps_lps_c11_policy_metrics.csv`
- Policy summary:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/c11_policy_readiness_2026-06-05/tables/ps_lps_c11_policy_summary.csv`
- Selected-lambda mismatches:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/c11_policy_readiness_2026-06-05/tables/ps_lps_c11_lambda_mismatches.csv`
- Pointwise delta diagnostics:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/c11_policy_readiness_2026-06-05/tables/ps_lps_c11_pointwise_delta.csv`
- Pointwise delta summary:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/c11_policy_readiness_2026-06-05/tables/ps_lps_c11_pointwise_delta_summary.csv`
- Failures:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/c11_policy_readiness_2026-06-05/tables/ps_lps_c11_failures.csv`

## Validation Design

C11 used the frozen first-batch non-manifold LPS/PS-LPS examples. For each of
the 14 datasets, the script evaluated both chart-dimension policies:

```r
chart.dim = "auto"
chart.dim = "local.auto"
```

This gives 28 dataset-by-chart-rule cases.

The exact reference used the expanded C10 `lambda.sync` grid:

```r
c(min.positive / 9, min.positive / 3, base.grid,
  max.positive * 3, max.positive * 9)
```

The exact reference also used the practical 0.2% tie rule. The guarded variants
were:

- `guarded_default`: the C10 guarded policy with default boundary controls;
- `guarded_strict_edge`: guarded search with a stricter near-boundary guard,
  `boundary.guard.rel.tol = 0.002`;
- `guarded_one_expansion`: guarded search with at most one boundary expansion.

The analysis compared:

- selected `lambda.sync`;
- candidate count;
- elapsed time;
- observed RMSE;
- Truth RMSE;
- fitted-value RMSE relative to exact reference;
- pointwise Truth-RMSE delta components.

## Results

There were no fit failures. The failures table contains only the header row.

Against the exact expanded-grid reference:

| Variant | Selected-lambda agreement | Mean Truth RMSE delta | Median Truth RMSE delta | Max absolute Truth RMSE delta | Mean candidates | Median candidates | Mean elapsed seconds | Median elapsed seconds |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Guarded default | 27 / 28 | -0.001638 | 0 | 0.045871 | 9.68 | 10.0 | 3.56 | 1.15 |
| Guarded stricter edge | 26 / 28 | -0.002728 | 0 | 0.045871 | 9.43 | 10.0 | 3.52 | 1.09 |
| Guarded one expansion | 23 / 28 | -0.006687 | 0 | 0.063499 | 9.43 | 9.5 | 3.40 | 1.10 |

The exact expanded reference evaluated 19 candidates per case. The guarded
policies therefore cut the typical candidate count by roughly half.

All selected-lambda mismatches had negative Truth RMSE delta relative to the
exact expanded reference. In other words, in the mismatch cases the guarded
variant had lower synthetic truth error, even though it accepted a slightly
worse observed-CV score.

The most important mismatch was:

- dataset `FB08`, `LA-D3-RAW-N500`, `chart.dim = "auto"`;
- exact reference selected `lambda.sync = 2700`;
- guarded default selected `lambda.sync = 10`;
- exact Truth RMSE was `0.078771`;
- guarded-default Truth RMSE was `0.032900`;
- Truth RMSE delta was `-0.045871`.

This suggests that the expanded exact-CV reference can sometimes chase a
high-lambda CV basin that is not truth-optimal on these synthetic examples. The
guarded policy's boundary discipline acted like a mild regularization of the
tuning process in these cases.

## Interpretation

C11 supports using `guarded_default` as the PS-LPS search policy for the next
prospective experiment campaign.

The reason is not only speed. The guarded default matched the expanded exact
reference in 27 of 28 cases, used about half as many candidates, and the single
selected-lambda mismatch improved Truth RMSE on the synthetic benchmark. That
is the most conservative positive signal among the guarded variants.

The `guarded_one_expansion` variant is more aggressive. It produced lower mean
Truth RMSE in this C11 suite, but it changed the selected lambda in 5 of 28
cases. It should be treated as an exploratory regularizing selector, not as the
main prospective policy.

The package default should remain exact grid search for now. C11 is enough to
freeze an experiment-facing policy, but not enough to promote guarded search to
the package API default.

## Recommended Next Step

Proceed to C12 as the prospective-policy freeze and experiment-preparation
phase.

Specific C12 tasks:

1. Freeze `guarded_default` as the PS-LPS policy for the next prospective
   experiments, while keeping exact grid search as the package default and audit
   reference.
2. Add a short policy note to the PS-LPS progress report documenting:
   - exact-grid default behavior;
   - guarded-search experiment policy;
   - the practical 0.2% tie rule;
   - the boundary-expansion and near-boundary guard;
   - the reason `guarded_one_expansion` is exploratory only.
3. Update the prospective experiment scripts to use:

   ```r
   lambda.sync.search = "guarded"
   lambda.sync.search.control = list()
   ```

   or the equivalent explicit C10 default controls:

   ```r
   lambda.sync.search.control = list(
     coarse.size = 5L,
     refine.radius = 2L,
     rel.tol = 0.002,
     boundary.guard.rel.tol = 0.01,
     boundary.expand = TRUE,
     boundary.factor = 3,
     max.boundary.expansions = 2L,
     max.candidates = 25L
   )
   ```
4. Persist PS-LPS search telemetry in future experiment outputs:
   selected `lambda.sync`, candidate count, boundary expansion count, evaluated
   grid, selected CV score, raw best CV score, and practical-tie threshold.
5. In the next PS-LPS/LPS comparison report, include an audit panel comparing
   guarded selected fits to an exact-grid reference on a small subset, so the
   experiment remains auditable without paying exact-grid cost everywhere.
