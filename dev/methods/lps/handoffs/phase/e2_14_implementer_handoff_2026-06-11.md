# E2.14 — Implementer handoff (local logistic robustness under separation)

Date: 2026-06-11
From: implementer agent (Tier 2, worktree `geosmooth-t2`, branch
`codex/geosmooth-t2-binary-hygiene`)
Gate: E2.14 (contract §C; frozen spec §E2.14) — correctness GATE
Spec-questions memo (submitted before implementation):
`audit_contracts/tiers1to4/t2_spec_questions_implementer_2026-06-11.md`
(items 1–5 cover E2.14).

## Goal

IRLS step-halving in the local logistic solver plus a deterministic,
telemetered fallback on non-convergence, with the GATE asserting the deviance
trajectory (non-increasing within `1e-8` per step), bounded outputs
(`p_hat` strictly in `(0,1)`, finite coefficients), and that exact separation
hits the documented fallback without looping or producing NaN.

## Files changed or created

All on branch `codex/geosmooth-t2-binary-hygiene`; base commit `b86b796`
(the smoke-accepted Tier-0 base).

- Commit `58fb1be` — `audit_contracts/tiers1to4/t2_spec_questions_implementer_2026-06-11.md` (new).
- Commit `75c1788`:
  - `R/lps.R` (modified): `.klp.solve.local.logistic` — deviance-based
    step-halving (slack `1e-8`, at most 30 halvings per Newton step, new
    terminal status `"step_halving_failed"`), a deviance closure evaluated on
    the same `[-35, 35]`-clamped linear predictor the IRLS update uses, and
    four additive return fields on both the converged and failure branches:
    `converged`, `iterations`, `step.halvings`, `deviance.trace`. The failure
    branch's trace fields describe the last attempted ridge multiplier (each
    `rho` restarts from the same initialization). The coefficient-step
    convergence criterion (`1e-7`), iteration cap (50), eta clamp, variance
    floor, ridge/condition bookkeeping, fallback layer, and aggregate
    telemetry are unchanged. `fit.lps` roxygen documents the behavior.
  - `tests/testthat/test-lps-binary-separation.R` (new): the E2.14 GATE,
    3 tests / 43 assertions; fixtures and assertions listed below.
  - `validation/e2_14_prefix_newton_overshoot.R` (new): deterministic
    replication of the pre-change plain-Newton internals on the gated
    fixture; writes `reports/e2_14_prefix_newton_overshoot.csv` (committed).
  - `scripts/ci/run_tier2_execution_artifact.sh`,
    `scripts/ci/tier2_binary_probe.R` (new): Tier-2 evidence-bundle harness
    reusing the Tier-0 pattern; reruns the full Tier-0 battery alongside the
    Tier-2 gate files and records realized quantities from the actual solver.

Package source was modified (one function in `R/lps.R` plus roxygen text).
No exported API change; no new `fit.lps` argument; `NAMESPACE`, `DESCRIPTION`
untouched. Generated `man/` is untracked in this repo and was not rebuilt.

## Fixtures (deterministic, no RNG; spec DGP family)

- Near-separable: `z = c(seq(-0.20, -0.04, by = 0.02), 6)`, `y = 1{z > 0}`
  with `y[2]` flipped to 1, weights `gaussian` on `|z|`, degree-1 design
  `cbind(1, z)`, `design.basis = "orthogonal.polynomial.drop"`, singleton
  `ridge.multiplier.grid = 0`, `ridge.condition.max = Inf`.
- Exactly separable: same support without the flip.

The flip position is load-bearing: an edge-of-cluster flip (index 2) produces
the pre-fix overshoot; a mid-cluster flip (e.g. index 5) leaves plain Newton
monotone (measured). This is documented in the test file's header comment.

## Exact commands run (from the worktree root)

