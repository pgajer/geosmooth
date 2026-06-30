# PS-LPS provenance

PS-LPS (`fit.ps.lps`) is the prediction-synchronized extension of LPS. It was
motivated by the S-LPL-TF / SLPLiFT line of work: local charts should not behave
as isolated regressions when their supports overlap, so neighboring local models
should be encouraged to agree on shared regions.

## Upstream research roots

- `~/current_projects/trend_filtering/development/slpl_tf/`: S-LPL-TF /
  SLPLiFT development, including the prediction-overlap synchronization idea,
  practical selector studies, P7/P7X comparisons, and PS-LPS experiments.
- `~/current_projects/trend_filtering/development/lpl_tf/`: LPL-TF development,
  which supplied the local polynomial lifting viewpoint that PS-LPS simplifies
  into a smoother without the LPL trend-filtering penalty.
- `~/current_projects/trend_filtering/development/slpl_tf/analysis/`: operator
  and null-space analyses that clarified how chart choices, overlap structure,
  and synchronization affect local-polynomial methods.

## Key upstream assets

- `~/current_projects/trend_filtering/development/slpl_tf/documentation/slpl_tf_phase_s7_practical_parameter_selection_methods.tex`
  and
  `~/current_projects/trend_filtering/development/slpl_tf/documentation/slpl_tf_phase_s7_practical_parameter_selection_implementation_specs.md`
  describe practical parameter-selection methods that informed PS-LPS lambda and
  support-search policies.
- `~/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/p7x_geometry_stress_suite_spec.md`
  specifies the geometry stress suite used to compare LPS, PS-LPS, SLPLiFT, and
  other baselines.
- `~/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/config/p7x_ps_lps_support_prior.csv`
  records support-prior material used in screened PS-LPS experiments.
- `~/current_projects/trend_filtering/development/slpl_tf/validation/slpl_tf_phase_s7_practical_selector_core.R`
  and companion selector scripts record the practical selector machinery that
  preceded package-facing PS-LPS search policies.

## Package promotion in `geosmooth`

The early LPS/PS-LPS orientation brief and the independent pre-submission audit
are the closest package-facing bridge from exploration to implementation:

- `~/current_projects/geosmooth/dev/notes/cross_method/lps_ps_lps_project_brief_09-06-2026.md`
- `~/current_projects/geosmooth/dev/notes/cross_method/lps_ps_lps_jasa_style_audit_2026-06-09.md`

The PS-LPS execution history, cache/search audits, and retained split handoffs
are curated under:

- `~/current_projects/geosmooth/dev/methods/ps_lps/`
- `~/current_projects/geosmooth/dev/archive/split_handoffs_retained/selected_files/ps_lps_audit_2026-06-05/`
- `~/current_projects/geosmooth/dev/archive/split_handoffs_retained/selected_files/ps_lps_cache_backend_2026-06-05/`
