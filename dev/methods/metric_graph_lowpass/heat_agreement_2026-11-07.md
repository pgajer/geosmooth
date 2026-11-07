# Graph-heat numerical agreement on weak connections

The verified graph-heat calculation lost accuracy when it formed a small
observed-data residual matrix by subtracting two nearly equal matrices.
Evaluating the same matrix through a residual factor removes that cancellation.
The fitted model, independent reference calculation, acceptance thresholds and
refusal to tune an unresolved GCV curve are unchanged.

## What was tested

The original failure occurred on Windows and Intel macOS in the nine-vertex
weak-chain test. The chain has eight edges, one with conductance `1e-8` and the
others between approximately 1 and 1.7. Only its two endpoints are observed,
with responses zero and one. The regression test uses 12 heat times from
`0.001` to `10000`.

For any connected graph with two observed responses, the observed residual
matrix is a scalar multiple of
`matrix(c(1,-1,-1,1),2)`. Consequently, its GCV score is exactly the squared
difference between the responses: one in this example. This gives an analytic
reference independent of either numerical eigensolver. GCV is flat, so the
method must provide the prescribed-time path and refuse to select a time.

The validation repeats these 12 times at five global conductance multipliers:
`1e-4`, `0.1`, `1`, `10` and `1e4`. Times are divided by the same multiplier,
preserving the heat operator. The regression tests also shift the response by
one million and multiply its difference by three; the corresponding GCV must
be nine. All existing operator-agreement and tuning gates still apply.

## Why the original calculation failed

Write the scaled heat complement as $A=(I-\exp(-tL))/s$, where $s$ is its
largest eigenvalue. Let $O$ and $U$ denote observed and unobserved vertices.
The missing-block solve is

$$X=A_{UU}^{-1}A_{UO}.$$

Previously, the observed residual matrix was evaluated directly as

$$K=A_{OO}-A_{OU}X.$$

On the weak-chain example at short times, the subtracted terms have entries
around 0.3, while the trace of the result is around $4\times10^{-9}$.
Double-precision roundoff in those larger terms becomes a material relative
error in the small result. GCV uses $K/\operatorname{tr}(K)$, so an inaccurate
residual trace affects the score even when the missing-block solve and fitted
predictions have small absolute errors. Platform-dependent rounding can
therefore make the candidate/reference comparison pass or fail.

The [original platform run](https://github.com/pgajer/geosmooth/actions/runs/42373054600)
failed `gcv.scaled.error` and `gcv.final.scaled.error` on both Windows and Intel
macOS. This was a numerical failure before the intended flat-GCV refusal, not
evidence that a smoothing time was identifiable.

## The corrected calculation

The checked eigensystem supplies a factor $F$ with $A=F^TF$. The implementation
now forms

$$R=F_O-F_UX,\qquad K=R^TR.$$

In exact arithmetic this is the same Schur complement. To see why, expand
$R^TR$ and substitute $A_{UU}X=A_{UO}$. In floating-point arithmetic it avoids
subtracting the two large quadratic terms. The existing solve for $X$ is
retained, as are its residual check and the independent bordered-pseudoinverse
reference. No ridge, edge removal, denominator floor, hard-coded GCV value or
relaxed tolerance is introduced.

## Measured local results

These are fixed-example numerical checks on macOS arm64, not a benchmark or a
study of predictive performance. The old subtraction and corrected formula
use the same candidate eigensystem and missing-block solve. This isolates the
effect of evaluating the Schur complement.

| Check | Result |
|---|---:|
| Prespecified time/conductance comparisons | 60 of 60 passed |
| Maximum old-formula absolute error against analytic GCV = 1 | `9.6270673766e-8` |
| Maximum corrected absolute error against analytic GCV = 1 | `4.4408920985e-16` |
| Largest fraction of the standardized candidate/reference error budget used | `0.162213` (limit: 1) |
| Failures when the old path implementation is restored in isolation | 10 new regression assertions |
| Corrected graph test group | 1,178 assertions across 15 files; no failures, warnings or skips |

The exact example is retained at full precision in the regression test and
the [reproduction script](../../../scripts/validate_graph_heat_agreement.R).
The [comparison table](heat_agreement_2026-11-07.csv) records the subtraction
scale, traces, nullspace errors and all 60 scores. Its numeric fields retain
17 significant digits so errors near machine precision are not rounded away.

## Package and platform validation

The candidate revision is `0569572b7c81f8393c236eddd30bfd631f764f10`.
The full local `R CMD check --as-cran` on macOS arm64 completed with zero
errors, warnings or notes. All 16,485 test expectations passed, with one
expected skip for a source-tree runner unavailable in the package archive.
Examples, rebuilt vignettes and PDF/HTML manuals passed. The checked archive's
changed implementation, regression, vignette and changelog files match the
candidate revision byte for byte.

The [five-platform check matrix](https://github.com/pgajer/geosmooth/actions/runs/42376015873)
completed successfully for that revision. Every job reported `Status: OK`
with no test failures or warnings:

| Platform | R configuration | Passing expectations | Expected skips |
|---|---|---:|---:|
| Windows 2022 | Release | 16,484 | 2 |
| Intel macOS 15 | Release | 16,485 | 1 |
| Ubuntu | Release | 16,485 | 1 |
| Ubuntu | Oldrel-1 | 16,485 | 1 |
| Ubuntu | Devel | 16,485 | 1 |

All jobs skip the source-tree-only runner check in the built archive. Windows
also retains the pre-existing exclusion for the graph-parallelism test.
The graph-heat regression tests run on every platform. The
[machine-readable validation record](heat_agreement_2026-11-07.json) gives the
source and evidence hashes and links to each completed job.

The first local package-build attempt stopped before tests because the default
installed `dgraphs` lacked a required header. The repeated check uses the
isolated `dgraphs` 0.4.0 build from the preceding successful package validation.
That environment correction is separate from the graph-heat repair.

## Reproduction and limits

From the package root, with the required development dependencies and an
optimized native build available:

```sh
OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 \
  Rscript scripts/validate_graph_heat_agreement.R /path/to/new/output-directory
make test-graph
make -o clean check
```

The script refuses to overwrite an existing output directory. It loads the
current source without rebuilding, writes the complete comparison table and
session information, and checks the analytic scores and numerical-agreement
budgets. A failed script produces no successful-validation table.

The verified fallback remains a double-precision agreement procedure. It does
not certify every graph or every weak edge, and it still refuses unresolved
spectra, inaccurate operators and unresolved tuning. The separate conservative
policy is unchanged. The [worked guide](../../../vignettes/verified-heat-fallback.Rmd)
describes the objective, independent reference and numerical limits.
