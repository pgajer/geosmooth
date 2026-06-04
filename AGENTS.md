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

## Split Discipline

- GE0 is the skeleton and native support scaffold.
- GE1-GE4 should move methods in small coherent groups and fix only
  split-induced namespace, registration, or helper issues.
- Do not silently change smoother semantics during migration.
