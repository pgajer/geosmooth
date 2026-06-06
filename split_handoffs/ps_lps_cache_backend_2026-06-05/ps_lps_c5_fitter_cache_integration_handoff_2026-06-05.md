# PS-LPS C5 Fitter Cache Integration Handoff

Build time: 2026-06-05 19:20:46 EDT

## Scope

C5 wires the C4 component cache into the exported `fit.ps.lps()` tuning path.
The public function signature and model semantics are unchanged.

Before C5, the cache-aware helpers were available only through internal calls.
`fit.ps.lps()` still called `.ps.lps.solve()` directly for every fold and every
candidate `lambda.sync`.  C5 changes that:

- one `ps_lps_system_cache` is built per fixed chart configuration;
- one `ps_lps_component_cache` is built per CV fold response-weight pattern;
- one full-data `ps_lps_component_cache` is built for full-data diagnostics and
  final fitting;
- positive `lambda.sync` candidates use `.ps.lps.solve.component.cached()`;
- `lambda.sync = 0` continues to use the independent/direct solver path.

This preserves the ordinary-LPS nesting interpretation at zero synchronization
while accelerating positive synchronization scans.

## Files Changed

- `R/ps_lps.R`
  - `fit.ps.lps()` now builds fold/full-data component caches when the lambda
    grid contains any positive `lambda.sync`.
  - Positive synchronization CV folds, full-data diagnostics, and selected
    final fits use the component-cache solve path.
  - The returned object includes `cache.backend`, equal to `"component"` when
    positive synchronization candidates are present and `"independent"` when
    the grid is zero-only.
- `tests/testthat/test-ps-lps.R`
  - Adds an integration test comparing cache-aware `fit.ps.lps()` against a
    manually reconstructed direct tuning loop.

## Verification

Focused PS-LPS tests:

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-ps-lps.R")'
```

Result: 50 passed, 0 failures, 0 warnings, 0 skips.

Full package tests:

```sh
make test
```

Result: 990 passed, 0 failures, 0 warnings.

End-to-end timing smoke check on one representative positive-sync grid:

- manually reconstructed direct CV plus diagnostic loop: 0.348 sec;
- cache-aware `fit.ps.lps()`: 0.198 sec;
- returned `cache.backend`: `component`;
- selected `lambda.sync`: 0.1.

## Interpretation

C5 is the first cache-backend phase that improves the exported fitter path.
It addresses the C3/C4 audit concern that backend helpers were only exercised
in isolated tests.

The speedup from this small smoke check is modest but meaningful.  It should
grow with larger lambda grids because each fold cache can be reused across all
positive `lambda.sync` candidates.

## Remaining Work

The next useful phase is not another cache layer by itself, but a profile and
policy phase:

**C6: cache-aware PS-LPS profile and selection-run validation.**

Recommended C6 tasks:

1. rerun the representative PS-LPS profile report against the cache-aware
   `fit.ps.lps()` path;
2. compare old direct-loop timings to C5 timings across larger grids;
3. inspect whether solve time, diagnostics, or chart construction is now the
   main bottleneck;
4. decide whether the next engineering target should be native factorization,
   faster diagnostics, or higher-level candidate-search logic.

