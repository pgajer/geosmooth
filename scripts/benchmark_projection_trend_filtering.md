# Synthetic projection-pursuit trend-filtering benchmark

`benchmark_projection_trend_filtering.R` compares Gaussian mean and binary
probability recovery on archived quadratic-residual trend-filtering examples.
It uses the original coordinates, responses, truths and first CV partitions.
The archive must be supplied separately; it is not included in geosmooth.

The selected examples contain 14 Gaussian and four binary datasets, with 125
or 144 observations and two or three predictors. They cover quadratic, squared
hinge, localized bump and sinusoidal-interaction surfaces, regular and jittered
designs, and six later hinge/bump examples with uneven density or a third
coordinate. These examples assess low-dimensional function recovery. They do
not establish performance with many predictors.

## Requirements and preparation

Install `geosmooth`, `dgraphs`, `Matrix`, `Rcpp`, `glmnet`, `digest` and
`jsonlite`. Source-checkout use additionally requires `pkgload`. Set
`GEOSMOOTH_SOURCE` and `DGRAPHS_SOURCE` to use already compiled source checkouts;
otherwise the script loads installed packages. Compile native package code with
optimization before timing. Preparation compiles the archived residual solver
once with `-O2`; fitting workers load that saved binary.

The supplied study directory must contain:

- `results/main_{design}_{family}_{surface}_6101.rds`, with the 12 original
  combinations: regular/irregular Gaussian quadratic, hinge, bump and interaction;
  regular/irregular binary hinge and bump.
- `practical_validation/step4_confirmation/planning/proposed_scenarios.csv`,
  identifying the six later scenarios and their first seeds.
- The corresponding archived objects under
  `practical_validation/step4_confirmation/results/problems/`.
- `residual_solver.cpp`, `quadratic_residual.R`, `null_face_polish.R`,
  `projector_variants.R` and `certificate_checker.R` under that study's
  `frozen_sources/` directory.

The first command copies the selected input objects and research solver sources,
records hashes, compiles the research solver, and constructs the geometric
operators. Choose an output directory outside the package checkout.

```sh
Rscript scripts/benchmark_projection_trend_filtering.R prepare STUDY_ROOT OUTPUT
```

## A bounded pilot configuration

Save an R list to `CONFIG_RDS`, for example:

```r
config <- list(
    name = "pilot", workers = 4L, repeats = 1L,
    memory.gib = 8, task.seconds = 900,
    methods = c("constant", "elastic_net", "quadratic", "knn",
                "coordinate_tf2", "fixed_bank_tf2", "learned_tf2",
                "classical_ppr", "complete", "central_matched", "graph"),
    nterms = c(0L, 1L, 2L), tf.ratios = c(1e-4, 1e-3, 1e-2, .1, 1),
    rho = .001,
    control = list(starts = 1L, sparse.directions = 4L,
                   dense.directions = 4L, refinement.passes = 1L,
                   refinement.proposals = 8L, max.sweeps = 200L),
    legacy.lambda = c(.01, .03, .1, .3, 1, 3, 10, 30, 100, Inf),
    legacy.iterations = 1000000L,
    knn = c(5, 15, 30, 60), quadratic.ridge = c(0, .001, .01, .1, 1),
    glmnet.ratios = c(1, .1, .01, .001), ppr.terms = c(1L, 2L)
)
saveRDS(config, "CONFIG_RDS")
```

An optional `datasets` character vector restricts the run to named input IDs.
Every run requires a new `name`; previous runs are preserved. One to three CV
repeats are supported. Later-study folds are reused; for the original examples,
the second and third partitions use the original seed plus 300000 and 400000.
These additional partitions are part of the current procedure, not a claim of
exact reproduction of historical tuning.

```sh
Rscript scripts/benchmark_projection_trend_filtering.R run OUTPUT CONFIG_RDS
Rscript scripts/benchmark_projection_trend_filtering.R summarize OUTPUT RUN_NAME
```

