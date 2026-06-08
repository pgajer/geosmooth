# Broader P7X-Style LPS / PS-LPS Backend Comparison Audit

Auditor: Codex
Date: 2026-06-07 05:52:22 EDT

## Verdict

Pass as a broader backend triage run, with report/table caveats.

The run answers the main operational question well enough to guide the next
comparison: `orthogonal_drop_adaptive_tiny` is the only LPS backend in this
grid with complete finite coverage, `weighted_qr_drop_tiny` is not attractive
for routine continuation, and the next focused run should usually compare
`monomial_tiny_ridge` against `orthogonal_drop_adaptive_tiny`.

This run should not be treated as a package-default decision or a final
performance benchmark. The PS-LPS guarded/drop long tail is severe, the
timeout rows are not fully represented in `combined_results.csv`, and the HTML
report does not explicitly label them as timeouts.

## Findings

### Nonblocking: `coverage_by_arm.csv` uses completed-result counts, not planned-task counts

`coverage_by_arm.csv` is computed from `combined_results.csv`, which excludes
the 8 killed/error tasks. As a result, guarded/drop PS-LPS arms show
`tasks = 12` rather than the planned `14`; the missing two tasks are only
visible through `task_status.csv`.

This does not invalidate the run, but future reports should make this explicit
or add planned/ok/nonfinite/error columns from the status table. Otherwise a
reader may read `tasks` as the planned arm size.

### Nonblocking: timeout/error reporting is too generic in the HTML report

The HTML report has the right sections and links to both `combined_results.csv`
and `task_status.csv`, but it does not contain the words `timeout` or
`worker_exit`. The error table says only that the worker exited nonzero or was
killed.

Because timeout behavior is one of the main audit questions, future reports
should include an explicit timeout/termination paragraph, the affected datasets,
and the effective elapsed-time range from `python_launcher.log`.

### Follow-up: two LPS monomial nonfinite rows had finite CV candidates

Most nonfinite rows are clean guard failures: 36 of 38 have
`finite_cv_candidates = 0`. Two exceptions were:

- `LA-D2-RAW-N500`, `lps`, `auto`, `monomial_tiny_ridge`, with 2 finite CV
  candidates but nonfinite final fitted/truth RMSE.
- `LA-D3-RAW-N500`, `lps`, `auto`, `monomial_tiny_ridge`, with 3 finite CV
  candidates but nonfinite final fitted/truth RMSE.

This is not evidence of a broad status-propagation bug, because the affected
rows are confined to LPS monomial `auto` and the task status records them as
`nonfinite_fit`. Still, the next runner should record final-refit status
separately from CV-candidate status so these cases are easier to diagnose.

## Audit Questions

### 1. Does the run answer the intended broader backend question?

Yes, for triage.

The broader grid exercises 14 frozen assets, `auto` and `local.auto`, LPS and
PS-LPS, support grid `15:35`, and three backend variants. It is enough to say:

- `orthogonal_drop_adaptive_tiny` is a credible guarded LPS backend: 28/28 LPS
  rows completed with finite selected fits across both chart-dimension rules.
- `monomial_tiny_ridge` remains a fast, viable PS-LPS baseline: 28/28 PS-LPS
  rows completed with finite selected fits.
- `weighted_qr_drop_tiny` is not a good routine backend candidate: it has the
  worst LPS finite coverage and the slowest PS-LPS median elapsed times.

I recommend that the next routine comparison drop `weighted_qr_drop_tiny` and
compare `monomial_tiny_ridge` versus `orthogonal_drop_adaptive_tiny`, while
retaining `weighted_qr_drop_tiny` only for occasional diagnostic runs.

### 2. Are nonfinite rows concentrated as expected?

Mostly yes.

All 38 nonfinite rows are LPS rows. None are PS-LPS rows. They are concentrated
in monomial and weighted-QR:

- LPS monomial: 9/14 nonfinite for `auto`, 9/14 nonfinite for `local.auto`.
- LPS weighted-QR: 10/14 nonfinite for `auto`, 10/14 nonfinite for
  `local.auto`.
- LPS orthogonal: 0/14 nonfinite for `auto`, 0/14 nonfinite for `local.auto`.

That pattern supports the focused-comparison conclusion that the orthogonal
backend gives the guarded LPS path much better finite coverage.

The two LPS monomial rows with finite CV candidates but nonfinite final fits
should be instrumented more clearly in future runs, but they do not change the
overall concentration finding.

### 3. How should the timeout/error rows be interpreted?

For this exact grid, they are operational infeasibility signals for routine
P7X comparisons of guarded/drop PS-LPS on the hardest fixtures.

