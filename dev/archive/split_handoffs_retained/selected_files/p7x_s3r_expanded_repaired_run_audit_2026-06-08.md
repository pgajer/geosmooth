# P7X S3R Expanded Repaired Run Audit

Auditor: Codex
Date: 2026-06-08

## Verdict

Accepted with minor comments.

The repaired S3R-expanded bundle is internally consistent and supports using screened PS-LPS as the routine experimental support-search policy for this class of runs, with full support-grid search retained as a validation/reference mode. I found no blocking accounting, provenance, leakage, or implementation-safety issue in the repaired bundle.

The only report-level issue is minor polish: the HTML report's "Recommended Next Step" paragraph is written as an audit instruction rather than as reader-facing report prose. It should be rewritten before this report is treated as a durable/public-facing analysis artifact, but it does not block accepting the run.

## Audited Inputs

- Handoff: `/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_expanded_repaired_run_auditor_handoff_2026-06-08.md`
- Repaired bundle: `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001`
- Source run: `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_20260607_001`
- Repair run: `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_screened_repair_guarded_20260608_001`
- Main HTML report: `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001/reports/ps_lps_s3r_expanded_repaired_results_report.html`
- Main implementation files inspected: `R/ps_lps.R`, `tests/testthat/test-ps-lps.R`, `scripts/render_ps_lps_s3r_expanded_results_report.R`

## Blocking Findings

None.

## Minor Comments

1. The HTML report includes an audit-facing instruction in its "Recommended Next Step" section:
   "Audit this repaired bundle against the original S3R-expanded handoff..."

   For a durable reader-facing report, replace this with a conclusion such as: "Screened PS-LPS is recommended as the routine experimental support-search policy for similar runs, while full-grid search remains the validation/reference mode for spot checks, new geometry families, and publication-critical sensitivity checks."

2. The scientific conclusion should stay slightly nuanced. The median paired Truth RMSE difference is exactly zero overall, but the `chart.dim = "auto"` subset has a small positive mean shift favoring full search. This is not a blocker because the effect is small and the median/paired accounting supports the practical conclusion, but it argues for retaining full-search validation checks.

3. Candidate inclusion is only about 48% overall. Screening often reaches the same or comparable result without retaining the exact full-search support candidate, which is acceptable here, but future reports should continue showing support/candidate inclusion and lambda-match diagnostics.

## Audit Question Responses

### 1. Does the merged repaired bundle preserve original successful rows and only replace failed screened tasks?

Yes.

- Original expanded run: 560 full tasks OK; 509 screened tasks OK; 51 screened tasks failed.
- Repair run: 51 screened tasks OK.
- Merged repaired bundle: 560 full tasks OK; 560 screened tasks OK.
- The 51 merged rows whose result paths point into the guarded repair run match exactly the 51 original failed screened task IDs.
- Non-failed original result paths are preserved in the merged bundle.

### 2. Does the repair manifest preserve scientific settings?

Yes.

I compared the repaired rows against the original failed screened rows on the scientific settings available in the manifests, including dataset, chart-dimension rule, backend variant, design basis, design drop tolerance, ridge multiplier grid, ridge condition cap, support grid, degree grid, kernel grid, lambda grid, lambda-search policy, and screened-search controls. The comparison found zero setting differences.

The repair changes the screening robustness path, not the paired experimental design.

### 3. Does the guarded LPS repair mask genuine failures?

No evidence of masking.

The screened repair path uses an explicit screening helper with an auditable screen backend:

- `screening.design.basis = orthogonal.polynomial.drop`
- `screening.ridge.condition.max = 1e12`
- screen ridge grid augmented with small ridge values
- explicit `ps_lps_lps_screen_failed` error class if screening and fallback both fail

In the repaired bundle, all 51 repaired screened tasks have local-candidate telemetry. Across the 1071 repaired screened candidate rows:

- `screening.design.basis`: all `orthogonal.polynomial.drop`
- `screening.degree.used`: all `2`
- `screening.fallback.used`: all `FALSE`
- local candidate rows: 606 evaluated, 465 screened out

So the repaired run did not silently use the degree-1 fallback for these repaired rows, and failures were not converted into success without candidate-level evidence.

### 4. Is repair telemetry sufficient?

Yes for this stage.

The merged tables contain enough telemetry to audit status, pair matching, seed matching, candidate inclusion, screening reasons, screen design basis, screen degree, ridge-grid metadata, ridge condition cap, fallback use, local candidate status, elapsed time, and candidate counts.

