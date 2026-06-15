# PS-LPS First Implementation Audit 2026-06-05

## Verdict

Blocked.

The implementation has the expected high-level PS-LPS structure: one local
chart per anchor, local weighted polynomial data rows, overlap synchronization
rows with the correct sign pattern, cached first-batch experiment regeneration,
and PS-local-GCV computed from synchronized coefficients. However, two release
gates fail:

1. `lambda.sync = 0` does not reduce to ordinary independent LPS chart fits in
   the frozen first-batch examples. The sparse normal-equation ridge materially
   changes some local fits.
2. `sync.energy` and `mean.sync.disagreement` are reported as zero whenever
   `lambda.sync = 0`, even though the unmultiplied synchronization energy
   `S(beta)` is generally nonzero and is requested as an audit diagnostic.

Because of these issues, the first-batch claim that PS-LPS is best on all 14
datasets is interesting but not yet interpretable as a clean synchronization
effect.

## Blocking Issues

1. `lambda.sync = 0` fails the ordinary-LPS reduction gate because the
   ridge-stabilized sparse normal-equation solve materially changes some
   independent local chart fits.
2. `sync.energy` and `mean.sync.disagreement` are diagnostically wrong at
   `lambda.sync = 0`; they are reported as zero instead of measuring the
   unmultiplied overlap disagreement energy for the fitted coefficients.

## Assets Audited

- Design: `split_handoffs/lps_prediction_synchronized_design_2026-06-05/lps_prediction_synchronized_design.tex`
- Implementation: `R/ps_lps.R`
- Export: `NAMESPACE`
- Experiment runner: `scripts/run_ps_lps_first_batch_experiment.R`
- Generated report and tables:
  `split_handoffs/ps_lps_first_batch_experiment_2026-06-05/`
- Frozen ordinary LPS inputs/results:
  `split_handoffs/lps_local_auto_nonmanifold_first_batch_2026-06-05/`

## Gate 1: Objective Implementation

Status: partially passes, with one blocker.

The local data-fit rows are assembled from the local polynomial design and
kernel weights:

- frames are built with local-PCA coordinates and polynomial design in
  `R/ps_lps.R:169-219`;
- data-fit rows use `sqrt(response.weight * kernel.weight) * design` and
  `sqrt(response.weight * kernel.weight) * y` in `R/ps_lps.R:276-291`.

The synchronization rows have the correct sign pattern
`phi_i beta_i - phi_j beta_j` and use
`sqrt(lambda.sync * omega)`:

- see `R/ps_lps.R:293-309`.

However, the solved objective is not exactly the design objective. The solver
adds an unconditional ridge,

```r
ridge <- 1e-8 * scale
normal <- cross + Matrix::Diagonal(ncoef, x = ridge)
```

at `R/ps_lps.R:323-335`. In ill-conditioned local charts this ridge is not
negligible; it materially changes intercepts and fitted values. This also
causes the lambda-zero reduction failure in Gate 3.

The reported `sync.energy` is the unmultiplied energy for positive
`lambda.sync`, but is incorrectly forced to zero for `lambda.sync = 0`
because diagnostics skip the synchronization-energy loop unless
`lambda.sync > 0` (`R/ps_lps.R:375-389`).

## Gate 2: Overlap Weights

Status: passes.

The implementation uses actual support intersections:

- `overlap <- intersect(frames[[ii]]$index, frames[[jj]]$index)` at
  `R/ps_lps.R:241`.

It computes product weights `w_ir * w_jr` and normalized-product weights with
approximately total mass `|O_ij|`:

- see `R/ps_lps.R:245-249`.

Pair construction is symmetric and de-duplicated by sorted pair keys:

- see `R/ps_lps.R:226-234`.

Spot check on FB01, auto setting, `support.size = 35`, `sync.neighbor.size = 3`:

- synchronization pairs: 1037;
- maximum absolute mass error
  `abs(sum(omega_ijr) - |O_ij|)`: `3.22e-08`;
- median absolute mass error: `2.18e-08`.

Degenerate overlaps and nonpositive/nonfinite weights are safely filtered.

## Gate 3: Lambda-Zero Reduction

Status: fails.

The design requires `lambda.sync = 0` to decompose into ordinary independent
LPS chart fits. The current implementation does decompose algebraically, but
the unconditional ridge in the normal-equation solve changes the local fits
enough that the fitted values do not match ordinary LPS.

Spot checks comparing `fit.ps.lps(lambda.sync.grid = 0)` to ordinary
`fit.lps()` / frozen ordinary LPS predictions with the same support, degree,
kernel, and chart dimensions:

