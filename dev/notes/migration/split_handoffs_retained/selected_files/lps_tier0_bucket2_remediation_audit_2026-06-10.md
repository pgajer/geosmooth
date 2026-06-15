# LPS Tier-0 Bucket-2 Remediation Audit

Auditor: Codex
Date: 2026-06-10

## Verdict

Accepted for smoke-scale Bucket-2 remediation, with required follow-up before final Tier-0 acceptance.

The implementer fixed the previously rejected smoke battery and the main harness defects I could verify locally. The three Tier-0 test files now pass in my R environment with the sanctioned E0.3a skip, E0.6 clears all six smoke family/prevalence slope checks, E0.7's positive control is no longer vacuous, E0.8's duplicate-rank and zero-bandwidth diagnostics are now populated, and both native parity tokens exercise the intended backends.

This is not final Tier-0 acceptance. The current artifacts are still dirty-tree artifacts, the Tier-0 files are still untracked in this working tree, no clean committed bundle exists, the full frozen `LPS_TIER0_FULL=1` run has not been produced, and the mutation/falsification stage has not been run.

## Audited Inputs

- Response: `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_tier0_bucket2_remediation_response_2026-06-10.md`
- Source under test: `/Users/pgajer/current_projects/geosmooth/R/lps.R`
- Tests:
  - `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-lps-tier0-correctness.R`
  - `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-lps-tier0-correctness-extended.R`
  - `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-lps-degenerate.R`
- Harness/probe/CI:
  - `/Users/pgajer/current_projects/geosmooth/scripts/ci/run_tier0_execution_artifact.sh`
  - `/Users/pgajer/current_projects/geosmooth/scripts/ci/tier0_headroom_probe.R`
  - `/Users/pgajer/current_projects/geosmooth/.github/workflows/tier0-gate.yml`
- Contract: `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_tier0_execution_artifact_contract_2026-06-10.md`

## Smoke Verification

I reran the three Tier-0 test files directly:

```text
test-lps-tier0-correctness.R: failed=0 error=0 warning=0 skipped=0
test-lps-tier0-correctness-extended.R: failed=0 error=0 warning=0 skipped=1
test-lps-degenerate.R: failed=0 error=0 warning=0 skipped=0
```

The only skip was the sanctioned E0.3a deferral because `fit.lps` exposes no independent per-point LOO/GCV residual field.

The independently reproduced E0.6 smoke outputs were:

```text
bernoulli prevalence=0.1 slope=-0.3244 ci_hi=-0.2587 max_na=0.0000
bernoulli prevalence=0.3 slope=-0.3405 ci_hi=-0.2825 max_na=0.0000
bernoulli prevalence=0.5 slope=-0.2940 ci_hi=-0.2269 max_na=0.0000
binomial  prevalence=0.1 slope=-0.3417 ci_hi=-0.2596 max_na=0.2360 median_fallback=0.0753
binomial  prevalence=0.3 slope=-0.3439 ci_hi=-0.2893 max_na=0.1240 median_fallback=0.0008
binomial  prevalence=0.5 slope=-0.3154 ci_hi=-0.2335 max_na=0.0240 median_fallback=0.0000
```

These satisfy the smoke `ci_hi < -0.1` criterion. The low-prevalence binomial NA fraction is high but below the new smoke guard of `0.25`; this remains a full-run audit focus.

## Harness Verification

I reran the harness in the dirty tree for both tokens. Both artifacts are invalid for final acceptance because `tree_clean: false`, but they verify the repaired harness behavior.

Ambient token:

- Artifact: `/Users/pgajer/current_projects/geosmooth/audit_artifacts/tier0_20260610T211827Z`
- `native_backend_token: cpp`
- `testthat_rc: 0`
- `tests=16 failed=0 error=0 warning=0 skipped=1`
- `gate_contexts: E0.1;E0.2;E0.3a;E0.4;E0.5;E0.6;E0.7;E0.8`
- `probe_rc: 0`
- `parity_max_abs_diff: 2.22044604925031e-16`

Local-PCA token:

- Artifact: `/Users/pgajer/current_projects/geosmooth/audit_artifacts/tier0_20260610T212543Z`
- `native_backend_token: cpp.local.pca`
- `testthat_rc: 0`
- `tests=16 failed=0 error=0 warning=0 skipped=1`
- `gate_contexts: E0.1;E0.2;E0.3a;E0.4;E0.5;E0.6;E0.7;E0.8`
- `probe_rc: 0`
- `parity_max_abs_diff: 0`

Direct backend spot check confirmed the parity paths are not R fallbacks:

```text
cpp backend.used: cpp; max diff vs R: 2.220446e-16
cpp.local.pca backend.used: cpp.local.pca; max diff vs R: 0
```

