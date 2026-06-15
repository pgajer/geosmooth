# geosmooth development workspace

This directory holds development notes, method workspaces, and project-level
planning material that should not live at the package root.

- `notes/`: durable explanations, design notes, prompts, plans, and tutorials.
- `methods/`: method-specific execution history such as audits, reports, runs,
  results, handoffs, and status records.
- `project_briefs/`: true project-level briefs that cut across methods or
  package phases.

During active branch work, keep existing root-level development directories in
place until dependent worktrees have merged. Move them here in a dedicated
layout migration commit.

## Dashboard

The human-facing development dashboard is generated at `dev/html/index.html`.
A convenience redirect is generated at `dev/index.html`.

Rebuild it after adding or moving development notes, project briefs, or method
reports:

```sh
python3 dev/scripts/build_dev_dashboard.py
```

Files under `dev/html/` are generated and should not be edited by hand.
