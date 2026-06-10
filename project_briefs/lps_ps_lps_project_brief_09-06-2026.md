# LPS/PS-LPS Project Brief

Generated: 09-06-2026 09:46:55 EDT  
Canonical source: `~/current_projects/geosmooth/project_briefs/lps_ps_lps_project_brief_09-06-2026.md`  
HTML companion: `~/current_projects/geosmooth/project_briefs/lps_ps_lps_project_brief_09-06-2026.html`

## Purpose of this brief

This is a timestamped orientation brief for the LPS/PS-LPS effort in
`geosmooth`. It is intended for another agent or auditor who needs enough
context to inspect, continue, or challenge the work without replaying the whole
conversation. It is not a dashboard, phase handoff, or final paper-style
report. It is a map of the current state of the project, the most important
ideas, the code and report assets, and the open decisions.

## Short project summary

The central applied question is whether local polynomial smoothers can become
strong general-purpose conditional expectation estimators on geometrically
complicated data, including nonmanifold and microbiome-style state spaces.

The current two model families are:

- **LPS**: local polynomial smoother. It fits local polynomial models around
  each anchor and combines the resulting local predictions into a smoother.
- **PS-LPS**: prediction-synchronized LPS. It adds a prediction-overlap
  synchronization penalty between local charts, so neighboring local models are
  encouraged to agree on overlapping support regions.

The current practical direction is:

- keep **LPS** as the mature baseline/local smoother;
- treat **PS-LPS** as the synchronized extension whose routine experimental
  policy now uses screened support search plus guarded lambda search;
- compare both under synthetic truth settings where the true conditional mean or
  probability surface is known.

## Repository and package state

Primary package:

- `~/current_projects/geosmooth`

Relevant package files:

- `~/current_projects/geosmooth/R/lps.R`
- `~/current_projects/geosmooth/R/ps_lps.R`
- `~/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R`
- `~/current_projects/geosmooth/tests/testthat/test-ps-lps.R`

Important implementation conventions:

- public R function names use dot delimiters, for example `fit.lps()` and
  `fit.ps.lps()`;
- legacy `kernel.local.polynomial.cv()` was removed in favor of `fit.lps()`;
- reusable local polynomial code now lives under LPS naming rather than
  kernel-smoother naming;
- generated run artifacts belong under `split_handoffs/` or experiment-specific
  report folders and should not be mixed with package source files.

## Model and API snapshot

### LPS

The current `fit.lps()` implementation supports:

- Gaussian continuous-response mode;
- minimal Bernoulli/Brier mode, where binary responses are treated as numeric
  conditional expectations with probability clipping and probability-scale
  diagnostics;
- binomial/logistic mode, using local logistic polynomial fits;
- global automatic chart dimension, `chart.dim = "auto"`;
- anchor-specific automatic chart dimension, `chart.dim = "local.auto"`;
- stabilized local polynomial designs using
  `design.basis = "orthogonal.polynomial.drop"`;
- tiny/adaptive ridge guards controlled through ridge multiplier and condition
  cap arguments.

Current preferred backend policy for routine LPS experiments:

- use `design.basis = "orthogonal.polynomial.drop"`;
- use a small/tiny ridge grid;
- retain explicit instability telemetry rather than silently falling back to
  weighted means.

### PS-LPS

The current `fit.ps.lps()` implementation supports:

- `chart.dim = "auto"` and `chart.dim = "local.auto"`;
- scalar support size and support grids;
- screened support search for routine experiments;
- full support-grid search as a validation/reference mode;
- guarded default lambda search for synchronization and ridge parameters;
- cache-aware synchronized system assembly and solve path;
- explicit telemetry for screened support selection and lambda search.

Current preferred routine experimental policy:

- use screened PS-LPS as the routine policy;
- keep full-grid PS-LPS as a validation/reference mode;
- use `monomial_tiny_ridge` as the current PS-LPS routine backend unless a later
  audit changes this;
