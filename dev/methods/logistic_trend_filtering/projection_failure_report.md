# Numerical failures in the AGP logistic trend-filtering pilot

## What failed and why it matters

The first pure *Bacteroides dorei* AGP pilot requested 1,999 outcome
permutations for each of 15 assessments (nine positive-abundance tests and six
zero-retaining sensitivity tests). Forty-seven statistics were unavailable;
six of nine primary assessments consequently lacked a point p-value. Original
results were preserved, and the same shuffled responses and folds were used to
diagnose the failures. Failed permutations were never replaced or discarded.

There were **two numerical causes**, rather than 47 identical projection
exceptions. Twenty-six failed statistics involved a compact projection exception
(one also recorded nonconverged CV candidates). The other 21 involved the
quadratic initializer exhausting its iteration limit, 13 on the full data and
eight in a CV training fold. An empty top-level error message did not imply
absence of a numerical failure: the lower-level diagnostics identify it.

## Cause 1: normal equations on nearly parallel boundary columns

The compact basis leaves its final three columns as truncated quadratics. When
three active knots are close, these columns can be nearly parallel over the
long right-hand tail. For the saved IBD/*B. dorei* permutation 1,684, inner
training fold 2, the active normalized knots are approximately 0.2589463,
0.2589552 and 0.2592235. The weighted design has 4,671 rows and six columns.
Its largest/smallest singular values are 0.6323327 and 5.538508e-10, a condition
number of about 1.14e9. The normal equations square that condition number. Replaying and capturing all
26 original projection-exception designs gives weighted-design condition numbers
from 2.33e8 to 8.38e9, confirming the same instability throughout that group.

The old projection accumulated `B' W B` and factored it with an undamped banded
LDL decomposition. Finite-precision accumulation/elimination lost its final
positive pivot and raised `Singular compact-basis projection.` This is not
mathematical singularity or a separation certificate. Recomputing the Gram
matrix from the captured basis with 80-digit decimal arithmetic gives strictly
positive LDL pivots; the final pivot is approximately 2.08209e-18. A conventional
double-precision eigensolve instead gives a spurious negative minimum eigenvalue
near -8.09e-18.

The fix computes the **same weighted least-squares projection** by column-scaled,
row-wise Givens QR. Rows are processed in nondecreasing right support, preserving
the four stored upper diagonals. This avoids the squared condition number and
retains linear workspace. It adds neither a ridge nor knot thinning, and does
not delete columns or alter the falling-factorial span. Newton steps, the
original objective, and the full-knot stopping tests remain unchanged.

A public synthetic regression fixture uses 28 locations with terminal knots
0.9, 0.90001 and 0.90002, fractional responses and an unpenalized candidate.
The old implementation throws; the corrected banded path converges and agrees
with the independent dense path. Weighted, tied and reversed rows are also
checked.

## Cause 2: objective-summation error stalls a valid Newton step

The banded solver initializes from a three-column quadratic logistic fit using
the dense solver. Its ordinary sequential likelihood sum can accumulate enough
roundoff over thousands of observations to reject a valid near-optimal Newton
step. The original initializer's convergence flag then prevents every candidate
on that path from being accepted.

For IBS/*A. hadrus*, zeros retained, permutation 318, the recorded iteration-4
stationarity is 3.66929e-9 and the Newton directional derivative is -9.85892e-17.
The computed objective change for the full step is instead +2.77556e-15.
Subsequent steps repeatedly shrink, and the initializer exhausts 1,000 iterations
with stationarity approximately 1.8132e-9. The default threshold is 1e-9.
This is a loss-accumulation/line-search failure, not a lack of cases, separation,
or insufficient flexibility of the smoother.

The fix uses compensated accumulation for the dense objective's likelihood,
ridge and barrier contributions. It preserves the existing rounding allowance,
stationarity/complementarity thresholds and maximum iteration count. The same
code serves the small shared initializer and the dense reference solver.

A second public regression fixture has 6,000 binary records in three predictor
groups, with case counts 115, 300 and 600 out of 2,000 each. The original solver
stalls at 1,000 iterations, stationarity 3.049657e-8 and 17,979 backtracks. The
corrected solver converges in six iterations, without backtracking, at
stationarity 1.763177e-14, and recovers the known probabilities
0.0575, 0.15 and 0.30.

## Validation and rerun policy

With both fixes, **all 47 exact originally failed shuffled assessments complete**
with unchanged seeds, folds, penalty path and convergence settings. QR alone
recovers the 26 projection-exception cases and leaves the other 21 unavailable,
providing an isolated check of the two failure mechanisms.

The frozen 30-dataset/seven-penalty comparison gives **210/210 converged banded
fits and 210/210 dense-agreement passes**, including all five historical difficult
lambda=0.001 cases. Maximum dense probability difference is 3.10e-8; maximum
absolute objective difference per observation is 9.99e-11. Maximum stationarity
is 8.86e-10, with zero complementarity. The maximum difference from saved custom
prediction grids is 1.22e-5. Corrected glmgen remains an imperfect reference;
its known disagreements are not a target for the new solver.

The logistic trend-filtering test group passes all **258 expectations**, including
the two new synthetic regressions. Twenty-four observed/permuted control refits
on the four unaffected assessments also reproduce their statistics within
1.42e-10. Several penalty labels change when candidates fit the same unpenalized
quadratic; such label changes are recorded separately from numerical fit changes. All 15 AGP assessments are rerun, rather than inserting 47 new statistics into
old objects. The four originally complete tests also contained individually
failed candidates; recovering those candidates can change the selected fit on
a previously complete shuffle. Each uses its original 1,999
permutation seeds and outcome-independent folds; affected heldout models are
also recomputed with their original split and tuning seeds. All final assessments use the same corrected implementation. Scientific conclusions are reported separately from the original pilot after
the reruns finish. A complete shuffle can still have excluded an individual
nonconverged penalty candidate; when that candidate is recovered, its selected
penalty and statistic may change. Consequently, merely inserting the 47 missing
statistics into old assessment objects would not reproduce the corrected fitting
procedure. Original/corrected comparisons record candidate-selection changes,
statistics and exceedance changes, observed curves and heldout predictions.

Evidence is private because it includes individual-level AGP and reference
observations. The reproducible public fixtures are in
[the fitter tests](../../../tests/testthat/test-logistic-trend-filtering.R) and
[the banded-backend tests](../../../tests/testthat/test-logistic-trend-filtering-banded.R).
Run them with `make test-logistic-tf`. The maintainer retains the root-cause
artifacts, optimized installation, replay records, reference comparisons and
corrected pilot bundle outside the public repository. The original bundle is
preserved separately and unchanged. Replaying the individual-level cases
requires access to those original inputs.

## Limits of the correction

The finite iteration budget and full-knot acceptance gates remain in force.
Some individual penalty candidates can still reach the working-set iteration
limit and remain explicitly nonconverged. They are not silently accepted or
assigned relaxed tolerances. A complete assessment requires an eligible candidate
in every required refit and a statistic for every requested shuffle; it does not
assert convergence of every candidate. The corrected pilot reports candidate
failures separately from missing permutation statistics. This work resolves the
two causes of the original 47 missing statistics and does not claim universal
convergence for every possible weak-penalty fit.

## Final complete rerun

All **15/15 assessments** were recomputed with the corrected optimized build,
with **29,985/29,985 permutation statistics available** and all nine heldout
prediction evaluations complete. Every seed, fold, input and heldout split was
verified against the original. All 47 originally missing statistics were
recovered; no permutation was replaced.

Two positive-abundance tests reject after Holm adjustment over the original
15-test family: *A. hadrus*/IBS (raw p=0.002, adjusted p=0.026) and
*B. dorei*/obesity (raw p=0.0035, adjusted p=0.042). Their exact binomial
Monte Carlo tail intervals both span the respective Holm boundary, so the
adjusted decisions remain sensitive to Monte Carlo variation. The two detection
findings remain *F. prausnitzii*/IBD and /IBS. No independent heldout log-loss
interval excludes zero. Observed/heldout predictions change only at numerical
precision; some shuffled statistics change materially when formerly failed
individual candidates become eligible. One originally complete p-value changes
by one Monte Carlo increment (*A. hadrus*/obesity, 0.3265 to 0.3270).

The saved diagnostic ledger contains 150,375 full-data candidate records with
three iteration-limit failures, and 451,125 inner-CV candidate evaluations with
three unavailable predictions. These six candidate failures are explicit and
do not leave any permutation statistic unavailable; they are not counted as
recovered or accepted fits. The original 47 missing-statistic failures and
these remaining candidate-level limits are distinct.

The maintainer retains the corrected 13-page report and its source, aggregate
tables, original/corrected comparison, failure classification and reproduction
instructions with the AGP pilot records. These are not distributed with the
package. The original report and evidence remain preserved separately.
