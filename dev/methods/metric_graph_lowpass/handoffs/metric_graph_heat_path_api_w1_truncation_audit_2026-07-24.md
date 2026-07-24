# Metric Graph Heat Path API And W1 Truncation Audit

Date: 2026-07-24

Audited handoff:
`dev/methods/metric_graph_lowpass/handoffs/metric_graph_heat_path_api_w1_truncation_handoff_2026-07-24.md`

Implementation and evidence commit:
`a693875ec9f1ab7c2bef751a8b5bea76cd6210d3`

Handoff commit:
`03d17e4`

Verdict: **changes requested**

The reusable basis/path implementation is promising and its focused tests pass,
but the principal W1 validation claim is not currently reproducible. The public
heat-grid API also silently gives a different grid from the documented W1 rule
when it receives a truncated basis.

## Findings

### [P1] The harness does not reconstruct the W1 graph-heat operator, and the committed parity result cannot be reproduced

The W1 production helper constructs every heat cache with
`conductance.local.k = 5L`:

- `/Users/pgajer/current_projects/vaginal_community_trajectory_types/R/eod_w1a_g1.R:319`
- `/Users/pgajer/current_projects/vaginal_community_trajectory_types/R/eod_w1a_g1.R:328`

The submitted comparison harness instead uses `5L` only for G1 and uses the
graph degree parsed from `graph.id` for G2--G5:

- `dev/methods/metric_graph_lowpass/ci/w1_g1_g5_full_vs_200.R:228`
- `dev/methods/metric_graph_lowpass/ci/w1_g1_g5_full_vs_200.R:231`
- `dev/methods/metric_graph_lowpass/ci/w1_g1_g5_full_vs_200.R:241`
- `dev/methods/metric_graph_lowpass/ci/w1_g1_g5_full_vs_200.R:253`

These are different operators whenever `graph.k != 5`. Therefore, the current
harness is not a valid reconstruction of the saved W1 calculation for most
G2--G5 graph candidates.

I ran the committed harness twice against the listed frozen inputs. Both runs
completed all 5 phases, 41 graphs, and 1,672 candidates and deterministically
reported:

```text
maximum_full_api_vs_saved_w1_absolute_error = 0.00326781393642336
G5 maximum full API vs saved W1 error       = 0.00326781393642336
```

The committed evidence and handoff instead report
`6.49480469405717e-15`. The current result RDS files, bundle RDS files, package
source, test file, and harness all match the hashes recorded in the submitted
evidence. Consequently, the committed headline cannot be regenerated from the
committed harness and the recorded inputs.

The provenance record does not include the external W1 repository commit or a
hash of `R/eod_w1a_g1.R`, even though the harness sources that mutable file at
runtime. This leaves the exact execution dependency incomplete.

This issue does not erase every truncation observation: the repeated runs
reproduced the submitted full-versus-200 selected-fit discrepancies and the
13/15 oracle agreement count. However, those comparisons currently use the
harness's operator, not necessarily the operator that generated the W1 fits.
The handoff's central claim that the new API reproduces W1 is unverified.

Required remediation:

1. Reconstruct the operator from the frozen W1 contract exactly, including
   `conductance.local.k = 5L`, or read the realized operator settings from
   immutable result metadata if such metadata is available.
2. Add an explicit per-case operator-contract assertion before comparing
   paths.
3. Record the external W1 Git commit and SHA-256 of every sourced external
   helper.
4. Regenerate all W1 comparison artifacts and the handoff from the corrected
   harness.
5. Add a failing gate for full-API-versus-saved-W1 parity rather than merely
   writing the observed discrepancy.

### [P1] `w1_inverse_spectrum` does not reproduce the W1 grid for a truncated basis

The public documentation says that `rule = "w1_inverse_spectrum"` reproduces
the W1 inverse-spectrum grid:

- `R/metric_graph_lowpass.R:243`
- `R/metric_graph_lowpass.R:244`

The implementation accepts a truncated basis and computes the lower endpoint
as the inverse of the largest *retained* eigenvalue:

