# LDS0 implementer work order — geometry-only joint (K_i, d_i) resolver

Date: 2026-06-14. To the LDS0 implementer. The complete specification is the design+test plan
`project_briefs/lps_lds_design_and_test_plan_2026-06-13.tex` (`.pdf` alongside) — read it first; this work
order scopes phase **LDS0** of its build sequence (§ "Build-and-validation sequence (LDS0–LDS3)"), sets the
acceptance bar, and fixes the branch point. It does not restate the algorithm; build from the plan's
sections, cited below by their stable IDs.

## Prerequisite — branch point (read before forking)

LDS code edits `R/lps.R` (the resolvers + the prediction loop), the same file t2 and e19 touch. The LPS
base is **not yet closed**: `main` is `678565c` (dgp + t4 + t2); **e19's bandwidth/CV reconciliation and the
Phase-3 merged-`main` re-audit are still pending**, and `main` carries none of the LDS resolvers yet (clean
slate). Per the plan (§ "How LDS fits the wider program"), LDS builds once the LPS base closes.

**Fork LDS0 from the integrated `main` after e19 reconciles and the Phase-3 re-audit clears**, so your
`R/lps.R` is the full integrated version (bandwidth-multiplier ∪ ridge/binary ∪ the unioned CV grid).
Building before that creates a *fourth* `R/lps.R` branch to reconcile — avoid it. (If the orchestrator
chooses to start LDS0 early in parallel, fork from current `main` and plan a rebase onto the integrated
base; flag that cost up front.) New branch/worktree: `codex/geosmooth-lds0` / `geosmooth-lds0`.

## Decisions assumed for LDS0 (ratify or override before starting)

LDS0 needs only the geometry decisions; the Mode-B decisions (D1, D4, D8) are LDS1.

- **D2** — `ESS_target` = the ESS of the global CV pick (derive-from-global-pick), giving the clean
  reduction to today. [recommended]
- **D3** — candidate scale grid = the plan default `{12,18,27,40,60,90,135}` (§ "The candidate scale grid").
- **D7** — ESS feasibility factor `ρ = 1.5` in `ESS(K) ≥ ρ·C(d+p,p)`.

## Scope — what LDS0 is, and is not

**Is:** the **geometry-only Mode A** joint `(K_i, d_i)` resolver and its machinery — and nothing that reads
`y` in the per-anchor choice. **Is not:** Mode B (local GCV / Lepski) → that is **LDS1**; GDF / coverage
(S3) → **LDS3**; spatial smoothing of the fields (LDR / LDSR). Wire the `scale.mode` argument's other
values but leave them inert (error if selected) until LDS1.

## Step 1 — add D-VARSCALE to the frozen DGP library

Per § "Synthetic test data": the 2-D-in-3-D paraboloid with the smooth/wiggly frequency ramp `g(u_1)`.
Record per point: the side label, the radius `ρ`, a **transition mask** (`|u_1| ≤ w`) and a **boundary
mask** (outer-`ρ` quantile). Honor the **no-confound** property (density and curvature depend on `ρ`,
symmetric in `u_1`; only `g(u_1)` is asymmetric) — the auditor checks this. Also provide the
**density-gradient variant** (more points where `u_1 > 0`, identical truth) for G8's positive control.
Follow the frozen-DGP-library conventions (registered generator in the registry, recorded seed, answer-key
helpers, a DGP re-audit tag) exactly as the existing `dgp.*` generators did.

## Step 2 — build the geometry-only resolver (the plan's I1–I6, geometry parts only)

Implement per § "Implementation plan" and § "The estimator, step by step" (Mode A path), § "The
scale-selection criteria" (Mode A), § "The dimension rule", § "The candidate scale grid":

- **I1** — new mode value `support.size = "local.auto"` and `scale.mode = "geometry"` (default of the field
  mode); `ess.target = NULL` ⇒ derive from the global pick; `scale.grid = NULL` ⇒ the D3 default.
