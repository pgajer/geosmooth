# Harlim Second-Order Local SVD H0 Contract Re-Audit

Date: 2026-06-04

Audited contract:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_local_svd_h0_contract_2026-06-04.md`

Prior audit:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_local_svd_h0_contract_audit_2026-06-04.md`

Verdict: accepted for minimal H1 prototype.

The revised H0 contract resolves the two prior P1 implementation-contract
issues:

1. It now distinguishes ordinary plain-PCA fallback from structured failure
   when fixed-`m` plain PCA cannot be computed.  The contract explicitly records
   `plain.pca.fallback.feasible`, `primary.failure.reason`, and the
   `"plain_pca_fallback_not_feasible"` fallback reason.
2. It replaces the previous absolute rank floor with a scale-relative rank
   cutoff and a separate `rank.absolute.tolerance` zero-scale guard.

The contract is now precise enough for the intentionally narrow H1
implementation: unweighted or optionally weighted, fixed-dimension,
anchor-centered second-order local SVD, isolated from existing plain PCA and
from production LPS/P7 behavior.

## Remaining Implementation Cautions

These are not blockers, but H1 should handle them explicitly.

- Structured failure must be implemented deliberately.  Do not call the
  existing `compute_local_pca_chart()` in cases where the contract has already
  determined that fixed-`m` plain PCA fallback is infeasible; return the
  structured failure object instead.
- The contract still uses the phrase "geodesic normal coordinates" for
  `rho_tilde`, but it now clearly labels them as preliminary tangent-coordinate
  estimates and explicitly says they are not ambient normal coordinates.  Keep
  H1 variable names and diagnostics on the tangent-coordinate side, for example
  `rho.tangent` or `preliminary.tangent.coordinates`.
- Keep ridge fallback disabled by default for H1.  If a ridge branch is added
  later, it should be audited as a pragmatic extension rather than treated as
  paper-faithful Harlim behavior.

## Validation Performed

This was a contract/document audit only.  No package source files were changed
by the H0 revision, so no package tests were run.  I re-read:

- the revised H0 contract;
- the prior H0 audit findings;
- the current plain local-PCA backend constraints relevant to fallback.

## Response to the Harlim Agent

Accepted.  Please proceed to H1 minimal prototype.

H1 scope:

- implement a separate experimental/internal primitive in `geosmooth`;
- do not modify `compute_local_pca_chart()`, `rcpp_local_pca_chart()`, LPS
  defaults, or production P7 behavior;
- implement the exact square-plus-doubled-cross quadratic design in the H0
  contract;
- implement the scale-relative rank rule and structured failure behavior;
- expose diagnostics sufficient to audit fallback, curvature fitting, first
  SVD, and second SVD;
- add focused tests for flat affine supports, simple curved supports, too-few
  support rows, all-zero effective weights, and projection/subspace comparison
  rather than raw signed basis comparison.

Expected H1 handoff:

```text
/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_local_svd_handoff_2026-06-04.md
```

The handoff should include files changed, algorithm implemented, deviations
from H0 if any, fallback behavior, tests added, exact validation commands and
outcomes, and whether the primitive is ready for H2/H3 chart-diagnostic smoke
tests.
