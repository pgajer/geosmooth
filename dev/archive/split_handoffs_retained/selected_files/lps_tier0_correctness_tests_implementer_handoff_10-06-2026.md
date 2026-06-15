# LPS Tier 0 Correctness Tests: Implementer Handoff

Date: 10-06-2026
Project: `geosmooth` LPS correctness tests
Phase label: Tier 0 LPS correctness tests
Primary test file: `~/current_projects/geosmooth/tests/testthat/test-lps-tier0-correctness.R`

This handoff follows the two-agent workflow:

`~/.codex/notes/workflows/worker_auditor_workflow.md`

The auditor's authoritative mandate is the workflow's Audit Charter. This handoff is an evidence bundle only. It does not set the audit scope, does not supply audit questions, and does not suggest a verdict.

## Phase Goal

Add runnable `testthat` checks for the first Tier 0 LPS correctness gates:

- E0.1: polynomial reproduction for local polynomial designs;
- E0.2: fixed-configuration LPS linear-smoother identity and degrees-of-freedom trace behavior.

These tests exercise the current `fit.lps()` implementation directly.

## Files Created Or Used

Created:

- `~/current_projects/geosmooth/tests/testthat/test-lps-tier0-correctness.R`

Relevant production source under test:

- `~/current_projects/geosmooth/R/lps.R`

The current git tree also contains many unrelated dirty and untracked files from parallel workstreams. This handoff concerns the Tier 0 test file and the `fit.lps()` behavior it exercises.

## Test Contents

The test file is 267 lines long and contains four `test_that()` blocks:

1. `E0.1 LPS reproduces ambient polynomials represented by the local design`
2. `E0.1 LPS reproduces intrinsic polynomials on flat embedded subspaces`
3. `E0.2 fixed-configuration LPS is a linear smoother in ambient coordinates`
4. `E0.2 fixed-configuration LPS is a linear smoother in local PCA charts`

The test file defines helper functions for:

- counting local polynomial columns:
  `tier0.poly.column.count()`;
- generating degree-1 or degree-2 polynomial truths:
  `tier0.polynomial.truth()`;
- generating random orthonormal embeddings:
  `tier0.orthonormal.frame()`;
- fitting fixed or reproduction-focused LPS configurations:
  `tier0.reproduction.fit()`, `tier0.fixed.lps.fit()`;
- extracting the empirical smoother matrix by applying LPS to coordinate basis responses:
  `tier0.extract.smoother.matrix()`.

## Exact Command Run

The targeted test file was run with:

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-lps-tier0-correctness.R", reporter="summary")'
```

Observed output:

```text
lps-tier0-correctness: ....................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................

