# LPS Binary GM/FF 5-Rep Run: Implementer Handoff

Date: 10-06-2026
Project: `geosmooth` LPS binary-outcome experiments
Run ID: `lps_binary_gm_ff_telemetry_valid_5rep_20260609_001`
Run directory: `~/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_telemetry_valid_5rep_20260609_001`

This handoff follows the two-agent workflow:

`~/.codex/notes/workflows/worker_auditor_workflow.md`

The auditor's authoritative mandate is the workflow's Audit Charter. This handoff is an evidence bundle only. It does not set the audit scope, does not supply audit questions, and does not suggest a verdict.

## Phase Goal

Run the LPS binary Gaussian-mixture / Frank-Friedman-style factorial experiment with corrected logistic telemetry, using:

- two binary LPS modes:
  - `lps_bernoulli_brier`;
  - `lps_binomial_logistic`;
- two chart-dimension policies:
  - `chart.dim = "auto"`;
  - `chart.dim = "local.auto"`;
- five repetitions per scenario;
- 14 local workers;
- failure-isolated per-task execution.

The experiment compares fitted probability surfaces against known synthetic probability truths.

## Source And Run Artifacts

Primary run assets:

- Run directory:
  `~/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_telemetry_valid_5rep_20260609_001`
- Task manifest:
  `~/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_telemetry_valid_5rep_20260609_001/task_manifest.csv`
- Run configuration:
  `~/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_telemetry_valid_5rep_20260609_001/run_config.csv`
- Combined results:
  `~/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_telemetry_valid_5rep_20260609_001/tables/combined_results.csv`
- Status rows:
  `~/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_telemetry_valid_5rep_20260609_001/tables/run_status_rows.csv`
- Topline summary:
  `~/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_telemetry_valid_5rep_20260609_001/tables/run_topline_summary.csv`
- HTML report:
  `~/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_telemetry_valid_5rep_20260609_001/reports/lps_binary_gm_ff_5rep_report.html`
- Figure directory:
  `~/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_telemetry_valid_5rep_20260609_001/reports/figures_lps_binary_gm_ff`

Generated report-side tables include:

- `tables/binary_gm_ff_paired_method_comparison.csv`
- `tables/binary_gm_ff_method_variant_summary.csv`
- `tables/binary_gm_ff_chart_delta_summary.csv`
- `tables/binary_gm_ff_geometry_delta_summary.csv`
- `tables/binary_gm_ff_profile_delta_summary.csv`
- `tables/binary_gm_ff_sample_delta_summary.csv`
- `tables/binary_gm_ff_overall_clustered_delta_summary.csv`
- `tables/binary_gm_ff_chart_clustered_delta_summary.csv`
- `tables/binary_gm_ff_geometry_clustered_delta_summary.csv`
- `tables/binary_gm_ff_fallback_telemetry_validity.csv`
- `tables/binary_gm_ff_selection_metric_summary.csv`

Relevant scripts:

- `~/current_projects/geosmooth/scripts/prepare_lps_binary_gm_ff_run.R`
- `~/current_projects/geosmooth/scripts/launch_lps_binary_gm_ff_run.py`
- `~/current_projects/geosmooth/scripts/run_lps_binary_gm_ff_task.R`
- `~/current_projects/geosmooth/scripts/summarize_lps_binary_gm_ff_run.R`
- `~/current_projects/geosmooth/scripts/render_lps_binary_gm_ff_report.R`
- Shared helper:
  `~/current_projects/geosmooth/scripts/lps_binary_gm_ff_helpers.R`

## Package Source Touched

The binary-outcome work depends on modified/uncommitted package source in:

- `~/current_projects/geosmooth/R/lps.R`

The current git tree also contains many unrelated dirty and untracked files from parallel workstreams. This handoff concerns the run and report assets listed above.

## Exact Commands Run

The run was prepared and launched earlier through the scripts listed above. The final status was checked with:

```sh
RUN_DIR=/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_telemetry_valid_5rep_20260609_001
Rscript scripts/summarize_lps_binary_gm_ff_run.R --run_dir="$RUN_DIR"
cat "$RUN_DIR/tables/run_topline_summary.csv"
cat "$RUN_DIR/tables/run_status_summary.csv"
```

The report was rendered with:

```sh
Rscript scripts/render_lps_binary_gm_ff_report.R \
  --run_dir=/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_telemetry_valid_5rep_20260609_001
```

Rendered report synchronization was checked with a Python HTML/file-link scan:

