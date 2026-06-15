# LPS worktree → main integration plan

Date: 2026-06-12, refreshed 2026-06-14. Four feature worktrees forked from `b86b796`. Goal: land each
on `main` with the single `R/lps.R` reconciliation planned, not stumbled into.

**Current state.** `main` = `41dc962` — **dgp and t4 merged** (base + DGP + E4.1). `main`'s `R/lps.R` is
still the **base** (neither dgp nor t4 touched it). **t2** is **fully accepted** — E2.12/E2.13/E2.14/E2.15
mutation-qualified (`tier2_combined_reaudit_2026-06-13`), the Tier-0 E0.6 re-open re-accepted, and the
E0.6 fallback-bound hardening accepted (`e0_6_fallback_bound_audit_2026-06-14`; the all-fallback path
now reddens E0.6). **e19** has E1.9 ✅ + E1.10 Part A ✅ + the P1/P3 fixes, but its **E1.10 Part B
acceptance run is still pending** (current tip only wired the bundle).

**The order flips.** Because e19 isn't ready and t2 is — and because `main`'s `R/lps.R` is still the
base — **t2 → main is a clean merge right now**, and the single `R/lps.R` reconciliation moves to
**e19's** later merge (e19 becomes the second lps.R branch, reconciling against t2).

## TL;DR order

```
dgp ✅  →  t4 ✅  →  t2  →  e19
(merged)  (merged)  (clean now)  (the one reconciliation)
```

dgp and t4 are in. **t2 merges clean now** (nothing in `main` touches its `R/lps.R` regions). **e19 is
last and carries the reconciliation**: once its Part B audit clears, e19 re-syncs `main` (gets t4 + t2),
resolves the top-of-`fit.lps` overlap against t2's edits **inside the e19 worktree**, runs the suite,
then fast-forwards `main`. Each branch still merges only after its audit accepts.

## Principles

1. **Audit-gated.** Nothing reaches `main` until its independent audit accepts. Status: dgp ✅ merged;
   t4 ✅ merged; **t2 ✅ fully accepted** (ready to merge); e19 E1.9 ✅ / E1.10 Part A ✅ / **Part B run +
   audit pending**.
2. **Clean branches first.** `dgp` and `t4` are additive (no `R/lps.R`) — already in.
3. **One reconciliation, not three.** Only `e19` and `t2` modify `R/lps.R`. Whichever merges **second**
   absorbs the union. With t2 going first (clean), **e19 is the one that reconciles**.
4. **Resolve-in-branch, then fast-forward.** Pull updated `main` *into* the feature worktree, resolve +
   run the suite there, then advance `main`. Never resolve `R/lps.R` blind on `main`.

## Conflict matrix

| Branch | Touches `R/lps.R` | Audit status | Merge gate | Conflict |
|---|---|---|---|---|
| **dgp** | no | ✅ accepted | **✅ MERGED** | done |
| **t4** | no (additive) | Part A ✅ + Part B ✅ | **✅ MERGED — `41dc962`** | done |
| **t2** | **yes** | ✅ E2.12/13/14/15 + E0.6 amend + E0.6 fallback-bound | **ready — clean now** (`main` lps.R is base) | none right now |
| **e19** | **yes** (+ `lps_cv_utils.R`) | E1.9 ✅; E1.10 Part A ✅; **Part B run + audit pending** | after Part B audit | **reconcile vs t2** (top-of-`fit.lps`) |

## Phase 0–1 — dgp, t4 ✅ DONE

`dgp` merged (the shared base + DGP library); `t4` merged (E4.1 bands, additive). `main` = base + DGP +
E4.1, with `R/lps.R` still untouched by any feature branch.

## Phase 2 — the two `R/lps.R` branches

### 2a. First lps.R branch — t2 (clean now)

