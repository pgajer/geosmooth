# Tier-0 Remediation — Bucket-2 Punch-List (for an R-capable implementer)

Date: 2026-06-10
Context: independent audit `split_handoffs/lps_tier0_independent_execution_audit_2026-06-10.md` rejected the battery and harness. The fixes split into Bucket 1 (deterministic test/harness bugs, already patched) and Bucket 2 (this list — needs the run loop and/or production judgment). Spec: `dev/methods/lps/specs/lps_experimental_plan_2026-06-09.tex`. Contract: `split_handoffs/lps_tier0_execution_artifact_contract_2026-06-10.md`.

## Already patched (Bucket 1) — re-run to confirm, do not redo

All of the following were edited but are **unverified** (author has no R). Your first job is to re-run the battery and confirm they actually pass:

- **E0.7 positive control** (`test-lps-tier0-correctness-extended.R`): `j` is now `i`'s nearest different-fold neighbour (`which.min(d2)`), so `i` is in `j`'s support. Confirm `abs(pert.j - base.j) > 0` now fires.
- **E0.8 duplicate-point** (`test-lps-degenerate.R`): the `min.design.rank == 1` assertion was removed (it is `NA` on the ambient path); behavioural collapse assertions remain.
- **E0.8 class-imbalance** (`test-lps-degenerate.R`): now asserts non-NA predictions ∈ [0,1] plus fallback diagnostics present, since `NA` is the sanctioned `unstable.action="na"` output.
- **Harness gate-context regex** (`run_tier0_execution_artifact.sh`): `\\.` → `[.]`, so `gate_contexts.txt` is always written.
- **Parity probe** (`tier0_headroom_probe.R`): `design.basis` for parity is now `"monomial"` (both `cpp` and `cpp.local.pca` require monomial + `ridge.multiplier.grid=0` + `ridge.condition.max=Inf`, per `.klp.resolve.backend`). Confirm `cpp` parity now runs instead of erroring.
- **CI** (`tier0-gate.yml`): enforcement expanded to contract §4 (coverage, warnings, sanctioned-skip, headroom, determinism, parity, checksums); `paths:` trigger now includes all gate files, the contract, and the workflow.

## Bucket 2 — your work

### 1. E0.6 consistency slope is positive (BLOCKER; may be a real finding)

Audit measured slope ≈ +0.016 (CI upper +0.099); the gate needs the slope CI below −0.1. Most likely cause: **the test holds `support.grid = c(30,60)` fixed across `n`**, leaving a variance floor so RMSE cannot vanish — the exact bias/variance-floor trap the spec warns about.

- Fix the DGP so support grows with `n` (mirror E0.5: `k(n) ∝ n^{4/(d+4)}`, `d=2` → `n^{2/3}`), or reconcile against what the frozen spec means by "routine grids" for E0.6 (the grid must let `k` grow for consistency to hold).
- Handle `NA` fitted probabilities in the RMSE (`na.rm`/exclude) and **record the NA fraction**.
- Re-run smoke; check the slope CI.
- **If the slope CI is still not below −0.1 after support grows, that is a genuine `lps.R` binary-convergence finding — escalate it; do NOT relax the −0.1 threshold to force green.** Post-hoc threshold changes invalidate the gate (spec §decision).
- Also restore prevalence coverage `{0.1, 0.3, 0.5}` (smoke used only 0.3) per spec E0.6.

### 2. E0.6 binomial NA probabilities (decide acceptability)

Binomial mode emitted 41 NAs (consistency) / 117 NAs (imbalance) under `unstable.action="na"`. That is plausibly correct guarded behaviour at low prevalence (spec E0.6 safeguard anticipates fallbacks). Decide and document: is the NA fraction at the smoke DGP acceptable? Stratify all E0.6 metrics by `logistic.diagnostics` fallback fraction (spec safeguard) and report it. This is coupled to item 3.

### 3. `R/lps.R` default-change diff (production judgment — the important one)

The uncommitted `R/lps.R` changes the public/internal defaults to `orthogonal.polynomial.drop`, `design.drop.tol=1e-8`, ridge grid `c(0,1e-10,1e-8)`, `ridge.condition.max=1e12`, `unstable.action="na"`. The auditor correctly refused to commit these unproven and noted they may be *why* binary calibration / degenerate cases behave as they do.

- Decide: keep the new defaults (and prove the gates pass under them) or revert.
- If keeping, confirm the E0.6 / E0.8 binary behaviour under `unstable.action="na"` (NA = guarded) is intended and that the gates assert accordingly (Bucket 1 already made E0.8 NA-tolerant).
- Record the exact `R/lps.R` diff accepted into the Tier-0 commit (the auditor will want it).

### 4. Spec-DGP fidelity vs smoke mode (decide and document)

The audit flagged deviations from the frozen DGP. Pick a policy and write it into the contract:

- **E0.1**: spec uses `n=200`, support `K=3·c_p`, and asserts min design rank `== c_p`; the implemented E0.1 uses `n=70/85`, `4·c_p`, and no rank assertion.
- **E0.5/E0.6**: smoke sizes deviate from the frozen `n`-grids and `R`. The contract documents smoke-vs-full (`LPS_TIER0_FULL`), but the acceptance run should be the **full** frozen DGP at least once; decide whether CI runs smoke and acceptance runs full.

### 5. Expose ambient rank diagnostic + add E0.1 rank assertion (production change)

To honour spec E0.1 (and the E0.8 duplicate-point `rank==1` check), `lps.R` should expose a usable `min.design.rank` (or equivalent) on the `coordinate.method="coordinates"` path, where it is currently `NA`. Then add the spec's rank assertions to E0.1 and re-enable the E0.8 duplicate rank check.

### 6. E0.8 case 6 zero-bandwidth diagnostic (decide)

Spec E0.8 case 6 wants the zero-bandwidth support fraction recorded; `zero.bandwidth.fraction` is absent, so the test's guarded check is currently a no-op. Either expose the field in `lps.R` and assert on it, or drop the guard and keep the behavioural-only check explicitly.

### 7. Strengthen parity (recommended, not blocking)

The parity probe now runs `cpp`, but its truth is a degree-2 polynomial fit at degree 2, so both backends reproduce it and the diff is trivially ~0. Use a non-reproducing config (noisy `y`, or a truth above the fit degree) so parity actually exercises the smoother arithmetic, not just reproduction.

## Exit criteria → hand back to the independent auditor

Only after items 1–6 are resolved and the baseline battery is **honestly green** on a clean tree:

1. Isolate the Tier-0 files + accepted `R/lps.R` diff on a clean branch (`git status --porcelain` empty).
2. Run the harness for **both** tokens: `LPS_NATIVE_BACKEND=cpp` and `LPS_NATIVE_BACKEND=cpp.local.pca`.
3. Run the **mutation stage** from the audit brief (`lps_tier0_independent_audit_brief_2026-06-10.md` §3): break `lps.R` each way and confirm the named gate turns red. A gate that stays green under its mutation is rejected.
4. Hand the clean bundles + mutation results to the independent auditor for the final verdict and commit/push. Do not self-certify.
