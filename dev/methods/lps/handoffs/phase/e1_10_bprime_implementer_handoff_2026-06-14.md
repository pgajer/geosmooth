# E1.10 Study b' implementer handoff — grouped-CV relative criterion + LOCO

Date: 2026-06-14
Author: implementer agent (E1.10)
Work order: `project_briefs/lps_e1_10_bprime_adjudication_workorder_2026-06-14.md`
Prior: Study (b) ρ=0.6 FAIL adjudicated genuine (re-audit
`audits/e1_10_partB_reaudit_2026-06-14.md`); b' is the additive, non-blocking
follow-up.
Branch/worktree: `codex/geosmooth-e1-9-bandwidth-multiplier` / `geosmooth-e19`
Bundle commit: `92707c0`; run-recorded source commit: `2474de0`.

## 1. Scope and the no-source-change guarantee

b' adds **one new sibling validation script**
(`validation/e1_10_grouped_loco_bprime.R`) and consumes only the existing
exported utilities: LOCO is `lps.grouped.foldid(cluster.id, v = n_clusters)`
fed to `lps.nested.cv`, and the relative criterion is a verdict computation.
**No package source changed**, and the ratified Study-(b) script is untouched.
The committed `reports/e1_10_bprime/MANIFEST.txt` verifies all four
Part-B-audited files hash-match the audit record:
`R/lps.R 588762790b…`, `R/lps_cv_utils.R db1e6fdb3a…`,
`validation/e1_10_nested_grouped_cv.R 98c0a3f7ea…`,
`tests/testthat/test-lps-nested-grouped-cv.R 8bd66a2ff8…`. I did **not** merge
`main` (reconciliation is the separate later step). The acceptance run was
daemonized (`scripts/ci/_daemon_run.py`, the general detached launcher) so the
~2 h run survived turn boundaries; the study script is run verbatim with
`LPS_E110_ACCEPT=1`.

## 2. Design (predeclared; ratified parameters)

Registry `dgp.g5`, K=40 train clusters, m=20, ρ∈{0.3,0.6}; fresh test
K_test=100×m=20 (n_test=2000), disjoint from training; R=40. Primary statistic
= the nested estimate under each folding. Fresh seeds (base 70000, distinct
from Study (a)/(b) 61000/62000). Three folding arms share each replicate's
train/test draw, differing only in fold construction:

| Arm | Folding | Train/fold |
|---|---|---|
| random | random 5-fold + round-robin inner | splits clusters |
| groupedA | grouped 5-fold + grouped inner | 32/40 clusters |
| loco | leave-one-cluster-out (v=40) + grouped inner | 39/40 clusters |

Decision rules at ρ=0.6 (gated; ρ=0.3 reported-only), both gated means
requiring SE < 0.10/3 else INCONCLUSIVE:
- **Primary (relative-improvement):** mean(gap) > 0.10 AND
  mean(rel.groupedA) ≤ (1−f)·mean(rel.random), f = 0.50.
- **Confirmatory (LOCO absolute):** mean(rel.loco) < 0.10.
- **Arm C (diagnostic, non-gated):** grouped 5-fold at K∈{40,80,160}, ρ=0.6,
  reduced R_C=10 (predeclared; monotone-trend diagnostic of the bias vs
  cluster count).

## 3. Verdicts (recorded faithfully; STUDY decision rules, §A1)

### ρ=0.6 (gated): PRIMARY = INCONCLUSIVE, LOCO confirmatory = FAIL

| quantity | value |
|---|---|
| mean.rel.random | 0.530 |
| mean.rel.groupedA (se) | 0.288 (0.0543) |
| mean.rel.loco (se) | 0.159 (0.0211) |
| mean.gap.primary (se) | 0.242 (0.0503) |
| closure.fraction | 0.456 |
| mean.realized.icc | 0.591 |

