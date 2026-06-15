# PS-LPS-S1 Lambda/Ridge Sensitivity Audit Handoff 2026-06-05

You are auditing the **PS-LPS-S1 lambda/ridge sensitivity experiment** for
prediction-synchronized local polynomial smoothing (PS-LPS) in the
`geosmooth` package.

The audit should focus on mathematical, statistical, numerical, and
implementation correctness.  Style comments are secondary unless they affect
auditability, reproducibility, or interpretation.

## Primary Assets

Progress report updated after S1:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_progress_2026-06-05/ps_lps_progress_report.tex`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_progress_2026-06-05/ps_lps_progress_report.pdf`

S1 experiment runner:

- `/Users/pgajer/current_projects/geosmooth/scripts/run_ps_lps_s1_lambda_ridge_sensitivity.R`

S1 generated HTML report:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s1_lambda_ridge_sensitivity_2026-06-05/ps_lps_s1_lambda_ridge_sensitivity_report.html`

S1 generated tables:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s1_lambda_ridge_sensitivity_2026-06-05/tables/ps_lps_s1_candidate_grid.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s1_lambda_ridge_sensitivity_2026-06-05/tables/ps_lps_s1_selected_by_cv.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s1_lambda_ridge_sensitivity_2026-06-05/tables/ps_lps_s1_selected_delta_vs_baseline.csv`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s1_lambda_ridge_sensitivity_2026-06-05/tables/ps_lps_s1_summary_by_rule_ridge.csv`

S1 generated figures:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s1_lambda_ridge_sensitivity_2026-06-05/figures/ps_lps_s1_selected_lambda_ridge.png`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s1_lambda_ridge_sensitivity_2026-06-05/figures/ps_lps_s1_delta_vs_ridge.png`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s1_lambda_ridge_sensitivity_2026-06-05/figures/ps_lps_s1_candidate_truth_rmse_profiles.png`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s1_lambda_ridge_sensitivity_2026-06-05/figures/ps_lps_s1_summary_by_ridge.png`

Implementation under audit:

- `/Users/pgajer/current_projects/geosmooth/R/ps_lps.R`
- exported function: `fit.ps.lps()`
- tests: `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ps-lps.R`

Relevant earlier audit artifacts:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_audit_2026-06-05/ps_lps_first_implementation_audit_2026-06-05.md`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_audit_2026-06-05/ps_lps_audit_response_2026-06-05.md`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_audit_2026-06-05/ps_lps_audit_response_reaudit_2026-06-05.md`

## Context

The first PS-LPS implementation audit identified that the initial experiment
did not cleanly separate synchronization from numerical ridge stabilization.
The implementation was then revised to expose the ridge term explicitly:

\[
  \lambda_{\mathrm{ridge}}\ge 0.
\]

The refined comparison treated the matched independent baseline as
\(\lambda_{\mathrm{sync}}=0\) at the same ridge scale.  S1 was then designed to
test whether the observed PS-LPS improvement over the matched independent
baseline is stable over a wider grid of:

\[
  \lambda_{\mathrm{sync}}
  \quad\text{and}\quad
  \lambda_{\mathrm{ridge}}.
\]

The S1 synchronization grid is:

\[
  \lambda_{\mathrm{sync}}
  \in
  \{0,\ 0.01,\ 0.03,\ 0.1,\ 0.3,\ 1,\ 3,\ 10\}.
\]

The S1 ridge grid is:

\[
  \lambda_{\mathrm{ridge}}
  \in
  \{0,\ 10^{-10},\ 10^{-8},\ 10^{-6}\}.
\]

For every dataset, chart rule, and ridge scale, the matched baseline is the
candidate with:

\[
  \lambda_{\mathrm{sync}}=0
\]

and the same support size, kernel, degree, chart rule, and ridge scale.

## Reported S1 Summary

The run evaluated:

