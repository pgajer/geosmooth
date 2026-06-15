# P7X / S3R Auditor Handoff: PS-LPS Screened Support Search and Backend Results

Generated: 2026-06-07

This handoff asks the auditor to review the current P7X method-evaluation
assets and the design of the new S3R repeated full-versus-screened PS-LPS
support-search experiments.  The immediate audit goal is not to rerun compute.
It is to decide whether the existing P7X results and the S3R-light /
S3R-expanded designs are statistically and engineering-wise sound enough to use
for the next PS-LPS support-search policy decision.

## Primary Audit Questions

1. Are the completed P7X backend-comparison results correctly interpreted as
   evidence that routine comparisons should use:
   - LPS with `orthogonal_drop_adaptive_tiny`, and
   - PS-LPS with `monomial_tiny_ridge`?
2. Does the completed P7X backend-comparison report follow the
   Frank/Friedman-style report logic closely enough: regret vector across
   cases, runtime, failure accounting, and clear method/backend definitions?
3. Is S3R-light correctly designed to test whether `PS-LPS screened` is
   practically equivalent to `PS-LPS full` while being much faster?
4. Does S3R-light need any additional bookkeeping before its results are used,
   such as explicit pair inclusion flags, candidate-set inclusion diagnostics,
   or per-dataset failure/timeout accounting?
5. Is the proposed S3R-expanded design sufficient to make a more durable
   decision about using screened PS-LPS support search in routine P7X-style
   experiments?
6. Are there any truth leakage, chart-dimension leakage, or reuse-of-test-data
   issues in the P7X/S3R setup?

## Completed P7X Assets

### P7X Geometry/Truth Registry and Materialization

These live in the S-LPL-TF prospective suite tree:

- GS0 registry design handoff:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/p7x_gs0_registry_design_handoff_2026-06-05.md`
- GS0 audit:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/p7x_gs0_registry_design_audit_2026-06-05.md`
- GS0 audit response:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/p7x_gs0_registry_design_audit_response_2026-06-05.md`
- GS0 re-audit:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/p7x_gs0_registry_design_reaudit_2026-06-06.md`
- GS1 materialization handoff:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/p7x_gs1_materialization_handoff_2026-06-06.md`
- GS1 audit:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/p7x_gs1_materialization_audit_2026-06-06.md`
- GS1 audit response:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/p7x_gs1_materialization_audit_response_2026-06-06.md`
- GS1 re-audit:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/p7x_gs1_materialization_reaudit_2026-06-06.md`

### P7X GS2-light Method-Comparison Report

- HTML report:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/reports/p7x_gs2_light_full_20260606/p7x_gs2_light_paired_method_comparison.html`
- Run handoff:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/p7x_gs2_light_run_handoff_2026-06-06.md`
- Run audit:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/p7x_gs2_light_run_audit_2026-06-06.md`

This report is the broad P7X method comparison.  It is useful background, but
the newer geosmooth backend comparison below is the more direct source for
LPS/PS-LPS backend and support-search decisions.

### P7X Kernel and Support-Selection Reports

- Kernel paired audit report:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/reports/p7x_kernel_pair_audit_full_20260606_launchd/p7x_kernel_pair_audit_report.html`
- Support-selection report:
  `/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/reports/p7x_gs2_support_selection_20260606/p7x_gs2_support_selection_report.html`

These informed two later decisions: prefer the tricube kernel in routine
P7X-style comparisons, and focus PS-LPS runtime work on support-search
screening rather than broad all-support exact search.

## Completed Geosmooth Backend-Comparison Assets

Main run directory:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001`

Key report and tables:

- HTML report:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/reports/lps_ps_lps_backend_broader_p7x_comparison.html`
- Task manifest:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/task_manifest.csv`
- Run config:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/run_config.csv`
- Combined results:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/tables/combined_results.csv`
- Coverage by arm:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/tables/coverage_by_arm.csv`
- Regret by case:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/tables/regret_by_case.csv`
- Regret summary by arm:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/tables/regret_summary_by_arm.csv`
- Best arm by dataset:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/tables/best_by_dataset.csv`
- Task status:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/tables/task_status.csv`

### Key Observations From The Backend Report

These are observations to audit, not final claims.

1. `PS-LPS / auto / monomial_tiny_ridge` had complete coverage over 14 cases and
   the smallest median regret in the completed backend comparison:
   - planned: 14
   - ok: 14
   - median regret: approximately `0.0007778`
   - median elapsed: approximately `95.3` seconds
   - max elapsed: approximately `4099.1` seconds