```sh
Rscript -e 'suppressMessages(pkgload::load_all(".", quiet = TRUE)); testthat::test_file("tests/testthat/test-lps-binary-separation.R")'
Rscript validation/e2_14_prefix_newton_overshoot.R
Rscript -e 'suppressMessages(pkgload::load_all(".", quiet = TRUE)); testthat::test_dir("tests/testthat", reporter = "summary")'
EXECUTOR="implementer-agent-t2" bash scripts/ci/run_tier2_execution_artifact.sh
# pre-existing-failure check + same-seed E0.6 baseline, throwaway detached
# worktrees at the base commit (created and removed; no branch touched):
git worktree add --detach /tmp/geosmooth-base-check b86b796   # test-ge7-lps-api.R
git worktree add --detach /tmp/geosmooth-base-e06 b86b796     # E0.6 smoke baseline
```

## Result artifacts

- Execution bundle: `dev/methods/lps/audit_artifacts/tier2_20260611T075822Z/` (gitignored
  path, on disk in the worktree), `git_head =
  75c1788b06f0c1811dc4f89f1ec52f1616c13a64`, `tree_clean: true`,
  `testthat_summary: tests=19 failed=0 error=0 warning=0 skipped=1`,
  `gate_contexts: E0.1;…;E0.8;E2.14`, `probe_rc: 0`. Contains
  `testthat_results.csv`, `e2_14_deviance_traces.csv`,
  `e2_14_solver_summary.csv`, `e2_14_fallback_telemetry.csv`,
  `e2_14_solver_args.txt`, `sessionInfo.txt`, `blas.txt`,
  `source_checksums.txt`, `BUNDLE_CHECKSUMS.txt`.
- Pre-fix trajectory: `reports/e2_14_prefix_newton_overshoot.csv`
  (regenerable via `Rscript validation/e2_14_prefix_newton_overshoot.R`).

## Numerical findings

Pre-fix (plain-Newton replication of the `b86b796` solver internals, same
fixture, singleton `rho = 0`):

- Near-separable arm: deviance increases by `4.890345e+02` at step 2, eight
  increases `> 1e-8` within 50 iterations, no convergence (the support
  therefore silently degraded to the event-rate fallback in the pre-change
  code). Per-iteration trace in `reports/e2_14_prefix_newton_overshoot.csv`.
- Exactly-separable arm: monotone decrease, no convergence in 50 iterations,
  no NaN (pre- and post-fix behavior coincide on this arm).

Post-fix (actual solver, recorded in the bundle):

- Near-separable arm: `status = "ok"`, converged at iteration 9 with exactly
  1 step-halving, `max deviance increase = 1.78e-15` (trajectory
  non-increasing within `1e-8`), coefficients finite,
  `p_hat(center) = 0.124668 ∈ (0,1)`, bitwise-identical on re-solve
  (determinism diff `0`).
- Exactly-separable arm: `status = "not_converged"` at the 50-iteration cap,
  trace finite and monotone (max increase `-1.58e-10`), 0 halvings; at the
  fitting layer the documented fallback fires and is telemetered:
  `unstable.action = "mean"` returns the weighted event rate `0.0631513478`
  (equals `weighted.mean(y, w)` to `1e-12`) with `attempted = 1, converged =
  0, fallback.path = 1, event.rate.fallback = 1`; `unstable.action = "na"`
  returns `NA` with `na.failure = 1`.

Tier-0 battery after the change (same bundle): 16 tests, 0 failures, 1
sanctioned skip (E0.3a). The E0.6 smoke statistics are **bit-identical** to a
same-seed rerun of the unmodified base commit `b86b796` in all six
family×prevalence cells (slopes, CI bounds, NA fractions, fallback medians;
e.g. binomial prevalence 0.1: `slope = -0.3412, ci_hi = -0.2400, max_na =
0.1900, median_fallback = 0.0155` both pre and post). Step-halving never
engaged on those supports.

Full package suite (`test_dir`): 4 failures, all in
`tests/testthat/test-ge7-lps-api.R` (lines 322–325 and 682), all reproduced
**unchanged at the unmodified base commit** `b86b796` in a detached throwaway
worktree; they are outside the Tier-0 battery and predate this work. No new
failures introduced.

