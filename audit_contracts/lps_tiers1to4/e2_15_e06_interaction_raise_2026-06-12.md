# E2.15 ⇄ Tier-0 E0.6 interaction — STOP-AND-RAISE (to the orchestrator)

Date: 2026-06-12
From: Tier-2 implementer (worktree `geosmooth-t2`)
Trigger: the E2.15 amendment's own instruction — "Confirm Tier-0 E0.6 is
unaffected via the full-battery rerun (no movement expected — E0.6 runs on
healthy data) … **If the rerun shows material E0.6 movement, stop and raise
it rather than absorb it silently.**" The movement is material; I have
stopped. E2.15 is implemented exactly per the amendment and its GATE is
green; the blocker is the interaction with the accepted E0.6 protocol.

## The fact

The amendment's premise — *E0.6 runs on healthy data* — does not hold for
the **binomial** arm at smoke sizes. E0.6 fits binomial with
`unstable.action = "na"`, small supports (22–95), and prevalences down to
0.1; logistic solves hit exact separation / non-convergence and return
`NA`, with per-fit NA fractions up to 0.19 (the accepted bundles record
`max_na = 0.19`). Under E2.15's ratified rule — any candidate with a
non-finite CV prediction scores `Inf` — in **7 of the 72 smoke cells every
one of the six candidates has at least one `NA` prediction**, so all
scores are `Inf` and `fit.lps` stops with "No candidate has a finite
selection score" (the same error the gaussian family raises in that
situation today). The affected smoke cells:

| prevalence | n | replicate |
|---|---|---|
| 0.1 | 1000 | 8 |
| 0.1 | 2000 | 1, 2, 5 |
| 0.3 | 500 | 1, 3, 8 |

The full-size battery (n up to 4000, R = 40) has not been run but will be
affected at least as often at prevalence 0.1.

What the old rule was doing in those cells (e.g. prevalence 0.3, n = 500,
replicate 1): every candidate's NA fraction is 3–13%, and the drop-`NA`
rule selected (support 38, degree 0) — a candidate that failed to predict
**8.4%** of the held-out points, scored only on the points it happened to
predict. That is precisely the defect class E2.15 exists to close: E0.6's
accepted smoke statistics at low prevalence were computed over selections
the amendment classifies as invalid.

## What this is NOT

- Not an E2.15 implementation artifact: the fix is the amendment's exact
  rule (`Inf` on any non-finite prediction, the `.klp.rmse` convention),
  the E2.15 GATE passes (NA-heavy candidate wins under the old rule by
  margin 0.38 on the constructed fixture, unselectable post-fix), and
  healthy-data selection is pinned unchanged.
- Not a cross-family inconsistency: a gaussian fit whose candidates all
  contain an `NA` errors identically today. The *rule* is now uniform;
  the *incidence* differs because logistic separation is common at small
  support and low prevalence while the least-squares solve rarely fails
  there (E0.6's bernoulli arm has `max_na = 0`).

## Options (decision is the orchestrator's — E0.6 is an accepted Tier-0 gate)

1. **Amend E0.6's binomial arm to `unstable.action = "mean"`.** The
   event-rate fallback predicts everywhere, so no `Inf` candidates; E0.6
   already records binomial fallback fractions, and an accuracy/calibration
   study arguably should score deployed fallback predictions rather than
   silently dropping failures. Changes an accepted Tier-0 test → needs
   sign-off and re-acceptance of the smoke numbers (they will move:
   previously-dropped points enter the RMSE/calibration).
2. **Keep E0.6's config; make its replicate loop treat the
   no-finite-candidate error as a failed replicate** (recorded like the
   existing `na.fraction` accounting, excluded with its count reported).
   Smallest statistical change; adds error-handling complexity to an
   accepted test and silently reduces the effective replicate count in the
   worst cells.
3. **Soften the E2.15 rule** (e.g. `Inf` only when some candidate predicts
   everywhere, otherwise fall back to drop-`NA`). I recommend **against**:
   it contradicts the amendment's ratified text, makes selection semantics
   conditional on the candidate set, and diverges from the gaussian
   convention the amendment explicitly adopts.

My recommendation is **option 1**: it is the only variant where E0.6's
headline statistics are computed on deployed predictions for every point,
and it aligns the study with the telemetered-fallback philosophy of E2.14.
I have not implemented any of the three.

## State of the branch

- E2.13 is complete and independent: commit `b79d041`, green bundle
  `audit_artifacts/tier2_20260612T201926Z` (27 tests, 0 failures, full
  E0.x + E2.12/13/14 coverage).
- E2.15 is committed with this memo: the source fix, its green GATE
  (`tests/testthat/test-lps-binomial-na-consistency.R`), and an execution
  bundle that **honestly shows the E0.6 binomial error** (the harness
  emits the artifact regardless of battery status). E2.15 must not be
  re-audited for acceptance until this interaction is adjudicated; the
  combined re-audit can proceed on E2.12/E2.13/E2.14 regardless.
