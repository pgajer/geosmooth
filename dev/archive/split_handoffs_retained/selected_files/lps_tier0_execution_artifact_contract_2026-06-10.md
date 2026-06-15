# Tier-0 Execution-Artifact Contract (Option 2)

Date: 2026-06-10 (ET)
Scope: the execution leg that closes the gap identified in the Phase-0 audit
(`split_handoffs/lps_phase0_audit_tier0_and_binary_5rep_2026-06-10.md`) — the auditor cannot run R, so an independent execution must produce a verifiable artifact that the auditor reviews instead of the implementer's console output.

Companion scripts:

- `scripts/ci/run_tier0_execution_artifact.sh` — the harness (produces the bundle)
- `scripts/ci/tier0_headroom_probe.R` — realized-error / determinism / backend-parity probe
- `.github/workflows/tier0-gate.yml` — minimal CI wrapper that runs the harness and enforces the gate

## 1. Purpose and the one rule that makes it work

The Tier-0 gate hinges on a single claim the static audit could not check: *do the correctness tests actually pass against the current `lps.R`?* A "row of dots" from the implementer does not settle it, because the implementer is the party being audited.

**Rule:** the execution is performed by an executor that is **not** the implementer's interactive session — either a second execution-capable agent, a different person, or (preferably) the CI runner — and the **auditor reviews the resulting bundle**, never a bare pass/fail message. The bundle is constructed to be self-verifying: it binds itself to the exact reviewed source (checksums), records the environment, and exposes the quantities (realized errors, determinism, parity) that a passing summary hides.

This preserves the only independence boundary that matters — **auditor vs. implementer** — without requiring a second *judgment*. It is an execution leg, not a second opinion.

## 2. What the executor must run

```sh
# clean, committed tree only:
git switch --detach <reviewed-commit>      # or check out the PR head
git status --porcelain                      # MUST be empty
LPS_NATIVE_BACKEND=<token> EXECUTOR="<id>" \
  bash scripts/ci/run_tier0_execution_artifact.sh
```

`LPS_NATIVE_BACKEND` must be set to the token `fit.lps()` actually accepts for the native backend (the scripts default to `cpp`; correct it if the package uses a different identifier). If no native backend exists, the parity row is recorded as `unavailable: …` rather than failing — that is an honest "N/A," and the auditor decides whether parity is required.

## 3. Required bundle contents

The harness writes everything under `dev/methods/lps/audit_artifacts/tier0_<UTC-timestamp>/`:

| File | Establishes |
|---|---|
| `git_head.txt`, `git_log1.txt`, `git_status.txt` | Exact commit; **clean tree** (status must be empty) |
| `tracked_files.txt` | `R/lps.R` and all Tier-0 test files are **tracked/committed** (not the untracked state the audit found) |
| `source_checksums.txt` | sha256 of `R/lps.R` + all Tier-0 test files — binds the run to the source the auditor reviewed |
| `sessionInfo.txt`, `blas.txt` | R version, platform, locale, attached package versions, **BLAS/LAPACK** (determinism context) |
| `testthat_results.csv`, `testthat_summary.txt` | Per-test machine-readable results; `failed/error/warning/skipped` counts |
| `gate_contexts.txt` | Which Tier-0 gates the run actually covers (coverage, not just pass/fail) |
| `headroom_e01_ambient.csv` | Per-case **realized** reproduction error, tolerance, and headroom ratio |
| `headroom_e02_ambient.csv` | Linear-smoother **identity residual**, linearity residual, `tr(S)`, df residual |
| `backend_parity.csv` | `max|fitted_R − fitted_native|` for a matched config, or an N/A reason |
| `headroom_summary.csv`, `probe_stdout.txt` | One-line roll-up of the above |
| `execution_manifest.txt` | Commit, `tree_clean`, native token, testthat summary, gate contexts, executor id |
| `BUNDLE_CHECKSUMS.txt` | sha256 of every file in the bundle — tamper-evidence over the whole artifact |

## 4. Acceptance criteria (the auditor checks these against the bundle)

These are the defaults the auditor confirms; they are not self-certified by the harness.

Default CI may run the smoke-sized accuracy studies for E0.5 and E0.6 because
their full grids are intentionally heavier. Final phase acceptance must include
at least one clean-tree run with `LPS_TIER0_FULL=1` so the frozen DGP sizes and
replication counts in `dev/methods/lps/specs/lps_experimental_plan_2026-06-09.tex` are
exercised. Smoke runs are admissible for pull-request screening; they are not a
substitute for the full acceptance artifact.