The previous harness regex defect is fixed: `gate_contexts.txt` is written and complete.

## Bucket-2 Item Status

1. E0.6 growing support grid: resolved at smoke scale. The slope failure from the prior audit is no longer present.
2. E0.6 binomial NA probabilities: partially resolved. The test now treats `NA` as guarded output and records NA/fallback fractions. The low-prevalence binomial case is close to the new `0.25` NA ceiling, so the full run must be inspected carefully.
3. `R/lps.R` guarded defaults: smoke evidence supports the candidate defaults, but final acceptance still requires a clean committed full artifact and mutation evidence.
4. Spec-DGP fidelity vs smoke mode: partially resolved. The contract now says full acceptance must include `LPS_TIER0_FULL=1` for E0.5/E0.6, but it does not document the remaining E0.1 deviation from the frozen spec (`n=70/85` and `4*c_p` support rather than `n=200` and `3*c_p`). This should be resolved before final Tier-0 acceptance.
5. Ambient rank diagnostics and E0.1 rank assertions: resolved at smoke scale. Direct spot check gave ambient `min.design.rank = 3`; duplicate-point case gives `min.design.rank = 1`.
6. E0.8 zero-bandwidth diagnostic: resolved at smoke scale. Direct spot check on the duplicate-point case gave `zero.bandwidth.fraction = 1`, and ordinary ambient reproduction gave `0`.
7. Stronger parity: resolved for smoke/probe. The probe uses a noisy non-reproducing degree-1 response and native-compatible monomial/no-ridge settings.

## Remaining Blockers For Final Acceptance

1. Produce a clean committed-tree artifact. Current artifacts are explicitly invalid because `tree_clean: false`.
2. Track and commit the Tier-0 files. In the current tree the Tier-0 tests, harness directory, contract, and artifacts are still untracked or dirty.
3. Run both harness tokens on the clean commit: `cpp` and `cpp.local.pca`.
4. Run at least one clean `LPS_TIER0_FULL=1` artifact for final phase acceptance.
5. Complete the mutation/falsification table from the independent audit brief. The current work proves smoke green, not that the gates can reliably go red.
6. Resolve/document the E0.1 spec deviation. Either run E0.1 at the frozen `n=200`, `K=3*c_p` design for final acceptance, or explicitly amend the contract/spec policy to justify the smoke-sized E0.1 gate.

## Nonblocking Harness/CI Comments

- The GitHub workflow now enforces much more of the contract and has the corrected path triggers, but it runs only `LPS_NATIVE_BACKEND=cpp`. The `cpp.local.pca` artifact remains a required manual/separate run unless CI adds a matrix over both tokens.
- The CI checksum step checks that `source_checksums.txt` exists, but it does not independently recompute and compare checksums. That may be acceptable for CI on a clean checkout, but the auditor still must perform the checksum binding check on the final bundle.
- The sanctioned-skip CI check greps for `E0.3a` when any skip exists; it does not prove that the skipped row, specifically, is E0.3a. The current artifacts are fine, but this check could be tightened.

## Commands Run

```sh
Rscript - <<'RS'
suppressMessages(pkgload::load_all('.', quiet=TRUE))
files <- c(
  'tests/testthat/test-lps-tier0-correctness.R',
  'tests/testthat/test-lps-tier0-correctness-extended.R',
  'tests/testthat/test-lps-degenerate.R'
)
for (f in files) {
  d <- as.data.frame(testthat::test_file(f, reporter='silent'))
  print(aggregate(cbind(nb, failed, warning) ~ test, d, sum))
  cat('errors:', sum(d$error), 'skipped:', sum(d$skipped),
      'warnings:', sum(d$warning), 'failed:', sum(d$failed), '\n')
}
RS

LPS_NATIVE_BACKEND=cpp EXECUTOR=codex-auditor-bucket2-cpp \
  bash scripts/ci/run_tier0_execution_artifact.sh

LPS_NATIVE_BACKEND=cpp.local.pca EXECUTOR=codex-auditor-bucket2-cpp-local-pca \
  bash scripts/ci/run_tier0_execution_artifact.sh

git diff --check -- R/lps.R \
  tests/testthat/test-lps-tier0-correctness.R \
  tests/testthat/test-lps-tier0-correctness-extended.R \
  tests/testthat/test-lps-degenerate.R \
  scripts/ci/run_tier0_execution_artifact.sh \
  scripts/ci/tier0_headroom_probe.R \
  .github/workflows/tier0-gate.yml \
  split_handoffs/lps_tier0_execution_artifact_contract_2026-06-10.md \
  split_handoffs/lps_tier0_bucket2_remediation_response_2026-06-10.md
```

`git diff --check` passed.
