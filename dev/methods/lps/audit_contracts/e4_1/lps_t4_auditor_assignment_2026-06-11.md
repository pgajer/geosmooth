You are the independent auditor for the LPS Tiers 1–4 program in the `geosmooth` R package. Your
standing role, rules, deliverable shape, and do-not list are in
`/Users/pgajer/current_projects/geosmooth/project_briefs/lps_e19_auditor_prompt_2026-06-11.md`
(everything above its "FIRST ASSIGNMENT" heading) — read it first; it applies here unchanged. The
program docs are not committed on this branch; read them from the e19 branch (shared `.git`):

```sh
git show codex/geosmooth-e1-9-bandwidth-multiplier:dev/methods/lps/specs/lps_experimental_plan_2026-06-09.tex > /tmp/plan.tex   # §E4.1 + §sec:smoother
git show codex/geosmooth-e1-9-bandwidth-multiplier:project_briefs/lps_tiers1to4_contract_2026-06-11.md > /tmp/contract.md  # §E + §A
```

This is your **Tier-4 Part-A assignment** (pointwise variance / df). **Part A only** — a deterministic
unit GATE on the E0.2 `S`-machinery, **no DGP dependency**. **Part B (coverage on G3a) is deferred**
pending the audited DGP library; do **not** audit it now.

## Target

Branch `codex/geosmooth-t4-uncertainty`, worktree `~/current_projects/geosmooth-t4` (tip `3860806`,
*"Add E4.1 implementer handoff (Part A delivered, Part B pending G3a)"*). Delivered: the Part-A unit
GATE (find via `git diff`), `scripts/ci/run_e4_1_execution_artifact.sh`, and the E4.1 handoff (evidence
+ admissions only).

## First — verify where you are

```sh
pwd                          # …/geosmooth-t4 — NOT the shared main checkout …/geosmooth
git rev-parse HEAD           # RECORD this; the SHA your verdict certifies
git status --short           # MUST be empty — if dirty, the implementer may still be active → STOP, tell the orchestrator
```

Audit in place; mutate `R/lps.R` only transiently (edit → test → `git checkout -- R/lps.R`); never
commit a mutation or commit to this branch.

## What to verify (plan §E4.1 + §sec:smoother — Part A)

For a **fixed config** (singleton grids, `chart.dim=2`, degree 1), the variance/band machinery on the
linear smoother `S`:

- `Var(ŷ_i) = σ² Σ_j S_ij²`;  `σ̂² = RSS / (n − tr S)`;  band `ŷ_i ± z_{0.975} · σ̂ · ‖S_{i·}‖₂`;
  `df = tr S`.
- **Deterministic unit GATE:** the implemented per-point variance equals `σ² Σ_j S_ij²` computed from
  an **independently extracted** `S` — the E0.2 column-by-column `fit(e_j)` extraction (§sec:smoother)
  — to **algebraic tolerance `1e-10`**; and `df = tr S` matches. This needs no DGP.

## Known weak points — scrutinize first

- **Circular `S` (the decisive one).** The gate is only meaningful if it extracts `S` **independently**
  (E0.2 `fit(e_j)` column-by-column) and compares the variance routine's output to `σ²Σ_j S_ij²`
  computed from *that* `S`. If it reuses the routine's own internal `S`, the gate checks the code
  against itself → vacuous → reject.
- **Algebraic, not sampling, tolerance.** Part A is exact algebra; the residual must sit **far below**
  `1e-10`, not near it. A residual within an order of magnitude of `1e-10` is suspicious.
- **`σ̂²` denominator.** Must be `n − tr S`, not `n` or `n − p`. Confirm the exact formula.
- **Part B not smuggled in.** A temporary inline paraboloid is allowed only for *wiring/smoke*. No
  **coverage acceptance number** may be reported off a non-audited DGP — that must wait for the audited
  G3a. Confirm none is claimed as a result.

## Mutation / falsification (the core deliverable)

Run the unit GATE clean (expect green), then for each row mutate, re-run, confirm **red**, and restore.

| Gate | Property | Mutation that MUST turn it red |
|---|---|---|
| variance | `Var_i = σ² Σ_j S_ij²` matches independently-extracted `S` to `1e-10` | drop the square (use `Σ_j S_ij`) or replace `‖S_{i·}‖` with a constant → the `1e-10` equality fails → red |
| df | `df = tr S` | perturb the trace accumulation (wrong index / off-diagonal) → `df` mismatch → red |
| band (if asserted) | half-width `= z·σ̂·‖S_{i·}‖₂`, `σ̂² = RSS/(n−tr S)` | change the `σ̂²` denominator to `n` → band half-width diverges from the spec formula → red |

## Run + reproduce

```sh
cd ~/current_projects/geosmooth-t4
git status --short                       # empty
Rscript -e 'pkgload::load_all(".", quiet=TRUE); library(testthat); test_file("tests/testthat/test-lps-tier4-uncertainty.R")'  # load_all first, or fit.lps isn't found
bash scripts/ci/run_e4_1_execution_artifact.sh   # the bundle harness loads the package itself
```

Reproduce ≥1 value yourself: extract `S` column-by-column for the fixed config, compute `σ²Σ_j S_ij²`
for one point, and confirm it equals the routine's output to `1e-10`; confirm `tr S` matches the
reported `df`.

## Deliver

`audits/e4_1_partA_audit_<your-run-date>.md` per the standing Deliverable shape: accept/reject for the
Part-A unit GATE, the mutation table with red/green results, the **independent-`S`** finding (weak
point 1), spec fidelity (`1e-10` algebraic; `n − tr S` denominator; chart.dim=2/degree 1/singleton),
your reproduced number, and an explicit line that **Part B (coverage) is deferred pending audited
G3a**. Leave it untracked for the orchestrator; do not commit to `codex/geosmooth-t4-uncertainty`.
