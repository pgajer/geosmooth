# HTML Report Style Audit Addendum

Auditor: Codex
Date: 2026-06-07 06:02:00 EDT

Scope:

- HTML report:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/reports/lps_ps_lps_backend_broader_p7x_comparison.html`
- Local style note:
  `/Users/pgajer/.codex/notes/agent_instructions/reports/html_report_style_guide.md`

## Verdict

The current HTML report is not ready under the Codex HTML report style guide.
The result bundle is useful, but the report body reads like a large execution
table dump with one crowded overview plot. It needs a report redesign before it
can serve as a readable methods/results document for the P7X backend decision.

This is a report-quality blocker, not a blocker on the underlying run.

## Main Deviations From The HTML Report Note

### 1. The main overview figure is not readable

The single Truth RMSE SVG combines all datasets, methods, chart-dimension
rules, and backend variants in one dense point plot. With 14 datasets and many
arms, labels and arm offsets are too crowded for the figure to answer a clear
question.

Required worker action:

- Replace the combined overview with a figure design split by dataset or by
  dataset family.
- Do not rely on one all-arms plot as the main evidence figure.
- Prefer a small set of readable diagnostic figures, for example:
  - a fit-status accounting figure by method/chart/backend;
  - a Truth RMSE figure split into LPS and PS-LPS panels;
  - paired deltas versus a declared reference backend, shown per dataset;
  - a dataset-level small-multiple view or appendix gallery for all datasets.

The regenerated report should explain how to read each figure and interpret
what it shows.

### 2. Timing is missing as a first-class result

The report includes `elapsed_sec` in a long table, but it has no runtime/timing
section. Timing is central here because the main practical issue is the
PS-LPS long tail and the killed guarded/drop tasks.

Required worker action:

- Add a dedicated timing section.
- Define exactly what `elapsed_sec` measures: end-to-end isolated R task wall
  time, including CV/search/final fit as applicable.
- Include timing by method/chart/backend, preferably on a log scale.
- Include timing split by dataset, because the hard datasets dominate the
  conclusion.
- Explicitly show or summarize the killed/error rows alongside completed rows.
- State that a strict 5400 second timeout would have killed several successful
  guarded/drop PS-LPS rows, not only the 8 manually killed rows.

Suggested figures:

- Runtime distribution by backend and method with log-scaled seconds.
- Dataset-by-method runtime heatmap or dot plot.
- A small table of timeout/error rows with `error_class` and elapsed time from
  the launcher log when available.

### 3. Long tables dominate the report body

The report embeds 6 tables and roughly 241 table rows. The style guide says
large tables and raw diagnostics should be linked as artifacts, not printed in
the main report body.

Required worker action:

- Remove the 160-row compact result table from the main body.
- Link `combined_results.csv`, `task_status.csv`, `coverage_by_arm.csv`, and
  `best_by_dataset.csv` as audit artifacts.
- Keep only short summary tables in the body, ideally:
  - status counts;
  - concise arm coverage with planned/ok/nonfinite/error counts;
  - a short timeout/error table;
  - optionally a small "top-line decision summary" table.
- Add a nearby variable dictionary for every displayed table. Define
  `ok`, `nonfinite_fit`, `error`, `finite_cv_candidates`,
  `total_cv_candidates`, `elapsed_sec`, `Truth RMSE`, and `selected CV RMSE`.

### 4. There is essentially no interpretation

The report has Purpose, Status Counts, Coverage, Truth RMSE, Best Row,
Compact Result Table, Nonfinite Fits, and Errors sections, but no real Results
Summary, Discussion, What We Learned, Limitations, or Recommendations section.

Required worker action:

- Add a "Results Summary And Discussion" section that answers the run's
  original questions directly.
- Add a "What We Learned" section that separates:
  - positive evidence for `orthogonal_drop_adaptive_tiny` in LPS;
  - negative/operational evidence against routine `weighted_qr_drop_tiny`;
  - mixed evidence for PS-LPS guarded/drop variants because of long runtimes;
  - remaining uncertainty due to killed tasks and descriptive-only comparisons.
- State the next methodological step: likely compare
  `monomial_tiny_ridge` versus `orthogonal_drop_adaptive_tiny`, with a hard
  timeout and report-level planned/ok/nonfinite/error accounting.

### 5. Timeout/error handling is not sufficiently visible

The handoff says the 8 error rows were manually terminated after the long tail.
The HTML report only says "worker process exited nonzero or was killed" and
does not use the words `timeout`, `worker_exit_-15`, or `task_timeout`.

Required worker action:

- Add an explicit timeout subsection.
- Include `error_class` in the error table.
- Explain that `combined_results.csv` has 160 completed/nonfinite rows, while
  `task_status.csv` has all 168 planned tasks.
- Explain that the current `coverage_by_arm.csv` `tasks` column counts
  completed-result rows, not planned rows, or regenerate that table with
  planned/ok/nonfinite/error counts from `task_status.csv`.

### 6. Provenance and reproducibility are incomplete

The report shows a build timestamp and run directory, but it does not provide
a clear reproducibility appendix with the result-generation command, report
render/merge command, task manifest, run config, worker script, and result
bundle links.

Required worker action:

- Add an Appendix / Reproducibility section.
- Link or name:
  - `run_config.csv`;
  - `task_manifest.csv`;
  - `combined_results.csv`;
  - `task_status.csv`;
  - `coverage_by_arm.csv`;
  - `best_by_dataset.csv`;
  - `logs/python_launcher.log`;
  - the launcher/worker/merge scripts used.
- Show both report build timestamp and result-generation/merge timestamp when
  available.
- State that the HTML consumes precomputed artifacts and does not rerun the
  experiment.

## Minimum Acceptance Criteria For The Regenerated Report

The regenerated HTML report should satisfy these before handoff:

1. It has a self-contained Purpose section with the main backend questions.
2. It defines Truth RMSE, selected CV RMSE, fit status values, and elapsed time.
3. Fit-status accounting appears before score interpretation.
4. The main Truth RMSE visualization is readable without zooming.
5. Runtime/timing is treated as a first-class result and split by dataset.
6. Large result tables are removed from the report body and linked instead.
7. Every short displayed table has a nearby variable dictionary.
8. Timeout/error rows are explicitly labeled and interpreted.
9. The discussion answers what should happen next:
   drop routine `weighted_qr_drop_tiny`, compare monomial versus orthogonal,
   and use hard task timeouts.
10. Reproducibility links and commands are present.

## Suggested Redesign

A reasonable report structure would be:

1. Purpose and Main Questions.
2. Run Design and Measures.
3. Fit Status Accounting.
4. Accuracy Results:
   - LPS accuracy, split by dataset or dataset family.
   - PS-LPS accuracy, split by dataset or dataset family.
   - Paired deltas versus a declared reference backend where possible.
5. Runtime Results:
   - method/backend/chart runtime summary;
   - dataset-level runtime split;
   - timeout/error rows.
6. Results Summary and Discussion.
7. What We Learned / Recommendation.
8. Appendix / Reproducibility with links to full tables and logs.

The worker should treat the current HTML as an audit artifact draft, not as a
final report.
