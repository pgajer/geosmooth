# P7X / S3R Audit Response Plan Audit

Auditor: Codex
Date: 2026-06-07 15:32:01 EDT

Scope:

- Audit response / corrective plan:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_response_2026-06-07.md`
- Original audit:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_2026-06-07.md`

## Verdict

Accepted, with mandatory implementation details below.

The response correctly accepts all audit blockers: the current S3R-light run is
only smoke/profiling evidence, the paired seed mismatch must be fixed before
any full-versus-screened policy decision, pair tables must be manifest-backed,
candidate-inclusion diagnostics are required, and S3R-expanded must wait until
corrected S3R-light passes re-audit.

I do not see a conceptual blocker in the proposed corrective plan. The plan is
sound enough for implementation, but the implementer should treat the
clarifications below as part of the contract.

## Required Clarifications Before Implementation

### 1. Seed formula must be explicit and precedence-safe

The plan says `pair_response_seed = f(dataset_id, repetition, chart_dim_rule)`
and `pair_fold_seed = g(dataset_id, repetition, chart_dim_rule)`. That is the
right contract, but the implementation must use explicit intermediate variables
and parentheses rather than a compact inline expression.

Required behavior:

- `response_seed` and `fold_seed` must be identical for `full` and `screened`
  within each `(dataset_id, repetition, chart_dim_rule)` pair.
- `response_seed` and `fold_seed` may differ across chart rules and repetitions.
- `search_policy` must not enter the seed formula.
- The prepare script must print and/or write a validation summary with:
  total planned pairs, seed-matched pairs, mismatched pairs, and arm balance.

### 2. Candidate identity should be defined, not just "where identifiable"

The response says to add `full_selected_candidate_in_screened_candidates`,
where identifiable. The implementer should make the candidate identity explicit
so this does not become a soft or skipped diagnostic.

Minimum candidate identity:

- support size;
- degree;
- kernel;
- evaluated/not-evaluated status in screened;
- selected lambda when comparing selected candidate outcomes.

At minimum, the pair table should include:

- `full_support_in_screened_evaluated_supports`;
- `full_candidate_key`;
- `screened_evaluated_candidate_keys` or a linked candidate-detail table;
- `full_candidate_key_in_screened_evaluated_candidates`;
- `support_match`;
- `lambda_match`.

If exact candidate-key matching is impossible from existing `fit.lps` return
objects, that limitation should be explicitly recorded in the corrected report,
and support-level inclusion must still be computed.

### 3. Manifest-backed status table should include launched/running states

The response mentions `missing` or `not_started`, which is good. The status
contract should distinguish these cases:

- `not_started`: no status file and no result file;
- `running`: status file exists and says running;
- `ok`;
- `nonfinite_fit`;
- `error`;
- `timeout`;
- `missing_or_corrupt_status`: status file exists but cannot be parsed.

This matters because the run may be audited while still active.

### 4. Corrected S3R-light should have a pre-launch QA gate

Before launching the corrected run, the preparer should create the manifest and
run a validation command without launching workers. Launch should proceed only
after the manifest QA passes.

Required checks:

- 168 planned tasks for `14 * 3 * 2 * 2`;
- 84 planned pairs;
- exactly two arms per pair;
- exactly one `full` and one `screened` arm per pair;
- zero seed mismatches;
- no missing asset paths;
- no missing or malformed source hashes;
- balanced counts by dataset, repetition, chart rule, and search policy.

### 5. Current S3R-light reporting must label the run invalid for paired accuracy

The plan correctly says the current run may finish for profiling. Any report
generated from the current run should include a visible warning near the top:

```text
This run is not valid as paired full-versus-screened accuracy evidence because
full and screened response/fold seeds were not consistently matched.
```

That warning should also appear in any handoff that cites the current run.

## Checks Against Original Audit Findings

- Pair seed mismatch: addressed by the plan, pending implementation.
- Dropped failed/incomplete pairs: addressed by manifest-backed pair tables,
  pending implementation.
- Candidate inclusion diagnostics: addressed in direction, but needs the
  candidate-identity clarification above.
- Manifest-backed task status: addressed, with the additional state distinctions
  above.
- S3R-expanded gating: addressed. The plan correctly says not to launch
  S3R-expanded until corrected S3R-light passes re-audit.

## Recommendation

Proceed with the corrective implementation. After implementation, re-audit the
new manifest before launching the corrected S3R-light run, then re-audit the
completed corrected report before using results to decide whether S3R-expanded
should run with 10 or 20 repetitions.
