# Tier-0 Final Acceptance — Implementer Work Order

Date: 2026-06-11
From: orchestrator
To: implementer agent
Re: the two items that stand between "smoke-accepted" and "Phase-0 final"

## Status

Tier-0 (E0.1–E0.8) is **smoke-accepted, release-pending**. The independent 2026-06-11 re-audit confirmed clean smoke evidence for both backend tokens and listed the remaining final-acceptance gates. Two substantive items remain. **One is yours** (the full-size run, and any fixes it surfaces). **One is the auditor's** (mutation/falsification) — you prepare for it and hand off, but you do **not** run it as your own acceptance evidence.

Do not relax any frozen threshold to make something pass. If a full-size claim genuinely fails, that is a real finding to report, not a number to loosen.

## Task 1 — Full-size evidence, efficiently (yours)

The accuracy gates E0.5 (consistency/rate) and E0.6 (binary recovery/calibration) have only run at smoke size. Produce the frozen-spec full-size evidence — but **do not run the heavy battery twice**. The entire Tier-0 `testthat` battery uses `backend="R"`, so it is **identical for both native tokens**; only the parity probe (`backend_parity.csv`) depends on `LPS_NATIVE_BACKEND`. So run the full battery **once**, and capture the second token's parity with a fast probe-only pass.

**1a. Small harness change first** (this edits an accepted Tier-0 asset, so it goes through the audit loop). In `scripts/ci/run_tier0_execution_artifact.sh`:
- Put the backend token in the bundle directory name — `OUT="audit_artifacts/tier0_${STAMP}_${LPS_NATIVE_BACKEND:-cpp}"` — so two runs in the same second cannot collide on the same folder.
- Add a **probe-only mode** (e.g. `MODE=probe`): run the binding + environment steps (git head, `tree_clean`, source checksums, `sessionInfo`, BLAS) and the probe, **skipping the `testthat` battery**, and write the manifest marked `mode: probe`. Put the rationale in a script comment: the battery is backend-token-independent, so it need run only once; the probe carries the only per-token output.

**1b. Clean tree — commit, do not stash.** Commit any in-progress work to a WIP branch; confirm `git status --porcelain` is empty. (A dropped `git stash -u` loses untracked work; a WIP commit cannot.)

**1c. Run the full battery once** (token `cpp`) — this is the full **gate** bundle (full-size E0.1–E0.8 + headroom + determinism + `cpp` parity):
```sh
LPS_TIER0_FULL=1 LPS_NATIVE_BACKEND=cpp bash scripts/ci/run_tier0_execution_artifact.sh
```
Expect it to be slow: E0.5 runs `n` up to 3200 × R=30; E0.6 runs `n` up to 4000 × R=40 across prevalences. Budget accordingly.

**1d. Capture the second token's parity** (probe-only, **same commit**) — a fast parity addendum:
```sh
LPS_TIER0_FULL=1 LPS_NATIVE_BACKEND=cpp.local.pca MODE=probe bash scripts/ci/run_tier0_execution_artifact.sh
```

**1e. Confirm.** The full bundle reports `tree_clean: true`, `failed=0 error=0 warning=0`, gate coverage `E0.1…E0.8`, the one sanctioned E0.3a skip, and `cpp` parity `ok`. The probe-only bundle reports the **same `git_head`**, `tree_clean: true`, `mode: probe`, and `cpp.local.pca` parity `ok`. The full bundle is the gate evidence; the probe-only bundle is the second-token parity addendum.

*(Fallbacks: if you would rather not touch the harness, run two full harness invocations sequentially — correct, but it re-does the heavy battery. For true parallelism, use two `git worktree`s of the same clean commit to avoid the shared-`src/` compile race and the output-dir collision; with the battery running only once, though, parallelism buys little.)*

## Task 2 — Fix anything the full run surfaces (yours)

The smoke thresholds for E0.5/E0.6 were authored without execution, so the full run is the first real test of the claims. If either fails at full size:

- **E0.6 (most at risk).** The smoke failure mode was a *positive* slope — RMSE not converging — caused by holding the support grid fixed across `n` (a variance floor). The fix is to **grow the support with `n`** on the optimal schedule (mirror E0.5's `k(n) ∝ n^{4/(d+4)}`), **handle `NA` fitted probabilities** in the RMSE (exclude + record the NA fraction), and **restore the full prevalence set** `{0.1, 0.3, 0.5}` per the frozen DGP. Stratify all metrics by the logistic fallback fraction (spec safeguard).
- **E0.5.** Confirm the log-RMSE-vs-log-`n` slope CI lies below `-0.1` at full size; if not, verify the bandwidth/support schedule actually grows with `n` (otherwise a bias/variance floor masks convergence).
- **Do not** weaken the frozen `-0.1` slope criterion or the `[0.8,1.25]`/`[-0.25,0.25]` calibration bands. If the claim genuinely fails after a correct schedule, report it as a real `lps.R` finding for the orchestrator to adjudicate.

## Task 3 — Keep smoke-vs-full honest (yours)

The default CI run stays **smoke** (fast regression catch); the full bundle is the **release** evidence. Make sure the harness/manifest and the contract label the two distinctly so a smoke run is never read as the full-mode gate. (The auditor already softened the CI wording — keep it that way.)

## Task 4 — Prepare for mutation, but do not run it as acceptance (auditor's step)

Mutation-qualification — planting a bug and confirming each gate turns red — is the **auditor's** job, because you authored the gates. Your part is to make it turnkey for them: in your handoff, list, per gate, the exact one-line mutation the contract/brief expects to redden it, and confirm each is a single, easily-reverted change:

| Gate | Mutation that must turn it red |
|---|---|
| E0.1 | perturb a design-centering constant → reproduction error explodes |
| E0.2 | inject `y`-dependence into the weights → identity/df residual blows up |
| E0.4 | mis-center the degree-1 fit → boundary ratio fails |
| E0.5 | pin support `k` constant (bias floor) → slope CI no longer < −0.1 |
| E0.6 | mis-clip probabilities → calibration slope leaves band |
| E0.7 | leak `y_i` into its own fold's training → perturbation delta ≫ 1e-12 |
| E0.8 | force a silent mean fallback under `unstable.action="na"` → "no silent mean" assertion fails |

Do **not** report "I ran these and they reddened" as acceptance evidence; that is the auditor's independent finding.

## Deliverable

A factual handoff at `phase_handoffs/lps_tier0_final_acceptance_implementer_handoff_<date>.md` — files changed (including the harness probe-only/`OUT`-naming change), exact commands, the full gate-bundle path and the second-token probe-only parity-bundle path, the full-size E0.5/E0.6 numbers, whether tests/source were modified, and a mandatory **"Limitations and unverified claims"** section. **No audit questions, no suggested verdict, no "what to inspect" checklist.** Then hand off to the auditor for mutation-qualification and the final Tier-0 verdict. Tier-0 is **not** final-accepted until that independent pass exists — a green full bundle alone is necessary, not sufficient.
