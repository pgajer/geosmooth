Please audit the focused LPS / PS-LPS design-basis backend comparison.

## Assets To Review

- Script:
  `/Users/pgajer/current_projects/geosmooth/scripts/lps_ps_lps_design_basis_focused_comparison.R`
- HTML report:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_design_basis_focused_comparison_2026-06-06/lps_ps_lps_design_basis_focused_comparison.html`
- Summary CSV:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_design_basis_focused_comparison_2026-06-06/tables/lps_ps_lps_design_basis_summary.csv`
- Failure/nonfinite CSV:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_design_basis_focused_comparison_2026-06-06/tables/lps_ps_lps_design_basis_failures.csv`

## What Was Run

The comparison used deterministic subsamples of four frozen first-batch
non-manifold assets:

- `LA-D1-RAW-N500`
- `LA-D1-HC-Li-N500`
- `SYN-PARA-LINE-N500`
- `SYN-RANK-BLOCKS-N600-P100`

For each dataset, both LPS and PS-LPS were run with:

- `chart.dim = "auto"`
- local PCA coordinates
- degree `2`
- tricube kernel
- support grid `{15, 25}`

PS-LPS used `lambda.sync.grid = {0, 0.01, 0.1}` with grid search.

The backend variants were:

- `monomial_tiny_ridge`
- `weighted_qr_drop_tiny`
- `orthogonal_drop_ridge0`
- `orthogonal_drop_adaptive_tiny`

The run produced 32 rows. All 16 PS-LPS rows had finite selected fits. Three
of 16 LPS rows were classified as `nonfinite_fit`, meaning no finite selected
fit or observed-CV score was available under that backend/guard configuration.

## Proposed Audit Questions

1. Does the implementation of `orthogonal.polynomial.drop` preserve the intended
   local polynomial prediction space when the ridge multiplier is zero, after
   rank-deficient columns are dropped?

2. Are the PS-LPS transformed frame designs correct? In particular, check that
   chart-local designs and anchor prediction rows are transformed consistently
   before synchronization rows are assembled.

3. Is the ridge interpretation stated correctly? The orthogonal-basis ridge is
   a ridge on orthogonalized coefficients, not on raw monomial coefficients.
   Please flag any documentation or report language that blurs this distinction.

4. Are numerical failures handled honestly? The intended contract is that
   rank/conditioning failures become explicit nonfinite or unstable rows, not
   silent weighted-mean fallbacks.

5. Is the focused comparison sufficient as a backend smoke/audit exercise, or
   should the next backend comparison include `chart.dim = "local.auto"` and/or
   a broader support grid before any experiment-facing default is changed?

6. Do the LPS `nonfinite_fit` rows indicate an overly strict guard for
   `weighted.qr.drop`, a genuine model instability, or a bug in candidate
   selection/status propagation?

7. Does the report avoid overclaiming? It should not be read as proof that
   `monomial_tiny_ridge` is best overall merely because it has the lowest
   Truth RMSE in this small focused run.

8. Should `orthogonal.polynomial.drop` remain opt-in while the code gathers
   more evidence, or is there enough numerical-contract evidence to make it the
   preferred backend for the next P7X-style comparison?

Please write the audit report in this same directory using a timestamped file
name such as:

`lps_ps_lps_design_basis_focused_comparison_audit_2026-06-06.md`