The 8 errors were all PS-LPS guarded/drop rows on two datasets:

- `LA-13K-SUB-N500`
- `SYN-RANK-BLOCKS-N600-P100`

and only for:

- `weighted_qr_drop_tiny`
- `orthogonal_drop_adaptive_tiny`

The monomial PS-LPS rows completed on those same datasets, so the timeout
pattern is not just "PS-LPS is impossible" or "the datasets are impossible."
It points to the cost of the guarded/drop design-basis variants under the
current PS-LPS grid/search implementation.

If accuracy on those exact rows is needed, rerun with a reduced support grid
or smaller lambda-sync search before drawing accuracy conclusions. But for
routine P7X-style throughput, the current timeout evidence is already enough
to avoid unrestricted guarded/drop PS-LPS runs on the full grid.

### 4. Does `orthogonal_drop_adaptive_tiny` remain credible?

Yes, especially for LPS.

For LPS, orthogonal completed all 28 rows with finite selected fits. That is
the strongest stability signal in the run.

For PS-LPS, orthogonal completed 24/28 planned rows with no nonfinite selected
fits among completed rows, but it timed out on four hard-dataset arms. That
means it remains credible, but not yet routine-default-ready for PS-LPS at
support grid `15:35` unless timeout/reduced-grid policy is part of the
experiment design.

Median successful PS-LPS elapsed time was also much higher for orthogonal than
for monomial:

- `auto`: about 607 seconds for orthogonal versus 95 seconds for monomial.
- `local.auto`: about 642 seconds for orthogonal versus 143 seconds for
  monomial.

So the backend is numerically credible but operationally expensive.

### 5. Does the HTML report contain enough design/result detail?

Mostly, but not quite enough on timeouts.

The report states the run purpose, the broader scope, status counts, coverage
by arm, Truth RMSE plot, best rows, compact result table, nonfinite rows, and
error rows. It links to `combined_results.csv` and `task_status.csv` and avoids
presenting the plot as complete over failed rows.

Missing or weak pieces:

- It does not explicitly say that the 8 error rows were manual long-tail
  terminations/timeouts.
- It does not show `error_class`, so `worker_exit_-15` is hidden.
- It does not explain that `combined_results.csv` has 160 rows while
  `task_status.csv` has all 168 tasks.
- `coverage_by_arm.csv` is easy to misread because its `tasks` column counts
  completed result rows, not planned rows.

These are report polish/traceability issues, not blockers for using the audit
bundle.

### 6. Should future supervisors use a hard per-task timeout, and is 90 minutes appropriate?

Yes, future supervisors should use a hard per-task timeout by default.

For routine backend triage at n=500-600, 90 minutes is a reasonable operational
SLA, but it must be interpreted carefully. A strict 90-minute timeout would
have killed several successful guarded/drop PS-LPS rows in this run:

- 8 successful `weighted_qr_drop_tiny` PS-LPS rows exceeded 5400 seconds.
- 2 successful `orthogonal_drop_adaptive_tiny` PS-LPS rows exceeded 5400
  seconds.
- No successful `monomial_tiny_ridge` PS-LPS rows exceeded 5400 seconds.

So 90 minutes is appropriate if the goal is routine throughput and backend
screening. If the goal is accuracy-complete results on hard fixtures, use a
reduced grid or a special long-run queue rather than simply raising the
timeout for all tasks.

## Verification Performed

- Read the handoff, run config, launcher, merge script, task runner, HTML
  report, task status table, combined results, coverage table, best-row table,
  and launcher log.
- Recomputed status counts and arm-level status summaries from CSVs.
- Checked that `combined_results.csv` contains 160 completed/nonfinite rows and
  `task_status.csv` contains all 168 planned tasks.
- Confirmed the 8 error rows match the handoff's listed timeout/killed tasks.
- Checked PS-LPS elapsed-time tails, including rows above 5400 seconds.
- Checked the HTML report for core design terms, table links, and timeout/error
  language.

## Recommendation

Accept this run as the broader backend triage result.

Next run:

- Drop `weighted_qr_drop_tiny` from the routine arm set.
- Compare `monomial_tiny_ridge` against `orthogonal_drop_adaptive_tiny`.
- Keep both `auto` and `local.auto`.
- Use a hard timeout recorded as `task_timeout_<seconds>s`.
- Add planned/ok/nonfinite/error arm coverage to the generated report.
- For PS-LPS guarded/drop on hard fixtures, either reduce the support/lambda
  grid or route those tasks to a separate long-run profile.
