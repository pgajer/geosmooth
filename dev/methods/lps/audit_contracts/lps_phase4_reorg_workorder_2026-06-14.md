# Phase 4 — dev/ reorganization work order (one atomic layout migration)

Date: 2026-06-14. To the reorg implementer (works on the `geosmooth` repo on the host; **not** in the
sandbox). The design authority is `dev/geosmooth_dev_target_structure_design.md` — read it first; it owns
the target layout, the routing rules, and the tracked-vs-ignored policy. This work order maps the **current
artifacts** onto that schema and fixes the procedure. Precondition met: all `geosmooth-*` worktrees have
merged (`main = 5d1d837`, Phase-3 Pass-2 ACCEPTED; `fee9485` is the integrated code tip before the
evidence/handoff commit). (This work order itself is an `audit_contract` and
moves to `dev/methods/lps/audit_contracts/` in the migration.)

Out of scope: the **E2.13 §A2-reference extension** (the unsafe/fallback bit-for-bit fixtures) — that is a
separate code+test+audit task, not a file move; see the closing note.

## 0. Branch, and gather the committed history first

```sh
cd ~/current_projects/geosmooth
git switch main && git pull --ff-only      # ensure main = 5d1d837 (or the pushed tip)
git switch -c chore/dev-layout-migration
# If needed only: merge codex/geosmooth-e1-9-bandwidth-multiplier.
# Current expected state: main, origin/main, and codex/geosmooth-e1-9-bandwidth-multiplier
# are already at 5d1d837, so this merge is normally a no-op.
```

After this the branch has **all** committed doc/evidence history plus the untracked working docs. Do the
entire migration on this branch; commit once at the end.

## 1. Untracked working docs → `dev/` (concrete mapping; `git add` in the new location)

These ~40 files are untracked on `main`, so place them in the destination and `git add` (no `git mv`).

**`dev/methods/lps/audit_contracts/`** — governance (prompts, work orders, auditor assignments, contracts,
ratifications, adjudications, amendments):
`lps_tiers1to4_agent_prompts_*`, `lps_tiers1to4_contract_*`, `lps_tier2_implementer_prompt_*`,
`lps_tier4_implementer_prompt_*`, `lps_dgp_library_implementer_prompt_*`, `lps_dgp_auditor_assignment_*`,
`lps_t2_auditor_assignment_*`, `lps_t2_reaudit_e2_12_13_14_assignment_*`, `lps_t2_combined_reaudit_*`,
`lps_t2_e2_13_work_order_*`, `lps_t4_auditor_assignment_*`, `lps_e19_auditor_prompt_*`,
`lps_e19_partB_auditor_assignment_*`, `lps_e19_partB_reaudit_addendum_*`, `lps_e19_reconciliation_workorder_*`,
`lps_e1_10_implementer_assignment_*`, `lps_e1_10_partB_work_order_*`, `lps_e1_10_partB_rerun_work_order_*`,
`lps_e1_10_bprime_adjudication_workorder_*`, `lps_e0_6_fallback_hardening_*`,
`lps_e2_15_binomial_na_consistency_amendment_*`, `lps_e2_15_e06_adjudication_*`, `lps_e4_1_k_ratification_*`,
`lps_e4_1_spec_questions_resolution_*`, `lps_g4_ridge_resolution_*`, `lps_phase3_merged_main_reaudit_*`
(the *assignment*), `lps_phase3_pass2_auditor_assignment_*`, `lps_lds0_implementer_work_order_*`, **this
work order**.

**`dev/methods/lps/specs/`** — frozen science/experiment definition:
`lps_experimental_plan_2026-06-09.tex` (if tracked, `git mv`), `lps_lds_design_and_test_plan_2026-06-13.{tex,pdf}`.

**`dev/methods/lps/audits/`** — audit reports (the two now untracked in `audits/`, plus everything gathered
in §2): `audits/phase3_merged_main_reaudit_2026-06-14.md`, `audits/phase3_pass2_reaudit_2026-06-14.md`.

**`dev/methods/lps/status/`** — orchestrator finding/closure records:
`lps_e1_10_grouped_cv_closure_2026-06-14.md`. *(Routing call: `status/` recommended; use `audits/` if you
prefer it filed as an acceptance record.)*

**`dev/notes/lps/`** — LPS-specific design/implementation notes:
`lps_per_point_scale_sketch_2026-06-13.md`.

**`dev/project_briefs/`** — repo/program-level coordination:
`lps_integration_plan_2026-06-12.md`, `lps_program_plan_of_action_2026-06-13.{tex,pdf}`,
`lps_program_plan_of_action_2026-06-10.tex`. *(Routing call: the program plan spans LPS+LCov+capstone, so
`dev/project_briefs/` is recommended over `dev/methods/lps/specs/`; flip if you consider it LPS-only.)*

**`dev/methods/lcov/specs/`** (new method dir) — the local-covariance design:
`chart_aware_local_association_design_2026-06-09.{tex,pdf}`. *(Routing call: a new `dev/methods/lcov/`
directory is recommended, since this is the LCov method spec; the alternative is `dev/notes/foundations/`
if you'd rather treat it as a design note until LCov is a live method. Add the `dev/README.md` key→source
mapping row either way.)*

Track scaffold source files only: `dev/README.md`, method READMEs, `.gitkeep`s, the schema doc, and
`dev/scripts/build_dev_dashboard.py`. Do not track generated `dev/html/` or `dev/index.html`.
Keep `dev/geosmooth_dev_target_structure_design.md` at the `dev/` root (it is the layout authority) or move
to `dev/notes/migration/` — your call.

## 2. Tracked old-root directories → `dev/` (`git mv`, decompose by content type)

