# PS-LPS C8 Lambda Search Policy Handoff

Build time: 2026-06-05 20:12:03 EDT

## Scope

C8 implements and evaluates a guarded coarse-to-refine search prototype for
`lambda.sync`.  It is not a package-facing default.  It is a validation phase
that asks whether a search policy can reduce the number of positive
`lambda.sync` candidates while preserving the full-grid CV selection.

The deployable correctness guard is

\[
  \Delta_{\rm CV}
  =
  {\rm CVRMSE}(\widehat\lambda_{\rm search})
  -
  {\rm CVRMSE}(\widehat\lambda_{\rm full}),
\]

where \(\widehat\lambda_{\rm full}\) is selected from the full grid and
\(\widehat\lambda_{\rm search}\) is selected from the searched subset.  C8 also
uses a practical tie rule: among candidates within `0.2%` of the minimum CV
RMSE, choose the smallest `lambda.sync`.

## New Script and Report

- `scripts/profile_ps_lps_c8_lambda_search_policy.R`

Generated report:

- `split_handoffs/ps_lps_cache_backend_2026-06-05/c8_lambda_search_policy_2026-06-05/ps_lps_c8_lambda_search_policy_report.html`

Generated tables:

- `tables/ps_lps_c8_search_summary.csv`
- `tables/ps_lps_c8_full_grid_curves.csv`
- `tables/ps_lps_c8_search_stages.csv`

Generated figures:

- `figures/ps_lps_c8_cv_curves.png`
- `figures/ps_lps_c8_candidate_counts.png`
- `figures/ps_lps_c8_cv_regret.png`

## Search Policy

For a proposed full grid:

1. evaluate `lambda.sync = 0` if it is present and requested;
2. evaluate a coarse set of up to five log-grid-spaced positive candidates,
   including positive-grid boundaries;
3. select the current best using the practical tie rule;
4. refine around the best coarse candidate:
   - if the best is at the left boundary, add the first few positive grid
     candidates;
   - if the best is at the right boundary, add the last few positive grid
     candidates;
   - if the best is interior, add immediate neighbors;
5. select from the searched candidate table using the same tie rule.

This policy includes explicit boundary guards and keeps `lambda.sync = 0`
separate from positive synchronization candidates.

## Evaluation Cases

C8 uses two frozen first-batch cases:

- `FB01`, `LA-D1-RAW-N500`, `chart_dim_rule = auto`;
- `FB14`, `SYN-RANK-BLOCKS-N600-P100`, `chart_dim_rule = local.auto`.

Each case is evaluated under three lambda-grid layouts:

- `right_boundary_mixed`:
  `c(0, 0.001, 0.003, 0.01, 0.03, 0.1, 0.3, 1, 3, 10)`;
- `interior_positive`:
  `c(0.1, 0.3, 1, 3, 10, 30, 100, 300, 1000)`;
- `left_boundary_positive`:
  `c(30, 100, 300, 1000, 3000, 10000, 30000, 1e5, 3e5)`.

These layouts deliberately exercise right-boundary, interior, and left-boundary
full-grid optima.

## Results

The final C8 run produced:

- selected-lambda agreement in all six case/layout combinations;
- zero CV RMSE regret in all six combinations;
- candidate-count reduction from `22.2%` to `33.3%`;
- elapsed speedups from about `1.20x` to `1.43x`.

Summary:

| Case | Layout | Full candidates | Search candidates | Full selected | Search selected | CV regret |
|---|---|---:|---:|---:|---:|---:|
| FB01 auto | right boundary mixed | 10 | 7 | 10 | 10 | 0 |
| FB01 auto | interior positive | 9 | 7 | 30 | 30 | 0 |
| FB01 auto | left boundary positive | 9 | 6 | 30 | 30 | 0 |
| FB14 local.auto | right boundary mixed | 10 | 7 | 10 | 10 | 0 |
| FB14 local.auto | interior positive | 9 | 7 | 30 | 30 | 0 |
| FB14 local.auto | left boundary positive | 9 | 6 | 30 | 30 | 0 |

## Audit Note

The first draft C8 run used full grids of length five.  That was degenerate:
the coarse stage evaluated the entire grid, so there was no candidate-count
reduction.  The final C8 run corrected this by using larger 9-10 candidate
grids.  The generated report and tables reflect the corrected run.

## Interpretation

C8 supports the C7 recommendation: a guarded search policy can reduce candidate
count while preserving the full-grid CV choice on this first prototype suite.

The result should not yet be treated as a package default.  It validates the
direction and suggests that a broader C9 evaluation is worthwhile.

## Recommended Next Phase

**C9: broader search-policy validation.**

C9 should expand beyond the two C8 cases and evaluate the search policy across
more frozen first-batch examples, multiple chart-dimension rules, and at least
one wider lambda grid.  Required outputs:

1. candidate-count reduction;
2. elapsed-time reduction;
3. CV RMSE regret relative to full grid;
4. selected-lambda agreement when the full-grid CV minimum is unique;
5. practical-tie behavior on flat curves;
6. failure cases, if any, with plots of the full-grid CV curve and searched
   candidates.

If C9 remains clean, C10 can consider exposing the policy as an experimental
option in `fit.ps.lps()`.
