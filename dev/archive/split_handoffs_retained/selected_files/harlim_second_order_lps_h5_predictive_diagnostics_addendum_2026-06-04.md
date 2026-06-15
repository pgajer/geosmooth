# H5.1 Predictive Diagnostics Addendum: Second-Order LPS Charts

Date: 2026-06-04

## Scope

This is a no-refit addendum built from the existing H5 artifacts:

- `split_handoffs/harlim_second_order_lps_h5_expanded_eval_2026-06-04/tables/h5_lps_chart_paired_results.csv`
- `split_handoffs/harlim_second_order_lps_h5_expanded_eval_2026-06-04/tables/h5_lps_chart_fit_results.csv`
- `split_handoffs/harlim_second_order_lps_h5_expanded_eval_2026-06-04/tables/h5_lps_chart_second_order_diagnostics.csv`

No package defaults were changed, and no models were refit.

## Output

HTML report:

`split_handoffs/harlim_second_order_lps_h5_predictive_diagnostics_2026-06-04/h5_predictive_diagnostics_addendum_report.html`

Derived CSVs:

- `split_handoffs/harlim_second_order_lps_h5_predictive_diagnostics_2026-06-04/tables/h5_1_case_level_predictive_diagnostics.csv`
- `split_handoffs/harlim_second_order_lps_h5_predictive_diagnostics_2026-06-04/tables/h5_1_predictor_rank_correlations.csv`
- `split_handoffs/harlim_second_order_lps_h5_predictive_diagnostics_2026-06-04/tables/h5_1_geometry_bucket_summary.csv`
- `split_handoffs/harlim_second_order_lps_h5_predictive_diagnostics_2026-06-04/tables/h5_1_practical_outcome_counts.csv`

Analysis script:

`scripts/harlim_second_order_lps_h5_predictive_diagnostics.R`

## Derived Labels

Primary quantities:

- `Delta = TruthRMSE_second.order.svd - TruthRMSE_pca`
- `relative Delta = Delta / TruthRMSE_pca`

Materiality rule:

- absolute threshold: `0.005` Truth RMSE
- relative threshold: `0.02`
- practical tie: inside both absolute and relative bands
- material second-order win: outside either band with negative Delta
- material PCA win: outside either band with positive Delta
- full fallback: non-informative for second-order accuracy

Counts:

- cases: 27
- effective second-order cases: 25
- full fallback non-informative: 2
- material second-order wins: 3
- material PCA wins: 3
- practical ties: 19

Full fallback cases:

- `paraboloid_sharp_2d`
- `folded_sheet_singular_2d`

Partial fallback case:

- `valencia_rel4_linf_4d`, one `second_svd_rank_deficient` fitted chart

## Question 1: What Best Distinguishes Material Wins?

No single diagnostic cleanly separates material second-order wins from material
PCA wins in this single-replicate 27-case suite.

The strongest rank correlations with Delta among effective second-order cases
were modest:

- `degree.delta`: rho about `0.34` in absolute magnitude
- `ambient.dimension`: rho about `+0.34`
- `runtime.ratio.second_over_pca`: rho about `+0.33`
- `support.delta`: rho about `+0.33`
- `high.dim.flag`: rho about `+0.32`

Positive correlation means larger values tend to favor PCA, since positive
Delta favors PCA. These are weak screening signals, not prediction rules.

Curvature/residual ratios and design-condition summaries were not strong
single-variable separators:

- `curvature.over.fit.median`: rho about `-0.19`
- `corrected.over.fit.median`: rho near `0`
- median design condition and median log condition: near `0`

## Question 2: What Characterizes Largest Second-Order Wins?

Material second-order wins:

| case | bucket | Delta | relative Delta | curvature/fit median | corrected/fit median |
| --- | --- | ---: | ---: | ---: | ---: |
| `torus_patch_2d` | curved 2D | `-0.1087304` | `-0.2260556` | `1.5106` | `1.0868` |
| `cusp_hypersurface_singular_3d` | singular 3D | `-0.0923458` | `-0.2772933` | `3.1406` | `1.7066` |
| `monkey_saddle_2d` | curved 2D | `-0.0053761` | `-0.0148770` | `2.4653` | `1.5054` |

These wins are not explained by one geometry label:

