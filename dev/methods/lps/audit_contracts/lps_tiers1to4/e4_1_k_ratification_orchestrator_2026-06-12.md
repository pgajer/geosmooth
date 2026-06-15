# E4.1 Part B — K ratification and per-point disposition

Date: 2026-06-12. Responds to the t4 implementer's Item-4a calibration (proposal doc
`e4_1_k_calibration_proposal_2026-06-12.md`, commit `6e717c3`). The calibration is accepted as sound:
the binding loads `dgp.g3a` from the audited DGP commit `58f5ab9` and hard-verifies
`G3a-R1-smooth-s010-n1200` against the frozen SHA-256, and the bias table is exact (deterministic at a
fixed configuration). Part A audit verdict (`0a21eba`, ACCEPT) preserved — good.

## K decision: pin **K = 20** (kernel `tricube`)

The calibration did its job — and seeing the table, I pin **K = 20**, not the criterion-maximal K = 22.

| K | interior mean bias/se | interior max | expected interior coverage |
|---|---|---|---|
| 15 | 0.126 | 0.566 | 0.9470 |
| **20** | **0.216** | **0.913** | **0.9416** |
| 22 | 0.254 | 1.195 | 0.9384 |
| 25 | 0.314 | 1.303 | 0.9323 |

Reasoning: my "largest K with interior-mean ≤ 0.3" rule was a pre-calibration heuristic; the data now
shows it lands K = 22 at interior coverage **0.9384 — on the low edge** of the `[0.93, 0.97]` band,
with a heavy per-point tail (worst interior point bias/se ≈ 1.20, ≈ 0.78 coverage). K = 20 gives
**0.9416** — more floor margin — and a materially lighter worst-point tail (max bias/se ≈ 0.91, worst
point ≈ 0.85 coverage), for a cleaner "interior matches nominal" demonstration while still showing
boundary degradation. K = 20 is your own smoke-validated conservative alternative (`0.9420` at R=100),
so no new calibration is needed — just run at 20. (K = 22 also *passes*; this is a margin/cleanliness
refinement, not a correction. If you'd prefer interior coverage essentially at nominal, K = 15 → 0.947
is the most conservative option.)

## Per-point limitation: a correct finding — report it, don't fold in the fix

The admission is right and worth stating plainly: a **variance-only band cannot achieve per-point
interior coverage on a curved truth at any K** — bias peaks where `|f″|` peaks, so a few interior
points under-cover regardless of smoothing (even K = 10 has interior max bias/se 0.384). This is not a
defect in the variance formula or the implementation; it is the known limitation the spec anticipates.

Disposition:

1. **The spec's E4.1 gate is the interior-*average* coverage** ∈ `[0.93, 0.97]`, which K = 20 meets
   with margin. That is the acceptance criterion — unchanged.
2. **Report the per-point limitation honestly** in the study: the stratified results already isolate
   the top-curvature-decile (which captures the worst-|f″| points), and the manifest must record the
   realized interior **mean and max** bias/se at the chosen K, so the interior coverage figure is
   attributable to residual bias, not mistaken for a formula error.
3. **Do not fold the bias-corrected band (the spec's case 3) into E4.1.** Unlike E2.15, this is real
   new methodology (bias estimation + band correction), not a hygiene fix — it deserves its own design
   and gate. **Logged as a deferred future extension** ("E4.2 — bias-corrected pointwise band"), to be
   scoped deliberately later, not now.

## Manifest requirement

The acceptance bundle records: the chosen **K = 20**, kernel `tricube`, the frozen design seed, the
realized **interior mean and max bias/se**, and both **known-σ** and **plug-in σ̂** interior coverage,
plus the boundary and top-curvature-decile strata reported separately (never averaged into the interior
headline).

## Next

On this sign-off the implementer runs the acceptance study (n = 1200, R = 500, known σ then plug-in,
conditional on the frozen design, drift-guarded fast path) at **K = 20**, produces the bundle with K and
realized bias/se in the manifest, and hands off to the auditor for the **Part B audit**. That clears t4
(the clean, additive branch in the integration plan).
