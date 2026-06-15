# P7X S3R-Light Corrected Run Audit

Generated: 2026-06-07

Auditor: Codex

Audited handoff:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_light_corrected_run_handoff_2026-06-07.md`

Audited corrected run bundle:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_20260607_002`

Primary HTML report:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_seedmatched_20260607_002/reports/ps_lps_s3r_light_report.html`

## Verdict

Pass for S3R-light. The corrected run is a valid seed-matched full-versus-screened paired light run, the accounting is internally consistent, and there are no remaining blockers before launching S3R-expanded.

The result should still be treated as light/profiling evidence rather than final policy evidence. It is strong enough to justify S3R-expanded and to keep screened PS-LPS in the run plan, but not strong enough by itself to freeze screened search as the routine/default policy.

Recommended next step: launch S3R-expanded with the same paired manifest design. Prefer 20 repetitions if compute budget allows; otherwise run 10 repetitions as an interim milestone and keep the manifest extendable to 20.

## Blocking Findings

None.

## Non-Blocking Notes

1. The `auto` chart-rule mean screened-minus-full Truth RMSE delta is positive: `0.0039435652`, with reported 95% interval `[0.0003388079, 0.0075483225]`. The median remains `0`, so this is not a blocker, but it is exactly why S3R-expanded should run before making a final default-policy claim.

2. Screened search often does not evaluate the exact support size selected by full search. Across all 84 complete pairs, full-selected support inclusion is `29/84 = 0.3452`. This does not invalidate the screened result because paired Truth RMSE is usually close, but expanded analysis should keep both accuracy delta and candidate-inclusion diagnostics.

3. The report is appropriately concise for this corrected-run audit and links the detailed CSV artifacts instead of embedding long tables. I did not find a report-style blocker in the regenerated HTML.

## Checks Performed

- Confirmed the handoff points to the corrected run bundle `ps_lps_s3r_light_seedmatched_20260607_002`, not the earlier flawed `ps_lps_s3r_light_20260607_001` bundle.
- Read `PRELAUNCH_QA_SUMMARY.txt`, `manifest_qa_summary.csv`, `manifest_pair_qa.csv`, `task_manifest.csv`, `tables/task_status.csv`, `tables/task_summary.csv`, `tables/full_vs_screened_pairs.csv`, `tables/local_candidate_details.csv`, `tables/paired_summary_by_chart_rule.csv`, and `tables/candidate_inclusion_diagnostics.csv`.
- Recomputed task and pair status counts from CSV.
- Recomputed candidate counts from `local_candidate_details.csv` using `local.candidate.status == "evaluated"` and compared them against `full_vs_screened_pairs.csv`.
- Inspected the HTML report text for seed validation, task accounting, candidate-count explanations, inclusion diagnostics, summary interpretation, and artifact links.
- Confirmed all five report SVG figures exist and have nonzero payloads.

## Audit Question Answers

1. Does the corrected run use a valid seed-matched full-versus-screened paired design?

Yes. `manifest_pair_qa.csv` reports 84 intended pairs, each with one full arm and one screened arm. All 84 pairs have one response seed value and one fold seed value. `full_vs_screened_pairs.csv` also reports `response_seed_match == TRUE` and `fold_seed_match == TRUE` for all 84 pairs.

2. Is the 168 task / 84 pair accounting correct?

Yes. `task_status.csv` has 168 rows, all `status == ok`. `full_vs_screened_pairs.csv` has 84 rows, all `pair_status == complete_ok` and `pair_complete == TRUE`. The chart-rule split is balanced: 42 `auto` pairs and 42 `local.auto` pairs.

3. Are failure, timeout, nonfinite, and missing-result statuses explicit enough for audit?

Yes. The report includes task accounting and states 168 attempted tasks, 168 successful tasks, 0 nonfinite fits, 0 errors, and 0 timeouts. `task_status.csv` confirms all 168 status and result files exist and all statuses are `ok`.

4. Are the candidate-count and inclusion diagnostics now computed correctly from `local_candidate_details.csv` rather than from support-size numeric differences?

Yes. Recomputing evaluated candidate counts from `local_candidate_details.csv` produced zero mismatches against `full_vs_screened_pairs.csv`. Full search evaluated 21 candidates in all 84 pairs. Screened search evaluated fewer candidates, commonly 4 candidates, with a distribution of `4:48`, `5:3`, `6:1`, `7:1`, `8:1`, `11:16`, and `12:14`.

5. Is the report interpretation of Figure 3 correct?

Yes. Figure 3 uses screened/full evaluated-candidate count ratios. The median candidate-count ratio is approximately `0.1905`, and the median runtime ratio is approximately `0.3796`. The report correctly separates the mechanism diagnostic from realized wall-clock speedup and states that screened search is faster mainly because it evaluates fewer local candidates.

6. Is the report interpretation of Figure 4 correct?

Yes. In this run degree and kernel are fixed, so candidate-key inclusion is effectively support-size inclusion. The report correctly says support/candidate-key inclusion is modest: `16/42 = 0.3810` for `auto`, `13/42 = 0.3095` for `local.auto`, and `29/84 = 0.3452` overall. Lambda-match rates are higher: `28/42 = 0.6667` for `auto`, `30/42 = 0.7143` for `local.auto`, and `58/84 = 0.6905` overall. The interpretation that exact full-selected support inclusion is modest but paired Truth RMSE remains close is supported by the tables.

7. Does S3R-light support using screened PS-LPS as the routine run policy, or should it be treated only as a smoke/profiling result pending S3R-expanded?

Treat it as valid smoke/profiling evidence pending S3R-expanded. It supports continuing with screened search as the practical candidate policy in expanded experiments, but it should not by itself settle the default routine policy because the run has only 3 repetitions per dataset and the `auto` chart-rule mean delta is positive.

8. If S3R-expanded should proceed, should it use 10 repetitions, 20 repetitions, or another design?

S3R-expanded should proceed. Prefer 20 repetitions for a policy-grade decision if compute budget allows, because the light run already shows a small positive mean delta for `auto` and expanded evidence will need stable dataset-family and chart-rule summaries. If compute is constrained, run 10 repetitions first as a planned interim checkpoint, but generate the manifest so it can be extended to 20 without changing seeds or design contracts.

9. Are there any remaining blockers before S3R-expanded launch?

No blockers. The corrected run resolves the earlier seed-pairing and incomplete-pair accounting issues. Keep the same paired seed discipline, explicit status accounting, detail-derived candidate counts, and linked detailed artifacts in the expanded run.

## Key Verified Numbers

- Planned tasks: 168
- Successful tasks: 168
- Planned pairs: 84
- Complete ok/ok pairs: 84
- Seed-matched pairs: 84
- Seed mismatches: 0
- Overall median screened-minus-full Truth RMSE delta: `0`
- Overall mean screened-minus-full Truth RMSE delta: `0.0021108144`
- Overall median screened/full runtime ratio: `0.3795842307`
- Full evaluated candidates: 21 for all 84 pairs
- Screened evaluated candidates: median around 4 to 4.5 by chart rule
- Overall support/candidate-key inclusion: `29/84 = 0.3452`
- Overall lambda match: `58/84 = 0.6905`

## Recommendation For S3R-Expanded

Launch S3R-expanded with:

- the same corrected pair identity: `(dataset_id, repetition, chart_dim_rule)`;
- response and fold seeds shared within each full/screened pair;
- explicit `ok`, `error`, `timeout`, `nonfinite`, and missing-result accounting;
- candidate-count diagnostics recomputed from candidate-detail rows;
- per-chart-rule and per-dataset-family summaries;
- a predeclared interim readout if using 10 repetitions before extending to 20.

Do not modify the screened policy before S3R-expanded unless the implementer discovers a new correctness bug. The current evidence is clean enough to test the policy at expanded scale.
