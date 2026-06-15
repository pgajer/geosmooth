# K9 Audit: LPS Local-PCA Native Phase Profile

Generated: 2026-06-04

## Scope

Audited `/Users/pgajer/current_projects/geosmooth/split_handoffs/k9_lps_local_pca_native_phase_profile_handoff_2026-06-04.md`, the profiling script `/Users/pgajer/current_projects/geosmooth/scripts/k9_lps_local_pca_native_phase_profile.R`, and the generated artifacts under `/Users/pgajer/current_projects/geosmooth/split_handoffs/k9_lps_local_pca_native_phase_profile_2026-06-04/`.

## Decision

K9 is accepted as a native phase-profile report for the explicit opt-in `backend = "cpp.local.pca"` path.

The optimization conclusion is supported for the high-dimensional and deterministic 16S profiling rows: local PCA chart construction is the dominant native CV phase there. This does not justify promoting `cpp.local.pca` to `backend = "auto"`.

## Findings

### P2: The script will overwrite the submitted handoff with a less complete version

The submitted handoff includes important interpretive details: the chart-build percentages, the deterministic `n = 500` 16S-subset caveat, and the recommendation not to treat the subset row as a P7 performance result. The script also writes `k9_lps_local_pca_native_phase_profile_handoff_2026-06-04.md`, but its embedded handoff text is shorter and does not include all of those current caveats.

This is not a computational blocker, but it is a reproducibility/auditability issue. If the implementer reruns:

```sh
Rscript scripts/k9_lps_local_pca_native_phase_profile.R
```

the handoff may lose the more precise submitted interpretation. The script should be updated so rerunning it regenerates the current handoff content, or the validation instructions should make clear that the handoff is manually curated and should not be overwritten by the profiler.

### P3: The chart-build conclusion needs to stay qualified to high-dimensional and 16S rows

The profile table supports the main recommendation, but only with the intended qualification:

| row | top phase | top share | chart_build share |
|---|---:|---:|---:|
| controlled 1D | local_solve | 84.97% | 12.39% |
| high-dimensional 1D | chart_build | 87.26% | 87.26% |
| high-dimensional 3D | chart_build | 91.55% | 91.55% |
| deterministic 16S subset n=500 | chart_build | 86.68% | 86.68% |

The HTML recommendation correctly says chart construction dominates the hard high-dimensional and 16S profiling rows. Future summaries should avoid phrasing that implies chart construction dominates the ordinary controlled 1D row.

### P3: Native end-to-end runtime is not yet a speedup result on the hard rows

The K9 summary shows exact profile/unprofiled native CV agreement and selected-output parity, but end-to-end native local-PCA elapsed time is slower than the R path on three of four rows:

| row | R/native elapsed ratio |
|---|---:|
| controlled 1D | 1.299 |
| high-dimensional 1D | 0.505 |
| high-dimensional 3D | 0.969 |
| deterministic 16S subset n=500 | 0.686 |

The handoff does not claim broad speedup, so this is not a defect. It reinforces the recommendation that the next phase should target chart construction before any default-backend promotion.

## Checks

Artifact consistency checks passed:

- `k9_profile_summary.csv` has four profiled rows.
- `profile.rmse.matches.unprofiled.max.abs.delta` is `0` for all rows.
- `selected.same` is `TRUE` for all rows.
- `max.abs.fitted.delta` is at numerical precision for all rows.
- Operation counts are internally consistent: `candidate.evals = targets * candidate.count`, and targets match ANN searches/tie recoveries.
- High-dimensional and 16S chart-build shares are all above 85%.

## Verification

Commands run from `/Users/pgajer/current_projects/geosmooth`:

- `Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); stopifnot(exists("rcpp_kernel_local_polynomial_cv_local_pca_profile", envir=asNamespace("geosmooth"))); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R", reporter="summary")'`
- Lightweight R artifact consistency checks over `k9_profile_summary.csv`, `k9_native_phase_timing.csv`, and `k9_native_operation_counts.csv`.
- `git diff --check`
- `make test`

Results:

- Focused GE7 LPS API tests: passed.
- Artifact consistency checks: passed.
- `git diff --check`: passed.
- `make test`: passed with `878` passes, `9` existing gflow-parity skips, `0` failures, and `0` warnings.

I did not rerun the full K9 profiling script during audit because it is expensive and, as noted above, currently rewrites the submitted handoff with a less complete embedded handoff block.

## Required Follow-Up

Before rerunning or handing K9 forward as a reproducible generated artifact, update `scripts/k9_lps_local_pca_native_phase_profile.R` so the handoff writer preserves the current detailed interpretation and deterministic-16S-subset caveat.
