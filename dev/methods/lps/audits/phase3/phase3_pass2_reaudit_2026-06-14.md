# Phase 3 merged-main re-audit, Pass 2 post-e19 reconciliation

Date: 2026-06-14
Auditor: Codex
Certified SHA: `fee94853515983384e8693efe2e460de782be325`
Materialized worktree: `/tmp/gm-phase3b`
Scope: final `main` integration after e19 reconciliation and GE7 cleanup.

## Verdict

ACCEPT.

The certified merged `main` tip preserves the Tier-2 binary behavior, the e19
bandwidth-multiplier behavior, the nested-CV behavior, and the GE7 test
maintenance fixes. The full `LPS_TIER0_FULL=1` test battery is green, the
explicit E1.9/E2.13/GE7 reference gates are green, and all seven required
mutation checks redden their corresponding gates.

## Inputs Reviewed

- Pass-1 verdict:
  `/Users/pgajer/current_projects/geosmooth/audits/phase3_merged_main_reaudit_2026-06-14.md`
- Reconciliation work order:
  `/Users/pgajer/current_projects/geosmooth/project_briefs/lps_e19_reconciliation_workorder_2026-06-14.md`
- Implementer handoff:
  `/Users/pgajer/current_projects/geosmooth-e19/dev/methods/lps/handoffs/phase/e1_phase2b_reconciliation_implementer_handoff_2026-06-14.md`
- Standing auditor prompt:
  `/Users/pgajer/current_projects/geosmooth/project_briefs/lps_e19_auditor_prompt_2026-06-11.md`

## Certified Tree And Battery

The audit worktree was created at:

```sh
git worktree add /tmp/gm-phase3b fee9485
```

`git rev-parse HEAD` in `/tmp/gm-phase3b` returned:

```text
fee94853515983384e8693efe2e460de782be325
```

The final clean full-suite command, run with `LPS_TIER0_FULL=1`, produced:

```text
files=27 tests=262 failed=0 error=0 warning=66 skipped=1
```

The slow E0.6 full-size rows printed during the successful run:

| family | prevalence | slope | ci_hi | max_na | median_fallback |
|---|---:|---:|---:|---:|---:|
| bernoulli | 0.1 | -0.3182 | -0.2963 | 0.0000 | NA |
| bernoulli | 0.3 | -0.3219 | -0.3021 | 0.0000 | NA |
| bernoulli | 0.5 | -0.3310 | -0.3088 | 0.0000 | NA |
| binomial | 0.1 | -0.3181 | -0.2973 | 0.0000 | 0.0020 |
| binomial | 0.3 | -0.3175 | -0.2980 | 0.0000 | 0.0000 |
| binomial | 0.5 | -0.3269 | -0.3060 | 0.0000 | 0.0000 |

The full-suite result artifacts from this audit run are:

- `/tmp/gm_phase3b_full_suite_summary.txt`
- `/tmp/gm_phase3b_full_suite_results.rds`
- `/tmp/gm_phase3b_full_suite_results.csv`

Note: one earlier full-suite run reached the end of the test battery but failed
while exporting the `testthat` result to CSV because the result object contained
list columns. That run was not counted as evidence. The accepted battery result
above is from the corrected rerun, which wrote the summary before exporting a
flattened CSV.

## Signature, Grid, And Defaults

The merged `fit.lps` signature contains the required additive union:

- `bandwidth.multiplier.grid = 1`
- `keep.cv.predictions = FALSE`
- `ridge.shrinkage.target = c("zero", "local.mean")`, so the default target is
  `"zero"`.

The candidate grid construction in `R/lps.R` is exactly:

```r
expand.grid(
    support.size = support.grid,
    degree = degree.grid,
    kernel = kernel.grid,
    bandwidth.multiplier = bandwidth.multiplier.grid
)
```

There is no extra Tier-2 grid dimension for `ridge.shrinkage.target` or
`keep.cv.predictions`. A default Gaussian fit produced 18 candidates; the same
configuration with `bandwidth.multiplier.grid = c(0.5, 1, 2)` produced 54
candidates. The CV table columns included `bandwidth.multiplier` and did not
include a ridge-target grid column.

I also reproduced a binomial default behavior equality against pre-e19 `main`
(`ffa840a`) using a canonical text digest of fitted values, selected row, and
CV metrics on a fixed synthetic binomial fixture:

```text
18ea9c803b8185cc4a18f84fb3db743470f9248b74183219f531587de2e71ede  fee9485
18ea9c803b8185cc4a18f84fb3db743470f9248b74183219f531587de2e71ede  ffa840a
```

This verifies that the merged default binomial behavior matches the Tier-2
parent, not the stale pre-Tier-2 e19 behavior.

## GE7 Cleanup

`tests/testthat/test-ge7-lps-api.R` passes cleanly at `fee9485`:

```text
test-ge7-lps-api.R failed=0 error=0 warning=0 skipped=0 tests=24
```

The former line 322/323/325 telemetry fixture is now the Pass-1 exact-separation
fixture:

```r
z <- c(seq(-0.20, -0.04, by = 0.02), 6)
design <- cbind(1, z)
y <- as.numeric(z > 0)
```