```sh
REPORT=/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_telemetry_valid_5rep_20260609_001/reports/lps_binary_gm_ff_5rep_report.html
python3 - <<'PY'
from pathlib import Path
import re
p=Path('/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_telemetry_valid_5rep_20260609_001/reports/lps_binary_gm_ff_5rep_report.html')
s=p.read_text()
print('exists', p.exists(), 'size', p.stat().st_size)
print('title', re.search(r'<title>(.*?)</title>', s).group(1))
print('figures', len(re.findall(r'<figure>', s)))
print('caption_numbers', re.findall(r'Figure \d+\.', s))
print('stale_report_text_in_html', any(x in s for x in ['ten repetitions','11,520','Full Run Report','Fallback telemetry is missing']))
imgs=re.findall(r'<img src="([^"]+)"', s)
missing=[]
for img in imgs:
    if not (p.parent/img).exists(): missing.append(img)
print('missing_images', missing)
PY
```

## Run Accounting

From `tables/run_topline_summary.csv`:

| Metric | Value |
|---|---:|
| planned_tasks | 5760 |
| status_rows | 5760 |
| result_rows | 5760 |
| ok_status_rows | 5760 |
| error_status_rows | 0 |
| timeout_status_rows | 0 |
| not_started_tasks | 0 |

Balanced row counts from `combined_results.csv`:

| Method | `auto` | `local.auto` |
|---|---:|---:|
| `lps_bernoulli_brier` | 1440 | 1440 |
| `lps_binomial_logistic` | 1440 | 1440 |

Paired comparisons generated by the report renderer:

- `2880` matched Brier-vs-logistic pairs.

## Main Numerical Findings Reported

From `tables/binary_gm_ff_method_variant_summary.csv`:

| Method variant | n | Median Truth RMSE | MAD Truth RMSE | Median elapsed seconds | Failure rate | Median support size |
|---|---:|---:|---:|---:|---:|---:|
| Bernoulli/Brier LPS / auto | 1440 | 0.1344469 | 0.0288755 | 9.942 | 0 | 35 |
| Bernoulli/Brier LPS / local.auto | 1440 | 0.1358046 | 0.0288574 | 21.092 | 0 | 35 |
| Binomial/logistic LPS / auto | 1440 | 0.1435560 | 0.0290384 | 58.544 | 0 | 35 |
| Binomial/logistic LPS / local.auto | 1440 | 0.1483073 | 0.0313315 | 76.435 | 0 | 35 |

From `tables/binary_gm_ff_overall_clustered_delta_summary.csv`:

- Cluster unit: scenario ID.
- Number of scenario clusters: `288`.
- Median paired delta, logistic minus Brier: `0.007529493`.
- Bayesian-bootstrap 95% credible interval: `[0.006628969, 0.008947326]`.
- Positive delta means higher Truth RMSE for logistic than for Bernoulli/Brier.

From `tables/binary_gm_ff_fallback_telemetry_validity.csv`:

- Six logistic telemetry columns have `2880` finite values each:
  - `logistic_cv_fallback_event_rate`;
  - `logistic_final_fallback_event_rate`;
  - `logistic_cv_event_rate_fallback_fraction`;
  - `logistic_final_event_rate_fallback_fraction`;
  - `logistic_cv_fallback_path_fraction`;
  - `logistic_final_fallback_path_fraction`.

## Report Rendering And QC Facts

Rendered report:

`~/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_telemetry_valid_5rep_20260609_001/reports/lps_binary_gm_ff_5rep_report.html`

The final HTML check found:

- title: `LPS Binary GM/FF 5-Rep Run Report`;
- five `<figure>` blocks;
- visible captions numbered `Figure 1.` through `Figure 5.`;
- no missing image files;
- no stale strings among:
  - `ten repetitions`;
  - `11,520`;
  - `Full Run Report`;
  - `Fallback telemetry is missing`.

Figures were visually spot-checked using local image rendering. The figure files are:

- `figure_1_paired_delta_by_chart_rule.png`
- `figure_2_paired_delta_by_geometry.png`
- `figure_3_paired_delta_by_profile_and_sample_size.png`
- `figure_4_frank_friedman_accuracy_runtime_summary.png`
- `figure_5_selected_support_size_and_degree.png`

## Limitations And Unverified Claims

- The report is not an independent audit. The run is complete and rendered, but it has not been accepted by an independent auditor under the two-agent Audit Charter.
- The comparison is a deployed-policy comparison, not a clean equal-objective comparison: Bernoulli/Brier LPS selects by observed CV Brier score, while binomial/logistic LPS selects by observed CV log loss.
- The scenario-clustered delta summary was generated by the renderer and not independently reproduced from raw task outputs by this handoff.
- The handoff does not prove that the synthetic data-generating process matches the intended GM/FF design; it lists the materialized manifest and result assets for independent checking.
- The current repository tree is dirty and includes unrelated uncommitted work. The run directory is self-contained, but package source state should be recorded carefully before reruns or comparisons.
- The HTML report contains interpretation text written by the implementer; it should be treated as a reported analysis, not as acceptance evidence.
- The old report filename `reports/lps_binary_gm_ff_full_report.html` also exists in the run directory from a prior render. The synchronized report for this handoff is `reports/lps_binary_gm_ff_5rep_report.html`.
