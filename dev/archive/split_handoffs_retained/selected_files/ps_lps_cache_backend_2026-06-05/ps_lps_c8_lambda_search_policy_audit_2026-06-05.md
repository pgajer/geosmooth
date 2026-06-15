# PS-LPS C8 Lambda Search Policy Audit

Date: 2026-06-05

Audited handoff:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/ps_lps_c8_lambda_search_policy_handoff_2026-06-05.md`

Repository:

- `/Users/pgajer/current_projects/geosmooth`

## Verdict

Accepted. C8 successfully implements a script-local guarded coarse-to-refine
`lambda.sync` search prototype and validates it against full-grid references on
the intended prototype suite.

I found no correctness blockers. The C8 result supports the C7 recommendation:
search policy is a promising next direction. It should not yet be promoted to a
package-facing default; the correct next step is the proposed broader C9
validation.

## Scope Reviewed

Reviewed:

- `scripts/profile_ps_lps_c8_lambda_search_policy.R`
- generated report:
  `split_handoffs/ps_lps_cache_backend_2026-06-05/c8_lambda_search_policy_2026-06-05/ps_lps_c8_lambda_search_policy_report.html`
- generated C8 tables and figures under:
  `split_handoffs/ps_lps_cache_backend_2026-06-05/c8_lambda_search_policy_2026-06-05/`
- relevant PS-LPS cache-aware evaluation paths
- focused PS-LPS tests and full package test target

## Audit Checks

### Search policy mechanics

The script-local search policy does what the handoff says:

- evaluates `lambda.sync = 0` when it is present and `include.zero = TRUE`;
- evaluates up to five log-grid-spaced positive candidates, including
  positive-grid boundaries;
- applies the same practical tie rule used for full-grid selection;
- refines around the coarse best;
- uses explicit left-boundary, right-boundary, and interior refinement branches;
- memoizes evaluated candidates through the evaluator, so duplicate
  coarse/refine candidates are not recomputed;
- compares the search-selected candidate against a separately evaluated
  full-grid reference.

The zero candidate is kept separate from the positive component-cache path. The
positive candidates use the C5 component-cache machinery, while `lambda.sync =
0` uses the direct solve path.

### Prototype evaluation coverage

C8 covers the C7-required prototype shapes:

- right-boundary full-grid optimum with a mixed grid containing zero;
- interior full-grid optimum;
- left-boundary full-grid optimum.

It evaluates these layouts on both:

- `FB01`, `LA-D1-RAW-N500`, `chart_dim_rule = auto`;
- `FB14`, `SYN-RANK-BLOCKS-N600-P100`, `chart_dim_rule = local.auto`.

This is adequate for a direction-setting prototype. It is not yet broad enough
for a package default.

### Reproducibility check

I reran:

```sh
Rscript scripts/profile_ps_lps_c8_lambda_search_policy.R
```

The script completed successfully and regenerated the C8 HTML report and CSV
tables.

The regenerated summary preserved the handoff's core claims:

- selected-lambda agreement in all six case/layout combinations;
- maximum CV RMSE regret: `0`;
- candidate-count reduction range: `22.22%` to `33.33%`;
- elapsed speedup range: about `1.21x` to `1.43x`;
- full-grid curve rows: `56`;
- search-stage rows: `50`.

Regenerated summary:

| Case | Layout | Full candidates | Search candidates | Full selected | Search selected | CV regret |
|---|---|---:|---:|---:|---:|---:|
| FB01 auto | right_boundary_mixed | 10 | 7 | 10 | 10 | 0 |
| FB01 auto | interior_positive | 9 | 7 | 30 | 30 | 0 |
| FB01 auto | left_boundary_positive | 9 | 6 | 30 | 30 | 0 |
| FB14 local.auto | right_boundary_mixed | 10 | 7 | 10 | 10 | 0 |
| FB14 local.auto | interior_positive | 9 | 7 | 30 | 30 | 0 |
| FB14 local.auto | left_boundary_positive | 9 | 6 | 30 | 30 | 0 |

## Interpretation

C8 demonstrates that a guarded coarse-to-refine policy can reduce candidate
count while preserving full-grid selection on this prototype suite. The result
is especially useful because it includes boundary optima and a mixed grid with
`lambda.sync = 0`.

The magnitude of candidate reduction is modest but meaningful: a 22-33%
candidate reduction gave about 1.2-1.4x elapsed speedup in the regenerated run.
That is consistent with the C7 conclusion that skipping whole candidate bundles
can be more immediately useful than low-level sparse-solver optimization.

## Caveats

1. C8 uses only two data cases.

   The result validates direction, not general robustness. C9 must expand over
   more frozen first-batch examples, chart-dimension rules, and wider grids.

2. The layouts are deliberately constructed.

   That is appropriate for testing left/interior/right boundary behavior, but
   C9 needs naturally occurring CV curves, flatter curves, and curves where the
   optimum is not aligned with the C8 refinement pattern.

3. The speedup estimate includes separate setup costs for full-grid and search
   evaluators.

   This is fair for the script-level comparison, but future package-facing
   integration should measure within one production-style runner so setup reuse
   and evaluation order are represented exactly.

4. The refinement radius is conservative but shallow.

   Boundary refinement currently adds only a small number of nearby candidates
   after deduplication. This passed C8, but C9 should test whether larger gaps
   or rougher CV curves need a wider local refinement window.

## Required C9 Guardrails

C9 should include:

- more frozen first-batch examples and multiple chart-dimension rules;
- at least one wider grid than C8;
- examples with unique full-grid minima and near-tie minima;
- examples where the full-grid optimum is at zero, left positive boundary,
  right positive boundary, and interior;
- CV RMSE regret relative to full grid;
- selected-lambda agreement when the full-grid minimum is unique;
- practical-tie behavior on flat curves;
- candidate-count and elapsed-time reduction;
- explicit failure reporting with full-grid curve plots and searched-candidate
  overlays.

If C9 remains clean, then C10 can consider exposing the policy as an
experimental `fit.ps.lps()` option.

## Verification Performed

C8 profiling/search script:

```sh
Rscript scripts/profile_ps_lps_c8_lambda_search_policy.R
```

Result:

- completed successfully;
- regenerated `ps_lps_c8_lambda_search_policy_report.html`;
- regenerated search summary, full-grid curves, and search-stage tables.

Focused PS-LPS tests:

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-ps-lps.R")'
```

Result:

- `FAIL 0 | WARN 0 | SKIP 0 | PASS 50`

Full package test target:

```sh
make test
```

Result:

- `FAIL 0 | WARN 0 | SKIP 0 | PASS 990`

## Gate Decision

C8 passes audit. Proceed to C9: broader search-policy validation.