══ DONE ════════════════════════════════════════════════════════════════════════
```

No failure, error, warning, or skip line was printed by the targeted test run.

## Test Details Recorded By The Implementer

### E0.1 Ambient Polynomial Reproduction

The ambient reproduction block crosses:

- `ambient.dim` in `{2, 3}`;
- `degree` in `{1, 2}`;
- kernels:
  - `gaussian`;
  - `tricube`;
  - `epanechnikov`;
  - `triangular`;
- design bases:
  - `orthogonal.polynomial.drop`;
  - `monomial`;
  - `weighted.qr`;
  - `weighted.qr.drop`.

For each case it:

- generates uniform random ambient `X`;
- constructs a polynomial truth represented by the requested degree;
- chooses support size at least four times the number of polynomial columns, clipped below `n`;
- fits `fit.lps()` with:
  - `coordinate.method = "coordinates"`;
  - `backend = "R"`;
  - `ridge.multiplier.grid = 0`;
  - `ridge.condition.max = Inf`;
  - `unstable.action = "na"`;
- checks:
  - no `NA` fitted values;
  - maximum absolute fitted-value error below tolerance;
  - a single-row CV table for the fixed one-candidate setup.

### E0.1 Intrinsic Flat-Subspace Polynomial Reproduction

The intrinsic-subspace block crosses:

- `intrinsic.dim` in `{1, 2}`;
- `degree` in `{1, 2}`;
- the same four kernels;
- the same four design bases.

For each case it:

- generates intrinsic coordinates `U`;
- embeds them into a higher-dimensional flat subspace by an orthonormal frame;
- defines the polynomial truth in intrinsic coordinates;
- fits `fit.lps()` with:
  - `coordinate.method = "local.pca"`;
  - `chart.dim = intrinsic.dim`;
  - `local.chart.method = "pca"`;
  - `backend = "R"`;
  - `ridge.multiplier.grid = 0`;
  - `ridge.condition.max = Inf`;
  - `unstable.action = "na"`;
- checks:
  - no `NA` fitted values;
  - maximum absolute fitted-value error below tolerance;
  - a single-row CV table;
  - local chart method recorded as `pca`;
  - zero chart fallback count.

### E0.2 Ambient Linear-Smoother Identity

The ambient E0.2 block:

- uses `n = 36` in two ambient coordinates;
- constructs the smoother matrix `S` by fitting the fixed LPS configuration to each coordinate basis response;
- fits the same fixed configuration to random `y1`, `y2`, and the linear combination `y3 = 0.6 y1 - 1.4 y2`;
- checks:
  - `S %*% y1`, `S %*% y2`, and `S %*% y3` match direct `fit.lps()` fitted values;
  - fitted values obey the same linear combination;
  - basis-response perturbation columns match `S[, j]` for sampled indices;
  - `sum(diag(S))` is finite and positive;
  - the trace agrees with the summed pointwise bump response.

The fixed configuration uses:

- `support.grid = 18`;
- `degree.grid = 1`;
- `kernel.grid = "tricube"`;
- `coordinate.method = "coordinates"`;
- `backend = "R"`;
- `design.basis = "orthogonal.polynomial.drop"`;
- `ridge.multiplier.grid = 0`;
- `ridge.condition.max = Inf`;
- `unstable.action = "na"`.

### E0.2 Local-PCA Linear-Smoother Identity

The local-PCA E0.2 block:

- uses `n = 34`;
- creates a one-dimensional line embedded in two ambient coordinates;
- extracts `S` with:
  - `coordinate.method = "local.pca"`;
  - `chart.dim = 1`;
- checks the same linearity, matrix-action, finite-diagonal, positive-trace, and trace-by-bump-response conditions as the ambient block.

## Package Source Modified

The Tier 0 step created the new test file. It did not, in this handoff, isolate a new production-code patch separate from the broader dirty LPS source tree. The production source under test is the current local `R/lps.R`.

## Commands Not Run For This Handoff

The targeted Tier 0 test file was run. A full package test suite was not rerun as part of this handoff after creating the handoff documents.

## Limitations And Unverified Claims

- This is not an independent audit. Passing targeted tests does not establish Tier 0 acceptance under the two-agent workflow.
- Only E0.1 and E0.2 are represented in the current Tier 0 test file. The file name says Tier 0 broadly, but it does not yet implement E0.7, E0.8, E0.4, E0.5, E0.6, or other later gates described in the broader plan.
- The tests use fixed random seeds but do not materialize their generated synthetic datasets as reusable artifacts.
- The tests exercise `backend = "R"` and do not establish the same properties for any native/C++ backend.
- The E0.2 smoother matrix is extracted by repeated calls to `fit.lps()` on basis-response vectors; this checks empirical linearity for the fixed configuration but is not an analytic proof of the implemented smoother matrix.
- The reproduction tolerances are numerical thresholds chosen by the implementer: `1e-6` for monomial cases and `1e-8` otherwise.
- The tests use nonadaptive chart settings or explicitly supplied `chart.dim`; they do not audit `chart.dim = "auto"` or `chart.dim = "local.auto"` behavior.
- The current repository tree is dirty and contains unrelated work. These tests do not correspond to a clean committed package state.