- keep all screening/failure accounting explicit in run reports.

## Main experimental story so far

### 1. LPS emerged as a strong baseline

Early P7/P7X comparisons showed that local polynomial smoothing was among the
best-performing practical smoothers in the controlled synthetic suites. This
motivated moving the former local script implementation into `geosmooth` as
`fit.lps()` and optimizing it.

Key report:

- `~/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/reports/p7e_kernel_chart_focused_comparison_fast_20260603/p7e_kernel_chart_focused_comparison.html`

### 2. LPS backend work narrowed the preferred implementation

The project explored native local-PCA acceleration, chart caching, row-Gram
backend ideas, and design-basis stabilization. The practical conclusion was
that backend behavior has to be judged jointly by accuracy, runtime, failure
rate, and conditioning.

Important assets:

- `~/current_projects/geosmooth/split_handoffs/k3_8_lps_valencia_scalability_2026-06-04/k3_8_lps_valencia_scalability_report.html`
- `~/current_projects/geosmooth/split_handoffs/k9_lps_local_pca_native_phase_profile_2026-06-04/k9_lps_local_pca_native_phase_profile.html`
- `~/current_projects/geosmooth/split_handoffs/k11_p7_lps_post_k10_backend_panel_2026-06-04/k11_p7_lps_post_k10_backend_panel.html`
- `~/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/reports/lps_ps_lps_backend_broader_p7x_comparison.html`

Current backend lesson:

- for **LPS**, `orthogonal_drop_adaptive_tiny` / orthogonal-polynomial dropping
  is preferred for routine robust experiments;
- for **PS-LPS**, `monomial_tiny_ridge` remained the better routine backend in
  the broad comparison, mostly because of implementation-time behavior and
  synchronized-system interactions;
- `weighted_qr_drop_tiny` should be dropped from routine broad comparisons.

### 3. Local automatic dimension became a major modeling axis

The project added `chart.dim = "local.auto"` because real data, especially
microbiome-style data, may not have a single homogeneous intrinsic dimension.

Important assets:

- `~/current_projects/geosmooth/split_handoffs/lps_local_auto_nonmanifold_first_batch_2026-06-05/lps_local_auto_nonmanifold_first_batch_report.html`
- `~/current_projects/geosmooth/split_handoffs/lps_local_auto_pointwise_decomposition_2026-06-05/lps_local_auto_pointwise_delta_decomposition.pdf`

Main idea:

- compare `auto` versus `local.auto` using pointwise decompositions of the
  Truth-RMSE delta;
- inspect where local dimension changes help or hurt;
- use color-coded 3D visualizations and pointwise contribution diagnostics to
  localize model differences.

### 4. Total local GCV alone was not a good global selector

The project tested whether summing local GCV values could select good global
candidate settings. The result was not encouraging as a standalone global
optimization criterion.

Important assets:

- `~/current_projects/geosmooth/split_handoffs/lps_local_gcv_first_experiment_2026-06-05/lps_local_gcv_first_experiment_report.html`
- `~/current_projects/geosmooth/split_handoffs/lps_gcv_synchronized_selection_2026-06-05/lps_gcv_synchronized_selection_design.pdf`

Current interpretation:

- local GCV remains useful as a diagnostic and possibly as a local screening
  signal;
- total local GCV should not be treated as a proven replacement for CV or
  external validation;
- PS-LPS may make GCV more meaningful than ordinary independent LPS, but that
  remains an empirical question.

### 5. PS-LPS became a serious candidate, not only a conceptual model

The PS-LPS development produced:

- a mathematical/design report;
- refined implementation after audit;
- lambda/ridge sensitivity experiments;
- cache-aware backend improvements;
- screened support-search policy;
- repaired S3R expanded comparisons.

Important assets:

