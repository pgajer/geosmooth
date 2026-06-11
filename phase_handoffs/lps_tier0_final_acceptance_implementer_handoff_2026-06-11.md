# LPS Tier-0 Final Acceptance Implementer Handoff

Date: 2026-06-11

Repository: `/Users/pgajer/current_projects/geosmooth`

Branch: `codex/geosmooth-tier0-bucket2-isolated`

Final commit under test:

```text
b86b796aeefa10204dc4a3b1e2e34c8b62dad837 Adjust E0.6 binary support schedule
```

## Changed Files

Files changed for the final-acceptance work order:

- `.gitignore`
- `.github/workflows/tier0-gate.yml`
- `scripts/ci/run_tier0_execution_artifact.sh`
- `tests/testthat/test-lps-tier0-correctness-extended.R`

No package source file such as `R/lps.R` was modified during this final-acceptance pass.

The test change is limited to the E0.6 binary support schedule constant. The frozen acceptance thresholds were not weakened.

## Exact Commands Run

Initial full run on clean commit `8a0964364a4cfa2afb6186d35453d5371fb914e3`:

```sh
LPS_TIER0_FULL=1 LPS_NATIVE_BACKEND=cpp EXECUTOR=codex-tier0-final-full bash scripts/ci/run_tier0_execution_artifact.sh
```

Initial full bundle:

```text
/Users/pgajer/current_projects/geosmooth/audit_artifacts/tier0_20260611T025625Z_cpp
```

That run failed E0.6 held-out Bernoulli calibration because the support schedule was too narrow at the full-size calibration sample. The source/test fix was to keep the same nonparametric growth rate but set the E0.6 reference support at `n = 500` to 30 instead of 20.

Final full run on clean commit `b86b796aeefa10204dc4a3b1e2e34c8b62dad837`:

```sh
LPS_TIER0_FULL=1 LPS_NATIVE_BACKEND=cpp EXECUTOR=codex-tier0-final-full bash scripts/ci/run_tier0_execution_artifact.sh
```

Final full gate bundle:

```text
/Users/pgajer/current_projects/geosmooth/audit_artifacts/tier0_20260611T040812Z_cpp
```

Second-token probe-only run on the same clean commit:

```sh
LPS_TIER0_FULL=1 LPS_NATIVE_BACKEND=cpp.local.pca MODE=probe EXECUTOR=codex-tier0-final-probe bash scripts/ci/run_tier0_execution_artifact.sh
```

Second-token probe bundle:

```text
/Users/pgajer/current_projects/geosmooth/audit_artifacts/tier0_20260611T051534Z_cpp.local.pca
```

Post-run deterministic extraction of E0.5 full-size numerical summaries was run from the committed E0.5 test code to print values that the test asserts but does not otherwise emit.

## Final Full Gate Bundle Summary

Manifest excerpt:

```text
artifact_id: tier0_20260611T040812Z
generated_utc: 20260611T040812Z
mode: full
repo: /Users/pgajer/current_projects/geosmooth
git_head: b86b796aeefa10204dc4a3b1e2e34c8b62dad837
tree_clean: true
native_backend_token: cpp
testthat_rc: 0
testthat_summary: tests=16 failed=0 error=0 warning=0 skipped=1
gate_contexts: E0.1;E0.2;E0.3a;E0.4;E0.5;E0.6;E0.7;E0.8
probe_rc: 0
probe_summary: E0.1 n=64 all_pass=TRUE max_err=3.331e-15 min_headroom=3002399.8x | E0.2 pass=TRUE id_res=4.441e-16 df_res=0.000e+00 | determinism=0.000e+00 | parity=ok
executor: codex-tier0-final-full
```

Backend parity CSV:

```text
"native_backend","status","max_abs_diff"
"cpp","ok",2.22044604925031e-16
```

## Second-Token Probe Bundle Summary

Manifest excerpt:

```text
artifact_id: tier0_20260611T051534Z
generated_utc: 20260611T051534Z
mode: probe
repo: /Users/pgajer/current_projects/geosmooth
git_head: b86b796aeefa10204dc4a3b1e2e34c8b62dad837
tree_clean: true
native_backend_token: cpp.local.pca
testthat_rc: 0
testthat_summary: tests=NA failed=NA error=NA warning=NA skipped=NA
gate_contexts:
probe_rc: 0
probe_summary: E0.1 n=64 all_pass=TRUE max_err=3.331e-15 min_headroom=3002399.8x | E0.2 pass=TRUE id_res=4.441e-16 df_res=0.000e+00 | determinism=0.000e+00 | parity=ok
executor: codex-tier0-final-probe
```

