# PS-LPS C3 Normal Cache Audit 2026-06-05

## Verdict

Accepted with minor issues.

C3 correctly adds an internal normal-equation cache for fixed positive-sync
PS-LPS systems. The cache stores `A' A`, `A' b`, and the diagonal scale used by
the ridge policy, and cached solves reproduce direct positive-synchronization
solves to numerical precision across fitted values, coefficients, diagnostics,
fold-weighted systems, coefficients-only paths, and multiple ridge values.

There are no correctness blockers. The main caveat is integration scope:
`fit.ps.lps()` still calls `.ps.lps.solve()` directly, and `.ps.lps.solve.cached()`
builds a normal cache for a single solve. The ridge-reuse benefit is available
only when callers explicitly build a normal cache with
`.ps.lps.prepare.normal.cache()` and then call `.ps.lps.solve.normal.cached()`
for multiple ridge values. That is consistent with the handoff's "future
selector / ridge scan" interpretation, but it should not be described as an
end-to-end speedup of the exported fitter yet.

## Checks Performed

- Read handoff:
  `split_handoffs/ps_lps_cache_backend_2026-06-05/ps_lps_c3_normal_cache_handoff_2026-06-05.md`.
- Inspected implementation:
  `R/ps_lps.R`.
- Inspected native assembler:
  `src/ps_lps_cache_rcpp.cpp`.
- Inspected tests:
  `tests/testthat/test-ps-lps.R`.
- Ran focused PS-LPS tests:

```bash
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-ps-lps.R")'
```

Result: 31 passed, 0 failures, 0 warnings, 0 skips.

- Ran full package tests:

```bash
make test
```

Result: 971 passed, 0 failures, 0 warnings, 0 skips.

- Ran an independent ridge-scan smoke check on a synthetic system:
  - four direct solves over `lambda.ridge = c(0, 1e-10, 1e-8, 1e-6)`: 0.103 sec;
  - one normal-cache build plus four cached ridge solves: 0.019 sec;
  - maximum absolute fitted-value difference: `1.80411241502e-14`;
  - system size: 2500 rows, 360 columns, 25062 nonzeros.

## Implementation Review

### Normal Cache Construction

`.ps.lps.prepare.normal.cache()` requires a `ps_lps_system_cache` and positive
`lambda.sync`. It calls the native cached-system assembler, builds the sparse
matrix, computes:

- `cross = A' A`;
- `rhs.cross = A' b`;
- `scale = max(diag(cross))`;
- system row/column/nnz metadata;
- normal-cache timing components.

This matches the C3 contract. Positive `lambda.sync` is enforced, so the
zero-sync path remains the independent chart solver that preserves ordinary
LPS nesting semantics and per-chart ridge scaling.

### Cached Solve

`.ps.lps.solve.normal.cached()` uses the cached `cross`, `rhs.cross`, and
`scale` to form:

```r
normal <- cross + Diagonal(ncoef, x = lambda.ridge * scale)
```

and solve for the coefficients. It then recomputes diagnostics and fitted
values from the solved coefficients. This is the intended ridge-reuse path.

The fallback ridge behavior matches the direct positive-sync normal-equation
solve: if the solve fails or returns nonfinite coefficients, it retries with
`sqrt(.Machine$double.eps) * scale`.

### Native Assembly

The native assembler mirrors the R sparse triplet semantics:

- data rows use positive finite `response_weights[point] * local_weight`;
- data row values are `sqrt(weight) * design`;
- data RHS is `sqrt(weight) * y[point]`;
- synchronization rows use
  `sqrt(lambda.sync) * sqrt(omega)` with positive sign for chart `i` and
  negative sign for chart `j`;
- synchronization RHS is zero;
- count/fill consistency is checked before returning triplets.

Index handling is correct: R's one-based point indices are converted to
zero-based positions for `response_weights` and `y`, while sparse matrix row
and column indices returned to R remain one-based.

## Test Coverage Assessment

The focused tests cover the essential correctness surfaces:

- cached solve versus direct solve for positive synchronization;
- fold-weighted systems;
- coefficients-only diagnostics;
- direct normal-cache solve versus direct solve;
- normal-cache reuse across multiple ridge values;
- earlier zero-sync nesting and synchronization-energy tests.

This is sufficient for C3 acceptance.

Useful future hardening:

1. Add an explicit error test that `.ps.lps.prepare.normal.cache()` rejects
   `lambda.sync = 0`.
2. Add a test proving that the same normal cache reused across multiple ridge
   values does not mutate the cache object or timing metadata in a way that
   affects later solves.
3. Add a larger, ill-conditioned stress case where the fallback ridge path is
   triggered in both direct and normal-cached solves, then compare results and
   reported `ridge.max`.

## Performance Interpretation

The handoff's performance interpretation is accurate for ridge scans at fixed:

- frames;
- sync rows;
- response vector;
- response weights;
- positive `lambda.sync`.

For that setting, the normal cache avoids rebuilding the sparse design and
recomputing crossproducts. My independent smoke check confirmed a clear speedup
on a small synthetic system.

However, C3 does not yet accelerate scans over `lambda.sync`, because the
synchronization rows scale with `sqrt(lambda.sync)` and C3 caches the already
combined normal matrix for one fixed synchronization value. The handoff
correctly identifies C4 as the natural next step:

```text
A(lambda.sync)' A(lambda.sync) = C_data + lambda.sync * C_sync
A(lambda.sync)' b = r_data
```

## Nonblocking Issues

1. `fit.ps.lps()` does not use the cached solve path, so C3 is not yet an
   exported-fitter speedup.
2. `.ps.lps.solve.cached()` builds a normal cache and immediately solves once;
   repeated-ridge speedups require callers to use
   `.ps.lps.prepare.normal.cache()` directly.
3. The normal cache stores `response.weights` but does not currently validate
   its length or finiteness at the R wrapper boundary. The native assembler and
   existing solve code effectively assume valid inputs from the caller; this is
   acceptable for an internal helper but worth hardening if the helper becomes
   broader infrastructure.

## Recommendation

Accept C3 and proceed to C4.

C4 should split the cached normal pieces into data and synchronization
components so that fixed frames and fold weights can scan `lambda.sync` without
reassembling the stacked sparse system:

- precompute `C_data`;
- precompute `C_sync`;
- precompute `r_data`;
- solve `C_data + lambda.sync * C_sync + rho I` for each sync/ridge pair.

Before wiring C3/C4 into S1-style experiment runners, add a small integration
test or benchmark showing that the actual runner path uses the cache rather
than only exercising it in isolated tests.

