# geosmooth dev target structure design

Status: draft for review
Scope: post-worktree-merge reorganization of development artifacts under
`dev/`

## Purpose

The `geosmooth` package root should stay focused on the shippable R package:
`R/`, `src/`, `tests/`, `inst/`, `man/`, `DESCRIPTION`, `NAMESPACE`, package
scripts, and CI configuration.

The `dev/` tree should hold process artifacts: durable development notes,
method-specific evidence, audit authority, handoffs, generated reports, run
records, shared benchmark infrastructure, and project-level coordination.
`dev/`, `validation/`, `scripts/`, and non-package tooling should be listed in
`.Rbuildignore` so `R CMD build` yields a clean package tarball.

This reorganization should happen after active `geosmooth-*` worktrees merge.
Creating the scaffold early is safe, but moving existing root-level directories
mid-flight would create avoidable merge noise.

## Design goals

- Keep the package root small and package-oriented.
- Partition evidence and execution history by method.
- Separate human-authored durable notes from generated/regenerable artifacts.
- Keep audit-authority specifications tracked and easy to find.
- Provide a shared home for cross-method DGPs, fixtures, registries, and specs.
- Make generated reports discoverable through a lightweight HTML dashboard.
- Write down tracked-vs-ignored policy before the bulk migration.
- Execute the final move as one atomic `git mv` commit with a reference sweep.

## Proposed top-level layout

```text
dev/
  README.md
  index.html                  # generated, ignored
  html/                       # generated, ignored
  scripts/
    build_dev_dashboard.py

  project_briefs/

  shared/
    README.md
    data/
    dgp/
    fixtures/
    registries/
    specs/

  notes/
    README.md
    tutorials/
    foundations/
    cross_method/
    migration/
    package/
    lps/
    ps_lps/
    malps/
    lpl_tf/
    slpl_tf/
    graph_trend_filtering/
    ssrhe_hessian_energy/
    metric_graph_lowpass/

  methods/
    README.md
    lps/
      README.md
      specs/
      audit_contracts/
      audits/
      audit_artifacts/
      handoffs/
      reports/
      runs/
      results/
      status/
      ci/
    ps_lps/
      specs/
      audit_contracts/
      audits/
      audit_artifacts/
      handoffs/
      reports/
      runs/
      results/
      status/
      ci/
    malps/
    lpl_tf/
    slpl_tf/
    graph_trend_filtering/
    ssrhe_hessian_energy/
    metric_graph_lowpass/
```

## Directory roles

### `dev/project_briefs/`

Use for true repository-level briefs: package-phase planning, cross-method
coordination, release positioning, or project-level status. Do not use this as
a catch-all for prompts, contracts, generated reports, or method design notes.

### `dev/shared/`

Use for cross-method infrastructure and durable shared assets.

Suggested routing:

- `shared/dgp/`: canonical DGP library designs and generators used by multiple
  methods.
- `shared/data/`: shared dataset specifications, frozen input manifests, and
  data access notes.
- `shared/fixtures/`: small reusable fixtures or fixture definitions.
- `shared/registries/`: frozen catalogues, asset indexes, benchmark registries,
  and manifest schemas.
- `shared/specs/`: canonical cross-method binding specifications and benchmark
  contracts.

Large generated data, `.rds` files, and bulky results should not be tracked
here unless explicitly accepted as small durable fixtures.

Cross-method specs should have one canonical home. Do not copy shared specs
into method directories; method-specific documents should reference the shared
spec with a relative link. If a shared spec later becomes method-specific,
move it with `git mv` into the method's `specs/` directory and update
references.

### `dev/notes/`

Use for durable, human-authored explanation. Notes are not audit authority by
default, and they are not the home for generated report evidence.

Suggested routing:

- `notes/tutorials/`: teaching-oriented notes that explain concepts or
  workflows.
- `notes/foundations/`: reusable theory or background that supports multiple
  methods, such as effective degrees of freedom, chart nerves, foundations of
  linear models, local dimension regularization, and COT-style bridges.
- `notes/cross_method/`: method comparisons, shared terminology, common
  benchmark design reasoning, and cross-method decision records.
