# radEmu Implications for geosmooth

Generated: 2026-06-25
Canonical source: `~/current_projects/geosmooth/dev/notes/cross_method/radEmu_compositional_implications_for_geosmooth.md`
Shared note: `~/.codex/notes/references/compositional_data/radEmu_bias_identifiability.md`

## Main Implication

For `geosmooth`, radEmu is a warning that conditional expectation estimation on
microbiome-style inputs can be statistically excellent for the observed
measurement but still ambiguous as biology.  If the response or predictors are
relative-abundance features, a smoother may learn a mixture of biological
structure, sample mean efficiency, taxon-specific efficiency, and closure.

This does not make the smoother wrong.  It means the estimand must be named.
For many applications the observed measurement target is appropriate.  For
biological abundance claims, the analysis needs calibration, ratio assumptions,
or sensitivity analysis.

## Consequences for LPS and PS-LPS

- Treat \(E(Y \mid Z)\) as an observed-data estimand unless the measurement
  model is part of the design.
- Add synthetic-truth stress axes where sample mean efficiency varies smoothly
  with latent position, condition, or neighborhood density.
- Evaluate whether PS-LPS synchronization spreads efficiency bias across
  overlapping charts or dampens local artifacts.
- Report performance separately for observed-scale prediction and
  biology-scale truth when synthetic data include known efficiencies.
- Avoid interpreting local chart effects on compositional predictors as
  biological gradients unless ratio or efficiency assumptions are explicit.

## Benchmark Additions

Useful controlled factors for future `geosmooth` benchmarks:

- no efficiency bias versus taxon-specific constant efficiency;
- sample mean efficiency correlated with latent coordinate;
- sample mean efficiency correlated with class label or batch;
- differential efficiency affecting only a subset of taxa;
- aggregate features whose internal mixture changes along the latent space.

These factors would pair naturally with existing P7/P7X-style synthetic-truth
experiments because they separate smoother accuracy from measurement-target
interpretability.

## Practical Rule

When using `geosmooth` on compositional microbiome data, record the target in
one of three bins:

1. observed-composition prediction;
2. ratio or relative-fold-change inference under stated efficiency assumptions;
3. biological conditional expectation requiring calibration or sensitivity
   analysis.
