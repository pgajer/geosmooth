# Independent Audit Brief — LPS Tier-0 Battery, Harness & Execution Artifact

Date: 2026-06-10
For: an independent auditor (a person, or an agent in a fresh session) who did **not** author the artifacts below.
Your authority: the frozen spec and the production source — not any "green" the harness prints.

- Frozen gate spec (authoritative): `dev/methods/lps/specs/lps_experimental_plan_2026-06-09.tex`, sections E0.1–E0.8.
- Production code under test: `R/lps.R`.
- Acceptance contract: `split_handoffs/lps_tier0_execution_artifact_contract_2026-06-10.md`.
- Worker-auditor workflow / Audit Charter: `~/.codex/notes/workflows/worker_auditor_workflow.md`.

## 0. Independence mandate (read first)

**Provenance disclosure.** The execution harness, the headroom probe, the CI workflow, the contract, and the new gate tests **E0.3a–E0.8** were written by an AI assistant acting as the *implementer*. The prior Phase-0 audit was also written by that same assistant. Treat **all of it as unverified implementer work**, including its comments and its self-reported "PRELIMINARY: green" line.

**Your job is not to confirm it passes. Your job is to try to make it fail, and to prove the gates *can* fail.** A correctness test that cannot go red is worthless; the central deliverable of this audit is the mutation check in §3 (break the code, watch each gate fail). The implementer cannot do this credibly on their own work — that is why you exist here.

You will act as both the **independent executor** (you commit, push, and run) and the **auditor** (you judge). That is acceptable because you did not write the code; the boundary that matters is implementer ≠ auditor.

## 1. Inventory to review, then commit

New / changed files (review **before** committing):

- `tests/testthat/test-lps-tier0-correctness-extended.R` — gates E0.3a, E0.4, E0.5, E0.6, E0.7
- `tests/testthat/test-lps-degenerate.R` — gate E0.8 (six pathology cases)
- `scripts/ci/run_tier0_execution_artifact.sh` — execution harness (runs all three Tier-0 files)
- `scripts/ci/tier0_headroom_probe.R` — realized-error / determinism / backend-parity probe (E0.1/E0.2)
- `.github/workflows/tier0-gate.yml` — CI wrapper
- `split_handoffs/lps_tier0_execution_artifact_contract_2026-06-10.md` — the contract

Already present (contains E0.1, E0.2, and an implementer-added E0.1 negative control):

- `tests/testthat/test-lps-tier0-correctness.R`

**Tree hazard.** `R/lps.R` is modified and the working tree carries unrelated parallel work. A valid gate artifact requires a **clean** tree (contract §4.1). Before committing: run `git diff R/lps.R` and decide what `lps.R` state the gate should run against; do **not** sweep unrelated parallel changes into the Tier-0 commit. Record the `lps.R` diff you accepted in your report.

## 2. Known weak points the implementer flagged as audit targets

Scrutinize these first — the implementer authored the gates without an R environment, so these are the most likely defects:

1. **E0.5 / E0.6 thresholds were set without ever executing them.** The smoke `-0.1` slope-CI criterion and the calibration band may be mis-tuned (too tight → flaky; too loose → vacuous). Verify empirically.
2. **E0.4 assumes `degree.grid = 0` is accepted** by `fit.lps`. Confirm local-constant fits actually run; if degree 0 errors, E0.4 is invalid as written.
3. **E0.8 diagnostic assertions are guarded** by `if (!is.null(field))`. Confirm the guarded fields (`min.design.rank`, `zero.bandwidth.fraction`, `logistic.diagnostics`) actually exist; a guard that is always false silently drops the assertion.
4. **E0.3a should defer, not test.** Confirm `fit.lps` exposes no per-point LOO/GCV residual field, so the gate correctly `skip()`s rather than reconstructing the shortcut from `S` and checking it against itself (spec forbids the tautology).
5. **E0.3b is intentionally absent** from the gate (the spec frames it as a characterization *study*, not pass/fail). Confirm that omission is correct, not a gap.

## 3. Step A — Pre-commit review: test the tests (mutation/falsification)

For the whole battery, the decisive check: **each gate must fail when the property it guards is broken.** Run the battery once clean (expect green), then apply each mutation below to a scratch copy and confirm the named gate turns **red**. A gate that stays green under its mutation is vacuous and must be rejected.

| Gate | Spec § | Property | Mutation that MUST turn it red |
|---|---|---|---|
| E0.1 | E0.1 | polynomial reproduction | perturb a design-centering constant in `lps.R` → reproduction error explodes |
| E0.2 | E0.2 | `ŷ=Sy`, df=tr S | inject any `y`-dependence into the weights → identity residual blows up |
| E0.3a | E0.3a | LOO algebra (or defer) | if a LOO field exists, corrupt it → relative error > 1e-8; if none, confirm `skip` |
| E0.4 | E0.4 | local-linear boundary correction | force degree-1 to mis-center (drop the local mean) → boundary ratio fails |
| E0.5 | E0.5 | consistency / rate | pin support `k` constant (bias floor) → slope CI no longer below −0.1 |
| E0.6 | E0.6 | probability recovery + calibration | mis-clip probabilities (e.g. `*0.5`) → calibration slope leaves band |
| E0.7 | E0.7 | no CV leakage | leak `y_i` into its own fold's training → perturbation delta ≫ 1e-12 |
| E0.8 | E0.8 | guarded degenerate behavior | force a silent mean fallback under `unstable.action="na"` → "no silent mean" assertion fails |

