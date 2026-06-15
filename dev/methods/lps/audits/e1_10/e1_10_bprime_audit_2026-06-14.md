# E1.10 Study b-prime audit -- grouped-CV relative criterion and LOCO

Date: 2026-06-14

Auditor: Codex, independent audit role

Worktree: `/Users/pgajer/current_projects/geosmooth-e19`

Current audit tip: `bc733df61c0b6394276e70ecc6cd7e4351dc3c59`

Study script commit: `2474de036e6cd464dc9b3121a561dd0ee44f2c0b`

Acceptance bundle commit: `92707c0647e29536f8092d3ad4c60f7e91ba7bf1`

## Verdict

**Accept the b-prime evidence bundle as provenance-valid and internally consistent.**

The scientific outcome is not a clean positive result:

- Primary relative-improvement criterion at rho=0.6: **INCONCLUSIVE** because the SE guards fail.
- LOCO confirmatory criterion at rho=0.6: **FAIL**, genuine and correctly implemented.
- Arm C is diagnostic only; it suggests the absolute bound becomes attainable by K=160, but R_C=10 and the K=40 to K=80 step is flat within SE.

This audit therefore accepts the b-prime record as a valid STUDY artifact, not as a PASS for the relative/LOCO claims.

## Provenance And Bundle Validity

The committed b-prime bundle is complete and tracked under `reports/e1_10_bprime/`:

- `e1_10_bprime_core_cases.csv`
- `e1_10_bprime_core_verdict.csv`
- `e1_10_bprime_armc_cases.csv`
- `e1_10_bprime_armc_summary.csv`
- `e1_10_bprime_run_metadata.txt`
- `MANIFEST.txt`
- `source_checksums.txt`
- `sessionInfo.txt`
- `gate_battery_summary.txt`
- `realized_rho_per_replicate.csv`

The gate-battery bundle `dev/methods/lps/audit_artifacts/e1_10_20260614T193921Z/` records:

- `git_head: 92707c0647e29536f8092d3ad4c60f7e91ba7bf1`
- `tree_clean: true`
- `tests=31 failed=0 error=0 warning=0 skipped=1`

Current `bc733df` adds only the b-prime handoff on top of the bundle.

## Source-Clean Check

No package source changed. The Part-B-audited files remain hash-identical:

```text
588762790b651091717fedc5c424b6dd78ae348ac0bd70a5af1691c68c4ff2ee  R/lps.R
db1e6fdb3ab4befd25a126d4e9884dbd5c34ca9c3d1212eb6a3f4e35a1ee0a0a  R/lps_cv_utils.R
98c0a3f7ea764549097704d0ce4b273f1d35c4f1d34c0862b494cf51cdf1d1f3  validation/e1_10_nested_grouped_cv.R
8bd66a2ff8cfb7f4f39b356127b3918bf41b7da9af648de8e9672599e573d9d2  tests/testthat/test-lps-nested-grouped-cv.R
```

The new script `validation/e1_10_grouped_loco_bprime.R` consumes `dgp.g5` from the `geosmooth` namespace in acceptance mode, refuses acceptance mode without `LPS_E110_ACCEPT=1`, and leaves the ratified Study (b) script untouched.

The general daemon wrapper runs the requested command verbatim and only detaches the process:

```sh
LPS_E110_ACCEPT=1 python3 scripts/ci/_daemon_run.py /tmp/e110_bprime_run.log \
  Rscript validation/e1_10_grouped_loco_bprime.R --mode=acceptance
```

## Recomputed Results

From `reports/e1_10_bprime/e1_10_bprime_core_cases.csv`, for rho=0.6:

| Quantity | Recomputed |
|---|---:|
| `mean.rel.random` | `0.5300577946563759` |
| `se.rel.random` | `0.012017130969176797` |
| `mean.rel.groupedA` | `0.2880969446284359` |
| `se.rel.groupedA` | `0.0543147465826249` |
| `mean.rel.loco` | `0.15850191654520693` |
| `se.rel.loco` | `0.021107170799635547` |
| `mean.gap.primary` | `0.24196085002794013` |
| `se.gap.primary` | `0.05034438311890292` |
| `closure.fraction` | `0.456480128143003` |
| `mean.realized.icc` | `0.5907589411808081` |