E0.1 is not smoke-sized. It uses the frozen sample size `n = 200` in both the
ambient-coordinate and flat-embedded-subspace reproduction gates. The local
support size is

```text
K = min(n - 1, max(15, 3 * c_p)),
```

where `c_p` is the number of local polynomial design columns for the tested
dimension and degree. The `3*c_p` term is the frozen polynomial-support rule;
the fixed floor of 15 prevents compact-kernel boundary supports in the
least-stable monomial/local-PCA case from becoming an artificial numerical
failure while preserving a deterministic, audited gate. E0.1 also asserts
`min.design.rank == c_p`, so the support floor cannot hide a rank-deficient
local design.

1. **Clean, committed tree.** `git_status.txt` empty; `tracked_files.txt` shows both files tracked; `source_checksums.txt` matches the source the auditor read. CI recomputes the same checksums from the reviewed checkout and diffs them against the artifact.
2. **Coverage.** `gate_contexts.txt` must contain every gate the phase requires: **E0.1, E0.2, E0.3a, E0.4, E0.5, E0.6, E0.7, E0.8**. All eight are now implemented across `test-lps-tier0-correctness.R`, `test-lps-tier0-correctness-extended.R`, and `test-lps-degenerate.R`. A run missing any label fails this criterion.
3. **Green.** `failed=0 error=0`; zero warnings; zero *unexplained* skips. The one sanctioned skip is **E0.3a**, which defers (with an explicit message) when `fit.lps` exposes no independent GCV/LOO residual path — reconstructing the shortcut from `S` and checking it against itself would be tautological, so deferral is the correct behaviour, not a gap. CI checks the skipped row itself, not merely the presence of the string `E0.3a` somewhere in the results file.
4. **Headroom (not just under the wire).** Every E0.1 case has `realized_err ≤ tol/10` (≥ 1 order of magnitude margin); `e01_min_headroom ≥ 10`. A case passing at `0.9×tol` is a yellow flag worth investigating.
5. **Identity tightness.** E0.2 `identity_residual` and `df_residual ≤ 1e-12` (well inside the 1e-10 assertion); `tr(S)` finite and `> 0`.
6. **Determinism.** `determinism_max_diff ≤ 1e-12` for a refit of the same config.
7. **Backend parity.** If a native backend exists, `max_abs_diff ≤ 1e-8`; otherwise the N/A reason is recorded and the auditor explicitly rules whether R-only coverage is acceptable for the gate.
8. **Environment recorded.** R version, platform, BLAS, and the geosmooth load method (`pkgload::load_all`) are present.

The GitHub workflow runs the harness as a matrix over both native tokens,
`cpp` and `cpp.local.pca`, and uploads one artifact bundle per token.

`tree_clean: false` voids the artifact for gate purposes regardless of a green battery — *report rendered ≠ data valid ≠ phase accepted* applies here too.

## 5. How the auditor uses it

1. Recompute `sha256` of `R/lps.R` + the Tier-0 test files in the reviewed checkout and confirm they match `source_checksums.txt` (the run is bound to the reviewed source).
2. Confirm `tree_clean: true` and the commit in `git_head.txt` is the reviewed commit.
3. Read `headroom_*` and `backend_parity.csv` directly — do **not** rely on the harness's "PRELIMINARY: green" line; recompute the headroom ratios and confirm they clear §4.
4. Confirm `gate_contexts.txt` covers the required gate set before declaring the phase gate met.
5. Optionally re-run the harness independently and diff `headroom_summary.csv` to confirm determinism across environments.

## 6. What this does and does not establish

It establishes that the **committed** code passes the **implemented** gates, with quantified headroom, deterministically, on a recorded environment, bound to reviewed source. All eight gates (E0.1–E0.8) are now implemented, so coverage is met once they run green on a clean tree. Two caveats remain before Phase 0 can be declared passed: (a) E0.5 and E0.6 are accuracy studies that run **smoke-sized** by default (`LPS_TIER0_FULL=1` selects the frozen-spec sizes); their slope/calibration thresholds are spec-verbatim but should be confirmed on the first real execution, since they were authored without an execution environment; and (b) parity (§4.7) is only as strong as the native-backend token supplied (`cpp` ambient, `cpp.local.pca` local-PCA). The artifact makes the *execution* trustworthy; the auditor still rules on *scope*, *headroom*, and the E0.5/E0.6 threshold confirmation.

## 7. Change control

The contract version is this file's commit. If the tolerances in §4, the gate set, or the native token change, bump the commit and note it in the manifest review — an artifact generated under an older contract is read against the contract in force at its timestamp.
