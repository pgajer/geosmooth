# Metric Graph Heat Path API And W1 Truncation Study Handoff

Status: ready for independent audit

Role: implementer and validation-study author

Repository/worktree: `/Users/pgajer/current_projects/geosmooth`

Branch: `main`

Base commit: `b412496401aa39c60b7eb709053f5aac1e7bf181`

Implementation and evidence commit:
`a693875ec9f1ab7c2bef751a8b5bea76cd6210d3`

Final git status before adding this handoff: the implementation commit was
clean relative to its own files. Pre-existing, unrelated modifications remained
in `src/Makevars` and `src/Makevars.win`; an archive PDF and files under
`dev/papers/` also remained untracked. None were staged or modified for this
task.

## Goal

Provide reusable `geosmooth` functions for constructing a metric graph
low-pass spectral basis, constructing a graph heat-time grid, and applying a
complete heat path to one or many responses. Verify that the new full-spectrum
API reproduces the saved W1 G1--G5 graph-heat implementation, then quantify the
effect of replacing all eigenvectors with the first 200 eigenvectors.

## Work Completed

Three public functions were added:

- `metric.graph.lowpass.basis()` constructs the response-independent weighted
  graph Laplacian and either a complete or truncated eigensystem.
- `metric.graph.heat.eta.grid()` constructs either the historical W1
  inverse-spectrum grid or a truncation-aware guarded grid.
- `apply.metric.graph.lowpass.path()` applies all requested low-pass
  parameters to a response vector or a matrix of responses. It batches
  response columns, returns the exact input for the heat-filter endpoint
  `eta = 0`, and reports whether each truncated candidate satisfies a
  conservative omitted-mode attenuation tolerance.

`fit.metric.graph.lowpass()` now obtains its operator and eigensystem through
`metric.graph.lowpass.basis()`. Its existing fitting, GCV, and return semantics
remain in place.

The W1 comparison harness evaluates one frozen representative dataset from each
of G1--G5. Within each dataset it evaluates every graph and every saved
graph-heat candidate in the corresponding result object. This produced 41
graphs and 1,672 candidate comparisons.

## Files Changed Or Created

Package source and generated namespace:

- `/Users/pgajer/current_projects/geosmooth/R/metric_graph_lowpass.R`
- `/Users/pgajer/current_projects/geosmooth/NAMESPACE`

Unit tests:

- `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-metric-graph-lowpass.R`

W1 comparison harness:

- `/Users/pgajer/current_projects/geosmooth/dev/methods/metric_graph_lowpass/ci/w1_g1_g5_full_vs_200.R`

The harness reads frozen W1 result and bundle files from:

- `/Users/pgajer/current_projects/vaginal_community_trajectory_types/analysis_output/eod_w1a_g1_graph_configs_20260723`
- `/Users/pgajer/current_projects/vaginal_community_trajectory_types/analysis_output/eod_w1b_g2_sentinel_v2_20260722`
- `/Users/pgajer/current_projects/vaginal_community_trajectory_types/analysis_output/eod_w1c_g3_sentinel_v6_20260723`
- `/Users/pgajer/current_projects/vaginal_community_trajectory_types/analysis_output/eod_w1d_g4_sentinel_v9_20260722`
- `/Users/pgajer/current_projects/vaginal_community_trajectory_types/analysis_output/eod_w1d_g5_sentinel_v8_report_r1_20260723`

## Generated Artifacts

The compact, committed evidence bundle is:

`/Users/pgajer/current_projects/geosmooth/dev/methods/metric_graph_lowpass/results/w1_g1_g5_full_vs_200_20260724`

Its main files are:

- `study_summary.csv`: aggregate counts and headline discrepancies.
- `case_summary.csv`: phase-level discrepancy maxima and timing.
- `graph_summary.csv`: graph-level discrepancy maxima and timing.
- `candidate_comparison.csv`: all 1,672 candidate comparisons.
- `w1_selected_comparison.csv`: comparisons at the W1-selected candidates.
- `oracle_selection_comparison.csv`: full-versus-truncated oracle choices for
  TV, RMSE, and Hellinger distance.
- `source_provenance.csv`, `source_checksums.csv`, `git_provenance.txt`, and
  `sessionInfo.txt`: input and execution provenance.

`comparison_results.rds` was also generated locally in that directory. It is
ignored by the repository's `*.RDS` rule and is not part of the implementation
commit. All reported numerical findings are present in the committed CSV files.

## Main Numerical Findings

### Full-spectrum API reproduction

Across 41 graphs and 1,672 candidates, the maximum absolute difference between
the density produced by the new full-spectrum API and the corresponding saved
W1 density was:

`6.49480469405717e-15`

This is numerical roundoff. The new API reproduces the tested W1 G1--G5
graph-heat calculation.

### First-200-eigenvector approximation at the W1-selected candidate

| Phase | Resolved at `1e-4` | Density TV | Density RMSE | Hellinger |
|---|---:|---:|---:|---:|
| G1 | yes | `1.83e-16` | `4.97e-16` | `1.55e-14` |
| G2 | no | `1.84e-05` | `7.35e-05` | `9.50e-04` |
| G3 | no | `5.83e-05` | `2.73e-04` | `2.92e-03` |
| G4 | yes | `9.10e-11` | `2.43e-10` | `1.72e-09` |
| G5 | yes | `1.47e-09` | `6.63e-09` | `5.07e-08` |

