# Repository Instructions

## Scope

This repository is the development home for the `geosmooth` R package split
from `gflow`.

## Preferred Skills

- Prefer `$r-package-qa` for package QA, documentation drift, native build
  issues, and release-readiness work.

## R Style

- Prefer dot-delimited function and variable names for new R code.
- Keep public function names unchanged while moving methods from `gflow`; API
  cleanup should happen after the package is installable and tested.
- Use leading-dot names only for private helpers.

## Package Hygiene

- Validate focused changes first:
  - `make test`
- Run package QA via Makefile targets:
  - Fast QA: `make check-fast`
  - Full CRAN-style QA: `make check`
- Keep local build products, check directories, and logs out of commits.

## Benchmark Design

- For controlled method-evaluation benchmark design, especially when building
  synthetic smoother/regression suites with interpretable stress axes, consider
  `/Users/pgajer/.codex/notes/references/evaluation_datasets/frank_friedman_style_factorial_design_for_method_evaluation.md`.

## Research Reports

- Every phase HTML report should follow
  `/Users/pgajer/.codex/notes/agent_instructions/reports/html_report_style_guide.md`.
- For figure/table readability and report polishing, follow
  `/Users/pgajer/.codex/notes/agent_instructions/reports/report_figure_table_qc.md`.
- Prefer self-contained report sections with stated questions, definitions,
  formulas when relevant, numbered figure captions, interpretation paragraphs,
  compact visible tables, and linked full CSV/RDS/log artifacts.

## Split Discipline

- GE0 is the skeleton and native support scaffold.
- GE1-GE4 should move methods in small coherent groups and fix only
  split-induced namespace, registration, or helper issues.
- Do not silently change smoother semantics during migration.

## Documentation And Artifact Reorganizations

- Before moving, deleting, ignoring, or declaring complete any reorganization of
  development artifacts, run the unmerged-branch artifact reconciliation gate:
  `/Users/pgajer/.codex/notes/workflows/unmerged_branch_artifact_reconciliation.md`.
- Inspect unmerged `codex/*` and other agent branches for durable artifacts
  before relying on the current branch's file tree. This is required for
  restructures involving `dev/`, `project_briefs/`, `split_handoffs/`,
  `audits/`, `audit_contracts/`, `reports/`, `validation/`, dashboards, or
  program roadmaps.
- Record a disposition for every durable side-branch artifact: promoted,
  already present, archived, externalized, or discarded with a concrete reason.
  Do not call a migration complete while active documents still cite old paths
  or while cited sources exist only on an unmerged branch.
