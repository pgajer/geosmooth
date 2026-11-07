# Logistic trend filtering

`fit.logistic.trend.filtering()` fits a one-dimensional piecewise-quadratic
logit curve with an R interface and dense or banded C++ backends. It supports
tied predictor values, binomial trial weights, covariates, offsets and fold-based penalty
selection. Failed fits retain diagnostic status; ordinary prediction returns
NA for them.

The penalty uses normalized training locations. The infinite-penalty limit is
quadratic. Extrapolation holds the curve at its boundary value while retaining
covariate and offset effects. Ridge stabilization changes the objective when
enabled. Consult the function help for backend controls and convergence limits.

Both backends target the same objective and retain convergence diagnostics.
The banded backend uses a compact representation suitable for thousands of
observations along one scalar predictor. The dense backend remains useful for
small problems and independent numerical comparisons. Neither backend turns
the method into a multivariate smoother.

`assess.logistic.trend.filtering()` tests constant probability using outcome
permutations and measures predictive improvement with nested cross-validation.
Likelihood is the default test statistic; absolute deviation and total variation
are also reported and can be tested. Its independence, tuning and failed-fit
requirements are described in the assessment help and validation record below.

## Usage and implementation

- [Function guide](../../../vignettes/function-guide.Rmd),
  [worked vignette](../../../vignettes/logistic-trend-filtering.Rmd),
  [fitting help](../../../man/fit.logistic.trend.filtering.Rd) and
  [assessment help](../../../man/assess.logistic.trend.filtering.Rd).
- [Fitting R interface](../../../R/logistic_trend_filtering.R) and
  [assessment R interface](../../../R/logistic_trend_filtering_assessment.R).
- [Dense C++ solver](../../../src/logistic_trend_filtering.cpp) and
  [banded C++ solver](../../../src/logistic_trend_filtering_banded.cpp).

## Validation evidence

These records describe the examples, reference implementations, acceptance
criteria and limitations of each study. Earlier results remain historical
evidence; later solver repairs and reruns are documented separately.

| Record | What it establishes |
|---|---|
| [Banded-backend report](banded_backend_report.md) ([HTML](banded_backend_report.html)) | Objective and diagnostic contracts, dense/banded comparisons, the five original difficult custom/glmgen cases, and synthetic scaling checks. |
| [Assessment design and initial validation](assessment_plan.md) | Permutation retuning, incomplete-permutation handling, predictive assessment and validation of the inference procedure. |
| [Probability-curve summary validation](shape_assessment_validation.md) | Definitions and checks for absolute deviation, total variation and optional permutation tests. |
| [AGP projection and initialization failure investigation](projection_failure_report.md) | Two earlier numerical causes, regression fixtures and reruns of the same failed permutations. |
| [Binary solver stagnation repair](stagnation_repair_2026-11-07.md) | Later dense/banded numerical repairs and replay of saved binary failures at unchanged convergence thresholds. |

The companion `trend_filtering` repository maintains the
[solver-repair study and LaTeX report](https://github.com/pgajer/trend_filtering/tree/main/development/logistic_tf_stagnation)
and the subsequent
[binary CV rerun](https://github.com/pgajer/trend_filtering/tree/main/development/quadratic_residual_tf/practical_validation/step1_cv/binary_solver_rerun_20261107).
Those studies retain original failures, diagnostic interventions and final
reruns as separate evidence. They do not establish a general predictive
advantage for trend filtering.

## Reproducible checks

Run `make test-logistic-tf` from the package root. Its regression coverage includes
the [fitting API](../../../tests/testthat/test-logistic-trend-filtering.R),
[banded backend](../../../tests/testthat/test-logistic-trend-filtering-banded.R),
[assessment](../../../tests/testthat/test-logistic-trend-filtering-assessment.R),
[saved stagnation mechanisms](../../../tests/testthat/test-logistic-trend-filtering-stagnation.R)
and [CV penalty scaling](../../../tests/testthat/test-trend-filtering-cv-scaling.R).

The comparison runners accept explicit reference inputs and output directories:

- [Custom/glmgen comparison](../../../scripts/validate_logistic_trend_filtering.R).
- [Dense/banded comparison](../../../scripts/validate_logistic_trend_filtering_banded.R).
- [Adjusted-fit comparison](../../../scripts/validate_logistic_trend_filtering_adjusted.R).
- [Synthetic banded scaling benchmark](../../../scripts/benchmark_logistic_trend_filtering_banded.R).

Clinical reference inputs and fitted predictions are not distributed with the
package. The reports identify their provenance and the conditions of the saved
comparisons; the synthetic regression tests can be run without those inputs.