\[
  14\ \text{datasets}
  \times 2\ \text{chart rules}
  \times 4\ \lambda_{\mathrm{ridge}}\text{ values}
  \times 8\ \lambda_{\mathrm{sync}}\text{ values}
  =
  896\ \text{candidate rows}.
\]

All candidate rows completed with status `ok`.

The selected-by-CV median Truth-RMSE deltas against the matched
\(\lambda_{\mathrm{sync}}=0\) baseline were reported as:

| Chart rule | lambda.ridge | Median Truth-RMSE delta | Wins |
|---|---:|---:|---:|
| `auto` | `0` | `-0.02223733` | `12/14` |
| `local.auto` | `0` | `-0.01523074` | `13/14` |
| `auto` | `1e-10` | `-0.01319178` | `12/14` |
| `local.auto` | `1e-10` | `-0.01104409` | `12/14` |
| `auto` | `1e-08` | `-0.01523378` | `12/14` |
| `local.auto` | `1e-08` | `-0.01094759` | `12/14` |
| `auto` | `1e-06` | `-0.01425194` | `12/14` |
| `local.auto` | `1e-06` | `-0.01057472` | `12/14` |

Negative values mean selected PS-LPS had lower Truth RMSE than the matched
independent baseline.  The reported interpretation is that the favorable signal
is not confined to one ridge scale.

The main caution recorded in the progress report is that the selected
\(\lambda_{\mathrm{sync}}\) is usually at the upper boundary of the tested grid:

\[
  \operatorname{median}\{\widehat{\lambda}_{\mathrm{sync}}\}=10
\]

for both chart rules and all ridge scales.

The second caution is numerical: requested \(\lambda_{\mathrm{ridge}}=0\) rows
were included, but the solver used its internal fallback ridge on a small number
of zero-ridge candidate solves.  The S1 run recorded:

- `35` requested zero-ridge candidate rows with `ridge_max > 0`;
- `5` selected requested zero-ridge rows with `ridge_max > 0`.

The realized ridge diagnostics are present in the candidate and selected tables
as:

- `ridge_median`;
- `ridge_max`.

## Reproducibility

The S1 report can be regenerated from cached block results by running:

```bash
cd /Users/pgajer/current_projects/geosmooth
Rscript scripts/run_ps_lps_s1_lambda_ridge_sensitivity.R
```

The runner supports parallel execution by setting:

```bash
PS_LPS_S1_WORKERS=4 Rscript scripts/run_ps_lps_s1_lambda_ridge_sensitivity.R
```

The actual run used `PS_LPS_S1_WORKERS=4`.

To force recomputation of block caches, use:

```bash
PS_LPS_FORCE=1 PS_LPS_S1_WORKERS=4 Rscript scripts/run_ps_lps_s1_lambda_ridge_sensitivity.R
```

You do not need to force recomputation unless the code or cached results look
inconsistent.  If you do not force recomputation, state that explicitly.

## Audit Questions / Gates

Please answer each question explicitly.

### 1. S1 scheduler and cache correctness

Does `run_ps_lps_s1_lambda_ridge_sensitivity.R` correctly enumerate the full
candidate grid?

Check:

- all 14 frozen first-batch datasets are included;
- both chart rules, `auto` and `local.auto`, are included;
- all four ridge values are included;
- all eight synchronization values are included;
- the result cache path is unique for each dataset, chart rule, and ridge scale;
- parallel execution with `parallel::mclapply()` cannot cause two workers to
  write the same RDS result;
- aggregation reads the same cached/result objects that the worker blocks
  produced.

### 2. Matched-baseline logic

Does the script correctly define the matched baseline as the
\(\lambda_{\mathrm{sync}}=0\) candidate with the same dataset, chart rule, ridge
scale, support size, kernel, degree, and chart construction?

Check especially that the selected deltas in
`ps_lps_s1_selected_delta_vs_baseline.csv` are computed as:

\[
  \Delta R
  =
  R_{\mathrm{selected}}
  -
  R_{\lambda_{\mathrm{sync}}=0,\ \mathrm{matched}}.
\]

### 3. Chart-dimension reuse

Does S1 correctly reuse the ordinary LPS-selected chart information?

Check:

- for `chart_dim_rule = "auto"`, the scalar selected chart dimension is used;
- for `chart_dim_rule = "local.auto"`, the per-anchor vector
  `chart_dim_by_eval` is used;
- the script accepts older/newer object naming safely and does not silently
  fall back to an invalid chart-dimension object;
- no truth information or latent dimension is used.

### 4. Zero-ridge and fallback-ridge interpretation

Is the progress report's treatment of zero-ridge rows honest and technically
accurate?

Please assess:

- whether requested \(\lambda_{\mathrm{ridge}}=0\) rows are a useful stress test;
- whether the internal fallback ridge means these rows should not be described
  as uniformly exact unregularized solves;
- whether reporting `ridge_median` and `ridge_max` is sufficient;
- whether the 35 zero-ridge candidate rows and 5 selected zero-ridge rows with
  `ridge_max > 0` materially affect the S1 interpretation.

### 5. Boundary synchronization selection

The selected \(\lambda_{\mathrm{sync}}\) is usually `10`, the largest tested
value.

Please assess:

- whether the progress report correctly treats this as a limitation;
- whether the S1 result is still meaningful despite boundary selection;
- whether the next run should extend the grid above 10;
- what extended grid you recommend, if any;
- whether additional numerical checks are needed at larger
  \(\lambda_{\mathrm{sync}}\).

### 6. Reported summary correctness

Verify the reported S1 summary values against the generated tables.

Check:

- `896` candidate rows;
- all candidate rows have status `ok`;
- median selected Truth-RMSE deltas by chart rule and ridge scale match the
  progress report;
- win counts match the progress report;
- median selected \(\lambda_{\mathrm{sync}}\) is 10 for both chart rules and all
  ridge scales;
- no table or figure silently drops failed or non-finite rows in a misleading
  way.

### 7. Statistical interpretation

Is the current S1 interpretation appropriately conservative?

The intended conclusion is:

> S1 supports prediction synchronization as useful on this frozen first-batch
> suite because median Truth-RMSE improvements over matched independent
> baselines appear across ridge scales, but the selected synchronization
> strength is often at the upper grid boundary, so the synchronization search
> range should be extended before prospective validation.

Please say whether you agree, disagree, or would revise this statement.

### 8. Progress report accuracy

Audit the updated progress report:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_progress_2026-06-05/ps_lps_progress_report.tex`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_progress_2026-06-05/ps_lps_progress_report.pdf`

Check that the S1 section is accurate, readable, and not overstated.

### 9. Next-step recommendation

Give a concrete next-step recommendation.

Possible next steps include, but are not limited to:

- S2: extend \(\lambda_{\mathrm{sync}}\) above 10 on the same frozen suite;
- S2: add a sparse QR / least-squares solve path to reduce reliance on fallback
  ridge before larger synchronization values;
- S2: run a smaller diagnostic grid first on the datasets where selected
  zero-ridge fallback occurred;
- proceed to a prospective experiment only after extended-grid sensitivity
  passes.

Please recommend one path and explain why.

## Expected Audit Output

Please write the audit report under:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_audit_2026-06-05/`

Use this exact filename:

`ps_lps_s1_lambda_ridge_sensitivity_audit_2026-06-05.md`

Please do not write the primary audit report elsewhere.  If you generate
supporting scratch files, logs, or small check tables, keep them in the same
directory and make the primary audit report link to them.

The worker will later look in this directory for the audit response to this
handoff.

The report should include:

1. Verdict: accepted, accepted with minor issues, blocked, or rejected.
2. Blocking issues, if any.
3. Nonblocking issues and recommended fixes.
4. Specific answers to the audit gates above.
5. A concrete recommendation for the next implementation/validation step.
