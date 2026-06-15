You are the independent auditor for the LPS Tiers 1–4 program in the `geosmooth` R package. Your
standing role, rules, deliverable shape, and do-not list are in
`/Users/pgajer/current_projects/geosmooth/project_briefs/lps_e19_auditor_prompt_2026-06-11.md`
(everything above its "FIRST ASSIGNMENT" heading) — read it first; it applies unchanged. Program docs
come from the e19 branch via the shared `.git`:

```sh
git show codex/geosmooth-e1-9-bandwidth-multiplier:project_briefs/lps_experimental_plan_2026-06-09.tex > /tmp/plan.tex   # §E0.6, §E2.12–E2.14
git show codex/geosmooth-e1-9-bandwidth-multiplier:project_briefs/lps_tiers1to4_contract_2026-06-11.md > /tmp/contract.md  # §A, §C
```

Orchestrator sign-offs that are the acceptance specs for this re-audit (read all three):
`lps_g4_ridge_resolution_2026-06-12.md` (E2.13), `lps_e2_15_binomial_na_consistency_amendment_2026-06-12.md`
(E2.15), and **`lps_e2_15_e06_adjudication_2026-06-12.md`** (the Tier-0 E0.6 re-open — Option 1).

This is the **combined Tier-2 re-audit** at the branch tip **`4367d10`** (code identical to the
green-bundle commit `5fb3a1c`; `4367d10` only adds docs). Scope: **E2.12-universal + E2.13 + E2.14 +
E2.15 + the re-opened Tier-0 gate E0.6.** The full battery is green here (E0.1–E0.8 + E2.12/13/14/15).

## Run in place — no separate worktree

The implementer is done with E0.6; the worktree is free and clean at the tip:

```sh
cd ~/current_projects/geosmooth-t2
git rev-parse --short HEAD     # MUST be 4367d10
git status --short             # MUST be empty
```

Mutate `R/lps.R` (or the E0.6 test) transiently and `git checkout -- <file>` after each; never commit.
Leave the worktree as you found it.

## A. The Tier-0 E0.6 re-audit — this is the heart of this pass

E0.6 (binary calibration) was an **accepted, merged** Tier-0 gate; it has been **re-opened** and amended
(Option 1: binomial arm `unstable.action` `"na"` → `"mean"`). The implementer's green bundle is **not**
acceptance evidence. Re-audit it as a Tier-0 gate:

**Prerequisite (implementer, before this re-audit runs):** the implementer produces the **full-size**
amended-E0.6 bundle (`LPS_TIER0_FULL=1`, clean committed tree, full-size binomial calibration numbers in
the handoff). The smoke bundle at `5fb3a1c` is not Tier-0 acceptance evidence. This re-audit **judges**
that full-size bundle — it does not produce it.

1. **Test-only diff.** `git diff 3dbb1c1 5fb3a1c -- tests/testthat/test-lps-tier0-correctness-extended.R` —
   confirm the change is **only** E0.6's binomial arm `"na"`→`"mean"` (bernoulli arm unchanged), with no
   `R/lps.R` or other source change. A production-source change here would be out of scope and a finding.
2. **Judge the implementer's full-size bundle (do not produce it).** The full-size E0.6 acceptance run
   is the **implementer's** deliverable (the prerequisite above). Judge it: clean committed tree, E0.6
   full-size coverage, the binomial-arm assertions pass (slope CIs, calibration bands, fallback
   fractions); then **independently reproduce ≥1 full-size number** — recompute a calibration slope from
   the bundle's raw outputs, or re-run a single full-size prevalence cell. You need not re-run the whole
   full-size battery; producing the acceptance evidence is the implementer's job, judging it is yours.
3. **Principled re-pin.** The implementer reports the assertions pass at the **original thresholds** (no
   loosening). Confirm that — the gate must still pass because the calibration genuinely stayed in the
   original bands, **not** because a threshold was widened to accommodate the change.
4. **Non-vacuity — the decisive check (the implementer flagged this himself).** Post-amendment the
   **binomial rows nearly coincide with the bernoulli rows** (reported max fitted-value diff `1.8e-15`),
   because where both arms select degree 0 the intercept-only logistic MLE, the event-rate fallback, and
   the degree-0 least-squares fit are all the same weighted event rate. Confirm this is a genuine
   **degree-0 identity, not a dead logistic path**: verify the logistic path is actually exercised (the
   handoff claims 450 converged solves + 50 telemetered fallbacks) **and** that E0.6's binomial arm still
   asserts on logistic-distinct behavior (degree-1 cells, fallback accounting) such that a logistic-path
   bug reddens it. If the amendment has quietly made the binomial arm a duplicate of bernoulli with no
   logistic-specific teeth, that is a **finding** — the fix would have weakened E0.6's Tier-0 coverage.

