# E0.6 binomial-arm amendment — Implementer handoff (Tier-0 re-open)

Date: 2026-06-12
From: implementer agent (Tier 2, worktree `geosmooth-t2`, branch
`codex/geosmooth-t2-binary-hygiene`)
Authority: orchestrator adjudication of the E2.15 ⇄ E0.6 stop-and-raise
(Option 1; resolution recorded in
`audit_contracts/tiers1to4/e2_15_e06_interaction_raise_2026-06-12.md`).
This amends an accepted Tier-0 gate — the program's first Tier-0 re-open —
executed only after the adjudication was forwarded as the go-ahead.

## Goal

Amend E0.6's **binomial** arm from `unstable.action = "na"` to `"mean"` so
its consistency/calibration statistics are computed on deployed
predictions at every point (event-rate fallback where the logistic solve
does not converge), compatible with E2.15's selection rule (any candidate
with a non-finite CV prediction is unselectable) under which 7 of 72
smoke cells previously could not fit at all. The bernoulli arm keeps
`"na"` (no NA incidence on these fixtures).

## Files changed

Commit `5fb3a1c` — `tests/testthat/test-lps-tier0-correctness-extended.R`
only (no `R/lps.R` change): the `fit.bin` helper sets `unstable.action`
per family, and the test header documents the amendment, its rationale,
and the raise/adjudication provenance. No assertion or threshold was
changed: the existing consistency criterion (slope `ci_hi < -0.1`), the
`na.fraction < 0.25` guard, and the calibration bands all pass unchanged
under the new configuration.

## Exact commands run

```sh
Rscript -e '...test_file("tests/testthat/test-lps-tier0-correctness-extended.R")'
Rscript -e '...test_dir("tests/testthat", ...)'    # full suite
EXECUTOR="implementer-agent-t2" bash scripts/ci/run_tier2_execution_artifact.sh
```

## Result artifacts

Execution bundle `dev/methods/lps/audit_artifacts/tier2_20260612T215842Z/`:
`git_head = 5fb3a1c…`, `tree_clean: true`, `testthat_summary: tests=29
failed=0 error=0 warning=0 skipped=1` (the sanctioned E0.3a skip),
`gate_contexts: E0.1;…;E0.8;E2.12;E2.12a;E2.12b;E2.13;E2.14;E2.15`,
`probe_rc: 0`, `study_rc: 0`. The full battery is green again with E2.15
in place; the prior bundle `tier2_20260612T202904Z` (head `fe57126`)
preserves the pre-amendment error state for the record.

## Realized movement (smoke; binomial arm; bernoulli rows unchanged exactly)

| prevalence | slope (na→mean) | ci_hi (na→mean) | max na.fraction | median fallback |
|---|---|---|---|---|
| 0.1 | -0.3412 → -0.3139 | -0.2400 → -0.2400 | 0.19 → 0 | 0.0155 |
| 0.3 | -0.3503 → -0.3491 | -0.2786 → -0.2775 | 0.10 → 0 | 0.0000 |
| 0.5 | unchanged (-0.2912) | unchanged (-0.2148) | 0 → 0 | 0.0000 |

Cells that moved are exactly the cells where instability fired
pre-amendment (prevalence 0.1 and 0.3); prevalence 0.5 had none and is
unchanged to every printed digit. All consistency assertions hold with
ci_hi ≤ -0.2148 against the -0.1 criterion.

**Identity note for the re-audit** (verified numerically, stated here so
it is not discovered as an anomaly): where both binary arms select degree
0 — most cells post-amendment — the binomial and bernoulli fitted values
coincide to machine precision (measured max diff `1.8e-15` on the
prevalence-0.3, n=500, r=1 cell, with identical selected configurations),
because the intercept-only logistic MLE, the non-converged-solve
event-rate fallback, and the degree-0 least-squares fit are all the same
weighted event rate. The near-identical printed rows across the two
families are this identity, not a plumbing error; the binomial arm's
logistic path is demonstrably active (e.g. 450 converged solves and 50
telemetered fallbacks among 500 final fits on that cell).

## Whether source/tests were run

Yes — the amended battery file standalone (5 tests, 0 failures, 1
sanctioned skip), the full package suite (225 tests; only the four
pre-existing `test-ge7-lps-api.R` failures, no errors), and the full
bundle on a clean committed tree.

## Full-size re-acceptance evidence (added 2026-06-12, closing the open item)

