# geosmooth development workspace

This directory holds development notes, method workspaces, and project-level
planning material that should not live at the package root.

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

- `notes/`: durable explanations, design notes, prompts, plans, and tutorials.
- `methods/`: method-specific execution history such as audits, reports, runs,
  results, handoffs, and status records.
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
- `archive/`: retained historical bundles that are useful for auditability but
  are not active canonical homes for new work.

New development artifacts should be placed directly under this layout. The
archive area is for retained legacy material only; promote archive files into
`methods/`, `shared/`, `notes/`, `programs/`, or `project_briefs/` when they
become active inputs to new work.

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