- `notes/migration/`: split-from-`gflow` notes, namespace migration,
  dependency-boundary planning, and cleanup sequencing.
- `notes/package/`: package-wide documentation, release-readiness, API, and QA
  guidance.
- `notes/<method>/`: method-specific conceptual, design, implementation,
  testing, planning, or prompt notes.

Generic expository notes should not be filed under `notes/lps/` merely because
LPS motivated them. Put broad teaching material in `tutorials/` or
`foundations/`.

### `dev/methods/<method>/`

Use for method-specific execution history, evidence, audit authority, and
generated outputs.

Recommended method names:

- `lps`
- `ps_lps`
- `malps`
- `lpl_tf`
- `slpl_tf`
- `graph_trend_filtering`
- `ssrhe_hessian_energy`
- `metric_graph_lowpass`

Canonical method directory keys should match the R source-file stem when there
is a clear source file. This keeps the mapping grounded in package source
rather than in ad hoc short aliases. If short aliases are ever introduced, keep
an explicit table in `dev/README.md` mapping directory key to R source file and
exported function names.

Subdirectory roles:

- `specs/`: scientific and methodological authority: frozen experimental
  plans, method definitions, benchmark designs, and binding specifications for
  what the method is and what should be tested.
- `audit_contracts/`: governance authority: auditor work orders, implementer
  prompts, tightening contracts, acceptance criteria, gate definitions, and
  contracts for how work is reviewed and accepted.
- `audits/`: audit reports, audit responses, re-audits, and final acceptance
  reports.
- `audit_artifacts/`: generated audit bundles and evidence dumps. Track only
  manifests or small summaries by default.
- `handoffs/`: implementer, auditor, phase, and split handoffs.
- `reports/`: generated HTML/PDF reports and their local assets, organized by
  tier/topic/date.
- `runs/`: run directories, manifests, launcher records, and operational logs.
- `results/`: durable result tables or serialized outputs, subject to the
  tracked-vs-ignored policy below.
- `status/`: progress notes and operational state.
- `ci/`: method-specific harnesses, report-export helpers, or gate
  orchestration that are not part of package-wide CI.

## CI tooling placement

CI tooling means scripts and configuration used by continuous integration, or
local harnesses that mimic CI gates.

Recommended placement:

- `.github/workflows/`: actual GitHub Actions workflow definitions.
- `tests/`: package tests that ship with or validate the package.
- `scripts/ci/`: package-wide CI helpers and local gate wrappers.
- `dev/methods/<method>/ci/`: method-program harnesses, report-export helpers,
  audit-bundle builders, validation scripts, and tier-specific gate
  orchestration that are not package-wide.

Do not move package-wide CI helpers into a method folder just because one
method currently uses them. Scope determines placement.

The root `validation/` directory should be reserved for package-wide validation
entry points. Method-specific validation tooling, such as a one-method
reference-fit pinning or report-input export script, should move to
`dev/methods/<method>/ci/` unless it is part of the package's shipped tests or
package-wide validation surface.

## Report placement convention

Generated method reports should live under method workspaces, not under
`dev/notes/`.

Preferred pattern:

```text
dev/methods/<method>/reports/<tier-or-topic>/<report-name>/<date>/
  report.html
  report.pdf
  README.md              # optional short manifest
  scripts/               # report-specific scripts, if not reusable
  tables/                # small CSV summaries, if tracked
  figures/               # small figures, if tracked
  assets/ or report_files/
```

Example:

```text
dev/methods/lps/reports/tier2/binary_hygiene/2026-06-11/
  lps_tier2_binary_hygiene_report_2026-06-11.html
  lps_tier2_binary_hygiene_report_2026-06-11.pdf
  scripts/export_tier2_report_inputs.R
```

Always track the report source script or source document and a small manifest
or README stating what the report shows, which run or inputs it consumed, and
the headline numbers.

Track rendered HTML/PDF only when the report is durable audit evidence, meaning
an audit or acceptance record cites it. Exploratory rendered reports are
regenerable and should be ignored. `report_files/`, widget asset directories,
`.rds`, and large CSVs are ignored by default.

