# Native order-2 logistic trend filtering

The structured backend is now available and selected automatically for large
knot sets. See the [banded backend report](banded_backend_report.md) for current
usage, dense comparisons, the five difficult cases and measured scaling results.
The sections below preserve the original dense-reference implementation record.

## Purpose and implementation

`fit.logistic.trend.filtering()` adds a one-dimensional piecewise-quadratic
logit curve to geosmooth with an R API and a C++ backend. No Python or glmgen
runtime is required. The implementation supports exact ties, trial weights,
observation-level covariates and offsets, optional ridge stabilization, and
explicit fold-based penalty selection. Failed fits are retained with diagnostic
status; ordinary prediction returns NA for them.

```r
fit <- fit.logistic.trend.filtering(
    x, y, lambda = c(1, 0.316227766, 0.1, 0.031622777, 0.01, 0.003162278, 0.001),
    lambda.selection = "cv", foldid = subject_fold
)
fit$diagnostics
fit$cv.table
predict(fit, x_new)
```

Supply training-ordered covariates and new offsets when used. Weights represent
trial counts when y is a binomial proportion. The penalty uses normalized
training locations on [0,1]; it does not use the original predictor units.
The lambda=Inf limit is quadratic, not linear. Extrapolation holds the curve
at its boundary value while retaining the supplied covariate and offset effects.
Ridge defaults to zero and changes the objective when explicitly enabled.

The dense reference solver uses a scaled falling-factorial basis and a profiled
logarithmic barrier for the L1 epigraph. It applies damped Newton steps with
line search, diagonal equilibration, and warm starts along decreasing lambda.
Newton damping stabilizes the numerical solve without adding an estimator ridge.
It checks the mean-loss stationarity residual, feasibility of an L1 dual vector,
and complementarity between that vector and the coefficients. The barrier
makes the latter check possible without classifying tiny coefficients as zero
using an arbitrary coefficient threshold. A returned optimizer status alone
never establishes convergence. The diagnostics are approximate KKT conditions,
not a separately calculated primal-dual objective-gap certificate.

An auxiliary search checks for unpenalized logistic recession directions. A
found direction is retained in `fit$fits[[j]]$separation.direction`, and the fit
is rejected as `separation_detected`. Not finding such a direction is not a
proof that separation is absent. Finite iteration budgets, singular systems,
and nonfinite arithmetic have separate failure statuses.

The initial dense reference implementation uses dense matrices. A conservative, configurable
workspace estimate (default ceiling 1 GiB) is checked before allocation; it is
not a process-wide memory limit. The backend is intended for moderate knot
counts, not unrestricted large-data fitting. No runtime superiority claim is made.

## Frozen unadjusted validation, November 5, 2026

The test collection contains 30 previously fitted immune-marker datasets across
ZAPPS and PreSSMat regions, each at the seven original penalties from 1 to 0.001.
The mathematical comparison uses the original unadjusted logistic objective,
with nuisance and curve ridge both zero. Input rows, original failures and
original versus stricter glmgen fits were preserved. No clinical associations
were retested and no penalties were retuned.

The fixed agreement gate requires absolute objective difference per observation
at most 1e-5 and maximum probability difference at most 0.001 (0.1 percentage
point). The native fit must also pass its own convergence diagnostics.

All **210/210 native fits converged and 210/210 agreed with the saved
custom reference**. The maximum probability difference was
1.0700926e-05 (0.00107009 percentage points).
The largest absolute objective difference per observation was
9.98491e-11. Maximum native mean-loss stationarity
was 9.80496e-10; maximum complementarity was 9.98934e-11.
Independent objective reconstruction also used the saved glmgen difference
operator, rather than only the native basis penalty.

Agreement with corrected glmgen remained **205/210**, with the same five weak-
penalty discrepancies. All five are at lambda=0.001:

| Dataset / marker | Native vs custom maximum probability difference (percentage points) | Native vs corrected glmgen (percentage points) | Native minus corrected objective / observation |
|---|---:|---:|---:|
| ZAPPS union / IL-6 | 7.59242e-05 | 0.358708 | -8.90989e-06 |
| PreSSMat Li Lc / IL-1a | 2.4705e-05 | 0.117559 | -6.07493e-08 |
| PreSSMat Li Lc / IL-1b | 0.000210332 | 3.25705 | -0.000155718 |
| ZAPPS Li Gv / IL-6 | 0.000297415 | 2.80257 | -0.000399697 |
| ZAPPS Li Gv / MIP-3a | 1.48959e-05 | 0.709566 | -6.2828e-05 |

The separately preserved stricter glmgen runs also retained their discrepancies.
The native solution closely matches the independent custom solution and has a
lower objective than corrected glmgen in all five cases. This supports using
the native/custom solution for these cases. It does not establish the precise
remaining defect in glmgen or prove reliability on arbitrary future datasets.

## Validation evidence and reproduction

- [Implementation plan](implementation_plan.md)
- [Native source](../../../src/logistic_trend_filtering.cpp)
- [R interface](../../../R/logistic_trend_filtering.R)
- [Synthetic regression tests](../../../tests/testthat/test-logistic-trend-filtering.R)
- [Frozen comparison runner](../../../scripts/validate_logistic_trend_filtering.R)
- [Adjusted full-fit comparison runner](../../../scripts/validate_logistic_trend_filtering_adjusted.R)
- [Private comparison table](/Users/pgajer/.codex/private/geosmooth/logistic-trend-filtering/validation-20261105-verified/comparison.csv)
- [Private summary](/Users/pgajer/.codex/private/geosmooth/logistic-trend-filtering/validation-20261105-verified/summary.json)
- [Input/source hashes](/Users/pgajer/.codex/private/geosmooth/logistic-trend-filtering/validation-20261105-verified/hashes.csv)

