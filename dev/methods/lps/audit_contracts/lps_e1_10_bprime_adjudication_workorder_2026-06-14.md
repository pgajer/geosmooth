# E1.10 Study (b) ρ=0.6 — adjudication + Study b′ work order

Date: 2026-06-14. Part I is the orchestrator's adjudication of the re-audited ρ=0.6 FAIL; Part II is the
follow-up work order to the E1.10 implementer (worktree `geosmooth-e19`, branch
`codex/geosmooth-e1-9-bandwidth-multiplier`, tip `8e432ea`). Inputs: re-audit
`audits/e1_10_partB_reaudit_2026-06-14.md` (**accepted, mutation-qualified; ρ=0.6 FAIL genuine and
correctly implemented**), implementer handoff `phase_handoffs/e1_10_partB_implementer_handoff_2026-06-14.md`,
acceptance bundle `de0f861`.

---

## Part I — Adjudication (orchestrator decision)

**What the re-audit settled.** The Part B bundle is provenance-valid and mutation-qualified ([P1], [P3]
accepted; Study (a) PASS; leakage/cluster/SE-guard/fold-count mutations all redden). The auditor
independently reproduced the ρ=0.6 numbers and the safeguards and confirmed the **FAIL is genuine and
correctly implemented** — not a folding defect — and explicitly did **not** re-spec the rule. So the
premise for re-specification is now established by an independent check, with the goalposts having stayed
fixed for that check.

**The finding.** Claim (b)'s core is robustly validated and the FAIL is orthogonal to it:

- *Validated (first clause).* Random-vs-cluster gap `0.344` (≫ 0.10); random K-fold underestimates
  fresh-cluster error in 40/40 replicates (`mean(nested.random − test) = −0.130`); leave-cluster-out
  closes **68%** of the relative error (`0.505 → 0.161`). Random CV is optimistic under cluster
  dependence; cluster folding removes most of it.
- *Failed (second clause), for a reason orthogonal to folding.* `cluster-fold within 0.10 of truth`
  fails at `0.161`. Cluster-fold *over*estimates (`mean(nested.cluster − test) = +0.026`, positive in
  65%) because grouped 5-fold at K=40 trains each fold on **32/40 clusters**; at ICC ≈ 0.59 that ~20%
  effective-data reduction biases the estimate upward — standard **K-fold train-size pessimism**, a
  property of "K-fold trains on less data," not of cluster-vs-random folding.

**Decision.**

1. **Record the ρ=0.6 FAIL** as a documented finding (contract §A1 — a STUDY verdict is recorded, not a
   CI failure). Claim (b)'s core stands as validated.
2. **The second clause was mis-specified.** It conflated *folding-scheme correctness* (the claim — does
   cluster-folding remove dependence-induced optimism? yes) with *absolute K-fold accuracy* (a stronger
   property K-fold structurally cannot deliver at K=40/5-fold). Re-spec it for Study b′:
   - **Primary — relative-improvement criterion:** cluster-fold closes a pinned fraction of the
     random-fold's relative error (recommend ≥ 50%; observed 68%). This tests the folding scheme directly,
     independent of train-size bias.
   - **Confirmatory — leave-one-cluster-out (LOCO):** train each fold on 39/40 clusters (≈ the deployed
     train size). Prediction: the train-size bias shrinks and the absolute "within 0.10 of truth" bound
     becomes attainable — which, if it holds, *confirms* the residual was train-size bias, not a folding
     defect.
3. **Study b′ is additive and non-blocking.** It does **not** alter the ratified Study (b) (which stays
   recorded as ρ=0.6 FAIL) and does **not** gate the e19 merge: E1.10 is content-complete (bundle accepted,
   fixes mutation-qualified). b′ strengthens and contextualizes the recorded finding; it may run before or
   after the e19→t2 reconciliation.

---

## Part II — Study b′ work order (to the E1.10 implementer)

### Scope guard — no package-source change

Work on the current tip `8e432ea`. **Do not merge `main`** (reconciliation is the separate later step).
**b′ requires no change to package source:** LOCO is the existing exported utility
`lps.grouped.foldid(cluster.id, v = n_clusters)` (one cluster per fold) fed to `lps.nested.cv(...)`, and
the relative criterion is a verdict computation. `R/lps.R` and `R/lps_cv_utils.R` must stay byte-frozen
(hash-verify against the Part-B audit record). Add b′ as a **new sibling validation script** (e.g.
`validation/e1_10_grouped_loco_bprime.R`) so the ratified Study-(b) script
`validation/e1_10_nested_grouped_cv.R` also stays byte-frozen and its provenance intact.

### Generators and sizes (same as Study (b), audited registry)

`dgp.g5` from the `geosmooth` namespace (no hand-rolled generator), K=40 train clusters, m=20,
ρ ∈ {0.3, 0.6}; fresh test K_test=100 × m=20 (n_test=2000), disjoint from training; R=40. Primary
statistic = the **nested** estimate under each folding (as ratified for Study (b)). Record realized ρ per
replicate; use fresh recorded seeds (distinct from the Study (b) seeds 61000/62000).

### Three folding arms at ρ=0.6 (ρ=0.3 reported-only)

| Arm | Folding | Train per fold | Purpose |
|---|---|---|---|
| A | grouped 5-fold (carry from Study (b)) | 32/40 clusters | comparison baseline; expect rel.cluster ≈ 0.16 |
| B | **leave-one-cluster-out** (`v = 40`) | 39/40 clusters | the train-size-bias test; expect rel.cluster ↓ toward the bound |
| C (optional diagnostic) | 5-fold at K ∈ {40, 80, 160} | (K−K/5)/K clusters | show the bias → 0 as cluster count grows |

LOCO is heavier (40 folds × R=40 ≈ 8× arm A); use the daemonized launch so the run survives turn
boundaries, exactly as the re-run did.

### Decision rules for b′ (STUDY)

At ρ=0.6, with both SE guards `< 0.10/3` on the gated means (else **INCONCLUSIVE**):

- **Primary (relative-improvement):** `gap > 0.10` **and** `rel.cluster(A) ≤ (1 − f)·rel.random`, with the
  closure fraction **f = 0.50** [recommended; observed 0.68 — orchestrator ratifies f]. → expected PASS.
- **Confirmatory (LOCO absolute):** `rel.cluster(B) < 0.10` at ρ=0.6. → expected PASS; **if it FAILs**,
  that is an escalation (the absolute bound is unattainable even at minimal train-size reduction → the
  bound itself is wrong for this regime, not just for 5-fold).
- Report arm C (if run) as the quantitative confirmation that rel.cluster(5-fold) → the bound as K grows.

### Deliver → re-audit

A committed b′ bundle under `reports/e1_10_bprime/` (cases + verdicts for arms A/B[/C], `MANIFEST.txt`
with `git_head`/clean `git_status`/**source checksums showing `R/lps.R` and `R/lps_cv_utils.R`
unchanged**, `sessionInfo`, BLAS, seeds, realized ρ), plus a handoff. **Do not run mutations** (the auditor
owns them). The b′ re-audit will mutation-qualify: breaking LOCO's whole-cluster property must redden the
LOCO absolute clause, and faking the relative improvement (e.g. shrinking the random arm) must redden the
primary clause.

After b′ accepts, the E1.10 record reads: grouped CV **validated** (random-fold optimism corrected;
relative criterion met; LOCO attains the absolute bound), with the 5-fold ρ=0.6 absolute FAIL recorded and
explained as K-fold train-size bias. e19's reconciliation merge against t2 is independent of this and not
gated by it.
