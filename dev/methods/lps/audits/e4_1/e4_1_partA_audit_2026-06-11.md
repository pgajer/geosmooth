# E4.1 Part A Audit - Pointwise Variance and Degrees of Freedom

Date: 2026-06-11
Auditor: Codex, independent auditor
Worktree: `/Users/pgajer/current_projects/geosmooth-t4`
Branch: `codex/geosmooth-t4-uncertainty`
Audited commit: `3860806864acf6cc2f40f207ccb1a74f35939f48`

## Verdict

- **E4.1 Part A deterministic unit GATE: accept.** The gate compares the implemented `lps.smoother.matrix()` / `lps.pointwise.band()` route against an independently extracted smoother matrix `S` built column-by-column through public `fit.lps(e_j)` calls, matching the E0.2 protocol. Variance, df, sigma-hat, row norms, and band endpoints are asserted at the program algebraic tolerance `1e-10`. All required mutations turned the gate red.
- **E4.1 Part B coverage: deferred pending audited G3a.** The delivered coverage script and execution bundle include an inline-paraboloid smoke/wiring run only. It is explicitly labeled `smoke-wiring (NOT acceptance evidence)`, and I did not audit it as coverage acceptance evidence.

## Baseline Runs

Clean start checks:

- `pwd`: `/Users/pgajer/current_projects/geosmooth-t4`
- `git rev-parse HEAD`: `3860806864acf6cc2f40f207ccb1a74f35939f48`
- `git status --short`: empty before audit runs and after mutation restoration.

Focused Part-A gate:

- Command: `Rscript -e 'pkgload::load_all(".", quiet=TRUE); library(testthat); test_file("tests/testthat/test-lps-tier4-uncertainty.R")'`
- Result: 53 pass, 0 fail, 0 warning, 0 skip.

Fresh execution artifact:

- Command: `EXECUTOR="auditor-agent-e4.1" bash scripts/ci/run_e4_1_execution_artifact.sh`
- Bundle: `dev/methods/lps/audit_artifacts/e4_1_20260611T212303Z`
- Bundle HEAD: `3860806864acf6cc2f40f207ccb1a74f35939f48`
- Bundle clean tree: `true`
- Test summary: `tests=5 failed=0 error=0 warning=0 skipped=0`
- Gate contexts: `E4.1`
- Probe: `probe_rc: 0`
- Probe summary: `max_S_diff=5.551e-17`, minimum headroom `1801439.9x`, determinism `0`
- Smoke leg: enabled, exit 0, but context is explicitly `smoke-wiring (NOT acceptance evidence)`.

The fresh bundle records `git_head`, `git_status`, `sessionInfo`, BLAS, source checksums, raw test results, probe outputs, smoke outputs, and bundle checksums.

## Mutation Results

The assignment text says to mutate `R/lps.R`, but the E4.1 Part-A production implementation is in the new file `R/lps_uncertainty.R`; `R/lps.R` is unchanged in this deliverable. I therefore mutated `R/lps_uncertainty.R`, restored it after each run, and reran the focused gate.

| Gate property | Transient mutation | Result |
|---|---|---|
| `Var_i = sigma^2 * sum_j S_ij^2` | Changed `row.sq <- rowSums(S^2)` to `row.sq <- rowSums(S)` | **Red.** Variance/se assertions failed in both ambient and local-PCA fixtures; max variance discrepancies were about `0.1255`. |
| `df = tr(S)` | Changed `df <- sum(diag(S))` to `df <- sum(S[1, ])` | **Red.** df mismatches were about `8.51` and `6.92`; plug-in sigma formula also failed. |
| `sigma.hat^2 = RSS / (n - tr(S))` | Changed `sqrt(rss / (n - df))` to `sqrt(rss / n)` | **Red.** Plug-in sigma-hat squared failed in both fixtures, with discrepancies about `0.213` and `0.233`. |

After restoring with `git checkout -- R/lps_uncertainty.R`, the Part-A gate reran green.

## Spec Fidelity

