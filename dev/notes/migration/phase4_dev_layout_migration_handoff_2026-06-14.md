# Phase-4 development-layout migration handoff

Date: 2026-06-14

Branch: `chore/dev-layout-migration`

Starting point: `main`/`origin/main` at
`5d1d8379307594442319393b7883127ff3307a34`.

## Scope

This migration reorganized development-only documents and evidence into the
new `dev/` layout while keeping package source and package-facing APIs
unchanged.

## Auditor findings addressed

- The work order was updated to use `main = 5d1d837`, with the E1.9 branch
  merge marked as already integrated/no-op.
- Tracked `project_briefs/` files were explicitly routed with `git mv`.
- The scaffold wording now says only source scaffold files are tracked; generated
  `dev/html/` and `dev/index.html` remain ignored.
- `*.tmp` was added to the generated-byproduct cleanup instruction.
- The reference sweep was changed from a generic term search to an old-root
  stale-path report with zero unresolved active references.
- Ignored/untracked `split_handoffs/` was inventoried explicitly.

## Major routing

- `audits/` -> `dev/methods/lps/audits/`
- `audit_contracts/` -> `dev/methods/lps/audit_contracts/`
- `dev/methods/lps/handoffs/phase/` -> `dev/methods/lps/handoffs/phase/`
- tracked `dev/methods/lps/audit_artifacts/` evidence -> `dev/methods/lps/runs/audit_artifacts/`
- tracked LPS run outputs under `reports/` -> `dev/methods/lps/runs/`
- method-specific `validation/` and `scripts/ci/` files ->
  `dev/methods/lps/ci/`
- tracked and untracked `project_briefs/` files were split among
  `dev/project_briefs/`, `dev/methods/lps/specs/`,
  `dev/methods/lps/audit_contracts/`, `dev/methods/lps/status/`,
  `dev/methods/lcov/specs/`, and `dev/notes/lps/design/`.

## Ignored split_handoffs inventory

The ignored `split_handoffs/` directory was not moved wholesale. It was
inventoried and selectively retained:

- total files inventoried: 58,127
- retained durable files copied into `dev/archive/split_handoffs_retained/selected_files/`: 235
- intentionally externalized/ignored files: 57,892
- inventory manifest:
  `dev/archive/split_handoffs_retained/split_handoffs_inventory_2026-06-14.csv`
- retention summary:
  `dev/archive/split_handoffs_retained/README.md`

Retained files include durable `.md` handoffs/audits/contracts/specs/manifests,
selected small tabular manifests, and selected cited reports. Bulky generated
run payloads, logs, and low-level task outputs remain externalized in the
ignored source tree.

## Stale path evidence

Reviewed report:

- `dev/notes/migration/stale_path_report_2026-06-14.md`

Result:

- active executable/package sweep unresolved old-root references: 0
- broader archival old-root mentions retained as historical context: 536

## Generated files policy

The following remain ignored and should not be edited by hand:

- `dev/html/`
- `dev/index.html`
- `dev/methods/*/audit_artifacts/*` except `.gitkeep`
- root `split_handoffs/`
- root `dev/methods/lps/audit_artifacts/`
- package-generated `man/`

## Verification completed

- Rebuilt the generated dev dashboard with
  `python3 dev/scripts/build_dev_dashboard.py`.
  - generated dashboard path: `dev/html/index.html`
  - note count: 157
  - project-brief count: 3
  - report-file count: 2
- Ran active stale-reference sweep over `.github`, `R`, `tests/testthat`, and
  `dev/methods/lps/ci`: zero hits.
- Ran `git diff --check`: clean.
- Ran targeted path-sensitive test:
  `Rscript -e 'suppressMessages(pkgload::load_all(".", quiet=TRUE)); testthat::test_file("tests/testthat/test-lps-ridge-alignment.R")'`
  - result: 20 passed, 0 failed, 0 warnings, 0 skips.
- Ran `R CMD build .`.
  - result: built `geosmooth_0.0.0.9000.tar.gz` successfully.
  - generated tarball was removed after verification.