- `~/current_projects/geosmooth/split_handoffs/ps_lps_progress_2026-06-05/ps_lps_progress_report.pdf`
- `~/current_projects/geosmooth/split_handoffs/ps_lps_first_batch_refined_experiment_2026-06-05/ps_lps_first_batch_refined_comparison_report.html`
- `~/current_projects/geosmooth/split_handoffs/ps_lps_s1_lambda_ridge_sensitivity_2026-06-05/ps_lps_s1_lambda_ridge_sensitivity_report.html`
- `~/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/`
- `~/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001/reports/ps_lps_s3r_expanded_repaired_report.html`

Current PS-LPS policy:

- screened PS-LPS is promoted to routine experimental policy;
- full-grid PS-LPS remains a validation/reference policy;
- run reports must preserve planned/ok/nonfinite/error/timeout accounting and
  support-screen telemetry.

### 6. Binary-outcome LPS is now being tested

Two binary LPS modes have been implemented:

- **Bernoulli/Brier mode**: treats binary `0/1` responses as numeric
  conditional expectation targets and evaluates probability-scale predictions.
- **Binomial/logistic mode**: uses local logistic polynomial fits and log-loss
  oriented selection.

Important design/report assets:

- `~/current_projects/geosmooth/split_handoffs/lps_binary_outcome_progress_2026-06-07/lps_binary_outcome_progress_report.pdf`
- `~/current_projects/geosmooth/split_handoffs/lps_binary_outcome_smoke_2026-06-07/lps_binary_outcome_smoke_report.html`
- `~/current_projects/geosmooth/split_handoffs/experiment_catalogue_20260608/experiment_catalogue_dashboard.html`
- `~/current_projects/geosmooth/split_handoffs/experiment_catalogue_20260608/lps_binary_gaussian_factorial_design_manifest.csv`
- `~/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_runtime_smoke_20260608_001/lps_binary_gm_ff_runtime_smoke_report.html`

Current overnight run:

- `~/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_full_20260608_001/`

This run uses:

- 14 workers;
- failure-isolated task runner;
- per-task timeout;
- status JSON rows and result CSVs per task;
- full LPS-BIN-GM-FF factorial design with 11,520 planned tasks.

At the most recent status check on 09-06-2026, the run was still active with no
recorded errors or timeouts, and roughly three quarters of tasks complete. Check
the run directory for current status rather than relying on this static brief.

## Experimental-design infrastructure

The project now has an experiment catalogue dashboard for prior and proposed
method-evaluation designs:

- `~/current_projects/geosmooth/split_handoffs/experiment_catalogue_20260608/experiment_catalogue_dashboard.html`

This dashboard links:

- earlier P7/P7e/P7X controlled synthetic suites;
- LPS/PS-LPS backend comparisons;
- binary-outcome Gaussian-mixture factorial design;
- relevant frozen manifests and report assets.

The project also adopted Frank/Friedman-style reporting ideas for broad method
comparisons:

- summarize methods by regret vectors across controlled cases;
- report median regret, median absolute deviation of regret, failure rate,
  median runtime, and runtime variability;
- prefer readable summary figures over large raw tables;
- include backend/color legends and figure captions.

Related Codex note:

- `~/.codex/notes/references/experimental_design/frank_friedman_style_factorial_design_for_method_evaluation.md`

## Important code/design decisions that should not be lost

1. **Do not silently fall back to weighted means for conditioning failures.**
   Conditioning failures should be guarded, telemetered, and represented in
   reports.

2. **Keep `auto` and `local.auto` chart dimension policies explicit.** They are
   modeling choices, not invisible implementation details.

3. **Use screened PS-LPS as a routine policy only with explicit accounting.**
   Full-grid PS-LPS remains important as a validation/reference mode.

4. **Keep binary-outcome comparisons paired.** Bernoulli/Brier and
   binomial/logistic modes should share geometry, truth/probability surface,
   binary response realization, folds, and repetition when being compared.