| Batch | Rule | Max abs diff | RMSE diff | LPS Truth RMSE | PS lambda-0 Truth RMSE |
|---|---:|---:|---:|---:|---:|
| FB01 | auto | 0.139301 | 0.016415 | 0.046726 | 0.041527 |
| FB01 | local.auto | 0.134823 | 0.019022 | 0.049115 | 0.043301 |
| FB06 | auto | 0.169507 | 0.036656 | 0.091683 | 0.077437 |
| FB06 | local.auto | 0.170594 | 0.045132 | 0.085575 | 0.066620 |
| FB14 | auto | 0.008747 | 0.001270 | 0.100134 | 0.099929 |
| FB14 | local.auto | 0.008747 | 0.001200 | 0.098655 | 0.098444 |

For FB01 auto, the worst anchor was 492:

- ordinary `lm.wfit()` intercept: `0.4045579`;
- PS-LPS ridge-normal-equation intercept: `0.2652568`;
- same local chart rank: 6 of 6;
- ridge used in that local block: about `2.37e-07`.

This is much larger than a harmless numerical perturbation. The blocker is not
the synchronization rows; it is the local solver used by PS-LPS at
`lambda.sync = 0`.

Recommended fix:

- either solve the stacked least-squares problem with a QR/SVD/least-squares
  backend that reproduces ordinary LPS at `lambda.sync = 0`;
- or explicitly define PS-LPS as a ridge-stabilized variant, expose/report the
  ridge, and rerun ordinary LPS baselines through the same ridge-stabilized
  local fitting backend before making comparative claims.

## Gate 4: CV Leakage

Status: passes for response leakage.

Fold solves set `response.weights <- as.numeric(foldid != fold)` and remove
validation-response rows from the data-fit system:

- see `R/ps_lps.R:92-101` and `R/ps_lps.R:279-284`.

Synchronization rows use only covariates, chart bases, kernel weights, overlap
membership, and fitted coefficients; they do not use validation responses.
Held-out predictions are extracted after the fold-specific solve, and the RMSE
score is computed against held-out responses afterward.

The CV protocol is transductive in covariates, consistent with the design:
held-out covariate locations may influence supports, charts, overlaps, and
synchronization rows, but held-out responses do not enter the fit.

One interpretive caveat: the ordinary LPS nested reference in the design is
not currently achieved numerically at `lambda.sync = 0`, so the lambda-zero CV
candidate is a ridge-stabilized PS-LPS variant rather than ordinary LPS.

## Gate 5: Diagnostics Correctness

Status: partially passes, with one blocker and one naming concern.

Correct:

- Truth RMSE and observed RMSE in the experiment are computed directly from
  `fit$fitted.values` against `asset$f` and `asset$y`
  (`scripts/run_ps_lps_first_batch_experiment.R:123-125`).
- CV RMSE is computed from fold-held-out predictions (`R/ps_lps.R:91-103`).
- PS-local-GCV is computed from synchronized chart coefficients, not from
  independent LPS fits (`R/ps_lps.R:360-373`).
- Local degrees-of-freedom ratio is the local weighted-design rank divided by
  support size (`R/ps_lps.R:200-201`, `R/ps_lps.R:366-369`).
- Pointwise components implement the exact decomposition of RMSE difference
  versus LPS auto:
  `(e_method^2 - e_auto^2) / (n * (RMSE_method + RMSE_auto))`
  (`scripts/run_ps_lps_first_batch_experiment.R:260-271`).

Incorrect:

- `sync.energy` and `mean.sync.disagreement` are set to zero at
  `lambda.sync = 0` because the diagnostic calculation is gated by
  `if (lambda.sync > 0 && length(sync.rows))`.

FB01 auto check:

- reported at `lambda.sync = 0`: `sync.energy = 0`,
  `mean.sync.disagreement = 0`;
- manually computed unmultiplied `S(beta)`: `4.5486`;
- corresponding weighted mean squared disagreement:
  `2 * S(beta) / sum(omega) = 0.000270734`.

The energy should be computed for every fitted coefficient vector whenever
sync rows exist, independent of whether the penalty was active in the
objective.

Naming concern:

- `mean.sync.disagreement` is a weighted mean squared disagreement, not a root
  mean squared disagreement or mean absolute disagreement. Rename or document
  it as `mean.sync.squared.disagreement`.

## Gate 6: Experiment Reproducibility

Status: passes with cached results.

