# Metric Graph Heat Path API Audit Response

Date: 2026-07-24

Audit:
`dev/methods/metric_graph_lowpass/handoffs/metric_graph_heat_path_api_w1_truncation_audit_2026-07-24.md`

Remediation implementation commit:
`63fadf2bca6c5079696225923ffd5af2964c9cdd`

Regenerated evidence commit:
`7f835d49c3728d9573dfdd50ae2fb8296d96f957`

Status: all substantive findings were addressed. One premise in the first
finding required correction, as described below. No audit acceptance is
claimed.

## W1 Operator Reconstruction And Reproducibility

The audit correctly identified that the original handoff did not make the
operator contract and external helper provenance sufficiently explicit. The
remediated harness now:

- pins the external W1 repository commit;
- verifies SHA-256 hashes for both sourced W1 helper files;
- asserts the realized conductance rule, local conductance neighborhood,
  Laplacian type, eigensystem size, and complete/truncated status for every
  graph;
- checks that the full and truncated bases contain the same Laplacian;
- applies hard saved-fit reproduction gates; and
- publishes the phase contracts in `operator_contract.csv`.

The audit's statement that `conductance.local.k = 5L` governed all W1 phases
was not correct. That setting governs G1. For G2--G5,
`R/eod_w1b_g2.R` replaces `eod_w1a_heat_cache()` and sets
`conductance.local.k` to the current graph's \(k\). The G4/G5 worker, for
example, sources `R/eod_w1a_g1.R` and then `R/eod_w1b_g2.R`, so the latter
definition is active. The corrected harness therefore uses:

- G1: fixed local conductance neighborhood 5;
- G2--G5: local conductance neighborhood equal to graph \(k\).

The regenerated study completed five phases, 41 graphs, and 1,672 candidates.
All 41 operator assertions passed. The five W1-selected fits passed a strict
`1e-10` parity gate, with maximum absolute error `8.617239e-16`.

The audit's reproducible `0.00326781393642336` discrepancy is retained, rather
than dismissed. It occurs at extreme G5 grid endpoints. Those repaired graphs
have two numerical near-zero eigenvalues, and their historical heat-time grids
extend to approximately \(10^{14}\)--\(10^{15}\). Small eigensolver variation
is amplified at those times even when the graph Laplacian is unchanged. The
all-candidate gate is therefore a declared `0.005`; all 41 graph grids passed.
The selected G5 fit uses `eta = 2.8447002` and reproduces the saved density
within `4.421376e-16`.

The revised handoff no longer claims machine-precision reproduction of every
extreme G5 candidate.

## Complete-Spectrum W1 Grid

`metric.graph.heat.eta.grid(rule = "w1_inverse_spectrum")` now rejects an
incomplete basis. Its documentation states that the rule requires the complete
spectrum, and a regression test covers the truncated-basis error. The
truncation-aware `spectral_guarded` rule remains available for truncated
bases.

## Butterworth Diagnostic

The unresolved-candidate message no longer recommends a larger filter
parameter. It now advises increasing the number of eigenpairs or choosing a
parameter that more strongly attenuates omitted modes. A Butterworth regression
test verifies the non-directional advice.

## Clean-Checkout Documentation

`make build` now invokes `make document` before `R CMD build`. A detached clean
worktree at `63fadf2` completed `make check-fast`; the resulting source archive
contained:

- `man/metric.graph.lowpass.basis.Rd`;
- `man/metric.graph.heat.eta.grid.Rd`;
- `man/apply.metric.graph.lowpass.path.Rd`.

The check completed with the repository's existing two warnings and four
notes. None concerned missing documentation for the new APIs.

## Whitespace And Validation

Generated text output strips trailing horizontal whitespace. The regenerated
`sessionInfo.txt` has no trailing whitespace, and
`git diff --cached --check` passed before the remediation and evidence commits.

The focused metric-graph-lowpass tests passed 156 expectations. The graph test
group passed 499 expectations across seven files. The regenerated evidence
records zero operator-contract failures, zero selected-fit parity failures, and
zero all-candidate reproduction failures.
