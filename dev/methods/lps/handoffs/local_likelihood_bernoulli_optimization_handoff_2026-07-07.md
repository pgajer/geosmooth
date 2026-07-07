# Local-Likelihood Bernoulli OD Visit-CV Optimization Handoff

Status: ready for audit  
Role: implementer  
Repository: `/Users/pgajer/current_projects/geosmooth`  
Branch: `main`  
Base commit: `932c46e` (`Add LPS OD speedup handoffs`)  
Final commit: `3163601e035d2cc27f11ee9145708a5645f53941` (`Accelerate local likelihood Bernoulli OD visit CV`)  
Final git status after commit/push: clean at the time of handoff generation

## Goal

Optimize the `local_likelihood_bernoulli` subject-occupation-density method in
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
`local_likelihood_bernoulli` inside OD visit CV.

For an OD candidate with scalar tuning parameters, the new path:

1. builds the fold-specific binary response columns once;
2. resolves the same chart-dimension policy used by `fit.local.likelihood()`;
3. builds each anchor's support, local chart, kernel weights, and local
   polynomial feature frame once;
4. reuses that frame across fold-response columns;
5. applies the existing Bernoulli local-likelihood solve and existing
   correction/normalization/status logic;
6. falls back to the original explicit fold loop when the candidate is not
   fixed-scalar or when unsupported nested source-level folds are supplied.

The Bernoulli solver was also lightly optimized:

- Newton iterations now start from the local degree-0 weighted Bernoulli
  optimum instead of the all-zero coefficient vector.
- Hessian assembly avoids one avoidable dense matrix allocation.
- The stable `log(1 + exp(x))` helper avoids `ifelse()`, which evaluates both
  branches.

The fallback semantics remain the same as before. Underdetermined local frames
or solver failures still use the existing Bernoulli fallback path.

## Files Changed

- `/Users/pgajer/current_projects/geosmooth/R/state_density.R`
  - Added the fixed-candidate OD visit-CV fast path.
  - Added private helpers:
    - `.state.density.local.likelihood.bernoulli.fixed.visit.predictions()`
    - `.state.density.local.likelihood.fixed.candidate()`
    - `.state.density.local.likelihood.bernoulli.fixed.fitted.matrix()`
    - `.state.density.local.likelihood.bernoulli.frame()`
    - `.state.density.local.likelihood.bernoulli.frame.values()`
    - `.state.density.local.likelihood.bernoulli.degree0.values()`
- `/Users/pgajer/current_projects/geosmooth/R/local_likelihood.R`
  - Added `.local.likelihood.bernoulli.initial.beta()`.
  - Reduced allocation in `.local.likelihood.bernoulli.state()`.
  - Rewrote `.local.likelihood.log1pexp()` without `ifelse()`.
- `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-state-density-od3.R`
  - Added a regression test showing the fixed-candidate fast path matches the
    explicit fold loop.

## Generated Artifacts

No generated reports, Rd files, NAMESPACE updates, or HTML artifacts were
created by this optimization.

This handoff itself was created after the optimization commit and is a source
Markdown artifact under `dev/methods/lps/handoffs/`.

## Commands Run

From `/Users/pgajer/current_projects/geosmooth`:

```sh
git diff --check
```

```sh
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-state-density-od3.R", reporter = "summary")'
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
git commit -m "Accelerate local likelihood Bernoulli OD visit CV"
git push origin main
```

## Validation

The focused OD3 regression test passed after the optimization.

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
fit.subject.od(method = "local_likelihood_bernoulli", od.cv = "none")
```

for two bandwidth multipliers. The fast and slow predictions matched to
`1e-8` tolerance.

## Timing Evidence

Focused timing on the local smoke benchmark gave:

| Benchmark | Before | After | Speedup | Numerical delta |
|---|---:|---:|---:|---:|
| fixed candidate | 0.161 s | 0.100 s | 1.61x | 0 |
| 16-candidate OD-CV grid | 0.712 s | 0.403 s | 1.77x | max score delta `8.88e-16` |

The speedup is smaller than the earlier LPS/PS-LPS OD optimizations because
the Bernoulli local likelihood still spends substantial time in per-anchor
logistic Newton solves. This optimization removes repeated chart/frame
construction in visit CV and improves Newton initialization, but it does not
replace the solver with a native or batched backend.

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

No native C++ or Rcpp backend was introduced for local-likelihood Bernoulli
solves. Further speedups may require batching or native implementation of the
per-anchor logistic fitting loop.

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