- two are smooth curved 2D cases;
- one is a singular 3D case;
- all are effective second-order cases with no fallback;
- selected support was `15` or `25`;
- selected degree was `1` or `2`;
- selected chart dimension was `2` or `3`.

The larger wins tend to have nontrivial curvature/residual structure, but the
same is also true for some PCA wins. Curvature signal should be predeclared for
H6, but it is not sufficient on its own.

## Question 3: What Characterizes Largest PCA Wins?

Material PCA wins:

| case | bucket | Delta | relative Delta | notable feature |
| --- | --- | ---: | ---: | --- |
| `highdim_curved_hypersurface_3d` | high-dimensional 3D | `+0.1700750` | `+0.4457845` | high ambient dimension |
| `cone_tip_singular_2d` | singular 2D | `+0.0952064` | `+0.7464548` | cone-tip singularity |
| `valencia_rel4_linf_4d` | VALENCIA probe | `+0.0073864` | `+0.1030080` | partial fallback, high condition |

PCA wins are associated with heterogeneous warning signs:

- high ambient dimension in one case;
- a sharp singularity in one case;
- VALENCIA-derived geometry plus one rank-deficient second-order chart in one
  case;
- higher runtime ratio and larger support/ambient-dimension signals are weakly
  associated with PCA-favoring Delta.

Design condition alone does not explain PCA wins. The VALENCIA probe has high
median condition (`10.269007`) and max condition (`2865.710905`), but the
cone-tip case is a PCA win without high condition.

## Question 4: Is VALENCIA Qualitatively Separate?

The VALENCIA-derived case should be treated as qualitatively separate.

It differs from most synthetic cases because it is:

- the only real-geometry probe;
- the only VALENCIA-derived case;
- a material PCA win;
- the only partial fallback case;
- high in median condition and curvature/fit ratio relative to most synthetic
  cases.

However, it is still only one probe with `n = 120` and a PCA-space Gaussian
synthetic truth. The correct conclusion is:

- `valencia_rel4_linf_4d` favored PCA in this H5 case.

The evidence does not support:

- VALENCIA-derived geometries generally favor PCA.

## Question 5: What Should Be Predeclared For H6?

If H6 is run, predeclare these diagnostics before fitting:

1. Outcome labels:
   - absolute Delta;
   - relative Delta;
   - practical tie thresholds;
   - material second-order win and material PCA win labels.

2. Fallback handling:
   - full fallback cases excluded from second-order accuracy claims;
   - partial fallback rate reported and modeled separately;
   - fallback reason counts.

3. Geometry flags:
   - high-dimensional flag;
   - singular flag;
   - VALENCIA/P7-real-geometry flag;
   - geometry bucket/family.

4. Selection diagnostics:
   - selected support size;
   - selected degree;
   - selected kernel;
   - selected chart dimension;
   - second-order minus PCA support, degree, and chart-dimension deltas.

5. Numerical diagnostics:
   - median, q90, and max design condition;
   - log10 condition summaries;
   - first-rank, second-rank, and design-rank summaries.

6. Curvature/residual diagnostics:
   - median and q90 `fit.residual.frobenius`;
   - median and q90 `curvature.fitted.frobenius`;
   - median and q90 `corrected.residual.frobenius`;
   - median and q90 `curvature.fitted.frobenius / fit.residual.frobenius`;
   - median and q90 `corrected.residual.frobenius / fit.residual.frobenius`.

7. Runtime:
   - runtime ratio, second-order/PCA;
   - runtime stratified by ambient dimension and chart dimension.

## H6 Recommendation

An H6 replicate study is warranted only if the goal is to learn when
second-order charts help, not to promote the method now.

Recommended H6 design:

- multiple seeds/noise replicates per geometry family;
- stratified curved 2D, singular 2D, curved 3D, singular 3D,
  high-dimensional, and VALENCIA/P7-real probes;
- full fallback cases separated from effective second-order cases;
- the diagnostics above predeclared before running;
- decision criteria based on material Delta and relative Delta, not raw win
  counts.

Do not change defaults or broaden integration before such a replicate study.

## Validation

Commands run:

```sh
Rscript scripts/harlim_second_order_lps_h5_predictive_diagnostics.R
```

Result:

- HTML report generated.
- Derived case-level, correlation, geometry-bucket, and practical-outcome CSVs
  generated.
- No model refits were performed.
