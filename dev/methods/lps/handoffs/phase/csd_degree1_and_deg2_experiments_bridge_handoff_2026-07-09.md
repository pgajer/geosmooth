# CSD Degree-1 And CSD-deg2 Experiments Bridge Handoff

Status: degree-2 run complete  
Role: implementer / report writer  
Branch/worktree: `/Users/pgajer/current_projects/geosmooth`  
Date: 2026-07-09  

## Goal

Provide a factual bridge between the original CSD5--CSD9 degree-1 experiment
assets and the new `CSD-deg2` experiment lane.  This handoff exists because the
degree-1 experiments studied coupled support-size and chart-dimension selection
with local polynomial degree `g = 1`, while the target LPS-like modeling regime
usually uses degree `g = 2`.

## Existing Degree-1 CSD Assets

The existing degree-1 CSD reports are:

```text
dev/methods/lps/reports/csd5_coupled_kd_evaluation_20260708/
dev/methods/lps/reports/csd6_expanded_relative_regret_20260708/
dev/methods/lps/reports/csd7_task_failure_diagnostics_20260708/
dev/methods/lps/reports/csd8_candidate_cv_surface_audit_20260708/
dev/methods/lps/reports/csd9_robust_cv_selection_policy_audit_20260708/
```

The corresponding HTML report files are:

```text
dev/methods/lps/reports/csd5_coupled_kd_evaluation_20260708/csd5_coupled_kd_evaluation_report.html
dev/methods/lps/reports/csd6_expanded_relative_regret_20260708/csd6_expanded_relative_regret_report.html
dev/methods/lps/reports/csd7_task_failure_diagnostics_20260708/csd7_task_failure_diagnostics_report.html
dev/methods/lps/reports/csd8_candidate_cv_surface_audit_20260708/csd8_candidate_cv_surface_audit_report.html
dev/methods/lps/reports/csd9_robust_cv_selection_policy_audit_20260708/csd9_robust_cv_selection_policy_audit_report.html
```

The degree-1 status/report document explaining `auto`, `local.auto`,
`full_kd`, and `sparse_kd` is:

```text
dev/methods/lps/status/lps_coupled_support_chart_dimension_selection_report.tex
dev/methods/lps/status/lps_coupled_support_chart_dimension_selection_report.pdf
```

## New Degree-2 Output Locations

The degree-2 lane is expected to generate:

```text
dev/methods/lps/reports/csd5_deg2_coupled_kd_evaluation_20260709/
dev/methods/lps/reports/csd6_deg2_expanded_relative_regret_20260709/
dev/methods/lps/reports/csd7_deg2_task_failure_diagnostics_20260709/
dev/methods/lps/reports/csd8_deg2_candidate_cv_surface_audit_20260709/
dev/methods/lps/reports/csd9_deg2_robust_cv_selection_policy_audit_20260709/
```

The run logs and step-status file are expected under:

```text
dev/methods/lps/runs/csd_deg2_20260709/
```

The status file is:

```text
dev/methods/lps/runs/csd_deg2_20260709/csd_deg2_step_status.csv
```

All planned run/render steps completed with `status = ok`.

## Design Difference Between Degree 1 And Degree 2

For local polynomial degree `g`, the local polynomial column count is:

```text
q(d, g) = choose(d + g, g)
```

The CSD feasibility rule is:

```text
q(d, g) + design.margin <= support.size
```

with `design.margin = 2`, `support.grid = 15:35`, and
`chart.dim.grid = 1:8`.

For `g = 1`, all 168 numeric pairs in `15:35 x 1:8` are feasible.

For `g = 2`, the same planned grid is filtered by the larger quadratic local
design.  The high chart dimensions are feasible only at sufficiently large
support sizes, and `d = 7, 8` are not feasible under `k <= 35`.  Therefore the
degree-2 CSD lane is not just a rerun with a different fit; it has a different
feasible candidate geometry.

## Source Changes Supporting The Degree-2 Lane

Modified source files:

```text
dev/methods/lps/ci/csd5_coupled_kd_evaluation_run.R
dev/methods/lps/ci/csd6_expanded_relative_regret_run.R
dev/methods/lps/ci/csd7_task_failure_diagnostics_render.R
dev/methods/lps/ci/csd8_candidate_cv_surface_audit_run.R
dev/methods/lps/ci/csd9_robust_cv_selection_policy_audit_render.R
```

Created source file:

