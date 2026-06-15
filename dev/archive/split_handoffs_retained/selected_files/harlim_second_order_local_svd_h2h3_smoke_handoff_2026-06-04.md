# Harlim Second-Order Local SVD H2/H3 Smoke Handoff

Date: 2026-06-04

## Scope

Executed the H1 audit recommendation: run chart-diagnostic smoke comparisons
for the experimental second-order local SVD primitive before any LPS or P7
integration.

This pass did not modify LPS, SLPLiFT, or production defaults.

## Files Added

- `scripts/harlim_second_order_local_svd_h2h3_smoke.R`
- `split_handoffs/harlim_second_order_local_svd_h2h3_smoke_results_2026-06-04.csv`
- `split_handoffs/harlim_second_order_local_svd_h2h3_smoke_handoff_2026-06-04.md`

## Smoke Design

The smoke script loads the package from source with `pkgload::load_all()` and
evaluates one supplied local support at a time.

Geometries:

- flat 2D plane in R3;
- 2D paraboloid in R3;
- 2D saddle in R3;
- 20D orthonormal embeddings of the same 3D geometries.

Support types:

- centered symmetric grid supports;
- asymmetric random supports around the anchor;
- asymmetric supports with several zero-weight rows;
- support-size sweep for paraboloid with sizes `1, 2, 3, 4, 6, 10, 25`;
- near-line conditioning sweep with line-noise levels
  `1, 1e-1, 1e-2, 1e-4, 1e-6`.

Recorded controls:

- `center.mode = "anchor"`;
- `chart.dim = 2`;
- `rank.tolerance = sqrt(.Machine$double.eps)`;
- `rank.absolute.tolerance = 0`;
- `curvature.condition.max = 1e8`.

Metrics:

- ordinary PCA tangent-projector error;
- second-order SVD tangent-projector error;
- error delta `PCA - second.order`;
- fallback status and primary failure reason;
- plain-PCA fallback feasibility;
- effective support, design rank, design condition, first/second ranks;
- curvature fit and corrected-residual Frobenius summaries;
- elapsed time for the two chart calls.

## Results Summary

Rows written: 55.

Fallback rates:

| Study | Fallback rate |
|---|---:|
| base | 0.000 |
| conditioning | 0.000 |
| support_sweep | 0.429 |
| weighted_zero_rows | 0.000 |

Median projector errors by study:

| Study | PCA error | Second-order error | Median improvement |
|---|---:|---:|---:|
| base | 0.0874 | 0.0126 | 0.0710 |
| conditioning | 1.4142 | 0.000485 | 1.4137 |
| support_sweep | 0.4336 | 0.1279 | 0.2387 |
| weighted_zero_rows | 0.3245 | 0.00737 | 0.3045 |

Median projector errors by geometry:

| Geometry / study | PCA error | Second-order error | Median improvement |
|---|---:|---:|---:|
| flat / base | 6.14e-16 | 5.70e-16 | -1.35e-19 |
| paraboloid / base | 0.246 | 0.0274 | 0.223 |
| saddle / base | 0.203 | 0.0132 | 0.184 |
| paraboloid / conditioning | 1.414 | 0.000485 | 1.414 |
| paraboloid / support_sweep | 0.434 | 0.128 | 0.239 |
| flat / weighted_zero_rows | 2.22e-16 | 8.43e-19 | 2.22e-16 |
| paraboloid / weighted_zero_rows | 0.326 | 0.00737 | 0.318 |
| saddle / weighted_zero_rows | 0.324 | 0.0200 | 0.304 |

High-dimensional embedded supports behaved like their 3D counterparts:

- flat 20D supports had projector error near machine precision;
- paraboloid 20D asymmetric support improved from `0.360` to `0.0196`;
- saddle 20D asymmetric support improved from `0.364` to `0.0330`;
- no high-dimensional base case fell back.

Support-size fallback behavior was deterministic:

- support size 1: structured failure with
  `fallback.reason = "plain_pca_fallback_not_feasible"`;
- support size 2: ordinary PCA fallback with
  `primary.failure.reason = "too_few_effective_support"`;
- support size 3: ordinary PCA fallback with
  `primary.failure.reason = "curvature_under_determined"`;
- support sizes 4, 6, 10, and 25: no fallback in the tested random supports.

The near-line conditioning sweep did not trigger fallback under
`curvature.condition.max = 1e8`.  Recorded design conditions ranged from about
`1.78` to `47.8`, so these are conditioning-stress smoke cases rather than
ill-conditioned rejection cases.

## Interpretation

The smoke tests support the intended chart-level behavior:

- second-order SVD preserves flat tangent spaces up to numerical precision;
- curved paraboloid and saddle supports show lower tangent-projector error than
  ordinary local PCA in the deterministic smoke cases;
- asymmetric supports do not erase the observed improvement;
- zero-weight rows are handled without fallback when enough positive-weight
  rows remain;
- undersized supports follow the H0/H1 fallback contract.

These are chart diagnostics only.  They do not establish smoothing-performance
gains and do not justify changing LPS defaults.

## Validation

Commands run from `/Users/pgajer/current_projects/geosmooth`:

```sh
Rscript scripts/harlim_second_order_local_svd_h2h3_smoke.R
```

Observed outcome:

- completed successfully;
- wrote `split_handoffs/harlim_second_order_local_svd_h2h3_smoke_results_2026-06-04.csv`;
- produced 55 diagnostic rows.

Additional hygiene checks are recorded in the final response for this task.

## Recommendation

Ready for a narrow optional chart-mode experiment only.

The primitive is ready to be proposed as an explicitly opt-in chart method for
small LPS/SLPLiFT diagnostic experiments, with fallback diagnostics surfaced in
candidate summaries.  It is not ready to replace local PCA defaults, and it
should not be used in production P7 runs until an opt-in integration is audited
and benchmarked end to end.
