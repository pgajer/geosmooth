# E1.10 Part B implementer handoff — acceptance studies (re-run)

Date: 2026-06-14
Author: implementer agent (E1.10)
Work order: `project_briefs/lps_e1_10_partB_rerun_work_order_2026-06-14.md`
(supersedes the run/deliver steps of `lps_e1_10_partB_work_order_2026-06-12.md`)
Prior audit: `audits/e1_10_partB_audit_2026-06-14.md` (Reject — incomplete bundle)
Branch/worktree: `codex/geosmooth-e1-9-bandwidth-multiplier` / `geosmooth-e19`
Bundle commit: `de0f861`; source-certifying parent: `79b94bf`

## 1. What was wrong, and what this delivers

The prior submission was rejected only for an **incomplete, uncommitted
bundle**: my background acceptance job was killed before Study (b) ran, so
`reports/e1_10_acceptance/` held Study (a) only, untracked, with no manifest.
Source and Study (a) numbers were accepted; [P3] accepted; [P1] confirmed
present but un-mutation-qualified because the bundle was invalid.

This delivers the completed re-run: **both studies, committed and tracked**,
with a manifest binding the run to the audited source. **No source changed** —
the four audited files hash-match the audit record (verified in
`reports/e1_10_acceptance/MANIFEST.txt` and below). I did **not** merge current
`main` (per the scope guard); the DGP library was already present from the
earlier dgp-only merge `88b39d2`.

## 2. Root cause of the prior incompleteness, and the fix

Not a code or science defect: Study (a) always completed and smoke mode runs
the Study (b) grouped path end-to-end. The `Rscript` was a direct child of a
harness-managed background task, which was reaped at a turn boundary (the
first kill coincided with a `/model` switch; the second when the turn idled
awaiting completion). The full run is ~33 min, longer than a turn.

Fix (operational only): `scripts/ci/_e110_daemon_launch.py` double-forks into a
new session (`setsid`) so the `Rscript` is detached from the controlling
terminal and the harness task tree; the study script is run verbatim with the
ratified parameters and `LPS_E110_ACCEPT=1`. The run then completed
(`EXIT_RC=0`, all five outputs + sentinel written). The study source
(`validation/e1_10_nested_grouped_cv.R`) was not touched.

## 3. Step 1 — clean audited tree (done)

- Removed the partial untracked `reports/e1_10_acceptance/` (Study (a)
  leftovers).
- Banked the audit verdict: `79b94bf` "Add E1.10 Part B audit verdict".
- Verified the source under test equals the audited source (audit Bundle
  Validity hashes), all four matching:
  - `R/lps.R` `588762790b…`
  - `R/lps_cv_utils.R` `db1e6fdb3a…`
  - `validation/e1_10_nested_grouped_cv.R` `98c0a3f7ea…`
  - `tests/testthat/test-lps-nested-grouped-cv.R` `8bd66a2ff8…`
- `git status --short` empty after step 1–2.
- Full `testthat` suite: E1.9 + E1.10 gates green (15/15). The 4 failing
  `test-ge7-lps-api.R` tests and 66 `test-graph-trend-filtering.R` warnings
  are the documented machine-local pre-existing issues (unchanged from base
  `b86b796`; see the E1.9/E1.10 handoffs), not in any E1.x gate.

## 4. Step 2 — both studies run to completion (ratified parameters)

Generated with `LPS_E110_ACCEPT=1`, registry generators `dgp.g3a` / `dgp.g5`,
R 4.5.2, Apple Accelerate BLAS. Seeds: Study (a) seed0 = 61000; Study (b)
seed0 = 62000 (per-replicate seeds in the cases CSVs; realized ρ per replicate
in `realized_rho_per_replicate.csv`).

### Study (a) — optimism, `dgp.g3a`, n=800 train + 4000 test, R=40, σ=0.10 → **PASS**
- mean.rel.nested = **0.03213** (< 0.10 ✓), se.rel.nested = 0.00393 (< 0.0333 ✓)
- mean.optimism.delta = **+2.53e-05** (≥ 0 ✓), se.optimism.delta = 2.53e-05
  (< 0.0333 ✓) → both [P1] SE guards satisfied