2. `PS-LPS / local.auto / monomial_tiny_ridge` also had complete coverage:
   - planned: 14
   - ok: 14
   - median regret: approximately `0.0008426`
   - median elapsed: approximately `143.1` seconds
   - max elapsed: approximately `3324.3` seconds
3. `LPS / auto / orthogonal_drop_adaptive_tiny` and
   `LPS / local.auto / orthogonal_drop_adaptive_tiny` had complete coverage over
   14 cases and were the stable LPS backends.
4. LPS with `monomial_tiny_ridge` and `weighted_qr_drop_tiny` had many nonfinite
   fits; they should not be routine LPS defaults without additional changes.
5. `weighted_qr_drop_tiny` is not recommended for routine broad comparisons.
   It is slower and less reliable than the two candidate defaults above.
6. The backend report already uses Frank/Friedman-inspired summary figures.
   Please audit whether the report makes the metric definitions clear enough
   and whether the figures support the stated backend policy.

## S3R-light Experiment: Current Design

S3R-light was started on 2026-06-07 and is still running at the time this
handoff was generated.

Run directory:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_20260607_001`

Key files:

- Prepare script:
  `/Users/pgajer/current_projects/geosmooth/scripts/prepare_ps_lps_s3r_light_run.R`
- Worker script:
  `/Users/pgajer/current_projects/geosmooth/scripts/run_ps_lps_s3r_light_task.R`
- Supervisor script:
  `/Users/pgajer/current_projects/geosmooth/scripts/launch_ps_lps_s3r_light_run.py`
- Merge/report script:
  `/Users/pgajer/current_projects/geosmooth/scripts/merge_ps_lps_s3r_light_run.R`
- Run config:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_20260607_001/run_config.csv`
- Task manifest:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_20260607_001/task_manifest.csv`
- Supervisor log:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_20260607_001/logs/python_launcher.log`
- Partial/final report path:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_20260607_001/reports/ps_lps_s3r_light_report.html`
- Status table path after merge:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_20260607_001/tables/task_status.csv`
- Task summary path after merge:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_20260607_001/tables/task_summary.csv`
- Full-versus-screened pair table path after merge:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_20260607_001/tables/full_vs_screened_pairs.csv`

### S3R-light Design Details

S3R-light uses the same 14 frozen first-batch P7X assets as the backend
comparison.  For each frozen geometry/truth asset, it generates three
deterministic repeated noisy responses and CV fold assignments.  The geometry
and truth are fixed; only response noise and fold assignment are resampled.

Factors:

- datasets: 14 frozen P7X first-batch assets
- repetitions: 3
- chart-dimension rule: `auto`, `local.auto`
- PS-LPS local-candidate search policy: `full`, `screened`
- backend: fixed to `monomial_tiny_ridge`
- kernel: fixed to `tricube`
- degree: fixed to `2`
- support grid: `15:35`
- lambda grid: `0, 0.001, 0.01, 0.1, 1, 10`
- lambda search: `guarded`
- screened support-search control:
  `top.n=8;max.candidates=12;neighbor.radius=1;guard.support.quantiles=0|0.5|1`

Total task count:

```text
14 * 3 * 2 * 2 = 168
```

The run uses 10 local workers through a launchd-backed Python supervisor.  Each
worker handles one task and writes an individual status JSON and result RDS.  A
single task failure should not halt the whole run.

### S3R-light Status At Handoff Creation

At a recent status check:

- total tasks: 168
- completed ok: 96
- running: 10
- pending/not-yet-launched: 62
- recorded errors: 0
- recorded nonfinite fits: 0
- result RDS files: 96
- currently in the `LA-13K-SUB-N500` block

The first eight datasets were complete at that check:

- `LA-D1-RAW-N500`
- `LA-D1-HC-Li-N500`
- `LA-D1-HC-Lc-N500`
- `LA-D1-HC-Gv-N500`
- `LA-D1-HC-Bv-N500`
- `LA-D2-RAW-N500`
- `LA-D2-HC-TOP1-N500`
- `LA-D3-RAW-N500`

Please re-check the run status before auditing S3R-light results.  The merge
script may be run after completion:

```bash
cd /Users/pgajer/current_projects/geosmooth
Rscript scripts/merge_ps_lps_s3r_light_run.R \
  --run_dir=/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_20260607_001
```

## S3R-light Audit Requests

Please audit the S3R-light design and, once complete, the results.  Specific
questions:

1. Does the resampling scheme correctly isolate support-search policy
   performance while preserving frozen P7X geometry/truth assets?
2. Are the generated response and fold seeds deterministic and auditable enough?
3. Is it valid to compare `screened - full` Truth RMSE within each
   `(dataset, repetition, chart.dim)` pair?
4. Does the screened search preserve enough guard candidates to be considered a
   safe practical approximation to full search?