- **PRIMARY = INCONCLUSIVE.** gap = 0.242 (> 0.10 ✓), but
  se.rel.groupedA = 0.0543 exceeds the 0.0333 SE guard, so the relative
  criterion cannot be evaluated on the mean. Cause: the grouped-5fold arm is
  heavy-tailed — its **median rel.groupedA = 0.193 is consistent with Study
  (b)'s mean 0.161**, but ~5 of 40 replicates have rel > 0.5 (max 1.67, from a
  single 8-cluster held-out block with extreme random effects), inflating the
  mean to 0.288 and the SE past the guard. closure on the (noisy) mean = 0.46
  (< 0.50); closure on medians = 1 − 0.193/0.517 = 0.63.
- **LOCO confirmatory = FAIL (genuine; se 0.0211 < guard).**
  mean.rel.loco = 0.159 > 0.10. Per the work order this is the **escalation
  case**: the absolute "within 0.10" bound is not met even at minimal
  train-size reduction (39/40 clusters).

### ρ=0.3 (reported-only)
gap = 0.173, closure = 0.40, rel.random = 0.433, rel.groupedA = 0.260,
rel.loco = 0.175, realized.icc = 0.315.

### Arm C (diagnostic, non-gated), ρ=0.6, grouped 5-fold, R_C=10
| K | mean.rel.cluster (se) | realized.icc |
|---|---|---|
| 40 | 0.121 (0.030) | 0.605 |
| 80 | 0.126 (0.033) | 0.593 |
| 160 | 0.051 (0.013) | 0.590 |

## 4. What the run establishes (facts, not adjudication)

These are the quantities behind the verdicts; the orchestrator decides their
implication for the E1.10 record.

1. **Random K-fold is optimistic, unanimously.** mean(nested.random − test) =
   −0.152 at ρ=0.6 and −0.090 at ρ=0.3, negative in **40/40** replicates at
   both ρ. (Claim (b) first clause.)
2. **The train-size bias is real and is removed by LOCO.** Signed bias
   mean(nested − test): groupedA (32/40 clusters) = **+0.039** (positive in
   72%); LOCO (39/40 clusters) = **−0.015** (positive in 50% → essentially
   unbiased). Increasing the per-fold cluster count from 32 to 39 removes the
   systematic overestimate — the mechanism the adjudication named.
3. **The K=40 absolute miss is driven by variance, not residual bias.** LOCO
   is near-unbiased yet mean|rel| = 0.159 because the per-replicate spread
   (sd 0.133, median 0.120) keeps the mean absolute deviation above 0.10 at
   K=40 clusters.
4. **Arm C: the absolute bound becomes attainable as cluster count grows.**
   grouped-5fold mean.rel.cluster falls to **0.051 < 0.10 at K=160** (from
   ~0.12 at K=40/80). Since 5-fold's train *fraction* is constant (4/5) across
   K, the drop reflects more clusters → lower CV-estimate variance and a
   better-generalizing fit, not a train-fraction change.
5. **Folding-scheme ordering holds.** Per replicate at ρ=0.6,
   rel.groupedA ≤ rel.random in 88%; on means and medians,
   loco < groupedA < random.
6. **Safeguards.** random arm split clusters in 40/40; groupedA and loco kept
   whole clusters in 40/40; LOCO used 40 outer folds; 0 missing predictions in
   any arm at either ρ; train/test clusters disjoint by construction.

## 5. Bundle and commands

Committed bundle `reports/e1_10_bprime/` (commit `92707c0`):
`e1_10_bprime_core_cases.csv`, `e1_10_bprime_core_verdict.csv`,
`e1_10_bprime_armc_cases.csv`, `e1_10_bprime_armc_summary.csv`,
`e1_10_bprime_run_metadata.txt`, `MANIFEST.txt` (git_head, tracked-source
status, frozen-source verification, gate battery, run metadata, verdicts, arm C
summary), `source_checksums.txt`, `sessionInfo.txt`, `gate_battery_summary.txt`,
`realized_rho_per_replicate.csv`. Built reproducibly by
`scripts/ci/e1_10_bprime_manifest.sh` (committed).

