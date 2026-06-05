# H5 Expanded LPS Chart Evaluation Report Audit

Date: 2026-06-04 17:35:00 EDT

Audited report:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h5_expanded_eval_2026-06-04/h5_lps_chart_expanded_eval_report.html`

Supporting artifacts inspected:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h5_expanded_eval_handoff_2026-06-04.md`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h5_decision_note_2026-06-04.md`
- `/Users/pgajer/current_projects/geosmooth/scripts/harlim_second_order_lps_h5_expanded_eval.R`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h5_expanded_eval_2026-06-04/tables/h5_lps_chart_paired_results.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h5_expanded_eval_2026-06-04/tables/h5_lps_chart_fit_results.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h5_expanded_eval_2026-06-04/tables/h5_lps_chart_second_order_diagnostics.csv`

## Verdict

The H5 report is acceptable as an exploratory opt-in evidence report for the
second-order local SVD chart method. Its main recommendation is correct:
second-order charts should remain experimental and should not become the
default or be integrated into MALPS, LPL-TF, SLPL-TF, or production P7 selectors
on the basis of this run.

However, the report does not yet answer the more ambitious question:

> Can we predict when second-order charts help?

It has some ingredients for that question, but it does not analyze them. The
next step should be an H5 predictive-diagnostics addendum built from the
existing CSV/RDS artifacts before any larger H6 replicate run is designed.

## Main Strengths

1. **Flat cases were correctly removed.** The revised suite now avoids using
   known fallback/identity behavior as accuracy evidence.

2. **The paired comparison is the right primary structure.** Each case compares
   ordinary local-PCA LPS to opt-in second-order-local-SVD LPS under matched
   data, truth, fold, support, degree, and kernel grids.

3. **The headline conclusion is appropriately conservative.** The report does
   not claim statistical significance or a default change.

4. **The implementation diagnostics are useful.** The paired table records
   selected support, selected degree, selected kernel, selected chart dimension,
   fallback counts/rates, rank diagnostics, condition summaries, runtime, and
   fit status.

5. **The VALENCIA-derived case is included and clearly identifiable.** This is
   important because real-geometry behavior may differ from synthetic curved
   surfaces.

## Findings And Limitations

### 1. The report does not yet identify shared predictors of wins

The report lists winners and losers, but it does not relate those outcomes to
diagnostics such as curvature-fit quantities, design conditioning, fallback,
support size, selected degree, estimated chart dimension, ambient dimension, or
geometry family.

From a quick audit of the paired CSV:

- second-order wins: 7
- PCA wins: 18
- ties: 2
- largest second-order wins:
  - `torus_patch_2d`
  - `cusp_hypersurface_singular_3d`
  - `monkey_saddle_2d`
  - `curved_2d_paraboloid`
- largest PCA wins:
  - `highdim_curved_hypersurface_3d`
  - `cone_tip_singular_2d`
  - `valencia_rel4_linf_4d`
  - `swiss_roll_2d`

These outcomes are too mixed to support a simple rule like "curvature helps
second-order" or "singularity helps second-order."

### 2. Current diagnostics do not cleanly separate winners from losers

Simple rank-correlation checks using the paired CSV did not reveal a strong
single diagnostic predictor. Approximate rank correlations with
`delta.truth.rmse = TruthRMSE_second.order.svd - TruthRMSE_pca` were modest:

- ambient dimension: about `+0.35`
- runtime ratio: about `+0.38`
- selected support size: about `+0.17`
- selected chart dimension: near `0`
- fallback rate: near `0`
- median design condition: near `0`
- max design condition: near `0`

Additional diagnostic aggregation from
`h5_lps_chart_second_order_diagnostics.csv` also did not yield an obvious
single predictor. Curvature and residual quantities may still be useful, but
they need a more careful derived-feature analysis.

### 3. The largest effects are dominated by a few cases

Most cases are close to zero delta. Two cases strongly favor second-order
(`torus_patch_2d`, `cusp_hypersurface_singular_3d`) and two cases strongly favor
PCA (`highdim_curved_hypersurface_3d`, `cone_tip_singular_2d`). This makes the
mean unstable and makes informal visual interpretation risky.

The addendum should define a material-effect band, for example using both:

\[
  \Delta = \operatorname{TruthRMSE}_{2\mathrm{nd}} -
           \operatorname{TruthRMSE}_{\mathrm{PCA}},
\]

and a relative version:

\[
  \Delta_{\mathrm{rel}} =
  \frac{\operatorname{TruthRMSE}_{2\mathrm{nd}} -
        \operatorname{TruthRMSE}_{\mathrm{PCA}}}
       {\operatorname{TruthRMSE}_{\mathrm{PCA}}}.
\]

Cases inside a small absolute and relative band should be called "practically
tied" rather than treated as meaningful wins.

