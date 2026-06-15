# Tier-2 Amendment — E2.15: binomial selection NA-consistency

Date: 2026-06-12. Promotes the Tier-2 implementer's **item 11** observation
(`t2_spec_questions_implementer_2026-06-11.md`) from "logged future finding" to a Tier-2 follow-up
**GATE**. Log in the contract §C / §H as a Tier-2 amendment. Implemented in the same pass as E2.13.

## Claim

Gaussian and bernoulli selection score any candidate with a non-finite CV prediction as `Inf` via
`.klp.rmse` — so a candidate that cannot predict everywhere is **unselectable**. Binomial selection
(`.klp.logloss`) instead **drops** non-finite pairs and scores the candidate on its remaining points.
A binomial candidate that predicts `NA` on most points (e.g. a small/degenerate support under
`unstable.action = "na"`) is therefore scored only where it happened to succeed and **can win** — the
selection rewards failing on the hard points, and cross-candidate scores are computed on **different,
incomparable** support sets.

## Failure mode addressed

A selection criterion that prefers a candidate for *omitting* its hard points; train/deploy and
cross-candidate incomparability in the binomial path. (This is the binary-family analogue of the
clipped-metric consistency E2.12 already fixed.)

## Fix

Make binomial selection consistent with the gaussian/bernoulli rule: **any candidate with a non-finite
CV prediction is unselectable** (scored `Inf`, the `.klp.rmse` convention). Implementation site
(`.klp.logloss` itself vs. the selection-column computation in `.klp.cv.table`) is the implementer's
choice; preserve the `logloss.clipped` **diagnostic's** current reporting unless the fix subsumes it —
document whichever. NA *treatment*, not clipping, is the subject here (E2.12's `1e-6` clip stands).

## Typing and §A2 stance

**GATE. Always-on correctness fix**, consistent with E2.14's always-on step-halving: behavior changes
**only on the defect class** — binomial candidates with non-finite CV predictions. Healthy-data fits
(no `NA`s) select identically to today, so the change is bit-for-bit on the non-defect path. Confirm
**Tier-0 E0.6** is unaffected via the full-battery rerun (no movement expected — E0.6 runs on healthy
data) and pin the change. If the rerun shows material E0.6 movement, stop and raise it rather than
absorb it silently.

## GATE

A constructed binomial fixture (deterministic, seeded) with a candidate set in which **one candidate
predicts `NA` on a majority of eval points** (a deliberately under-supported/degenerate candidate under
`unstable.action = "na"`) and which **would win** under the old drop-`NA` rule. Assert:

1. The `NA`-heavy candidate is **not selected**; its selection score is `Inf` (unselectable).
2. A complete-prediction candidate is selected instead.
3. **Cross-family consistency:** binomial now matches the gaussian/bernoulli `Inf`-on-any-non-finite
   rule on the same kind of fixture.
4. **Pre-fix demonstration in the same file:** the old drop-`NA` rule would have returned the
   `NA`-heavy candidate (documented from the scored table, the way E2.12 documents its raw-vs-clipped
   flip).
5. **Regression pin:** on healthy data (no `NA`s) the binomial selection is unchanged vs pre-fix.

Validity: verify the `NA`-heavy candidate genuinely **wins** under the old rule on the fixture (a real
flip, not a tie). Pin the fixture exactly.

## Mutation (the auditor's, not the implementer's)

Reverting binomial selection to **drop** non-finite pairs must let the `NA`-heavy candidate win again,
reddening assertion (1). Altering the healthy-data path must redden the regression pin (5).

## Status

Folded into the E2.13 implementation pass (`lps_t2_e2_13_work_order_2026-06-12.md`). The combined Tier-2
re-audit covers E2.12 (universal), E2.13, **E2.15**, and the E2.14/E2.12-R regression. Assign the
amendment number when logging in the contract.
