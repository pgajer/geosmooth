# Metric Graph Heat Path API And W1 Truncation Re-Audit

Date: 2026-07-24

Audited response:
`dev/methods/metric_graph_lowpass/handoffs/metric_graph_heat_path_api_w1_truncation_audit_response_2026-07-24.md`

Audited revised handoff:
`dev/methods/metric_graph_lowpass/handoffs/metric_graph_heat_path_api_w1_truncation_handoff_2026-07-24.md`

Remediation implementation commit:
`63fadf2bca6c5079696225923ffd5af2964c9cdd`

Regenerated evidence commit:
`7f835d49c3728d9573dfdd50ae2fb8296d96f957`

Re-audit target HEAD:
`aa8622f`

Verdict: **accepted**

No blocking or major findings remain. The API corrections, reproducibility
gates, regenerated evidence, and clean-build documentation contract are
implemented and independently reproducible.

## Correction To The First Audit

The first audit's claim that all W1 phases fixed
`conductance.local.k = 5L` was incorrect.

The realized production contract is:

- G1 sources `R/eod_w1a_g1.R` and fixes `conductance.local.k = 5L`.
- G2--G5 source `R/eod_w1a_g1.R` followed by `R/eod_w1b_g2.R`.
  The second file overrides `eod_w1a_heat_cache()` and sets
  `conductance.local.k` to the graph's recorded \(k\).

The G2--G5 worker scripts confirm that source order. The remediated harness
therefore reconstructs the phase-specific operators correctly. The original
audit's operator-mismatch premise is withdrawn.

The separately observed `0.00326781393642336` discrepancy was real, but it was
not caused by a conductance-contract mismatch. It occurs only at unselected G5
grid endpoints with heat times near \(10^{14}\)--\(10^{15}\) on repaired,
nearly disconnected graphs with two near-zero modes. The revised handoff now
states this rather than claiming machine-precision parity over every historical
candidate.

## Finding Closure

### W1 reconstruction and evidence

Closed.

The harness now pins W1 commit
`46611a0f4daa8fec6710cb0908770d7ad536725f`, verifies SHA-256 hashes for both
sourced helpers, records them in the evidence, and asserts the realized
conductance rule, local neighborhood, Laplacian type, requested eigensystem
size, completeness state, and full-versus-truncated Laplacian equality.

The regenerated evidence contains:

- 41 successful operator-contract assertions;
- 5 successful selected-fit parity gates at tolerance `1e-10`;
- 41 successful historical-grid reproduction gates at tolerance `0.005`;
- maximum selected-fit saved-W1 error `8.61723886691479e-16`;
- maximum all-candidate saved-W1 error `0.00326781393642336`.

An independent full replay in a separate temporary output directory reproduced
all counts, discrepancies, oracle results, and zero-failure gate totals.

The `0.005` all-candidate threshold is accepted only for these pinned
historical grids and their extreme near-zero-mode endpoints. It should not be
treated as a generic parity tolerance for other datasets, operators, platforms,
or future API tests. The strict selected-fit gate remains the relevant
production reproduction check.

### Complete-spectrum W1 grid

Closed.

`metric.graph.heat.eta.grid(rule = "w1_inverse_spectrum")` now rejects an
incomplete basis, the roxygen contract states the complete-spectrum
requirement, and the focused test covers the rejection.

### Butterworth diagnostic

Closed.

The unresolved-path message is now direction-neutral across filter
parameterizations, and a Butterworth regression test covers the corrected
message.

### Clean-checkout documentation

Closed.

`make build` now invokes `make document`. An independent build from a detached
clean worktree created a source archive containing:

- `man/metric.graph.lowpass.basis.Rd`;
- `man/metric.graph.heat.eta.grid.Rd`;
- `man/apply.metric.graph.lowpass.path.Rd`.

An independent clean-worktree `make check-fast` completed with two warnings and
three notes, all from known repository-wide issues. It reported no missing
documentation entries or new API defect.

### Whitespace claim

Closed.

Generated text output strips trailing horizontal whitespace. The regenerated
`sessionInfo.txt` and all three remediation/documentation commit ranges pass
`git diff --check`.

## Independent Verification

- Focused metric-graph-lowpass tests: 156 passed, 0 failed, 0 warned, 0
  skipped.
- Graph test group: 499 passed across 7 files, 0 failed, 0 warned, 0 skipped.
- Full W1 harness replay: 5 phases, 41 graphs, 1,672 candidates; all hard gates
  passed.
- Evidence table dimensions, maxima, gate totals, helper hashes, source hashes,
  and provenance fields were independently reconciled.
- Clean detached-worktree source build succeeded and packaged all three new Rd
  pages.
- Clean detached-worktree `make check-fast` completed with the known baseline
  status of 2 warnings and 3 notes.
- `git diff --check` passed over the remediation, evidence, and documentation
  commit ranges.

The unrelated pre-existing modifications to `src/Makevars` and
`src/Makevars.win`, the unrelated archive PDF, and unrelated `dev/papers/`
files were not changed.

## Residual Scope

The accepted study remains a one-representative-per-phase validation at a
fixed truncation count of 200. It does not establish that 200 eigenvectors are
universally adequate, and it correctly retains the unresolved G2/G3 selected
fits, 467 unresolved historical candidates, and 13/15 oracle agreement as
limitations rather than general guarantees.