- mean.rel.selectedmin = 0.03228; Wilcoxon (one-sided, delta>0) p = 0.5
- 0 missing predictions across all 40 replicates.
- **Non-vacuity figure (requested):** only **1 of 40** `optimism.delta` values
  is nonzero (range [0, 1.01e-3]). On `dgp.g3a`, nested and selected-min select
  the same configuration in 39/40 replicates, so the intrinsic optimism is
  ≈ 0; nested correctly adds no *spurious* optimism. I flag this so the
  re-audit can judge whether the leakage mutation is non-vacuous on this DGP
  (the optimism-delta contrast is near-degenerate here; the leak's effect may
  be more visible in `rel.nested` than in `optimism.delta`). I have **not**
  changed the generator or the rule.

### Study (b) — grouped CV, `dgp.g5`, K=40, m=20, K_test=100 (n_test=2000), R=40 → ρ=0.6 **FAIL**, ρ=0.3 reported-only
Primary statistic: the **nested** estimate under each folding (ratified).

| ρ (nominal) | gated | realized ρ (mean / median / range) | mean gap (se) | mean rel.random | mean rel.cluster (se) | verdict |
|---|---|---|---|---|---|---|
| 0.6 | yes | 0.587 / 0.595 / [0.435, 0.728] | **0.344** (0.027) | 0.505 | **0.161** (0.021) | **FAIL** |
| 0.3 | no  | 0.292 / 0.292 / [0.177, 0.429] | 0.196 (0.039) | 0.444 | 0.248 (0.031) | REPORTED-ONLY |

Decision rule (ρ=0.6, gated): `mean(gap) > 0.10` **and**
`mean(rel.cluster) < 0.10`, with both SE guards < 0.0333.

- **First condition met, strongly:** the random-vs-cluster gap is 0.344
  (≫ 0.10). Random K-fold underestimates fresh-cluster error in **40/40**
  replicates at both ρ (mean nested.random − rmse.test = −0.130 at ρ=0.6,
  −0.099 at ρ=0.3). Leave-cluster-out closes most of the gap: relative error
  0.505 → 0.161 at ρ=0.6 (a 68% reduction). Claim (b)'s first half ("random
  K-fold underestimates under cluster dependence; cluster folding closes the
  gap") is robustly supported.
- **Second condition not met → FAIL:** cluster-fold relative error is 0.161
  (> 0.10). Cluster-fold *over*estimates fresh-cluster error
  (mean nested.cluster − rmse.test = +0.026; positive in 65% of replicates).
  Mechanism: grouped 5-fold trains each fold on 32 of 40 clusters (640/800
  points), so the CV estimate reflects a model trained on 20% fewer
  clusters/data than the deployed full-train model, biasing it upward — a
  small-cluster-count / train-size effect, amplified by the large
  between-cluster variance at ICC≈0.59.
- Both SE guards pass (se.gap = 0.027, se.rel.cluster = 0.021, both < 0.0333),
  so this is a **genuine FAIL, not INCONCLUSIVE**.
- Safeguards verified: random arm split clusters in 40/40 reps; cluster arm
  whole in 40/40; train/test clusters disjoint by construction
  (`train_` vs `test_` prefixes); identical truth + noise law across arms;
  0 missing predictions in either arm.

Per contract §A1 these are **STUDY** decision rules: a negative verdict is
**recorded, not a CI failure**. The implications of the ρ=0.6 FAIL — in
particular whether the ratified "cluster-fold within 0.10 of truth" bound is
attainable at K=40 with 5-fold (vs leave-one-cluster-out or more clusters) —
are for the orchestrator/auditor to adjudicate. I have not altered the rule,
generator, sizes, or ρ grid.

## 5. Step 3 — committed acceptance bundle

`reports/e1_10_acceptance/` (tracked, commit `de0f861`):
- `e1_10_a_optimism_cases.csv`, `e1_10_a_optimism_verdict.csv`
- `e1_10_b_grouped_cases.csv`, `e1_10_b_grouped_verdict.csv`
- `e1_10_run_metadata.txt` (seeds, fit args, BLAS, git_head)
- `MANIFEST.txt` — git_head, tracked-source status, source-hash verification
  vs the audit (all four match), gate battery, run metadata, both verdicts
- `source_checksums.txt`, `sessionInfo.txt`, `gate_battery_summary.txt`
- `realized_rho_per_replicate.csv` (80 rows: rho.nominal, replicate,
  seed.base, realized.icc)

Generated reproducibly by `scripts/ci/e1_10_acceptance_manifest.sh` (committed).

