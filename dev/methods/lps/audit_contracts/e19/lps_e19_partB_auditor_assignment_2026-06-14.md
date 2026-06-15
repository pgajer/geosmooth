You are the independent auditor for the LPS Tiers 1–4 program in the `geosmooth` R package. Your
standing role, rules, deliverable shape, and do-not list are in
`/Users/pgajer/current_projects/geosmooth/project_briefs/lps_e19_auditor_prompt_2026-06-11.md`
(everything above its "FIRST ASSIGNMENT" heading) — read it first; it applies unchanged. The program
docs are committed on this branch (read them in place): `dev/methods/lps/specs/lps_experimental_plan_2026-06-09.tex`
(§E1.10), `project_briefs/lps_tiers1to4_contract_2026-06-11.md` (§A, §B). The **acceptance spec** for
this pass is the orchestrator ratification + work order
`/Users/pgajer/current_projects/geosmooth/project_briefs/lps_e1_10_partB_work_order_2026-06-12.md`.

This is the **E1.10 Part B audit**. **Part A is already accepted** (`audits/e1_10_audit_2026-06-12.md`,
machinery + leakage/cluster/paired gates). Scope here: the two **acceptance studies** on the audited
DGP library, plus the **[P1]/[P3] fixes** from the Part A audit. Out of scope: Part A's machinery gates
(already done) and anything t2 — the e19↔t2 `R/lps.R` reconciliation is a separate merge step *after*
this audit accepts (see the bottom note).

## Prerequisite (implementer, before this audit)

The studies' **acceptance bundle** is the implementer's deliverable: it runs Study (a) and Study (b) at
the ratified parameters with `LPS_E110_ACCEPT=1` on the audited `dgp.g3a`/`dgp.g5`, on a clean committed
tree, with a handoff. The pre-existing `reports/e1_10_smoke/` outputs are **smoke, not acceptance** — do
not audit those as the verdict. If the acceptance bundle is absent, STOP and tell the orchestrator.

## Run in place — no separate worktree

The implementer is done by audit time; the worktree is free at the e19 tip.

```sh
cd ~/current_projects/geosmooth-e19
git rev-parse --short HEAD     # RECORD the SHA you certify
git status --short             # MUST be empty
```

Mutate `R/lps.R` / `R/lps_cv_utils.R` transiently and `git checkout -- <file>` after each; never commit.

## What to verify (plan §E1.10, ratified in the work order)

**Study (a) — optimism, generator `dgp.g3a`** (n=800 train + n_test=4000 independent test, R=40).
Statistic `|rmse_• − rmse_test| / rmse_test` for `• ∈ {selected-min, nested}`. Decision (a STUDY rule):
**nested relative error `< 0.10`** *and* **nested `≥` selected-min in expectation** (optimism sign
correct), and — the **[P1] fix** — the verdict is **INCONCLUSIVE unless both gated means meet the SE
guard**, i.e. `se.rel.nested < 0.10/3` *and* `se.delta < 0.10/3` (`validation/e1_10_nested_grouped_cv.R`).

**Study (b) — grouped CV, generator `dgp.g5`** (K=40 train clusters, m=20, ρ∈{0.3,0.6}; fresh test
K_test=100×m=20 = n_test=2000, disjoint from training; R=40). Primary statistic = the **nested**
estimate under each folding (the ratified choice). Decision: **random-fold relative error exceeds
cluster-fold by `> 0.10` at ρ=0.6**, and **cluster-fold within `0.10` of fresh-cluster truth**; the
realized ρ is reported.

**[P3] fix** (`R/lps_cv_utils.R`): the exported `lps.grouped.foldid()` / `lps.nested.cv()` **reject**
non-whole or non-scalar fold counts (e.g. `2.9`) with an error, instead of silently truncating.

## Judge the implementer's acceptance bundle (do not produce it)

Per the role split: the R=40 acceptance runs are the **implementer's** evidence. Judge the bundle —
clean committed tree, checksums, coverage, both verdict rows present and labeled `acceptance` (not
`smoke`), the studies bound to the **audited** `dgp.g3a`/`dgp.g5` (registry SHA-verified, no hand-rolled
generator) — and **independently reproduce ≥1 number**: recompute one cell's nested-vs-selected-min
relative error from the bundle's raw outputs, or the random-vs-cluster gap at ρ=0.6. You need not re-run
the full R=40 studies.

## Mutation / falsification (the core — smoke scale is fine)

Run the gate file + a smoke study clean (expect green/PASS), then per row mutate, re-run, confirm the
named effect, and restore.

| Target | Mutation | Must happen |
|---|---|---|
| Study (a) — no leakage | leak the held-out outer fold into inner selection | nested stops correcting optimism → nested rel-err collapses toward selected-min and the **optimism-sign / `nested<0.10`** decision reddens |
| Study (b) — cluster integrity | break `lps.grouped.foldid()`'s whole-cluster property (split a cluster across folds) | the random-vs-cluster **gap collapses** → the `>0.10 at ρ=0.6` decision reddens |
| **[P1] SE guard** | inflate `se.delta` (make the optimism-delta mean too noisy) | the verdict must flip to **INCONCLUSIVE**, not PASS — proves the guard covers *both* gated means |
| **[P3] validation** | call `lps.grouped.foldid(v = 2.9)` (or `lps.nested.cv(inner.folds = 2.9)`) | it **errors**, not silently uses 2 |

Also confirm by reading the code: the **paired discipline** (same `foldid` to both arms) is structurally
enforced by `lps.nested.cv` (a Part-A property; verify it still holds in the studies), and Study (a)/(b)
consume the registry generators, not inline fixtures.

## Deliver

`audits/e1_10_partB_audit_<your-run-date>.md` per the standing Deliverable shape: a verdict for **Study
(a)** and **Study (b)** (accept / inconclusive / reject — these are STUDY decision rules), confirmation
of the **[P1]** SE-guard fix (the mutation forces INCONCLUSIVE) and the **[P3]** validation fix, the
mutation table, the audited-DGP-consumption check, and your reproduced number. Leave it untracked for
the orchestrator.

**After this accepts:** E1.10 (and so e19) is content-complete. e19 then becomes the **second `R/lps.R`
branch** and does the one reconciliation against the already-merged t2 — a separate merge step in the
e19 worktree (integration plan §2b), not part of this audit.