Interpretation under the predeclared rho=0.6 rules:

- The primary point estimates do not meet the 50% closure rule (`0.456 < 0.50`) and, independently, both primary SE guards fail (`se.gap = 0.0503`, `se.groupedA = 0.0543`, both above `0.0333`). The recorded `INCONCLUSIVE` primary verdict is correct.
- LOCO has acceptable SE (`0.0211 < 0.0333`) but misses the absolute threshold (`0.1585 > 0.10`). The recorded `FAIL` is correct.

From `reports/e1_10_bprime/e1_10_bprime_armc_cases.csv`, I recomputed:

| K | mean.rel.cluster | se.rel.cluster | mean.realized.icc | R_C |
|---:|---:|---:|---:|---:|
| 40 | `0.12138434532113988` | `0.030103145165917798` | `0.6049833333904129` | 10 |
| 80 | `0.12644734352651954` | `0.032683561343140335` | `0.5928114953428338` | 10 |
| 160 | `0.051127076970701776` | `0.012717937131314853` | `0.590159386903683` | 10 |

Arm C supports a drop by K=160, but the K=40 and K=80 means are essentially tied within SE. It should remain diagnostic, not promoted to a gated trend claim.

## Safeguards

For rho=0.6 core cases:

- random arm splits clusters in all replicates.
- groupedA keeps whole clusters in all replicates.
- LOCO keeps whole clusters in all replicates.
- LOCO uses 40 outer folds.
- maximum missing predictions are zero for random, groupedA, and LOCO.
- signed biases: random `-0.15222009257541907`, groupedA `+0.039026936866673294`, LOCO `-0.014841359173484748`.
- groupedA signed bias is positive in 72.5% of replicates; LOCO signed bias is positive in 50%.

These support the implementer's mechanism statement: grouped 5-fold has a train-size/cluster-count bias, while LOCO largely removes systematic bias but still has enough variance at K=40 that the absolute 0.10 threshold fails.

## Mutation / Falsification Checks

All mutations were transient and restored.

| Target | Mutation | Result |
|---|---|---|
| LOCO / grouped whole-cluster dependence | In `lps.grouped.foldid()`, returned row-wise cyclic folds instead of cluster-wise folds, then ran b-prime smoke. | Red signal. At rho=0.6, `all.groupedA.whole` and `all.loco.whole` became `FALSE`; `mean.gap.primary` moved from `+0.165941` to `-0.159975`; `closure.fraction` moved from `+0.313008` to `-0.301755`. |
| Primary relative-improvement verdict logic | On the acceptance raw cases, faked no improvement by setting `rel.groupedA = rel.random` and `gap.primary = 0`. | Red. The primary verdict logic changed from the real `INCONCLUSIVE` to `FAIL` once the no-improvement mutation made the SE guard pass and the effect clause fail. |
| LOCO confirmatory verdict logic | On the acceptance raw cases, forced `rel.loco = 0.05` and `rel.loco = 0.20`. | Verdict toggled as expected: real `FAIL`, forced-good `PASS`, forced-bad `FAIL`. |

Because the real primary verdict is already `INCONCLUSIVE`, it cannot be mutation-qualified as a passing gate. The relevant audit point is that the verdict logic can fail under a no-improvement mutation and that the source-level whole-cluster property feeds the reported arms.

## Live Checks Run

```sh
Rscript validation/e1_10_grouped_loco_bprime.R --mode=smoke --out=/tmp/geosmooth_e110_bprime_smoke_audit_20260614
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-lps-nested-grouped-cv.R", reporter="summary")'
```

Both completed successfully. Final `git status --short` after restoring mutations showed only this untracked audit report.

## Handoff Honesty

The handoff accurately reports:

- no package-source changes;
- b-prime as additive and non-blocking;
- the new script and committed bundle;
- primary rho=0.6 as `INCONCLUSIVE`, not PASS;
- LOCO confirmatory as `FAIL`;
- Arm C as diagnostic and non-gated;
- the unrun mutation responsibility as belonging to the auditor.

The only caveat I would preserve in orchestration notes: b-prime explains the Study (b) failure mechanism better, but it does not produce a clean PASS for either the primary relative criterion or the LOCO absolute criterion at K=40.
