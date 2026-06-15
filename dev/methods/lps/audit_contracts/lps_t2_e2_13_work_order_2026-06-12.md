# Tier-2 work order — E2.13 + E2.15 (and status confirmations)

Date: 2026-06-12. To the Tier-2 implementer (worktree `geosmooth-t2`, branch
`codex/geosmooth-t2-binary-hygiene`, tip `c621e2f`). Your standing implementer role and conventions
apply unchanged. This responds to your spec-questions doc and the independent Tier-2 audit.

## Status — what's settled, what's next

- **E2.14 — accepted.** No action. (Item 3: your **always-on** step-halving reading was correct and is
  confirmed; the audit reran the full Tier-0 battery and E0.6 held, so the §A2 tension you flagged is
  resolved in practice.)
- **E2.12 — your audit-required fix is the right call and is already in** (`550d7e8`, option (a):
  bernoulli resolves to the R backend, explicit cpp errors, raw-RMSE fallback removed, gate added).
  **This goes to the auditor for re-audit — it is not more implementer work.** You do not need to
  re-touch it.
- **Item 11 (binomial NA-handling asymmetry): promoted to a Tier-2 gate — E2.15.** Implement it in this
  pass alongside E2.13 (see the E2.15 section below).
- **E2.13 — signed off. Implement it now** per the resolution below.

## E2.13 — sign-off (§G4 resolved; ratifies your item 12)

Authoritative sign-off: `project_briefs/lps_g4_ridge_resolution_2026-06-12.md`. Your item-12 proposal is
**ratified with its specifics**:

1. **Argument `ridge.shrinkage.target = c("zero", "local.mean")`, default `"zero"`** — your name,
   adopted. `"zero"` = current behavior **bit-for-bit** (default path unchanged); `"local.mean"`
   activates the aligned solve.
2. **Scope: the gaussian / WLS solver only — ratified.** The logistic solver's identical penalty is
   **out of scope** (it would perturb the binomial path you just stabilized, and its natural target is
   `qlogis(weighted event rate)`, not the weighted mean — a separate future gate). Roxygen must not
   promise logistic behavior it doesn't implement.
3. **Construction: weighted-centering reparametrization — ratified** (solve on the weighted-centered
   response + non-constant directions, add back the local weighted mean; `ρ→∞` → local weighted mean,
   `ρ=0` → unpenalized WLS).

GATEs to build (plan §E2.13, `design.basis="orthogonal.polynomial.drop"`, `ridge.condition.max=Inf`,
singleton grids, `ρ∈{0,1e-8,1e-2,1,1e2}`, paired across `ρ`):

- **Aligned-mode GATE** (`ridge.shrinkage.target="local.mean"`): `|f̂_{ρ=1e2} − ȳ^w|` small relative to
  `|f̂_{ρ=1e2} − 0|` (shrinks to the local weighted mean, not 0); `|f̂_{ρ=1e-8} − f̂_{ρ=0}| < 1e-6`.
- **Default-arm regression pin** (`ridge.shrinkage.target="zero"`): documents the shrink-**to-zero**
  behavior **and** serves as the §A2 bit-for-bit GATE that the default path is unchanged — this is the
  pin that protects Tier-0 and E1.9.

Per your item 13: rerun the **full Tier-0 battery** after the change and report any movement in E0.6's
realized statistics in the handoff (none expected — the default arm is untouched). **Do not run your own
mutation** as acceptance evidence (the auditor will: a wrong alignment that still pulls `f̂_{ρ=1e2}`
toward 0 must redden the aligned GATE; altering the `"zero"` path must redden the regression pin).

Deliverable: the code (new arg + aligned WLS branch), the `testthat` GATE, an execution bundle on a
clean committed tree (your Tier-2 harness pattern), and a handoff (facts + limitations). Commit on the
branch.

## E2.15 — binomial selection NA-consistency (folded in)

Implement alongside E2.13. Spec: `project_briefs/lps_e2_15_binomial_na_consistency_amendment_2026-06-12.md`.
Make binomial selection consistent with gaussian/bernoulli — **any candidate with a non-finite CV
prediction is unselectable** (`Inf`, the `.klp.rmse` convention) — instead of `.klp.logloss` dropping
non-finite pairs and letting an `NA`-heavy candidate win on its remainder. **Always-on** correctness fix
(behavior changes only on the defect class — `NA`-producing candidates; healthy-data selection is
unchanged), same stance as E2.14. GATE: a constructed binomial fixture with an `NA`-heavy candidate that
**wins under the old drop-`NA` rule** but is correctly unselectable under the fix — assert it is not
selected, its score is `Inf`, a complete-prediction candidate wins, plus a pre-fix demonstration in the
same file and a healthy-data regression pin. Rerun the full Tier-0 battery (E0.6 expected unchanged);
preserve the `logloss.clipped` diagnostic unless the fix subsumes it (document which). **Do not run your
own mutation** (the auditor reverts to drop-`NA` and confirms the `NA`-heavy candidate wins again).

## After you deliver

One **combined re-audit** covers: (i) E2.12 universal claim — the C++ gap is closed
(bernoulli+cpp errors, selection uses the clipped metric on every legal path) + its mutation; (ii)
E2.13 — the two GATEs above + mutations; (iii) **E2.15** — the `NA`-heavy candidate is unselectable +
its mutation; (iv) regression — E2.14 and the E2.12 R-path gates still green. That clears Tier-2 for
merge (it is the second `R/lps.R` branch in the integration plan, after e19).
