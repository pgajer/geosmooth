# LPS provenance

LPS (`fit.lps`) is the package-facing local polynomial smoother in `geosmooth`.
It grew out of the broader `trend_filtering` research program, especially the
search for multidimensional smoothers that remain useful on curved,
nonmanifold, and microbiome-style state spaces.

## Upstream research roots

- `~/current_projects/trend_filtering/development/lpl_tf/`: local polynomial
  lifting trend filtering development. This work established the local-chart
  lifting viewpoint and the need for robust local polynomial infrastructure.
- `~/current_projects/trend_filtering/development/slpl_tf/`: synchronized LPL-TF
  / SLPLiFT development. The S7/P7/P7X experiments compared local polynomial,
  graph, and synchronized smoothers and motivated LPS as a strong, simpler
  package-facing baseline.
- `~/current_projects/trend_filtering/development/malps/`: MALPS development.
  MALPS provided early model-averaged local polynomial ideas, binary-response
  stabilization work, and GCV/CV selection lessons that shaped LPS validation.

## Key upstream assets

- `~/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/p7x_geometry_stress_suite_spec.md`
  defines the P7X geometry-stress suite that tested methods on controlled,
  high-dimensional, nonmanifold, and real-geometry synthetic examples.
- `~/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/config/p7x_geometry_registry.csv`
  and `config/p7x_truth_registry.csv` record frozen P7X geometry/truth
  registries.
- `~/current_projects/trend_filtering/development/slpl_tf/documentation/slpl_tf_phase_s7_practical_parameter_selection_methods.tex`
  records practical selector ideas that helped clarify why an LPS-style
  estimator needed auditable tuning and validation rules.
- `~/current_projects/trend_filtering/development/malps/documentation/malps_model_development_report.tex`
  and related MALPS reports provide predecessor local-polynomial and
  model-selection context.

## Package promotion in `geosmooth`

The early LPS/PS-LPS orientation brief has been restored here:

- `~/current_projects/geosmooth/dev/notes/cross_method/lps_ps_lps_project_brief_09-06-2026.md`

The independent pre-submission audit that turned the early LPS/PS-LPS work into
the Tier 0--4 validation agenda is:

- `~/current_projects/geosmooth/dev/notes/cross_method/lps_ps_lps_jasa_style_audit_2026-06-09.md`

The current LPS validation spine is:

- `~/current_projects/geosmooth/dev/methods/lps/specs/lps_experimental_plan_2026-06-09.tex`
- `~/current_projects/geosmooth/dev/methods/lps/specs/lps_tiers1to4_project_brief_2026-06-11.md`
- `~/current_projects/geosmooth/dev/methods/lps/audit_contracts/tiers1to4/lps_tiers1to4_contract_2026-06-11.md`
