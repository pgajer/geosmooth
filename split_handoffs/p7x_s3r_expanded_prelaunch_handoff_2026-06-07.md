# P7X / S3R-expanded Pre-launch Auditor Handoff

Generated: 2026-06-07

This handoff asks the auditor to review the proposed S3R-expanded run before
launch. The corrected S3R-light run passed audit, and the auditor recommended
S3R-expanded with the same paired manifest design. This document freezes the
planned expanded design, launch commands, expected accounting, and report
requirements so any remaining design issue can be caught before the overnight
compute.

## Prior Accepted Evidence

Corrected S3R-light run:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_20260607_002`

Corrected S3R-light report:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_20260607_002/reports/ps_lps_s3r_light_report.html`

Corrected S3R-light handoff:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_light_corrected_run_handoff_2026-06-07.md`

Corrected S3R-light audit:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_light_corrected_run_audit_2026-06-07.md`

Audit verdict:

- S3R-light passes as a valid seed-matched full-versus-screened paired light
  run.
- No blockers were identified before S3R-expanded.
- S3R-light should be treated as light/profiling evidence, not final policy
  evidence.
- S3R-expanded should use the same paired manifest design.
- The auditor preferred 20 repetitions if compute budget allows.

## Proposed S3R-expanded Run

Proposed run id:

`ps_lps_s3r_expanded_seedmatched_20260607_001`

Proposed run directory:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_20260607_001`

Frozen asset source:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_local_auto_nonmanifold_first_batch_2026-06-05`

The expanded run should use the same 14 frozen first-batch P7X assets as the
corrected S3R-light run.

## Generated Manifest For Re-audit

After correcting the task/pair arithmetic and report-script generalization, the
20-repetition manifest was generated but not launched.

Generated manifest:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_20260607_001/task_manifest.csv`

Generated pre-launch QA summary:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_20260607_001/PRELAUNCH_QA_SUMMARY.txt`

Generated monitoring/report dry run:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_20260607_001/reports/ps_lps_s3r_expanded_report.html`

The generated pre-launch QA reports:

```text
planned_tasks: 1120
planned_pairs: 560
seed_matched_pairs: 560
mismatched_pairs: 0
qa_passed: TRUE
```

## Experimental Design

Purpose:

Compare `PS-LPS screened` against `PS-LPS full` with repeated seed-matched
pairs, using the same response noise and CV folds within each pair.

Factors:

- datasets: 14 frozen P7X first-batch assets;
- repetitions: 20;
- chart-dimension rules: `auto`, `local.auto`;
- search policies: `full`, `screened`.

Fixed method settings:

- method: `ps_lps`;
- backend variant: `monomial_tiny_ridge`;
- design basis: `monomial`;
- ridge multiplier: `1e-8`;
- ridge condition cap: `Inf`;
- kernel: `tricube`;
- degree: `2`;
- support grid: `15:35`;
- lambda grid: `0, 0.001, 0.01, 0.1, 1, 10`;
- lambda search: `guarded`;
- screened local-candidate search control:
  `top.n=8; max.candidates=12; neighbor.radius=1; guard.support.quantiles=0|0.5|1`.

Expected task count:

```text
14 datasets * 20 repetitions * 2 chart rules * 2 search policies = 1120 tasks
```

Expected paired comparisons:

```text
14 datasets * 20 repetitions * 2 chart rules = 560 pairs
```

Each pair is indexed by:

```text
(dataset_id, repetition, chart_dim_rule)
```

Each pair must contain exactly one `full` arm and one `screened` arm with:

- identical response seed;
- identical fold seed;
- identical dataset asset and source hash;
- identical chart-dimension rule;
- identical fixed method settings except for local candidate search policy.

## Planned Execution Policy

Machine policy:

- local-only;
- 10 workers;
- no remote machine;
- one task per R worker process;
- Python supervisor keeps workers busy and records status per task;
- one task failure must not halt the whole run.

Task timeout:

- proposed per-task timeout: 7200 seconds.

Runtime estimate from corrected S3R-light:

- S3R-light, 3 repetitions, 168 tasks: about 1.45 hours wall time;
- S3R-expanded, 20 repetitions, 1120 tasks, 10 workers: expected about
  9.5--11 hours in practice;
- main runtime uncertainty: the long-tail `SYN-RANK-BLOCKS-N600-P100` tasks.

The 10-worker choice is deliberate. It leaves local CPU and memory headroom for
parallel work on another project while still fitting the expected run into an
overnight window.

The scripts currently have S3R-light names but are parameterized by `n_reps`,
`n_workers`, and `run_id`. The proposed S3R-expanded run intentionally reuses
the corrected S3R-light machinery rather than introducing a new untested script
family.

## Proposed Pre-launch Commands

Prepare the manifest:

```bash
cd /Users/pgajer/current_projects/geosmooth
Rscript scripts/prepare_ps_lps_s3r_light_run.R \
  --repo=/Users/pgajer/current_projects/geosmooth \
  --run_id=ps_lps_s3r_expanded_seedmatched_20260607_001 \
  --n_reps=20 \
  --n_workers=10 \
  --task_timeout_sec=7200 \
  --base_seed=20260607
