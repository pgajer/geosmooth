# E1.10 Part B — re-run work order (complete + bundle the acceptance studies)

Date: 2026-06-14. To the E1.10 implementer (worktree `geosmooth-e19`, branch
`codex/geosmooth-e1-9-bandwidth-multiplier`, tip `ce4d558`). Responds to the Part B audit
`audits/e1_10_partB_audit_2026-06-14.md` (**Reject — incomplete acceptance bundle**). The original
ratified spec is `project_briefs/lps_e1_10_partB_work_order_2026-06-12.md`; this supersedes only its
run/deliver steps.

## What this is, and isn't

The rejection is **not** about the science or the source. The audit already accepted/confirmed:

- **Part A** — accepted and banked (machinery + leakage/cluster/paired gates).
- **[P3] fold-count validation** — accepted (live checks error on `2.9`).
- **[P1] SE guard** — source now gates on **both** `se.rel.nested` and `se.optimism.delta`; correct (it
  could not be mutation-qualified only because the bundle was invalid).
- **Study (a) machinery + numbers** — parameters match the work order; the auditor recomputed the verdict
  cells from the raw cases to ~15 digits.
- **DGP library** — `dgp.g3a` / `dgp.g5` already on this branch (merged at `88b39d2`); Study (a) ran
  against the registry generators.

The **only** failure is an **incomplete, uncommitted bundle**: Study (a) wrote at 16:40 on 6-12, but
**Study (b) and the run metadata were never written**, `reports/e1_10_acceptance/` is **untracked**, and
there is no manifest / checksums / sessionInfo / BLAS. The auditor correctly stopped at the prerequisite
and did not run the mutation table. Your task is to **complete the run and deliver a clean, committed,
complete bundle** — nothing in the source changes.

## Scope guard — do NOT merge current `main`

Re-run on the **current e19 tip (`ce4d558`)**. **Do not merge `main`** as part of this task. Current
`main` (`678565c`) now carries t4 + t2; pulling it is the **later reconciliation step** (integration plan
§2b) and would change the code under test. The DGP library you need is already present from the earlier
dgp-only `main` merge (`88b39d2`). Keep the Part B re-run and the reconciliation strictly separate.

## Step 1 — clean, audited tree

1. **Remove the untracked partial outputs** so the run starts clean. `git status --short` should show only
   `?? reports/e1_10_acceptance/` (the Study (a) leftovers) plus the untracked audit report. Delete
   `reports/e1_10_acceptance/` — it will be regenerated complete.
2. **Bank the audit verdict** (as the t2 verdicts were banked):
   `git add audits/e1_10_partB_audit_2026-06-14.md && git commit -m "Add E1.10 Part B audit verdict (reject — incomplete bundle)"`.
3. **Confirm the source is the audited source** — the re-run must not alter it. Verify these match the
   hashes the audit recorded (its *Bundle Validity* section): `R/lps.R` `588762790b…`,
   `R/lps_cv_utils.R` `db1e6fdb…`, `validation/e1_10_nested_grouped_cv.R` `98c0a3f7…`,
   `tests/testthat/test-lps-nested-grouped-cv.R` `8bd66a2f…`. After step 1–2, `git status --short` must be
   empty.
4. **Sanity:** full `testthat` suite green (E1.9 + E1.10 gates) before running anything.

## Step 2 — run BOTH studies to completion (`LPS_E110_ACCEPT=1`, ratified parameters)

- **Study (a) — optimism, `dgp.g3a`:** n = 800 train + n_test = 4000 independent test, R = 40, σ = 0.10.
  Statistic `|rmse_• − rmse_test| / rmse_test` for `• ∈ {selected-min, nested}`. Decision: nested rel-err
  `< 0.10` **and** nested `≥` selected-min in expectation, with the [P1] SE guard on **both** gated means
  (`se.rel.nested < 0.10/3` **and** `se.optimism.delta < 0.10/3`), else **INCONCLUSIVE**.
- **Study (b) — grouped CV, `dgp.g5`:** K = 40 train clusters, m = 20, ρ ∈ {0.3, 0.6}; fresh test
  K_test = 100 × m = 20 (n_test = 2000), disjoint from training; R = 40. **Nested** estimate under both
  foldings as primary. Decision: random-fold rel-err exceeds cluster-fold by `> 0.10` at ρ = 0.6, and
  cluster-fold within `0.10` of fresh-cluster truth. Record the realized ρ **per replicate**.

**Make sure Study (b) actually completes** — this is exactly where the prior run stopped. The grouped study
is the heavier one (fresh test 2000 × R = 40). If it does not write its outputs, **find the cause**
(timeout, memory, or a silent error in the grouped path) and fix it; do not relaunch blind or hand over a
second Study-(a)-only directory. **Do not run any mutation** — the auditor owns that.

## Step 3 — the acceptance bundle (clean, committed, complete)

All five files under `reports/e1_10_acceptance/`:

- `e1_10_a_optimism_cases.csv`, `e1_10_a_optimism_verdict.csv`
- `e1_10_b_grouped_cases.csv`, `e1_10_b_grouped_verdict.csv`
- `e1_10_run_metadata.txt`

Bind the bundle to the run with a manifest recording: `git_head` (the commit you certify), a **clean**
`git_status`, **source checksums**, `sessionInfo()`, BLAS/LAPACK identification, the generator **seeds**,
and the **realized ρ** per replicate. **Commit the bundle** — it must be tracked (the previous
submission's fatal flaw was an untracked directory). Leave the worktree clean afterward except the
(now-committed) audit report.

## Step 4 — handoff

Write the implementer handoff with the realized verdicts (Study (a), Study (b), [P1], [P3]) and the bundle
location/commit. **One thing to record explicitly:** the prior Study (a) had only **1 of 40**
`optimism.delta` values nonzero — on `dgp.g3a`, nested and selected-min pick the same configuration almost
always, so intrinsic optimism is ≈ 0 (the rule still passes; nested correctly adds no *spurious*
optimism). If your re-run shows the same near-degeneracy, **report how many of the R deltas are nonzero**
so the re-audit can confirm the **leakage mutation is non-vacuous** (that leaking the outer fold actually
produces measurable optimism on this DGP). This is a heads-up to record, not a fix — do **not** change the
generator or the decision rule.

## Deliver → re-audit

The Part B re-audit (`project_briefs/lps_e19_partB_auditor_assignment_2026-06-14.md`) re-fires on the valid
bundle: it runs the full mutation table that was blocked last time — leakage (optimism-sign), cluster
integrity (the random-vs-cluster gap), the [P1] SE-guard forcing **INCONCLUSIVE**, and [P3] erroring on
fractional folds — **plus** the leakage-mutation non-vacuity check above. When it clears, **E1.10 is
complete**, and e19 proceeds to its **reconciliation merge against the already-merged t2** (integration
plan §2b — e19 is now the *second* `R/lps.R` branch, reconciling against t2; the original work order's
"first to merge, ahead of t2" ordering is superseded).