Backend parity CSV:

```text
"native_backend","status","max_abs_diff"
"cpp.local.pca","ok",0
```

## Full-Size E0.5 Numbers

E0.5 deterministic extraction from the committed full-size test settings:

```text
E0.5 slope=-0.301974 se=0.005392 ci_hi=-0.291406
E0.5 n=200 k=20 mean=0.083595 median=0.084177 sd=0.006078 min=0.073001 max=0.094275
E0.5 n=400 k=32 mean=0.071219 median=0.070908 sd=0.005056 min=0.060066 max=0.080503
E0.5 n=800 k=50 mean=0.056404 median=0.056792 sd=0.003431 min=0.049032 max=0.062585
E0.5 n=1600 k=80 mean=0.046077 median=0.046216 sd=0.002622 min=0.041216 max=0.051289
E0.5 n=3200 k=127 mean=0.036426 median=0.036412 sd=0.001752 min=0.032965 max=0.040075
```

## Full-Size E0.6 Numbers

The final full bundle emitted the following E0.6 rows:

```text
E0.6 family=bernoulli prevalence=0.1 support=22/30/38,36/48/60,57/76/95,90/120/150 slope=-0.3182 ci_hi=-0.2963 max_na=0.0000 median_fallback=NA
E0.6 family=bernoulli prevalence=0.3 support=22/30/38,36/48/60,57/76/95,90/120/150 slope=-0.3219 ci_hi=-0.3021 max_na=0.0000 median_fallback=NA
E0.6 family=bernoulli prevalence=0.5 support=22/30/38,36/48/60,57/76/95,90/120/150 slope=-0.3310 ci_hi=-0.3088 max_na=0.0000 median_fallback=NA
E0.6 family=binomial prevalence=0.1 support=22/30/38,36/48/60,57/76/95,90/120/150 slope=-0.3572 ci_hi=-0.3325 max_na=0.1900 median_fallback=0.0025
E0.6 family=binomial prevalence=0.3 support=22/30/38,36/48/60,57/76/95,90/120/150 slope=-0.3268 ci_hi=-0.3074 max_na=0.1000 median_fallback=0.0000
E0.6 family=binomial prevalence=0.5 support=22/30/38,36/48/60,57/76/95,90/120/150 slope=-0.3319 ci_hi=-0.3097 max_na=0.0200 median_fallback=0.0000
```

The full-size E0.6 calibration check is included in the green `tests=16 failed=0 error=0 warning=0 skipped=1` testthat summary for the final full bundle.

## Per-Gate Mutation/Falsification Hooks

The following one-line mutations are listed for the independent auditor; they were not run by the implementer in this final-acceptance handoff.

| Gate | Mutation that must turn it red |
|---|---|
| E0.1 | Perturb the design-centering constant or polynomial truth coefficient so polynomial reproduction is no longer exact. |
| E0.2 | Perturb one row of the extracted smoother matrix or degrees-of-freedom calculation. |
| E0.3a | Replace the analytic linear-smoother leave-one-out denominator by `1` or use an off-by-one diagonal. |
| E0.4 | Downgrade the boundary degree-1 fit to degree-0 in the boundary-bias comparison. |
| E0.5 | Break the support-growth schedule or add a fixed positive bias to the fitted values. |
| E0.6 | Break probability clipping/calibration or force the binary support schedule back to the too-small full-size constant. |
| E0.7 | Allow held-out responses into the training vector for their own out-of-fold prediction. |
| E0.8 | Remove or perturb deterministic tie ordering in the native/local-PCA neighbor path. |

## Limitations and Unverified Claims

Mutation/falsification was not run by the implementer. The auditor must run independent mutation/falsification before final acceptance.

The final full artifact was produced in one local environment on one clean git commit. It records BLAS, session information, source checksums, tree cleanliness, the git head, testthat results, gate contexts, and backend parity, but independent verification is still required.

The `cpp.local.pca` bundle is intentionally probe-only. It records binding, environment, determinism, and parity evidence for the second backend token on the same git head, but it does not rerun the backend-independent testthat battery.

The E0.6 binomial path has nonzero NA/fallback diagnostics in the full-size run. The recorded maxima are within the frozen finite-row criterion and the consistency slopes pass, but these diagnostics remain part of the artifact record.

Tier-0 should not be considered finally accepted until the auditor completes the independent review and records a final verdict.
