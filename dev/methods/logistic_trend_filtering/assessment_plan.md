# Logistic trend-filtering assessment

This assessment tests a constant binary probability using a global permutation
test and separately measures predictive improvement. It uses a separate
assessment function; the fitting API and native objective remain unchanged.

Scope: independent binary, unit-weight observations, with no covariates or
offset. Reject unsupported inputs. The caller must establish independence and
prespecify the penalty path independently of outcomes. Do not claim a test of
nonlinearity against linear logistic regression, confidence bands or causality.

Fix outcome-independent balanced random folds using a local seed. Ignore input
fit fold labels because they may have been stratified using outcomes. Retune the
supplied lambda path on all data and on every outcome permutation, using the
same global tuning folds. Statistic: nonnegative twice the increase in ordinary
binomial log likelihood over the sample event rate. Use inclusive exceedances
and (1 + exceedances)/(B + 1). Preserve failed permutation records; if any fail,
return no point p-value and show the possible p-value range counting failures
at both extremes. No retries or successful-only denominator.

Independently assess prediction using outer CV, inner-only tuning, training-only
normalization and outer-training event rates for the baseline. Return per-row
predictions, fold choices and diagnostics, pooled log loss and Brier scores,
and baseline-minus-smoother improvements. Require complete outer predictions
for the smoother summary; do not silently score a supported subset. No naive
SE or confidence interval from overlapping CV folds.

Validation: independent reconstruction of the statistic and randomization
p-value; a small enumerated conditional null for calibration; RNG preservation
and reproducibility; unsupported-input and numerical-failure gating; outer-test
outcome isolation; loss reconstruction; candidate diagnostics; existing dense/
banded regression tests. Synthetic null/signal examples illustrate the two
outputs without claiming broad power or coverage. Use fixed seeds and record
actual results. Integrate help, grouped guides, test target and a short vignette
example. Full package checks follow targeted checks.

Validation used sequential numerical work with one thread and a 1 GiB memory
allocation. Targeted tests used the previously checked optimized installed
backend, followed by a current-source package check. No native source changed.
Implementation and validation are complete.

Real-data integration check after package checks: MASS::Pima.tr only (200
women), binary Yes outcome and glucose predictor, no covariates/offset/weights,
lambda = c(Inf, 10^seq(0,-4,by=-.5)), backend banded, default zero ridge,
999 permutations, five inner/outer folds, seed 9601. Reconstruct held-out
losses and outer-training baseline probabilities independently. This checks
the API on tied real predictor values; it is an illustrative analysis of
previously explored data, not a new confirmatory scientific result. Do not use
Pima.te outcomes in this assessment.

## Implementation and findings

Added `assess.logistic.trend.filtering(object, permutations=999L,
inner.folds=5L, outer.folds=5L, seed=1L, predictive=TRUE, warn=TRUE)`.
The original fitting API, native source and exact penalized objective are
unchanged. The assessment returns its newly tuned observed fit because the
input's selected penalty/folds may have depended on outcomes. It also returns
randomization statistics, full-path convergence/CV records, Monte Carlo
resolution, failure-aware p-value bounds, realized folds/seeds, and per-row
outer predictions. The point p-value is provided only for complete runs.
Predictive assessment can be disabled explicitly.

| Illustration | Observations | Permutations completed | Monte Carlo p-value | Nested-CV log-loss improvement | Brier improvement |
|---|---:|---:|---:|---:|---:|
| Constant probability 0.35, seed 9401 | 160 | 99/99 | 0.92 | -0.008740 | -0.003767 |
| Localized probability peak, seed 9402 | 160 | 99/99 | 0.01 | 0.107532 | 0.066470 |
| Pima training glucose, assessment seed 9601 | 200 | 999/999 | 0.001 | 0.105900 | 0.047063 |

Improvements are constant minus smoother loss, so positive values favor the
smoother. Log loss is mean natural-log loss per observation. Synthetic
assessments used lambda c(Inf,.1,.01,.001), no additional ridge, three inner
and five outer folds, assessment seeds 9501/9502. The signal probability is
plogis(-2+4.8*exp(-((x-.4)/.15)^2)); x is an equally spaced 160-point grid.
These are fixed workflow illustrations, not an average method ranking.
The p-values 0.01 and 0.001 are the respective Monte Carlo resolution limits,
not claims that the exact permutation tails equal those values.

Pima had 68 events and 98 distinct glucose values. Its nested-CV log loss was
0.641534 for the constant and 0.535634 for trend filtering; Brier scores were
0.224625 and 0.177562. All outer predictions were available. Independently
recomputed losses and training-only baseline probabilities agreed. No Pima
test-set outcomes were used. Numerical completion supports the implementation;
it does not make this previously explored example confirmatory.

