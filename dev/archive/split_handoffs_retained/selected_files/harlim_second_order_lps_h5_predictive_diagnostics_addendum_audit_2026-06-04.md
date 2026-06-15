# H5.1 Audit: Predictive Diagnostics Addendum

Generated: 2026-06-04 17:58:00 EDT

## Scope

Audited the H5.1 no-refit predictive-diagnostics addendum for second-order LPS
charts.

Reviewed:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h5_predictive_diagnostics_addendum_2026-06-04.md`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h5_predictive_diagnostics_2026-06-04/h5_predictive_diagnostics_addendum_report.html`
- `/Users/pgajer/current_projects/geosmooth/scripts/harlim_second_order_lps_h5_predictive_diagnostics.R`
- derived CSVs under `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h5_predictive_diagnostics_2026-06-04/tables/`
- source H5 paired/fit/diagnostic CSVs under `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_lps_h5_expanded_eval_2026-06-04/tables/`

## Verdict

Accepted as a no-refit exploratory addendum.

The report is appropriately cautious: it does not claim that second-order chart
wins can be predicted from the current single-replicate 27-case suite, and it
does not recommend changing defaults. The main conclusion, that no single
diagnostic cleanly predicts second-order wins and that H6 needs predeclared
replicate diagnostics, is supported by the derived tables.

## Checks Performed

Re-ran:

```sh
Rscript scripts/harlim_second_order_lps_h5_predictive_diagnostics.R
git diff --check
```

Confirmed:

- The script does not call `fit.lps()` or any model-fitting backend. It reads
  existing H5 CSVs and computes case-level summaries, plots, and derived CSVs.
- All 27 source H5 cases appear in the case-level diagnostic CSV.
- No diagnostic case IDs are dropped or introduced by the merge.
- Counts match the report:
  - 27 cases;
  - 25 effective second-order cases;
  - 2 full fallback non-informative cases;
  - 3 material second-order wins;
  - 3 material PCA wins;
  - 19 practical ties.
- The named material second-order wins are:
  - `torus_patch_2d`;
  - `cusp_hypersurface_singular_3d`;
  - `monkey_saddle_2d`.
- The named material PCA wins are:
  - `highdim_curved_hypersurface_3d`;
  - `cone_tip_singular_2d`;
  - `valencia_rel4_linf_4d`.
- The two full fallback cases are:
  - `paraboloid_sharp_2d`;
  - `folded_sheet_singular_2d`.
- The VALENCIA case is correctly treated as a single qualitatively separate
  probe rather than as class-level evidence.

## Claim Review

The materiality rule is implemented as stated:

\[
  \Delta
  =
  \operatorname{TruthRMSE}_{\mathrm{second.order.svd}}
  -
  \operatorname{TruthRMSE}_{\mathrm{pca}},
  \qquad
  \Delta_{\mathrm{rel}} = \Delta / \operatorname{TruthRMSE}_{\mathrm{pca}}.
\]

A practical tie is a case with both

\[
  |\Delta| \le 0.005
  \quad\text{and}\quad
  |\Delta_{\mathrm{rel}}| \le 0.02.
\]

A material win/loss is assigned by the sign of \(\Delta\) when either band is
exceeded. This matches the script and the narrative.

The rank-correlation claim is also supported. Among effective cases, the
largest absolute Spearman correlations are modest, approximately:

- `degree.delta`: `0.34`;
- `ambient.dimension`: `0.34`;
- `runtime.ratio.second_over_pca`: `0.33`;
- `support.delta`: `0.33`;
- `high.dim.flag`: `0.32`.

The report correctly frames these as weak screening signals, not prediction
rules.

## Minor Notes

No blockers.

1. The Markdown validation section lists the R script but omits
   `git diff --check`, even though the completion note says it was run. This is
   only documentation drift; the check passed during this audit.

2. The script uses `root <- getwd()`, so it is intended to be run from the
   geosmooth repository root. That is consistent with how it was validated, but
   future handoff scripts would be slightly more robust if they either document
   the required working directory explicitly or resolve paths relative to the
   script location.

3. The grouped summary CSV created by `aggregate(cbind(...), ...)` is fine as
   a machine-readable artifact, but it is not especially pleasant for manual
   reading. This is not a problem for the report, because the report uses
   figures and selected summaries rather than asking the reader to inspect that
   CSV.

## Recommended Next Step

Proceed to H6 planning only if the project wants to learn when second-order
charts help. H6 should not be a default-promotion phase. It should be a
predeclared replicate study with:

- geometry-family strata;
- material \(\Delta\) and relative-\(\Delta\) labels fixed in advance;
- full and partial fallback handled separately;
- VALENCIA/P7-real-geometry probes represented by more than one case;
- the H5.1 diagnostics collected before fitting and analyzed after fitting.

Do not broaden second-order chart integration or defaults based on H5/H5.1
alone.
