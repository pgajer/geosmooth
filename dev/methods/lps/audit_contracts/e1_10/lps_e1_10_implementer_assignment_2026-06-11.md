You are the implementer for the LPS Tiers 1–4 program in the `geosmooth` R package. Your standing
role, conventions, and deliverable discipline are the **implementer block** of
`project_briefs/lps_tiers1to4_agent_prompts_2026-06-11.md` — they apply here unchanged. This is your
next assignment after E1.9, **continuing on the same branch and worktree**.

## First — verify your isolation

```sh
pwd                          # …/geosmooth-e19
git branch --show-current    # MUST be codex/geosmooth-e1-9-bandwidth-multiplier
git rev-parse --short HEAD   # expect d231bb1 (E1.9 work + the accepted E1.9 audit verdict)
git status --short           # MUST be empty
```

E1.9 is audited and accepted (E1.9a/E1.9b GATEs; E1.9c study deferred to the DGP library). Build E1.10
on top of this branch — commit here, never stash. Every new argument/behavior defaults **bit-for-bit**
to current behavior, regression-pinned by a GATE (contract §A2).

## Reading

- Contract **§B / E1.10** and **§A** (GATE/STUDY/PROMOTION typing, evidence bundle, matching):
  `project_briefs/lps_tiers1to4_contract_2026-06-11.md`
- Plan **§E1.10** and **§sec:paired** (matched-arm protocol):
  `dev/methods/lps/specs/lps_experimental_plan_2026-06-09.tex`
- **Amendment 1** (the DGP library your Part B consumes).

## Assignment — E1.10: nested and grouped cross-validation

Two claims (plan §E1.10): (a) the selected-minimum CV score is optimistic; **nested CV** corrects it
and tracks held-out test error. (b) random K-fold underestimates error under cluster dependence;
**leave-cluster-out CV** closes the gap. Split into code-now and study-on-DGP.

**Part A — code-now (machinery + leakage GATEs, NO DGP-library draw):**

- Implement **nested CV** (outer 5-fold; inner 5-fold for selection) and **grouped / leave-cluster-out**
  `foldid` (folds built by cluster id). Additive; the existing CV path stays unchanged and
  regression-pinned (§A2).
- Deterministic **GATEs** on small inline fixtures (no DGP library needed):
  1. **No selection leakage** — the held-out outer fold never enters inner selection (the inner loop
     sees only inner-training indices).
  2. **Cluster integrity** — every cluster lies wholly within one fold; train and any held-out fold
     share no cluster.
  3. **Paired discipline** — the *same* `foldid` is handed to both arms of a comparison (§sec:paired).
- These land now and are your first deliverable.

**Part B — study-on-DGP (GATED on the audited DGP library):**

- (a) **Optimism study**, generator `dgp.g3a`: `n=800` train + `n_test=4000` independent test, `R=40`;
  statistic `|rmse_• − rmse_test| / rmse_test` for `• ∈ {selected-min, nested}`.
  **GATE:** nested relative error `< 0.10` **and** nested `≥` selected-min in expectation (optimism
  sign correct).
- (b) **Grouped-CV study**, generator `dgp.g5`: `K=40` clusters, `m=20`, `ρ ∈ {0.3, 0.6}`, a
  fresh-cluster test set, `R=40`. **GATE:** random-fold relative error exceeds cluster-fold by a
  predeclared margin (`> 0.10` at `ρ=0.6`); cluster-fold within `0.10` of fresh-cluster truth.
- **Safeguards:** test clusters disjoint from training clusters (no cluster in both); identical truth
  across arms; report the realized `ρ`.
- Both `dgp.g3a` and `dgp.g5` are **frozen in the registry** (`inst/dgp_registry/`), so Part B
  unblocks the moment the **DGP-library audit** accepts G3a and G5. Build and smoke the harness now on
  a tiny inline fixture, but **do not run the acceptance study until the orchestrator confirms the DGP
  audit is clear.** Consume the registry generators — do **not** hand-roll G3a/G5.

**Mutation (the auditor's job, not yours):** leaking the outer-test fold into inner selection must
collapse nested toward selected-min; splitting a cluster across folds must erase the random-vs-cluster
gap. Do not run your own mutation as acceptance evidence.

## Deliverables

Per part: the code; `testthat` GATEs (Part A) and/or `validation/` STUDY scripts + `reports/`
(Part B); an execution bundle on a clean committed tree (Tier-0 harness pattern — checksums,
`sessionInfo`, BLAS, full arg lists, seeds, realized quantities); and a handoff at
`dev/methods/lps/handoffs/phase/e1_10_implementer_handoff_<date>.md` that is **facts and admissions only**, with a
mandatory **"Limitations and unverified claims"** section. Part A is acceptable as the first
deliverable; Part B follows when the DGP audit clears. Hand off to the auditor; do not run your own
mutation.
