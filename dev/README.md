# geosmooth development workspace

This directory holds development notes, method workspaces, and project-level
planning material that should not live at the package root.

- `notes/`: durable explanations, design notes, prompts, plans, and tutorials.
- `methods/`: method-specific execution history such as audits, reports, runs,
  results, handoffs, and status records.
- `programs/`: active cross-method or cross-project program roadmaps that
  connect `geosmooth` method development to downstream scientific applications.
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
A convenience redirect is generated at `dev/index.html`.

Rebuild it after adding or moving development notes, project briefs, or method
reports:

```sh
python3 dev/scripts/build_dev_dashboard.py
```

Files under `dev/html/` are generated and should not be edited by hand.
