# geosmooth development workspace

This directory holds development notes, method workspaces, and project-level
planning material that should not live at the package root.

Standalone scientific documents and report bundles were relocated to sibling
manuscript workspaces on September 12, 2026. See
[Document locations](../DOCUMENT_LOCATIONS.md) for the current owners. The
descriptions below apply to package-facing guidance and reusable development
tools, not to a second copy of those scientific sources or private audit records.

For the strategic scaffold that connects `geosmooth` methods to downstream
biological and multi-omics applications, start with the canonical
`trend_filtering` roadmap:
`~/current_projects/trend_filtering/programs/lps_lcov_omics_program/README.md`.
The local [LPS / LCov / Omics Program](programs/lps_lcov_omics_program/README.md)
page is the package-facing pointer and implementation slice.

Deep exploratory history for many `geosmooth` methods lives in
`~/current_projects/trend_filtering`. That repository is the research sandbox
for multidimensional trend-filtering and local-smoothing ideas; this `dev/`
tree is the curated package-development layer. In short:

- `trend_filtering`: broad idea exploration, literature reviews, dense
  experiments, exploratory reports, and manuscript-facing notes.
- `geosmooth`: exported R-package implementation, package tests, package
  documentation, curated audit evidence, and selected lineage/provenance
  pointers back to the research sandbox.

The top-level `trend_filtering` research dashboard is generated at
`~/current_projects/trend_filtering/dashboard/index.html`. Use it for the
program-level map of strategic roadmaps, literature reviews, theory notes,
method-development histories, and package bridges.

- `notes/`: durable explanations, design notes, plans, and tutorials.
- `methods/`: method-specific public development material such as specs,
  reports, reproducibility scripts, results summaries, and status records.
- `programs/`: package-facing pointers and implementation slices for active
  cross-method or cross-project program roadmaps whose canonical strategic
  home may live in `trend_filtering`.
- `lineage/`: short bridge notes explaining how `geosmooth` package work relates
  to upstream exploratory repositories such as `trend_filtering`; this directory
  should contain pointers and summaries, not copied bulk artifacts.
- `project_briefs/`: true project-level briefs that cut across methods or
  package phases.
- `shared/`: cross-method registries, DGPs, fixtures, benchmark specs, and
  dataset manifests.
- Agent-only audits, handoffs, prompts, work orders, and intermediate review
  products belong under `~/.codex/private/geosmooth/`, not in this repository.

New development artifacts should be placed directly under this layout when they
are appropriate for the public repository. Private agent coordination material
should stay in the private tree, with a README recording its origin and possible
future disposition.

## Dashboard

The human-facing development dashboard is generated at `dev/html/index.html`.
A convenience redirect is generated at `dev/index.html`. The same build also
generates readable HTML companions for Markdown files under sibling `html/`
directories, for example
`dev/programs/lps_lcov_omics_program/html/README.html`.
Dashboard source cards link Markdown files with `HTML` and `Markdown` buttons,
and LaTeX files with `PDF` and `LaTeX` buttons when a matching PDF exists.

Rebuild it after adding or moving development notes, project briefs, or method
reports:

```sh
python3 dev/scripts/build_dev_dashboard.py
```

Markdown files remain canonical. Files under `dev/html/`, `dev/index.html`, and
generated sibling `html/` directories are rebuildable artifacts and should not
be edited by hand.

## Source and documentation map

| Maintained source | Generated output | Supported command |
|---|---|---|
| R roxygen comments | `man/*.Rd`, `NAMESPACE` | `make document` |
| Rcpp interfaces | R/native export wrappers | `make attrs` (included in document) |
| `vignettes/*.Rmd` | Installed HTML vignettes | `make build` |
| Built tarball's `inst/doc/*.html` | Both `validation/vignettes/` and `validation/api-guide/` preview aliases | `make previews` |
| `inst/doc-tools/first-fit.R` | README figure and guide example | `make readme-figure`; vignette executes the same recipe |
| `inst/doc-tools/graph-workflow.R` | Graph guide workflow | Vignette build and workflow test |
| `_pkgdown.yml`, README, Rd, vignettes | `docs/` website | `make website` |
| R signatures and guide catalog | `dev/notes/package/api-signatures.md` | `make update-api` |

`make check-docs` is read-only. Run it after `make check` and `make website`:
it checks the source catalog and aliases, the package installed by R CMD check,
and generated site links. It fails if the appendix is stale; it never rewrites
it. The API rationale in `dev/notes/package/` is a design note, not the user
entry point. Private reports are never needed to build the package.

## Implementation map

- Public coordinate fitters: `lps.R`, `malps.R`, `ps_lps.R`, `chart_kernel.R`,
  and `local_likelihood.R`; local chart and design helpers live alongside them.
- Lifting estimators and their operators: `lpl_tf.R`, `slpl_tf.R`.
- Graph validation: `graph_validation_helpers.R`; dgraphs representation and
  geodesic adaptation: `split_bridge_helpers.R`. Keep validators here instead
  of creating competing definitions in fitter files.
- Spectral graph fitting: `metric_graph_lowpass.R`; recursive graph penalties:
  `graph_trend_filtering.R`; transported geometry and penalties: `pttf_*.R`.
- Quadratic Hessian construction/selection and L1 orchestration:
  `ssrhe_hessian_energy.R`; original-objective ADMM: `ssrhe_hessian_l1_solver.R`.
- Density normalization/accounting and occupation workflows: `state_density.R`.
- Shared operations: `model_generics.R`; stored-value accessors:
  `model_values.R`; bounded displays and structured summaries: `model_summaries.R`.
- Synthetic component registry/materialization: `synthetic_*.R`; plotting and
  dataset contracts: `synthetic_dataset.R`.

Extract a cohesive helper when changing its behavior or eliminating conflicting
ownership. File length alone is not a reason to split stable numerical code.