Deliver a **distinct Tier-0 E0.6 re-acceptance verdict** (accept / accept-with-fixes / reject), separate
from the E2.x verdicts.

## B. The Tier-2 gates (at the same tip)

- **E2.12-universal** (fix `550d7e8`): `bernoulli` + `backend="auto"` resolves to R; explicit
  `backend="cpp"`/`"cpp.local.pca"` bernoulli **errors**; the raw-RMSE fallback is removed — selection
  scores the deployed clipped metric on **every** legal bernoulli path.
- **E2.13** (per the §G4 sign-off): `ridge.shrinkage.target=c("zero","local.mean")`, default `"zero"`;
  aligned `ρ=1e2` shrinks to the **local weighted mean** (not 0); `|f̂_{ρ=1e-8}−f̂_{ρ=0}|<1e-6`; default
  `"zero"` reproduces the pinned 308-value reference bit-for-bit; gaussian-only (binomial warns).
  **Provenance:** `git merge-base --is-ancestor c796408 b79d041` must hold (the §A2 reference predates the
  E2.13 source — else the pin is circular).
- **E2.14** (regression): per-step deviance non-increasing to `1e-8`; exact-separation fallback. Confirm
  green.
- **E2.15** (per the amendment): binomial selection scores `Inf` for any candidate with a non-finite CV
  prediction; the constructed `NA`-heavy candidate wins under the old drop-`NA` rule but is unselectable
  post-fix; `.klp.logloss` untouched (the `logloss.clipped` diagnostic unchanged).

## Mutation / falsification

Run the battery clean (green), then per row mutate, re-run, confirm **red**, restore.

| Gate | Mutation that MUST redden |
|---|---|
| E0.6 calibration (Tier-0) | mis-clip / bias the binomial fitted probabilities → calibration slope/band assertion red |
| **E0.6 logistic-path non-vacuity** | break the logistic solve (e.g. `max.step.halvings <- 0L`, or force the event-rate fallback everywhere) → E0.6's binomial arm must red (if it stays green, the binomial arm is vacuous vs bernoulli → finding) |
| E2.12 universal | restore bernoulli→cpp / the `cv.rmse.observed` fallback → a `cpp` bernoulli fit selects on raw RMSE → red |
| E2.13 aligned | penalize the constant in the aligned WLS branch → `f̂_{ρ=1e2}` moves toward 0 → red |
| E2.13 §A2 pin | alter the `"zero"` path → the 308-value reference pin red |
| E2.14 | `max.step.halvings <- 0L` → near-separable trajectory red |
| E2.15 | revert binomial selection to drop-`NA` → the `NA`-heavy candidate wins → red |

## Run + reproduce

```sh
cd ~/current_projects/geosmooth-t2
git status --short                                   # empty
bash scripts/ci/run_tier2_execution_artifact.sh      # smoke battery — confirm green + base for the mutations
# (the full-size amended-E0.6 acceptance bundle is the implementer's deliverable; judge it + reproduce one slice)
Rscript -e 'pkgload::load_all(".", quiet=TRUE); library(testthat);
  for (f in c("test-lps-tier0-correctness-extended.R","test-lps-binary-metric-consistency.R",
              "test-lps-ridge-alignment.R","test-lps-binary-separation.R","test-lps-binomial-na-consistency.R"))
    test_file(file.path("tests/testthat", f))'
```

Reproduce ≥1 number yourself in **each** of: the E0.6 binomial calibration (e.g. a slope), the E2.13
`ρ=1e2` aligned fit vs `ȳ^w`, and the E2.15 ranking flip.

## Deliver

`audits/tier2_combined_reaudit_<your-run-date>.md` per the standing Deliverable shape, with **separate
verdicts** for: **Tier-0 E0.6 re-acceptance** (§A — including the full-size result, the non-vacuity
finding, and the principled-re-pin confirmation), and **E2.12-universal / E2.13 / E2.14 / E2.15** (§B).
Plus the mutation table, the §A2 ancestry finding, and your reproduced numbers. Leave it untracked; do
not commit. When this clears, **all of Tier-2 plus the re-pinned Tier-0 E0.6 are accepted**, and t2 is
ready to merge (the second `R/lps.R` branch, reconciling against e19).
