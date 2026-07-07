# Local-Likelihood Density OD Visit-CV Optimization Handoff

Status: ready for audit  
Role: implementer  
Repository: `/Users/pgajer/current_projects/geosmooth`  
Branch: `main`  
Base commit: `45349f4` (`Add local likelihood Bernoulli optimization handoff`)  
Final commit: `fff4e71ec4c5aa2a8cd6aebf39860e1295a0864e` (`Accelerate local likelihood density OD visit CV`)  
Final git status after commit/push: clean at the time of handoff generation

## Goal

Optimize the `local_likelihood_density` subject-occupation-density method in
the OD visit-CV path without changing fitted values, candidate scores, or
selection semantics.

The immediate motivation was the OD method runtime profiling lane, where the
pre-optimization median runtimes were:

| Method | Median sec | Max sec |
|---|---:|---:|
| `ps_lps_count` | 111.4 | 360.6 |
| `lps_count` | 62.1 | 75.5 |
| `lps_logistic_binary` | 27.3 | 34.3 |
| `local_likelihood_bernoulli` | 7.6 | 9.1 |
| `local_likelihood_density` | 5.9 | 7.4 |
| `chart_kernel` | 2.4 | 3.4 |
| `graph_random_walk` | 0.16 | 0.18 |
| `empirical` | 0.006 | 0.006 |

## Work Completed

The implementation added a conservative fixed-candidate fast path for
`local_likelihood_density` inside OD visit CV.

For an OD candidate with scalar tuning parameters, the new path:

1. builds fold-specific normalized count-mass response columns once;
2. resolves the same chart-dimension policy used by `fit.local.likelihood()`;
3. builds each anchor's support, local chart, kernel weights, quadrature weights,
   and local polynomial feature frame once;
4. reuses that frame across fold-response columns;
5. applies the existing density exponential-tilt local-likelihood solve and the
   existing correction/normalization/status logic;
6. falls back to the original explicit fold loop when the candidate is not
   fixed-scalar or when unsupported nested source-level folds are supplied.

The density exponential-tilt state calculation was also lightly optimized:

- `log.weights` is now filled only on positive-base entries instead of using
  `ifelse()`, which evaluates both branches.
- The weighted-feature matrix uses vector recycling instead of explicitly
  allocating a repeated probability matrix.

The fallback semantics remain the same as before. Zero-mass local windows,
underdetermined local frames, sparse local mass, or solver failures still use
the existing local-likelihood density fallback path.

## Files Changed

- `/Users/pgajer/current_projects/geosmooth/R/state_density.R`
  - Added the fixed-candidate OD visit-CV fast path for
    `local_likelihood_density`.
  - Added private helpers:
    - `.state.density.local.likelihood.density.fixed.visit.predictions()`
    - `.state.density.local.likelihood.density.fixed.fitted.matrix()`
    - `.state.density.local.likelihood.density.frame()`
    - `.state.density.local.likelihood.density.frame.values()`
- `/Users/pgajer/current_projects/geosmooth/R/local_likelihood.R`
  - Reduced allocation in `.local.likelihood.density.state()`.
  - Replaced `ifelse()` in density log-weight construction with positive-base
    indexing.
- `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-state-density-od3.R`
  - Added a regression test showing the fixed-candidate density fast path
    matches the explicit fold loop for degree 0 and degree 1.

## Generated Artifacts

No generated reports, Rd files, NAMESPACE updates, or HTML artifacts were
created by the optimization commit.

This handoff itself was created after the optimization commit and is a source
Markdown artifact under `dev/methods/lps/handoffs/`.

## Commands Run

From `/Users/pgajer/current_projects/geosmooth`:

```sh
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-state-density-od3.R", reporter = "summary")'
```

```sh
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-state-density-odcv2-chart-dim-density.R", reporter = "summary")'
```

```sh
git diff --check
```

```sh
make test-od
```

```sh
make test
```

The final commit and push commands were:

```sh
git add R/state_density.R R/local_likelihood.R tests/testthat/test-state-density-od3.R
git commit -m "Accelerate local likelihood density OD visit CV"
git push origin main
```

## Validation

The focused OD3 regression test passed after the optimization.

The OD-CV2 density chart-dimension test passed after the optimization.

The OD grouped test target passed:

```text
make test-od
```

The package fast development gate passed:

```text
make test
```

Whitespace validation passed:

```text
git diff --check
```

The added fixed-candidate regression test compared the fast path with an
explicit fold loop calling:

```r
fit.subject.od(method = "local_likelihood_density", od.cv = "none")
```

for degree 0 and degree 1 local-likelihood density candidates. The fast and
slow predictions matched to `1e-8` tolerance.

## Timing Evidence

Focused timing on the local smoke benchmark gave:

| Benchmark | Before | After | Speedup | Numerical delta |
|---|---:|---:|---:|---:|
| fixed candidate | 0.120 s | 0.057 s | 2.11x | max prediction delta `6.94e-18` |
| 16-candidate OD-CV grid | 0.356 s | 0.168 s | 2.12x | max score delta `0` |

The speedup comes from avoiding repeated chart/frame construction inside the
visit-CV fold loop. The density branch benefits more than the Bernoulli branch
in this smoke benchmark because the density solve is cheaper than repeated
logistic Newton solves, so chart/frame reuse accounts for a larger fraction of
runtime.

## Canonical/Generated File Notes

The canonical files are the R source and test files listed above. No generated
package files were edited.

`man/*.Rd`, `NAMESPACE`, package check directories, and dashboard HTML were not
modified by the optimization commit.

## Limitations And Unverified Claims

The original four-cell OD runtime profiling lane was not rerun end-to-end after
this optimization. The reported timings are focused smoke timings for a
representative local benchmark, not a full replacement for the OD profiling
table.

No native C++ or Rcpp backend was introduced for local-likelihood density
solves. Further speedups may be possible through native batching of the
per-anchor exponential-tilt local likelihood, but that was outside this
optimization.

The fast path only applies to scalar fixed candidates. Candidate configurations
that request nested source-level `foldid`, non-scalar grids inside a candidate,
or unsupported candidate shapes fall back to the original explicit fold loop.

No CRAN-style `make check-fast` or full `make check` was run for this isolated
optimization.

## Reusable Workflow Capture

Classification: no reusable artifact needed.

Rationale: this optimization follows the same local pattern as the recent
OD-method speedup work: identify repeated fold-loop work, add a conservative
fixed-candidate fast path, add equality regression tests against the old path,
and run focused OD/package tests. That pattern is already represented in the
nearby package history and does not yet need a separate workflow note.

## Next Actor

Ready for: independent audit or continuation of the OD method optimization
sequence.

Requested decision: none recorded in this handoff.
