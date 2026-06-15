# LPS Tier-0 Independent Execution Audit

Auditor/executor: Codex
Date: 2026-06-10

## Verdict

### Gate battery

Reject.

The Tier-0 battery is not ready to commit, push, or use as an acceptance gate. The local baseline run is already red before mutation/falsification: E0.6 fails the probability-recovery criterion and emits `NA` probabilities; E0.7 has a vacuous positive control for its chosen index; E0.8 fails two pathology tests. Because the baseline is red, the requested mutation stage cannot certify the gates.

### Harness / contract artifact

Reject.

The execution harness correctly records a dirty tree as `tree_clean: false`, but it currently fails while extracting gate contexts, leaving no `gate_contexts.txt`. The generated bundle therefore cannot satisfy the acceptance contract's coverage criterion even aside from the red tests.

No Tier-0 commit or push was made. Creating a clean artifact from this state would be misleading.

## Blocking Findings

1. Baseline test battery is red before mutation.

   Command:

   ```sh
   Rscript -e 'pkgload::load_all("."); files <- c("tests/testthat/test-lps-tier0-correctness.R", "tests/testthat/test-lps-tier0-correctness-extended.R", "tests/testthat/test-lps-degenerate.R"); for (f in files) { cat("\n==", f, "==\n"); print(testthat::test_file(f, reporter="summary")) }'
   ```

   Results:

   - `test-lps-tier0-correctness.R`: passed.
   - `test-lps-tier0-correctness-extended.R`: E0.6 had 8 failures; E0.7 had 1 failure; E0.3a skipped with the sanctioned "no independent LOO/GCV path" message.
   - `test-lps-degenerate.R`: E0.8 duplicate-point support and extreme class-imbalance cases failed.

2. E0.6 smoke criterion is empirically false in the current implementation/test pairing.

   Recomputing the smoke study used in the test gave:

   - Bernoulli: slope `0.01640786`, upper 95% CI `0.09934015`, total fitted-probability NAs `0`.
   - Binomial: slope `0.01652023`, upper 95% CI `0.09941299`, total fitted-probability NAs `41`.

   The frozen smoke criterion requires the slope CI to lie entirely below `-0.1`. These values are in the opposite direction. This is not a harmless threshold-edge failure.

3. E0.6 binomial mode violates the probability-output expectation.

   In the E0.8 class-imbalance diagnostic probe with `outcome.family = "binomial"` and `unstable.action = "na"`, fitted values included 117 `NA`s:

   ```text
   fitted.values NA count: 117
   logistic.diagnostics$final$na.failure.count: 117
   logistic.diagnostics$final$convergence.fraction: 0.61
   ```

   The spec says probabilities should be in `[0,1]` and diagnostics should report fallback behavior. Diagnostics are present, but the current test expectation `all(fv >= 0 & fv <= 1)` evaluates to `NA` when predictions contain `NA`.

4. E0.7's positive control is vacuous for the hard-coded index.

   The test chooses the first row in a different fold as `j`. For that `j`, perturbing `y_i` causes zero prediction change, so `expect_gt(abs(pert.j - base.j), 0)` fails. A scan of all different-fold candidates showed the property is not inherently impossible:

   ```text
   i delta: 0
   max other-fold delta: 1.491064
   positive count among other-fold candidates: 31
   ```

   The gate should choose a positive-control index whose training support actually contains `i`, not assume the first different-fold point will do so.

5. E0.8 diagnostic assertions are not correctly grounded in exposed diagnostics.

   For ambient-coordinate fits, `local.chart.diagnostics.summary$min.design.rank` exists but is `NA` because no chart diagnostics are populated for `coordinate.method = "coordinates"`. The duplicate-point test therefore fails with:

   ```text
   Expected diag.sum$min.design.rank to equal 1L.
   actual: NA
   expected: 1
   ```

   The compositional structural-zero test guards `zero.bandwidth.fraction`, but that field is absent in the inspected object, so the assertion never executes. This matches the known weak point: guarded diagnostics can silently drop the intended check.

