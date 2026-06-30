# LCov provenance

LCov is the chart-aware local covariance / local association branch of the
LPS/LCov/omics program. It is less a direct port of one `trend_filtering`
method than a package-facing extension of the local-chart machinery developed
through LPS, PS-LPS, LPL-TF, S-LPL-TF/SLPLiFT, and microbiome-state-space
experiments.

## Upstream research roots

- `~/current_projects/trend_filtering/development/slpl_tf/`: nonmanifold and
  real-geometry experiments that showed why local chart dimension, support
  scale, and overlap structure matter for omics-style state spaces.
- `~/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/`:
  P7/P7X geometry and truth registries, which provide controlled settings where
  local conditional mean and local association methods can be tested.
- `~/current_projects/trend_filtering/development/malps/`: predecessor local
  polynomial and binary/prevalence modeling work that helped motivate
  covariance/association questions over biological state spaces.

## Key upstream assets

- `~/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/p7x_geometry_stress_suite_spec.md`
  records the geometry-stress design that motivates local association methods
  on high-dimensional, curved, stratified, and real-geometry examples.
- `~/current_projects/trend_filtering/development/slpl_tf/analysis/slpl_tf_analysis_a5_geometric_operator_quantities.tex`
  and related analysis reports record geometric diagnostics that inform local
  operator and local covariance questions.
- `~/current_projects/trend_filtering/development/slpl_tf/documentation/slpl_tf_a7_chart_nullity_experiment_report.pdf`
  records chart/nullity experiments that helped clarify why local chart quality
  matters for downstream operator behavior.
- `~/current_projects/trend_filtering/development/malps/documentation/malps_model_development_report.tex`
  is predecessor context for local polynomial modeling and microbiome-style
  applications.

## Package promotion in `geosmooth`

The current LCov design source is:

- `~/current_projects/geosmooth/dev/methods/lcov/specs/chart_aware_local_association_design_2026-06-09.tex`

The strategic program roadmap that places LCov beside LPS, PS-LPS, synthetic
data, compositional state spaces, CAG construction, and 16S/omics applications
is:

- `~/current_projects/geosmooth/dev/programs/lps_lcov_omics_program/lps_lcov_omics_program_plan.tex`
