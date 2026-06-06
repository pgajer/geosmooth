# PS-LPS C4 Component Cache Handoff

Build time: 2026-06-05 19:15:37 EDT

## Scope

C4 addresses the main C3 audit caveat: C3 cached a complete normal system for
one fixed positive `lambda.sync`, so it accelerated ridge scans but not
synchronization-penalty scans.  C4 splits the PS-LPS normal system into reusable
data and synchronization components.

For fixed frames, synchronization rows, response vector, and response weights,
the stacked PS-LPS system has the form

\[
  A(\lambda_{\rm sync})^\top A(\lambda_{\rm sync})
    =
    C_{\rm data} + \lambda_{\rm sync} C_{\rm sync},
\]

and

\[
  A(\lambda_{\rm sync})^\top b = r_{\rm data},
\]

because synchronization rows have zero right-hand side.

C4 precomputes

\[
  C_{\rm data},\qquad C_{\rm sync},\qquad r_{\rm data},
\]

and then each positive `lambda.sync` solve only combines

\[
  C_{\rm data}+\lambda_{\rm sync}C_{\rm sync}
\]

before applying the existing ridge-normal and solve path.

## Files Changed

- `R/ps_lps.R`
  - Adds `.ps.lps.prepare.component.cache()`.
  - Adds `.ps.lps.component.normal.cache()`.
  - Adds `.ps.lps.solve.component.cached()`.
- `tests/testthat/test-ps-lps.R`
  - Adds component-cache parity tests across multiple positive
    `lambda.sync` values.
  - Adds explicit rejection tests for nonpositive `lambda.sync` in
    positive-sync cache helpers.

No public API is changed.

## Component Cache Contract

`.ps.lps.prepare.component.cache(cache, y, response.weights)` requires:

- a `ps_lps_system_cache`;
- finite `y`;
- finite `response.weights` of the same length as `y`.

It returns a `ps_lps_component_cache` containing:

- `cross.data = C_data`;
- `cross.sync = C_sync`;
- `rhs.data = r_data`;
- system dimensions and nonzero counts;
- component-cache timing metadata.

The synchronization component is built once with the C2 native assembler using
zero response weights and `lambda.sync = 1`.  Therefore `cross.sync` is the
unscaled synchronization normal matrix, ready to be multiplied by any positive
`lambda.sync`.

`.ps.lps.solve.component.cached(component.cache, lambda.sync, lambda.ridge)`
requires `lambda.sync > 0`.  The zero-synchronization case still belongs to the
ordinary independent chart solver so the ordinary-LPS nesting interpretation
remains separate.

## Verification

Focused PS-LPS tests:

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-ps-lps.R")'
```

Result: 45 passed, 0 failures, 0 warnings, 0 skips.

Full package tests:

```sh
make test
```

Result: 985 passed, 0 failures, 0 warnings.

Synchronization-scan smoke check on one representative synthetic system:

- three direct solves over `lambda.sync = c(0.1, 1, 10)`: 0.132 sec;
- one component-cache build plus three cached sync solves: 0.039 sec;
- maximum absolute fitted-value difference: `8.52651282912e-14`.

## Interpretation

C4 turns the C3 fixed-`lambda.sync` cache into a reusable synchronization-scan
cache.  This directly addresses the auditor's main C3 performance caveat.

The component cache is still internal.  It does not yet make `fit.ps.lps()`
faster end to end because the exported fitter still calls the direct solver
path.  The next useful phase should therefore be integration, not another
isolated cache layer.

## Recommended Next Phase

**C5: cache-aware fitter integration.**

Add an internal PS-LPS tuning path that uses:

1. one `ps_lps_system_cache` per fixed chart configuration;
2. one `ps_lps_component_cache` per fold response-weight pattern;
3. repeated `.ps.lps.solve.component.cached()` calls over positive
   `lambda.sync` values;
4. the existing independent solver for `lambda.sync = 0`;
5. unchanged selected-fit semantics and diagnostics.

C5 should include an integration benchmark proving that `fit.ps.lps()` or a
nearby internal tuning runner actually exercises the component cache on a
multi-`lambda.sync` grid.

