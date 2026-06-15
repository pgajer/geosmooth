# Contract §G4 resolution — E2.13 ridge-penalty alignment

Date: 2026-06-12. Resolves the open §G4 question (ridge-alignment ↔ Tier-0 default coupling) and
unblocks the Tier-2 implementer to build **E2.13**. Fold into the contract §G4; this is the
orchestrator sign-off the Tier-2 prompt requires before any default change.

## The question

E2.13 aligns the ridge penalty so the **constant direction is left unpenalized** (large ridge then
shrinks toward the local weighted mean, not toward 0). The current behavior — penalizing the constant
— is what the plan calls "a statistically wrong shrinkage target." §G4 asks: **should the aligned
penalty become the default, or be opt-in?** — because changing it touches the ridge defaults that the
accepted Tier-0 base (`b86b796`) and the regression pins depend on.

## Why this is not free (grounded in the actual defaults)

`fit.lps` currently defaults to:

- `design.basis = "orthogonal.polynomial.drop"` — the exact basis E2.13 targets (constant is a clean
  coordinate), and it is the **default**, so it is on the default path.
- `ridge.multiplier.grid = c(0, 1e-10, 1e-8)` — **not zero**. The default CV grid applies tiny but
  nonzero ridges.
- `ridge.condition.max = 1e12`.

At `ρ = 0` the penalty term vanishes and aligned ≡ legacy. But at the default grid's `ρ = 1e-10, 1e-8`
the two structures differ by a tiny, **nonzero** amount (below `1e-6`, above bit-for-bit). So making
the aligned penalty the **default** would change default-configuration fits at the tiny-ridge level —
enough to redden any pin that asserts exact reproduction (Tier-0 reproduction gates, E1.9's `b=1`
max-residual-`0` pin). That violates §A2 (new behavior must default to bit-for-bit current).

## Decision

**The aligned ridge is opt-in. The default preserves the current penalty structure bit-for-bit.**

This **ratifies the implementer's item-12 proposal** (`t2_spec_questions_implementer_2026-06-11.md`)
with the specifics below.

1. **Argument:** `ridge.shrinkage.target = c("zero", "local.mean")`, **default `"zero"`** — the
   implementer's name, adopted (it describes the user-visible semantics, not the matrix mechanism).
   `"zero"` runs today's code path unchanged (shrinks toward 0); `"local.mean"` activates the aligned
   solve (large ridge shrinks toward the local weighted mean).
2. **Opt-in only.** The aligned path runs **only** when `ridge.shrinkage.target = "local.mean"`. The
   default path is untouched, so **no Tier-0 or E1.9 re-pin is needed**. The contract's "pre-fix test
   documents the shrink-to-zero behavior" becomes a **permanent regression pin** of the default
   `"zero"` arm, which doubles as the §A2 GATE for the new argument.
3. **Scope: gaussian / WLS solver only — RATIFIED.** The defect is specific to the **orthogonal-basis**
   branch (the default basis; `monomial`/`weighted.qr*` already leave the constant unpenalized via
   `diag(c(0,1,…))`). E2.13 aligns the gaussian WLS solve there. The **logistic solver's identical
   penalty is explicitly out of scope** — aligning it would perturb the binomial path E2.14 just
   stabilized, and its natural target (shrink η toward `qlogis(weighted event rate)`) differs from the
   weighted mean; that is a separate future gate. Roxygen must not promise logistic behavior it does
   not implement.
4. **Construction: weighted-centering reparametrization — RATIFIED.** Solve the penalized system on the
   weighted-centered response and the non-constant directions, then add back the local weighted mean
   (the standard equivalent of leaving the constant function unpenalized): `ρ → ∞` tends to the local
   weighted mean exactly, `ρ = 0` is the unpenalized WLS. (The literal "unpenalized constant direction
   in the transformed basis" alternative is also acceptable; the GATE holds for both.)
5. `ridge.condition.max` default unchanged (`1e12`); the E2.13 GATE sets `Inf` per the plan so the
   chosen `ρ` is actually applied. R-backend-only (ridge `> 0` is R-only; `cpp` requires `ρ = 0`,
   where the two targets coincide).

**Forward intent (not part of this change):** `"aligned"` is the statistically correct behavior and
the recommended setting; document it as such. Flipping it to the **default** should be a deliberate,
separately-versioned, separately-audited change *after* downstream studies migrate and re-pin — out of
scope for E2.13, and not to ride in silently on this work.

## GATEs the Tier-2 implementer builds

- **E2.13 aligned-mode GATE** (plan §E2.13, `ridge.shrinkage.target="local.mean"`, `design.basis=
  "orthogonal.polynomial.drop"`, `ridge.condition.max=Inf`, singleton grids, `ρ∈{0,1e-8,1e-2,1,1e2}`):
  `|f̂_{ρ=1e2} − ȳ^w|` small relative to `|f̂_{ρ=1e2} − 0|` (shrinks to the local weighted mean, not
  zero); and `|f̂_{ρ=1e-8} − f̂_{ρ=0}| < 1e-6` (tiny-ridge invariance). Paired across `ρ` on the same
  data.
- **Legacy regression test** documenting the current shrink-to-**zero** behavior under the default
  `ridge.shrinkage.target="zero"`, so the contrast is intentional and visible (plan: "a pre-fix test
  documents the shrink-to-zero behavior").
- **§A2 backward-compat GATE:** default-mode fits (`ridge.shrinkage.target="zero"`, default grid/basis) are
  **bit-for-bit** identical to pre-change fits — the pin that protects Tier-0 and E1.9.

## Mutation (the auditor's, not the implementer's)

A wrong alignment — still penalizing the constant direction, or penalizing the wrong coordinate — must
push `f̂_{ρ=1e2}` away from the local weighted mean (toward 0), reddening the aligned-mode GATE. The
backward-compat GATE must redden if the "legacy" path is altered.

## Impact

- **No re-pin of Tier-0 or E1.9** — the default path is unchanged.
- **Unblocks the Tier-2 implementer** to build E2.13 under these terms (the last of E2.14 → E2.12 →
  E2.13).
- **Integration:** E2.13's edit is localized to the penalized-solve code, distinct from e19's
  kernel-weight/bandwidth body. It should not widen the e19↔t2 `fit.lps` overlap beyond the existing
  top-of-`fit.lps` plumbing (signature / arg-clean / CV grid), but the integrator should re-check the
  solve-region hunks once E2.13 lands, per the integration plan.

## Status

**§G4 resolved.** Tier-2 may implement E2.13 as an opt-in `ridge.shrinkage.target="local.mean"` with the default
preserving current behavior bit-for-bit. Log as a contract amendment alongside the §G1/§G2/§G5
resolutions.
