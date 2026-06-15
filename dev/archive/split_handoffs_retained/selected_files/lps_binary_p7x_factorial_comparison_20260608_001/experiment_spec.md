# LPS Binary P7X Factorial Comparison Experiment Spec

Generated: 2026-06-08

This is the richer overnight-ready binary LPS comparison manifest.  It supersedes
the smaller `lps_binary_p7x_density_comparison_20260608_001` manifest for the
overnight run because it includes two factors missing from that first compact
draft:

- more probability-profile / smooth-function types;
- an explicit sample-size factor.

The compact draft remains useful as a fallback if runtime becomes a concern.

## Scientific Question

The experiment compares two binary-outcome LPS modes:

- `lps_bernoulli_brier`: `fit.lps(outcome.family = "bernoulli")`;
- `lps_binomial_logistic`: `fit.lps(outcome.family = "binomial")`.

The main question is whether the local logistic-polynomial mode improves
probability-surface recovery over the minimal Bernoulli/Brier conditional
expectation mode, and whether any improvement or instability depends on:

- geometry;
- probability-profile shape;
- sample size;
- global versus local automatic chart dimension.

## Source Geometry

The experiment uses all 14 frozen P7X first-batch geometries from:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_local_auto_nonmanifold_first_batch_2026-06-05/asset_manifest.csv`

The run does not regenerate these geometries.  It records asset paths and SHA256
hashes in the task manifest.

## Probability Profiles

Each frozen geometry contains a continuous truth vector \(f\).  The experiment
turns \(f\) into a binary probability surface through a calibrated smooth
logistic transform
\[
  p_i
  =
  \varepsilon
  +
  (1-2\varepsilon)
  \operatorname{logit}^{-1}
  \{\alpha+\beta h_i\}.
\]
The intercept \(\alpha\) is chosen so that the mean probability equals the
target prevalence.  The score \(h_i\) defines the profile shape.

The four profiles are:

| profile | target prevalence | score \(h_i\) | interpretation |
|---|---:|---|---|
| `balanced_signed_smooth` | 0.50 | standardized \(f_i\) | smooth monotone signal |
| `low_prevalence_signed_smooth` | 0.20 | standardized \(f_i\) | imbalanced smooth monotone signal |
| `balanced_tail_smooth` | 0.50 | \(|z_i|\), centered | both low/high truth tails have high probability |
| `low_prevalence_central_smooth` | 0.20 | \(-|z_i|\), centered | low-prevalence central-band probability |

Here
\[
  z_i =
  \operatorname{clip}
  \left(
    \frac{f_i-\operatorname{median}(f)}
         {\operatorname{scale}(f)},
    -4,\ 4
  \right),
\]
where the scale is the MAD of \(f\), falling back to the standard deviation and
then to \(1\) if needed.

All profiles use:

```text
logit_slope = 1.25
probability_floor = 0.02
z_clip = 4
```

Profile materialization table:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_p7x_factorial_comparison_20260608_001/probability_surface_manifest.csv`

## Sample-Size Factor

The run includes two sample-size policies:

- `n250`: stratified subsample of 250 points, using `region.label` when
  available and a single `"all"` stratum otherwise;
- `full`: all points in the frozen asset, which is \(n=500\) for most assets
  and \(n=600\) for the synthetic \(N600\) assets.

Sample indices are materialized as RDS files under:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_p7x_factorial_comparison_20260608_001/sample_indices`

The sample-index manifest is:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_p7x_factorial_comparison_20260608_001/sample_index_manifest.csv`

Within each paired method comparison, both methods use the same sample index,
binary response seed, and fold seed.

## Design Size

Factors:

- 14 frozen geometries;
- 4 probability profiles;
- 2 sample-size policies;
- 5 repetitions per geometry/profile/sample-size cell;
- 2 chart-dimension rules: `auto`, `local.auto`;
- 2 methods: Bernoulli/Brier LPS and binomial/logistic LPS.

Task count:
\[
14\times4\times2\times5\times2\times2 = 2240.
\]

Paired comparisons:
\[
14\times4\times2\times5\times2 = 1120.
\]

This is a larger overnight run.  A full 10 repetitions per
geometry/profile/sample-size/chart cell would double the manifest to 4,480
tasks.  The present manifest uses 5 repetitions per cell as a pragmatic
overnight compromise while still giving 40 binary response realizations per
geometry across the profile and sample-size factors.

## Model Settings

Both methods use:

```r
coordinate.method = "local.pca"
backend = "R"
support.grid = 15:35
degree.grid = 1:2
kernel.grid = "tricube"
design.basis = "orthogonal.polynomial.drop"
design.drop.tol = 1e-8
ridge.multiplier.grid = c(0, 1e-10, 1e-8)
ridge.condition.max = 1e12
unstable.action = "mean"
cv.folds = 5
```

Selection scores:

- Bernoulli/Brier LPS selects by `cv.brier.observed`;
- binomial/logistic LPS selects by `cv.logloss.observed`.

Both methods should report both observed Brier and observed log loss, plus
TruthRMSE against the known probability surface.

## Required Accounting

Every planned task must produce a status row:

- `ok`;
- `nonfinite`;
- `error`;
- `timeout`.

The report must summarize:

- task status by method, profile, sample size, chart rule, and geometry;
- paired method-comparison completeness;
- logistic CV and final-fit convergence/fallback telemetry;
- runtime tails, especially for high-dimensional `full` sample rows.

## Manifest QA

Generated manifest bundle:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_p7x_factorial_comparison_20260608_001`

Pre-launch QA:

```text
planned_tasks: 2240
planned_pairs: 1120
frozen_geometries: 14
probability_profiles: 4
sample_policies: n250,full
reps_per_cell: 5
seed_matched_pairs: 1120
mismatched_pairs: 0
qa_passed: TRUE
```

Key files:

- `task_manifest.csv`
- `probability_surface_manifest.csv`
- `sample_index_manifest.csv`
- `manifest_qa_summary.csv`
- `manifest_pair_qa.csv`
- `manifest_balance_qa.csv`
- `run_config.csv`

## Recommended Launch Policy

Suggested overnight local-only launch:

```text
workers: 12
task timeout: 3600 seconds
```

If runtime becomes too long, the first reduction should be to launch only
`sample_policy = "n250"` first, then repair/continue the `full` rows.  Do not
drop the paired design or mix response/fold seeds across methods.
