# E1.10 grouped-CV closure note (Study (b) + Study b′)

Date: 2026-06-14. Final orchestrator record for the grouped cross-validation thread of E1.10. This note
**supersedes the optimistic prediction** in `lps_e1_10_bprime_adjudication_workorder_2026-06-14.md` (which
expected LOCO to attain the absolute bound and the relative criterion to pass).

Provenance: Study (b) bundle `de0f861` (re-audit `audits/e1_10_partB_reaudit_2026-06-14.md`); Study b′
bundle `92707c0`, script `2474de0` (audit `audits/e1_10_bprime_audit_2026-06-14.md`). Both bundles are
provenance-valid, mutation-qualified, and changed no package source.

## The question

Does grouped (cluster-aware) cross-validation honestly estimate the **fresh-cluster** generalization error
under cluster dependence — and by how much does it beat naive random K-fold?

## What is validated (robust across every run)

**Random K-fold is optimistic under cluster dependence, and cluster folding removes that leakage.** Random
K-fold *underestimates* fresh-cluster error in 40/40 replicates (signed bias ≈ −0.13 to −0.15); the
random-vs-cluster gap is large and positive in every run (Study (b) 0.34; b′ 0.24). This is claim (b)'s
core, and it holds qualitatively and directionally across all three runs and both folding schemes. Using
random K-fold under cluster structure would materially overstate accuracy; grouped folding is the correct
procedure.

## What is NOT attained, and why (the honest finding)

The absolute clause — **"cluster-fold within 0.10 of fresh-cluster truth"** — is **not met at K=40 clusters,
ICC ≈ 0.59**, by *either* 5-fold or leave-one-cluster-out. Study b′ was designed to test whether the
residual was the K-fold train-size bias (LOCO trains on 39/40 clusters, removing it). It showed:

- **LOCO removes the bias but not the error.** LOCO's signed bias is ≈ 0 (−0.015, positive in 50% of
  reps) versus grouped 5-fold's +0.039 — so the systematic train-size overestimate is gone. But LOCO's
  *relative error* is still **0.159 > 0.10** → a genuine FAIL on **variance**, not bias.
- **The relative-improvement criterion is INCONCLUSIVE.** Closure fraction 0.456 (< the 0.50 target) and
  both SE guards fail (≈ 0.05 > 0.033) — the estimates are too noisy to gate.
- **The quantity is variance-limited / seed-sensitive.** The same nominal statistic — grouped 5-fold
  `rel.cluster` at K=40, ρ=0.6 — lands at **0.161, 0.288, 0.121** across three seed sets (Study (b), b′
  core, b′ Arm C). It swings 0.12–0.29; no absolute bound on it is stable.
- **More clusters, not better folding, is the lever.** Arm C (diagnostic, R=10) drops to ≈ 0.05 at
  K=160, consistent with variance shrinking as the cluster count grows; but it is underpowered (K=40→80
  flat within SE), so it remains suggestive only.

**Mechanism:** at small cluster count and high ICC the effective information is ≈ the number of clusters,
so the cluster-fold estimate of fresh-cluster error carries large variance. Cluster folding fixes the
*bias* (dependence leakage and, via LOCO, train-size); it cannot fix the *variance*, which is set by the
cluster budget.

## Adjudication correction

My b′ adjudication hypothesized the Study (b) FAIL was a train-size-bias artifact that LOCO and a relative
criterion would clear. The data falsified that: the residual is variance-dominated, and neither LOCO nor
the relative criterion produced a clean PASS. The independent audit held the goalposts fixed and surfaced
this; this note records the correction. No further re-specification is warranted — re-spec'ing a third time
to force a green would be goalpost-moving, and the finding is already complete.

## Disposition

Per contract §A1, STUDY verdicts are **recorded, not CI failures**:

- Study (b), ρ=0.6: **FAIL** (absolute bound) — recorded.
- Study b′, ρ=0.6: **INCONCLUSIVE** (relative criterion) + **FAIL** (LOCO absolute) — recorded.

These do **not** block E1.10 or the e19 merge. E1.10 is **content-complete**: Part A machinery accepted,
[P1]/[P3] fixes mutation-qualified, the studies run and recorded, all bundles provenance-valid and
source-clean.

## Scientific bottom line

Grouped (cluster-aware) cross-validation is the **correct procedure** under cluster dependence: it removes
the optimism that random K-fold incurs. Its **absolute accuracy** as an estimator of fresh-cluster error is
**variance-limited at small cluster counts** — at K=40 / ICC ≈ 0.59 it cannot be pinned to within 0.10 of
truth by any folding scheme; honest absolute estimates require materially more clusters (Arm C hints
≈ K=160). This is a **design guideline**, not a method defect.

## Optional, deferred follow-up (non-blocking)

A properly powered cluster-count sweep (Arm C at full R, several K) would let the
"absolute accuracy is variance-limited; ≈ K clusters needed" statement be *gated* as a positive design
guideline rather than a diagnostic. It is optional; the closure above stands without it.