If a script is reusable package-wide validation tooling, keep it in
`validation/` or `scripts/ci/`. If it is method-specific dev tooling, put it in
`dev/methods/<method>/ci/`. If it exists only to build one report, keep it
beside that report under `scripts/`.

## Routing current root-level directories

The final migration should decompose the existing root-level development
directories by content type. Do not simply rename a grab-bag into another
grab-bag.

Suggested routing:

```text
audit_artifacts/
  -> dev/methods/<method>/audit_artifacts/

audit_contracts/
  -> dev/methods/<method>/audit_contracts/

audits/
  -> dev/methods/<method>/audits/

phase_handoffs/
  -> dev/methods/<method>/handoffs/

project_briefs/
  -> dev/project_briefs/
  -> dev/methods/<method>/specs/
  -> dev/methods/<method>/audit_contracts/
  -> dev/notes/<method>/
  -> dev/notes/tutorials/ or dev/notes/foundations/

split_handoffs/
  -> dev/methods/<method>/handoffs/
  -> dev/methods/<method>/runs/
  -> dev/methods/<method>/reports/
  -> dev/methods/<method>/results/
  -> dev/methods/<method>/audit_contracts/
  -> dev/shared/data/
  -> dev/shared/registries/
```

The current `split_handoffs/` directory contains handoffs, run directories,
dataset specs, contracts, experiment catalogues, reports, tables, and result
bundles. It should be decomposed during migration.

## Routing examples from current `project_briefs/`

Binding specs and audit-authority documents:

```text
lps_experimental_plan_2026-06-09.tex
  -> dev/methods/lps/specs/

lps_tiers1to4_agent_prompts_2026-06-11.md
lps_tiers1to4_contract_2026-06-11.md
lps_tier*_implementer_prompt_*.md
lps_*work_order*.md
lps_*acceptance*.md
  -> dev/methods/lps/audit_contracts/
```

Use `specs/` for the science and experiment definition. Use
`audit_contracts/` for the governance layer: prompts, work orders, gate
definitions, acceptance criteria, and tightening contracts.

Generated LaTeX byproducts:

```text
*.aux
*.log
*.out
*.toc
*.fdb_latexmk
*.fls
*.tmp
.auctex-auto/
  -> delete if reproducible
  -> keep ignored by global byproduct patterns
```

Do not create `dev/build/` for retained byproducts. It will become an
unmaintained junk drawer. Keep `.tex` sources tracked in the appropriate note
or spec directory. Track `.pdf` only when it is a referenced deliverable or
audit evidence.

Expository notes:

```text
effective_degrees_of_freedom_*
lps_chart_nerve_substrate_*
local_dimension_regularization_*
foundations_of_linear_models_*
cot_bridge_*
  -> dev/notes/foundations/
  or dev/notes/tutorials/
```

LPS-specific implementation/design notes:

```text
notes only about LPS API, backend policy, test strategy, or validation design
  -> dev/notes/lps/
```

## Tracked-vs-ignored policy

Default tracked:

- `dev/README.md`
- `dev/scripts/build_dev_dashboard.py`
- `dev/project_briefs/**/*.md`
- `dev/shared/**/*.md`
- small `dev/shared` manifests, schemas, registries, and fixture definitions
- `dev/notes/**/*.md`
- `dev/methods/*/specs/**/*.md`
- `dev/methods/*/audit_contracts/**/*.md`
- `dev/methods/*/audits/**/*.md`
- `dev/methods/*/handoffs/**/*.md`
- report source scripts or source documents
- small report manifests or README files with run IDs and headline numbers
- rendered HTML/PDF only when cited by an audit or acceptance record
- small CSV summaries only when they are durable evidence and intentionally
  reviewed

Default ignored or externalized:

