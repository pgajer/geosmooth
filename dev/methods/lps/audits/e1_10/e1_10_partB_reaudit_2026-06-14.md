# E1.10 Part B re-audit -- complete acceptance bundle and mutation addendum

Date: 2026-06-14

Auditor: Codex, independent audit role

Worktree: `/Users/pgajer/current_projects/geosmooth-e19`

Current audit tip: `8e432ea959a85ba549bbabbbdf2de8e9741f2883`

Acceptance bundle commit: `de0f861c7c46f1d2159f3997d9e75abb24ee868a`

Source-certifying run commit recorded by acceptance manifest: `79b94bfc3b2d14ede4fbc5a98d02588112fc9c10`

## Verdict

**Accept the E1.10 Part B evidence bundle as provenance-valid and mutation-qualified.**

Disposition:

- Study (a), `dgp.g3a`: **PASS accepted under the ratified STUDY rule**, with a caveat that the optimism contrast is near-degenerate on this DGP.
- Study (b), `dgp.g5`: **rho=0.6 FAIL is genuine and correctly implemented.** This is a recorded negative STUDY finding, not a CI failure.
- [P1] SE guard: **accept.** Inflating the optimism-delta SE flips the Study (a) verdict logic from `PASS` to `INCONCLUSIVE`.
- [P3] fractional fold-count validation: **accept.** Non-whole `v` and `inner.folds` error instead of truncating.

The audit worktree was clean before mutation and clean after restoration.

## Bundle Validity

The committed acceptance evidence is now complete and tracked under `reports/e1_10_acceptance/`:

- `e1_10_a_optimism_cases.csv`
- `e1_10_a_optimism_verdict.csv`
- `e1_10_b_grouped_cases.csv`
- `e1_10_b_grouped_verdict.csv`
- `e1_10_run_metadata.txt`
- `MANIFEST.txt`
- `source_checksums.txt`
- `sessionInfo.txt`
- `gate_battery_summary.txt`
- `realized_rho_per_replicate.csv`

The gate-battery bundle `dev/methods/lps/audit_artifacts/e1_10_20260614T152852Z/` records:

- `git_head: de0f861c7c46f1d2159f3997d9e75abb24ee868a`
- `tree_clean: true`
- `tests=31 failed=0 error=0 warning=0 skipped=1`
- acceptance binding: `a:PASS b(rho=0.6):FAIL generator:registry acceptance_evidence:TRUE`

The acceptance manifest itself was generated before the bundle commit, so its recorded run commit is `79b94bf`; the gate-battery artifact then certifies the committed bundle at `de0f861`. Current `8e432ea` adds only the implementer handoff.

## Source-Clean Confirmation

The four audited source files are unchanged from the prior source audit through both `de0f861` and current `8e432ea`:

```sh
git diff ce4d558..de0f861 -- R/lps.R R/lps_cv_utils.R validation/e1_10_nested_grouped_cv.R tests/testthat/test-lps-nested-grouped-cv.R
git diff ce4d558..8e432ea -- R/lps.R R/lps_cv_utils.R validation/e1_10_nested_grouped_cv.R tests/testthat/test-lps-nested-grouped-cv.R
```

Both diffs were empty.

Recorded source hashes match the previous audit:

```text
588762790b651091717fedc5c424b6dd78ae348ac0bd70a5af1691c68c4ff2ee  R/lps.R
db1e6fdb3ab4befd25a126d4e9884dbd5c34ca9c3d1212eb6a3f4e35a1ee0a0a  R/lps_cv_utils.R
98c0a3f7ea764549097704d0ce4b273f1d35c4f1d34c0862b494cf51cdf1d1f3  validation/e1_10_nested_grouped_cv.R
8bd66a2ff8cfb7f4f39b356127b3918bf41b7da9af648de8e9672599e573d9d2  tests/testthat/test-lps-nested-grouped-cv.R
```

The daemon launcher `scripts/ci/_e110_daemon_launch.py` is operational-only. It runs:

```text
LPS_E110_ACCEPT=1 Rscript validation/e1_10_nested_grouped_cv.R --mode=acceptance
```

It does not substitute parameters or bypass the validation script.

## Reproduced Numbers

### Study (a), acceptance aggregate

From `e1_10_a_optimism_cases.csv`, I recomputed:

| Quantity | Recomputed |
|---|---:|
| `mean.rel.nested` | `0.0321321135388682` |
| `se.rel.nested` | `0.00392977557371172` |
| `mean.rel.selectedmin` | `0.03227519721238836` |
| `mean.optimism.delta` | `2.533132656554048e-05` |
| `se.optimism.delta` | `2.533132656554047e-05` |
| nonzero `optimism.delta` count | `1 / 40` |

These match the verdict file to printed precision.

### Study (a), fresh seed-level reproduction

I reran replicate 1 from the recorded seeds and reproduced the committed case row:

| Field | Recomputed |
|---|---:|
| `nested.rmse` | `0.1037175963622422` |
| `selectedmin.score` | `0.1037175963622422` |
| `rmse.test` | `0.1150167308739761` |
| `rel.nested` | `0.09823905118738249` |
| `optimism.delta` | `0` |

### Study (b), rho=0.6 aggregate

From `e1_10_b_grouped_cases.csv`, I recomputed the gated rho=0.6 quantities:

