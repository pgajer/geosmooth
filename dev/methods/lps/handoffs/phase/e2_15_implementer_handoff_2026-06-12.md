# E2.15 — Implementer handoff (binomial selection NA-consistency)

Date: 2026-06-12
From: implementer agent (Tier 2, worktree `geosmooth-t2`, branch
`codex/geosmooth-t2-binary-hygiene`)
Gate: E2.15 (Tier-2 amendment
`project_briefs/lps_e2_15_binomial_na_consistency_amendment_2026-06-12.md`,
promoting spec-memo item 11; recorded as memo addendum 11c; folded into the
E2.13 pass by `project_briefs/lps_t2_e2_13_work_order_2026-06-12.md`).

**Status: implemented per the amendment; GATE green; BLOCKED on an
orchestrator decision.** The amendment's own stop-condition fired: the
full-battery rerun shows material E0.6 movement (7 of 72 binomial smoke
cells error), raised in
`audit_contracts/lps_tiers1to4/e2_15_e06_interaction_raise_2026-06-12.md`
rather than absorbed. No E0.6 change was made.

## Goal

Binomial selection consistent with gaussian/bernoulli: any candidate with
a non-finite CV prediction is unselectable (selection score `Inf`, the
`.klp.rmse` convention), instead of `.klp.logloss` dropping non-finite
pairs and scoring the candidate on the points it happened to predict.
Always-on; healthy-data selection unchanged.

## Files changed or created

Commit `fe57126`:

- `R/lps.R`: in `.klp.cv.table`, the binomial selection column
  `cv.logloss.observed` returns `Inf` whenever any out-of-fold prediction
  for the candidate is non-finite; otherwise it is the unchanged
  `.klp.logloss` value. `.klp.logloss` itself is untouched — it still
  backs the `logloss.clipped` probability **diagnostic**, whose
  observed-pairs reporting semantics are preserved (the amendment's
  "preserve unless subsumed" choice, documented in-code). Roxygen updated.
- `tests/testthat/test-lps-binomial-na-consistency.R` (new): the E2.15
  GATE, 2 tests / 15 assertions.
- `scripts/ci/run_tier2_execution_artifact.sh`: gate file added.
- `audit_contracts/lps_tiers1to4/e2_15_e06_interaction_raise_2026-06-12.md`
  (new): the stop-and-raise memo.

## Fixture (deterministic, no RNG; pinned exactly in the GATE)

`n = 120` points on a 1-D grid in `[-1, 1]`; labels alternate in ten
stripes of twelve points; ONE flipped label at index 66 (stripe-5 center).
Candidates `support ∈ {8, 110}`, degree 1, gaussian kernel,
`unstable.action = "na"`, singleton ridge 0, `ridge.condition.max = Inf`,
R backend, explicit foldid. Mechanism: support-8 windows straddling a
stripe boundary without the flip are exactly separable → the logistic
solve cannot converge → `NA` (realized: 55.8% of its out-of-fold
predictions); its retained points are dominated by confident-correct
stripe interiors. Support-110 windows always contain the flipped label,
are never separable, and predict everywhere (0% `NA`).

## Numerical findings

- Pre-fix demonstration (from the scored predictions, in the same file):
  under the old drop-`NA` rule the `NA`-heavy candidate **wins** —
  `0.3016` vs `0.6818`, margin `0.38` (a real flip, not a tie).
- Post-fix: the `NA`-heavy candidate's `cv.logloss.observed` is `Inf` and
  it is not selected; the complete candidate (support 110) is selected on
  a finite score equal to the unchanged observed-pairs log loss.
- Cross-family consistency: both binomial selection-facing columns
  (`cv.logloss.observed`, `cv.brier.observed`) are `Inf` for the
  `NA`-heavy candidate and finite for the complete one — the
  gaussian/bernoulli convention now holds uniformly.
- Healthy-data regression pin: on an all-finite binomial fixture the
  selection column equals the unchanged `.klp.logloss` values exactly and
  the finite argmin is selected (the `Inf` guard is structurally inert on
  the non-defect path).

## The blocker (raised, not absorbed)

E0.6's binomial arm runs `unstable.action = "na"` at small supports and
prevalence down to 0.1, where logistic separation makes `NA` predictions
routine (accepted bundles record `max_na = 0.19`). Post-E2.15, in 7 of 72
smoke cells **every** candidate has at least one `NA`, all score `Inf`,
and `fit.lps` errors ("No candidate has a finite selection score" — the
identical error the gaussian family raises in that situation). In those
cells the old rule had been selecting candidates that failed on up to
~8–13% of held-out points — the defect class itself. The raise memo lists
the affected cells, three resolution options (amend E0.6 binomial to
`unstable.action = "mean"`; per-replicate error accounting in E0.6;
soften the E2.15 rule — recommended against), and recommends the first.
The decision changes an accepted Tier-0 gate and is the orchestrator's.

## Result artifacts

Execution bundle `audit_artifacts/tier2_20260612T202904Z/`:
`git_head = fe57126…`, `tree_clean: true`, `testthat_summary: tests=29
failed=0 error=1 warning=0 skipped=1` — the one **error is the E0.6
binomial interaction documented above** (deliberately not masked),
`gate_contexts: E0.1;…;E2.13;E2.14;E2.15`, `probe_rc: 0`, `study_rc: 0`.
The E2.13 bundle one commit earlier
(`audit_artifacts/tier2_20260612T201926Z`, head `b79d041`) is fully green
and unaffected by E2.15.

## Whether source/tests were run

Yes — the E2.15 gate standalone (15/15 green), the full battery inside
the bundle (green except the documented E0.6 binomial error), the
affected-cell scan that produced the raise memo's table, and the full
package suite (the four pre-existing GE7 failures, plus the E0.6 error).

## Limitations and unverified claims

- **No mutation run** (the amendment names it: reverting to drop-`NA`
  must let the `NA`-heavy candidate win again; altering the healthy path
  must redden the regression pin). The auditor's.
- **The healthy-data "bit-for-bit" claim is structural plus one pinned
  fixture**: on all-finite predictions the new code calls the same
  `.klp.logloss` as before, and the pin asserts equality on one fixture;
  I did not enumerate other healthy configurations.
- **The E0.6 full-size battery was not run**; the 7/72 incidence is
  smoke-sized. Full sizes at prevalence 0.1 will be affected at least as
  often (more replicates, larger n with the same support schedule).
- The affected-cell scan (the raise memo's table) was an in-session
  script over the E0.6 generator definitions, mirrored from the committed
  test file; the scan script itself is not committed.
- E2.15 acceptance is **not requested** until the orchestrator
  adjudicates the raise memo; the implementation may need a follow-up
  commit depending on the chosen option (options 1 and 2 change E0.6, not
  the E2.15 source; option 3 would change the E2.15 source and its GATE).