Command run:

```bash
cd /Users/pgajer/current_projects/geosmooth
Rscript scripts/run_ps_lps_first_batch_experiment.R
```

The command completed and regenerated the report at:

```text
/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_first_batch_experiment_2026-06-05/ps_lps_first_batch_experiment_report.html
```

`PS_LPS_FORCE` was not set. The script reuses cached result RDS files when
present (`scripts/run_ps_lps_first_batch_experiment.R:50-56`), so this run was
a cached regeneration of tables/figures/report rather than a full recompute.
That is acceptable for this audit, given the direct code inspection and spot
checks above.

## Gate 7: Numerical Concerns

Status: fails for promotion beyond prototype.

The current sparse normal-equation solve with unconditional ridge is not safe
to treat as essentially the stated quadratic objective. It is stabilizing some
local fits, but the stabilization is large enough to change first-batch fitted
values and Truth RMSE at `lambda.sync = 0`.

Required before promotion:

- report the actual ridge used, fallback ridge status, and ideally local/global
  conditioning diagnostics;
- add a formal lambda-zero parity test against ordinary `fit.lps()` for fixed
  support/kernel/degree/chart dimensions;
- use a sparse QR, dense block QR for `lambda.sync = 0`, LSQR/LSMR, or another
  least-squares backend that avoids solving only ridge-regularized normal
  equations as the default audit path;
- if ridge is retained, include it as a documented modeling choice and compare
  against ordinary LPS baselines fit with the same ridge policy.

The ridge materially affects lambda-zero comparisons. It cannot be dismissed
as tiny numerical noise.

## Gate 8: Result Interpretation

Status: blocked pending fixes.

The result pattern is broad:

- best method counts from the generated comparison table:
  - `PS-LPS auto`: 5 datasets;
  - `PS-LPS local.auto`: 9 datasets;
  - ordinary LPS variants: 0 datasets.
- best PS-LPS beats best ordinary LPS on all 14 datasets;
- median absolute Truth-RMSE gain: `0.02079`;
- median relative Truth-RMSE gain: `30.6%`;
- relative gains range from `10.2%` to `48.2%`.

The CV selection of `lambda.sync` is coherent within the current implementation:

- `lambda.sync = 1` is selected in 27 of 28 PS-LPS method/dataset runs;
- `lambda.sync = 0.1` is selected once;
- `lambda.sync = 0` is never selected.

However, the comparison is not yet clean:

- PS-LPS at `lambda.sync = 0` is already not ordinary LPS, due to the solver
  ridge;
- the `sync.energy = 0` diagnostics at lambda zero hide the true baseline
  disagreement;
- the positive-lambda gains are therefore a mixture of synchronization and a
  different ridge-stabilized local solver.

The first-batch result should be described as a promising prototype result,
not as evidence that synchronization alone beats ordinary LPS on all 14
datasets.

## Required Fixes

1. Make `lambda.sync = 0` reproduce ordinary LPS fixed-chart fits up to a
   genuinely negligible tolerance, or explicitly redesign the comparison as a
   ridge-stabilized PS-LPS variant with ridge-matched ordinary baselines.
2. Compute unmultiplied `sync.energy = S(beta)` for all lambda values,
   including zero.
3. Rename or clearly document `mean.sync.disagreement` as a mean squared
   disagreement.
4. Add focused tests:
   - overlap weight mass per pair;
   - lambda-zero fitted-value parity against `fit.lps()`;
   - `sync.energy` at lambda zero equals manual `S(beta)`;
   - CV fold solves do not include validation-response rows.
5. Report numerical ridge diagnostics, and do not promote the normal-equation
   backend beyond prototype without a more reliable least-squares backend or a
   documented ridge model.

## Next Step Recommendation

First fix and test the lambda-zero parity and synchronization-energy
diagnostics. Then rerun the first-batch comparison from frozen assets, ideally
with a solver path that reproduces ordinary LPS at `lambda.sync = 0`, before
interpreting positive-lambda gains as synchronization gains.

## Non-Blocking Notes

- The overlap construction through `sync.neighbor.size` is reasonable for the
  first implementation and avoids duplicate pair rows, but the experiment
  report should state that only a sparse subset of anchor pairs is synchronized.
- The lambda grid `{0, 0.1, 1}` is small. It is adequate for a smoke/prototype
  run, but a later publishable run should widen/refine the lambda grid after
  the lambda-zero and numerical issues are fixed.
- `NAMESPACE` exports `fit.ps.lps`, as expected.