- `dev/html/` generated dashboard files.
- `dev/index.html` generated dashboard redirect.
- `dev/methods/*/audit_artifacts/**` except selected manifests or `.gitkeep`.
- `dev/methods/*/runs/**` except selected manifests or small status files.
- bulky `dev/methods/*/reports/**/report_files/` or widget asset directories.
- exploratory rendered reports, unless cited as audit evidence.
- `.rds`, `.RDS`, model objects, large CSVs, and raw generated results.
- LaTeX build byproducts: `.aux`, `.log`, `.out`, `.toc`, `.fls`,
  `.fdb_latexmk`, `.synctex.gz`.

Possible tracked exceptions should be explicit in the local README or manifest.

## Dashboard policy

The generated dashboard should index:

- `dev/notes/**/*.md`
- `dev/project_briefs/**/*.md`
- selected report entry points under
  `dev/methods/*/reports/**/*.{html,pdf}`

The dashboard should remain a navigation surface, not the canonical source.
Canonical content remains in Markdown notes, specs, reports, manifests, and
audits.

Generated dashboard files should be marked:

```text
Generated by dev/scripts/build_dev_dashboard.py. Do not edit by hand.
```

Track the generator and the source files it indexes. Do not track generated
dashboard output. Generated dashboards go stale and create noisy diffs on every
rebuild. If a browsable dashboard is needed without a build step, publish it to
a separate site or `gh-pages`-style branch rather than carrying generated
dashboard HTML on the main development branch.

## Migration timing

Do not move existing root-level development directories until active
`geosmooth-*` worktrees have merged.

Safe before merge:

- Create `dev/` scaffold.
- Add README files and `.gitkeep` placeholders.
- Add dashboard generator.
- Tell agents where new reports should go.

Post-merge migration:

1. Confirm active worktrees have landed.
2. Create a dedicated branch for the layout migration.
3. Use `git mv` for tracked files.
4. Decompose grab-bag directories by content type.
5. For files now covered by the ignore policy, use `git rm --cached` rather
   than `git mv`; moving a tracked `.rds`, `.aux`, or bulky asset keeps it
   tracked.
6. Update `.gitignore` and `.Rbuildignore`.
7. Rebuild the `dev/` dashboard locally.
8. Sweep references to old paths.
9. Run focused checks.
10. Commit as one atomic layout migration.

## Reference sweep checklist

Search for old paths after moving:

```sh
rg "audit_artifacts|audit_contracts|audits|phase_handoffs|project_briefs|split_handoffs"
```

Check likely affected areas:

- `scripts/`
- `scripts/ci/`
- `validation/`
- `.github/workflows/`
- `tests/`
- `dev/`
- audit contracts and handoffs
- report source scripts
- generated manifests
- harness/probe scripts with `OUT=...` paths
- execution-artifact contracts with documented expected paths
- absolute paths in agent prompts and reading lists

Update CI `paths:` filters and any harness output directories if they refer to
old top-level locations.

## Concurrent worktree hygiene

For concurrent agent Git and filesystem discipline, follow the canonical Codex
workflow:

```text
/Users/pgajer/.codex/notes/workflows/isolated_agent_worktree_hygiene.md
```

This design document owns the `geosmooth/dev` layout. The worktree hygiene note
owns multi-agent operating rules.

For `geosmooth`, the practical implications are:

- Agents write only inside their assigned `geosmooth-*` worktree and branch.
- Agents do not edit the shared main checkout or sibling worktrees.
- Agents should place new reports, manifests, and method-specific artifacts
  using the target `dev/methods/<method>/...` conventions inside their assigned
  worktree.
- Handoffs and report manifests should record worktree path, branch, base
  commit, final commit, final `git status --short`, exact commands, generated
  artifact paths, and limitations.
- The final root-directory migration should wait until active worktree branches
  have landed, then happen as one dedicated layout commit.

## Current decisions

- Track the dashboard generator and indexed source files, not generated
  `dev/html/` output or `dev/index.html`.
- Do not create `dev/build/`; delete reproducible build byproducts during
  migration.
- Use R source-file stems as canonical method directory keys.
- Track report source and small manifests. Track rendered HTML/PDF only when
  cited as audit evidence.
- Keep cross-method specs in one canonical `dev/shared/specs/` home and link to
  them from methods. Reference, do not copy.
