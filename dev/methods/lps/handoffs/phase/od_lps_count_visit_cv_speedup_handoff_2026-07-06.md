# OD LPS Count Visit-CV Speedup Handoff

Status: ready for audit
Role: implementer
Repository: `/Users/pgajer/current_projects/geosmooth`
Branch: `main`
Base context: OD-CV3 LPS-family outer visit-CV implementation
Primary commit: `a82ef594e2a7d13ded00341112c9c27fd7f7358a`
Current head after later related work: `62cc86139018a946092f055081a315751a85ef43`
Final git status at handoff creation: clean before this handoff document was added

## Goal

Optimize `fit.subject.od(method = "lps_count", od.cv = "visit", ...)` without
changing its selected candidate scores or held-out visit masses. The immediate
motivation was the OD runtime profile in the community-typing project, where
`lps_count` was the second slowest OD method after `ps_lps_count`.

Original OD runtime profile asset:

`/Users/pgajer/current_projects/vaginal_community_trajectory_types/analysis_output/subject_od_runtime_profile_20260706/subject_od_runtime_profile_report.html`

The profile summary reported:

| Method | Median seconds | Max seconds |
|---|---:|---:|
| `lps_count` | 62.1 | 75.5 |

## Work Completed

The implementation added a fixed-candidate fast path for LPS-family OD visit
CV. Instead of refitting `fit.subject.od()` once per fold and once per
candidate, the fast path builds the fold-specific training response matrix once
for a fixed OD candidate, computes all fold predictions together, normalizes the
resulting raw OD field fold-by-fold, and then reads the held-out visit masses.

For `lps_count`, the fold response for fold `F` is the count vector

```text
y_j^{(-F)} = number of retained training visits assigned to design row j.
```

The fast path is in:

- `/Users/pgajer/current_projects/geosmooth/R/state_density.R`

Key helper entry points:

- `.state.density.visit.cv.score.table()`
- `.state.density.lps.fixed.visit.predictions()`
- `.state.density.lps.fixed.direct.fitted.matrix()`

For eligible local-PCA fixed candidates, the path reuses the PS-LPS independent
local-frame/cache machinery to compute the all-fold independent LPS fits as a
single matrix operation. For ineligible candidates, it uses a direct fixed-LPS
matrix path rather than the outer `fit.subject.od()` fold loop.

## Files Changed

Primary speedup commit `a82ef59` changed:

- `/Users/pgajer/current_projects/geosmooth/R/state_density.R`
- `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-state-density-odcv3-lps-outer-visit-cv.R`

A later related commit, `62cc861`, generalized the same helper to support
`lps_logistic_binary`. That later commit touched the same source file but kept
the `lps_count` path in the shared fast helper and re-ran the LPS/OD test
targets.

## Validation

Regression coverage was added in:

`/Users/pgajer/current_projects/geosmooth/tests/testthat/test-state-density-odcv3-lps-outer-visit-cv.R`

The test named
`OD-CV3 LPS count fixed-candidate fast path matches fold loop` compares the new
fast helper against the original explicit fold loop on a curved smoke fixture.
It checks both:

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

All completed successfully. The later `lps_logistic_binary` commit re-ran
`make test-od`, `make test-lps`, and `git diff --check` successfully after the
shared helper was generalized.

## Timing Sanity Check

A representative fixed-candidate timing sanity check compared the original
explicit fold loop with the new fixed-candidate fast path for `lps_count`.

Result:

| Quantity | Value |
|---|---:|
| Original explicit fold loop | 1.734 sec |
| Fast path | 0.128 sec |
| Speedup | 13.55x |
| Max absolute prediction delta | 5.55e-17 |

The timing check was a local smoke comparison, not a rerun of the full OD4
expanded workload.

## Source Modified After Validation

Yes. The later `lps_logistic_binary` optimization commit `62cc861` modified the
same fast helper to add an `outcome.family` argument and Bernoulli handling.
The final package checks listed above were rerun after that change and still
covered the `lps_count` regression test.

## Canonical And Generated File Notes

No generated package files were changed by this optimization. No Rd,
`NAMESPACE`, or generated dashboard files were edited by hand.

This handoff is a source Markdown document. Generated dashboard HTML, if
rebuilt, is ignored by git under `dev/**/html/`.

## Limitations And Unverified Claims

- The speedup number is from a representative fixed-candidate smoke comparison,
  not from the full OD4 expanded runtime profile rerun.
- The exact R timing one-liner used for the 1.734 sec versus 0.128 sec check was
  not saved as a durable script.
- The optimization is validated against the old explicit fold loop on smoke
  fixtures. It was not independently validated against external OD truth
  metrics or basin-recovery metrics.
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
