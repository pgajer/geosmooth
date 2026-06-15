# P7X S3R-Expanded Repaired Run Audit Response

Date: 2026-06-08

Audit addressed:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_expanded_repaired_run_audit_2026-06-08.md`

Verdict from auditor: accepted with minor comments.

## Actions Taken

### 1. Rewrote the durable HTML report recommendation

The audit noted that the repaired report's "Recommended Next Step" paragraph was
written as an audit instruction rather than reader-facing report prose.

Updated renderer:

`/Users/pgajer/current_projects/geosmooth/scripts/render_ps_lps_s3r_expanded_results_report.R`

New reader-facing policy statement:

- screened PS-LPS is recommended as the routine experimental support-search
  policy for similar broad synthetic and real-geometry sweeps;
- full support-grid PS-LPS remains the validation/reference mode for spot
  checks, new geometry families, publication-critical sensitivity checks, and
  unusual screening telemetry.

Regenerated report:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001/reports/ps_lps_s3r_expanded_repaired_results_report.html`

### 2. Promoted screened PS-LPS in the package-facing policy documentation

Updated policy note:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_policy_2026-06-07.md`

The note now records the accepted S3R-expanded repaired audit as the policy gate
and states:

- screened PS-LPS local-candidate search is the routine experimental
  support-search policy for broad sweeps;
- exact full support-grid search remains the validation/reference policy;
- reports should continue showing status accounting, support/candidate
  inclusion, lambda-match diagnostics, and dataset-level deltas.

The note also separates backend choice from support-search policy. The
S3R-expanded repaired run supports screened support search; it should not be
misread as a claim that the historical `monomial_tiny_ridge` backend is the
permanent PS-LPS backend.

### 3. Updated package front-door documentation

Updated README:

`/Users/pgajer/current_projects/geosmooth/README.md`

Added PS-LPS to the method map and linked the repaired S3R-expanded report in
the progress-report section.

### 4. Updated the generic S3R report generator

Updated:

`/Users/pgajer/current_projects/geosmooth/scripts/merge_ps_lps_s3r_light_run.R`

For complete clean S3R-expanded bundles, the generic report now states the
settled policy conclusion rather than asking whether screened search can replace
full search.

## Policy Now In Effect

For broad experimental PS-LPS sweeps:

```text
routine support-search policy: local.candidate.search = "screened"
validation/reference policy:   local.candidate.search = "full"
```

Full-grid PS-LPS should be retained for:

- spot checks;
- new geometry families;
- publication-critical sensitivity checks;
- unusual screening telemetry, including low inclusion rates, fallback use,
  long runtime tails, nonfinite fits, or status-accounting anomalies.

## Nuance Preserved From Audit

The policy does not claim that screened and full search are numerically
identical in every summary. The report and policy note preserve the auditor's
nuance:

- overall median screened-minus-full Truth RMSE is `0`;
- `chart.dim = "auto"` has a small positive mean shift favoring full search;
- candidate inclusion is about `0.48`, so future reports should keep inclusion
  and lambda-match diagnostics visible.

## Validation

Regenerated reports from cached repaired tables only; no models were refit.

Commands run:

```sh
Rscript scripts/merge_ps_lps_s3r_light_run.R \
  --run_dir=/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001

Rscript scripts/render_ps_lps_s3r_expanded_results_report.R \
  --run_dir=/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001 \
  --report_name=ps_lps_s3r_expanded_repaired_results_report.html \
  --source_run_dir=/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_20260607_001 \
  --repair_run_dir=/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_screened_repair_guarded_20260608_001

Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-ps-lps.R", reporter = "summary")'

git diff --check
```

Focused PS-LPS tests passed. `git diff --check` was clean.
