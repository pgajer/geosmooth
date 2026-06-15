# LPS Tier-0 Bucket-2 Remediation Response

Date: 2026-06-10

This response addresses the Bucket-2 punch-list attached to the rejected independent audit:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_tier0_independent_execution_audit_2026-06-10.md`

Primary contract:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_tier0_execution_artifact_contract_2026-06-10.md`

## Executive Summary

Bucket 2 has been remediated at smoke-execution scale. The important E0.6 finding was real: the fixed support grid created a variance/bias floor that prevented a consistency slope from appearing. E0.6 now uses a growing support grid, restores the prevalence grid `{0.1, 0.3, 0.5}`, excludes/records NA probability outputs, and reports fallback telemetry.

The guarded LPS defaults in `R/lps.R` are kept as the Tier-0 candidate defaults:

- `design.basis = "orthogonal.polynomial.drop"`
- `design.drop.tol = 1e-8`
- `ridge.multiplier.grid = c(0, 1e-10, 1e-8)`
- `ridge.condition.max = 1e12`
- `unstable.action = "na"`

This is not self-certified as final phase acceptance. The smoke harness now passes under both native parity tokens, but the tree is dirty and the full frozen acceptance run with `LPS_TIER0_FULL=1` remains required on a clean committed tree.

## Files Changed

- `R/lps.R`
- `tests/testthat/test-lps-tier0-correctness.R`
- `tests/testthat/test-lps-tier0-correctness-extended.R`
- `tests/testthat/test-lps-degenerate.R`
- `scripts/ci/tier0_headroom_probe.R`
- `scripts/ci/run_tier0_execution_artifact.sh`
- `.github/workflows/tier0-gate.yml`
- `split_handoffs/lps_tier0_execution_artifact_contract_2026-06-10.md`

## Bucket-2 Item Responses

### 1. E0.6 Consistency Slope

Resolved at smoke scale.

The E0.6 DGP now uses support grids that grow with sample size:

```text
n = 500:  support.grid = 15/20/25
n = 1000: support.grid = 24/32/40
n = 2000: support.grid = 38/50/62
```

The schedule mirrors the E0.5 rate logic, with `d = 2` and `k(n) proportional to n^(2/3)`.

The E0.6 prevalence grid has been restored to:

```text
0.1, 0.3, 0.5
```

Smoke-run slopes now satisfy the `ci_hi < -0.1` gate for both binary modes and all prevalences:

| family | prevalence | slope | CI upper | max NA fraction | median fallback fraction |
|---|---:|---:|---:|---:|---:|
| bernoulli | 0.1 | -0.3244 | -0.2587 | 0.0000 | NA |
| bernoulli | 0.3 | -0.3405 | -0.2825 | 0.0000 | NA |
| bernoulli | 0.5 | -0.2940 | -0.2269 | 0.0000 | NA |
| binomial | 0.1 | -0.3417 | -0.2596 | 0.2360 | 0.0753 |
| binomial | 0.3 | -0.3439 | -0.2893 | 0.1240 | 0.0008 |
| binomial | 0.5 | -0.3154 | -0.2335 | 0.0240 | 0.0000 |

### 2. E0.6 Binomial NA Probabilities

Handled and documented.

E0.6 now treats NA probabilities as guarded outputs under `unstable.action = "na"` rather than as silent valid predictions. The RMSE calculation excludes NA predictions, records the NA fraction, and requires the smoke maximum NA fraction to remain below `0.25`.

The smoke maximum occurs for low-prevalence binomial mode:

```text
family = binomial
prevalence = 0.1
max_na = 0.2360
median_fallback = 0.0753
```

This is accepted as guarded smoke behavior, not as evidence that binomial local-logistic fitting is clean in that regime. If the full frozen run exceeds this guard, or if fallback dominates the estimates, that should be escalated as a real binary-convergence finding.

### 3. `R/lps.R` Default-Change Diff

The guarded defaults are kept as the Tier-0 candidate policy.