5. **Do not overinterpret one suite.** P7X, S3R, and LPS-BIN-GM-FF answer
   related but different questions.

6. **Generated RDS/results/log files should not become package source debt.**
   Keep generated artifacts out of source-oriented commits unless deliberately
   versioned as small manifest/report assets.

## Current open questions

### Binary LPS

- Does local logistic LPS materially outperform Bernoulli/Brier LPS on
  probability-profile recovery?
- Does the answer depend on prevalence, profile transform, dimension, embedding
  family, sample size, or number of Gaussian components?
- Are runtime and failure behavior acceptable for logistic mode at the larger
  sample sizes?

### LPS versus PS-LPS

- Does PS-LPS continue to improve over LPS when support search is screened
  rather than full-grid?
- When PS-LPS improves, is the gain concentrated in nonmanifold/high-dimensional
  examples, or is it broad?
- Is screened PS-LPS robust enough for prospective runs, or does it need another
  support-screening pass?

### Local dimension

- When does `local.auto` help over `auto`?
- Can pointwise Truth-RMSE decomposition and local dimension maps predict where
  local dimension flexibility matters?
- Should local dimension be stabilized spatially or by graph neighborhoods in
  future work?

### Backend and numerical policy

- Should `orthogonal.polynomial.drop` become the default LPS design backend for
  all routine runs?
- Should PS-LPS remain on `monomial_tiny_ridge`, or should later cache/backend
  improvements revisit orthogonal designs for synchronized systems?
- Are there remaining monomial paths that should be replaced by guarded local
  polynomial solvers?

## Recommended entry points for a new agent

For an implementation agent:

1. Read `~/current_projects/geosmooth/R/lps.R`.
2. Read `~/current_projects/geosmooth/R/ps_lps.R`.
3. Read `~/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R`.
4. Read `~/current_projects/geosmooth/tests/testthat/test-ps-lps.R`.
5. Read the latest binary run directory README:
   `~/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_full_20260608_001/README.md`.

For an auditor:

1. Start with this brief.
2. Inspect the latest PS-LPS repaired S3R report:
   `~/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001/reports/ps_lps_s3r_expanded_repaired_report.html`.
3. Inspect the broad backend comparison:
   `~/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/reports/lps_ps_lps_backend_broader_p7x_comparison.html`.
4. Inspect the binary outcome progress report:
   `~/current_projects/geosmooth/split_handoffs/lps_binary_outcome_progress_2026-06-07/lps_binary_outcome_progress_report.pdf`.
5. Inspect the current overnight run after it completes:
   `~/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_full_20260608_001/`.

For an analysis/reporting agent:

1. Use the HTML report style guide:
   `~/.codex/notes/agent_instructions/reports/html_report_style_guide.md`.
2. Use the figure/table QC guide:
   `~/.codex/notes/agent_instructions/reports/report_figure_table_qc.md`.
3. Use the Frank/Friedman-style method-evaluation note:
   `~/.codex/notes/references/experimental_design/frank_friedman_style_factorial_design_for_method_evaluation.md`.
4. Treat paired design and failure accounting as first-class report sections.

## Suggested next actions after the current binary run

1. Generate a full HTML report for
   `lps_binary_gm_ff_full_20260608_001`.
2. Include method definitions, paired Bernoulli-vs-logistic comparisons,
   probability Truth-RMSE, Brier/log-loss diagnostics, runtime and failure
   accounting, and Frank/Friedman-style summary figures.
3. Audit whether the binary run preserved exact pair matching across response
   realization, folds, geometry, probability surface, chart rule, and
   repetition.
4. Decide whether binary LPS should proceed to a larger real-geometry
   microbiome-focused suite.
5. Update this project brief or create a new dated brief after the binary run
   report and audit are complete.

## Maintenance note

This brief is intentionally static. It should not be edited to keep up with
every run status update. Instead, create a new dated brief when the project
enters a new state worth handing to another agent.