The worker queue uses forked R processes, so this runner requires a Unix-like
system. Each worker uses one numerical thread. `memory.gib` limits admission
using summed coordinator/worker RSS; it is not a hard process memory limit.
Shared pages can be counted more than once. `task.seconds` is a wall-clock limit
for a complete dataset/method task, including CV and full refitting. A task
exceeding it is stopped and recorded as `resource_limit`; completed fold
checkpoints remain available. Preparation is timed separately.

## Methods and tuning

The TF2 models use geosmooth's piecewise-quadratic order-2 trend filter. Gaussian
components model the mean; binary components add on the logit scale. Every
training split repeats preprocessing, direction selection and fitting. Predictor
centering plus a common scale preserves the supplied Euclidean geometry.

- **Coordinate TF2:** jointly fits all coordinate directions, with an
  intercept-only alternative.
- **Fixed-bank TF2:** selects components from coordinate and seeded random
  directions without refining them.
- **Learned TF2:** starts with that bank and refines directions. With one start,
  the fixed-bank and learned fits use identical initial banks at matched seeds.
  Additional starts do not guarantee matched later banks because refinement
  consumes random draws.

TF2 tunes component count and penalty ratio, keeping the declared component
ridge fixed. The ratio multiplies a training-only reference penalty: the maximum
certified single-direction quadratic saturation penalty over the initial bank.
This is a scale reference, not a multi-component saturation certificate.
`Inf` explicitly fits quadratic components; it does not mean a constant model.
The reference is recomputed for full refitting. Finite reference fits must agree
with the quadratic limit within `1e-6` on the link scale. Failed reference
directions and candidate fits are recorded without coordinate jitter or rounding.

Other regression methods are the training mean/probability, Euclidean kNN,
full quadratic regression with a ridge grid, elastic net, and classical
projection pursuit (`stats::ppr`, Gaussian only; both supersmoother and spline
options). Polynomial expansion and coefficient scaling use training rows only.
Elastic net uses alpha 0, 0.5 and 1 and fractions of the first penalty returned
by each training fit's `glmnet` path. Its alpha-0 reference follows glmnet's
ridge-path convention. Penalty units differ across methods.

The three geometric comparators are complete quadratic-residual TF, its matched
central-residual version, and graph TF2. The two residual operators share
supports of size twice the quadratic polynomial dimension (maximum six times
that dimension), with whole distance ties. Graph neighborhoods have twice the
predictor dimension neighbors, are symmetrized, and have unit-normalized penalty
rows. The research solver uses active-set polishing and independent KKT checks.
It does not silently invoke a larger recovery budget. Finite penalties for these
summed-loss solvers are multiplied by training sample size divided by full sample
size during CV.

## Interpreting outputs

All methods tune against identical held-out responses. Gaussian CV uses squared
error; binary CV uses log loss, clipping probabilities to `[1e-8, 1-1e-8]` for
scoring. A candidate is eligible only if every fold fit passes its checks.
Selection uses pooled observation loss across repeats. A failed selected full
refit remains a failure; another candidate is not substituted after scoring.

This is **known-location recovery**: the geometric operators use all supplied
coordinates and mask held-out responses with zero weights. Regression fits use
training rows to build their curves, then predict the held-out coordinates.
Final fits use all responses and are scored against the archived noise-free
means or probabilities at those same locations. This is not independent test-set
prediction error.

Outputs include `scores.csv`, the task ledger, full selected fits and tuning
grids, fold predictions and numerical diagnostics, training penalty references,
source/binary hashes, package versions, and thread settings. Report Gaussian
truth RMSE; binary probability RMSE, expected log loss and excess Brier loss;
failure rates; selected complexity and grid endpoints; and computational cost.
The boundary diagnostic uses locations with any absolute coordinate above 0.75.
Anchor and operator preparation costs are separate from method-task elapsed
time. Queue elapsed times additionally include collection delay.

One replicate per scenario and one CV repeat support feasibility checks and
descriptive comparisons. They do not support Monte Carlo confidence intervals,
a universal method ranking, or claims about high-dimensional regression.
Forest and boosting comparisons, independent-location prediction, larger
direction searches, and fresh-seed confirmation require separate experiments.