Rationale: the repaired E0.1/E0.2/E0.5/E0.6/E0.8 smoke battery passes under these defaults, and the defaults are consistent with the recent LPS backend decision to prefer rank-aware orthogonal polynomial design with tiny ridge candidates and explicit NA failure over silent mean fallback.

Scope caveat: this is a candidate acceptance for the current Tier-0 remediation, not a final release decision. Final acceptance still requires the clean-tree full artifact and independent auditor review.

### 4. Spec-DGP Fidelity vs Smoke Mode

The execution artifact contract now explicitly distinguishes smoke CI from final phase acceptance.

Policy added to the contract:

- default CI may run smoke-sized E0.5/E0.6;
- final phase acceptance must include at least one clean-tree run with `LPS_TIER0_FULL=1`;
- smoke runs are admissible for pull-request screening but do not replace the full frozen DGP artifact.

### 5. Ambient Rank Diagnostic and E0.1 Rank Assertions

Implemented.

`fit.lps()` now records final-fit local polynomial diagnostics for R-backed fits, including:

- `effective.support`
- `design.rank`
- `design.condition`
- `zero.bandwidth`

The summary now exposes:

- `min.design.rank`
- `median.design.rank`
- `max.design.rank`
- `zero.bandwidth.fraction`

E0.1 now asserts that `min.design.rank` equals the expected local polynomial column count for both ambient-coordinate and local-PCA reproduction cases.

E0.8 duplicate-point support now re-enables the rank assertion:

```text
min.design.rank == 1
```

### 6. E0.8 Zero-Bandwidth Diagnostic

Implemented.

The final-fit diagnostics now include `zero.bandwidth`, and the summary exposes `zero.bandwidth.fraction`. E0.8 case 6 now asserts that the field exists, is finite, and lies in `[0, 1]`.

### 7. Backend Parity Strengthening

Implemented.

The parity probe no longer uses an exactly reproduced degree-2 polynomial as the response. It now uses a non-reproducing noisy nonlinear response while keeping native-compatible settings:

- `design.basis = "monomial"`
- `ridge.multiplier.grid = 0`
- `ridge.condition.max = Inf`

Probe parity results:

| native token | max absolute R/native difference |
|---|---:|
| `cpp` | `2.22044604925031e-16` |
| `cpp.local.pca` | `0` |

## Verification Runs

Targeted checks:

```text
test-lps-tier0-correctness.R: passed
test-lps-degenerate.R: passed
test-lps-tier0-correctness-extended.R: passed, with the sanctioned E0.3a skip
```

Full smoke harness artifacts:

- `dev/methods/lps/audit_artifacts/tier0_20260610T204818Z` with `LPS_NATIVE_BACKEND=cpp`
- `dev/methods/lps/audit_artifacts/tier0_20260610T205535Z` with `LPS_NATIVE_BACKEND=cpp.local.pca`

Both smoke artifacts report:

```text
testthat_rc: 0
testthat_summary: tests=16 failed=0 error=0 warning=0 skipped=1
gate_contexts: E0.1;E0.2;E0.3a;E0.4;E0.5;E0.6;E0.7;E0.8
probe_rc: 0
```

Both artifacts are deliberately invalid for final gate acceptance because:

```text
tree_clean: false
```

That is expected for this remediation response. The final independent audit needs clean committed-tree execution.

Post-response sanity checks:

```text
git diff --check: passed
pkgload::load_all("."): passed
```

## Remaining Required Acceptance Work

Before the independent auditor can accept Tier 0:

1. Commit the Tier-0 remediation files on a clean branch.
2. Run the harness with `LPS_NATIVE_BACKEND=cpp` on a clean tree.
3. Run the harness with `LPS_NATIVE_BACKEND=cpp.local.pca` on a clean tree.
4. Run at least one full frozen acceptance artifact with `LPS_TIER0_FULL=1`.
5. Run the mutation checks from `lps_tier0_independent_audit_brief_2026-06-10.md` section 3.
6. Hand the clean bundles and mutation results to the independent auditor.

Do not self-certify the phase from the dirty-tree smoke artifacts.
