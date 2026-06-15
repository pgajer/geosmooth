# K7 P7 LPS Native Opt-In Preflight Comparison Handoff

## Scope

K7 evaluates the explicit P7 local-PCA LPS backend option introduced in K6:

```text
--lps-local-pca-backend=cpp.local.pca
```

The goal is not to promote the native backend to `backend = "auto"`. The goal
is to check whether the P7 LPS path can use the native backend explicitly and
whether the selected fit, candidate CV table, and metadata agree with the R
reference backend on the P7 preflight dataset.

## Split-Aware P7 Patch

The broad P7 preflight initially failed at setup validation because the baseline
registry still treated graph Laplacian smoothing and graph trend filtering as
`gflow`-owned methods. After the package split, those methods are available from
`geosmooth`.

Updated:

- `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/config/p7_baseline_method_registry.csv`
- `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/scripts/p7_baseline_fitters.R`

The registry now marks graph Laplacian and graph trend filtering engines as
`geosmooth`. The fitter helper now resolves graph engine functions from
`geosmooth`, `dgraphs`, or `gflow` namespaces explicitly instead of relying on
unqualified functions attached to the search path.

Validation:

```sh
Rscript scripts/validate_p7a_baseline_roster.R
```

passed after the patch.

## Full P7 Preflight Attempt

I attempted:

```sh
Rscript scripts/run_p7e_prospective_orchestrator.R \
  --mode=preflight \
  --run-id=k7_lps_backend_auto_preflight2_20260604 \
  --workers=4 \
  --heavy-workers=2 \
  --lps-local-pca-backend=auto
```

Setup validation passed, but the run spent several minutes in the first
SLPLiTF selector before reaching the LPS baseline layer. Since K7 is specifically
about LPS backend integration, I terminated that broad preflight and replaced it
with the focused LPS-only comparison below. The partial run directory is left in
place as evidence:

```text
/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/runs/k7_lps_backend_auto_preflight2_20260604
```

## Focused K7 LPS Comparison

Script:

```text
/Users/pgajer/current_projects/geosmooth/scripts/k7_p7_lps_backend_preflight_comparison.R
```

Output directory:

```text
/Users/pgajer/current_projects/geosmooth/split_handoffs/k7_p7_lps_backend_preflight_comparison_2026-06-04
```

The script uses the actual P7 preflight dataset:

```text
p7d_1d_two_gaussian_v1__noise_sd010_r01
```

It uses the same P7 materialization helpers, fold IDs, baseline support grid,
local-PCA LPS settings, and P7 `p7.fit.lps()` wrapper. It compares:

- `backend = "auto"`: current reference path, `backend.used = "R"`;
- `backend = "cpp.local.pca"`: explicit native local-PCA path.

Run command:

```sh
Rscript scripts/k7_p7_lps_backend_preflight_comparison.R
```

## Results

Summary table:

```text
/Users/pgajer/current_projects/geosmooth/split_handoffs/k7_p7_lps_backend_preflight_comparison_2026-06-04/tables/k7_lps_backend_summary.csv
```

Main outcome:

| run label | backend used | selected support | selected degree | selected kernel | selected CV RMSE | Truth RMSE | runtime seconds |
|---|---:|---:|---:|---|---:|---:|---:|
| auto | R | 24 | 2 | tricube | 0.10216 | 0.0399263 | 0.786 |
| cpp.local.pca | cpp.local.pca | 24 | 2 | tricube | 0.10216 | 0.0399263 | 0.058 |

Candidate CV-table comparison:

```text
/Users/pgajer/current_projects/geosmooth/split_handoffs/k7_p7_lps_backend_preflight_comparison_2026-06-04/tables/k7_lps_backend_cv_table_comparison.csv
```

The maximum absolute candidate CV-RMSE difference between native and R was:

```text
1.110223e-16
```

Fitted-value comparison:

```text
/Users/pgajer/current_projects/geosmooth/split_handoffs/k7_p7_lps_backend_preflight_comparison_2026-06-04/tables/k7_lps_backend_fitted_delta.csv
```

The maximum absolute fitted-value difference was:

```text
2.220446e-15
```

The fitted-value RMSE difference was:

```text
3.329024e-16
```

## Interpretation

On this P7 preflight LPS-only comparison, the native local-PCA backend is
effectively identical to the R reference path for:

- selected candidate;
- selected observed CV RMSE;
- selected Truth RMSE;
- full candidate CV table;
- final fitted values.

Runtime improved from 0.786 seconds to 0.058 seconds, about a 13.5x speedup for
this small P7 preflight LPS grid.

This is encouraging, but it does not overturn the K5.1 caveat: K5.1 found
candidate-table drift in a separate exact-plane diagnostic. Therefore the native
local-PCA backend should remain explicit opt-in and should not yet become the
default `backend = "auto"` path.

## Validation

Passed:

```sh
Rscript scripts/validate_p7a_baseline_roster.R
Rscript scripts/k7_p7_lps_backend_preflight_comparison.R
git diff --check
```

`git diff --check` passed in both:

- `/Users/pgajer/current_projects/geosmooth`
- `/Users/pgajer/current_projects/trend_filtering`

No generated native build artifacts remained under `geosmooth/src`.

## Recommendation

Proceed with native local-PCA LPS only as an explicitly labeled experimental
backend in prospective runs:

```text
--lps-local-pca-backend=cpp.local.pca
```

Do not promote it to `backend = "auto"` yet.

The next useful step is a K8/P7e focused prospective run that compares deployable
methods on a small controlled subset while recording `backend.used` in every LPS
artifact. If K8 remains clean across multiple 2D/3D/real-geometry examples, then
we can reconsider a staged promotion plan. The promotion gate should require no
material candidate-table drift on a deliberately chosen diagnostic suite, not
only selected-fit agreement.
