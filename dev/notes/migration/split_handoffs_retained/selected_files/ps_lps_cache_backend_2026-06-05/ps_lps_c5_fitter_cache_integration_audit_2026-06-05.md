# PS-LPS C5 Fitter Cache Integration Audit

Date: 2026-06-05

Audited handoff:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/ps_lps_c5_fitter_cache_integration_handoff_2026-06-05.md`

Repository:

- `/Users/pgajer/current_projects/geosmooth`

## Verdict

Accepted. C5 correctly integrates the PS-LPS component cache into the exported
`fit.ps.lps()` tuning and final-fit path without changing the public interface
or model semantics.

I found no correctness blockers. The implementation satisfies the C5 contract:
positive `lambda.sync` candidates use the component-cache normal-equation path,
zero `lambda.sync` candidates remain on the direct/independent path, CV and
final fits agree with direct assembly to numerical precision, and the returned
`cache.backend` field reflects whether the component backend was active.

## Scope Reviewed

Reviewed:

- `R/ps_lps.R`
- `tests/testthat/test-ps-lps.R`
- C5 handoff and claimed verification notes

Primary implementation points checked:

- `fit.ps.lps()` constructs one PS-LPS system cache for the fixed chart/sync
  configuration.
- It constructs one component cache per CV fold using fold-specific response
  weights and one full-data component cache for diagnostics/final fitting when
  positive synchronization candidates are present.
- Positive `lambda.sync` candidates route through
  `.ps.lps.solve.component.cached()`.
- `lambda.sync == 0` candidates route through `.ps.lps.solve()` directly.
- Final selected positive-sync fits use the full-data component cache.
- Final selected zero-sync fits use the direct path.
- `cache.backend` is `"component"` when any positive-sync candidate is present
  and `"independent"` for zero-only grids.

## Correctness Assessment

The algebraic split is correct. The component cache stores:

- the data normal-equation contribution, `cross.data` and `rhs.data`, under the
  relevant response weights; and
- the synchronization normal-equation contribution, `cross.sync`, assembled once
  at unit synchronization strength with zero response weights.

For positive `lambda.sync`, the normal matrix is recombined as
`cross.data + lambda.sync * cross.sync`, while the right-hand side remains
`rhs.data`. This is the same objective represented by direct assembly, since
synchronization rows carry zero response and only contribute a quadratic
penalty.

The fold-specific cache construction also preserves CV semantics: held-out fold
responses are excluded by zero response weights in the fold component cache, and
predictions are read from the fitted values at the held-out indices, matching the
existing direct CV loop.

## Verification Performed

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

Additional mixed-grid spot check performed by the auditor:

- Grid: `lambda.sync.grid = c(0, 0.2, 1, 5)`
- Exported `fit.ps.lps()` compared against a manual direct-assembly CV loop.
- Result:
  - `cache.backend = component`
  - selected lambda matched direct: `0.2`
  - maximum CV RMSE difference: `4.44e-16`
  - maximum fitted-value difference: `8.66e-15`

This spot check covers the mixed zero-plus-positive branch that is not fully
exercised by the positive-only integration test.

## Nonblocking Issues and Recommendations

1. Add a committed mixed-grid regression test.

   The current integration test checks a positive-only grid, and earlier tests
   cover zero-sync nesting. Since the exported C5 contract explicitly depends on
   mixed branch behavior, add a focused test with `lambda.sync.grid` containing
   both `0` and positive values. The auditor spot check above passed, so this is
   test hardening rather than a blocker.

2. Consider avoiding system-cache construction for zero-only grids.

   `fit.ps.lps()` currently prepares the system cache before checking whether
   any positive synchronization candidates exist. Semantically this is harmless,
   and zero-only fits still report `cache.backend = "independent"`, but it means
   a zero-only grid pays some cache setup cost that is not used by the solve
   path. This is a small performance cleanup candidate, not a correctness issue.

3. Keep the timing smoke interpretation narrow.

   The handoff timing result supports the intended direction, but it is still a
   smoke check. C6 should profile larger grids and larger fold counts, where the
   component-cache design should have the clearest payoff.

## Gate Decision

C5 passes audit. It is ready to proceed to the next cache-backend phase, with
the mixed-grid regression test recommended as a small follow-up guard.