A deliberately rare-event 12-observation fixture generated four failed
permutations among 39. The function returned no point p-value and bounds
[0.625,0.725], with incomplete outer scores left unavailable. This checks
failure handling, rather than redefining the scientific procedure after a
failed run. Increasing penalties/ridge or choosing a different fold strategy
is an analysis change, not an automatic retry in this implementation.

## Validation evidence

The focused assessment tests passed 154 expectations. They independently
reconstruct binomial likelihood differences, shuffled refits, inclusive
p-values and outer prediction losses; test held-out-outcome isolation, seed
preservation/replay, unsupported inputs and failure reporting; and compare
dense and banded assessments. Complete enumeration of the 70 labelings with
four events among eight observations gave conditional-null rejection rates
no greater than nominal at the tested levels 0.01, 0.05, 0.1 and 0.2. This small
finite-null check is not a broad simulation study of power or calibration.

A fresh complete `make check` (including examples, all package tests, vignette
rebuilding and PDF/HTML manuals) finished **Status: OK**, zero errors, warnings
or notes. Tests: 13,936 passing expectations, zero failures/warnings, one
intentional source-runner skip in the package tarball. Installed documentation
resolves 69 exports and 101 S3 methods; all three audited guides and labeled
figures are available offline. Source guide audits and their negative fixtures
passed. The new vignette permutation figure was visually inspected.

The first staging attempt started before its source copy finished; it was
discarded and is retained as incomplete-snapshot/ and incomplete-snapshot.log.
The accepted run used a complete source snapshot, verified against 276
source/help/test/vignette files before building. Packaged inputs were then
checked against the working tree in both directions, excluding the intentional
tests/migration omission. No incomplete-snapshot result was accepted.

The maintainer retains the original validation bundle outside the public
repository: targeted and full-check logs, the checked source tarball and
installation, the built vignette/figure, synthetic analysis objects, the Pima
validation script and result/score/permutation files, and session information.
Public regression checks are in
[the assessment tests](../../../tests/testthat/test-logistic-trend-filtering-assessment.R);
run them with the fitting regressions using `make test-logistic-tf`. The
[logistic trend-filtering vignette](../../../vignettes/logistic-trend-filtering.Rmd)
contains the synthetic examples. Numerical work used one thread with the local
optimized backend; full builds used the previously validated private dgraphs library,
sequential Makevars and -O2 -g0. This was correctness validation, not a runtime
benchmark. No native source was changed, and no bootstrap confidence band,
Bayesian posterior or adjusted/grouped permutation test is claimed.

## Probability-curve summaries and optional tests (2026-11-06)

The extension retains the likelihood test and predictive assessment, adds
absolute-deviation and total-variation summaries, and optionally tests those
summaries through the existing complete refit-and-permute procedure.

Conventions: absolute deviation averages over observations, preserving tied
predictor multiplicities; total variation covers the whole observed predictor
range on the probability scale. Recover each quadratic logit segment from its
endpoints and midpoint in local coordinates, then include its interior vertex.
No coarse-grid approximation, bootstrap t-test, new fitting objective or native
backend change. Both observed summaries are always returned. Optional tests
share folds, seeds and selected fits, with per-statistic failure bounds and
Holm adjustment across the requested family including likelihood. Existing
scalar fields and the original permutation table keep their likelihood meaning.

Validation plan: analytic constant/monotone/interior-turning-point curves;
independent fine-grid variation and participant-average calculations; tied
predictors; permutation-statistic reconstruction; unchanged default likelihood
and nested-CV results; dense/banded agreement; failure/tie/argument checks;
conditional-null enumeration for each statistic and the Holm family. Update
help, grouped guide, vignette and NEWS. Run targeted tests followed by a full
package check. This is implementation validation, not a general power study.

Validation used one compute thread and a 1 GiB memory allocation, with no
competing numerical workloads. Targeted tests reused the verified optimized
backend (source and DLL hashes matched the projection-fix record), followed by
an optimized package build. The maintainer retains the original validation
bundle outside the public repository. Implementation and validation are
complete. The focused group passed 342 expectations and the full package suite passed 14,031
expectations (one intentional tarball/source-runner skip). Full `make check`
had no errors or warnings and one environment note about V8 being hidden by
the overridden user-library path. Restoring that path and rerunning the
documentation checks, including PDF/HTML manuals and math rendering, finished
Status: OK. The original complete test and vignette results were retained.
An independent comparison against the pre-extension source found identical
legacy likelihood results, fitted objects, folds, seeds and prediction outputs.
Default and extended runs both used 13 assessment refits in the comparison.
See [the validation record](shape_assessment_validation.md) for scope and evidence.
