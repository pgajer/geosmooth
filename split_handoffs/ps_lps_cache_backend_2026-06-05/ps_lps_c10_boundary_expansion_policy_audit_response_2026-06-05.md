# PS-LPS C10 Boundary-Expansion Search Policy Audit Response

Build time: 2026-06-05 21:14:21 EDT

## Audit Addressed

Audit file:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/ps_lps_c10_boundary_expansion_policy_audit_2026-06-05.md`

The audit accepted C10 with two minor nonblocking issues:

1. `max.candidates` was validated but did not globally cap coarse/refine
   evaluations.
2. `lambda.sync.search.control` needed user-facing documentation of supported
   fields and defaults.

## Changes Made

### `max.candidates` is now a global cap

`.ps.lps.search.lambda.sync()` now enforces `max.candidates` across the full
guarded search path:

- zero/coarse stage;
- local refinement;
- boundary expansion.

This preserves the intended meaning of `max.candidates`: it is a cap on the
number of distinct `lambda.sync` values evaluated by the guarded policy. If a
user supplies a very small cap, the search can stop before refinement or
boundary expansion. That behavior is now explicit and documented.

Added regression coverage:

- `PS-LPS guarded lambda search enforces max.candidates globally`

This test covers the auditor's spot-check pattern where the previous
implementation could exceed a small cap during coarse/refine evaluation.

### Search controls are now documented

The roxygen documentation for `fit.ps.lps()` now lists all guarded-search
control fields and defaults:

- `coarse.size = 5`
- `refine.radius = 2`
- `rel.tol = 0.002`
- `boundary.guard.rel.tol = 0.01`
- `boundary.expand = TRUE`
- `boundary.factor = 3`
- `max.boundary.expansions = 2`
- `max.candidates = 25`

The documentation also states that boundary expansion may evaluate positive
candidates outside the supplied `lambda.sync.grid`, and that `max.candidates`
is a global cap.

`man/fit.ps.lps.Rd` was regenerated with `make document`.

## Validation

Commands run:

```sh
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-ps-lps.R")'
make document
Rscript scripts/profile_ps_lps_c10_boundary_expansion_policy.R
make test
git diff --check -- R/ps_lps.R tests/testthat/test-ps-lps.R man/fit.ps.lps.Rd scripts/profile_ps_lps_c10_boundary_expansion_policy.R
```

Results:

- focused PS-LPS tests: passed, 67 tests;
- C10 validation report regenerated successfully;
- C10 validation retained selected-lambda agreement with expanded reference:
  12 / 12;
- maximum CV RMSE regret: 0;
- maximum relative CV RMSE regret: 0;
- median candidate reduction versus expanded reference: 47.37%;
- median elapsed speedup: 1.80x;
- full package tests: passed, 1007 tests, no failures, no warnings;
- whitespace check: passed.

## Recommendation

Proceed to C11, but narrow C11 to prospective-policy readiness rather than more
low-level search mechanics.

The useful C11 question is:

Do exact grid search and guarded search produce practically equivalent PS-LPS
fits, not just matching selected `lambda.sync` values, on the first-batch
examples?

Suggested C11 scope:

1. Run exact grid and guarded search side by side on the first-batch examples.
2. Compare selected `lambda.sync`, fitted values, Truth RMSE, observed RMSE, CV
   RMSE, total local GCV, and pointwise truth-error delta diagnostics.
3. Include at least two guarded variants:
   - default C10 guarded policy;
   - stricter boundary guard, for example `boundary.guard.rel.tol = 0.002`.
4. Keep package API defaults as exact grid search.
5. If fitted-value and Truth-RMSE differences are negligible, freeze guarded
   search as the prospective-experiment policy for the next PS-LPS campaign.

The next phase should not yet promote guarded search as the package default.