Gate-battery regression evidence (clean committed tree, `git_head 92707c0`,
`tree_clean: true`): `dev/methods/lps/audit_artifacts/e1_10_20260614T193921Z/` (in-worktree,
gitignored per convention) — `tests=31 failed=0 error=0 warning=0 skipped=1`,
gate contexts `E0.1–E0.8; E1.9/a/b; E1.10A1–A3`.

```sh
# acceptance run (daemonized)
LPS_E110_ACCEPT=1 python3 scripts/ci/_daemon_run.py /tmp/e110_bprime_run.log \
  Rscript validation/e1_10_grouped_loco_bprime.R --mode=acceptance
# bundle manifest + gate battery
bash scripts/ci/e1_10_bprime_manifest.sh
EXECUTOR=... bash scripts/ci/run_e1_10_execution_artifact.sh
# smoke (pipeline check, inline fixture)
Rscript validation/e1_10_grouped_loco_bprime.R --mode=smoke
```
`git status --short` is empty except the auditor's own untracked report.

## 6. Source / test declarations

- Package R source modified: **no** (frozen files hash-verified unchanged).
- New files: `validation/e1_10_grouped_loco_bprime.R`,
  `scripts/ci/_daemon_run.py`, `scripts/ci/e1_10_bprime_manifest.sh`,
  `reports/e1_10_bprime/`, `reports/e1_10_bprime_smoke/`, this handoff, and the
  banked `audits/e1_10_partB_reaudit_2026-06-14.md`.
- Tests run: E1.9+E1.10 gate battery (15/15) in the manifest builder; the
  31-test E1.9+E1.10+Tier-0 battery via the harness on the clean committed
  tree. Mutations: **none run by me** (the auditor owns them).

## 7. Limitations and unverified claims

1. **The primary relative criterion did not return a clean PASS.** It is
   INCONCLUSIVE because grouped-5fold's mean is destabilized by ~5 heavy-tail
   replicates. The supplementary median/closure (0.193 / 0.63) and the
   88% per-replicate ordering support the folding scheme, but those are
   **non-gated context**; I did not substitute a robust statistic for the
   predeclared mean rule, and I did not change f, seeds, sizes, or the rule. A
   genuinely clean relative-criterion PASS may require a higher-K or
   higher-R design (lower grouped-5fold variance) — that is a design question
   for the orchestrator, not a change I made.
2. **The LOCO FAIL is the escalation the work order anticipated**, surfaced
   here as a fact: at K=40 the absolute 0.10 bound is unmet even by
   near-unbiased LOCO. I do not assert the bound "should" change — I report
   that it is unattainable in this regime (and, per arm C, attainable by
   K=160). The orchestrator adjudicates the bound.
3. **Seed-set sensitivity of the grouped-5fold mean.** Study (b) (seed base
   62000) gave rel.cluster mean 0.161; b' (seed base 70000) gives 0.288 for
   the same scheme — the difference is entirely in the heavy tail (medians
   0.161 vs 0.193 agree). The grouped-5fold mean is high-variance at K=40, so
   point means are seed-set-sensitive; the verdict is deterministic only for
   the predeclared b' seeds.
4. **Arm C is R_C=10 (reduced).** The K=40→80 step is flat within SE
   (0.121→0.126); only the K=160 drop (0.051) is clearly separated. The trend
   "bias/variance shrinks with K" rests mainly on the K=160 point; a larger
   R_C would tighten the K=40/80 comparison. Arm C is diagnostic, non-gated.
5. **Single machine / BLAS** (macOS arm64, R 4.5.2, Apple Accelerate);
   cross-platform reproduction not attempted. Determinism rests on the fixed
   seeds, not the daemon launch; I did not re-run to confirm bit-identical
   reproduction of the ~2 h run.
6. **realized ρ vs nominal:** mean realized ICC 0.591 (ρ=0.6) and 0.315
   (ρ=0.3); per-replicate values in `realized_rho_per_replicate.csv`. Gating
   uses nominal ρ; realized ρ is reported, not conditioned on.
7. **The b' script is not mutation-qualified by me.** The auditor's planned
   mutations (breaking LOCO's whole-cluster property must redden the LOCO
   clause; faking the relative improvement must redden the primary clause)
   were not run as acceptance evidence.
