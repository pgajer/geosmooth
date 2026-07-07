# OD LPS Logistic-Binary Visit-CV Speedup Handoff

Status: ready for audit
Role: implementer
Repository: `/Users/pgajer/current_projects/geosmooth`
Branch: `main`
Base context: OD-CV3 LPS-family outer visit-CV implementation
Primary commit: `62cc86139018a946092f055081a315751a85ef43`
Final git status at handoff creation: clean before this handoff document was added

## Goal

Optimize `fit.subject.od(method = "lps_logistic_binary", od.cv = "visit", ...)`
without changing its held-out visit masses. The immediate motivation was the OD
runtime profile in the community-typing project, where `lps_logistic_binary`
was the third slowest OD method after `ps_lps_count` and `lps_count`.

Original OD runtime profile asset:

`/Users/pgajer/current_projects/vaginal_community_trajectory_types/analysis_output/subject_od_runtime_profile_20260706/subject_od_runtime_profile_report.html`

The profile summary reported:

| Method | Median seconds | Max seconds |
|---|---:|---:|
| `lps_logistic_binary` | 27.3 | 34.3 |

## Work Completed

The implementation extended the LPS fixed-candidate OD visit-CV fast path,
originally added for `lps_count`, to `lps_logistic_binary`.

For `lps_logistic_binary`, the fold response for fold `F` is the binary visit
indicator

```text
y_j^{(-F)} = 1 if design row j has at least one retained training visit,
             0 otherwise.
```

The fast helper passes `outcome.family = "bernoulli"` into the fixed LPS
prediction path and then applies the package response-scale clipping before OD
density normalization:

```text
fitted[] <- .klp.response.scale(fitted, "bernoulli")
```

The matrix-preserving assignment is intentional because `.klp.response.scale()`
returns a numeric vector when given a matrix. The assignment keeps the all-fold
prediction matrix dimensions intact.

Important semantic note: the OD method label `lps_logistic_binary` currently
uses the package's Bernoulli identity-link/clipped-probability LPS workflow,
that is `fit.lps(..., outcome.family = "bernoulli")`. It is not the
`outcome.family = "binomial"` local-logistic IRLS path.

## Files Changed

Primary speedup commit `62cc861` changed:

- `/Users/pgajer/current_projects/geosmooth/R/state_density.R`
- `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-state-density-odcv3-lps-outer-visit-cv.R`

The same commit generalized:

- `.state.density.visit.cv.score.table()`, which now routes both `lps_count`
  and `lps_logistic_binary` into `.state.density.lps.fixed.visit.predictions()`;
- `.state.density.lps.fixed.visit.predictions()`, which now accepts
  `outcome.family = c("gaussian", "bernoulli")`;
- `.state.density.lps.fixed.direct.fitted.matrix()`, which now passes
  `outcome.family` through to the local-polynomial prediction helper.

## Validation

Regression coverage was added in:

`/Users/pgajer/current_projects/geosmooth/tests/testthat/test-state-density-odcv3-lps-outer-visit-cv.R`

The test named
`OD-CV3 LPS Bernoulli fixed-candidate fast path matches fold loop` compares the
new fast helper against the original explicit fold loop on a curved smoke
fixture with repeated subject visits. It checks both:

- `bandwidth.multiplier = 1`, which exercises the cached local-PCA fixed
  candidate path;
- `bandwidth.multiplier = 1.2`, which exercises the direct fallback path.

The check uses `expect_equal(..., tolerance = 1e-8)` for the held-out visit
mass vector.

Validation commands run during the implementation sequence:

```sh
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-state-density-odcv3-lps-outer-visit-cv.R", reporter = "summary")'
make test-od
make test-lps
git diff --check
```

All completed successfully.

## Timing Sanity Check

A representative fixed-candidate timing sanity check compared the original
explicit fold loop with the new fixed-candidate fast path for
`lps_logistic_binary`.

Result:

| Quantity | Value |
|---|---:|
| Original explicit fold loop | 1.776 sec |
| Fast path | 0.133 sec |
| Speedup | 13.35x |
| Max absolute prediction delta | 1.04e-17 |

The timing check was a local smoke comparison, not a rerun of the full OD4
expanded workload.

## Source Modified After Validation

No source files were modified after the final validation commands listed above
and before commit `62cc861`.

## Canonical And Generated File Notes

No generated package files were changed by this optimization. No Rd,
`NAMESPACE`, or generated dashboard files were edited by hand.

This handoff is a source Markdown document. Generated dashboard HTML, if
rebuilt, is ignored by git under `dev/**/html/`.

## Limitations And Unverified Claims

- The speedup number is from a representative fixed-candidate smoke comparison,
  not from the full OD4 expanded runtime profile rerun.
- The exact R timing one-liner used for the 1.776 sec versus 0.133 sec check was
  not saved as a durable script.
- The optimization is validated against the old explicit fold loop on smoke
  fixtures. It was not independently validated against external OD truth
  metrics or basin-recovery metrics.
- The method name `lps_logistic_binary` can be misleading because the
  implementation under this OD label is the Bernoulli identity-link/clipped
  probability workflow, not the binomial IRLS local-logistic workflow. This
  handoff records the naming/semantics explicitly but does not rename the
  method.
- The fast path assumes scalar fixed candidates, consistent with the OD-CV3
  non-nesting contract. It does not implement nested source-level selection
  inside each outer OD candidate.
- The direct fallback branch is covered by `bandwidth.multiplier = 1.2`, but
  the smoke fixture is small and does not exercise every possible LPS backend
  configuration.

## Reusable Workflow Capture

Classification: no new reusable artifact needed.

Rationale: the optimization pattern is now directly encoded in
`R/state_density.R` and covered by regression tests. A broader reusable profiling
workflow already exists in the community-typing OD runtime profile scripts.

## Current State

Ready for audit. The code is committed and pushed on `main`; this handoff
documents the speedup evidence and known limitations.
