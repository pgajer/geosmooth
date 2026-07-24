# Metric Graph Heat Path API And W1 Truncation Study Handoff

Status: ready for independent audit

Role: implementer and validation-study author

Repository/worktree: `/Users/pgajer/current_projects/geosmooth`

Branch: `main`

Base commit: `b412496401aa39c60b7eb709053f5aac1e7bf181`

Audit-remediation implementation commit:
`63fadf2bca6c5079696225923ffd5af2964c9cdd`

Regenerated evidence commit:
`7f835d49c3728d9573dfdd50ae2fb8296d96f957`

Final git status before updating this handoff: the remediation and evidence
commits were clean relative to their files. Pre-existing, unrelated
modifications remained in `src/Makevars` and `src/Makevars.win`; an archive PDF
and files under `dev/papers/` also remained untracked. None were staged or
modified for this task.

## Goal

Provide reusable `geosmooth` functions for constructing a metric graph
low-pass spectral basis, constructing a graph heat-time grid, and applying a
complete heat path to one or many responses. Verify selected-fit reproduction
against the saved W1 G1--G5 graph-heat implementation, quantify numerical
reproduction across the complete historical candidate grids, and quantify the
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

The audit remediation also made four API/build corrections:

- `rule = "w1_inverse_spectrum"` now rejects a truncated basis because its
  lower endpoint requires the largest eigenvalue of the complete spectrum;
- unresolved-candidate advice no longer recommends increasing the filter
  parameter, which is the wrong direction for the implemented Butterworth
  filter;
- `make build` runs `make document` before constructing the source archive;
- generated text evidence removes trailing spaces.

The W1 comparison harness evaluates one frozen representative dataset from each
of G1--G5. Within each dataset it evaluates every graph and every saved
graph-heat candidate in the corresponding result object. This produced 41
graphs and 1,672 candidate comparisons.

The harness pins the external W1 checkout at
`46611a0f4daa8fec6710cb0908770d7ad536725f` and verifies both sourced helper
hashes before execution. It asserts the realized operator for every graph. The
frozen phase contracts are:

- G1: self-tuned Gaussian conductance with local conductance neighborhood
  fixed at 5;
- G2--G5: self-tuned Gaussian conductance with the local conductance
  neighborhood equal to the symmetric graph's \(k\).

The G2--G5 rule is defined by the override in `R/eod_w1b_g2.R`, which is sourced
after `R/eod_w1a_g1.R` by the G2--G5 workers.

## Files Changed Or Created

Package source and generated namespace:

- `/Users/pgajer/current_projects/geosmooth/Makefile`
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
- `operator_contract.csv`: phase-specific W1 graph-heat settings, helper
  provenance, and hard-gate tolerances.
- `source_provenance.csv`, `source_checksums.csv`, `git_provenance.txt`, and
  `sessionInfo.txt`: input and execution provenance.

`comparison_results.rds` was also generated locally in that directory. It is
ignored by the repository's `*.RDS` rule and is not part of the implementation
commit. All reported numerical findings are present in the committed CSV files.

## Main Numerical Findings

### Full-spectrum API reproduction

All 41 graph-level operator assertions passed. The five W1-selected fits passed
a strict `1e-10` saved-fit parity gate; their largest absolute discrepancy was
`8.617239e-16`.

Across the complete 1,672-candidate historical grids, the largest discrepancy
was `0.00326781393642336`, on the G5 `symmetric_knn_k04` graph. This is not an
operator mismatch. The G5 repaired graphs have two numerical near-zero
eigenvalues, and their historical grids extend to heat times between
approximately \(10^{14}\) and \(10^{15}\). At those endpoints, solver-scale
changes in a near-zero eigenvalue are amplified by the exponential heat
filter. The selected G5 fit uses `eta = 2.8447002` and reproduces the saved
density within `4.421376e-16`.

The harness therefore applies two explicit hard gates:

- `1e-10` for each saved W1-selected fit;
- `0.005` for every candidate in the historical grids, with the extreme-grid
  discrepancies retained in the evidence rather than described as roundoff.

All five selected-fit gates and all 41 all-candidate reproduction gates passed.
The corrected evidence does not claim machine-precision reproduction of every
extreme G5 endpoint.

### First-200-eigenvector approximation at the W1-selected candidate

| Phase | Resolved at `1e-4` | Density TV | Density RMSE | Hellinger |
|---|---:|---:|---:|---:|
| G1 | yes | `1.15e-16` | `3.28e-16` | `1.04e-14` |
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
git worktree add --detach /tmp/geosmooth-clean-audit-hoAaMl 63fadf2
```

```sh
make check-fast
```

```sh
tar -tzf geosmooth_0.0.0.9000.tar.gz | rg \
  'geosmooth/man/(metric.graph.lowpass.basis|metric.graph.heat.eta.grid|apply.metric.graph.lowpass.path)\.Rd$'
```

```sh
git diff --cached --check
```

## Validation

- The focused metric-graph-lowpass file passed 156 expectations with no
  failures, warnings, or skips.
- `make test-graph` passed all seven graph test files, totaling 499
  expectations with no failures, warnings, or skips.
- The W1 harness completed all five phase representatives, 41 graphs, and
  1,672 candidates. It passed 41 operator assertions, five strict selected-fit
  parity gates, and 41 bounded all-candidate reproduction gates, then wrote
  candidate-, graph-, phase-, selected-fit-, and oracle-level comparisons
  atomically.
- `make check-fast` ran from a clean detached worktree at `63fadf2`, built and
  installed the source package successfully, and completed with two warnings
  and four notes. None identified the new API or its generated Rd pages as
  defective.
- The clean source archive contained the Rd pages for all three exported APIs.
- `git diff --cached --check` reported no whitespace errors before each
  remediation/evidence commit. The regenerated `sessionInfo.txt` has no
  trailing whitespace.
- The exported functions were loaded through `geosmooth::`, confirming
  namespace exposure.

## Canonical And Generated File Notes

`R/metric_graph_lowpass.R` and its roxygen comments are canonical.
`NAMESPACE` was regenerated with `make document` and committed.

The following Rd pages were generated successfully by roxygen but are ignored
under the repository-wide `man/` rule:

- `man/metric.graph.lowpass.basis.Rd`
- `man/metric.graph.heat.eta.grid.Rd`
- `man/apply.metric.graph.lowpass.path.Rd`

They are regenerated by `make document`; they were not hand-edited.
`make build` now invokes that documentation step before `R CMD build`, so the
public help pages are present in an archive built from a clean checkout.

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
- Complete-path reproduction is not machine-precision on the G5 candidate-grid
  endpoints with heat times near \(10^{14}\)--\(10^{15}\). The maximum observed
  saved-fit discrepancy is `0.00326781393642336`; selected-fit reproduction
  remains at machine precision.
- The observed basis-construction times were collected during a local
  `pkgload` execution and are descriptive only. No formal runtime or memory
  benchmark was performed.
- A prior full smoke-suite run exposed a pre-existing CSD4 PS-LPS support-reuse
  call-count failure. That test was not modified or re-investigated here, so
  this handoff does not claim the full package smoke suite is green.
- `make check-fast` retained two warnings and four notes. These include
  non-mainstream dependencies and package metadata, an unrelated
  `normalize.density` usage mismatch, an unrelated Rd brace issue, and an
  existing undefined `tail` import note. They were not corrected in this task.
- The ignored local `comparison_results.rds` is not durable Git evidence.
- The first independent audit requested changes. This handoff records the
  remediation; no re-audit acceptance is claimed.

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
