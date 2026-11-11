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

The Tier 0--4 validation agenda developed from the early LPS/PS-LPS design work
and independent pre-submission review. The maintainer retains rendered copies
of those original design and review records outside the public repository.

The maintained public validation sources are:

- [LPS experimental plan](specs/lps_experimental_plan_2026-06-09.tex), including
  the scientific questions, fixtures and acceptance criteria;
- [validation scripts](ci/), with fixed configurations, provenance checks and
  numerical diagnostics;
- [package tests](../../../tests/testthat/), containing the executable
  correctness and regression checks.

The upstream paths above identify historical research assets in the maintainer's
separate `trend_filtering` checkout; they are not package files or public download
links. Reproducing those upstream studies requires their original inputs.
