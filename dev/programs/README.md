# Program Pointers

This directory holds package-facing pointers and implementation slices for
cross-method program roadmaps. Canonical strategic roadmaps whose scope extends
beyond the package should live in the exploratory program layer, usually under
`~/current_projects/trend_filtering/programs/`.

Use this directory for durable package-facing pages that answer questions such
as:

- Which canonical program roadmap motivates this package work?
- Which `geosmooth` methods and implementation workspaces are involved?
- Which package-facing foundation notes, specs, audits, or reports should be
  easy to reach from the dashboard?
- Which downstream work is intentionally linked rather than copied into the
  package repository?

Program pointer pages are different from:

- `dev/project_briefs/`: repository-level briefs or package-phase summaries;
- `dev/methods/<method>/specs/`: method-specific scientific or implementation
  specifications;
- `dev/methods/<method>/audit_contracts/`: work orders, gates, and auditor
  assignments;
- `dev/methods/<method>/audits/`: audit reports and responses.

The current flagship pointer is:

- [LPS / LCov / Omics Program](lps_lcov_omics_program/README.md)

Run `python3 dev/scripts/build_dev_dashboard.py` from the repository root to
refresh the dashboard and generated HTML companions for program Markdown files.
The generated pages are for reading and navigation; edit the Markdown sources.
