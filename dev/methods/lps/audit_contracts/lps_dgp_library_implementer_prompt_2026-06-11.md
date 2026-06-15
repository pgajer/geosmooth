# LPS DGP Library — Implementer Agent Prompt (Amendment 1: the shared data-enabler)

Paste this entire file into a fresh agent session.

## Setup — HUMAN STEP, before launching this agent

A Claude Code session's root directory is fixed at launch; an agent **cannot** relocate itself into a worktree by `cd`-ing. So **you (the human) create the worktree and launch the agent from inside it** — never launch this agent in `~/current_projects/geosmooth` itself (that shares the branch with every other agent and corrupts their work).

```sh
cd ~/current_projects/geosmooth
git worktree add -b codex/geosmooth-dgp-library ~/current_projects/geosmooth-dgp b86b796
cd ~/current_projects/geosmooth-dgp && claude     # launch the agent HERE, then paste this prompt
```

## FIRST — verify your isolation (do this before anything else)

Run `git branch --show-current`. It **must** print `codex/geosmooth-dgp-library`. If it prints `codex/geosmooth-tier0-bucket2-isolated` or anything else, you are in the shared main checkout — **STOP immediately: do not edit, commit, or run anything, and tell the orchestrator.** Only once this check passes: commit in-progress work (**never** `git stash --include-untracked`), and never touch other agents' worktrees/branches (`geosmooth-e19` = Tier 1, `geosmooth-t2` = Tier 2, `geosmooth-t4` = Tier 4).

## Shared reading (before any work)

- Contract — read **Amendment 1** and **§A** (conventions): `/Users/pgajer/current_projects/geosmooth/project_briefs/lps_tiers1to4_contract_2026-06-11.md`
- Brief — **§2 "DGP / synthetic-dataset assets"** and §3 (the G-tag map): `/Users/pgajer/current_projects/geosmooth/project_briefs/lps_tiers1to4_project_brief_2026-06-11.md`
- Frozen spec — **§sec:dgp** (the exact G1–G7 definitions you must match) and §sec:rng / §sec:tol (conventions): `/Users/pgajer/current_projects/geosmooth/project_briefs/lps_experimental_plan_2026-06-09.tex`
- Non-manifold dataset spec — the standard dataset-object common contract + frozen FB01–FB14 registry: `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_local_auto_nonmanifold_dataset_specs_2026-06-05.md`
- Workflow + **Audit Charter**: `/Users/pgajer/.codex/notes/workflows/worker_auditor_workflow.md`

## Role

You are an **Implementer** for the LPS Tiers 1–4 program in the `geosmooth` R package, building **shared infrastructure**, not a single gate. You build code + a frozen registry + a factual handoff; an independent auditor verifies it. You are not the auditor.

Conventions that bind you: RNG discipline (`set.seed` immediately before each draw; replicate `r` uses seed `s0+r`); reproducibility (every artifact records `sessionInfo()`, package version + git hash, BLAS id, seeds); commit on your worktree branch (don't stash); raise spec questions in writing to the orchestrator as **versioned amendments**, never silent reinterpretation. Your handoff (`phase_handoffs/dgp_library_implementer_handoff_<date>.md`) is **facts and admissions only** — files changed, exact commands, what each generator binds to, the registry path + checksums, and a mandatory **"Limitations and unverified claims"** section. No audit questions, no suggested verdict, no "what to inspect" checklist.

## Assignment — Amendment 1: consolidate the DGP library

You are building the program's **cross-cutting data enabler**: the single, plan-conformant DGP module that every STUDY in Tiers 1/3/4 will consume. This is contract **Amendment 1**. It is a **consolidation, not a green-field build** — the generators mostly already exist; gather, bind, and freeze them, do **not** reinvent.

**Deliverable:**

1. `R/dgp_library.R` — **one exported function per plan G-tag**, with the plan's **exact** parametrization (§sec:dgp), each returning the **standard dataset object** (per the non-manifold spec's common contract): `U`/`Z` intrinsic coords, `X` observed coords, `truth` (noiseless `f`), `y` (noisy response), `sigma`, `seed`, and region labels where defined.
2. `tests/testthat/test-dgp-library.R` — a `testthat` file asserting each generator's **fidelity**: correct object shape/fields; correct geometry (e.g. G3a apex curvature `= 1/R`; G6 realized prevalence ≈ target, `p ∈ [0.05,0.95]`; G7 rows sum to 1 with the documented zeros); and **determinism** (same seed → bitwise-identical output).
3. A **frozen registry** (`dgp_registry.csv` or `.rds` + manifest) with one row per canonical dataset: `dataset.id`, G-tag, parameters, `n`, `seed`, and a **SHA-256** of the materialized object — reuse the Tier-0 evidence-bundle discipline.

**Bind each G-tag (consolidate; wrap/adapt, do not fork):**

| Tag | Bind to |
|---|---|
| G1 | `make.flat.dataset()` + the plan's degree-`p` polynomial truth |
| G2 | flat helper + a fixed random orthonormal frame `Q` (small add) |
| G3a | `make.quadform.dataset(dim=2,…)` / `quadform.sample.dataset()` / geosmooth `2d_curved_paraboloid` |
| G3b | sphere cap — add (quadform approximation or explicit cap) |
| G3c | 1-D helix — add (small) |
| G3d | quadform saddle / geosmooth `2d_curved_saddle` (+ torus add) |
| G4 | SYN-RANK-BLOCKS / SYN-TWO-PLANES / SYN-PARA-LINE / SYN-SADDLE-LINE (frozen FB10–FB14) |
| G5 | SYN-DISK-CLUSTERS + a repeated-measures cluster model (add) |
| G6 | `scripts/lps_binary_gm_ff_helpers.R` + the binary factorial manifest |
| G7 | LA-* (FB01–FB09), SYN-SIMPLEX-FACES (FB13), LA-13K-SUB |

Source helpers (read, then **vendor/adapt into `R/dgp_library.R` with provenance comments** — prefer self-containment over fragile cross-repo `source()`):
- `~/current_projects/trend_filtering/development/ssrhe_hessian_energy/ssrhe_order3_l1_validation_helpers.R` (`make.flat.dataset`, `make.quadform.dataset`, `make.1d.dataset`, `quadform.embed`, `coeff.base`, `add.noise`)
- `~/current_projects/gflow/R/quadform_geodesics.R` (`quadform.sample.dataset`)
- geosmooth's own `scripts/lps_binary_gm_ff_helpers.R`, `scripts/freeze_lps_local_auto_nonmanifold_first_batch.R`
- the frozen FB01–FB14 assets under `split_handoffs/lps_local_auto_nonmanifold_first_batch_2026-06-05/`

**Acceptance (the independent auditor confirms):** each generator emits the standard object and **matches the plan's DGP definition, not a hand-rolled variant**; the registry is frozen with seeds + SHA-256; determinism holds. Only then may any STUDY consume it.

**Priorities:** the studies waiting on you are E1.9c (G3a/G3d), E3.1 (G3a/G3b/G3d), E3.2 (G3a), E4.1 (G3a). So **deliver G3a first**, then G3d, G3b — that unblocks the most downstream work soonest. If a G-tag's parametrization genuinely cannot be met by the existing assets, raise it as an amendment to the orchestrator — do not silently approximate.
