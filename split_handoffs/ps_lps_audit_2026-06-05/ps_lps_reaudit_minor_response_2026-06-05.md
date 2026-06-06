# PS-LPS Re-Audit Minor Response 2026-06-05

This note responds to:

`~/current_projects/geosmooth/split_handoffs/ps_lps_audit_2026-06-05/ps_lps_audit_response_reaudit_2026-06-05.md`

## Minor Comments Addressed

1. Added a permanent `local.auto`-style vector-chart parity test for the
   ordinary nesting gate:

   `~/current_projects/geosmooth/tests/testthat/test-ps-lps.R`

   The new test fits ordinary `fit.lps(..., chart.dim = "local.auto")`,
   passes the resulting per-anchor chart-dimension vector to `fit.ps.lps()`,
   and verifies that `lambda.ridge = 0`, `lambda.sync = 0` reproduces ordinary
   LPS fitted values.

2. Updated the refined HTML report script so the report explicitly says the
   matched ridge-LPS comparison is a 13/14 dataset-wise win for each PS-LPS
   variant, not a universal win on every dataset:

   `~/current_projects/geosmooth/scripts/run_ps_lps_first_batch_refined_experiment.R`

3. Updated the PS-LPS progress report with the same caveat:

   `~/current_projects/geosmooth/split_handoffs/ps_lps_progress_2026-06-05/ps_lps_progress_report.tex`

## Validation

Commands run:

```bash
cd /Users/pgajer/current_projects/geosmooth
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-ps-lps.R")'
Rscript scripts/run_ps_lps_first_batch_refined_experiment.R
make test
cd split_handoffs/ps_lps_progress_2026-06-05
pdflatex -interaction=nonstopmode -halt-on-error ps_lps_progress_report.tex
pdflatex -interaction=nonstopmode -halt-on-error ps_lps_progress_report.tex
```

Results:

- focused PS-LPS tests: 12 passed, 0 failed;
- full package test target: 952 passed, 0 failed, 0 warnings, 0 skips;
- refined HTML report regenerated successfully;
- progress PDF rebuilt successfully.

The refined report now links:

- `tables/ps_lps_refined_matched_ridge_win_counts.csv`
- `tables/ps_lps_refined_gcv_truth_lm_table.csv`

## Proposed Next Step: PS-LPS-S1 Lambda/Ridge Sensitivity

The next phase should be a focused sensitivity phase on the frozen first-batch
assets, before broader claims or prospective runs.

Recommended phase name:

`PS-LPS-S1: first-batch lambda/ridge sensitivity`

Purpose:

Test whether the refined PS-LPS signal is stable to the two obvious prototype
degrees of freedom:

1. the synchronization grid, \(\lambda_{\mathrm{sync}}\);
2. the ridge scale, \(\lambda_{\mathrm{ridge}}\).

Suggested grids:

```text
lambda.sync.grid = c(0, 0.01, 0.03, 0.1, 0.3, 1, 3, 10)
lambda.ridge.grid = c(0, 1e-10, 1e-8, 1e-6)
```

Design:

- Reuse the frozen first-batch ordinary LPS selected support/kernel/degree/chart
  settings.
- Run both `auto` and `local.auto` source chart rules.
- For every ridge scale, include the matched ridge-LPS baseline
  `lambda.sync = 0`.
- For every positive ridge scale, compare PS-LPS only to the matched ridge-LPS
  baseline with the same ridge.
- For `lambda.ridge = 0`, treat the matched baseline as ordinary LPS.

Primary outputs:

- selected \(\lambda_{\mathrm{sync}}\) by dataset, chart rule, and ridge scale;
- Truth RMSE versus matched baseline;
- median and paired dataset-wise Truth-RMSE deltas;
- sensitivity heatmap over
  \((\log_{10}\lambda_{\mathrm{ridge}}^+,\log_{10}\lambda_{\mathrm{sync}}^+)\);
- diagnostic plots for total local GCV, synchronization energy, and mean
  squared overlap disagreement versus Truth RMSE.

Decision criterion:

Proceed to prospective PS-LPS experiments only if the improvement over matched
ridge-LPS is not confined to one ridge scale or one boundary value of
\(\lambda_{\mathrm{sync}}\). If the result is ridge-sensitive, freeze the
ridge policy first or revise the solver/backend before prospective runs.