### 4. Fallback behavior needs clearer interpretation

Two non-flat cases had full fallback because `chart.dim` equaled ambient
dimension:

- `paraboloid_sharp_2d`
- `folded_sheet_singular_2d`

These cases are effectively not testing the second-order chart. The report
mentions this, but the paired result table still includes them in the same
winner/tie counts. The predictive addendum should separate:

- effective second-order cases;
- full fallback cases;
- partial fallback cases.

### 5. VALENCIA-derived evidence is still only a single probe

The VALENCIA-derived case favors PCA and has a small fallback rate plus a very
large maximum condition number. This is interesting, but it is only one
VALENCIA-derived case with `n = 120` and a PCA-space Gaussian synthetic truth.
It should not be generalized to 16S-style real geometry.

The report should phrase this as:

- "VALENCIA-derived probe favored PCA in this case,"

not:

- "VALENCIA-derived geometries favor PCA."

### 6. The report is too table-heavy for prediction

The large paired-results table is useful as an artifact, but not as a human
analysis surface. For the predictive question, it should be replaced or
supplemented by compact diagnostic figures:

- delta by geometry family;
- delta versus log condition number;
- delta versus curvature/residual ratios;
- delta versus selected support and degree;
- fallback-category strips;
- a top-win/top-loss diagnostic panel.

The full CSV should remain linked as a table artifact.

## Recommendation

Do not change package defaults. Do not broaden integration. Do not launch a
large H6 replicate study yet.

First, run a no-refit H5 predictive-diagnostics addendum using the existing
artifacts. The purpose is to decide which diagnostics are plausible enough to
predeclare for a larger replicate study.

## Next Task For The Harlim Agent

Please perform **H5.1: Predictive Diagnostics Addendum for Second-Order LPS
Charts**.

This is a no-refit analysis phase. Use the existing H5 artifacts:

- paired results CSV;
- fit results CSV;
- second-order diagnostics CSV;
- RDS bundle if needed for rerendering.

### Required Questions

Answer these questions explicitly:

1. Among H5 cases where second-order charts were actually used, what diagnostic
   quantities best distinguish material second-order wins from material PCA
   wins?
2. Are the largest second-order wins associated with curvature, singularity
   type, selected support size, selected degree, chart dimension, rank,
   condition number, or residual/curvature-fit ratios?
3. Are the largest PCA wins associated with high ambient dimension, ill
   conditioning, fallback behavior, singularity type, or VALENCIA-derived
   geometry?
4. Does the VALENCIA-derived case look like the synthetic cases under the
   available diagnostics, or is it qualitatively separate?
5. Which diagnostics should be predeclared for a later H6 replicate study?

### Required Derived Quantities

Compute at least:

- absolute delta:
  \[
  \Delta =
  \operatorname{TruthRMSE}_{2\mathrm{nd}} -
  \operatorname{TruthRMSE}_{\mathrm{PCA}};
  \]
- relative delta:
  \[
  \Delta_{\mathrm{rel}} =
  \Delta / \operatorname{TruthRMSE}_{\mathrm{PCA}};
  \]
- practical-outcome label using a stated absolute and relative materiality
  threshold;
- fallback category:
  `none`, `partial`, or `full`;
- high-dimensional flag;
- singular flag;
- VALENCIA-derived flag;
- selected support/degree/kernel/chart-dimension comparison;
- log condition summaries;
- per-case medians and upper quantiles of:
  - `fit.residual.frobenius`;
  - `curvature.fitted.frobenius`;
  - `corrected.residual.frobenius`;
  - `corrected.residual.frobenius / fit.residual.frobenius`;
  - `curvature.fitted.frobenius / fit.residual.frobenius`;
  - `design.condition`;
  - `first.rank`, `second.rank`, and `design.rank`.

### Required Figures

Generate an HTML addendum report with compact figures:

1. paired delta plot with a practical-equivalence band;
2. relative delta by geometry family;
3. delta versus log condition summaries;
4. delta versus curvature/residual ratios;
5. delta by fallback category;
6. top second-order wins and top PCA wins diagnostic panel;
7. VALENCIA case shown explicitly, not hidden inside a table.

Do not include long tables in the HTML body. Link CSVs instead.

### Required Output

Create:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h5_predictive_diagnostics_addendum_2026-06-04.md`
- an HTML report under a new sibling directory such as:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h5_predictive_diagnostics_2026-06-04/`
- CSV files for derived case-level diagnostics.

### Guardrails

- Do not refit models in H5.1.
- Do not change package defaults.
- Do not claim prediction success from a single-replicate 27-case suite.
- Treat full fallback cases as non-informative for second-order accuracy.
- Treat the VALENCIA-derived case as one probe, not a class-level conclusion.

After H5.1, propose whether an H6 replicate study is warranted and, if so, what
diagnostics should be predeclared.
