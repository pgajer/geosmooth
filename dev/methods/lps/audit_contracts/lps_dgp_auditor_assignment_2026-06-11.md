You are the independent auditor for the LPS Tiers 1–4 program in the `geosmooth` R package. Your
standing role, rules, deliverable shape, and do-not list are in
`/Users/pgajer/current_projects/geosmooth/project_briefs/lps_e19_auditor_prompt_2026-06-11.md`
(everything above its "FIRST ASSIGNMENT" heading) — read it first; it applies here unchanged. The
program docs are not committed on this branch; read them from the e19 branch (all worktrees share one
`.git`):

```sh
git show codex/geosmooth-e1-9-bandwidth-multiplier:project_briefs/lps_experimental_plan_2026-06-09.tex > /tmp/plan.tex   # §sec:dgp = G1–G7
git show codex/geosmooth-e1-9-bandwidth-multiplier:project_briefs/lps_tiers1to4_contract_2026-06-11.md > /tmp/contract.md  # Amendment 1 + §A
```

This is your **DGP-library assignment** (contract **Amendment 1**). It is **infrastructure, not a
gate**: you are certifying that every generator the downstream studies will consume matches the plan's
exact data-generating definition and is frozen reproducibly. A wrong generator silently poisons every
study built on it, so this verdict gates all DGP-consuming work (E1.9c, E3.1, E3.2, E4.1 Part B).

## Target

Branch `codex/geosmooth-dgp-library`, worktree `~/current_projects/geosmooth-dgp` (tip `c0e0d17`,
*"Freeze DGP-library registry and add implementer handoff"*). Deliverables: `R/dgp_library.R`,
fidelity tests `tests/testthat/test-dgp-library.R`, the frozen registry
`inst/dgp_registry/dgp_registry.csv` (+ `dgp_registry_manifest.md`, `sessionInfo.txt`) built by
`scripts/freeze_dgp_registry.R`, and `phase_handoffs/dgp_library_implementer_handoff_2026-06-11.md`
(evidence + admissions only).

## First — verify where you are

```sh
pwd                          # …/geosmooth-dgp — NOT the shared main checkout …/geosmooth
git rev-parse HEAD           # RECORD this (expect c0e0d17 or later); the SHA your verdict certifies
git status --short           # MUST be empty — if dirty, the implementer may still be active → STOP, tell the orchestrator
```

You audit in place; any scratch you create (re-materialized objects, checksums) goes in `/tmp`, never
committed. Do not commit to this branch; deliver your verdict as a file.

## What to verify (plan §sec:dgp + Amendment 1)

1. **One exported function per G-tag**, each returning the **standard dataset object** (intrinsic
   coords `U`/`Z`, observed `X`, noiseless `truth`, noisy `y`, `sigma`, `seed`, region labels where
   the tag defines them), and matching the plan's **exact** parametrization — not a hand-rolled
   variant. The bindings that matter most downstream are **G3a, G3d, G1, G6** (verify these first).
2. **Frozen registry**: one row per canonical dataset with `dataset.id`, G-tag, parameters, `n`,
   `seed`, and a **SHA-256** of the materialized object. Re-materializing from the recorded seed must
   reproduce the recorded SHA.
3. **Determinism**: same seed → **bitwise-identical** output (RNG discipline per plan §sec:rng).

The mandate was *consolidate existing generators, do not reinvent* — but you judge the **output against
the plan**, regardless of source. Provenance comments are nice; a generator that matches the plan's
geometry is what's required.

## Known weak points — scrutinize first

- **G3a curvature normalization.** Plan: `X = (u₁, u₂, (u₁²+u₂²)/(2R))`, apex principal curvature
  `κ = 1/R`. An off-by-2 in the quadratic coefficient gives `κ = 2/R` — passes a loose smell test,
  fails the geometry. Measure realized apex curvature, don't trust the comment.
- **G1 truth.** Plan (D=2, p=2): `f(x) = 0.5 + 1.0x₁ − 0.7x₂ + 0.4x₁² + 0.3x₁x₂ − 0.6x₂²`, noiseless
  unless stated. Check every coefficient and that `truth` is noiseless.
- **G6 clip + prevalence.** `p(x) = expit(α + η(x))` clipped to `[0.05, 0.95]`, `α` chosen for target
  prevalence, default `η = 1.5 sin(π x₁)`. Confirm no `p` escapes `[0.05, 0.95]` and realized
  prevalence ≈ target.
- **G7 simplex + structural zeros.** Rows sum to 1 after renormalization, with the *documented* subset
  of parts at exact 0.
- **Determinism leaks.** Any draw not preceded by `set.seed` (or using a global stream) breaks
  reproducibility and the registry SHA.

## Mutation / falsification (the core deliverable)

For each generator, break the property and confirm its **fidelity test turns red**. A fidelity test
that stays green under its mutation does not verify that generator → reject it (and block any study
that would consume it). Restore (`git checkout -- R/dgp_library.R`) between mutations; never commit one.

| Generator / check | Plan property | Mutation that MUST redden its test |
|---|---|---|
| G3a geometry | `X₃ = (u₁²+u₂²)/(2R)`, apex `κ = 1/R` | change the coefficient (`/(2R)` → `/R`) → measured apex curvature ≠ `1/R` → red |
| G1 truth | exact degree-2 polynomial above | perturb one coefficient → truth-field assertion fails → red |
| G6 clip | `p ∈ [0.05, 0.95]` | remove the clip → some `p` escapes the band → red |
| G7 simplex | rows sum to 1, documented zeros | skip the renormalization → row sums ≠ 1 → red |
| determinism | same seed → bitwise identical | replace a seeded draw with an unseeded `runif` → two calls differ → red |
| registry freeze | recorded SHA reproduces from seed | corrupt one registry parameter → re-materialized SHA ≠ recorded → mismatch caught |

## Run + reproduce

```sh
cd ~/current_projects/geosmooth-dgp
git status --short                       # empty
Rscript -e 'pkgload::load_all(".", quiet=TRUE); library(testthat); test_file("tests/testthat/test-dgp-library.R")'  # load_all first, or the generators/package internals aren't found
```

Independently: re-materialize **at least G3a** from its registry seed (`inst/dgp_registry/dgp_registry.csv`),
recompute the SHA-256, and match `inst/dgp_registry/dgp_registry_manifest.md`; call one generator twice
with a fixed seed and confirm bitwise equality; for G3a compute the realized apex curvature yourself and
confirm `= 1/R`.

## Deliver

`audits/dgp_library_audit_<your-run-date>.md` per the standing Deliverable shape: an accept/reject
**per G-tag**, the mutation table with red/green results, which tags are registry-frozen and reproduce
their SHA, the determinism confirmation, and a **downstream-unblock statement** (which studies each
accepted tag releases: G3a → E1.9c/E3.1/E3.2/E4.1 Part B; G3d → E1.9c/E3.1; G5 → E1.10b; G6 → E2.x).
Leave it untracked for the orchestrator; do not commit to `codex/geosmooth-dgp-library`. Flag any tag
not yet conformant as **blocking** its dependents.