Execution bundle `dev/methods/lps/audit_artifacts/tier2_20260612T233509Z/` — the full
battery under `LPS_TIER0_FULL=1` on the clean committed tree at
`git_head = 4367d10…` (`tree_clean: true` before and after,
`testthat_summary: tests=29 failed=0 error=0 warning=0 skipped=1` — the
sanctioned E0.3a skip — `gate_contexts: E0.1;…;E0.8;E2.12;E2.12a;E2.12b;
E2.13;E2.14;E2.15`, `probe_rc: 0`, `study_rc: 0`). Command:

```sh
LPS_TIER0_FULL=1 EXECUTOR="implementer-agent-t2" bash scripts/ci/run_tier2_execution_artifact.sh
```

This bundle is committed alongside this handoff update (force-added at its
standard `dev/methods/lps/audit_artifacts/` path, which is gitignored by default) per the
orchestrator's instruction, as the Tier-0 E0.6 re-acceptance evidence.

Full-size E0.6 binomial-arm consistency (n ∈ {500, 1000, 2000, 4000},
R = 40, support schedule up to 90/120/150; criterion `ci_hi < -0.1`),
against the accepted pre-amendment full-size values (`"na"`-era bundle
`tier0_20260611T040812Z_cpp` at `b86b796`):

| prevalence | slope (na→mean) | ci_hi (na→mean) | max na.fraction | median fallback |
|---|---|---|---|---|
| 0.1 | -0.3572 → -0.3181 | -0.3325 → -0.2973 | 0.236 → 0 | 0.0025 → 0.0020 |
| 0.3 | -0.3268 → -0.3175 | -0.3074 → -0.2980 | 0.124 → 0 | 0.0008 → 0.0000 |
| 0.5 | -0.3319 → -0.3269 | -0.3097 → -0.3060 | 0.024 → 0 | 0.0000 → 0.0000 |

All three full-size bernoulli rows are unchanged from the accepted values
to every printed digit (arm untouched, same seeds).

Full-size calibration (held-out logistic recalibration at n = 4000,
prevalence 0.3, seed 69999; the test gates the **bernoulli** arm with
bands slope ∈ (0.8, 1.25), intercept ∈ (-0.25, 0.25)):

- **bernoulli (gated):** slope `0.8005`, intercept `-0.0781`, all 2000
  held-out predictions finite — inside the bands, but the slope clears the
  lower band edge by only `5e-4`. This value is inherited from the
  accepted configuration (the bernoulli arm is untouched by the
  amendment); the margin is stated here so the re-audit sees it rather
  than discovers it.
- **binomial (reported, NOT gated — E0.6 has no binomial calibration
  assertion):** same protocol on a binomial fit: slope `0.8005`,
  intercept `-0.0781`, all predictions finite, final-fit fallback
  fraction `0.0000`. Identical to bernoulli by the degree-0 identity:
  both arms select (support 95, degree 0) at this size, where the
  intercept-only logistic MLE equals the weighted event rate. Computed by
  the mirrored standalone script recorded in this handoff's command log
  (the committed test computes but does not print these values).

## Limitations and unverified claims

- ~~**Smoke sizes only.**~~ **Closed above**: the full-size battery ran
  green on the clean tree at `4367d10` (bundle
  `tier2_20260612T233509Z`).
- **The full-size bernoulli calibration slope passes by `5e-4`.** Not a
  product of this amendment (the arm and seeds are unchanged), but any
  future change that perturbs bernoulli numerics — or a different BLAS —
  could flip that assertion. Flagged as a fragility, not acted on.
- **The full-size binomial calibration analogue is informative only**: at
  n = 2000 training both arms select degree 0, so it numerically equals
  the bernoulli value and does not separately exercise the logistic
  path's calibration; the logistic path's distinct full-size behavior
  shows up in the consistency cells where degree 1 is selected and in the
  fallback accounting.
- **No mutation run.** The adjudication assigns the re-audit to confirm
  the `unstable.action` change is the deployed-scoring fix rather than
  goalpost-moving and that no real calibration failure is masked; none of
  that is attempted here.
- **The movement comparison is against the printed 4-decimal statistics**
  of the accepted bundles (and my earlier same-seed reruns); I did not
  archive per-cell RMSE tables from the "na" era beyond those lines, so
  finer-grained before/after deltas per (n, r) cell are not recorded.
- The E0.6 calibration block (held-out logistic recalibration) runs on
  the **bernoulli** arm only, as before; the amendment does not add a
  binomial calibration assertion. Whether the binomial arm should gain
  one is a spec question I have not raised formally.
- The degree-0 identity makes the smoke binomial consistency slope
  largely coincide with the bernoulli slope wherever degree 0 wins
  selection; the slope criterion therefore currently exercises the
  logistic path's distinct behavior only through the cells/replicates
  where degree 1 is selected and through the fallback accounting. The
  full-size run (larger supports) may select degree 1 more often.
