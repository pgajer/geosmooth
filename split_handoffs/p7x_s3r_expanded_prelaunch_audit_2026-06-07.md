# P7X S3R-Expanded Prelaunch Audit

Generated: 2026-06-07

Auditor: Codex

Audited handoff:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_expanded_prelaunch_handoff_2026-06-07.md`

Relevant scripts inspected:

- `/Users/pgajer/current_projects/geosmooth/scripts/prepare_ps_lps_s3r_light_run.R`
- `/Users/pgajer/current_projects/geosmooth/scripts/launch_ps_lps_s3r_light_run.py`
- `/Users/pgajer/current_projects/geosmooth/scripts/merge_ps_lps_s3r_light_run.R`

Prior accepted light-run audit:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_light_corrected_run_audit_2026-06-07.md`

## Verdict

`blocked pending changes`

The proposed 20-repetition S3R-expanded design is scientifically valid and the preparer/launcher machinery appears capable of generating and running the paired expanded manifest. However, the prelaunch handoff has a central arithmetic/accounting error: it says 20 repetitions but gives the 10-repetition task and pair counts.

For 14 datasets, 20 repetitions, 2 chart-dimension rules, and 2 search policies, the expected accounting is:

```text
14 * 20 * 2 * 2 = 1120 tasks
14 * 20 * 2     = 560 full/screened pairs
```

The handoff currently states:

```text
14 * 20 * 2 * 2 = 560 tasks
14 * 20 * 2     = 280 pairs
```

Those are the counts for 10 repetitions, not 20. The handoff and expected accounting gates must be corrected before manifest generation and launch.

## Blocking Findings

1. P0 - The expected task and pair counts are wrong for a 20-repetition run.

   Location: `/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_expanded_prelaunch_handoff_2026-06-07.md`

   The handoff states `560 tasks` and `280 pairs` for 20 repetitions. The correct counts are `1120 tasks` and `560 pairs`. This affects the frozen design, required accounting section, auditor question 3, runtime framing, and any human interpretation of the prelaunch QA output. The preparer script itself uses `expected.tasks <- nrow(asset.manifest) * n.reps * length(chart.rules) * length(search.policies)`, so with `--n_reps=20` it should generate 1120 tasks. The document must agree with the manifest machinery before launch.

2. P1 - The current merge/report script is still S3R-light-specific and cannot satisfy the expanded report contract as written.

   Location: `/Users/pgajer/current_projects/geosmooth/scripts/merge_ps_lps_s3r_light_run.R`

   The script hardcodes S3R-light report title/text and includes a hardcoded callout that says `all 168 tasks completed successfully, giving 84 complete full/screened pairs`. It also lacks the required expanded-run report sections for 10-repetition interim summaries, 20-repetition summaries, by-dataset accuracy summaries, by-geometry-family accuracy summaries, and a final policy-decision section. This does not corrupt the computation, but it would make monitoring/final HTML output misleading. Fix before relying on merge output for expanded monitoring or final reporting.

## Non-Blocking Notes

1. Reusing the S3R-light preparer/launcher is acceptable if the handoff explicitly says the script names are legacy names and the generated `run_id`, `run_config.csv`, and report title identify the run as S3R-expanded. A rename would reduce confusion, but it is not necessary for computation.

2. The 10-worker local-only execution policy is reasonable. The light-run runtime tail had maximum observed task time about `2638.719` seconds and p95 about `1750.752` seconds, so a 7200-second per-task timeout is conservative.

3. The runtime estimate should be reworded after the count correction. The stated 9.5--11 hour estimate is plausible for a 20-repetition / 1120-task run if the light run took about 1.45 hours for 168 tasks at 10 workers. It is not consistent with the handoff's stated 560-task count.

4. A hard 10-repetition pause is not required if the team is comfortable spending the overnight compute. The predeclared `repetition <= 10` subset is a reasonable interim analysis subset. If the human wants an audit gate before spending the second half of compute, then the run should be staged as 10 + 10; otherwise a continuous 20-repetition launch is acceptable after the blockers are fixed.

5. The inspected scripts are currently untracked in the local git status. That is not a launch blocker in this local workflow, but the expanded run should record script paths and preferably script hashes or a code snapshot in `run_config.csv` or the final report for reproducibility.

## Required Changes

Before manifest generation:

- Fix the handoff/accounting contract to choose exactly one design:
  - 20 repetitions: `1120` tasks and `560` pairs; or
  - 10 repetitions: `560` tasks and `280` pairs.
