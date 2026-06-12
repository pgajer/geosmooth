# E4.1 spec-questions resolution — orchestrator ratification

Date: 2026-06-12. Responds to `geosmooth-t4/audit_contracts/lps_tiers1to4/e4_1_spec_questions_implementer_2026-06-11.md`.
Disposition per item below. **Net: Part A is ratified as designed (proceed to audit unchanged); Part B
is unblocked — G3a is now audit-accepted, and the four open questions are answered here, with one that
requires a short calibration step (Item 4a).**

Overall: a strong, well-reasoned submission. The separate-file (`R/lps_uncertainty.R`),
no-`fit.lps`-change design is endorsed emphatically — it keeps t4 **additive** (clean merge per the
integration plan) and gives the GATE two genuinely different `S` routes (analytic influence row vs.
E0.2 `fit(e_j)`), which is the non-circularity the audit needs. The honest admission that §A2(i) is
vacuous-by-construction for Part A is the correct reading.

## Ratified as proposed

- **Item 1 — two exported functions, no `fit.lps` change.** RATIFIED. Keep the analytic row as the
  implementation route and the E0.2 `fit(e_j)` probe as the GATE's independent route. Keep the
  self-guard (`max|S·y − fitted.raw| ≤ check.tol`). One note for the auditor (not a change): the two
  routes share the geometry helpers (`.klp.kernel.weights`, KNN, chart) and differ in the
  influence/solve step — that is adequate independence for the variance check, and the auditor will
  mutation-qualify it.
- **Item 2 — configuration envelope.** RATIFIED, including `orthogonal.polynomial.drop`-only (the
  consistent normal-equations route is the right call), `X.eval == X` for `lps.pointwise.band`,
  rectangular `S` allowed for `lps.smoother.matrix`, and rejecting `auto`/`local.auto` chart modes.
  Widening (other bases, new-point bands, `bernoulli`) is a future amendment, as you say.
- **Item 4d — boundary stratum `h`.** RATIFIED: per-eval-point realized `h_i` as the primary
  flag, global `h = median_i h_i` reported alongside, strata never averaged into the interior
  headline.
- **Item 5 — coverage fast path (`ŷ_r = S y_r`).** RATIFIED. It is algebraically exact by the
  **accepted** E0.2 linear-smoother identity, not an approximation; the drift guard (full `fit.lps`
  at replicate 1, every 25th, and last, `≤ 1e-10`) is the right safety net. Keep
  `fit.every.replicate = TRUE` — the auditor will use it to reproduce acceptance evidence without the
  shortcut.

## Confirmed (info readings — proceed)

- **Item 3 — NA/fallback rows** (mean→`w/Σw`, na→all-`NA`; GATE asserts zero `NA`s): correct.
- **Item 4c — conditional-on-design coverage** (one frozen `X` by recorded seed, noise redrawn per
  replicate `s₀+r`): **confirmed — this is the intended reading.** It matches the variance formula
  (`S` depends only on `X`) and is the only reading under which per-point stratification
  (interior/boundary/curvature) is meaningful. Do not redraw the design per replicate.
- **Item 6 — Part A GATE fixture** (ambient + `local.pca` cases, `fit.lps(e_j)` reference, all
  assertions `≤ τ_alg = 1e-10`, negative controls): confirmed. This is the deterministic unit GATE the
  spec asks for; the `fit(e_j)` reference is exactly the independent route the audit requires.
- **Item 7 — execution bundle** (Tier-0 pattern; smoke labeled `inline-smoke`, "never acceptance
  evidence"): confirmed.
- **Item 8 — naming** (`lps.smoother.matrix`, `lps.pointwise.band`): confirmed, keep as-is.

## Answers to the Part-B blockers

**Item 4b — G3a curvature `R`: pinned to `R = 1`.** Use the frozen registry row
**`G3a-R1-smooth-s010-n1200`** (`dgp.g3a`, R=1, truth=smooth, σ=0.1, n=1200, seed=1) — that row *is*
the E4.1 DGP, already audit-accepted. `curvature.radius = 1`.

**Item 4a — support size `K` and kernel: needs a short calibration, not a blind pin.** This is the one
that matters. The band is variance-only, and the **known-σ** interior coverage is therefore a *direct*
test of interior bias: if the degree-1 fit over-smooths the `sin(πu₁)cos(πu₂)` truth at `R = 1`, the
interior under-covers for a **bias** reason, not a variance-formula reason — and `K = 30` may well be
too large for that. So:

1. Kernel: **`tricube`** (pinned).
2. Before the acceptance run, run a smoke calibration on `G3a-R1-smooth-s010-n1200`: report the
   realized **interior bias-to-se ratio** `max_i |E[ŷ_i] − f(x_i)| / se_i` (or its interior mean) as a
   function of `K`. **Pin the largest `K` whose interior bias/se is small enough that bias cannot move
   coverage out of band** — target interior bias/se ≲ 0.3 (bias contributes ≲ ~10% of MSE). Propose
   that `K` back to me with the bias/se table; I ratify the number. Record the chosen `K` and the
   realized interior bias/se in the bundle, so the coverage GATE's `[0.93, 0.97]` is unambiguously a
   test of the variance formula.
3. If *no* reasonable `K` gives a bias-negligible interior at `R = 1`, that is itself the finding: the
   variance-only band needs the spec's bias-corrected branch ("if a bias-corrected band is
   implemented, re-test interior+boundary"). Raise it rather than forcing `K` down to an unnatural
   value.

(The Part A unit GATE's `K = 18` fixture is unaffected — it is deterministic algebra; this calibration
is only for Part B's coverage config.)

## Status

- **Part A:** ratified as built → proceed to the t4 Part-A audit (the streamlined t4 auditor
  assignment already covers it).
- **Part B:** unblocked — consume `G3a-R1-smooth-s010-n1200`, `tricube`, `K` per the 4a calibration,
  conditional-on-design coverage, fast path with drift guard. Acceptance run after you send the K
  calibration and I ratify it.
- **Integration:** the new-file design keeps t4 additive; nothing here changes its clean-merge status.

Fold this into the contract as the E4.1 spec-question resolution, alongside §G1/§G2/§G5/§G4.
