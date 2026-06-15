# K3.9 Plan: Local-PCA LPS Acceleration Audit

Date: 2026-06-04

## Goal

K3.9 audits why `fit.lps(coordinate.method = "local.pca", chart.dim = "auto")`
is much slower than ambient-coordinate C++ LPS in the K3.8 VALENCIA-derived
run. This phase is diagnostic only: it does not change `fit.lps()` semantics.

## Questions

1. How much slower is local-PCA LPS than ambient C++ LPS on the same bounded
   VALENCIA-derived datasets and candidate grid?
2. Within the R local-PCA path, how much time is spent in:
   - nearest-neighbor ordering,
   - local PCA chart construction,
   - kernel weighting and weighted local-polynomial fitting,
   - chart-dimension resolution?
3. What is the highest-value next implementation target?

## Scope

Use a bounded version of the K3.8 setup:

- datasets: `rel4`, `hypercube_Li`, `depth3_top`
- sample sizes: `n = 250, 500`
- candidate grid:
  - support sizes `15, 25, 35`
  - degrees `1, 2`
  - kernels `gaussian, tricube`
  - CV folds `3`

The audit includes:

- end-to-end runtime comparison for ambient C++ and local-PCA auto LPS;
- an instrumented R replay of local-PCA CV for one representative dataset;
- a compact HTML report and CSV/RDS results bundle.

## Expected Decision

If local-PCA runtime is dominated by repeated R-level ordering/chart/fitting
loops, the next phase should be a native local-PCA LPS backend that reuses the
existing `compute_local_pca_chart()` C++ primitive and the ambient C++ LPS
weighted-regression infrastructure.

If auto chart-dimension resolution dominates, the next phase should instead
cache or precompute chart-dimension diagnostics by support-size/degree.

If nearest-neighbor ordering dominates, the next phase should reuse ANN tree
construction across local-PCA CV folds, mirroring the ambient C++ backend.
