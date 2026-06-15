# H5 Handoff: Revised Curved/Singular LPS Chart Comparison

Date: 2026-06-04

## Scope Completed

Updated the H5 evaluation suite after user review:

- Removed flat datasets from the expanded LPS chart comparison.
- Added guardrails in the runner so flat cases cannot silently re-enter.
- Expanded the suite to 27 curved or singular paired cases.
- Regenerated CSV tables, RDS bundle, figures, and HTML report.
- Kept `local.chart.method = "second.order.svd"` opt-in only.
- Did not change defaults or integrate second-order charts into MALPS, LPL-TF,
  SLPL-TF, or production P7 selectors.

The package-facing H5 cleanup remains in place:

- `local.chart.method.effective = "none"` for ambient-coordinate LPS.
- `local.chart.method.effective = local.chart.method` for local-PCA LPS.
- Diagnostics summaries report the effective chart method.
- Regression tests cover default equality, ambient reporting, diagnostics,
  second-order `predict()`, and the ambient second-order hard error.

## Files

Direct revised H5 files/artifacts:

- `scripts/harlim_second_order_lps_h5_expanded_eval.R`
- `split_handoffs/harlim_second_order_lps_h5_expanded_eval_2026-06-04/`
- `split_handoffs/harlim_second_order_lps_h5_expanded_eval_handoff_2026-06-04.md`
- `split_handoffs/harlim_second_order_lps_h5_decision_note_2026-06-04.md`

The existing package implementation and tests from H5 remain:

- `R/kernel_local_polynomial_cv.R`
- `man/fit.lps.Rd`
- `tests/testthat/test-ge1-r-smoothers.R`

Workspace note: the tree still contains earlier H0-H4 second-order chart files
and unrelated local-PCA acceleration/generated export drift. Those were left
intact.

## Output Artifacts

Output directory:

`split_handoffs/harlim_second_order_lps_h5_expanded_eval_2026-06-04/`

Main report:

`split_handoffs/harlim_second_order_lps_h5_expanded_eval_2026-06-04/h5_lps_chart_expanded_eval_report.html`

Tables:

- `tables/h5_lps_chart_paired_results.csv`
- `tables/h5_lps_chart_fit_results.csv`
- `tables/h5_lps_chart_second_order_diagnostics.csv`

Rerender bundle:

- `h5_lps_chart_expanded_eval_bundle.rds`

Figures:

- `report_files/h5_truth_rmse_paired_segments.png`
- `report_files/h5_delta_truth_rmse.png`
- `report_files/h5_runtime_ratio.png`
- `report_files/h5_second_order_fallback_rate.png`

## Revised Suite

Flat rows are excluded by construction. The script now errors if any case ID,
dataset ID, or geometry family contains `flat`, `unit_square`, or `unit_cube`.

Suite summary:

- paired cases: 27
- flat rows: 0
- curved/singular-like rows: 27
- registry-backed non-flat P7 cases: 4
- custom curved/singular generated cases: 22
- VALENCIA-derived real-geometry probe: 1
- synthetic/custom sample size: `n = 80`
- VALENCIA-derived sample size: `n = 120`
- folds: fixed shared 5-fold non-oracle folds
- support grid: `15, 25, 35`
- degree grid: `1, 2`
- kernel grid: `gaussian, tricube`
- chart dimension: `chart.dim = "auto"`
- noise: Gaussian noise with `sd = 0.10 * sd(truth)`

Coverage includes:

- curved 2D paraboloid and saddle registry cases
- P7 high-dimensional 2D and 3D embedded cases
- paraboloid, saddle, monkey saddle, corrugated sheet, sphere patch, torus
  patch, swiss roll, and helicoid custom curved 2D cases
- cone, cusp, folded-sheet, and near-line singular 2D cases
- curved, saddle, and cusp 3D hypersurface cases
- high-dimensional curved 2D and 3D embeddings
- VALENCIA-derived 4D rel4 composition subset

## Paired Results

Primary paired quantity:

`Delta = TruthRMSE_second.order.svd - TruthRMSE_pca`

Negative values favor second-order charts. Positive values favor ordinary PCA.

Summary:

- outcomes: 18 PCA, 7 second-order, 2 tied
- median Delta: `+0.000388813`
- mean Delta: `+0.002978867`
- best Delta: `-0.1087304`
- worst Delta: `+0.170075`
- median runtime ratio, second-order/PCA: `4.287293`

Largest second-order wins:

- `torus_patch_2d`: Delta `-0.1087304`
- `cusp_hypersurface_singular_3d`: Delta `-0.0923458`
- `monkey_saddle_2d`: Delta `-0.005376068`
- `curved_2d_paraboloid`: Delta `-0.002506617`

Largest PCA wins:

- `highdim_curved_hypersurface_3d`: Delta `+0.170075`
- `cone_tip_singular_2d`: Delta `+0.09520639`
- `valencia_rel4_linf_4d`: Delta `+0.007386373`
- `swiss_roll_2d`: Delta `+0.004421614`

The revised evidence is more relevant than the flat-inclusive run. It remains
mixed and does not support a default change.

## Fallback And Conditioning

Second-order fallback rows:

- `paraboloid_sharp_2d`: fallback rate `1.0`, reason
  `chart_dim_not_less_than_ambient_dim`
- `folded_sheet_singular_2d`: fallback rate `1.0`, reason
  `chart_dim_not_less_than_ambient_dim`
- `valencia_rel4_linf_4d`: fallback rate `0.008333333`, reason
  `second_svd_rank_deficient` for one fitted chart

These are not flat datasets. The first two are curved/singular geometries where
the auto-selected chart dimension equaled the ambient dimension, triggering the
same conservative second-order guard.

Selected diagnostic highlights:

- `nearline_paraboloid_singular_2d` and `nearline_saddle_singular_2d` had
  median design condition `1.0` and selected lower-rank local designs.
- `valencia_rel4_linf_4d` had median design condition `10.269007` and max
  `2865.710905`.
- `monkey_saddle_2d` had max design condition `45.934563`.
- most curved 2D cases had median design condition roughly `1.7` to `2.2`.

## Validation

Commands run after revising the suite:

```sh
Rscript scripts/harlim_second_order_lps_h5_expanded_eval.R
git diff --check
```

Results:

- revised evaluation completed successfully
- paired rows: 27
- flat rows: 0
- curved/singular-like rows: 27
- VALENCIA-derived case included: yes
- `git diff --check`: clean

Earlier H5 package validation, before the suite-only revision, passed:

- `make document`
- targeted GE1 smoother tests: 53 passed, 0 failures
- targeted Harlim chart tests: 26 passed, 0 failures
- `make test`: 849 passed, 0 failures, 9 existing skips

No package source or test files were changed after that validation; only the H5
evaluation script/report/handoff artifacts were revised.

## Recommendation

Keep second-order charts as an opt-in experimental LPS chart method only.

The revised curved/singular suite shows that second-order charts can help on
some genuinely curved or singular geometries, sometimes by a large amount, but
ordinary PCA still wins in most paired cases and second-order remains about
`4.3x` slower at the median. The next step, if any, should be a larger
replicate study with predeclared case families and decision criteria, not a
broader integration.

Stop here and wait for audit.
