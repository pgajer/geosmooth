# PS-LPS Audit Handoff 2026-06-05

You are auditing the first implementation and first-batch experiment for **prediction-synchronized local polynomial smoothing (PS-LPS)** in the `geosmooth` package.

The audit should focus on mathematical, statistical, and implementation correctness. Style comments are secondary unless they affect reproducibility, correctness, or auditability.

## Primary Assets

Design/specification document:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_prediction_synchronized_design_2026-06-05/lps_prediction_synchronized_design.tex`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_prediction_synchronized_design_2026-06-05/lps_prediction_synchronized_design.pdf`

Implementation:

- `/Users/pgajer/current_projects/geosmooth/R/ps_lps.R`
- exported function: `fit.ps.lps()`
- namespace edit: `/Users/pgajer/current_projects/geosmooth/NAMESPACE`

Experiment runner:

- `/Users/pgajer/current_projects/geosmooth/scripts/run_ps_lps_first_batch_experiment.R`

Generated experiment report:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_first_batch_experiment_2026-06-05/ps_lps_first_batch_experiment_report.html`

Generated experiment tables:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_first_batch_experiment_2026-06-05/tables/ps_lps_first_batch_method_comparison.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_first_batch_experiment_2026-06-05/tables/ps_lps_first_batch_summary.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_first_batch_experiment_2026-06-05/tables/ps_lps_lambda_cv_gcv_table.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_first_batch_experiment_2026-06-05/tables/ps_lps_pointwise_components.csv`

Frozen input assets and ordinary LPS comparison results:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_local_auto_nonmanifold_first_batch_2026-06-05/`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_local_auto_nonmanifold_first_batch_2026-06-05/runs/lps_local_auto_fb_20260605_001/tables/combined_results.csv`

## Context

PS-LPS fits one local polynomial chart per anchor, as ordinary LPS does, but estimates all local chart coefficients jointly.  It adds a quadratic synchronization penalty that encourages overlapping local charts to agree on shared prediction points.

For chart anchors `i` and `ell`, overlap points are

\[
O_{i\ell}=N_i\cap N_\ell.
\]

The design document recommends normalized product overlap weights:

\[
\omega_{i\ell r}
=
|O_{i\ell}|
\frac{w_{ir}w_{\ell r}}
{\sum_{s\in O_{i\ell}} w_{is}w_{\ell s}+\epsilon}.
\]

The model objective is

\[
\mathcal L_{\rm local}(\beta)
+
\lambda_{\rm sync}\mathcal S(\beta),
\]

where

\[
\mathcal L_{\rm local}(\beta)
=
\frac12\sum_i\sum_{j\in N_i}
 w_{ij}\{y_j-\phi_i(x_j)^\top\beta_i\}^2
\]

and

\[
\mathcal S(\beta)
=
\frac12
\sum_{(i,\ell)}\sum_{r\in O_{i\ell}}
\omega_{i\ell r}
\{\phi_i(x_r)^\top\beta_i-
\phi_\ell(x_r)^\top\beta_\ell\}^2.
\]

The first-batch experiment compares:

- ordinary `LPS auto`,
- ordinary `LPS local.auto`,
- `PS-LPS auto`, reusing the ordinary `auto` candidate settings,
- `PS-LPS local.auto`, reusing the ordinary `local.auto` candidate settings.

The PS-LPS experiment tunes only

\[
\lambda_{\rm sync}\in\{0,0.1,1\}
\]

in the first run.

## Audit Questions / Gates

Please answer each question explicitly.

### 1. Objective implementation

Does `fit.ps.lps()` implement the objective described in the design document?

Check especially:

- local data-fit rows use the correct weighted local polynomial design;
- synchronization rows have the correct sign pattern:
  \[
  \phi_i(x_r)^\top\beta_i-\phi_\ell(x_r)^\top\beta_\ell;
  \]
- `lambda.sync` enters synchronization rows as `sqrt(lambda.sync * omega)`;
- the reported `sync.energy` corresponds to the unmultiplied synchronization energy \(\mathcal S(\widehat\beta)\), not to \(\lambda_{\rm sync}\mathcal S(\widehat\beta)\), unless clearly stated otherwise.

