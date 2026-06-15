# Phase 3 merged-`main` re-audit — Pass 2 (post-e19 reconciliation)

You are the independent auditor for the LPS Tiers 1–4 program. Standing role, run-in-place rules, and
deliverable shape are in `project_briefs/lps_e19_auditor_prompt_2026-06-11.md` (above its FIRST ASSIGNMENT
heading) — apply unchanged. Inputs: the Pass-1 verdict `audits/phase3_merged_main_reaudit_2026-06-14.md`
(t2-into-main, ACCEPTED), the reconciliation work order
`project_briefs/lps_e19_reconciliation_workorder_2026-06-14.md`, and the implementer's reconciliation
handoff (it reports the certified `main` tip).

This is **Pass 2**: the **fully-integrated `fit.lps`** — e19's bandwidth/CV code reconciled on top of the
already-accepted t2 binary/ridge code — the artifact **no single audit has seen**. Pass 1 cleared the t2
half and proved the four ge7 failures are pre-existing stale tests. Pass 2 clears the e19 reconciliation
and the now-unioned signature.

## Materialize and certify

`main` (post-reconciliation) is not checked out live. The certified tip is **`fee9485`** (= `main`; merge
commit `4d458c5` + GE7-fix `fee9485`). The implementer's evidence bundle
(`reports/phase2b_reconciliation/`) and reconciliation handoff sit on the **e19 branch tip just ahead of
`main`** — read them there, but reproduce independently. Materialize the certified tip in a throwaway
worktree:

```sh
cd ~/current_projects/geosmooth
git worktree add /tmp/gm-phase3b fee9485 && cd /tmp/gm-phase3b
git rev-parse HEAD     # RECORD — confirm it equals fee9485 / main
git status --short     # MUST be empty
```

Mutate `R/lps.R` transiently and `git checkout -- R/lps.R` after each; never commit; remove the worktree
when done.

## §1 — Full gate battery green on the reconciled tip

Run full-size (set `LPS_TIER0_FULL=1`) and confirm green:

- **e19 gates:** E1.9a/E1.9b (bandwidth multiplier) + E1.10 (`test-lps-nested-grouped-cv.R`).
- **t2 gates:** E2.12 (`test-lps-binary-metric-consistency`), E2.13 (`test-lps-ridge-alignment`), E2.14
  (`test-lps-binary-separation`), E2.15 (`test-lps-binomial-na-consistency`).
- **Tier-0:** `test-lps-tier0-correctness` + `-extended` (incl. amended E0.6 + the fallback-bound).
- **dgp:** `test-dgp-library`.
- **ge7:** `test-ge7-lps-api` — must now be **green** (the stale fixtures were updated; see §3).

A green full suite on the reconciled tip is the integration-acceptance baseline.

## §2 — Signature-union bit-for-bit check (the Pass-2 deliverable)

The merge unions three additive arguments onto the common base. Confirm the merged `fit.lps` signature
carries **all three** at their bit-for-bit defaults, and nothing else changed:

- `bandwidth.multiplier.grid = 1` (e19)
- `ridge.shrinkage.target = c("zero", "local.mean")` (t2 — default `"zero"`)
- `keep.cv.predictions = FALSE` (t2)

Then verify **every argument still defaults bit-for-bit** (the §A2-style pin): a default-config `fit.lps()`
reproduces the pre-merge fitted values and CV scores exactly — i.e. the reconciliation did not perturb the
default path. Concretely: the E1.9b reference GATEs and the E2.13 §A2 reference (`reports/e2_13_reference_fits.csv`)
must both still pass on the reconciled tip. For the **CV candidate grid**: the implementer found that t2
added **no grid axis** (its `ridge.shrinkage.target` is a scalar arg and its bernoulli "clip" is the
selection *metric*, not an `expand.grid` dimension), so the merged grid is e19's
`support × degree × kernel × bandwidth.multiplier`. **Independently confirm** this — that main's
`expand.grid` carries no extra dimension — and that the **default** config (`bandwidth.multiplier.grid = 1`)
enumerates exactly the **18-candidate** set both parents produce (no dropped or duplicated candidates), and
that the bandwidth grid `{0.5, 1, 2}` expands to 54. A union that silently drops a behavior, changes a
default, or double-counts the grid is a blocking finding. (The implementer's cross-parent sha256 digest
battery — merged ≡ e19 on the bandwidth axis, merged ≡ main on the binomial/ridge axes, decisively
merged ≠ e19 on binomial — is available to cross-check; reproduce at least the binomial-default digest
equality yourself.)

## §3 — GE7 cleanup verification

Confirm the Pass-1 follow-ups are correctly applied and the failures are gone:

- Lines 322/323/325 now use the **exact-separation fixture** and actually exercise the `na.failure`
  telemetry path (`is.na(failed)`, `fallback.path.count == 1`, `na.failure.count == 1`) — i.e. the test is
  no longer vacuous.
- Line 682 now asserts the **current default behavior** (the orthogonal-polynomial ridge path returns a
  finite fitted intercept, not the weighted-mean fallback; `is.safe == FALSE` retained) — matching the
  Pass-1 adjudication, with no production `is.safe` guard added.

## §4 — Mutation qualification on the reconciled `main` (no behavior dropped by the merge)

Run each gate clean (green), mutate `R/lps.R` in the worktree, re-run, confirm the named reddening, restore.
Reuse the Pass-1 set and add the e19 gates:

| target | mutation | gate | must |
|---|---|---|---|
| E2.13 ridge | remove the `+ ybar.w` add-back | `test-lps-ridge-alignment` | redden |
| E2.14 separation | `max.step.halvings <- 0L` | `test-lps-binary-separation` | redden |
| E2.12 metric/backend | force-to-R branch binomial-only | `test-lps-binary-metric-consistency` | redden |
| E2.15 NA-consistency | restore old drop-NA logloss | `test-lps-binomial-na-consistency` | redden |
| E0.6 fallback-bound | `return(fallback("forced"))` in the logistic fitter | Tier-0 extended | redden |
| **E1.9 bandwidth** | neutralize the bandwidth multiplier (force `1`) | the E1.9 bandwidth gate | redden |
| **E1.10 nested** | leak the held-out outer fold into inner selection | `test-lps-nested-grouped-cv` | redden |

A surviving (green) gate under its mutation means the merge dropped that behavior — blocking.

## Deliver

`audits/phase3_pass2_reaudit_<run-date>.md` per the standing shape: the certified reconciled SHA, the §1
battery result, the §2 signature-union + bit-for-bit finding (E1.9b + E2.13-§A2 references pass; grid spans
both axes), the §3 GE7 verification, the §4 mutation table, and a verdict: **ACCEPT INTEGRATION** /
ACCEPT-WITH-REQUIRED-FIX / REJECT. Leave it untracked for the orchestrator.

When this accepts, **Tier 1–4 is integration-complete**: `main` can be pushed to origin (the held push is
now safe), and Phase 4 (docs/dev reorg, incl. the deferred §A2-reference extension and the planning-doc
consolidation) follows.