| Quantity | Recomputed |
|---|---:|
| `mean.gap.primary` | `0.34415259028962575` |
| `se.gap.primary` | `0.026788353110395725` |
| `mean.rel.nested.random` | `0.5048564397384792` |
| `mean.rel.nested.cluster` | `0.16070384944885335` |
| `se.rel.nested.cluster` | `0.02082504086103796` |
| `mean.realized.icc` | `0.5867219923961001` |

Both SE guards pass the `< 0.0333` requirement. The first decision clause is strongly met (`gap > 0.10`), while the second fails (`rel.cluster = 0.1607 > 0.10`), so the rho=0.6 verdict is a genuine `FAIL`, not `INCONCLUSIVE`.

### Study (b), fresh seed-level reproduction

I reran rho=0.6 replicate 1 from the recorded seed `662001` and reproduced the committed case row:

| Field | Recomputed |
|---|---:|
| `realized.icc` | `0.4813178416981687` |
| `random.split.clusters` | `TRUE` |
| `cluster.arm.whole` | `TRUE` |
| `nested.random` | `0.1181827278076219` |
| `nested.cluster` | `0.3272772911767893` |
| `rel.nested.random` | `0.418974028417624` |
| `rel.nested.cluster` | `0.4330282095672175` |
| `gap.primary` | `-0.0140541811495935` |

The negative per-replicate gap is consistent with the handoff note that the mean, not every replicate, is gated.

## Study (b) Safeguards

For rho=0.6:

- random arm splits clusters in `40 / 40` replicates.
- cluster arm keeps whole clusters in `40 / 40` replicates.
- maximum missing predictions: `0` for both arms.
- `mean(nested.cluster - rmse.test.cluster) = +0.026224431867766`, positive in `65%` of replicates.
- `mean(nested.random - rmse.test.random) = -0.12971576516114328`.
- `gap.primary` ranges from `-0.064090623034109` to `0.573391340341795`.

These numbers support the stated mechanism: random folds underestimate fresh-cluster error, while grouped 5-fold removes dependence leakage but overestimates fresh-cluster performance because each fold trains on only 32 of 40 clusters. I do not re-spec the rule here; under the current rule, the result is correctly recorded as `FAIL`.

## Mutation Qualification

All mutations were transient and restored.

| Target | Mutation | Result |
|---|---|---|
| Study (a) no leakage | In `lps.nested.cv()`, changed the outer-loop training index from `which(outer.foldid != label)` to `seq_len(n)`, leaking the outer test rows into the inner fit. | Non-vacuous. On smoke, `mean.optimism.delta` changed from `+0.010457` to `-0.062981`, violating the optimism-sign clause. `mean.rel.nested` increased from `0.140420` to `0.231419`; the relative-error direction differs from the addendum's expected wording on this smoke fixture, but the STUDY decision logic goes red through the sign clause. |
| Study (b) cluster integrity | In `lps.grouped.foldid()`, returned row-wise cyclic folds instead of cluster-wise folds. | Red. On smoke, `all.cluster.arm.whole` became `FALSE`, `mean.gap.primary` changed from `+0.088685` to `-0.237929`, and the rho=0.6 smoke verdict became `FAIL`. |
| [P1] SE guard | Inflated Study (a)'s `se.delta` to `Inf` in the verdict logic while keeping the acceptance raw cases fixed. | Red. Real logic: `PASS`; inflated `se.delta`: `INCONCLUSIVE`. This proves the guard covers both gated means. |
| [P3] fold-count validation | Called `lps.grouped.foldid(v = 2.9)` and `lps.nested.cv(inner.folds = 2.9)`. | Red by error: both reject with "single whole number" instead of silently truncating. |

Commands used for clean checks:

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-lps-nested-grouped-cv.R", reporter="summary")'
Rscript validation/e1_10_nested_grouped_cv.R --mode=smoke --out=/tmp/geosmooth_e110_smoke_audit_20260614
```

Both completed successfully before mutations.

## DGP And Pairing Checks

`validation/e1_10_nested_grouped_cv.R` consumes `dgp.g3a` and `dgp.g5` from the `geosmooth` namespace only in acceptance mode. It refuses acceptance mode unless `LPS_E110_ACCEPT=1` is set. The inline fixtures are restricted to smoke mode and marked `acceptance.evidence=FALSE`.

`lps.nested.cv()` enforces paired discipline structurally by owning `X`, `y`, `foldid`, and `X.eval`; it rejects those names in `fit.args`, uses the supplied outer fold ID for the selected-min arm, and records inner/outer fold telemetry.

## Handoff Honesty

The implementer handoff accurately describes:

- the previous failure as incomplete/uncommitted evidence rather than a source defect;
- the new complete committed acceptance bundle;
- the source files remaining unchanged;
- Study (a)'s near-degenerate optimism contrast;
- Study (b)'s rho=0.6 `FAIL` as a negative STUDY result with passing SE guards;
- the daemon launcher as operational-only.

The only nuance I would keep explicit in orchestration notes is provenance wording: current audit tip is `8e432ea`, acceptance bundle commit is `de0f861`, and the acceptance manifest's run-time source commit is `79b94bf`.

## Residual Caveats

1. Study (a)'s written PASS is accepted, but the optimism contrast is nearly content-free on `dgp.g3a` (`1 / 40` nonzero deltas, Wilcoxon p = 0.5). Future study design should include a configuration with genuine selection instability if the scientific claim needs more than a plumbing check.
2. Study (b)'s rho=0.6 result is a real `FAIL` under the current rule. Whether the second clause should be re-specified for K-fold grouped CV at `K=40` is an orchestrator decision for the planned Study b-prime, not something I change in this audit.
