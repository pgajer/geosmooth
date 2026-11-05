# Banded order-2 logistic trend filtering

## Purpose and use

This backend supports one-dimensional nonlinear outcome analyses with thousands
of observations, including analyses within merged AGP community-state groups.
One-dimensional refers to the scalar predictor, not sample count; this is not
multivariate graph smoothing. Linear covariates and offsets remain available.

```r
fit <- fit.logistic.trend.filtering(
    marker, binary_outcome, lambda = c(1, .1, .01, .001),
    backend = "banded", lambda.selection = "cv", foldid = subject_fold
)
fit$diagnostics
fit$cv.table
predict(fit, new_marker)
```

The example path is explicit, not a universal tuning recommendation.
`backend="auto"` chooses banded above 256 distinct predictor values or when the
dense workspace estimate exceeds its guard. `backend="dense"` retains the
small-problem reference. Both minimize the same summed weighted binomial
likelihood plus the L1 third-difference penalty and optional nuisance/centered-
curve ridge, on the same normalized predictor locations. No jitter, binning,
knot thinning or additional estimator ridge was introduced. Exact ties retain
observation-level covariates/offsets. CV and boundary predictions preserve the
existing contracts.

## Structure and diagnostics

The falling-factorial basis is a quadratic polynomial plus functions
`0.5*(u-t[j-1])*(u-t[j])*I(u>t[j])`. Four consecutive functions have quadratic
polynomial tails. Cancelling their three polynomial coefficients yields a
locally supported column. These columns and boundary functions give an
invertible reparameterization of the working-set span, with a fixed-bandwidth
curve Hessian. A small Schur complement handles nuisance predictors and curve
centering. A Newton step updates all working-set coefficients jointly.

Every stopping check evaluates the gradient for **all original knot
coefficients**, using shifted suffix moments. Omitted coefficients are exactly
zero; violating knots are admitted and can leave at orthant boundaries. An
inexact restricted solve is allowed when omitted-knot violations are much
larger, but final acceptance always uses the unchanged global KKT gates.

Default acceptance requires finite values, mean-loss stationarity <=1e-9,
L1 dual feasibility and complementarity <=1e-10. These are approximate KKT
conditions, not a separately computed dual objective gap or a proof of finite
MLE existence. Null-space separation detection is retained; a pure outcome at
a free knot also supplies a witness for zero penalty without curve ridge.
Iteration limits and numerical failures remain explicit, and ordinary
prediction returns NA for failed fits.

Compensated likelihood/penalty sums and a machine-precision line-search allowance
prevent rounding-scale objective changes from stalling Newton steps. Neither
changes the estimator or final tolerances. Diagnostics record backend, working
knots and initialization iterations; each fit also records the last line-search
step and directional derivative. Initialization uses the dense solver only on
three polynomial columns and optional covariates, never the full knot basis.

Storage is linear in observations and knots for fixed covariate count and path
length. Fitting and prediction avoid observation-by-full-knot and full-knot-
square dense arrays. Runtime still depends on working-set changes, sorted
suffix scans, covariate count and convergence. Difficult weak penalties can
exhaust the budget. The workspace guard estimates solver allocations, not RSS.

## Frozen reference comparisons

The original 30 ZAPPS/PreSSMat immune-marker datasets were each fitted at the
same seven penalties (1 through 0.001), with identical rows, zero extra ridge
and no retuning. Agreement required maximum probability difference <=0.001
(0.1 percentage point), absolute objective difference per observation <=1e-5,
and successful convergence.

All **210/210 dense/banded comparisons pass** and all 210 banded fits
converge. Maximum probability difference is 3.09966496e-08; maximum
absolute objective difference per observation is 9.98933577e-11.
Maximum stationarity is 8.85486538e-10, with zero complementarity. Independent
reconstruction using the saved glmgen difference operator changes the summed
objective by at most 8.399373e-07. On the saved 150-point prediction
grids, maximum difference from the original custom implementation is
1.21007794e-05, below the same 0.001 gate.

All five original lambda=0.001 disputes pass against dense. Corrected glmgen
remains an imperfect independent reference; reproducing its discrepancies is
not the desired outcome.

| Dataset / marker | Banded vs dense maximum probability difference (percentage points) | Banded vs corrected glmgen (percentage points) | Banded stationarity |
|---|---:|---:|---:|
| ZAPPS union / IL-6 | 1.00274e-06 | 0.3587083 | 7.37257e-17 |
| PreSSMat Li Lc / IL-1a | 5.289243e-07 | 0.1175587 | 4.97737e-14 |
| PreSSMat Li Lc / IL-1b | 1.437286e-07 | 3.257049 | 9.35991e-17 |
| ZAPPS Li Gv / IL-6 | 1.059653e-07 | 2.802567 | 3.07806e-12 |
| ZAPPS Li Gv / MIP-3a | 7.034116e-07 | 0.7095655 | 2.03824e-10 |