## Whether source/tests were run

Yes: the new GATE file (43/43 pass), the full package suite (4 pre-existing
failures as above, nothing else), the Tier-0 battery inside the bundle
(green), the validation replication script, and the Tier-2 probe (green,
exit 0) were all executed in this worktree at commit `75c1788`.

## Limitations and unverified claims

- **No mutation run.** I did not run the contract's named mutation (disable
  step-halving) as acceptance evidence; mutation-qualification is not mine
  to perform. The fixture was, however, chosen so that the plain-Newton
  iteration on it is non-monotone (the pre-fix replication above), and the
  GATE additionally asserts `step.halvings >= 1` on that fixture.
- **The pre-fix demonstration is a replication, not an execution of deleted
  code.** The pre-change solver had no trace hooks, so
  `validation/e2_14_prefix_newton_overshoot.R` re-implements the `b86b796`
  update equations (for singleton `rho = 0`, orthogonal basis, condition
  guard disabled) rather than calling the old function. I assert the replica
  matches the old code path under the gate configuration — the ridge-grid
  retry and condition-guard branches are inert there — but that equivalence
  is my reading of the diff, not a verified execution of the old binary.
- **Bit-for-bit preservation is structural, not exhaustively verified.** The
  claim "well-behaved solves are numerically identical" rests on: (i) the
  halving loop accepts the unmodified Newton candidate whenever the full
  step satisfies the deviance slack, and (ii) one committed regression test
  comparing the solver against an independent plain-IRLS replication on one
  benign fixture, and (iii) the bit-identical E0.6 smoke statistics. Solves
  where a full Newton step increases the deviance by more than `1e-8`
  change behavior by design; beyond E0.6 I have not surveyed how often such
  supports occur in real fits.
- **The recorded deviance is the clamped-eta surrogate.** Trajectory
  monotonicity is asserted for the deviance evaluated at
  `eta` clamped to `[-35, 35]` (the same surrogate the IRLS update uses).
  For iterates with `|eta| > 35` this differs from the exact binomial
  deviance; on the gated fixtures the converged iterates are well inside the
  clamp, but I did not verify exactness of the surrogate along every
  intermediate iterate.
- **Failure-path trace scope.** On the failure branch the returned
  `deviance.trace` / `iterations` / `step.halvings` describe only the last
  attempted ridge multiplier; with the default ridge grid (three values) the
  earlier attempts' traces are discarded. The gate uses a singleton grid, so
  this does not affect the gated assertions. The failure branch also carries
  no `coefficients`/`prediction` fields (pre-existing shape, unchanged); the
  probe's `beta.all.finite = FALSE` for the exact arm reflects that absence,
  not a non-finite value.
- **Fixture-search provenance.** The fixture was found by an in-session
  randomized search over the spec's DGP family (plain-Newton overshoot in
  roughly 1541 of 50000 targeted draws; near-zero incidence under broader
  uniform configurations). The search scripts were exploratory and are not
  committed; only the final deterministic fixture and its committed
  replication are evidence.
- **Single environment.** All numbers are from one machine/BLAS
  (`sessionInfo.txt`, `blas.txt` in the bundle: macOS arm64, vecLib). The
  step-halving decision compares floating-point deviances; a different BLAS
  could in principle halve at a different step on near-threshold supports. I
  did not test other environments, and the smoke-vs-full distinction for
  Tier-0 release evidence is unaffected by this gate but was not exercised
  here (`LPS_TIER0_FULL` not set).
- **`max.step.halvings = 30` and the `1e-8` slack are constants, not
  arguments.** The slack is the contract's number; the cap is my choice
  (memo item 1). Neither is reachable from `fit.lps`; a support needing more
  than 30 halvings lands in the documented fallback, and I constructed no
  case exercising the `"step_halving_failed"` status end-to-end.
- The four pre-existing `test-ge7-lps-api.R` failures at `b86b796` are
  reported as found; I did not investigate their cause.
