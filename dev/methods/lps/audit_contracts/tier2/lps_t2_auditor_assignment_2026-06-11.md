You are the independent auditor for the LPS Tiers 1–4 program in the `geosmooth` R package. Your
standing role, rules, deliverable shape, and do-not list are in
`/Users/pgajer/current_projects/geosmooth/project_briefs/lps_e19_auditor_prompt_2026-06-11.md`
(everything above its "FIRST ASSIGNMENT" heading) — read it first; it applies here unchanged. The
program docs are not committed on this branch; read them from the e19 branch (shared `.git`):

```sh
git show codex/geosmooth-e1-9-bandwidth-multiplier:dev/methods/lps/specs/lps_experimental_plan_2026-06-09.tex > /tmp/plan.tex   # §E2.12–E2.14
git show codex/geosmooth-e1-9-bandwidth-multiplier:project_briefs/lps_tiers1to4_contract_2026-06-11.md > /tmp/contract.md  # §C + §A
```

This is your **Tier-2 assignment** (binary path & numerical hygiene). All gates are real-valued/binary
correctness GATEs with **no DGP-library dependency** — you can mutation-qualify them now.

## Target

Branch `codex/geosmooth-t2-binary-hygiene`, worktree `~/current_projects/geosmooth-t2` (tip `53a0b0c`).
Delivered: `tests/testthat/test-lps-binary-separation.R` (**E2.14**),
`tests/testthat/test-lps-binary-metric-consistency.R` (**E2.12**),
`scripts/ci/run_tier2_execution_artifact.sh`, plus a Tier-2 report.
**E2.13 (ridge alignment) is NOT delivered** — it was gated on contract §G4. Confirm it is *absent
because deferred*, not silently dropped; note it pending and do not fault its absence.

## First — verify where you are

```sh
pwd                          # …/geosmooth-t2 — NOT the shared main checkout …/geosmooth
git rev-parse HEAD           # RECORD this; the SHA your verdict certifies
git status --short           # MUST be empty — if dirty, the implementer may still be active → STOP, tell the orchestrator
```

Audit in place; mutate `R/lps.R` only transiently (edit → test → `git checkout -- R/lps.R`); never
commit a mutation or commit to this branch.

## What to verify (plan §E2.14, §E2.12 — thresholds verbatim)

**E2.14 — local logistic robustness (separation).** IRLS with **step-halving**: the per-iteration
**deviance is non-increasing to within `1e-8` per step**; final `p̂ ∈ (0,1)` and `|β̂| < ∞`; if the
convergence tolerance is not met within the iteration cap, a **documented, telemetered fallback**
fires (`converged`, `fallback.path`, `event.rate.fallback`). Tests **both** the near-separable case
(one flipped label) **and** the exactly-separable case (no flip), and asserts on the deviance
**trajectory**, not only the endpoint.

**E2.12 — binary selection metric + log-loss clip.** After the fix the selection score equals the
**deployed (clipped)** metric; the **pre-fix discrepancy is demonstrated in the same file** as a
documented motivating case with a *real* ranking flip (clipped vs unclipped Brier rank two candidates
differently — verify by hand it is not a tie). The log-loss clip is **pinned at `1e-6`**; the score at
`1e-15` is demonstrably dominated by one confident-wrong point. Cross-clip stability over
`{1e-6, 1e-3}` is a **diagnostic, reported NOT gated** — confirm it is not a hard assertion.

## Known weak points — scrutinize first

- **E2.14 endpoint-only assertion.** If the test checks only the final deviance, an IRLS run that
  *oscillates* but happens to end low passes falsely. The assertion must be on the per-iteration
  sequence.
- **E2.14 fallback under exact separation.** The no-flip case must hit the documented fallback — not
  loop, not return `p̂ ∈ {0,1}`, not NaN.
- **E2.12 vacuous motivating case.** If the constructed case is a near-tie, "clipped vs unclipped
  selects differently" is luck, not a property. Re-derive the two Brier scores yourself and confirm a
  genuine rank flip.
- **E2.12 clip over-claim.** Cross-clip invariance must be reported, not gated (near-ties may
  legitimately reselect). A hard "selection identical across clips" assertion is a spec violation.

## Mutation / falsification (the core deliverable)

Run the battery clean (expect green), then for each row mutate, re-run the named gate, confirm **red**,
and restore. A gate green under its mutation is vacuous → reject it.

| Gate | Property | Mutation that MUST turn it red |
|---|---|---|
| E2.14 (monotone) | deviance non-increasing `≤1e-8`/step under step-halving | disable step-halving (force the full Newton step) → deviance oscillates/increases on the near-separable support → trajectory assertion red |
| E2.14 (bounded/fallback) | exact separation → fallback; `p̂ ∈ (0,1)` | remove the fallback trigger → exact-separable case loops or returns `p̂ ∈ {0,1}`/NaN → red |
| E2.12 (clipped metric) | selection score = clipped deployed metric | revert selection to score **unclipped** predictions → selected candidate flips on the constructed case → regression assertion red |
| E2.12 (clip value) | clip pinned `1e-6`; `1e-15` unstable | set the clip to `1e-15` → the score is dominated by the one confident-wrong point → the "stable clip" assertion red |

## Run + reproduce

```sh
cd ~/current_projects/geosmooth-t2
git status --short                       # empty
Rscript -e 'pkgload::load_all(".", quiet=TRUE); library(testthat); test_file("tests/testthat/test-lps-binary-separation.R")'           # load_all first, or fit.lps isn't found
Rscript -e 'pkgload::load_all(".", quiet=TRUE); library(testthat); test_file("tests/testthat/test-lps-binary-metric-consistency.R")'
bash scripts/ci/run_tier2_execution_artifact.sh   # the bundle harness loads the package itself
```

Reproduce ≥1 number yourself: e.g. the E2.12 selected candidate under clip `1e-15` vs `1e-6` (confirm
the flip), or one step of the E2.14 deviance trajectory.

## Deliver

`audits/tier2_audit_<your-run-date>.md` per the standing Deliverable shape: accept/reject for **E2.14**
and **E2.12** separately, the mutation table with red/green results, spec-fidelity notes (verbatim
`1e-8` / `1e-6`; cross-clip *reported not gated*; both separation cases tested), your reproduced
number, and an explicit line that **E2.13 is deferred pending §G4** (not a defect). Leave it untracked
for the orchestrator; do not commit to `codex/geosmooth-t2-binary-hygiene`.
