# E1.10 — spec ratification + Part B work order

Date: 2026-06-12. To the E1.10 implementer (worktree `geosmooth-e19`, branch
`codex/geosmooth-e1-9-bandwidth-multiplier`). Responds to the independent E1.10 audit
(`audits/e1_10_audit_2026-06-12.md`) and your spec-questions doc.

## Status

**Part A — accepted and banked.** The nested-CV plumbing, grouped-fold construction, telemetry, and
paired-discipline gates pass on a clean tree and the leakage + cluster-splitting mutations redden them.
Nothing more to do on Part A. **Part B is not yet acceptance-runnable** — three things below clear it.

## 1. Spec-questions — ratified (audit [P2])

- **Item 1 — exported `lps.grouped.foldid()` and `lps.nested.cv()` (not script-locals): RATIFIED.**
  Exported, testable utilities are the right call (script-locals break under `R CMD check`), they are
  genuinely useful public API, and they touch no existing path — `fit.lps` is unchanged, so §A2 is
  vacuous for existing entry points and the E1.9b reference GATEs remain the regression pin. Same
  pattern as E4.1's standalone functions. (This adds two `NAMESPACE` exports — see step 3.)
- **Item 4 — Study (b) primary statistic = the *nested* estimate under each folding: RATIFIED.** It
  removes the selection-optimism confound from both arms, so the random-vs-cluster contrast isolates
  the dependence-leakage axis — exactly claim (b). Keep selected-min as recorded supplementary.
- **Item 5 — Study (b) fresh test size `K_test = 100`, `m = 20` (n_test = 2000): RATIFIED.** Ample to
  keep the fresh-cluster RMSE (the shared denominator) well inside the 0.10 decision margin. Clusters
  disjoint from training, identical truth + noise law.
- **Items 2, 3, 6, 7, 8, 9 (info) — confirmed:** structural pairing, explicit recorded inner folds,
  realized-ρ via MoM ICC, the smoke-vs-registry boundary, the STUDY typing of (a)/(b) with deterministic
  Part-A GATEs, and the three Part-A gate designs are all correct as written.

## 2. Pre-acceptance fixes (audit [P1], [P3])

- **[P1] SE guard (blocker).** In `validation/e1_10_nested_grouped_cv.R`, `se.ok.a` checks only
  `se.rel.nested`. Study (a)'s rule gates on **two** means (`mean(rel_nested) < 0.10` **and**
  `mean(optimism_delta) ≥ 0`), so the guard must cover **both**: add `se.delta` to `se.ok.a`
  (`… && is.finite(se.delta) && se.delta < SE.MAX`), and emit **INCONCLUSIVE** unless both gated means
  meet the SE guard. Otherwise an acceptance run can report PASS on a too-noisy optimism sign.
- **[P3] Integer validation.** In `R/lps_cv_utils.R`, `as.integer(v)` / `as.integer(inner.folds)`
  silently truncate `2.9 → 2`. Since these are now **exported** utilities, `stop()` on non-whole or
  non-scalar fold counts instead of truncating.

## 3. Get the DGP library into this branch

The acceptance studies need the audited `dgp.g3a` / `dgp.g5`, which are **absent on this branch** (it
forked before the DGP library). They are now on **`main`** (dgp merged at `58f5ab9`). **Merge `main`
into this branch** to bring `R/dgp_library.R` + the registry. Expect one **trivial `NAMESPACE` /
`DESCRIPTION` union** — `main` adds the `dgp.*` exports, this branch adds `lps.grouped.foldid` /
`lps.nested.cv`; they're disjoint export lines. Resolve the union, then confirm the full `testthat`
suite is green (E1.9 + E1.10 gates) before running anything. Consume the audited generators only — no
hand-rolled G3a/G5.

## 4. Run Part B acceptance (ratified parameters)

With `LPS_E110_ACCEPT=1`:

- **Study (a) — optimism, `dgp.g3a`:** n = 800 train + n_test = 4000 independent test, R = 40.
  Statistic `|rmse_• − rmse_test| / rmse_test` for `• ∈ {selected-min, nested}`. Decision: nested
  relative error `< 0.10` **and** nested `≥` selected-min in expectation (optimism sign correct), with
  the **fixed [P1] SE guard** on both gated means.
- **Study (b) — grouped CV, `dgp.g5`:** K = 40 train clusters, m = 20, ρ ∈ {0.3, 0.6}; fresh test
  K_test = 100 × m = 20 (n_test = 2000), disjoint from training; R = 40. **Nested** estimate under both
  foldings as primary. Decision: random-fold relative error exceeds cluster-fold by `> 0.10` at
  ρ = 0.6; cluster-fold within `0.10` of fresh-cluster truth. Report the realized ρ per replicate.

Record the chosen generator seeds and the realized ρ in the manifest. **Do not run your own mutation**
(the auditor will).

## 5. Deliver → re-audit

New execution bundle (clean committed tree) + handoff. The Part B re-audit covers: the [P1] SE-guard
fix (mutation-checkable — a noisy delta must force INCONCLUSIVE), [P3] validation, and the (a)/(b)
study verdicts on the real G3a/G5. When that clears, **E1.10 is complete** and e19 (E1.9 + E1.10) is
ready for the integration sequence — it is the **first `R/lps.R` branch** to merge to `main`, ahead of
t2.
