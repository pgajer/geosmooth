# LPS Binary P7X-Density Comparison Experiment Spec

Generated: 2026-06-08

This bundle freezes the manifest for an overnight comparison of the two
implemented binary-outcome LPS modes:

- `lps_bernoulli_brier`: `fit.lps(outcome.family = "bernoulli")`
- `lps_binomial_logistic`: `fit.lps(outcome.family = "binomial")`

The experiment uses the frozen P7X first-batch continuous-outcome geometries and
turns each known continuous truth function into calibrated binary probability
surfaces.  Binary outcomes are then sampled from those probability surfaces.

## Source Documents

Primary binary-outcome progress report:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_progress_2026-06-07/lps_binary_outcome_progress_report.tex`

Binary design note:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_binary_outcome_design_note_2026-06-07.md`

Minimal Bernoulli audit response:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_minimal_bernoulli_audit_response_2026-06-07.md`

Logistic re-audit:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_logistic_audit_response_reaudit_2026-06-07.md`

Preliminary smoke report:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_outcome_smoke_2026-06-07/lps_binary_outcome_smoke_report.html`

## Frozen Geometry Source

Frozen asset source:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_local_auto_nonmanifold_first_batch_2026-06-05`

Asset manifest:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_local_auto_nonmanifold_first_batch_2026-06-05/asset_manifest.csv`

The run includes all 14 frozen first-batch P7X geometries:

1. `LA-D1-RAW-N500`
2. `LA-D1-HC-Li-N500`
3. `LA-D1-HC-Lc-N500`
4. `LA-D1-HC-Gv-N500`
5. `LA-D1-HC-Bv-N500`
6. `LA-D2-RAW-N500`
7. `LA-D2-HC-TOP1-N500`
8. `LA-D3-RAW-N500`
9. `LA-13K-SUB-N500`
10. `SYN-PARA-LINE-N500`
11. `SYN-SADDLE-LINE-N500`
12. `SYN-TWO-PLANES-N600`
13. `SYN-SIMPLEX-FACES-N600`
14. `SYN-RANK-BLOCKS-N600-P100`

## Manifest Bundle

Run id:

`lps_binary_p7x_density_comparison_20260608_001`

Run directory:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_p7x_density_comparison_20260608_001`

Generated files:

- `task_manifest.csv`: one row per planned model-fit task;
- `probability_surface_manifest.csv`: one row per frozen geometry and
  probability profile;
- `manifest_qa_summary.csv`: pre-launch QA checks;
- `manifest_pair_qa.csv`: pair-level seed and arm checks;
- `manifest_balance_qa.csv`: design-cell balance checks;
- `run_config.csv`: run-level metadata;
- `PRELAUNCH_SPEC_SUMMARY.txt`: compact pre-launch summary.

Preparer script:

`/Users/pgajer/current_projects/geosmooth/scripts/prepare_lps_binary_p7x_density_manifest.R`

## Probability-Surface Construction

Each frozen P7X asset contains a known continuous truth vector
\[
  f=(f_1,\ldots,f_n).
\]
For a probability profile \(g\), the binary probability surface is
\[
  p_i^{(g)}
  =
  \varepsilon
  +
  (1-2\varepsilon)
  \operatorname{logit}^{-1}
  \{\alpha_g+\beta_g z_i\},
\]
where
\[
  z_i
  =
  \operatorname{clip}
  \left(
    \frac{f_i-\operatorname{median}(f)}
         {\operatorname{scale}(f)},
    -4,\ 4
  \right).
\]
The scale is the median absolute deviation of \(f\), falling back to the
standard deviation and then to \(1\) if needed.  The intercept \(\alpha_g\) is
chosen numerically so that
\[
  \frac1n\sum_{i=1}^n p_i^{(g)}
  =
  \pi_g,
\]
where \(\pi_g\) is the target event prevalence.

The two frozen probability profiles are:

| profile | target prevalence \(\pi_g\) | logit slope \(\beta_g\) | floor \(\varepsilon\) |
|---|---:|---:|---:|
| `balanced_smooth` | 0.50 | 1.25 | 0.02 |
| `low_prevalence_smooth` | 0.20 | 1.25 | 0.02 |

This gives 10 binary repetitions per geometry by using five response
replicates for each of two probability profiles.

For each task, binary responses should be generated as
\[
  Y_i\sim\operatorname{Bernoulli}(p_i^{(g)}),
\]
using the task's `response_seed`.

## Experimental Design

Factors:

- frozen geometries: 14;
- probability profiles: 2;
- binary repetitions per profile: 5;
- chart-dimension rules: `auto`, `local.auto`;
- methods: `lps_bernoulli_brier`, `lps_binomial_logistic`.

