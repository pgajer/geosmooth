# E1.10 implementer handoff — nested + grouped CV (Part A; Part B harness)

Date: 2026-06-11
Author: implementer agent (E1.10)
Contract: `project_briefs/lps_tiers1to4_contract_2026-06-11.md` §B / E1.10, §A1–A6
Plan: `project_briefs/lps_experimental_plan_2026-06-09.tex` §E1.10, §sec:paired
Spec memo (pre-implementation): `audit_contracts/lps_tiers1to4/e1_10_spec_questions_implementer_2026-06-11.md`
Base: branch `codex/geosmooth-e1-9-bandwidth-multiplier`, worktree
`/Users/pgajer/current_projects/geosmooth-e19`, on top of the accepted E1.9
verdict (`d231bb1`).

## 1. Scope delivered

**Part A (delivered):** nested-CV and grouped-foldid machinery plus the three
deterministic GATEs (no selection leakage; cluster integrity; paired
discipline) on inline fixtures. **Part B (harness delivered; acceptance not
run):** the study script with predeclared decision rules and a smoke run on
inline non-DGP fixtures. The acceptance studies were **not** run: the
registry generators `dgp.g3a` / `dgp.g5` are not present on this branch
(`inst/dgp_registry/` does not exist here), and the assignment gates the
acceptance run on the orchestrator's confirmation of the DGP-library audit.
No G3a/G5 logic was hand-rolled. The E1.10(a)/(b) verdicts therefore do not
exist yet; nothing here evidences the optimism or cluster-leakage claims on
the plan DGPs.

## 2. Commits (this assignment, oldest first)

| Commit | Content |
|---|---|
| `3e72eee` | E1.10 spec memo (9 items: package-API counter-proposal, structural pairing, inner-fold rules, study (b) primary statistic, K_test, realized-ρ, smoke/registry boundary, STUDY typing, GATE designs). |
| `799c31a` | `R/lps_cv_utils.R` (+ regenerated `NAMESPACE`): `lps.grouped.foldid`, `lps.nested.cv`. |
| `164f913` | `tests/testthat/test-lps-nested-grouped-cv.R` (7 tests, E1.10A1–A3). |
| `7c824c0` | `validation/e1_10_nested_grouped_cv.R` + committed smoke outputs `reports/e1_10_smoke/`. |
| `36e7806` | `scripts/ci/run_e1_10_execution_artifact.sh` + `scripts/ci/e1_10_realized_quantities_probe.R`. Bundle generated at this head. |

## 3. What the machinery does (facts)

- `lps.grouped.foldid(cluster.id, v, shuffle.seed = NULL)`: whole-cluster
  folds by deterministic size-balanced greedy assignment (largest cluster
  first, smallest fold first, deterministic tie-breaks); optional seeded
  cluster-order shuffle; `v = #clusters` is leave-cluster-out; errors when
  `v` exceeds the cluster count or labels contain NA.
- `lps.nested.cv(X, y, outer.foldid, fit.args, inner.folds, cluster.id,
  inner.foldid.method, inner.shuffle.seed)`: per outer fold, one ordinary
  `fit.lps` call on the inner-training rows with an explicit inner foldid
  and `X.eval` = the held-out rows; pooled outer-test RMSE is the nested
  estimate; the **same call** computes the selected-min arm via `fit.lps` on
  all rows with the **same** `outer.foldid` (pairing by construction);
  `fit.args` containing `X`/`y`/`foldid`/`X.eval` is an error; gaussian
  outcome family only; complete telemetry returned (per-fold index sets,
  constructed and `fit.lps`-recorded inner foldids, full inner CV tables,
  `outer.cluster.whole` flag).
- Existing code paths untouched: `fit.lps` and its signature unchanged; the
  machinery consumes the public API only. `NAMESPACE` gained exactly the two
  new exports.

## 4. Exact commands run (worktree)

```sh
Rscript -e 'roxygen2::roxygenise(".")'        # NAMESPACE +2 exports; man/ untracked
Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-lps-nested-grouped-cv.R")'
Rscript validation/e1_10_nested_grouped_cv.R --mode=smoke
Rscript validation/e1_10_nested_grouped_cv.R --mode=acceptance            # refusal check 1
LPS_E110_ACCEPT=1 Rscript validation/e1_10_nested_grouped_cv.R --mode=acceptance  # refusal check 2
Rscript -e 'pkgload::load_all("."); testthat::test_dir("tests/testthat", stop_on_failure = FALSE)'
EXECUTOR="implementer-agent-e110-worktree" bash scripts/ci/run_e1_10_execution_artifact.sh
```

## 5. Artifacts

- Execution bundle `audit_artifacts/e1_10_20260611T211913Z/` (worktree;
  `audit_artifacts/` is gitignored): `git_head 36e7806`, `tree_clean true`,
  `testthat_rc 0`, `probe_rc 0`, gate contexts
  `E0.1–E0.8; E1.9; E1.9a; E1.9b; E1.10A1; E1.10A2; E1.10A3`; per-test CSV,
  probe CSVs (`e110_leakage_invariance.csv`, `e110_grouped_balance.csv`,
  `e110_paired_telemetry.csv`, `e110_probe_summary.csv`), fixture
  provenance, smoke-output binding note, sessionInfo, BLAS id, source and
  bundle checksums.