The **30/30 saved adjusted full-data fits** also pass, preserving the original
age/assay transformations and explicit ridge settings. Maximum probability
difference is 1.33193121e-06; maximum absolute objective difference per
observation is 6.98646528e-13. These results do not repair or replace
original failed/unsupported nested-validation attempts.

## Measured synthetic scaling

Each optimized installed-package run used one thread and four fixed penalties
(1, 0.1, 0.01, 0.001). Uniform scalar locations and a sinusoidal probability
curve define the smooth binary examples. Additional cases have rare outcomes
or 100 exact predictor values, with two covariates, offsets and explicit ridge.
Prediction uses an equally sized new grid. Seeds, generated data, source/DLL
hashes, sessions and raw `/usr/bin/time -l` logs are preserved.

| Scenario | Observations | Distinct predictor values | Converged | Fit time (s) | Prediction (s) | Process peak RSS (MiB) |
|---|---:|---:|---:|---:|---:|---:|
| Smooth binary | 1,000 | 1,000 | 4/4 | 0.022 | 0.001 | 104.5 |
| Smooth binary | 4,000 | 4,000 | 4/4 | 0.131 | 0.002 | 106.8 |
| Smooth binary | 24,000 | 24,000 | 4/4 | 1.117 | 0.009 | 127.1 |
| Rare binary, adjusted | 4,000 | 4,000 | 4/4 | 0.140 | 0.003 | 108.7 |
| Exact ties, adjusted | 4,000 | 100 | 4/4 | 0.077 | 0.002 | 108.2 |

All 20 fits passed the same KKT gates and all predictions were finite. These
are measured synthetic examples, not actual AGP analyses or worst-case runtime
guarantees. Concurrent AGP embedding workers were present. The user authorized
up to three threads and 6 GiB for this task; each worker used one thread.

## Preserved failures and tests

The initial tied-data stress test correctly returned iteration-limit failures
at weak penalties. Admission-timing changes improved one fit but left another
stalled. Independent reconstruction confirmed a correct Newton direction with
expected objective improvement at summation-rounding scale. Compensated sums
and the rounding allowance resolved the same case without changing its inputs,
seed, penalties, ridge or final KKT gates. Failed/intermediate attempts remain
separate from accepted `scaling-verified` results.

All 93 focused assertions pass. The tied-data regression independently
reconstructs the global gradient, including omitted knots. Other tests cover
weighted binomial equivalence, covariates/offsets, exact and near ties, off-grid
prediction, CV isolation, separation, iteration failure, automatic backend
selection and workspace guarding.

## Evidence and reproduction

- [Dense/banded comparison table](/Users/pgajer/.codex/private/geosmooth/logistic-trend-filtering/banded-20261105/reference-verified/comparison.csv)
- [Comparison summary](/Users/pgajer/.codex/private/geosmooth/logistic-trend-filtering/banded-20261105/reference-verified/summary.json)
- [Input/source/DLL hashes](/Users/pgajer/.codex/private/geosmooth/logistic-trend-filtering/banded-20261105/reference-verified/hashes.csv)
- [Adjusted comparison](/Users/pgajer/.codex/private/geosmooth/logistic-trend-filtering/banded-20261105/adjusted-verified/comparison.csv)
- [Scaling runs](/Users/pgajer/.codex/private/geosmooth/logistic-trend-filtering/banded-20261105/scaling-verified)
- [Development and failure evidence](/Users/pgajer/.codex/private/geosmooth/logistic-trend-filtering/banded-20261105)
- [Implementation plan](sparse_backend_plan.md)

Compile optimized once from the package root, or install the current source in
an isolated library. Run `scripts/validate_logistic_trend_filtering_banded.R`
with the frozen reference root and a new output directory; its optional third
argument selects that library. The adjusted validator accepts `banded` as its
fourth argument. The benchmark runner takes sample size, scenario and a new
output directory plus an optional library. Wrap it in `/usr/bin/time -l` for
process RSS. Never overwrite previous outputs. `make test-logistic-tf` runs both
test files. Neither backend requires Python or a glmgen runtime.

The final `make check-fast` completed with zero errors, zero warnings and one
NOTE about public documentation links not yet available on the deployed site.
It built and rebuilt the vignettes and checked installation, compiled code,
namespace/S3 registration and documentation. Examples and package tests are
excluded by that fast target; the 93 focused assertions and numerical reference
checks were run separately against the final optimized isolated installation.
API coverage checks pass for 68 exports and 100 S3 registrations. The full
source/input/DLL hash manifest was rechecked: all 187 entries match.
[Final QA logs](/Users/pgajer/.codex/private/geosmooth/logistic-trend-filtering/banded-20261105/qa-verified)
preserve those checks and the final build/install evidence.

The benchmark host was an Apple M4 Max with 64 GiB physical RAM; each benchmark
used one numerical thread, within this task's three-thread/6-GiB allocation.
Windows checks, the entire existing test suite and new clinical AGP analyses
are outside these completed comparisons. Gaussian minimax guarantees are not asserted for this model.
