# Logistic trend-filtering probability summaries and tests

This extension adds two probability-curve summaries to
`assess.logistic.trend.filtering()` while preserving its default likelihood
test, original scalar result fields, complete tuning procedure, convergence
requirements and separate nested-CV predictive assessment. The native fitting
objective and C++ implementations are unchanged.

## Definitions and inference

Absolute deviation is the mean of `abs(p.hat(x) - mean(y))` over observations.
Repeated predictor values retain their participant counts. It describes the
sampled population rather than an interval with uniform predictor weighting.
Total variation sums absolute probability changes across the full observed
predictor range, including endpoints, knots and interior turning points.

The logit is quadratic on each interval between knots. Its endpoint and
midpoint values determine that quadratic in interval-relative coordinates;
an interior derivative root identifies its turning point. The inverse logit
is monotone, so the same points partition the probability curve into monotone
pieces. Summing their endpoint probability differences computes variation up
to floating-point precision without a coarse grid or unstable reconstruction
of global basis coefficients. Intervals without a representable midpoint use
their two distinct endpoints. Nonfinite arithmetic is recorded as a summary
failure rather than converted to a zero statistic.

Both observed summaries are always returned. Optional `additional.tests`
selects `absolute.deviation`, `total.variation`, or both. Each requested
statistic is calculated from the same tuned fit on each existing permutation.
The inclusive plus-one test, numerical tie tolerance and missing-statistic
bounds are applied separately. No resampled differences are treated as new
observations in a t-test. Holm adjustment covers likelihood and the requested
optional statistics; it does not cover other predictors or outcomes. Incomplete
families have no Holm p-values. The original scalar p-value always remains the
individual likelihood p-value.

## Validation

The focused test group passed 342 expectations: 52 fitter, 52 banded-backend
and 238 assessment expectations, without failures, warnings or skips. Checks
include analytic constant and monotone curves, an interior quadratic peak
missed by knot-only evaluation, a piecewise curve with multiple turns, affine
predictor transformations, participant weighting at tied predictors, and
independent fine-grid reconstruction of variation for observed and permuted
fits. Optional p-values and Holm adjustment are reconstructed independently.

An independent script loaded the pre-extension assessment source from commit
`b914563` alongside the current implementation, using the checked installation
for fitting. Legacy likelihood statistics, p-values/bounds, fitted objects,
permutation tables, folds, seeds, prediction scores and row-level predictions
were identical. Observed + nine shuffled + three outer-training refits totaled
13 calls in each of the original, new-default and new-extended runs.

Full `make check` included all examples, all package tests, vignette rebuilding
and both manuals. It completed with no errors or warnings; 14,031 test
expectations passed and one source-only test-runner check was intentionally
skipped in the tarball. Its sole NOTE was that V8 was unavailable for HTML math
rendering: the private `R_LIBS_USER` setting had hidden the installed user-library
copy. A subsequent check with the user library visible passed PDF and HTML
manual checks, including math rendering, with **Status: OK**. That focused
recheck used `--no-install --no-tests --no-examples --no-vignettes`; it supplements
the full run rather than substituting for its tests. Installed help resolves
all 69 exports and 101 S3 methods, and the three audited guides have their
figures available offline.

All 70 allocations of four events among eight fixed locations were enumerated.
At levels 0.01, 0.05, 0.1 and 0.2, the exact conditional-null rejection fraction
did not exceed the nominal level for any individual statistic or the Holm
family. This finite-null check is not a broad power or calibration study.
Further tests cover failed observed/permuted fits, a deliberate variation-only
arithmetic failure, exact ties, malformed arguments and dense/banded agreement.

The first tied-predictor test fixture accidentally gave every predictor group
the same response mean and therefore could not distinguish participant from
unique-location averaging. It was replaced by a heterogeneous fixture; the
implementation was unchanged. The initial failing test log is preserved.

The rebuilt vignette uses the two existing synthetic examples (160 independent
binary observations each, 99 shuffles, prespecified penalty path, seeds and
fold counts). Its likelihood results are unchanged. The new outputs are:

| Example | Absolute deviation | Total variation | Individual p-values: likelihood / deviation / variation | Holm p-values |
|---|---:|---:|---|---|
| Constant probability | 0.0221 | 0.1677 | 0.92 / 0.92 / 0.76 | 1 / 1 / 1 |
| Localized peak | 0.2705 | 1.8832 | 0.01 / 0.01 / 0.02 | 0.03 / 0.03 / 0.03 |

These are illustrations on fixed datasets, not evidence that one statistic
has greater average power. Total variation can exceed one because it
accumulates multiple rises and falls.

## Reproduction and environment

Use `make test-logistic-tf`, `make check`, `make update-api`, and
`Rscript scripts/test_documentation_checks.R`. All numerical work used one
thread. Targeted tests reused the verified optimized backend; the full check
uses `-O2 -g0` and sequential compilation.

At the time of this validation, the default installed dgraphs lacked an
intrinsic-distance header required by an existing geosmooth module. The full
build therefore used a previously validated development installation through
`R_LIBS` as well as `R_LIBS_USER`; setting only the latter left the default
library first. The relevant header was verified identical to authoritative
local dgraphs source. Both initial dependency-related build failures are
preserved. This was an environment correction, not a change to package
dependencies or fitting algorithms. Reproduction requires the dependency
versions declared in `DESCRIPTION` and access to the optional documentation
tools. The historical development-library workaround is not a substitute for
final release checks with published dependencies.

The maintainer retains the original scripts, logs, built vignette, source
hashes and baseline comparison outside the public repository. Public checks
are in [the assessment tests](../../../tests/testthat/test-logistic-trend-filtering-assessment.R);
the [vignette source](../../../vignettes/logistic-trend-filtering.Rmd) contains
the synthetic examples.
The package tarball was compared against 228 current source, help, test and
vignette files (DESCRIPTION compared as normalized DCF fields). The grouped
guide and API appendix audit passed, including its negative fixtures.
