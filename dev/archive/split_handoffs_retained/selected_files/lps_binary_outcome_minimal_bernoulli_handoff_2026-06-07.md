# LPS Binary-Outcome Minimal Bernoulli Mode Handoff

Date: 2026-06-07

## Request

Please audit the new minimal Bernoulli/Brier mode for `fit.lps()`.

This is intentionally not a logistic LPS implementation.  It is the first,
minimal binary-outcome path:

\[
Y_i\in\{0,1\},\qquad
p(x)=\mathbb E(Y\mid X=x)=\Pr(Y=1\mid X=x),
\]

with the existing local least-squares LPS machinery used as a conditional
expectation estimator.  Bernoulli mode validates the response, reports
probability diagnostics, and clips response-scale fitted probabilities to
\([0,1]\).

## Files Changed

- `/Users/pgajer/current_projects/geosmooth/R/lps.R`
- `/Users/pgajer/current_projects/geosmooth/man/fit.lps.Rd`
- `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R`

Related design note:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_binary_outcome_design_note_2026-06-07.md`

## Implementation Summary

### New API argument

`fit.lps()` now has:

```r
outcome.family = c("gaussian", "bernoulli")
```

This argument was placed at the end of the signature to reduce risk for
existing positional callers.

### Gaussian/default behavior

The default remains:

```r
outcome.family = "gaussian"
```

For Gaussian mode, fitted values and predictions remain ordinary numeric LPS
outputs.

### Bernoulli mode

For:

```r
outcome.family = "bernoulli"
```

the implementation:

1. validates that `y` contains only `0` and `1`;
2. keeps the same local least-squares fitting and CV machinery;
3. stores the unmodified least-squares conditional-expectation estimates in
   `fitted.values.raw`;
4. stores clipped probability-scale fitted values in `fitted.values`;
5. adds `cv.brier.observed = cv.rmse.observed^2` to the candidate CV table;
6. records `probability.diagnostics`, including raw range, clipped range,
   fraction below 0, fraction above 1, raw Brier score, clipped Brier score,
   and clipped log loss;
7. extends `predict.lps()` with:

```r
type = c("response", "raw")
```

For Bernoulli fits, `type = "response"` returns clipped probabilities and
`type = "raw"` returns the raw local least-squares predictions.

## Intended Semantics

For Bernoulli mode, the raw model is still:

\[
\hat p_{\rm raw}(x)\approx \mathbb E(Y\mid X=x).
\]

The reported response-scale probability is:

\[
\hat p_{\rm response}(x)
=
\min\{1,\max\{0,\hat p_{\rm raw}(x)\}\}.
\]

The Brier score is:

\[
\operatorname{Brier}
=
\frac{1}{n}\sum_{i=1}^{n}(y_i-\hat p_i)^2.
\]

Because `cv.rmse.observed` is the square root of the mean squared CV error,
the candidate-level Brier score is reported as:

\[
\operatorname{CVBrier}
=
(\operatorname{CVRMSE})^2.
\]

The clipped log loss is reported as a diagnostic:

\[
-\frac{1}{n}\sum_i
\left[
y_i\log(\tilde p_i)+(1-y_i)\log(1-\tilde p_i)
\right],
\]

where \(\tilde p_i\) is clipped away from exactly 0 and 1 internally for the
log calculation.

## Validation Already Run

The following commands passed:

```sh
make document
Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R")'
Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge1-r-smoothers.R")'
Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ps-lps.R")'
git diff --check
```

Full `make test` was not run yet, partly to avoid adding unnecessary load while
the S3R-expanded run is underway.

## Specific Audit Questions

Please audit the following points:

1. Is the minimal Bernoulli mode correctly described as a Brier-risk
   conditional-expectation mode rather than a logistic/Bernoulli-likelihood
   model?

2. Is the object contract acceptable?
   In particular:
   - `fitted.values.raw` contains raw least-squares conditional-expectation
     estimates;
   - `fitted.values` contains clipped response-scale probabilities for
     Bernoulli mode;
   - Gaussian mode remains unchanged.

3. Is `predict.lps(type = c("response", "raw"))` the right API for exposing
   clipped probabilities versus raw predictions?

4. Is it acceptable that candidate selection still follows
   `cv.rmse.observed`, with `cv.brier.observed` recorded as its square, or
   should Bernoulli mode explicitly select on a named Brier column even though
   the ordering is identical?

5. Are the probability diagnostics sufficient for the minimal mode?
   If not, what must be added before this is used in binary-outcome experiments?

6. Are there compatibility risks from changing `fitted.values` to clipped
   probabilities only in Bernoulli mode?

7. Are the tests adequate for the first implementation?
   The new test checks:
   - 0/1 validation;
   - raw Bernoulli predictions match Gaussian predictions on the same `0/1`
     data;
   - response predictions are clipped to `[0,1]`;
   - `cv.brier.observed = cv.rmse.observed^2`;
   - Brier/log-loss diagnostics are finite.

8. Should a single-class binary response be a warning, as currently implemented,
   or should it be an error?

9. Should `lps.backend.diagnostics()` include additional Bernoulli probability
   fields, or is `outcome.family` plus selected `cv.brier.observed` enough for
   backend diagnostics?

## Requested Output

Please write an audit report with:

- verdict: accepted, accepted with minor comments, or blocked;
- any correctness or API-contract issues;
- any required test/documentation additions;
- recommendation on whether this minimal Bernoulli LPS mode is ready for
  binary-outcome smoke experiments;
- recommended next step toward binary PS-LPS or logistic LPS.