- `R/metric_graph_lowpass.R:280`
- `R/metric_graph_lowpass.R:287`
- `R/metric_graph_lowpass.R:289`

That is not the W1 lower endpoint, which uses the largest eigenvalue of the
complete spectrum. On a 20-vertex path graph, for example, the complete-basis
lower endpoint is approximately `0.25155`, while a five-eigenpair basis returns
approximately `2.61803`, more than ten times larger.

The test at `tests/testthat/test-metric-graph-lowpass.R:459` exercises the W1
rule only with a complete basis, so it does not catch the silent contract
violation.

Required remediation: either reject an incomplete basis for
`w1_inverse_spectrum`, or rename and document the rule as a retained-spectrum
grid. Add a truncated-basis regression test. If exact W1 endpoints need to be
available with a truncated working basis, they must be supplied from separately
verified complete-spectrum metadata.

### [P2] The unresolved-candidate advice is backwards for Butterworth filtering

All unresolved paths receive this advice:

```text
increase n.eigenpairs or use larger eta
```

at `R/metric_graph_lowpass.R:388`. For the implemented Butterworth weight,
`1 / (1 + (lambda / eta)^4)`, increasing `eta` increases retained and omitted
mode weights and therefore makes the attenuation bound worse:

- `R/metric_graph_lowpass.R:1063`
- `R/metric_graph_lowpass.R:1065`

Required remediation: make the advice filter-specific, or omit the directional
eta recommendation. Add a Butterworth unresolved-path test.

### [P2] The three exported APIs have no documentation in a clean checkout

The new functions are exported in `NAMESPACE`, but the repository ignores all
of `man/`, and none of their generated Rd files are tracked:

- `.gitignore:16`
- `NAMESPACE:35`
- `NAMESPACE:80`
- `NAMESPACE:81`

`make build` does not run `make document`; it directly invokes `R CMD build .`:

- `Makefile:21`
- `Makefile:51`

Thus, the reported `make check-fast` used locally generated ignored help files
and does not establish that the committed source tree contains documentation
for the public API.

Required remediation: make the clean-checkout build contract explicit and
test it. Either track the generated Rd files or ensure the canonical build
target generates documentation before packaging, then run the check from a
clean archive/worktree.

### [P3] The recorded `git diff --check` result is inaccurate

`git diff --check a693875^ a693875` reports trailing whitespace in seven lines
of the committed `sessionInfo.txt`. This is generated evidence rather than
package code, but the handoff's statement that `git diff --check` reported no
whitespace errors is not true for the final implementation commit.

Required remediation: normalize the generated session-info text or narrow and
state the exact path set checked.

## Verification Performed

- Read the handoff, implementation diff, public API source, focused tests,
  W1 harness, committed CSV evidence, and provenance files.
- Re-ran
  `tests/testthat/test-metric-graph-lowpass.R`: 154 expectations passed.
- Re-ran the complete W1 harness twice in separate temporary output
  directories: both runs completed 5 phases, 41 graphs, and 1,672 candidates
  and produced the same `0.00326781393642336` maximum saved-W1 discrepancy.
- Confirmed that the package source, focused test, harness, W1 result RDS
  files, and W1 bundle RDS files match the hashes recorded by the submitted
  evidence.
- Compared the harness's realized operator parameters with the W1 production
  helper.
- Probed complete versus truncated `w1_inverse_spectrum` grids and the
  Butterworth attenuation direction.
- Checked clean-checkout tracking of the generated Rd pages and ran
  `git diff --check` across the implementation commit.

The unrelated existing modifications in `src/Makevars` and `src/Makevars.win`
and the unrelated untracked files were not changed.

## Re-Audit Gate

Re-audit should begin after the W1 harness and evidence bundle have been
regenerated from an exact, pinned W1 operator contract; the grid-rule behavior
has an explicit complete-versus-truncated contract; Butterworth diagnostics are
corrected; and a clean-checkout package build exposes help for all three public
functions.