6. The harness does not produce `gate_contexts.txt`.

   Running the harness in the dirty tree:

   ```sh
   LPS_NATIVE_BACKEND=cpp EXECUTOR=codex-auditor-dirty-check \
     bash scripts/ci/run_tier0_execution_artifact.sh
   ```

   created `audit_artifacts/tier0_20260610T195855Z/` and correctly marked:

   ```text
   tree_clean: false
   testthat_rc: 1
   testthat_summary: tests=16 failed=11 error=0 warning=0 skipped=1
   ```

   But `testthat_stdout.txt` contains:

   ```text
   Error: '\.' is an unrecognized escape in character string (<input>:1:49)
   Execution halted
   ```

   and `gate_contexts.txt` was not written. This violates the contract's coverage requirement.

7. The GitHub workflow does not enforce the full contract.

   `.github/workflows/tier0-gate.yml` only enforces:

   ```sh
   grep -q "tree_clean: true" "$AID/execution_manifest.txt"
   grep -q "failed=0 error=0" "$AID/testthat_summary.txt"
   ```

   It does not enforce gate coverage, zero warnings, sanctioned-skip policy, headroom, identity tightness, determinism, backend parity, or source checksum validity. Its `pull_request.paths` trigger also omits the extended and degenerate Tier-0 test files, the contract, and workflow file itself.

## Spec Fidelity

Observed deviations from the frozen spec:

- E0.1 spec uses `n = 200` and support `K = 3 * c_p`; the implemented test uses `n = 70/85` and support `max(12, 4 * c_p)`. This may be a smoke-size choice, but it is not spec-verbatim.
- E0.1 spec says the test asserts reported minimum design rank equals `c_p`; the implemented E0.1 tests do not assert design rank. In ambient-coordinate fits, the available `min.design.rank` diagnostic is `NA`, not usable for this assertion.
- E0.5 smoke mode uses `n = {200,400,800,1600}` and `R = 12`, while the frozen spec's DGP is `n = {200,400,800,1600,3200}` and `R = 30`. The contract documents smoke-vs-full mode, but the audit brief asked for DGP fidelity to the frozen spec.
- E0.6 smoke mode uses only prevalence `0.3`, `n = {500,1000,2000}`, and `R = 8`, while the frozen spec uses prevalences `{0.1,0.3,0.5}`, `n = {500,1000,2000,4000}`, and `R = 40`. Again, this may be intended as smoke mode, but it is not the frozen DGP.
- E0.8 case 6 expects a zero-bandwidth diagnostic where exposed, but the current production object does not expose `zero.bandwidth.fraction` for the inspected ambient-coordinate compositional fit.

Confirmed fidelity:

- E0.3a defers rather than reconstructing the shortcut from `S`; `fit.lps` exposes no independent per-point LOO/GCV residual field.
- E0.3b is correctly absent as a pass/fail gate; the frozen spec frames it as a characterization study, not a hard gate.
- E0.4's `degree.grid = 0` path is accepted by `fit.lps`; the API assumption is valid.
- E0.4 uses the frozen threshold triplet `0.5 / 3 / 5`.
- E0.7 uses the frozen no-leakage threshold `1e-12`, but the positive control index selection is flawed.

## Mutation / Falsification Results

The mutation stage was not completed because the unmutated baseline is already red and the harness cannot produce a valid coverage artifact. A mutation-qualified gate must first pass honestly in the baseline state.

