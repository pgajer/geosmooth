# PS-LPS C9 Broader Search-Policy Validation Handoff

Build time: 2026-06-05 20:29:05 EDT

## Scope

Phase C9 broadened the C8 guarded coarse-to-refine search-policy prototype for
`lambda.sync`. This is still an offline validation phase: it does not change
package defaults, public APIs, or the PS-LPS fitting contract.

The question was whether the C8 policy can recover the same selected
`lambda.sync` as a wider full-grid scan while evaluating fewer candidates on a
more diverse set of first-batch examples and chart-dimension rules.

## Assets

- Script:
  `/Users/pgajer/current_projects/geosmooth/scripts/profile_ps_lps_c9_broader_search_validation.R`
- HTML report:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/c9_broader_search_validation_2026-06-05/ps_lps_c9_broader_search_validation_report.html`
- Summary table:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/c9_broader_search_validation_2026-06-05/tables/ps_lps_c9_search_summary.csv`
- Full-grid curves:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/c9_broader_search_validation_2026-06-05/tables/ps_lps_c9_full_grid_curves.csv`
- Search stages:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/c9_broader_search_validation_2026-06-05/tables/ps_lps_c9_search_stages.csv`

## Candidate Grid

The full reference grid was

```r
c(0, 1e-4, 3e-4, 1e-3, 3e-3, 1e-2, 3e-2,
  0.1, 0.3, 1, 3, 10, 30, 100, 300)
```

The search policy used a guarded coarse-to-refine protocol inherited from C8:

- evaluate a small coarse subset including zero and high-end guard candidates;
- identify the best coarse region by observed CV RMSE;
- evaluate local refinement candidates around that region;
- select the final candidate using the same practical-tie rule as the full
  grid comparison.

## Cases

C9 evaluated 12 dataset/chart combinations:

- `FB01` with `auto`
- `FB01` with `local.auto`
- `FB06` with `auto`
- `FB07` with `local.auto`
- `FB09` with `auto`
- `FB09` with `local.auto`
- `FB10` with `local.auto`
- `FB11` with `local.auto`
- `FB12` with `local.auto`
- `FB13` with `local.auto`
- `FB14` with `auto`
- `FB14` with `local.auto`

This covers low-dimensional, VALENCIA-derived, mixed-dimension synthetic, and
rank-block high-dimensional examples from the frozen first-batch assets.

## Results

The guarded search matched the full-grid selected `lambda.sync` in all cases:

- agreement: 12 / 12;
- maximum CV RMSE regret: 0;
- maximum relative CV RMSE regret: 0;
- candidate reduction: 7 of 15 candidates skipped in every case;
- median candidate reduction: 46.67%;
- median elapsed speedup: 1.71x.

Two full-grid optima were on the right boundary:

- `FB01`, `local.auto`;
- `FB14`, `auto`.

The C9 search recovered the same selected candidate in both boundary cases, but
the boundary finding is important. It argues for explicit boundary-expansion
logic in the next phase rather than treating the current finite grid as final.

## Interpretation

C9 gives good evidence that the guarded search policy can reduce PS-LPS
`lambda.sync` evaluations without changing the selected candidate on the
current first-batch validation set.

The result is stronger than C8 because it uses a wider 15-point mixed grid and
more examples. It is still not a final deployment decision because:

- all evidence is retrospective on frozen first-batch examples;
- the policy has not yet implemented automatic boundary expansion;
- the validation is only for `lambda.sync` at the current ridge policy;
- it does not yet optimize over support size, kernel, degree, or chart-dimension
  policy.

## Validation

Executed:

```sh
Rscript scripts/profile_ps_lps_c9_broader_search_validation.R
```

The script completed successfully and wrote the report and CSV assets listed
above.

## Recommended Next Step

Proceed to C10 as a policy-hardening phase, not as a solver phase.

Specific C10 requirements:

1. Add explicit boundary expansion for `lambda.sync` when the selected or raw
   best candidate is on either edge of the current positive grid.
2. Preserve zero as a diagnostic candidate, but avoid letting zero-only
   neighborhoods masquerade as a positive smoothing search.
3. Record search telemetry in a stable schema: initial grid, evaluated
   candidates, boundary expansions, final selected candidate, practical-tie
   candidates, elapsed time, and failure status.
4. Add regression tests on small fixtures where:
   - the best value is interior;
   - the best value is on the left positive boundary;
   - the best value is on the right boundary;
   - zero is evaluated but the selected smoothing candidate is positive.
5. Re-run the first-batch C9 validation after boundary expansion to confirm
   that the C9 agreements remain intact.

Only after C10 passes should this search policy be considered for integration
into the higher-level prospective PS-LPS comparison workflow.
