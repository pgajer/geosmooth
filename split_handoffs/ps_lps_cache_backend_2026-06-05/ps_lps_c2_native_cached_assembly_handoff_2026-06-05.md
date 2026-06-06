# PS-LPS C2 Native Cached Assembly Handoff

Build time: 2026-06-05 18:23:26 EDT

## Scope

C2 adds a native C++ assembly routine for the private PS-LPS cached-system path.
The goal is to remove repeated R-side `c()` growth and R loop assembly from the
hot stacked least-squares system construction used by `.ps.lps.solve.cached()`.

This is still an internal backend experiment.  The public `fit.ps.lps()` path is
not yet switched to the cached solver by default.

## Files Changed

- `src/ps_lps_cache_rcpp.cpp`
  - Adds `rcpp_ps_lps_assemble_cached_system()`.
  - Counts and fills sparse triplets and right-hand-side values in C++.
  - Uses 1-based sparse indices suitable for `Matrix::sparseMatrix()`.
- `R/RcppExports.R`
  - Adds the generated R wrapper.
- `src/RcppExports.cpp`
  - Adds the generated native registration wrapper.
- `R/ps_lps.R`
  - Updates `.ps.lps.solve.cached()` to call the native assembler.
  - Keeps sparse matrix construction, crossproducts, ridge normal formation,
    solve, diagnostics, and fitted-value recovery in R/Matrix.
- `tests/testthat/test-ps-lps.R`
  - Existing C1/C2 cached solver tests now exercise the native assembly path.

## Native Assembler Contract

The native assembler accepts:

- `cache`: a `ps_lps_system_cache` object from `.ps.lps.prepare.system.cache()`;
- `y`: the response vector;
- `response_weights`: fold or full-data response weights;
- `lambda_sync`: synchronization penalty.

It returns:

- `rows`, `cols`, `vals`: triplets for the stacked sparse design matrix;
- `rhs`: stacked right-hand side;
- `nrow`, `ncol`, `nnz`: system dimensions and nonzero count;
- `data_nrow`, `sync_nrow`: data and synchronization row counts.

For `lambda_sync = 0`, `.ps.lps.solve.cached()` continues to use the independent
chart solver and does not call the native assembler.

## Verification

Focused PS-LPS tests:

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-ps-lps.R")'
```

Result: 20 passed, 0 failures, 0 warnings, 0 skips.

Full package tests:

```sh
make test
```

Result: 960 passed, 0 failures, 0 warnings.

Ad hoc direct-versus-cached parity smoke check:

- direct solver elapsed: 0.029 sec
- cached native-assembly solver elapsed: 0.017 sec
- max absolute fitted-value difference: `6.08402217495e-14`
- max absolute coefficient difference: `4.01512156856e-13`

## Remaining Work

C2 only moves cached triplet/RHS assembly into C++.  The main remaining PS-LPS
costs are still:

- `Matrix::sparseMatrix()` construction;
- sparse crossproducts;
- ridge-normal matrix formation;
- sparse linear solve;
- diagnostics.

Recommended next phase:

**C3: cached crossproduct and factorization strategy.**  Decide whether the next
backend should cache reusable data/synchronization crossproduct pieces,
factorization objects, or both, so repeated CV folds and lambda values avoid
rebuilding as much of the normal system as possible.

