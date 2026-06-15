# E4.1 — K calibration on the audited G3a: table and proposal (to the orchestrator)

Date: 2026-06-12
From: implementer agent (E4.1), worktree `geosmooth-t4`, branch
`codex/geosmooth-t4-uncertainty` (calibration assets committed at `a809511`)
Responds to: orchestrator resolution 2026-06-12, **Item 4a** (pin `K` from a
bias/se calibration; kernel `tricube` pinned; DGP row pinned to
`G3a-R1-smooth-s010-n1200`).
Status: **PROPOSAL — the acceptance run has not been started** and will not
start until you ratify a `K`.

## 1. Method (deterministic; no Monte Carlo in the table)

On the frozen, audit-accepted row `G3a-R1-smooth-s010-n1200` (materialized via
the binding `validation/e4_1_g3a_binding.R` from the DGP library at its
accepted commit `58f5ab9…`, content SHA-256 verified `TRUE` against the frozen
registry):

- `bias_i = E[ŷ_i] − f(x_i) = (S f)_i − f_i` exactly (`S` is `y`-free at the
  fixed configuration; `S` from `lps.smoother.matrix`),
- `se_i = σ‖S_{i·}‖₂` with known `σ = 0.1`,
- per-point expected coverage of the known-σ band under exact bias:
  `Φ(z − r_i) − Φ(−z − r_i)`, `r_i = |bias_i|/se_i`, `z = z_{0.975}`.

Fixed configuration per the resolution: singleton grids, degree 1, `tricube`,
`local.pca`, `chart.dim = 2`, ridge `0`, `ridge.condition.max = Inf`,
`unstable.action = "na"`, R backend. Interior/boundary per the ratified
per-point `h_i` rule (so `n.interior` varies with `K` by definition).
Script: `validation/e4_1_k_calibration.R`; artifacts:
`audit_artifacts/e4_1_k_calibration_20260612T192750Z/`.

## 2. Calibration table (interior unless labeled)

| K | df = tr S | n.int | max r | mean r | q90 r | E[int cov] | E[bnd cov] | E[topκ cov] |
|---|---|---|---|---|---|---|---|---|
| 10 | 468.3 | 967 | 0.384 | 0.052 | 0.114 | 0.9494 | 0.9488 | 0.9494 |
| 12 | 370.9 | 953 | 0.401 | 0.079 | 0.169 | 0.9488 | 0.9479 | 0.9488 |
| 15 | 281.5 | 919 | 0.566 | 0.126 | 0.259 | 0.9470 | 0.9456 | 0.9471 |
| 18 | 226.0 | 885 | 0.850 | 0.179 | 0.353 | 0.9442 | 0.9420 | 0.9445 |
| 20 | 200.4 | 872 | 0.913 | 0.216 | 0.419 | 0.9416 | 0.9385 | 0.9424 |
| **22** | **179.7** | **856** | **1.195** | **0.254** | **0.501** | **0.9384** | **0.9339** | **0.9398** |
| 25 | 155.8 | 831 | 1.303 | 0.314 | 0.628 | 0.9323 | 0.9251 | 0.9349 |
| 28 | 137.4 | 811 | 1.571 | 0.378 | 0.753 | 0.9243 | 0.9132 | 0.9284 |
| 30 | 127.6 | 797 | 1.653 | 0.422 | 0.854 | 0.9177 | 0.9035 | 0.9234 |
| 35 | 108.4 | 773 | 2.213 | 0.542 | 1.083 | 0.8959 | 0.8741 | 0.9038 |
| 40 | 94.6 | 760 | 2.450 | 0.672 | 1.379 | 0.8666 | 0.8393 | 0.8775 |

(`r = |bias|/se`; full CSV with all columns, including mean |bias| and mean
se, in the artifact directory.)

## 3. Confirmatory MC smokes at the candidate K (audited G3a, R = 100)

Run with the same harness the acceptance run will use (drift guards ≤
5.6e-16; labeled smoke, **not** acceptance evidence):

| K | interior known σ (gate [0.93, 0.97]) | predicted | interior plug-in (gate [0.92, 0.98]) | boundary known | top-κ known |
|---|---|---|---|---|---|
| 22 | **0.9394** pass | 0.9384 | 0.9349 pass | 0.9330 | 0.9365 |
| 20 | **0.9420** pass | 0.9416 | 0.9363 pass | 0.9379 | 0.9418 |

The deterministic predictor matches realized MC coverage to ≈ 0.001 at both
candidates (and retrodicts the earlier inline-smoke K=30 failure: predicted
0.9177 on the audited design vs 0.9174 realized on the inline instance).
Empirical MC-SE of the interior average at R = 100 ≈ 0.0017; at the
acceptance R = 500 it scales to ≈ 0.0008.

## 4. Proposal

**Propose `K = 22`** — the largest grid value satisfying the resolution's
interior **mean** bias/se target (`0.254 ≤ 0.3`; the next grid point, K = 25,
exceeds it at `0.314`). At K = 22 the expected interior average coverage is
0.9384 and the realized smoke is 0.9394: a margin of ≈ +0.009 over the 0.93
gate bound, ≈ 11× the interior-average MC-SE at R = 500. Conservative
alternative if you prefer more margin: **K = 20** (mean r = 0.216, expected
0.9416, realized 0.9420, margin ≈ +0.012). I implement whichever you ratify;
nothing in the harness depends on the choice.

## 5. Admissions on the criterion

1. **The interior MAX bias/se target is unachievable on this truth at every
   grid K** (max r = 0.384 even at K = 10, where df = tr S ≈ 468 — i.e., a
   near-interpolating fit). A handful of interior points sit where
   `sin(πu₁)cos(πu₂)` has its largest second derivatives, and their
   *worst-point* coverage will be below nominal at any reasonable K (at
   K = 22 the interior q90 of r is 0.50). The gate's statistic is the
   interior **average**, which the calibration protects; per-point worst-case
   coverage is not protected, and the stratified STUDY output will show it.
   If you want per-point protection, that is the resolution's case-3 branch
   (bias-corrected band) — a separate decision, not folded in here.
2. The interior set varies with K by the ratified per-point `h_i` definition
   (n.interior: 967 at K=10 → 760 at K=40); the expected-coverage columns are
   computed on each K's own interior.
3. The expected-coverage column assumes exact gaussian noise and the exact
   `S` of the fixed configuration — the same assumptions under which the
   acceptance gate is meaningful; the two MC smokes are the empirical check
   of that assumption on the audited design (agreement ≈ 0.001).
4. Smoke artifacts: `audit_artifacts/e4_1_kcal_smoke_K22/`, `…_K20/`
   (R = 100, labeled `smoke-wiring`, dgp.source
   `amendment1-g3a (K-calibration smoke)`).

## 6. On ratification

I will: pin the ratified K in the acceptance invocation, run the acceptance
study (`n = 1200`, `R = 500`, known σ first, plug-in second, conditional on
the frozen design, fast path + drift guards; `fit.every.replicate = TRUE`
remains available to the auditor), produce the execution bundle on a clean
committed tree with the chosen K and realized interior bias/se recorded in
the manifest, and hand off factually.