Task count:

\[
  14 \times 2 \times 5 \times 2 \times 2 = 560.
\]

Paired method comparisons:

\[
  14 \times 2 \times 5 \times 2 = 280.
\]

The paired unit is
\[
  (\texttt{dataset.id},\ \texttt{probability.profile},\
   \texttt{repetition},\ \texttt{chart.dim.rule}).
\]
Within each pair, the Bernoulli/Brier and binomial/logistic methods use the same
probability surface, binary response seed, fold seed, geometry, and chart rule.

## Model-Fit Settings

Both methods use:

```r
coordinate.method = "local.pca"
backend = "R"
support.grid = 15:35
degree.grid = 1:2
kernel.grid = "tricube"
design.basis = "orthogonal.polynomial.drop"
design.drop.tol = 1e-8
ridge.multiplier.grid = c(0, 1e-10, 1e-8)
ridge.condition.max = 1e12
unstable.action = "mean"
cv.folds = 5
```

The Bernoulli/Brier method uses:

```r
outcome.family = "bernoulli"
selection score = cv.brier.observed
```

The binomial/logistic method uses:

```r
outcome.family = "binomial"
selection score = cv.logloss.observed
```

Both methods must report both Brier and log-loss metrics even though they select
by different primary CV scores.

## Primary Metrics

The primary synthetic target is probability Truth RMSE:
\[
  \operatorname{TruthRMSE}_p
  =
  \left[
    \frac1n\sum_{i=1}^n
    \{\widehat p_i-p_i\}^2
  \right]^{1/2}.
\]

The primary paired contrast is
\[
  \Delta R_p
  =
  \operatorname{TruthRMSE}_p(\text{binomial/logistic})
  -
  \operatorname{TruthRMSE}_p(\text{Bernoulli/Brier}).
\]
Negative values favor the local logistic-polynomial mode; positive values favor
the minimal Bernoulli/Brier mode.

Secondary metrics:

- truth Brier:
  \[
    \frac1n\sum_i (p_i-\widehat p_i)^2;
  \]
- observed Brier:
  \[
    \frac1n\sum_i (Y_i-\widehat p_i)^2;
  \]
- observed log loss:
  \[
    -\frac1n\sum_i
    \{Y_i\log\widetilde p_i+(1-Y_i)\log(1-\widetilde p_i)\};
  \]
- calibration summaries by probability bins;
- fitted probability range and clipping diagnostics;
- logistic CV and final-fit convergence/fallback telemetry.

## Required Run Accounting

The worker/supervisor should use one status/result/log file per task so one
failure does not halt the run.  Every planned task must end with exactly one
status row:

- `ok`;
- `nonfinite`;
- `error`;
- `timeout`.

For `outcome.family = "binomial"`, reports must separately show:

- CV logistic attempted solves;
- CV converged solves;
- CV fallback-path count;
- CV failure count;
- final-fit attempted solves;
- final-fit converged solves;
- final-fit fallback-path count;
- final-fit failure count.

## Recommended Overnight Execution

Suggested local-only policy:

```text
workers: 12
task timeout: 3600 seconds
```

This is intentionally a broader first comparison, not a tiny smoke test.  The
run is still bounded: 560 model-fit tasks, no PS-LPS synchronization, one kernel,
and two probability profiles.

## Required HTML Report

The post-run report should follow:

- `/Users/pgajer/.codex/notes/agent_instructions/reports/html_report_style_guide.md`
- `/Users/pgajer/.codex/notes/agent_instructions/reports/report_figure_table_qc.md`

Required sections:

1. answer-first summary;
2. main questions and design;
3. probability-surface construction with formulas;
4. fit-status accounting;
5. paired TruthRMSE comparison by chart rule and probability profile;
6. observed Brier and observed log-loss comparisons;
7. fallback/convergence telemetry for logistic LPS;
8. runtime tail and failure-mode summary;
9. Frank/Friedman-style method summary across cases if enough rows complete;
10. links to full CSV/RDS/log artifacts.

Required main figure:

- paired dot/interval plot of
  `TruthRMSE_p(binomial_logistic) - TruthRMSE_p(bernoulli_brier)`,
  with Bayesian bootstrap credible intervals for the paired median.

## Pre-launch QA Result

The generated manifest passed pre-launch QA:

```text
planned_tasks: 560
planned_pairs: 280
seed_matched_pairs: 280
mismatched_pairs: 0
qa_passed: TRUE
```

This spec freezes the design only.  It does not launch the overnight run.