- Tolerance is spec-verbatim: `1e-10`.
- The gate uses singleton grids, degree `1`, fixed chart dimension for the local-PCA fixture (`chart.dim = 2`), R backend, `orthogonal.polynomial.drop`, ridge grid `0`, and `ridge.condition.max = Inf`.
- The independent reference `S` is not taken from `lps.smoother.matrix()`. It is extracted column-by-column through public `fit.lps()` calls on unit responses `e_j`, the E0.2 protocol.
- The implemented Part-A routine computes `Var(yhat_i) = sigma^2 * rowSums(S^2)`, `df = sum(diag(S))`, and `sigma.hat^2 = RSS / (n - df)`.
- Band endpoints are checked as `fitted +/- z * se` with `z = qnorm(0.975)` for the default `level = 0.95`.
- The rectangular `X.eval` case is allowed for `lps.smoother.matrix()` but rejected for `lps.pointwise.band()`, consistent with df/RSS being defined on the square training smoother.

Part B:

- The inline paraboloid coverage run is not smuggled in as acceptance. The fresh bundle records the K=30 smoke interior coverage as failing: known sigma `0.9174` against `[0.93, 0.97]`; plug-in `0.9163` against `[0.92, 0.98]`.
- Coverage acceptance remains deferred until the audited Amendment-1 G3a generator and unpinned knobs (`K`, kernel, curvature radius) are resolved.

## Reproduced Numbers

I independently rebuilt `S` for the ambient fixture by fitting each unit response `e_j` through `fit.lps()`, then computed the variance and df outside the bundle/probe.

- Point 1 known-sigma variance from independent `S`: `0.059501820627789435`
- `lps.pointwise.band()` variance at point 1: `0.059501820627789442`
- Absolute difference: `6.94e-18`
- Independent `df = tr(S)`: `9.5136373719711038`
- Reported `band$df`: `9.5136373719711038`
- Absolute df difference: `0`
- Independent plug-in sigma squared `RSS/(n - tr(S))`: `0.94043983348777949`
- Reported `band$sigma.hat^2`: `0.94043983348777938`
- Absolute difference: `1.11e-16`
- Linear identity max difference `max(abs(S %*% y - fitted))`: `3.33e-16`

These are far below `1e-10`, not near the tolerance boundary.

## Bundle Validity

The fresh bundle is bound to the audited clean commit and includes source checksums for:

- `R/lps.R`
- `R/lps_uncertainty.R`
- `validation/e4_1_coverage_study.R`
- `scripts/ci/e4_1_headroom_probe.R`
- `tests/testthat/test-lps-tier4-uncertainty.R`

The manifest records `tree_clean: true`, `testthat_rc: 0`, `probe_rc: 0`, `smoke_rc: 0`, and `gate_contexts: E4.1`. I did not treat the harness's "PRELIMINARY: green" as the verdict; I inspected the manifest, probe CSV, smoke summary, and ran the required mutations.

## Handoff Honesty

The implementer handoff matches what I found:

- It accurately says Part A is delivered and Part B is only smoke-wired.
- It accurately discloses that `R/lps.R` was not modified; the implementation is a new `R/lps_uncertainty.R` file plus two `NAMESPACE` exports.
- It accurately reports the narrow supported envelope: gaussian, R backend, `orthogonal.polynomial.drop`, singleton grids, explicit fixed chart dimension, and square `X.eval` for bands.
- It accurately reports the fresh smoke coverage shortfall at K=30 and does not claim coverage acceptance.
- It states mutation qualification had not been run by the implementer; I supplied that audit evidence here.

I did not rerun the full package suite. The assignment's required acceptance evidence is the Part-A gate, execution artifact, independent reproduction, and mutation qualification. The handoff reports unrelated pre-existing full-suite failures in `test-ge7-lps-api.R`; I did not rely on those for this Part-A verdict.

## Reviewed Diff

Reviewed diff from base `b86b796` through audited tip `3860806`:

- `R/lps.R`: no diff for this deliverable.
- `R/lps_uncertainty.R`: new Part-A implementation, including `lps.smoother.matrix()`, `lps.pointwise.band()`, and private validation/influence-row helpers.
- `NAMESPACE`: exports `lps.smoother.matrix` and `lps.pointwise.band`.
- `tests/testthat/test-lps-tier4-uncertainty.R`: new Part-A gate.
- `scripts/ci/e4_1_headroom_probe.R`: bundle probe.
- `scripts/ci/run_e4_1_execution_artifact.sh`: execution-artifact harness.
- `validation/e4_1_coverage_study.R`: Part-B smoke/coverage harness, not acceptance evidence.
- `audit_contracts/tiers1to4/e4_1_spec_questions_implementer_2026-06-11.md` and `dev/methods/lps/handoffs/phase/e4_1_implementer_handoff_2026-06-11.md`: reviewed as handoff/context, not as authority.

I did not commit, push, or leave any mutation in package source.