Gate-battery regression evidence (clean committed tree, `git_head de0f861`,
`tree_clean: true`): `audit_artifacts/e1_10_20260614T152852Z/` (in-worktree,
gitignored per the established convention; reviewed in place as for Part A) —
`testthat tests=31 failed=0 error=0 warning=0 skipped=1`, gate contexts
`E0.1–E0.8; E1.9/a/b; E1.10A1–A3`; probe: leakage max-delta 0, grouped folds
whole, paired telemetry identical, and the acceptance binding records
`a:PASS b(rho=0.6):FAIL generator:registry acceptance_evidence:TRUE`.

`git status --short` is empty (worktree clean except this handoff and the
auditor's own untracked report).

## 6. Files changed / created this task

- Created (committed): `reports/e1_10_acceptance/` (10 files),
  `scripts/ci/_e110_daemon_launch.py`, `scripts/ci/e1_10_acceptance_manifest.sh`,
  this handoff, and the banked `audits/e1_10_partB_audit_2026-06-14.md`.
- **Not changed:** `R/lps.R`, `R/lps_cv_utils.R`,
  `validation/e1_10_nested_grouped_cv.R`,
  `tests/testthat/test-lps-nested-grouped-cv.R` (hash-verified unchanged),
  and no `main` merge.

## 7. Source / test execution declarations

- Package R source modified this task: **no** (hash-verified).
- Tests run: E1.9 + E1.10 gate files (15/15 green) inside the manifest builder;
  the 5-file E1.9+E1.10+Tier-0 battery (31/31, 1 skip) via the harness on the
  clean committed tree; the full suite at Step 1 (pre-existing ge7/graph
  issues only).
- Mutations: **none run by me** (the auditor owns the mutation table).

## 8. Limitations and unverified claims

1. **Study (b) ρ=0.6 is a FAIL**, and I did not attempt to make it pass. The
   cluster-fold's 16% overestimate is, on my reading, a train-size/cluster-
   count bias at K=40 with 5-fold; I did not test whether leave-one-cluster-out
   or a larger K would bring it within 10%, because those are not the ratified
   parameters and the work order forbids changing them. Whether the ratified
   bound is attainable here is unadjudicated.
2. **Study (a) optimism is near-degenerate** (1/40 nonzero deltas). The PASS is
   on the written rule, but the optimism *contrast* carries almost no signal on
   `dgp.g3a`; I have not verified that the leakage mutation produces measurable
   optimism on this DGP (that is the auditor's mutation, flagged here per the
   work order).
3. **Detached-run method.** I daemonized the `Rscript` (double-fork/`setsid`) to
   survive turn boundaries. The run's determinism rests on the script's fixed
   seeds, not on the launch method; I did not re-run a second time to confirm
   bit-identical reproduction of Study (b) (Study (a) reproduced its
   audit-recomputed cells exactly: mean.rel.nested 0.0321321135…). A fresh
   `Rscript validation/e1_10_nested_grouped_cv.R --mode=acceptance` with
   `LPS_E110_ACCEPT=1` should reproduce all numbers from the recorded seeds.
4. **Single machine / BLAS.** All numbers are macOS arm64, R 4.5.2, Apple
   Accelerate. Cross-platform reproduction was not attempted.
5. **realized ρ vs nominal.** Realized ICC (MoM, one-way ANOVA on y − truth)
   averages 0.587 (nominal 0.6) and 0.292 (nominal 0.3); per-replicate ranges
   are wide ([0.44, 0.73] at ρ=0.6). The decision uses nominal ρ for gating and
   reports realized ρ as required; I did not re-weight or condition on realized
   ρ.
6. **Gate-battery bundle is gitignored.** `audit_artifacts/…` follows the
   established Part A/E1.9 convention (in-worktree, reviewed in place). The
   *acceptance* evidence is the committed `reports/e1_10_acceptance/` bundle;
   if the auditor requires the gate-battery bundle tracked as well, it can be
   force-added on request.
7. **`gap.primary` is not positive in every replicate** (min −0.064 at ρ=0.6,
   −0.436 at ρ=0.3): because the per-replicate statistic is an absolute-value
   ratio, a few replicates where cluster-fold overestimates by more (in abs
   terms) than random-fold underestimates flip the per-rep gap sign. The
   gated quantity is the **mean** gap, which is strongly positive; the
   per-replicate distribution is in the committed cases CSV for the auditor.
