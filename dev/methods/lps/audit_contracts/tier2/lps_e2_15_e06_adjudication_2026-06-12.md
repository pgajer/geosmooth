# E2.15 ⇄ Tier-0 E0.6 — adjudication (Tier-0 E0.6 amendment)

Date: 2026-06-12. Adjudicates the Tier-2 implementer's stop-and-raise
(`e2_15_e06_interaction_raise_2026-06-12.md`). The implementer did the right thing: implemented E2.15
exactly per the amendment, hit the E0.6 interaction, and **stopped and raised** rather than absorbing a
Tier-0 change.

## Decision: Option 1 — amend E0.6's binomial arm to `unstable.action = "mean"`

I concur with the implementer's recommendation. **This re-opens an accepted, already-merged Tier-0
gate (E0.6), so it needs your explicit go-ahead before the agent touches it** — but it is the correct
call, not an overreach.

## Why (and why not 2 or 3)

The finding is real and important: E0.6's accepted low-prevalence **binomial** statistics were computed
over selections the now-ratified E2.15 classifies as **invalid** — candidates that failed to predict
8–13% of held-out points, scored only on the points they happened to hit. Fixing the selection bug
(E2.15) necessarily changes what E0.6 selects, so **E0.6 must be re-measured regardless** of how the
all-NA-cell error is handled. Given that:

- **Option 1 (`mean`):** the event-rate fallback predicts everywhere, so E0.6's calibration is computed
  on the **deployed predictions at every point** — the same train/deploy-consistency principle E2.12
  enforces (score the deployed metric), and consistent with E2.14's telemetered-fallback philosophy.
  No `Inf`, no dropped data. ✓
- **Option 2 (drop all-NA cells as failed replicates):** still re-pins E0.6 (non-error cells' selections
  changed too) **and** silently drops the hardest cells — exactly where calibration matters most — a
  subtle bias toward better-looking calibration, plus error-handling complexity. Dominated by Option 1. ✗
- **Option 3 (soften E2.15):** contradicts the ratified E2.15, makes a candidate's selectability depend
  on the rest of the candidate set (non-local, surprising), and breaks the gaussian-convention
  uniformity E2.15 deliberately adopts. Reject. ✗

## This re-opens Tier-0 — and that is the methodology working

E0.6 is accepted and already on `main`. Option 1 amends it — the program's **first Tier-0 re-open**.
It is justified: a downstream bug fix surfaced that an accepted gate's numbers depended on the very
defect being fixed. Re-pinning E0.6 under deployed-scoring makes it **more** correct, not less. The
audit chain catching this — rather than shipping a quietly-wrong calibration baseline — is the system
working as designed. Frame it that way in the record, not as a Tier-0 regression.

## Process — the E0.6 amendment (t2 implementer)

1. Amend E0.6's binomial arm: `unstable.action` `"na"` → `"mean"`.
2. Re-measure the binomial-arm statistics (slope CIs, calibration bands, fallback fractions) under the
   new config **and** the E2.15 selection rule.
3. Re-pin E0.6's expected values / thresholds as needed; document the movement and which cells moved.
4. Re-bundle — the full battery is green again (E2.15 + re-pinned E0.6, no error).

Then the **re-audit** independently confirms: the `unstable.action` change is the deployed-scoring fix
(not goalpost-moving), the re-pinned thresholds still test binary calibration meaningfully, and no real
calibration failure is masked. **Log as a Tier-0 amendment.**

## Sequencing

- **Now (unblocked):** the combined re-audit proceeds on **E2.12-universal + E2.13 + E2.14 regression at
  `b79d041`** — the green E2.13 tip, before E2.15. This banks E2.13 and the E2.12 fix; they are
  independent of the E0.6 question.
- **Follow-up:** after the E0.6 amendment + re-pin lands, a second re-audit covers **E2.15 + the
  re-pinned E0.6** (with a quick E2.12/13/14 regression check).

## Integration impact — none new

The E0.6 change is a **test** (no `R/lps.R`); E2.15's source change sits in t2's existing
**selection-metric region** (the same area as E2.12), not e19's — so neither widens the e19↔t2
`R/lps.R` reconciliation. Both ride with the t2 merge. The Phase-3 merged-`main` re-audit must confirm
the **re-pinned E0.6** passes alongside E1.9/E1.10/E2.x.

## Status

Option 1 recommended — **awaiting your go-ahead** (Tier-0 re-open). The E2.12/E2.13/E2.14 re-audit at
`b79d041` can start immediately regardless of that decision.
