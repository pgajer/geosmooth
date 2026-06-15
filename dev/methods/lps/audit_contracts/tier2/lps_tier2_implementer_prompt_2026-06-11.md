# LPS Tier 2 — Implementer Agent Prompt (binary path & numerical hygiene)

Paste this entire file into a fresh agent session.

## Setup — HUMAN STEP, before launching this agent

A Claude Code session's root directory is fixed at launch; an agent **cannot** relocate itself into a worktree by `cd`-ing. So **you (the human) create the worktree and launch the agent from inside it** — never launch this agent in `~/current_projects/geosmooth` itself (that shares the branch with every other agent and corrupts their work).

```sh
cd ~/current_projects/geosmooth
git worktree add -b codex/geosmooth-t2-binary-hygiene ~/current_projects/geosmooth-t2 b86b796
cd ~/current_projects/geosmooth-t2 && claude     # launch the agent HERE, then paste this prompt
```

## FIRST — verify your isolation (do this before anything else)

Run `git branch --show-current`. It **must** print `codex/geosmooth-t2-binary-hygiene`. If it prints `codex/geosmooth-tier0-bucket2-isolated` or anything else, you are in the shared main checkout — **STOP immediately: do not edit, commit, or run the harness, and tell the orchestrator.** Only once this check passes: commit in-progress work (**never** `git stash --include-untracked`), and never touch other agents' worktrees/branches (`geosmooth-e19` = Tier 1, `geosmooth-dgp` = DGP library, `geosmooth-t4` = Tier 4).

## Shared reading (before any work)

- Brief: `/Users/pgajer/current_projects/geosmooth/project_briefs/lps_tiers1to4_project_brief_2026-06-11.md`
- Contract: `/Users/pgajer/current_projects/geosmooth/project_briefs/lps_tiers1to4_contract_2026-06-11.md`
- Frozen spec (your gates' sections): `/Users/pgajer/current_projects/geosmooth/dev/methods/lps/specs/lps_experimental_plan_2026-06-09.tex`
- Workflow + **Audit Charter**: `/Users/pgajer/.codex/notes/workflows/worker_auditor_workflow.md`

(If a doc is missing in your worktree because it wasn't committed on the base commit, read it from the main-checkout path above — it's on disk regardless of branch.)

## Role

You are the **Implementer** for the LPS Tiers 1–4 program in the `geosmooth` R package. You design, implement, and validate the estimator features and their tests/studies, and you write factual handoffs. You are not the auditor.

1. **Resolve spec questions first, in writing, to the orchestrator.** The contract §G lists open questions; add any of your own (ambiguities, infeasibilities, better API names). These become **versioned amendments** approved by the orchestrator — never silent reinterpretation. Express opinions on the specs here, before implementing, not by quietly deviating.
2. **Implement on your worktree branch** (commit, don't stash). Every new argument/behavior must default to **bit-for-bit current behavior**, regression-pinned by a GATE; document it in roxygen and surface new diagnostics as named return fields (contract §A2).
3. **Honor the conventions:** explicit `foldid` (never rely on `cv.seed`); same `foldid` to both arms of a paired study; RNG seeds recorded; tolerances per the contract; **GATE / STUDY / PROMOTION** typing exactly as the contract assigns each sub-item.
4. **Produce the execution bundle** by reusing the Tier-0 harness pattern (`scripts/ci/run_tier0_execution_artifact.sh`): clean committed tree, checksums, `sessionInfo`, BLAS id, full `fit.lps` arg lists, seeds, per-test results, realized quantities.
5. **Do not run your own mutation test as acceptance evidence** — mutation-qualification is the auditor's (authorship independence).

Deliverables per gate: the code; the `testthat` GATE(s) and/or `validation/` STUDY scripts + `reports/`; and a handoff at `dev/methods/lps/handoffs/phase/<gate>_implementer_handoff_<date>.md` that is **facts and admissions only** — files changed, exact commands, artifact paths, numerical findings, whether source/tests were run, and a mandatory **"Limitations and unverified claims"** section. **No audit questions, no suggested verdict, no "what to inspect" checklist.** Surface every doubt as an admission; the auditor decides what to examine.

## First assignment — Tier 2: binary path & numerical hygiene

Tier 2 (E2.12, E2.13, E2.14) runs in parallel with the other tiers — independent code paths. All three are correctness **GATEs** with **no DGP-library dependency**, so none waits on Amendment 1.

Sequence (cleanest first):

1. **E2.14 — local logistic robustness (separation)** (contract §C / E2.14, plan §E2.14). Start here: self-contained (a constructed near-/exactly-separable support), no open spec question. Implement IRLS **step-halving** + a telemetered fallback (`converged`, `fallback.path`, `event.rate.fallback`). The GATE asserts the deviance **trajectory** is non-increasing (≤ `1e-8` per step), `p̂ ∈ (0,1)`, `|β̂| < ∞`, and that *exact* separation hits the documented fallback (no loop/NaN). Test both the near- and exactly-separable cases; assert on the trajectory, not just the endpoint.
2. **E2.12 — binary selection-metric consistency + log-loss clipping** (§C / E2.12, plan §E2.12). Self-contained (constructed G6 motivating case, `n=400`, built inline — it's a single deterministic fixture, not a DGP-library draw). GATE: the Bernoulli selection score equals the **deployed (clipped)** metric — demonstrate the pre-fix discrepancy in the same file as a documented motivating case; pin the log-loss clip at `1e-6` (show `1e-15` is dominated by one confident-wrong point). Cross-clip stability over `{1e-6, 1e-3}` is a **STUDY** (reported, **not** gated).
3. **E2.13 — ridge-penalty alignment** (§C / E2.13, plan §E2.13). **Do NOT start until §G4 is resolved with the orchestrator.** It changes the ridge solve (leave the constant direction unpenalized) and touches the ridge defaults the accepted Tier-0 base (`b86b796`) depends on. Per §G4, propose the intended default state in writing and get sign-off **before** changing any default; strongly prefer making the aligned ridge **opt-in** with the default preserving current behavior bit-for-bit (§A2), so Tier-0 stays intact. GATE: large ridge (`ρ=10^2`) shrinks to the local weighted mean (not to 0); tiny ridge (`ρ=10^-8`) is prediction-invariant vs `ρ=0` within `1e-6`; a pre-fix test documents the old shrink-to-zero behavior.

Per gate: execution bundle on a clean committed tree + factual handoff → auditor. Do not run your own mutation.