- If keeping the proposed command `--n_reps=20`, update every `560 tasks` / `280 pairs` reference in the handoff to `1120 tasks` / `560 pairs`.
- Update the required manifest-level QA section to require exactly `1120` planned tasks and `560` planned pairs for the 20-repetition design.
- Update auditor question 3 accordingly.

Before launch or before using monitoring HTML:

- Generalize the merge/report script so expanded monitoring output does not claim S3R-light, 168 tasks, or 84 pairs.
- At minimum, make the title, callout task count, pair count, and "What We Learned" text data-driven from `task_manifest.csv`, `full_vs_screened_pairs.csv`, and `task_status.csv`.

Before final reporting:

- Add the required expanded summaries:
  - overall paired accuracy;
  - by chart rule;
  - by dataset;
  - by geometry family;
  - interim repetitions 1--10;
  - full repetitions 1--20;
  - runtime ratios and evaluated-candidate ratios;
  - candidate inclusion and match diagnostics;
  - explicit screened-policy decision section.

## Audit Question Answers

1. Is the proposed 20-repetition S3R-expanded design a valid extension of the corrected S3R-light run?

Yes in concept, but the handoff arithmetic must be corrected first. A true 20-repetition extension over the same 14 frozen assets, two chart rules, and two policies is valid and should produce 1120 tasks / 560 pairs.

2. Is reusing the parameterized S3R-light scripts acceptable, despite the script names, or should they be renamed before launch to avoid ambiguity?

Acceptable for manifest generation and task execution. The preparer takes `run_id`, `n_reps`, `n_workers`, `task_timeout_sec`, and `base_seed`; the launcher uses the generated manifest and failure-isolated worker execution. Renaming is optional. The merge/report script, however, must be generalized before expanded monitoring/final reporting because it contains hardcoded S3R-light text.

3. Are 560 tasks and 280 pairs the correct expected counts?

No. For 20 repetitions the correct counts are 1120 tasks and 560 pairs. The 560-task / 280-pair counts correspond to a 10-repetition run.

4. Is the seed-matching contract complete and auditable?

Yes, once the counts are corrected. The preparer writes `pair_id`, `pair_seed_base`, `fold_seed`, `response_seed`, `search_policy`, asset path, and source hash. Its QA checks exactly two arms per pair, one full arm, one screened arm, matched response seeds, matched fold seeds, asset presence, source-hash shape, and balanced design cells.

5. Is the planned 10-worker local-only execution reasonable, given the need to leave machine capacity for another active project?

Yes. The worker count is conservative relative to a local overnight run and should leave headroom. The expected wall time should be recalculated using 1120 tasks, not 560 tasks.

6. Is the 7200-second per-task timeout appropriate, given the corrected S3R-light runtime tail?

Yes. The corrected S3R-light maximum observed task time was about 2639 seconds, with the long tail driven by `SYN-RANK-BLOCKS-N600-P100`. A 7200-second timeout is a reasonable safety margin and the launcher records timeout status explicitly.

7. Is the predeclared 10-repetition readout acceptable as an analysis subset, or should the run be staged as `10 + 10` with a hard pause?

The predeclared subset is acceptable. A hard `10 + 10` pause is only needed if the human wants a mid-run audit gate before spending the second half of compute. For an overnight policy-grade run, a continuous 20-repetition launch is acceptable after blockers are fixed.

8. Are the required accounting and candidate-diagnostic outputs sufficient?

Yes for manifest/runtime/pair/candidate accounting. The conventions carried forward from S3R-light are sufficient: explicit task statuses, complete/incomplete pair accounting, seed mismatch flags, evaluated-candidate counts from detail rows, support inclusion, candidate-key inclusion, support match, and lambda match.

9. Are the required report sections sufficient for a policy decision about screened PS-LPS support search?

Yes as specified in the handoff, but the current merge/report script does not yet implement them. The final expanded report must include the specified by-dataset, by-geometry-family, interim 10-repetition, full 20-repetition, runtime, candidate-count, candidate-inclusion, and policy-decision sections.

10. Are there any blockers before manifest generation and launch?

Yes. The task/pair count mismatch is a blocker before manifest generation and launch. The merge/report script mismatch is a blocker before relying on expanded monitoring/final report output; if the team intends to monitor via the generated HTML during the run, fix it before launch as well.

## Recommendation

Revise the handoff to use 1120 tasks / 560 pairs for the 20-repetition design, or explicitly change the command to `--n_reps=10` if the intended run is actually 560 tasks / 280 pairs. After that revision, re-audit the corrected prelaunch handoff and the generated manifest before launch.

If the 20-repetition design is retained and the handoff is corrected, the computation plan is otherwise acceptable.