Also confirm, by reading each test against its spec section: the DGP matches (truth nonlinear where required, noiseless where required, flat embedding for intrinsic cases), the thresholds are the spec's **verbatim** (E0.4: 0.5 / 3 / 5; E0.7: 1e-12; E0.5/E0.6: slope CI < −0.1), and seeds are fixed. Flag any threshold that differs from the spec.

## 4. Step B — Clean-tree isolation, commit, push

```sh
cd ~/current_projects/geosmooth
git switch -c tier0-gate-e0x                       # work on a branch
git diff R/lps.R                                    # decide what lps.R state to accept
git add tests/testthat/test-lps-tier0-correctness.R \
        tests/testthat/test-lps-tier0-correctness-extended.R \
        tests/testthat/test-lps-degenerate.R \
        scripts/ci/run_tier0_execution_artifact.sh \
        scripts/ci/tier0_headroom_probe.R \
        .github/workflows/tier0-gate.yml \
        split_handoffs/lps_tier0_execution_artifact_contract_2026-06-10.md \
        R/lps.R                                     # only if you accept its diff
git commit -m "Tier-0 battery E0.1-E0.8 + execution-artifact harness"
git stash --include-untracked                       # park unrelated parallel work
git status --porcelain                              # MUST be empty before the gate run
```

Do not push until §5 produces a clean, green bundle. Then `git push -u origin tier0-gate-e0x` and open the PR (CI `tier0-gate.yml` will run the same harness).

## 5. Step C — Run the harness, then audit the bundle

```sh
LPS_NATIVE_BACKEND=cpp           bash scripts/ci/run_tier0_execution_artifact.sh
LPS_NATIVE_BACKEND=cpp.local.pca bash scripts/ci/run_tier0_execution_artifact.sh   # 2nd parity path
git stash pop                                         # restore parallel work afterward
```

Audit the newest `dev/methods/lps/audit_artifacts/tier0_<stamp>/` against the contract (§4), independently:

- **Tree & binding.** `git_status.txt` empty; recompute `sha256` of `R/lps.R` and the three test files and match `source_checksums.txt`; `git_head.txt` is the commit you made.
- **Coverage.** `gate_contexts.txt` = `E0.1 E0.2 E0.3a E0.4 E0.5 E0.6 E0.7 E0.8`. The only skip permitted is E0.3a (verify its skip message).
- **Green.** `testthat_summary.txt`: `failed=0 error=0`, zero warnings, no unexplained skips. Read `testthat_stdout.txt` for any error text.
- **Headroom (recompute one).** Open `headroom_e01_ambient.csv`; pick one row and re-derive its reproduction error yourself from `lps.R`; confirm `realized_err ≤ tol/10`. Confirm `headroom_summary.csv` `determinism_max_diff = 0` and the E0.2 residuals ≤ 1e-12.
- **Parity.** `backend_parity.csv`: `max_abs_diff ≤ 1e-8` for `cpp`, and for `cpp.local.pca` (or a recorded N/A reason). Confirm the token matches the path it exercises (`cpp` = ambient, `cpp.local.pca` = local-PCA prototype).
- **Harness honesty.** Re-run once with a deliberately dirty tree and confirm the manifest flips to `tree_clean: false` and the CI "enforce" step would reject it. Confirm the probe's `test_that`-shadow trick loads helpers without executing assertions.

## 6. Deliverable

A short written verdict (markdown), independent of this brief, stating:

1. **Verdict:** accept / accept-with-fixes / reject, for (a) the gate battery and (b) the harness/contract.
2. **Mutation results:** the §3 table with pass/fail for "did the gate go red under its mutation?" — this is the core evidence.
3. **Spec fidelity:** any gate whose DGP or threshold deviates from `lps_experimental_plan_2026-06-09.tex`.
4. **Reproduced numbers:** the one headroom value and one parity value you re-derived yourself.
5. **Bundle validity:** is the committed-tree bundle a valid gate artifact per contract §4 (clean tree + green + coverage + headroom + parity)?
6. **The `lps.R` diff** you accepted into the commit.

## 7. Do not

- Do not accept the harness's "PRELIMINARY: green" as the verdict — recompute.
- Do not treat the gate-file comments as evidence; check each gate against the spec.
- Do not reuse the implementer's earlier local bundle (`dev/methods/lps/audit_artifacts/tier0_20260610T184844Z`, `tree_clean:false`) — generate your own.
- Do not commit unrelated parallel work alongside the Tier-0 change.
- Do not let a gate that stayed green under its §3 mutation pass review.