### 2. Overlap weights

Are overlap weights computed correctly?

Check:

- `O_{i\ell}` is the actual intersection of supports;
- raw product weights are `w_ir * w_ell_r`;
- normalized-product weights have approximately total mass `|O_{iell}|` per overlap pair;
- zero or degenerate overlaps are handled safely;
- pair selection through `sync.neighbor.size` is documented and does not accidentally produce asymmetric or duplicate rows.

### 3. Lambda-zero reduction

Does `lambda.sync = 0` reduce to independent local polynomial chart fits?

This is an important correctness gate.  Please test or reason through whether, at `lambda.sync = 0`, the PS-LPS fitted values match ordinary local chart fits with the same fixed support, kernel, degree, and chart dimensions, up to the tiny numerical ridge used in the sparse normal-equation solve.

If they do not match, identify why.

### 4. CV leakage

Is cross-validation implemented without validation-response leakage?

Check:

- local data-fit rows with validation response indices are zeroed/removed in fold solves;
- synchronization rows do not use validation responses, only covariates, chart bases, kernel weights, and overlap structure;
- held-out predictions are extracted only after solving the fold-specific system;
- the fold score is computed against held-out `y` values only after fitting.

### 5. Diagnostics correctness

Are these diagnostics computed correctly and named accurately?

- Truth RMSE;
- Observed RMSE;
- CV RMSE;
- total synchronized local GCV:
  \[
  \sum_i \operatorname{GCV}^{\rm PS}_i;
  \]
- local degrees-of-freedom ratio;
- synchronization energy;
- mean synchronization disagreement;
- pointwise \(c_i\) components in the experiment report.

In particular, verify that PS-local-GCV is computed from synchronized chart coefficients, and is not accidentally reusing independent-LPS local fits.

### 6. Experiment reproducibility

Can the first-batch report be regenerated from frozen assets by running:

```bash
cd /Users/pgajer/current_projects/geosmooth
Rscript scripts/run_ps_lps_first_batch_experiment.R
```

If cached result files are reused, please note that.  If you force recomputation, use:

```bash
PS_LPS_FORCE=1 Rscript scripts/run_ps_lps_first_batch_experiment.R
```

You do not need to force recomputation if the code inspection and spot checks are sufficient, but please state what you did.

### 7. Numerical concerns

Assess the numerical risks of the current solver.

The implementation uses sparse normal equations with a tiny scale-relative ridge:

```r
ridge <- 1e-8 * scale
```

Please comment on:

- whether this ridge is small enough to treat the solution as essentially the stated quadratic objective;
- whether the ridge should be reported as a diagnostic;
- whether a sparse QR / iterative least-squares backend should be required before this is promoted beyond prototype;
- whether `lambda.sync = 0` comparisons are affected materially by the ridge.

### 8. Result interpretation

The initial report suggests PS-LPS is best on all 14 first-batch datasets:

- `PS-LPS local.auto`: best on 9;
- `PS-LPS auto`: best on 5;
- ordinary LPS variants: best on 0.

Please evaluate whether this is a legitimate result of the implemented comparison or whether it may be due to any methodological or implementation artifact.

Consider especially:

- the small lambda grid `{0, 0.1, 1}`;
- reuse of ordinary LPS-selected support/kernel/degree/chart settings;
- whether PS-LPS gets extra flexibility that should be accounted for in comparisons;
- whether CV selection of `lambda.sync` appears coherent;
- whether Truth RMSE improvements are visible across many datasets or driven by a few large wins.

## Expected Audit Output

Please write a concise audit report under:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_audit_2026-06-05/`

Use this exact filename:

`ps_lps_first_implementation_audit_2026-06-05.md`

Please do not write the primary audit report elsewhere.  If you generate
supporting scratch files or logs, keep them in the same directory and make the
primary report link to them.  The worker will later look in this directory for
the audit response to this handoff.

The report should include:

1. Verdict: accepted, accepted with minor issues, blocked, or rejected.
2. Blocking issues, if any.
3. Nonblocking issues and recommended fixes.
4. Specific answers to the audit gates above.
5. A short recommendation for the next implementation/validation step.
