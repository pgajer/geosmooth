# LPS / PS-LPS Backend Policy Update

Build date: 2026-06-07

Source context:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001/reports/lps_ps_lps_backend_broader_p7x_comparison.html`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001/reports/ps_lps_s3r_expanded_repaired_results_report.html`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_expanded_repaired_run_audit_2026-06-08.md`
- `/Users/pgajer/.codex/notes/references/evaluation_datasets/frank_friedman_style_factorial_design_for_method_evaluation.md`

## Decision

Drop `weighted_qr_drop_tiny` from routine broad comparisons.

The P7X backend comparison showed that `weighted_qr_drop_tiny` did not solve the
ordinary LPS nonfinite-fit problem and created PS-LPS long-runtime risk.  It may
remain useful as a narrow debugging or profiling variant, but it should not be
included in routine broad benchmark manifests unless a new experiment
explicitly asks for it.

Promote screened PS-LPS local-candidate search to the routine experimental
support-search policy for broad sweeps.  Exact full support-grid PS-LPS remains
the validation/reference policy, not the routine policy.

## Method-Specific Candidate Defaults

Use method-specific defaults rather than one shared backend default:

- LPS default candidate backend: `orthogonal_drop_adaptive_tiny`.
- PS-LPS routine package backend: `orthogonal_drop_adaptive_tiny`.
- Historical S3R-expanded support-search evidence used
  `monomial_tiny_ridge`; that result supports the screened support-search
  policy, not a claim that monomial remains the preferred backend.

The reason is model-specific:

- For LPS, `orthogonal_drop_adaptive_tiny` gave the strongest robustness signal:
  it avoided the selected-fit nonfinite failures seen in the monomial and
  weighted-QR/drop LPS variants without creating a large runtime penalty.
- For PS-LPS, the package now uses the same guarded
  `orthogonal_drop_adaptive_tiny` design/ridge policy as the routine backend.
  The S3R-expanded repaired audit should be read as a support-search-policy
  audit: screened search preserved median Truth RMSE and reduced runtime
  relative to full support-grid search under the then-frozen backend.

## Concrete Parameter Bundles

`orthogonal_drop_adaptive_tiny` means:

```r
design.basis = "orthogonal.polynomial.drop"
design.drop.tol = 1e-8
ridge.multiplier.grid = c(0, 1e-10, 1e-8)
ridge.condition.max = 1e12
unstable.action = "na"
```

`monomial_tiny_ridge` means:

```r
design.basis = "monomial"
design.drop.tol = 1e-8
ridge.multiplier.grid = 1e-8
ridge.condition.max = Inf
```

For PS-LPS, `lambda.ridge = 0` with `ridge.multiplier.grid = 1e-8` represents
the same operational tiny-ridge backend because the adaptive ridge grid controls
the synchronized-system ridge used by the solver.

## Implementation Notes

Package-facing changes:

- `fit.lps()` should default to the `orthogonal_drop_adaptive_tiny` bundle.
- `fit.ps.lps()` should default to the guarded
  `orthogonal_drop_adaptive_tiny` backend unless a future audited profiling
  phase justifies another package-facing backend.
- When `fit.ps.lps()` is called with a support/kernel/degree grid, the routine
  local-candidate search policy should be `local.candidate.search = "screened"`.
  Exact full-grid PS-LPS remains available through
  `local.candidate.search = "full"` and should be used for audit/reference
  runs, not routine broad comparisons.

S3R-expanded repaired policy gate:

- Accepted audit:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_expanded_repaired_run_audit_2026-06-08.md`.
- Repaired result bundle:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_repaired_20260608_001`.
- Accounting: `560 / 560` full rows and `560 / 560` screened rows completed,
  giving `560 / 560` complete seed-matched pairs.
- Accuracy: overall median screened-minus-full Truth RMSE was `0`; the
  `chart.dim = "auto"` subset had a small positive mean shift favoring full
  search, so full-grid validation checks should remain in the workflow.
- Runtime: screened search was faster in every complete pair and had median
  screened/full elapsed-time ratio about `0.438`.
- Candidate diagnostics: full-support inclusion was about `0.48` and selected
  lambda-match rate was about `0.81`; routine reports should keep these
  diagnostics visible because screened search often succeeds without retaining
  the exact full-search support candidate.

Benchmark-manifest changes:

- Routine broad P7X-style preparers should exclude `weighted_qr_drop_tiny`.
- Routine broad P7X-style PS-LPS rows should record
  `local_candidate_search = "screened"` and the exact screening controls in the
  task manifest.
- Routine broad P7X-style reports should state that screened is the routine
  experimental policy and full-grid is the validation/reference policy.
- Full-grid PS-LPS should be included for spot checks, new geometry families,
  publication-critical sensitivity checks, and any case where screened
  telemetry shows unusual candidate inclusion, fallback use, runtime tails, or
  status accounting.
- If `weighted_qr_drop_tiny` is included in a future run, the manifest should
  describe the run as a targeted diagnostic rather than a routine comparison.

## Profiling Priority

The next engineering priority is not to impose timeouts as a substitute for
speed.  Timeouts should be retained for status accounting, but the urgent work
is to profile and improve the PS-LPS monomial backend/search path.

Profile:

- system assembly;
- component-cache construction and reuse;
- lambda-search policy cost;
- support-grid and local-candidate search cost;
- final full-data solve;
- number of evaluated lambda and local candidates.

The profiling output should distinguish elapsed time spent before lambda
evaluation from time spent inside repeated lambda evaluations.  This is needed
to decide whether the next optimization should target system-cache construction,
candidate screening, lambda-search policy, or native solve components.

## Reporting Policy

Broad method reports should still include planned/ok/nonfinite/error/timeout
accounting.  This accounting is not an optimization strategy.  It is a
reproducibility and interpretability requirement: every planned task should have
a status row even if it fails, times out, or returns nonfinite predictions.