- **I2** — the resolver(s): `.klp.resolve.prediction.support.size` mirroring
  `.klp.resolve.prediction.chart.dim`, and the **joint** `.klp.resolve.prediction.scale.and.dim` returning
  both fields (one distance sort, one SVD sweep per anchor).
- **I3** — prediction loop: replace the scalar `support.size` with `support.size.by.eval[[i]]` in
  `.klp.predict.local.polynomial` (it already reads `chart.dim.by.eval[[i]]`).
- **Mode A criterion + feasibility:** `score(K) = |ESS(K) − ESS_target|`; the two hard filters — **ESS-based**
  feasibility `ESS(K) ≥ ρ·C(d(K)+p,p)` and the conditioning filter — then Pick = smallest ESS-gap; Guard =
  fall back to the global size + summary dimension, recorded (never silent).
- **Dimension rule (§ "The dimension rule"):** reuse it, with the **ESS-based cap gated to the LDS path
  only** — the existing global-`K` `chart.dim = "local.auto"` keeps the raw-`K` cap, byte-identical.
- **I5** — R backend only; the field mode forces R (native backends stay on the global path).
- **I6** — in Mode A, **assert and record that `S` stayed response-independent**. (The generalized-df
  estimate is LDS3; do not build it here.)
- **Outputs (§ "Outputs and diagnostics"):** `support.size.by.eval` (new), `chart.dim.by.eval` (now produced
  jointly), and the per-anchor diagnostics table.

**Bit-for-bit preservation (the load-bearing constraint).** Every default reproduces today's
single-global-`K` behavior **bit-for-bit** (I1); the field mode is opt-in; and the ESS cap is gated to the
LDS path so the existing global-`K` `local.auto` dimension is byte-identical. No package-default behavior
changes.

## Step 3 — gates (you write the tests; the auditor mutation-qualifies)

Implement the LDS0 gates from § "Test plan": **G1** (reduction to today, on G3a, match to `1e-10` in the
degenerate one-`K` grid), **G2** (linearity preserved in Mode A — column-probe `ŷ = S y` to `1e-10`,
`df = tr S`), **G5** (ESS-based well-posedness), **G6** (determinism — bitwise-identical fields per seed),
**G8** (geometry-only control on D-VARSCALE: flat `K` across the ramp; the **density-gradient positive
control** — `h` shrinks, `K` ≈ stable, `ESS` near target). Add a **bit-for-bit regression pin**: the
global-`K` default path (incl. `chart.dim = "local.auto"`) is byte-identical to the base. Tests carry
explicit seeds and pinned thresholds. **Do not run the mutations yourself** — the auditor owns them.

## Step 4 — acceptance bundle

A clean, committed bundle: the LDS0 gate battery green at full size where applicable; `git_head`, clean
`git_status`, **source checksums**, `sessionInfo()`, BLAS, and seeds; the **bit-for-bit pin evidence** (the
global-default path unchanged); and the D-VARSCALE registry SHA (audited generator, not hand-rolled). Plus a
handoff.

## Deliver → audit, then LDS1

The independent LDS0 auditor (R-capable; standing-charter rules) judges the bundle, reproduces ≥1 gate, and
**mutation-qualifies G1/G2/G5/G6/G8 + the bit-for-bit pin** (each mutation must redden its named gate; e.g.
letting the ESS target read `y` breaks G2/G8, reverting the ESS cap to raw `K` breaks G5, an unseeded
tie-break breaks G6). When LDS0 accepts, **LDS1 (Mode B–Lepski)** begins — that is when D1/D4/D8 and the
Lepski σ̂/τ policy come into play.

## Spec-questions allowance

Before building, you may raise a short spec-questions pass (as Tier-2 / E1.10 did) — e.g. the exact API
surface, joint-vs-two resolvers, the construction of the bit-for-bit pin, and the D-VARSCALE parameter
defaults (`R, k, w, n, σ`). Send it to the orchestrator for ratification rather than guessing.