Useful future addition: include a compact repair-specific summary table in the HTML report itself, listing the 51 repaired task IDs by dataset/chart rule and summarizing screen basis, fallback use, and candidate counts. The data are present in CSVs, but a reader should not have to reconstruct this manually.

### 5. Does the HTML report satisfy the project HTML report guidelines?

Mostly yes, with one minor report-prose issue.

Strengths:

- Answer-first framing is present.
- Methods and quantities are defined.
- Fit-status accounting appears before conclusions.
- Figures are captioned and directly interpreted.
- Long tables are kept out of the body and linked in reproducibility.
- Build timestamp uses Eastern wall time.
- Local figure and table links resolve.

Minor deviation:

- The final "Recommended Next Step" paragraph is written as a worker/auditor instruction. It should be rewritten as reader-facing interpretation before durable publication.

### 6. Does the repaired report cover all 560 pairs with no stale pre-repair language?

Yes for the core accounting.

The report states:

- 560 full-search rows completed.
- 560 screened rows completed.
- 560 complete seed-matched pairs.
- Screened errors total 0.
- Full non-OK rows total 0.

I did not find stale claims that the repaired bundle still has screened failures. The report does mention the repair and the original failure context, which is appropriate provenance.

### 7. Are accuracy/runtime conclusions supported?

Yes, with nuance.

Key reconstructed metrics:

- Complete pairs: 560 / 560.
- Response seed mismatches: 0.
- Fold seed mismatches: 0.
- Overall mean screened-minus-full Truth RMSE: 0.000319109.
- Overall median screened-minus-full Truth RMSE: 0.
- Delta signs: screened better 148, ties 269, full better 143.
- Median elapsed ratio screened/full: 0.4379457.
- Screened faster than full: 560 / 560 pairs.
- Median candidates evaluated: screened 5.5 versus full 21.
- Overall full-support inclusion in screened evaluated supports: 0.4803571.
- Overall lambda-match rate: 0.8089286.

By chart-dimension rule:

- `auto`: 280 complete pairs; mean delta 0.0006577171; 95% interval [0.00004580991, 0.0012696243]; median delta 0; median runtime ratio 0.3684665.
- `local.auto`: 280 complete pairs; mean delta -0.00001949904; 95% interval [-0.0002979636, 0.0002589655]; median delta 0; median runtime ratio 0.4456354.

The speed conclusion is strongly supported. The accuracy conclusion is supported in median/practical terms, but not as "exactly identical" across all summaries because the `auto` mean shift is small but positive.

### 8. Should screened PS-LPS be promoted to routine experimental policy?

Yes, for routine experimental runs resembling this S3R-expanded setting.

Recommended policy:

- Use screened PS-LPS as the routine support-search policy for broad experimental sweeps.
- Keep full support-grid PS-LPS as the validation/reference mode.
- Run periodic full-vs-screened paired audits, especially for new geometry families, new chart-dimension policies, publication-critical results, or cases where screening telemetry shows low inclusion, high fallback use, or unusual candidate counts.
- Continue reporting fit-status accounting, seed matching, candidate inclusion, lambda matching, runtime ratios, and dataset-level deltas.

## Verification Performed

Data/provenance checks:

- Parsed repaired manifest, task status, paired table, local candidate details, and summary tables.
- Compared original failed screened task IDs with repair task IDs and merged repair-path rows.
- Compared scientific settings between original failed rows and repaired rows.
- Checked all result/status/log paths referenced by the repaired manifest.
- Checked paired row counts, pair statuses, seed matching, runtime ratios, candidate counts, and inclusion diagnostics.

Implementation checks:

- Inspected screened repair implementation in `R/ps_lps.R`.
- Inspected focused tests in `tests/testthat/test-ps-lps.R`.
- Ran focused PS-LPS test file successfully:

```text
Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-ps-lps.R", reporter = "summary")'
DONE
```

Report checks:

- Read the HTML report against the HTML report style guide.
- Checked that all six PNG figure references resolve.
- Checked that all local reproducibility table links resolve.
- Grepped for stale failure/accounting language.
- Ran `git diff --check` on the relevant changed files; no whitespace errors were reported.

## Residual Risk

This audit did not rerun the full expanded experiment. It validates the cached repaired bundle, provenance, tables, report, focused PS-LPS tests, and relevant implementation path. That is appropriate for this handoff because the task is to audit the repaired run bundle, not to regenerate the computational sweep.
