# P7X / S3R Audit Response: Corrective Plan for S3R-light Pairing Contract

Date: 2026-06-07

Response to audit:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_2026-06-07.md`

## Summary Response

The audit is accepted.  The seed mismatch identified in S3R-light is a real blocker for using the current run as paired evidence comparing `PS-LPS screened` against `PS-LPS full`.

The current S3R-light run should be treated as a smoke/profiling run only.  It may still be useful for runtime tails, timeout policy, memory behavior, and worker/supervisor robustness, but its full-versus-screened Truth RMSE deltas should not be used for the support-search policy decision.

The completed P7X backend-comparison interpretation remains conditionally accepted with the auditor's wording: it supports practical routine defaults on the frozen 14-case P7X suite, not a universal backend theorem.

## Accepted Audit Findings

### Finding 1: Pair Seed Mismatch

Accepted.

The current manifest lets `search_policy` affect `response_seed` and `fold_seed` for at least the `chart_dim_rule = "auto"` full/screened pairs.  Therefore those pairs do not compare methods on the same noisy response and the same CV folds.

Required correction:

- Define a `pair_id` for each intended pair:

```text
(dataset_id, repetition, chart_dim_rule)
```

- Define pair-level seeds that depend only on the pair factors, not on `search_policy`:

```text
pair_response_seed = f(dataset_id, repetition, chart_dim_rule)
pair_fold_seed     = g(dataset_id, repetition, chart_dim_rule)
```

- Assign identical `pair_response_seed` and `pair_fold_seed` to both `full` and `screened` rows in each pair.
- Add manifest validation that fails if any intended pair has mismatched seeds.

Implementation clarification from the plan audit:

- the seed formula must use explicit intermediate variables:
  `dataset_seed_component`, `repetition_seed_component`,
  `chart_seed_component`, `pair_seed_base`, `pair_fold_seed`, and
  `pair_response_seed`;
- `search_policy` must not enter any seed component;
- the preparer must write a validation summary with total planned pairs,
  seed-matched pairs, mismatched pairs, and arm balance.

### Finding 2: Pair Construction Drops Failed/Incomplete Pairs

Accepted.

The pair table must be manifest-backed, not result-backed.  Failed, missing, timed-out, and nonfinite arms are part of the experiment outcome and must not silently disappear from pair summaries.

Required correction:

- Build one pair row per planned pair from the task manifest.
- Left-join full and screened arm status and summaries.
- Include:
  - `full_status`
  - `screened_status`
  - `pair_status`
  - `pair_complete`
  - `pair_exclusion_reason`
- Compute accuracy deltas only for complete valid pairs, while keeping all planned pairs in failure/runtime accounting.

### Finding 3: Missing Screened-Candidate Inclusion Diagnostics

Accepted.

S3R is not only an accuracy comparison.  It is also a mechanism audit: screened search should be evaluated for whether it actually covers the local candidate region selected by full search.

Required correction:

Add to the pair table and HTML report:

- `screened_evaluated_supports`
- `full_support_in_screened_evaluated_supports`
- `full_candidate_key`
- `screened_evaluated_candidate_keys`, or a linked candidate-detail table
- `full_candidate_key_in_screened_evaluated_candidates`
- `support_match`
- `lambda_match`
- full and screened local candidate counts

Candidate identity is defined as:

```text
support.size | degree | kernel
```

The selected lambda is reported separately through `lambda_match`.  This keeps
two questions distinct: whether screened search evaluated the same local model
selected by full search, and whether the two arms selected the same
synchronization penalty inside that model.  If exact candidate-key matching is
unavailable in any legacy artifact, the report must say so explicitly and still
compute support-level inclusion.

### Finding 4: Incomplete Manifest-Backed Status Accounting

Accepted.

The merge script should always produce one task-status row per manifest task.  Missing status files should be explicit, not omitted.

Required correction:

- Emit a manifest-backed `task_status.csv` with one row per planned task.
- Represent absent status files as `not_started` when no result file exists.
- Represent unparseable status files or result-without-usable-status cases as
  `missing_or_corrupt_status`.
- Preserve `running`, `ok`, `nonfinite_fit`, `error`, and `timeout` states.
- Report planned/running/ok/nonfinite/error/not-started/corrupt/timeout counts
  by dataset, chart rule, and search policy.

## Implementation Plan

### S3R-Fix-1: Patch Manifest Generation

Modify:

`/Users/pgajer/current_projects/geosmooth/scripts/prepare_ps_lps_s3r_light_run.R`

Changes:

1. Add `pair_id` to every task row.
2. Compute pair-level seeds before iterating over `search_policy`, using
   explicit intermediate variables:
   - `dataset_seed_component`
   - `repetition_seed_component`
   - `chart_seed_component`
   - `pair_seed_base`
   - `pair_fold_seed`
   - `pair_response_seed`
3. Add columns:
   - `pair_response_seed`
   - `pair_fold_seed`
4. Set worker-facing `response_seed = pair_response_seed` and `fold_seed = pair_fold_seed` for both arms.
5. Add a manifest validation helper that checks:
   - exactly two arms per pair, one `full` and one `screened`;
   - identical `response_seed` within pair;
   - identical `fold_seed` within pair;
   - balanced planned counts across dataset, repetition, chart rule, and search policy;
   - all frozen asset paths and hashes are present.
6. Make the prepare script fail fast if validation fails.
7. Write pre-launch QA artifacts:
   - `manifest_qa_summary.csv`
   - `manifest_pair_qa.csv`
   - `manifest_balance_qa.csv`
   - `PRELAUNCH_QA_SUMMARY.txt`
8. Make the generated launcher refuse to start unless the pre-launch QA summary
   records `qa_passed: TRUE`.

### S3R-Fix-2: Patch Worker Output

Modify:

`/Users/pgajer/current_projects/geosmooth/scripts/run_ps_lps_s3r_light_task.R`

Changes:

1. Preserve `pair_id`, `pair_response_seed`, and `pair_fold_seed` in result summaries.
2. Preserve enough local-candidate metadata to support pair-level inclusion diagnostics.
3. Record `selected_candidate_key` and `evaluated_candidate_keys` using
   `support.size|degree|kernel`.
4. Keep current one-task failure isolation.

### S3R-Fix-3: Patch Merge and HTML Report

Modify:

`/Users/pgajer/current_projects/geosmooth/scripts/merge_ps_lps_s3r_light_run.R`

Changes:

1. Build task status from the manifest first, not from existing status files.
2. Left-join status files and result summaries.
3. Build pair rows from unique `pair_id` values in the manifest.
4. Include complete/incomplete pair accounting fields:
   - `full_status`
   - `screened_status`
   - `pair_status`
   - `pair_complete`
   - `pair_exclusion_reason`
5. Add screened-candidate inclusion diagnostics.
6. Add report sections:
   - design contract and seed validation summary;
   - task accounting by dataset/chart/search policy;
   - pair accounting by dataset/chart rule;
   - full versus screened Truth RMSE for complete pairs;
   - runtime ratio for complete pairs;
   - candidate inclusion diagnostics;
   - explicit limitations.
7. Write:
   - `task_status.csv`
   - `task_summary.csv`
   - `local_candidate_details.csv`
   - `full_vs_screened_pairs.csv`
   - `paired_summary_by_chart_rule.csv`

### S3R-Fix-4: Rerun Corrected S3R-light

Prepare and launch a corrected run with a new run id, for example:

```text
ps_lps_s3r_light_seedmatched_20260607_001
```

Configuration:

- same 14 frozen P7X first-batch assets;
- `n_reps = 3`;
- `chart_dim_rule in {auto, local.auto}`;
- `search_policy in {full, screened}`;
- backend fixed to `monomial_tiny_ridge`;
- kernel fixed to `tricube`;
- degree fixed to `2`;
- support grid `15:35`;
- lambda grid and guarded lambda search as in the original S3R-light;
- 10 local workers unless system load suggests a lower count;
- common hard timeout across both arms.

### S3R-Fix-5: Auditor Recheck Before S3R-expanded

After corrected S3R-light completes, produce:

- updated HTML report;
- `task_status.csv`;
- `task_summary.csv`;
- manifest-backed `full_vs_screened_pairs.csv`;
- short handoff for re-audit.

Do not launch S3R-expanded until the corrected S3R-light design and report pass re-audit.

## Handling Current S3R-light Run

Current run directory:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_20260607_001`

Decision:

- Keep the current run labeled as smoke/profiling only.
- Do not use its full-versus-screened Truth RMSE pair deltas for policy decisions.
- It may be allowed to finish if compute is available, because it can still inform runtime tails, timeout risk, worker robustness, and rough profiling.
- Any report or handoff generated from it should explicitly state:

```text
This run is not valid as paired full-versus-screened accuracy evidence because
full and screened response/fold seeds were not consistently matched.
```

## Requested Re-audit Scope

After implementation, please re-audit:

1. corrected manifest seed-pairing contract;
2. manifest QA failure behavior;
3. manifest-backed task and pair tables;
4. screened-candidate inclusion diagnostics;
5. corrected S3R-light report structure;
6. whether corrected S3R-light is sufficient to decide whether S3R-expanded should run, and with how many repetitions.
