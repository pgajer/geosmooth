# H5 Decision Note: Revised Curved/Singular LPS Chart Evidence

Date: 2026-06-04

## Decision

Keep second-order local SVD charts as an opt-in experimental LPS chart method
only.

Do not:

- make `local.chart.method = "second.order.svd"` the default;
- integrate second-order charts into MALPS, LPL-TF, SLPL-TF, or P7 production
  selectors;
- use the H4 smoke run as accuracy evidence.

## Revision From User Review

The flat datasets were removed from the H5 evidence suite because they mostly
exercise known fallback or identity behavior. The revised suite contains no
flat datasets and expands to 27 curved or singular paired cases.

Suite checks:

- paired cases: 27
- flat rows: 0
- curved/singular-like rows: 27
- VALENCIA-derived real-geometry probe included

## Implementation Readiness

Implementation readiness remains acceptable for an experimental option:

- ordinary PCA remains the default;
- ambient-coordinate fits reject second-order charts;
- `local.chart.method.effective` reports `"none"` for ambient coordinates;
- local-PCA default matches explicit `local.chart.method = "pca"`;
- second-order local-PCA fits return diagnostics;
- `predict()` returns a plain numeric vector;
- package tests passed in the H5 validation run.

H4 was only a smoke and wiring phase. It validated argument routing,
diagnostics, and default preservation; it did not evaluate performance.

## Revised Accuracy Evidence

Primary Delta:

`TruthRMSE_second.order.svd - TruthRMSE_pca`

Negative values favor second-order charts. Positive values favor ordinary PCA.

Revised curved/singular results:

- outcomes: 18 PCA, 7 second-order, 2 tied
- median Delta: `+0.000388813`
- mean Delta: `+0.002978867`
- best Delta: `-0.1087304`
- worst Delta: `+0.170075`
- median runtime ratio, second-order/PCA: `4.287293`

Interpretation:

- Second-order charts can materially help on some curved or singular cases.
- Ordinary PCA still wins in most paired cases.
- Runtime remains materially higher for second-order charts.
- The evidence is not strong enough to justify broader integration or a default
  change.

## Diagnostic Notes

Three non-flat cases had second-order fallbacks:

- `paraboloid_sharp_2d`: all fitted charts fell back because selected chart
  dimension equaled ambient dimension.
- `folded_sheet_singular_2d`: all fitted charts fell back for the same guard.
- `valencia_rel4_linf_4d`: one fitted chart had
  `second_svd_rank_deficient`.

The largest second-order wins were `torus_patch_2d` and
`cusp_hypersurface_singular_3d`. The largest PCA wins were
`highdim_curved_hypersurface_3d`, `cone_tip_singular_2d`, and the
VALENCIA-derived probe.

## Recommended Next Step

Do not broaden integration yet. If the project wants to continue, assign a
larger study with:

- multiple noise replicates per curved/singular family;
- full P7 16S graph-geodesic truth cases;
- explicit analysis of when auto chart dimension triggers second-order fallback;
- runtime profiling;
- predeclared promotion criteria.

Otherwise, stop expansion here and keep the method as a guarded research hook.