Thus, 200 eigenvectors are effectively exact for the selected G1, G4, and G5
fits in this study. They introduce small but measurable differences for the
selected G2 and G3 fits.

### Candidate paths and oracle selection

Of the 1,672 candidate fits, 467 did not meet the conservative
`1e-4` retained-cutoff attenuation rule. Across the entire candidate paths, the
largest full-versus-200 density discrepancies were:

| Phase | Maximum TV | Maximum RMSE | Maximum Hellinger |
|---|---:|---:|---:|
| G1 | `2.97e-04` | `9.25e-04` | `9.13e-03` |
| G2 | `4.43e-04` | `2.37e-03` | `1.05e-02` |
| G3 | `4.80e-04` | `3.88e-03` | `1.38e-02` |
| G4 | `4.94e-04` | `1.44e-03` | `9.19e-03` |
| G5 | `8.19e-04` | `2.64e-03` | `1.90e-02` |

The full and truncated paths selected the same truth-facing oracle candidate in
13 of 15 phase-by-measure comparisons. The two disagreements were both in G3:

- TV selected adjacent heat times `0.4834553` and `0.5465441` on the same
  `symmetric_knn_k09` graph.
- Hellinger selected `0.4834553` and `0.6178657` on that graph.

RMSE agreed in G3, and all three oracle choices agreed in G1, G2, G4, and G5.
The evidence therefore does not support a blanket claim that 200 eigenvectors
are identical to the full spectrum for parameter selection.

## Commands Run

All commands were run from
`/Users/pgajer/current_projects/geosmooth`.

```sh
make document
```

```sh
Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-metric-graph-lowpass.R')"
```

```sh
Rscript dev/methods/metric_graph_lowpass/ci/w1_g1_g5_full_vs_200.R
```

```sh
make test-graph
```

```sh
make test
```

```sh
Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-coupled-kd-selection-csd4.R')"
```

```sh
make check-fast
```

```sh
git diff --check
```

## Validation

- The focused metric-graph-lowpass file passed 154 expectations with no
  failures, warnings, or skips.
- `make test-graph` passed all seven graph test files, totaling 497
  expectations with no failures, warnings, or skips.
- The W1 harness completed all five phase representatives, 41 graphs, and
  1,672 candidates. It verified saved-W1 reproduction and wrote candidate-,
  graph-, phase-, selected-fit-, and oracle-level comparisons atomically.
- `make check-fast` built and installed the source package successfully and
  completed with two warnings and four notes. None identified the new API or
  its generated Rd pages as defective.
- `git diff --check` reported no whitespace errors.
- The exported functions were loaded through `geosmooth::`, confirming
  namespace exposure.

`make test` traversed the smoke suite but displayed one failure in the
pre-existing CSD4 PS-LPS support-reuse call-count test: 76 calls were observed
where the test expects 3. The custom target nevertheless returned process
status zero. Running
`tests/testthat/test-coupled-kd-selection-csd4.R` alone reproduced the same
failure. The failing code and test were not modified in this task.

## Canonical And Generated File Notes

`R/metric_graph_lowpass.R` and its roxygen comments are canonical.
`NAMESPACE` was regenerated with `make document` and committed.

The following Rd pages were generated successfully by roxygen but are ignored
under the repository-wide `man/` rule:

- `man/metric.graph.lowpass.basis.Rd`
- `man/metric.graph.heat.eta.grid.Rd`
- `man/apply.metric.graph.lowpass.path.Rd`

They are regenerated by `make document`; they were not hand-edited.

The comparison CSV and text files are generated by
`dev/methods/metric_graph_lowpass/ci/w1_g1_g5_full_vs_200.R`.

Package source was not modified after the final package validation. The harness
was rerun after its final aggregation change.

## Limitations And Unverified Claims

- The W1 study uses one frozen representative dataset from each phase rather
  than every W1 dataset. It covers every graph and heat-time candidate stored
  for those five representatives.
- The study evaluates a fixed truncation count of 200. It does not estimate a
  per-graph minimum eigenpair count or compare 300, 400, or adaptive counts.
- The `1e-4` spectral-resolution diagnostic is conservative and
  response-independent. A candidate can fail that bound while still having
  small response-specific error.
- The study does not repeat cross-validation using truncated predictions. It
  compares fitted paths, truth-facing measures, the saved W1-selected
  candidate, and truth-facing oracle choices.
- The observed basis-construction times were collected during a local
  `pkgload` execution and are descriptive only. No formal runtime or memory
  benchmark was performed.
- The CSD4 call-count failure prevents a claim that the full package smoke
  suite is green. Its isolated reproduction and lack of overlap with this
  change are documented, but its cause was not investigated here.
- `make check-fast` retained two warnings and four notes. These include
  non-mainstream dependencies and package metadata, an unrelated
  `normalize.density` usage mismatch, an unrelated Rd brace issue, and an
  existing undefined `tail` import note. They were not corrected in this task.
- The ignored local `comparison_results.rds` is not durable Git evidence.
- No independent audit has been performed, and no audit acceptance is claimed.

## Reusable Workflow Capture

Classification: script/template candidate already captured.

Rationale: the committed harness preserves the cross-repository W1
reconstruction, provenance checks, full-versus-truncated comparison, and
machine-readable evidence layout. No separate shared Codex note or skill was
created.

## Next Actor

Ready for: independent code and evidence audit.

Requested decision: none. This handoff records implementation facts and
limitations; it does not claim acceptance.