| Gate | Required mutation result | Audit result |
|---|---|---|
| E0.1 | Must turn red under design-centering perturbation | Not run; baseline package rejected before mutation stage. Original E0.1 smoke passes, but it is not spec-verbatim and lacks the rank assertion. |
| E0.2 | Must turn red under `y`-dependent weights | Not run; baseline package rejected before mutation stage. Original E0.2 smoke passes. |
| E0.3a | If no independent LOO field exists, must skip | Passes this audit condition: no independent LOO/GCV field exists and the test skips with the sanctioned rationale. |
| E0.4 | Must turn red under degree-1 mis-centering | Not run; baseline package rejected before mutation stage. API assumption for degree 0 is valid and original E0.4 passes. |
| E0.5 | Must turn red under constant `k` bias-floor mutation | Not run; baseline package rejected before mutation stage. Original smoke passes. |
| E0.6 | Must turn red under probability mis-clipping | Baseline already red; no mutation needed to falsify. |
| E0.7 | Must turn red under held-out response leakage | Baseline already red because the positive control is vacuous for the selected `j`. |
| E0.8 | Must turn red under silent mean fallback with `unstable.action = "na"` | Baseline already red on duplicate-point rank diagnostic and class-imbalance probability assertion. |

This table is intentionally not a pass certificate. It documents that the battery is not mutation-qualified.

## Reproduced Numbers

From the dirty-tree harness probe bundle `audit_artifacts/tier0_20260610T195855Z/`:

- E0.1 ambient headroom: `max_err = 2.220e-15`, `min_headroom = 4503599.6x`.
- E0.2 ambient identity residual: `4.441e-16`; df residual: `0.000e+00`.
- Determinism: `0.000e+00`.
- Backend parity for token `cpp`: unavailable because the probe asks `backend = "cpp"` to run with `orthogonal.polynomial.drop` and guarded ridge settings, which `fit.lps` explicitly rejects:

  ```text
  'backend = "cpp"' does not support non-monomial design bases or guarded ridge solves; use backend = 'auto' or 'R'.
  ```

The parity probe therefore does not currently exercise the ambient C++ path promised by the contract.

## Bundle Validity

No valid committed-tree bundle was produced.

The only generated bundle in this audit, `audit_artifacts/tier0_20260610T195855Z/`, is invalid by construction and by content:

- `tree_clean: false`
- `testthat_rc: 1`
- `failed=11`
- `skipped=1`
- missing `gate_contexts.txt`
- parity unavailable for `cpp`

It is useful as evidence that the harness records a dirty tree, but it is not a gate artifact.

## `R/lps.R` Diff Decision

I did not accept the current `R/lps.R` diff into a Tier-0 commit.

The diff changes LPS defaults from raw monomial/no-ridge/uncapped-condition behavior to `orthogonal.polynomial.drop`, `design.drop.tol = 1e-8`, ridge multiplier grid `c(0, 1e-10, 1e-8)`, `ridge.condition.max = 1e12`, and `unstable.action = "na"` defaults across public and internal paths. Those changes may be scientifically justified, but the current tests and harness do not yet prove the new defaults satisfy the frozen gates. In particular, binary probability recovery/calibration and degenerate-pathology behavior fail under these changes.

## Required Fixes Before Re-Audit

1. Make the baseline Tier-0 battery green without weakening frozen-spec claims.
2. Fix E0.7's positive-control selection so it chooses a different-fold point whose training support actually contains the perturbed index.
3. Decide whether E0.6 failures indicate implementation defects, smoke-DGP defects, or an invalid threshold for smoke mode; do not relax the frozen threshold without a spec/contract update.
4. Fix E0.8 diagnostic expectations so they assert on diagnostics that the production object actually exposes, or add the missing production diagnostics.
5. Fix the harness gate-context extraction quoting so `gate_contexts.txt` is always written.
6. Update CI enforcement to check the full contract: clean tree, failed/error/warning counts, sanctioned skips, coverage, headroom, identity residuals, determinism, parity, source checksums, and environment presence.
7. Fix the parity probe so `LPS_NATIVE_BACKEND=cpp` actually exercises the ambient C++ path with supported settings, and `cpp.local.pca` exercises the local-PCA prototype path.
8. Only after the above, isolate the Tier-0 files and accepted `R/lps.R` diff on a clean branch, commit, run both backend-token harnesses, and audit the resulting clean bundles.
