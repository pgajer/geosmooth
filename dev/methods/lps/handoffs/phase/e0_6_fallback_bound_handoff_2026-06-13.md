# E0.6 binomial fallback-fraction bound — Implementer handoff

Date: 2026-06-13
From: implementer agent (Tier 2, worktree `geosmooth-t2`, branch
`codex/geosmooth-t2-binary-hygiene`)
Authority: orchestrator instruction — "add a bounded fallback-fraction
assertion to E0.6's binomial arm … promotes the already-printed telemetry
into an enforceable gate; no production-source change; re-bundle smoke +
full-size."
Builds on the E0.6 binomial-arm amendment (Tier-0 re-open) recorded in
`phase_handoffs/e0_6_binomial_amendment_handoff_2026-06-12.md`.

## Goal

E0.6's binomial arm runs `unstable.action = "mean"`, so non-converged
logistic solves deploy an event-rate fallback prediction at every point and
the per-fit fallback fraction is telemetered
(`fit$logistic.diagnostics$final$fallback.path.fraction`). E0.6 already
printed the per-prevalence median of that fraction
(`median_fallback=%.4f`). This change turns that printed telemetry into an
enforceable gate: the per-prevalence median deployed-fallback fraction must
stay below a documented threshold.

## Files changed

Commit `83218b6` — `tests/testthat/test-lps-tier0-correctness-extended.R`
only (no `R/lps.R` change). The previously-inline median is hoisted into a
`median.fallback` variable (so the printed line and the assertion use the
same value), and a binomial-only assertion is added immediately after the
existing `expect_lt(ci.hi, -0.1)`:

```r
if (identical(fam, "binomial")) {
    expect_lt(median.fallback, 0.3)
}
```

The bernoulli arm records `NA` fallback (least-squares solve, no logistic
path); a median over all-`NA` is `NA`, not a meaningful bound, so the
assertion is guarded to the binomial arm. No fit, seed, RNG draw, or
threshold elsewhere was changed — `stats::median(...)` is pure computation
over already-realized telemetry.

## The bound and its rationale

The threshold is `0.3`. Realized per-prevalence medians are ~`0.0155`
(smoke) / ~`0.0020` (full-size) at prevalence 0.1 and `0` at prevalences
0.3 and 0.5. `0.3` clears the realized binomial path by ~20× (smoke) /
~150× (full-size) while reddening a degenerate regime where every final fit
takes the fallback path (median `1.0`). It is a fixed guard chosen above the
realized fraction, not a quantity derived from the frozen spec (which states
no fallback-fraction criterion); see Limitations.

## Exact commands run

```sh
# standalone gate (smoke), confirming the assertion passes and bernoulli is skipped
Rscript -e 'pkgload::load_all("."); library(testthat); test_file(
  "tests/testthat/test-lps-tier0-correctness-extended.R", reporter="summary")'

# smoke + full-size execution bundles, on a clean committed tree
EXECUTOR="implementer-agent-t2" bash scripts/ci/run_tier2_execution_artifact.sh
LPS_TIER0_FULL=1 EXECUTOR="implementer-agent-t2" bash scripts/ci/run_tier2_execution_artifact.sh
```

The bundles were generated against a pristine checkout of `83218b6` and then
copied into this worktree and force-added (`audit_artifacts/` is gitignored
by default), as with the prior E0.6 evidence.

## Result artifacts

- Smoke bundle `audit_artifacts/tier2_20260613T235106Z/`:
  `git_head = 83218b6…`, `tree_clean: true`, `testthat_summary: tests=29
  failed=0 error=0 warning=0 skipped=1` (sanctioned E0.3a skip),
  `gate_contexts: E0.1;…;E0.8;E2.12;E2.12a;E2.12b;E2.13;E2.14;E2.15`,
  `probe_rc: 0`, `study_rc: 0`, `tree_clean_post_study: true`.
- Full-size bundle `audit_artifacts/tier2_20260614T015321Z/` (run under
  `LPS_TIER0_FULL=1`): identical manifest fields — `git_head = 83218b6…`,
  `tree_clean: true`, `tests=29 failed=0 error=0 warning=0 skipped=1`, full
  gate coverage, `probe_rc: 0`, `study_rc: 0`, `tree_clean_post_study: true`.

## Realized gated quantity (binomial arm; bernoulli median is NA, not gated)

| size | prevalence | slope | ci_hi | median_fallback | < 0.3 |
|---|---|---|---|---|---|
| smoke | 0.1 | -0.3139 | -0.2400 | 0.0155 | yes |
| smoke | 0.3 | -0.3491 | -0.2775 | 0.0000 | yes |
| smoke | 0.5 | -0.2912 | -0.2148 | 0.0000 | yes |
| full | 0.1 | -0.3181 | -0.2973 | 0.0020 | yes |
| full | 0.3 | -0.3175 | -0.2980 | 0.0000 | yes |
| full | 0.5 | -0.3269 | -0.3060 | 0.0000 | yes |

All consistency slopes (`ci_hi < -0.1`) and all calibration/`na.fraction`
assertions pass unchanged; the slopes and ci_hi values reproduce the prior
accepted bundles (`tier2_20260613T235106Z`-era smoke and
`tier2_20260612T233509Z` full-size) to every printed digit, since the change
adds only an assertion.

## Whether source/tests were run

Yes — the amended battery file standalone at smoke size (E0.6 passes; the
binomial assertion fires on three prevalences and the bernoulli arm is
skipped), and both execution bundles on a clean committed tree. I did NOT
run any mutation/negative-control tests against the new assertion; that is
the auditor's authorship-independent check.

## Branch housekeeping (not part of the gate change)

Per a separate orchestrator instruction, the two untracked 2026-06-13
auditor re-audit notes (`audits/e0_6_binomial_amendment_reaudit_2026-06-13.md`,
`audits/tier2_combined_reaudit_2026-06-13.md`) were checked in verbatim
(commit `722628b`, no implementer edits to their content) and the branch was
pushed to `origin/codex/geosmooth-t2-binary-hygiene` (new branch, upstream
set). This leaves the worktree clean so bundles no longer require a throwaway
worktree.

## Limitations and unverified claims

- **The `0.3` threshold is a guard, not a spec-derived bound.** The frozen
  E0.6 spec states consistency and calibration criteria but no
  fallback-fraction criterion; `0.3` was chosen to sit well above the
  realized fraction and well below the degenerate `1.0`. A different DGP,
  BLAS, or future numerics change could raise the realized fraction; the
  bound was not stress-tested against such a perturbation.
- **Only the binomial arm is gated.** The bernoulli arm has no logistic
  fallback path (`median_fallback=NA`) and is deliberately skipped, so the
  assertion exercises nothing on that arm.
- **Wall-time.** The full-size bundle ran ~74 minutes (logistic IRLS at
  n=4000 dominates); the first two background attempts were killed mid-run
  and the green full-size bundle was produced from a fully-detached run.
  This is an environment/runtime note, not a property of the gate.
- **No mutation run** (as above): whether the bound meaningfully constrains
  the code beyond the printed telemetry is left to the auditor.