Apply the schema's routing table (§ "Routing current root-level directories") to whatever is **tracked** on
`main` in these roots — use `git status`/`git ls-files` to see what's actually tracked, then `git mv`:

- `audits/` (the merged per-gate audits: e0_6, t2, e4_1, e1_9, e1_10, dgp, …) → `dev/methods/lps/audits/`.
- `phase_handoffs/` (incl. the gathered `e1_phase2b_reconciliation_*`, `e1_10_*`, `e2_*`, `e4_1_*`, `e0_6_*`,
  `dgp_library_*`) → `dev/methods/lps/handoffs/`.
- `audit_artifacts/` → `dev/methods/lps/audit_artifacts/` — but per the tracked-vs-ignored policy, **`git rm
  --cached`** the bulky bundles (`.rds`, large CSVs, `report_files/`); keep only manifests/`.gitkeep`.
- `project_briefs/` tracked files → route with `git mv`: LPS specs to `dev/methods/lps/specs/`,
  LCov specs to `dev/methods/lcov/specs/`, repo/program briefs to `dev/project_briefs/`, and governance
  prompts/contracts/work orders to `dev/methods/lps/audit_contracts/`. This explicitly includes tracked
  `lps_experimental_plan_2026-06-09.tex`, `chart_aware_local_association_design_2026-06-09.{tex,pdf}`, and
  `lps_tiers1to4_project_brief_2026-06-11.md`.
- `reports/phase2b_reconciliation/` and `reports/e1_10_*` (the e19 run evidence) → `dev/methods/lps/runs/`
  (manifests/summaries tracked; bulky outputs `git rm --cached`).
- `split_handoffs/` is ignored/untracked locally but contains durable records. Inventory it explicitly.
  Promote selected durable `.md`, specs, manifests, small CSV summaries, and cited reports to `dev/`; leave
  bulky generated bundles ignored/externalized. Record an inventory manifest stating each retained item and
  each intentionally externalized/ignored item class so the no-loss audit can be proven.
- `validation/` → package-wide entry points stay in `validation/`; **method-specific** scripts
  (`e1_10_*`, `e2_1*`, `e4_1_*`, `e1_10_grouped_loco_bprime.R`, `e2_13_pin_reference_fits.R`) →
  `dev/methods/lps/ci/`. `scripts/ci/` method-specific helpers → `dev/methods/lps/ci/` likewise.
- LaTeX byproducts (`.aux .log .out .toc .fls .fdb_latexmk .synctex.gz`, `.tmp`, `.auctex-auto/`) → delete (they
  are reproducible and ignored).

The `.gitignore` / `.Rbuildignore` edits already in your working tree (the `dev/` rules) are part of this
commit.

## 3. Procedure (per the schema's Migration section)

1. Moves: `git mv` tracked files; place untracked docs in the new path and `git add`; `git rm --cached` for
   files now covered by the ignore policy (do **not** `git mv` a tracked `.rds`/`.aux`/bulky asset).
2. **Reference sweep** — make the sweep old-root-specific and reviewable. Search for unresolved old-root
   references such as `(^|[^A-Za-z0-9_./-])(audits|phase_handoffs|project_briefs|split_handoffs|audit_artifacts|audit_contracts)/`
   plus `^validation/` and `scripts/ci/`; allow valid `dev/...` hits. Deliver a reviewed
   `stale_path_report.txt` with zero unresolved old-root references rather than a raw generic-term search.
   Update
   across `scripts/`, `validation/`, `.github/workflows/`, `tests/`, `dev/`, audit contracts, handoffs,
   report scripts, harness `OUT=`/manifest paths, and absolute paths in agent prompts/reading lists. Update
   every stale path. Update CI `paths:` filters.
3. Rebuild the `dev/` dashboard locally (`dev/scripts/build_dev_dashboard.py`); do **not** track its output.
4. **Focused checks:** `R CMD build .` yields a clean tarball (the `.Rbuildignore` additions keep `dev/`,
   `validation/`, `scripts/` out); `R CMD check` (or at least `devtools::check()` light) has no new
   notes from moved files; spot-check that no audit/handoff cross-link is broken.
5. **One atomic commit**: `Reorganize development artifacts under dev/ (layout migration)`. Then fast-forward
   `main` and push:
   ```sh
   git switch main && git merge --ff-only chore/dev-layout-migration
   git push origin main
   ```

## 4. Deliver → short reorg audit

Hand off with: the branch/commit SHA, the count of files moved/added/`rm --cached`, the reviewed
`stale_path_report.txt` result (zero unresolved old-root references), the split-handoff inventory manifest,
and the `R CMD build` result. A **short Phase-4 audit** then confirms: the
package tarball is clean (no `dev/` leakage), the reference sweep is genuinely empty, the tracked-vs-ignored
policy is honored (no bulky `.rds`/artifact bundles newly tracked), and **no audit/handoff/spec was dropped**
(every pre-migration tracked doc is accounted for at a new path). This is a completeness/no-loss audit, not
a behavioral one — no mutation table.

## 5. Separate parallel task — E2.13 §A2-reference extension (do NOT fold into this commit)

The Pass-1/Pass-2 audits found the bit-for-bit §A2 reference covers only well-conditioned default fits. The
extension adds reference fits for the three named unsafe/fallback fixtures (near-saturated WLS;
rank-deficient orthogonal-polynomial drop; logistic `unstable.action="na"` exact-separation telemetry) and a
gate, then re-pins. That is code+test work touching `validation/e2_13_pin_reference_fits.R`
(`→ dev/methods/lps/ci/`) and `reports/e2_13_reference_fits.csv`, and it should be **audited**. Run it as its
own small work order — before or after this reorg, but as a distinct commit. (I can draft that work order
separately on request.)