It asserts `is.na(failed)`, `fallback.path.count == 1`,
`event.rate.fallback.count == 0`, and `na.failure.count == 1`, so it now
exercises the intended `na.failure` path.

The former line 682 nearly-saturated WLS expectation was updated per the
orchestrator-ratified disposition: it keeps
`expect_false(.klp.local.design.is.safe(...))`, then asserts the fitted
intercept is finite and is not equal to the local weighted mean. No production
`.klp.local.design.is.safe()` to fallback guard was added.

## Explicit Reference Gates

After all mutation restores, I ran the explicit reference gates clean:

```text
test-lps-bandwidth-multiplier.R failed=0 error=0 warning=0 skipped=0 tests=8
test-lps-ridge-alignment.R failed=0 error=0 warning=0 skipped=0 tests=4
test-ge7-lps-api.R failed=0 error=0 warning=0 skipped=0 tests=24
```

## Mutation Qualification

All mutations were applied only in `/tmp/gm-phase3b` and restored immediately.
`git status --short` was empty after each restore.

| Required check | Mutation applied | Gate run | Red result |
|---|---|---|---|
| E2.13 ridge alignment | Removed the `+ ybar.w` add-back in the aligned ridge prediction branch. | `tests/testthat/test-lps-ridge-alignment.R` | `failed=9 error=0` |
| E2.14 separation | Changed `max.step.halvings <- 30L` to `0L`. | `tests/testthat/test-lps-binary-separation.R` | `failed=4 error=1` |
| E2.12 metric/backend | Changed the binary `backend="auto"` force-to-R branch to apply only to binomial. | `tests/testthat/test-lps-binary-metric-consistency.R` | `failed=0 error=1` |
| E2.15 NA consistency | Restored old drop-NA `cv.logloss.observed <- .klp.logloss(...)` behavior. | `tests/testthat/test-lps-binomial-na-consistency.R` | `failed=3 error=0` |
| E0.6 fallback bound | Inserted `return(fallback("forced"))` in `.klp.fit.logistic.prob.design()`. | `tests/testthat/test-lps-tier0-correctness-extended.R` with `LPS_TIER0_FULL=1` | `failed=3 error=0`; binomial median fallback became `1.0000` for all three prevalence rows |
| E1.9 bandwidth | Forced `b <- 1` in `.klp.kernel.weights()`, neutralizing the multiplier. | `tests/testthat/test-lps-bandwidth-multiplier.R` | `failed=2 error=0` |
| E1.10 nested CV | Changed outer-fold training rows from `which(outer.foldid != label)` to `seq_len(n)`. | `tests/testthat/test-lps-nested-grouped-cv.R` | `failed=22 error=0` |

These mutations qualify the relevant gates: each required behavioral regression
is caught by its intended test.

## Source Checksums

Final restored checksums in the certified worktree:

| file | sha256 |
|---|---|
| `R/lps.R` | `3f3260b0692a1956c406995c3a1f3a5cbd7dcae69f167e4c3c069b134cb3e1c8` |
| `R/lps_cv_utils.R` | `db1e6fdb3ab4befd25a126d4e9884dbd5c34ca9c3d1212eb6a3f4e35a1ee0a0a` |
| `tests/testthat/test-ge7-lps-api.R` | `6282be983d763880e0658c0bb2731cfffdc838822e48a84309401fee571db5fc` |
| `tests/testthat/test-lps-bandwidth-multiplier.R` | `31b46595b7a65d4128da64d817b6b3e305edaec2af9f2ff0f94b1e9cfbbbc888` |
| `tests/testthat/test-lps-ridge-alignment.R` | `83d3188f1a730e86cdc3bc5bcf8ecd30b6193d53707c34eb55f885b937ae521d` |
| `tests/testthat/test-lps-binary-separation.R` | `15781b28a55a50ea265d08f9b7d468bd7e343662f40fc6c343088bd39433417c` |
| `tests/testthat/test-lps-binary-metric-consistency.R` | `db3d5b77a7ee423aa370b8c83881c44b84f401320b2a0ee04deaab71c1bc42a7` |
| `tests/testthat/test-lps-binomial-na-consistency.R` | `193110f61ccc2b24d30ab1b8d97ffef0d9221477878b0fe9763114d6b93f1905` |
| `tests/testthat/test-lps-tier0-correctness-extended.R` | `6d361fb3d494ace72d8f635788319f31a414bbe13e3038c459ca8fe09f28c7bf` |

## Limitations

- The implementer evidence bundle in
  `/Users/pgajer/current_projects/geosmooth-e19/reports/phase2b_reconciliation/`
  records `git_status.txt` with the evidence directory itself untracked at the
  moment that bundle was generated. I did not treat that as a certified-code
  defect because the independent full-suite rerun above is the acceptance
  evidence for this pass.
- The 66 warnings in the full suite were not reclassified in this pass. The
  implementer handoff attributes them to pre-existing graph-trend-filtering
  warnings, and the pass criterion here is failure/error-free LPS integration.

## Final Decision

ACCEPT `fee94853515983384e8693efe2e460de782be325` as the Phase 3 merged-main
Pass 2 result. The integrated `main` is ready for the orchestrator's push and
for the next phase.