```

Required pre-launch gate after manifest generation:

```bash
grep -q "qa_passed: TRUE" \
  /Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_20260607_001/PRELAUNCH_QA_SUMMARY.txt
```

Launch after audit acceptance and pre-launch QA:

```bash
cd /Users/pgajer/current_projects/geosmooth
screen -dmS pslps_s3r_exp_20260607_001 \
  bash -lc './split_handoffs/ps_lps_s3r_expanded_seedmatched_20260607_001/launch_s3r_light.sh'
```

Monitor:

```bash
cd /Users/pgajer/current_projects/geosmooth
Rscript scripts/merge_ps_lps_s3r_light_run.R \
  --run_dir=/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_20260607_001
```

The merge/report script is safe to run while the pipeline is in progress. It
should show explicit accounting for `ok`, `error`, `timeout`, `nonfinite`, and
missing/not-started tasks.

## Interim 10-repetition Readout

The planned expanded run has 20 repetitions. The predeclared interim readout is
the subset of complete pairs with:

```text
repetition <= 10
```

This is an analysis subset of the 20-repetition manifest, not a hard stop. The
current launcher will not automatically pause after 10 repetitions. If the
auditor believes a hard 10-repetition pause is necessary, the launch plan should
be changed before execution to a staged `10 + 10` design.

The final report should include both:

- interim summaries for repetitions 1--10;
- full summaries for repetitions 1--20.

## Required Expanded-run Accounting

The expanded run must preserve the corrected S3R-light accounting conventions:

1. Manifest-level QA:
   - exactly 1120 planned tasks;
   - exactly 560 planned full/screened pairs;
   - exactly two arms per pair;
   - one `full` and one `screened` arm per pair;
   - response seed matched within every pair;
   - fold seed matched within every pair;
   - asset paths present;
   - source hashes well formed;
   - dataset/repetition/chart/search cells balanced.

2. Runtime status accounting:
   - `ok`;
   - `error`;
   - `timeout`;
   - `nonfinite`;
   - missing status/result.

3. Pair accounting:
   - complete ok/ok pairs;
   - incomplete pairs;
   - exclusion reason for every incomplete pair;
   - seed mismatch flags, expected to be zero.

4. Candidate diagnostics:
   - candidate counts must be recomputed from
     `local_candidate_details.csv`;
   - do not rely on stale worker-level top-row summaries;
   - report whether the full-selected support was evaluated by screened search;
   - report whether the full-selected candidate key was evaluated by screened
     search;
   - report support and lambda match rates.

## Required Expanded-run Report Sections

The expanded HTML report should follow:

- `/Users/pgajer/.codex/notes/agent_instructions/reports/html_report_style_guide.md`
- `/Users/pgajer/.codex/notes/agent_instructions/reports/report_figure_table_qc.md`

Required sections:

1. Main questions.
2. Design and pairing contract.
3. Run accounting and failure/timeout/nonfinite accounting.
4. Truth RMSE delta definition:

```text
Delta Truth RMSE = Truth RMSE(screened) - Truth RMSE(full)
```

5. Paired accuracy results:
   - overall;
   - by chart rule;
   - by dataset;
   - by geometry family;
   - 10-repetition interim subset;
   - full 20-repetition subset.
6. Runtime and candidate-count results:
   - screened/full runtime ratios;
   - screened/full evaluated-candidate ratios;
   - runtime tail figures.
7. Candidate-inclusion diagnostics:
   - full support included in screened set;
   - full candidate key included in screened set;
   - lambda match;
   - interpretation separated from accuracy claims.
8. Decision section:
   - whether screened search can be used as the routine PS-LPS support-search
     policy;
   - whether any exception is needed for `auto` or `local.auto`;
   - whether additional profiling or policy modification is needed.

## Auditor Questions

Please answer these questions explicitly.

1. Is the proposed 20-repetition S3R-expanded design a valid extension of the
   corrected S3R-light run?
2. Is reusing the parameterized S3R-light scripts acceptable, despite the
   script names, or should they be renamed before launch to avoid ambiguity?
3. Are 1120 tasks and 560 pairs the correct expected counts?
4. Is the seed-matching contract complete and auditable?
5. Is the planned 10-worker local-only execution reasonable, given the need to
   leave machine capacity for another active project?
6. Is the 7200-second per-task timeout appropriate, given the corrected
   S3R-light runtime tail?
7. Is the predeclared 10-repetition readout acceptable as an analysis subset,
   or should the run be staged as `10 + 10` with a hard pause?
8. Are the required accounting and candidate-diagnostic outputs sufficient?
9. Are the required report sections sufficient for a policy decision about
   screened PS-LPS support search?
10. Are there any blockers before manifest generation and launch?

## Requested Auditor Output

Please write the pre-launch audit to:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_expanded_prelaunch_audit_2026-06-07.md`

If accepted, please state one of:

- `accepted for manifest generation and launch`;
- `accepted for manifest generation only; re-audit manifest before launch`;
- `blocked pending changes`.

If accepted with changes, please specify whether the changes must be made before
manifest generation, before launch, or only before final reporting.
