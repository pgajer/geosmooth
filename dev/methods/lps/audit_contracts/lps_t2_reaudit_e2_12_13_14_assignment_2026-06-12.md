You are the independent auditor for the LPS Tiers 1–4 program in the `geosmooth` R package. Your
standing role, rules, deliverable shape, and do-not list are in
`/Users/pgajer/current_projects/geosmooth/project_briefs/lps_e19_auditor_prompt_2026-06-11.md`
(everything above its "FIRST ASSIGNMENT" heading) — read it first; it applies unchanged. Program docs
(not committed on this branch) come from the e19 branch via the shared `.git`:

```sh
git show codex/geosmooth-e1-9-bandwidth-multiplier:project_briefs/lps_experimental_plan_2026-06-09.tex > /tmp/plan.tex   # §E2.12–E2.14
git show codex/geosmooth-e1-9-bandwidth-multiplier:project_briefs/lps_tiers1to4_contract_2026-06-11.md > /tmp/contract.md  # §C + §A
```

Also read the **§G4 ridge sign-off** `/Users/pgajer/current_projects/geosmooth/project_briefs/lps_g4_ridge_resolution_2026-06-12.md` — it is the E2.13 acceptance spec.

This is a **Tier-2 RE-audit at commit `b79d041`** (the E2.13 tip, *before* E2.15). Scope: **E2.12
universal claim + E2.13 + E2.14 regression**. **E2.15 is OUT of scope** — it raised a Tier-0 E0.6
interaction now being amended (Option 1) and gets its own re-audit later. Do not audit E2.15 or the
E0.6 change here.

## Run in place — no separate worktree

This re-audit runs in the existing `geosmooth-t2` worktree, at commit **`b79d041`** (the green E2.13
tip, *before* E2.15 — the live branch tip reds the full battery while the E2.15/E0.6 interaction is
open). The worktree is clean at the branch tip, so check out the audited commit, audit, then restore
the branch when done:

```sh
cd ~/current_projects/geosmooth-t2
git status --short                  # MUST be empty (clean at the branch tip)
git checkout b79d041                # detached HEAD at the audited commit
git rev-parse --short HEAD          # MUST be b79d041
```

You mutate `R/lps.R` transiently and `git checkout -- R/lps.R` after each. **When done, restore the
worktree:** `git checkout codex/geosmooth-t2-binary-hygiene` (returns it to the branch tip).

**Sequencing (you share this worktree with the implementer's E0.6 amendment):** run this re-audit and
the E0.6 work **one at a time, not simultaneously**. The worktree is free now (E0.6 hasn't started), so
run this first — it restores the worktree to the branch tip on completion, ready for the E0.6 work.

## What to verify (at `b79d041`)

**E2.12 — universal clipped-metric claim** (the first audit's required fix, commit `550d7e8`). The
original audit accepted E2.12 only on the R path and required closing the C++ bernoulli gap. Confirm:
a `bernoulli` fit with `backend="auto"` resolves to **R**; an explicit `backend="cpp"` /
`"cpp.local.pca"` with `outcome.family="bernoulli"` **errors**; the raw-RMSE selection fallback is
**removed** (no `score.column <- "cv.rmse.observed"` for bernoulli). Net: selection scores the
**deployed clipped metric on every legal bernoulli configuration**, not just the R default.

**E2.13 — aligned ridge** (per the §G4 sign-off). `ridge.shrinkage.target = c("zero","local.mean")`,
default `"zero"`. Verify:
- **Aligned-mode GATE** (`"local.mean"`, `design.basis="orthogonal.polynomial.drop"`,
  `ridge.condition.max=Inf`, singleton grids, `ρ∈{0,1e-8,1e-2,1,1e2}`): `|f̂_{ρ=1e2} − ȳ^w|` small vs
  `|f̂_{ρ=1e2} − 0|` (shrinks to the **local weighted mean**, not 0); `|f̂_{ρ=1e-8} − f̂_{ρ=0}| < 1e-6`.
- **§A2 default-arm pin:** default `"zero"` reproduces the pinned pre-change reference (the 308-value
  reference frozen in `c796408`) **bit-for-bit** — this protects Tier-0 + E1.9.
- **Gaussian-only scope:** the alignment touches the WLS solve only; binomial mode **warns** the
  alignment does not apply (logistic alignment is explicitly out of scope).

**E2.14 — regression:** the previously-accepted separation gate still passes (per-step deviance
non-increasing to `1e-8`; exact-separation fallback). Confirm green; one mutation spot-check below.

## Provenance (non-mutation — decisive for E2.13's §A2 pin)

The §A2 pin is only sound if the reference fits were frozen **before** the E2.13 source change. Confirm
`c796408` ("Pin pre-E2.13 reference fits") is an **ancestor** of `b79d041`:

```sh
git merge-base --is-ancestor c796408 b79d041 && echo "OK: pin predates change" || echo "CIRCULAR — reject"
```

## Mutation / falsification (the core)

Run the battery clean (expect green), then per row mutate `R/lps.R`, re-run, confirm **red**, restore.

| Gate | Property | Mutation that MUST redden |
|---|---|---|
| E2.12 universal | bernoulli selects the clipped metric on **every** legal path | restore the bernoulli→cpp route (or the `cv.rmse.observed` fallback) → a `backend="cpp"` bernoulli fit selects on raw RMSE → universal claim red |
| E2.13 aligned | `ρ=1e2` shrinks to the local weighted mean | in the aligned WLS branch, penalize the constant direction too → `f̂_{ρ=1e2}` moves toward 0 → aligned GATE red |
| E2.13 §A2 pin | default `"zero"` is bit-for-bit current | alter the `"zero"` path → the 308-value reference pin red |
| E2.14 (spot-check) | step-halving keeps deviance non-increasing | set `max.step.halvings <- 0L` → near-separable trajectory red |

## Run + reproduce

```sh
cd ~/current_projects/geosmooth-t2
git status --short                       # empty (you are at b79d041, detached)
Rscript -e 'pkgload::load_all(".", quiet=TRUE); library(testthat);
  for (f in c("test-lps-binary-metric-consistency.R","test-lps-ridge-alignment.R","test-lps-binary-separation.R"))
    test_file(file.path("tests/testthat", f))'
bash scripts/ci/run_tier2_execution_artifact.sh    # full bundle (loads the package itself); expect green E0.x + E2.12/13/14
```

Reproduce ≥1 number yourself: e.g. the E2.13 `ρ=1e2` aligned fit vs the per-anchor weighted mean `ȳ^w`,
or the tiny-ridge invariance residual against `1e-6`.

## Deliver

`audits/tier2_reaudit_e2_12_13_14_<your-run-date>.md` per the standing Deliverable shape: accept/reject
for **E2.12-universal** and **E2.13**, an **E2.14 regression** confirmation, the §A2 ancestry finding,
the mutation table with red/green results, your reproduced number, and an explicit line that **E2.15 is
deferred pending the Tier-0 E0.6 Option-1 amendment and its own re-audit**. Leave it untracked for the
orchestrator; do not commit to the branch. When this clears, E2.13 and the E2.12 fix are banked, and
only the E2.15 + re-pinned-E0.6 pass remains before t2 can merge.
