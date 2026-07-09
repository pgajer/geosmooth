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
  - Fast development gate: `make test`
  - Full local test suite: `make test-all`
  - Focused lanes: `make test-lps`, `make test-ps-lps`, `make test-od`,
    `make test-graph`, `make test-ssrhe`, `make test-validation`,
    `make test-migration`
  - Fast QA: `make check-fast`
  - Full CRAN-style QA: `make check`
- Keep local build products, check directories, and logs out of commits.
- Keep `make test` as a fast package-development gate. Scientific validation
  sweeps, migration/parity tests, and acceptance-style mini-experiments should
  live in opt-in grouped targets such as `make test-validation` or
  `make test-all`, not in the default edit-test loop.
- For runtime profiling and benchmark claims involving native code, do not rely
  on default `pkgload::load_all()` timings unless the debug build is the object
  of study. Use an optimized source build or installed package, and record the
  load/build mode. See
  `/Users/pgajer/.codex/notes/agent_instructions/r_packages/optimized_package_builds_for_runtime_benchmarks.md`.

## Benchmark Design

- For controlled method-evaluation benchmark design, especially when building
  synthetic smoother/regression suites with interpretable stress axes, consider
  `/Users/pgajer/.codex/notes/references/evaluation_datasets/frank_friedman_style_factorial_design_for_method_evaluation.md`.

## Research Reports

- Every HTML research report, dashboard, and generated analysis summary should
  follow
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
