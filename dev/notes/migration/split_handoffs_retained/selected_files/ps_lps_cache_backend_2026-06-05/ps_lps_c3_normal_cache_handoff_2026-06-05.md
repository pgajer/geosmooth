# PS-LPS C3 Normal Cache Handoff

Build time: 2026-06-05 18:53:02 EDT

## Scope

C3 adds an internal PS-LPS normal-equation cache on top of the C2 native sparse
system assembler.  The new cache is intended for repeated solves with the same:

- frames;
- synchronization rows;
- response vector;
- response-weight pattern, for example one CV fold;
- positive `lambda.sync`.

For that fixed system, C3 precomputes:

\[
  A^\top A,\qquad A^\top b,\qquad \max_j (A^\top A)_{jj},
\]

and then solves repeated ridge systems

\[
  \{A^\top A + \rho I\}\hat\beta = A^\top b,
  \qquad
  \rho = \lambda_{\rm ridge}\max_j(A^\top A)_{jj},
\]

without rebuilding the stacked sparse design or recomputing crossproducts.

## Files Changed

- `R/ps_lps.R`
  - Adds `.ps.lps.prepare.normal.cache()`.
  - Adds `.ps.lps.solve.normal.cached()`.
  - Refactors `.ps.lps.solve.cached()` so positive-synchronization solves use
    the new normal-cache path.
- `tests/testthat/test-ps-lps.R`
  - Adds direct-solver parity tests for the normal cache.
  - Adds a ridge-reuse test that solves multiple ridge values from the same
    normal cache.

No public API is changed.

## Cache Contract

`.ps.lps.prepare.normal.cache(cache, y, response.weights, lambda.sync)` requires
`lambda.sync > 0`.  The zero-synchronization case remains routed through the
independent chart solver, because that path intentionally preserves ordinary
LPS nesting semantics and per-chart ridge scaling.

The returned object has class `ps_lps_normal_cache` and stores:

- `frames`, `sync.rows`, `y`, `response.weights`;
- `lambda.sync`;
- sparse `cross = A' A`;
- `rhs.cross = A' b`;
- scale used to form the ridge term;
- system dimensions and nonzero count;
- timing components for assembly and crossproduct work.

`.ps.lps.solve.normal.cached(normal.cache, lambda.ridge)` then performs only:

- ridge-normal formation;
- linear solve;
- diagnostics;
- fitted-value recovery unless `coefficients.only = TRUE`.

## Verification

Focused PS-LPS tests:

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-ps-lps.R")'
```

Result: 31 passed, 0 failures, 0 warnings, 0 skips.

Full package tests:

```sh
make test
```

Result: 971 passed, 0 failures, 0 warnings.

Ridge-scan smoke check on one representative synthetic system:

- four direct solves over `lambda.ridge = c(0, 1e-10, 1e-8, 1e-6)`: 0.139 sec;
- one normal-cache build plus four cached ridge solves: 0.031 sec;
- maximum absolute fitted-value difference: `3.04201108747e-14`.

## Interpretation

C3 is most useful for ridge sensitivity or any future selector that scans
`lambda.ridge` while holding a fold and `lambda.sync` fixed.  It does not yet
avoid rebuilding the normal cache across different `lambda.sync` values, because
the synchronization block changes with `sqrt(lambda.sync)`.

The natural next backend step is therefore:

**C4: split normal-cache pieces into data and synchronization components.**

For fixed frames and response weights, the normal system has the structure

\[
  A(\lambda_{\rm sync})^\top A(\lambda_{\rm sync})
  = C_{\rm data} + \lambda_{\rm sync} C_{\rm sync},
\]

and

\[
  A(\lambda_{\rm sync})^\top b = r_{\rm data},
\]

because synchronization rows have zero right-hand side.  If C4 precomputes
`C_data`, `C_sync`, and `r_data`, then scanning `lambda.sync` would no longer
require rebuilding sparse stacked systems or recomputing crossproducts.
