# PS-LPS C10 Boundary-Expansion Search Policy Handoff

Build time: 2026-06-05 20:50:54 EDT

## Scope

C10 hardened the experimental guarded `lambda.sync` search policy for PS-LPS.
The default `fit.ps.lps()` behavior remains exact grid search. The guarded
policy is opt-in through

```r
lambda.sync.search = "guarded"
```

This phase added package-side policy helpers, regression tests, and a first-batch
validation report against an expanded reference grid.

## Source Changes

- Added `lambda.sync.search` and `lambda.sync.search.control` to
  `fit.ps.lps()`.
- Added private helpers:
  - `.ps.lps.select.lambda.table()`
  - `.ps.lps.raw.best.lambda.table()`
  - `.ps.lps.search.control()`
  - `.ps.lps.grid.search.telemetry()`
  - `.ps.lps.search.lambda.sync()`
- Added boundary-expansion logic for the guarded policy.
- Added a near-boundary guard: if an evaluated edge candidate is close to the
  raw best CV score, the policy expands that edge even when the practical
  tie-rule selection is interior.
- Added regression tests for:
  - interior optimum;
  - right-boundary expansion;
  - near-best right-boundary expansion;
  - left positive-boundary expansion;
  - zero as diagnostic candidate;
  - `fit.ps.lps()` telemetry under guarded search.
- Regenerated `man/fit.ps.lps.Rd`.

## Validation Assets

- Script:
  `/Users/pgajer/current_projects/geosmooth/scripts/profile_ps_lps_c10_boundary_expansion_policy.R`
- HTML report:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/c10_boundary_expansion_policy_2026-06-05/ps_lps_c10_boundary_expansion_policy_report.html`
- Summary table:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/c10_boundary_expansion_policy_2026-06-05/tables/ps_lps_c10_search_summary.csv`
- Reference curves:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/c10_boundary_expansion_policy_2026-06-05/tables/ps_lps_c10_reference_grid_curves.csv`
- Search telemetry:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/c10_boundary_expansion_policy_2026-06-05/tables/ps_lps_c10_search_stages.csv`

## Validation Design

The initial grid was the C9 mixed grid:

```r
c(0, 1e-4, 3e-4, 1e-3, 3e-3, 1e-2, 3e-2,
  0.1, 0.3, 1, 3, 10, 30, 100, 300)
```

The expanded reference grid added two lower-bound candidates and two upper-bound
candidates:

```r
c(min.positive / 9, min.positive / 3, initial.grid,
  max.positive * 3, max.positive * 9)
```

The guarded search was compared against this expanded reference, not merely
against the original 15-point grid.

## Results

Final C10 validation results:

- selected-lambda agreement with expanded reference: 12 / 12;
- maximum CV RMSE regret: 0;
- maximum relative CV RMSE regret: 0;
- median candidate reduction versus expanded reference: 47.37%;
- median elapsed speedup: 1.82x;
- boundary expansions occurred in 6 of 12 cases:
  - 3 cases had one expansion;
  - 3 cases had two expansions.

The most important diagnostic case was `FB09` with `chart_dim_rule = "auto"`.
Before the near-boundary guard, the search selected `lambda.sync = 100` while
the expanded reference selected `2700`. The evaluated right edge was close to
the raw best but not itself the raw best, so a strict boundary-only expansion
missed the high-lambda basin. The near-boundary guard expanded the edge and
recovered the reference selection.

## Verification

Commands run:

```sh
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-ps-lps.R")'
Rscript scripts/profile_ps_lps_c10_boundary_expansion_policy.R
make document
make test
git diff --check -- R/ps_lps.R tests/testthat/test-ps-lps.R scripts/profile_ps_lps_c10_boundary_expansion_policy.R
```

Results:

- `test-ps-lps.R`: passed, 65 tests.
- `make document`: passed and regenerated `fit.ps.lps.Rd`.
- `make test`: passed, 1005 tests, no failures, no warnings.
- `git diff --check`: passed.

## Interpretation

C10 makes the guarded search policy substantially safer than the C8/C9
prototype because it no longer assumes that the practical tie-rule selection
alone should control boundary expansion. It checks the raw CV best and a looser
near-boundary guard. This matters for noisy or multi-basin CV curves, where a
boundary candidate can be almost best even though the practical tie-rule chooses
a smaller interior lambda.

The policy is still experimental. It has only been validated for `lambda.sync`
search at the current fixed ridge policy and fixed LPS chart/support settings.
It should not yet be promoted to a default for all PS-LPS use.

## Recommended Next Step

Proceed to C11 as a search-integration audit phase.

Specific C11 tasks:

1. Add a small user-facing vignette or internal note explaining the guarded
   search policy: coarse grid, local refinement, boundary expansion, near-edge
   guard, practical tie rule, and telemetry.
2. Decide whether prospective PS-LPS experiments should use
   `lambda.sync.search = "guarded"` by default while package API defaults remain
   exact grid search.
3. Run a compact prospective comparison on the first-batch examples using:
   - exact grid;
   - guarded search;
   - guarded search with one fewer expansion;
   - guarded search with a stricter near-boundary guard.
4. Confirm that the selected fits, not only selected lambdas, match or remain
   practically equivalent under Truth RMSE and pointwise delta diagnostics.
5. Only after that, freeze the policy for the next PS-LPS prospective
   experiment campaign.