The validation uses one numerical thread and an optimized source build. Clinical
inputs and fitted predictions remain outside the package repository. The first
validation directory is retained; its JSON summary rounded the maximum
probability difference to zero, while its CSV retained full precision. Later runs use full-precision JSON. The verified installed-source run linked
above is the authoritative comparison; earlier runs remain preserved.

From the package root, compile optimized once and load without recompiling:

```r
pkgbuild::compile_dll(".", debug = FALSE)
```

Then run `scripts/validate_logistic_trend_filtering.R` with the frozen reference
root and a new output directory. Never reuse an existing output directory. The
runner records per-fit diagnostics, original and stricter corrected-glmgen
comparisons, input/source hashes, source copies, and R session information.
`make test-logistic-tf` runs the focused synthetic tests. `make check-fast` checks
the built package; the focused tests and frozen comparisons are additional checks.

The saved adjusted full-data validation is separate from the unadjusted solver
comparison. It does not replace earlier failed/unsupported nested-validation
results or provide new clinical predictive evidence. The original Gaussian
minimax theorem is not asserted for this logistic or ridge-stabilized model.

## Adjusted objectives and package QA

All **30 saved selected full-data adjusted fits** converged and agreed with the
custom implementation, using its same age/assay design and explicit ridge
penalties (0.16 for standardized nuisance coefficients, 0.04 for the centered
curve). The maximum probability difference was 1.33193117e-6
(0.000133193 percentage points); the maximum absolute objective difference per
observation was 9.848314e-11. Sixteen references came from completed original
validation workflows and fourteen from separately preserved descriptive
full-data fits. These results do not repair or replace the original five conic
nested-validation failures or nine unsupported validation tasks.

[Adjusted comparison table](/Users/pgajer/.codex/private/geosmooth/logistic-trend-filtering/adjusted-validation-20261105-verified/comparison.csv)
and [summary](/Users/pgajer/.codex/private/geosmooth/logistic-trend-filtering/adjusted-validation-20261105-verified/summary.json).

The final optimized isolated installation passed **48 focused test assertions**
with no test warnings or skips. They cover independent GLM and objective/KKT
reconstruction, binomial weight equivalence, exact and near ties, offsets,
covariates, boundary prediction, CV training isolation, explicit iteration
failure, separation, and input/workspace validation. Documentation coverage
checks pass for all 67 explicit package exports and 99 S3 registrations.

`make check-fast` completed with **zero errors, zero warnings, and two NOTEs**.
One NOTE concerns public documentation links not yet present on the deployed
website. The other identified unqualified stats generics in the new R methods;
those calls were qualified and the final installed package was checked again
with `codetools::checkUsagePackage()`. The new methods have no remaining usage
diagnostics; that broader checker prints existing unused-local-variable messages
in unrelated methods. The final installation and focused/numerical validations
include that correction and an additional overflow-input guard. The full
package check was not repeated after these targeted corrections. The new
function-guide entries now use plain help names, avoiding a new unpublished
website link. No website was published.

The fast package check excludes examples and package tests, but builds and
rebuilds the vignettes. The new documented example was exercised separately;
the 48 focused assertions and frozen solver comparisons are separate completed
checks. The complete existing package test suite, Windows checks, and CRAN
submission checks have not been run for this change.

[Preserved QA logs](/Users/pgajer/.codex/private/geosmooth/logistic-trend-filtering/qa-20261105)
include the original package check, final installation, focused assertions,
source-usage checks, documentation generation and numerical validation logs.

## Applicability to 24,000 AGP observations

The dense backend is not appropriate for a full 24,000-observation fit when
nearly every predictor value is distinct. With n observations, m distinct x
values, and q nuisance columns, its design has p=m+q columns. Storage includes
O(n*p+p^2) arrays; each Newton iteration forms a dense Hessian in O(n*p^2)
work and factors it in O(p^3) work. Penalty paths and cross-validation repeat
that work. These are algorithmic scaling estimates, not measured runtimes.

For 24,000 observations, seven penalties, and no nuisance columns:

| Distinct predictor values | One dense design matrix (GiB) | Conservative solver workspace estimate (GiB) |
|---:|---:|---:|
| 200 | 0.0358 | 0.1504 |
| 1,000 | 0.1788 | 0.8086 |
| 2,000 | 0.3576 | 1.7922 |
| 24,000 | 4.2915 | 68.6721 |

The default 1-GiB workspace guard rejects the last two examples. These estimates
include conservative allowances for working matrices, not a measurement of peak
RSS; they exclude unrelated process memory and aggregate concurrent fits.
Raising the guard does not solve the computation problem. Nuisance columns add
to p. Exact ties reduce the knot count; arbitrary rounding or knot thinning
would change the estimator and was not introduced here.

The initial recommendation for full continuous-predictor AGP fits was to retain
the exact objective and convergence checks while using the sparse third-
difference operator and structured/banded linear algebra or an appropriate
operator-splitting solver. The banded backend now implements that recommendation; retain the dense implementation as the small-problem
reference and validate the scalable solver against it and the frozen difficult
cases. This recommendation does not imply that the existing multidimensional
or graph smoothers in geosmooth share this dense backend.