```text
dev/methods/lps/ci/run_csd_deg2_suite.sh
```

The source change is intended to keep the same CSD machinery while exposing
degree as a runtime argument for CSD5, CSD6, and CSD8.

## Commands

The degree-2 suite runner command is:

```sh
dev/methods/lps/ci/run_csd_deg2_suite.sh
```

The runner internally calls:

```sh
Rscript dev/methods/lps/ci/csd5_coupled_kd_evaluation_run.R --degree=2 --report-dir=<csd5-deg2-dir>
Rscript dev/methods/lps/ci/csd5_coupled_kd_evaluation_render.R --report-dir=<csd5-deg2-dir>
Rscript dev/methods/lps/ci/csd6_expanded_relative_regret_run.R --degree=2 --report-dir=<csd6-deg2-dir>
Rscript dev/methods/lps/ci/csd6_expanded_relative_regret_render.R --report-dir=<csd6-deg2-dir>
Rscript dev/methods/lps/ci/csd7_task_failure_diagnostics_render.R --input-dir=<csd6-deg2-dir> --report-dir=<csd7-deg2-dir>
Rscript dev/methods/lps/ci/csd8_candidate_cv_surface_audit_run.R --degree=2 --report-dir=<csd8-deg2-dir>
Rscript dev/methods/lps/ci/csd8_candidate_cv_surface_audit_render.R --report-dir=<csd8-deg2-dir> --csd6-dir=<csd6-deg2-dir>
Rscript dev/methods/lps/ci/csd9_robust_cv_selection_policy_audit_render.R --input-dir=<csd8-deg2-dir> --report-dir=<csd9-deg2-dir>
```

## Validation

Validation completed before this handoff:

- R parse check for modified CSD run/render scripts.
- Shell syntax check for the new runner.
- A failed first wrapper launch was diagnosed as a path-root bug.
- The accidental outside-repo failed-log tree was removed.
- The corrected wrapper was started from the geosmooth repository.

Validation not completed before this handoff:

- No direct degree-1 versus degree-2 paired comparison table had been generated.
- No independent reproduction of task-level degree-2 values was performed.
- No package-wide test suite was run.

## Degree-2 Headline Results

CSD6 degree-2 expanded summary:

```text
strategy      median truth ratio   median relative regret (%)   candidates
auto                 2.469163                    146.91634          21
local_auto           2.564846                    156.48457          21
sparse_kd            2.502075                    150.20751           6
full_kd              1.723348                     72.33476         101
```

CSD9 degree-2 replay summary:

```text
policy          median truth ratio   severe misses > 1.5
3% low-d              1.632715                 27
1% low-d              1.723348                 28
low-d penalty         1.723348                 29
CV min                1.723348                 29
3% large-k            1.724252                 27
boundary penalty      1.747110                 29
5% low-d              1.874399                 30
```

The CSD6 degree-2 full numeric grid had 101 feasible candidates per task and
4848 full-grid truth-reference rows across the 48 expanded tasks.

## Canonical/Generated File Notes

The CSD run/render scripts and suite runner are canonical source files.

The report directories under `dev/methods/lps/reports/` are generated outputs.
They should be regenerated from the scripts rather than edited by hand.

The CSD status LaTeX/PDF report is source-plus-generated:

```text
dev/methods/lps/status/lps_coupled_support_chart_dimension_selection_report.tex
dev/methods/lps/status/lps_coupled_support_chart_dimension_selection_report.pdf
```

The `.tex` file is canonical and the `.pdf` is generated.

## Limitations And Unverified Claims

The degree-2 generated tables and reports now exist, but the values have not
been independently audited or recomputed from raw task-level outputs.

The CSD-deg2 render reports have degree-aware titles, but some interpretation
paragraphs may still inherit degree-1 wording.  A later report polish may be
needed before using the HTML reports as final human-facing evidence.

This handoff does not assert a final scientific conclusion about degree 1 versus
degree 2.  It records the asset bridge, run setup, and headline generated
summaries.

## Reusable Workflow Capture

Classification: workflow note candidate

Rationale: degree-specific reruns of CSD experiments require coordinated changes
to run scripts, generated directories, feasible-grid interpretation, and
boundary diagnostics.  A short future note could turn this into a reusable
pattern for `degree = g` reruns.

## Next Actor

Ready for: independent audit and, if desired, a formal degree-1 versus degree-2
comparison report.

Requested decision: none recorded in this handoff.