- Smoke study outputs (committed): `reports/e1_10_smoke/` — per-replicate
  case tables, verdict rows, run metadata. Both smoke verdicts are
  `INCONCLUSIVE` by the predeclared SE guard (R = 2), and their rows carry
  `acceptance.evidence = FALSE`.

## 6. Numerical findings

- **Gate battery (bundle):** 31 tests, 0 failed, 0 errors, 0 warnings,
  1 skipped (the sanctioned E0.3a deferral). E1.9 and Tier-0 batteries green
  on top of the new machinery.
- **Leakage invariance (probe, realized):** shifting the held-out fold's `y`
  by +7 produced max |Δ inner CV score| = 0, identical selections, and max
  |Δ held-out prediction| = 0 for every outer fold (4/4).
- **Grouped folds (probe, realized):** fixture of 12 clusters (sizes 1–8,
  n = 44) at v = 4 gives fold sizes 11;11;11;11, whole-cluster TRUE,
  deterministic TRUE; leave-cluster-out yields 12 folds.
- **Paired telemetry (probe):** selected-min arm foldid, underlying
  `fit.lps$foldid`, and all constructed-vs-used inner foldids identical.
- **Smoke pipeline signals (inline fixtures — pipeline evidence only):**
  study (a) mean rel. error nested 0.140 vs selected-min 0.087, optimism
  delta +0.0105 (positive sign as theory predicts); study (b) at nominal
  ρ = 0.6: realized ICC 0.600, random-vs-cluster gap +0.089 (positive),
  random arm split clusters, cluster arm whole. Both INCONCLUSIVE per the
  SE guard at R = 2, by design.
- **Full suite parity:** 21 files, 227 tests, failed = 4, warnings = 66,
  skipped = 1 — the identical 4 pre-existing `test-ge7-lps-api.R` failures
  and 66 `test-graph-trend-filtering.R` warnings documented (with pre/post
  baselines) in the E1.9 handoff; nothing new.

## 7. Source / test execution declarations

- Package R source modified: **yes** — one new file `R/lps_cv_utils.R` and
  the roxygen-regenerated `NAMESPACE` (+2 exports). `R/lps.R` and all other
  existing source files: **unchanged** (verifiable via the bundle's source
  checksums against the E1.9 bundle). C++: untouched.
- Package tests run: **yes** — new gate file, five-file bundle battery on a
  clean committed tree, full suite.

## 8. Limitations and unverified claims

1. **The E1.10 studies have no verdicts.** Part B acceptance was not run
   (registry absent on this branch + orchestrator gate). The smoke outputs
   exercise the pipeline only; their fixtures are deliberately not the plan
   DGPs, and their INCONCLUSIVE rows must not be read as study evidence.
2. **The registry adapter is written against an assumed interface.** The
   shim in `validation/e1_10_nested_grouped_cv.R` guesses
   `dgp.g3a(n, sigma, seed)` / `dgp.g5(K, m, rho, seed)` and the
   Amendment-1 standard-object field names (with fallbacks for the cluster
   label field). The audited registry's actual signatures are not visible on
   this branch; the shim may need rebinding when it merges, and any
   mismatch is currently a runtime error, not a tested path.
3. **σ = 0.1 for study (a) and K_test = 100 for study (b) are implementer
   predeclarations** (the spec pins G3a/G5 but not these); flagged in the
   spec memo (§5) and the script header. The orchestrator has not yet ruled
   on memo items 1, 4, 5, 8 (API surface, primary statistic, K_test,
   typing); I implemented my proposals — if any is rejected, the affected
   piece must be revised before the acceptance run.
4. **No mutation qualification was run by me** (auditor's job per §A5): the
   named mutations — leaking the outer-test fold into inner selection;
   splitting a cluster across folds — were not executed as acceptance
   evidence.
5. **The leakage GATE covers the implemented plumbing, not all conceivable
   leaks.** It proves inner selection and held-out predictions are invariant
   to the held-out fold's `y` (and selection invariant to its `X`), per
   fold. It does not (and cannot) certify the absence of leakage in future
   callers that bypass `lps.nested.cv`'s plumbing, nor in `fit.lps`
   internals beyond what Tier-0/E1.9 pin.
6. **Machinery is gaussian-only and RMSE-pooled.** Binomial/bernoulli
   outcome families are rejected; if E1.10 studies are later wanted on
   binary responses, the machinery needs a scoring extension.
7. **Nested estimate with `unstable.action = "na"`:** non-finite outer-test
   predictions are excluded from the pooled RMSE and counted in
   `n.missing.predictions` (zero in every run here). A high missing count
   would bias the nested estimate; no guard beyond reporting exists.
8. **Grouped-fold balance is greedy, not optimal**: size balancing is
   heuristic (largest-first/smallest-fold); pathological cluster-size
   distributions can produce uneven folds (e.g. one giant cluster). The
   probe records realized fold sizes; the studies' G5 (equal m) is
   unaffected.
9. **Smoke runtime, not acceptance runtime, was measured implicitly.** No
   timing of the full acceptance sizes (R = 40, n = 800/4000, two arms ×
   two ρ) exists; the acceptance run's wall-clock cost is unknown.
10. **Concurrent-session context:** other program work proceeds in sibling
    worktrees/branches (Tier-2, Tier-4, DGP library). This branch was not
    rebased onto any of them; the E0.6-patch duplication and scaffolding
    duplicates noted in the E1.9 handoff (§8.8) remain unreconciled.
