# Harlim Second-Order Local SVD H0 Contract Audit

Date: 2026-06-04

Audited contract:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_local_svd_h0_contract_2026-06-04.md`

Verdict: revise before H1.

The contract is strong overall.  It keeps the second-order chart separate from
plain local PCA, fixes the chart dimension for the first prototype, states the
row-oriented transpose convention, makes fallback explicit, distinguishes
paper-faithful pieces from pragmatic extensions, and correctly treats the
quadratic columns as squared terms plus doubled cross terms.  The recommended
H1 scope, "minimal prototype only", is appropriate.

Two implementation-contract issues should be fixed before code begins.

## Findings

### P1. Fallback-to-PCA is not always implementable with the requested dimension

The contract says that numerical degeneracy should fall back to ordinary local
PCA with the same fixed dimension `m`; see the output and fallback language in
the contract around `coordinates`, `basis`, and the fallback policy.  The
current plain local PCA backend, however, uses thin SVD and rejects
`m > min(K, n)`:

- `/Users/pgajer/current_projects/geosmooth/src/local_pca_charts.cpp`

This matters for cases such as `K_eff < m + 1`, all/most weights zero, or
degenerate supports.  Some of these are listed as fallback cases, but the
fallback call itself may error or be unable to return an `n x m` basis and
`K x m` coordinate matrix.

Required contract revision:

- State an explicit fallback feasibility rule:
  `plain PCA fallback is allowed only when m <= min(K, n)` and there is enough
  finite input for the current plain-PCA backend to return `m` columns.
- For cases where neither second-order SVD nor fixed-`m` plain PCA is feasible,
  choose one of two behaviors and document it:
  1. hard error because the requested chart dimension is impossible for the
     support; or
  2. structured failure object with `fallback.used = TRUE`,
     `fallback.reason = "plain_pca_fallback_not_feasible"`, and empty/`NA`
     chart fields.
- Add the chosen behavior to the H1 tests with too-few rows and all-zero
  effective weights.

### P1. The proposed rank cutoff has an unintended absolute scale floor

The contract recommends

```text
cutoff = rank.tolerance * max(nrow(M), ncol(M)) * max(max(s), 1)
```

This is not scale-invariant.  If local coordinates are small in absolute units,
for example after rescaling, centering, or using a small-radius neighborhood,
then `max(max(s), 1)` can make the cutoff dominated by `1` rather than by the
matrix scale.  A geometrically valid small local support could then be declared
rank deficient solely because the coordinate units are small.

Required contract revision:

- Use a relative rank rule such as

```text
cutoff = rank.tolerance * max(nrow(M), ncol(M)) * sigma_max
```

  with an explicit separate zero-scale rule when `sigma_max <= absolute.zero`.
- If an absolute floor is intentionally desired, make it a separate parameter,
  for example `rank.absolute.tolerance`, and explain how it is scaled to the
  data.

This is especially important because the Harlim-style method is local: small
neighborhood radii are not numerical accidents; they are expected.

## Nonblocking Notes

- The phrase "approximate geodesic normal coordinates in the tangent space" is
  mathematically understandable, but easy to misread as ambient normal
  coordinates.  For H1 implementation notes and diagnostics, prefer a name such
  as `preliminary.tangent.coordinates` or `rho.tangent`.  Keep the explanatory
  sentence that these are not ambient normal coordinates.
- The contract says `normal.basis` is optional for H1.  That is acceptable
  because the implementable least-squares curvature correction does not require
  explicitly constructing the ambient normal complement.  If H1 does not return
  `normal.basis`, tests should focus on tangent projectors and fallback
  diagnostics.
- The default of no ridge fallback is the right first choice.  Ridge can be
  explored later, but it should not be mixed into the first paper-faithful
  prototype.

## Validation Performed

This was a document/contract audit, not an implementation check.  I read:

- the H0 contract;
- the Harlim agent prompt;
- the local Harlim/Jiang/Peoples memo;
- the current `geosmooth` plain local-PCA C++ backend;
- the current LPS local-PCA chart call path.

No package tests were run because H0 did not modify package source code.

## Assigned Next Task for the Harlim Agent

Revise the H0 contract to address both P1 findings above.  Keep the current
recommendation as "Ready for a minimal H1 prototype only" unless the revisions
expose a deeper ambiguity.

After revising, stop and provide a short revision note.  Do not start H1 until
the revised H0 contract is accepted.