t2 is fully accepted and `main`'s `R/lps.R` is still the base, so **t2 → main has nothing to reconcile
against — a clean merge commit** (t2 doesn't contain `main`'s DGP+E4.1, but those are disjoint files;
expect at most a trivial `DESCRIPTION`/`NAMESPACE` union). Steps (commit the untracked t2 verdicts
first; `main` isn't checked out anywhere, so use a throwaway worktree):

```sh
cd ~/current_projects/geosmooth-t2 && git add audits/ && git commit -m "Add Tier-2 + E0.6 audit verdicts"
cd ~/current_projects/geosmooth && git worktree add /tmp/gm main && cd /tmp/gm
git merge codex/geosmooth-t2-binary-hygiene
Rscript -e 'pkgload::load_all("."); testthat::test_dir("tests/testthat")'   # E0.x + E2.x green
git push origin main && cd ~/current_projects/geosmooth && git worktree remove /tmp/gm
```

After this, `main`'s `fit.lps` carries t2's binary/ridge edits (E2.12/13/14/15) and the amended E0.6.

### 2b. Second lps.R branch — e19 (the one reconciliation)

Once the E1.10 Part B audit clears, e19 merges last and **does the reconciliation against t2**. The
overlap is the same top-of-`fit.lps` region the plan always flagged — now unioning **three** argument
additions and the CV-grid:

| Region (≈ old-file lines) | What's there | How to resolve |
|---|---|---|
| `fit.lps` signature | e19's `bandwidth.multiplier.grid` + t2's `ridge.shrinkage.target` (+ other E2 args) | **Union** the new arguments; each defaults bit-for-bit (§A2), so it's an additive union. |
| argument cleaning/validation | per-argument cleaning for each new arg | Union; order-independent. |
| CV candidate-grid construction | e19 added the bandwidth axis (partly in `lps_cv_utils.R`); t2 expanded for clip/ridge | Combine so the grid spans **both** axes without double-counting. |

Everything else is **disjoint** and coexists: e19's kernel-weight/bandwidth body and `lps_cv_utils.R`;
t2's IRLS/binary body and selection-metric. No logic clash.

**Tactic — resolve in the e19 worktree, then fast-forward main:**

```sh
cd ~/current_projects/geosmooth-e19
git merge main                       # pull t2's lps.R changes in; resolve ONLY the top-of-fit.lps hunks
# … union the args / CV grid in R/lps.R …
Rscript -e 'pkgload::load_all("."); library(testthat); test_dir("tests/testthat")'   # E1.9/E1.10 + E2.x + Tier-0 ALL green
git commit
git branch -f main codex/geosmooth-e1-9-bandwidth-multiplier && git push origin main   # fast-forward
```

The e19 implementer/auditor (or a dedicated integrator) owns this — they reconcile their bandwidth/CV
code against t2's already-merged binary/ridge code.

## Phase 3 — re-audit the integrated `fit.lps` (do not skip)

The merged `fit.lps` is a **new artifact neither audit saw.** Run the **combined gate battery on
post-merge `main`**: E1.9a/E1.9b + E1.10 + E2.12/E2.13/E2.14/E2.15 + the full Tier-0 set (incl. the
amended E0.6) must all be green. Each gate defaults bit-for-bit, so a union that silently drops a
behavior reddens. A green full-suite run on merged `main` is the acceptance criterion.

## Phase 4 — docs + dev/ reorg (the tail)

1. **Consolidate the planning docs onto `main`.** The contract / briefs / experimental-plan / the new
   design notes (per-point scale, LDS, the v2 program plan) live on `tier0-bucket2` and partly on `e19`,
   with untracked copies in the main checkout. Reconcile to a **single canonical copy** on `main`.
2. **Execute the dev/ reorg** per `dev/geosmooth_dev_target_structure_design.md`, after all code + docs
   land. (t2 already renders its report under `dev/methods/lps/reports/…`.)

## One-line status (refreshed 2026-06-14)

- [x] **dgp → main ✅ MERGED**
- [x] **t4 → main ✅ MERGED** (`41dc962`; Part A + Part B accepted, additive)
- [ ] **t2 → main**: ✅ fully accepted (E2.12/13/14/15 + E0.6 amend + E0.6 fallback-bound) — **merges CLEAN now**
- [ ] **e19**: E1.9 ✅ + E1.10 Part A ✅; **Part B run + audit pending** → then e19 → main (**reconcile vs t2**, resolve-in-e19)
- [ ] re-audit merged `fit.lps` on `main` (full gate battery green)
- [ ] docs consolidation + dev/ reorg
