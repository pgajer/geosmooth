# Binary solver stagnation repair (2026-11-07)

The 17 unresolved binary candidates from the practical-validation study now
converge under the original tolerances and iteration ceiling. Both backends
also pass all 364 surrounding candidate fits and agree with the saved certified
reference fits. The research record, raw reruns, diagnostic controls and LaTeX
report are maintained in
`/Users/pgajer/current_projects/trend_filtering/development/logistic_tf_stagnation/`.

- Banded: project inactive-knot duals and choose admission signs using the same
  centered gradients as the convergence check. This removes spurious knot
  admission and immediate removal near the tolerance boundary.
- Dense: represent the ridge by its residual factor, evaluate the ridge and
  gradient from residuals, and evaluate line-search objective changes directly.
  This removes cancellation in the expanded ridge and in nearly equal totals.

The public functions, summed-loss objective, CV scaling, convergence thresholds
and failure semantics are preserved. The internal unexported native `ridge`
argument is now a rectangular `ridge_factor` argument. Its Gram matrix is used
for Hessian construction only. The Gaussian backend shares this infrastructure
and was included in regression and full package checks. Dense workspace estimates
include residual-factor storage. Banded full-knot storage remains compact.

Regression coverage is in `tests/testthat/test-logistic-trend-filtering-stagnation.R`.
`make test-logistic-tf` includes these tests. Full `make -o clean check` passed
with 0 errors, warnings or notes, 16,417 passing expectations and one expected
source-runner skip in the built archive. This is a numerical repair, not evidence
that any particular smoothing penalty predicts better, nor a guarantee that all
future fits will converge.