5. Should the pair table additionally record whether the support size selected
   by full search was included in the screened evaluated candidate set?
6. Is the 2-hour per-task timeout suitable, or should future S3R runs use
   method/dataset-specific timeout thresholds?
7. Is the current report builder sufficient, or should it be expanded to the
   same HTML report style as the P7X backend report, with Frank/Friedman-style
   regret/runtime/failure figures?

## Proposed S3R-expanded Design

S3R-expanded is not yet run.  Please audit this design before execution.

Purpose:

S3R-expanded should be a more durable Frank/Friedman-style repeated experiment
to decide whether the screened PS-LPS support-search policy can replace full
support-grid search in routine P7X-style experiments.

Recommended factors:

- dataset suite: the same 14 frozen P7X first-batch assets as S3R-light, plus
  any later P7X frozen assets only if their registries/hashes are already
  audit-accepted
- repetitions: at least 10; preferably 20 if runtime is acceptable
- chart-dimension rule: `auto`, `local.auto`
- search policy: `full`, `screened`
- backend: `monomial_tiny_ridge`
- kernel: `tricube`
- degree: `2`
- support grid: `15:35`
- lambda grid/search: same as S3R-light unless S3R-light exposes a boundary
  problem
- per-task isolation: same worker/supervisor design as S3R-light
- report: Frank/Friedman-style summary across cases, not only per-dataset wins

Core response variable:

For each paired case, define

```text
Delta R_j = R_j(screened) - R_j(full),
```

where `R_j` is Truth RMSE for paired case `j`.  Negative values favor screened
search, positive values favor full search.

Runtime response:

```text
rho_j = T_j(screened) / T_j(full).
```

The main claim should not be that screened always chooses the exact same
support or lambda as full.  The useful claim would be that screened has
near-zero or acceptable Truth RMSE regret relative to full, sharply lower
runtime, and no new failure/timeout pattern.

Recommended S3R-expanded summaries:

1. Pair-level scatter of full vs screened Truth RMSE, with diagonal reference
   line.
2. Distribution of `Delta R_j` by chart-dimension rule and dataset family.
3. Bayesian paired estimate of mean/median `Delta R_j` with credible intervals.
4. Frank/Friedman-style method vector summary: median regret, MAD of regret,
   regret signal-to-noise ratio, failure rate, median elapsed time, MAD elapsed
   time, and elapsed-time signal-to-noise ratio.
5. Runtime ratio summary `rho_j`, including tail cases.
6. Candidate-set accounting: full selected support/lambda, screened selected
   support/lambda, number of screened candidates evaluated, whether
   full-selected support was evaluated by screened, and whether full-selected
   local candidate was evaluated by screened where identifiable.
7. Boundary and fallback accounting: timeout, nonfinite fit, lambda boundary
   expansion, selected lambda at boundary, and candidate-search failures.

Recommended decision criteria:

- Screened is acceptable for routine P7X-style runs if its paired Truth RMSE
  regret relative to full is practically negligible against between-dataset
  variability and if it gives substantial runtime savings.
- Screened is not acceptable as a default if the regret is concentrated in
  specific geometry families, chart-dimension rules, or high-dimensional
  examples unless those failure modes are understood and guarded.
- Full search should remain as an audit/reference path regardless of the
  routine default.

## Engineering Notes To Audit

1. The background-launch environment cleaned up ordinary `nohup` children in
   this Codex shell.  S3R-light was therefore launched through a launchd agent
   plist stored in the run directory:
   `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_20260607_001/com.pgajer.geosmooth.ps-lps-s3r-light-20260607-001.plist`
2. The supervisor uses explicit `/usr/local/bin/Rscript` when available, to
   avoid sparse launchd PATH problems.
3. The run directory currently contains generated result RDS files.  These
   should remain untracked unless a separate artifact-storage policy is chosen.
4. The scripts added for S3R-light are currently source files in
   `/Users/pgajer/current_projects/geosmooth/scripts`.  Please audit whether
   they should remain as scripts, be generalized, or be moved under a benchmark
   harness directory.
5. If S3R-expanded is approved, it should probably reuse the S3R-light scripts
   with a new run id and `n_reps` argument, rather than creating another
   near-duplicate script set.

## Requested Auditor Output

Please write an audit report with:

1. Verdict on completed P7X backend-report interpretation.
2. Verdict on S3R-light design.
3. Any blockers that must be fixed before interpreting S3R-light results.
4. Any blockers that must be fixed before launching S3R-expanded.
5. Specific recommendations for the S3R-expanded number of repetitions, timeout
   policy, and report contents.
6. A concise list of assets reviewed.

Suggested audit report location:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_2026-06-07.md`
