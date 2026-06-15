# E2.12 — Implementer handoff (binary selection-metric consistency & log-loss clipping)

Date: 2026-06-11
From: implementer agent (Tier 2, worktree `geosmooth-t2`, branch
`codex/geosmooth-t2-binary-hygiene`)
Gate: E2.12 (contract §C; frozen spec §E2.12) — sub-items (a) and (b) are
correctness GATEs; cross-clip selection stability is the non-gated STUDY.
Spec-questions memo: `audit_contracts/tiers1to4/t2_spec_questions_implementer_2026-06-11.md`
items 6–11 and addendum 11b (the addendum was written before the (b) test
landed and corrects the dominance operationalization).

## Goal

(a) Bernoulli-mode selection scores the deployed (clipped) metric, with the
pre-fix discrepancy demonstrated in the same file as a documented motivating
case; (b) the log-loss probability truncation is pinned at `1e-6` (from
`1e-15`), with the `1e-15` instability demonstrated as a single
deliberately confident-wrong held-out point; cross-clip selection stability
over `{1e-6, 1e-3}` reported as a STUDY, not gated.

## Files changed or created

- Commit `5065a18`:
  - `R/lps.R` (modified): `.klp.clip.probability` default `eps` `1e-15 →
    1e-6` (only caller: `.klp.logloss`; the logistic-solver init already
    passed `1e-6` explicitly). `.klp.cv.table` (R path) computes
    `cv.brier.observed` as the Brier score of the response-scale
    ([0,1]-clipped) out-of-fold predictions with `Inf` for any candidate
    having a non-finite prediction (same NA semantics as the raw selection
    score). `.klp.selection.score.column("bernoulli")` returns
    `cv.brier.observed`. In `fit.lps`, the legacy C++ CV path (which
    returns aggregate raw RMSE, no per-point predictions) keeps selection
    on `cv.rmse.observed` exactly as before, and
    `.klp.decorate.outcome.cv.table` retains the `rmse^2` Brier decoration
    only when the column was not computed (i.e. only on those C++ paths).
    New `fit.lps` argument `keep.cv.predictions = FALSE` (appended at the
    signature end): `TRUE` stores the per-candidate out-of-fold prediction
    matrix as `$cv.predictions`; the default adds no element. Roxygen
    updated for all of the above.
  - `tests/testthat/test-lps-binary-metric-consistency.R` (new): E2.12
    GATEs (fixtures below).
  - `validation/e2_12_crossclip_stability_study.R` (new) +
    `reports/e2_12_crossclip_scores.csv`,
    `reports/e2_12_crossclip_stability_verdict.csv` (committed,
    deterministic, regenerated identically by the harness).
  - `scripts/ci/tier2_binary_probe.R`, `scripts/ci/run_tier2_execution_artifact.sh`
    (modified): E2.12 realized-quantities sections; the harness now also
    runs the STUDY and records `tree_clean_post_study`.
  - `audit_contracts/tiers1to4/t2_spec_questions_implementer_2026-06-11.md`
    (modified): addendum 11b.
- Commit `3eaf9cf`: §A2 regression pin for the `keep.cv.predictions`
  default (object-shape and component-identity GATE) added to the same test
  file.

Package source was modified. No existing exported signature changed except
the appended optional argument; binomial/gaussian selection columns are
unchanged (`gaussian` selection untouched everywhere).

## Fixtures (deterministic; G6 with named overrides, n = 400)

Both use `eta(x) = 6 * tanh(15 * x1)` on `x ∈ [-1,1]^2` (sharp-cliff
override of the G6 default smooth surface; `alpha = 0`, symmetric, target
prevalence 0.5), `p = expit(eta)` clipped to `[0.05, 0.95]` per the G6
construction, `y ~ Bernoulli(p)`, explicit `foldid = rep(1:5, length.out =
400)`, gaussian kernel, `backend = "R"`,
`design.basis = "orthogonal.polynomial.drop"`, singleton ridge 0,
`ridge.condition.max = Inf`, `unstable.action = "mean"`.

- **(a)** seed `2121`, `outcome.family = "bernoulli"`, candidates
  `support {8, 60} × degree {0, 2}`.
- **(b)** seed `7001`, `outcome.family = "binomial"`, candidates
  `support 60 × degree {0, 1}`, with observation 7 (`x1 = -0.702`, drawn
  label 0, all-zero 60-point neighborhood) deliberately flipped to 1 — the
  confident-wrong held-out point.

## Exact commands run

```sh
Rscript -e 'suppressMessages(pkgload::load_all(".", quiet = TRUE)); testthat::test_file("tests/testthat/test-lps-binary-metric-consistency.R")'
Rscript validation/e2_12_crossclip_stability_study.R
Rscript -e 'suppressMessages(pkgload::load_all(".", quiet = TRUE)); testthat::test_dir("tests/testthat", reporter = "silent", stop_on_failure = FALSE)'  # full suite
EXECUTOR="implementer-agent-t2" bash scripts/ci/run_tier2_execution_artifact.sh
```

## Result artifacts

- Execution bundle `dev/methods/lps/audit_artifacts/tier2_20260611T084642Z/` (on disk,
  gitignored path): `git_head = 3eaf9cf…`, `tree_clean: true`,
  `testthat_summary: tests=22 failed=0 error=0 warning=0 skipped=1` (the
  skip is the sanctioned E0.3a deferral), `gate_contexts:
  E0.1;…;E0.8;E2.12;E2.12a;E2.12b;E2.14`, `probe_rc: 0`, `study_rc: 0`,
  `tree_clean_post_study: true`. Realized-quantity tables:
  `e2_12a_selection_metric.csv`, `e2_12b_clip_dominance.csv`,
  `e2_12_fit_args.txt`, plus the E2.14 tables and the copied STUDY CSVs.
- An earlier bundle `dev/methods/lps/audit_artifacts/tier2_20260611T083751Z/` (head
  `5065a18`, also fully green) predates the §A2 pin test; the `084642Z`
  bundle supersedes it.

## Numerical findings

(a) — from `e2_12a_selection_metric.csv` (per-candidate, raw vs deployed):

| candidate | raw Brier (rmse²) | deployed (clipped) Brier |
|---|---|---|
| support 8, degree 0 | **0.075078** (raw argmin) | 0.075078 |
| support 60, degree 0 | 0.097000 | 0.097000 |
| support 8, degree 2 | 0.882721 | 0.110365 |
| support 60, degree 2 | 0.075653 | **0.072937** (clipped argmin, selected) |

The raw rule (the pre-fix selection) picks `(8, 0)`; the deployed metric
picks `(60, 2)`; the fitted object selects `(60, 2)`. Margins between the
two flipped candidates: `5.75e-4` (raw scale), `2.14e-3` (clipped scale) —
both > 100× the contract's `1e-6` comparison tolerance, so the flip is not
a tie. 263 of the 1600 out-of-fold predictions fall outside `[0, 1]`. The
selection-score column equals the deployed metric recomputed from the
stored CV predictions without package helpers: max residual `1.4e-17`
(contract tolerance `1e-6`). CV-prediction determinism across refits: `0`.

(b) — from `e2_12b_clip_dominance.csv`: the flipped point's out-of-fold
prediction is exactly `0` under both candidates (all-zero-neighborhood
event-rate fallback); it is the **unique** point whose wrong-side clip
binds at `1e-6`; it accounts for 100.0000 % of the `1e-15`-vs-`1e-6` score
change on both candidates (`0.051808` of the mean score each); at clip
`1e-15` it contributes `-log(1e-15) = 34.5388`, 8.57× the largest other
contribution (4.0318) on the selected candidate. The deployed
`cv.logloss.observed` equals the clip-`1e-6` log loss recomputed manually
from the stored predictions (residual `0`). The clip constant is pinned via
`formals` and realized bounds (`clip(c(0,1)) = c(1e-6, 1 - 1e-6)`).

STUDY (recorded verdict, not gated): selection is stable between clips
`1e-15` and `1e-6` (both pick support 60, degree 0; margin `0.0022`) and
**reselects at `1e-3`** (support 60, degree 1; margin `0.0106`) — a
near-tie reselection, exactly the case the contract anticipated; verdict
row in `reports/e2_12_crossclip_stability_verdict.csv`.

Regression context: the full Tier-0 battery in the bundle is green, and the
E0.6 realized smoke statistics remain **bit-identical** to the base commit
in all six family×prevalence cells (no E0.6 selection changed under either
the clip pin or the bernoulli selection switch). Full package suite: 217
tests, 4 failures — the same four pre-existing `test-ge7-lps-api.R`
failures already reproduced at the unmodified base commit (documented in
the E2.14 handoff); no new failures.

## Whether source/tests were run

Yes — gate file 38/38 green standalone; battery + gates green inside the
bundle on a clean committed tree; STUDY script run twice (standalone and in
the harness) with identical committed outputs; full package suite run once
post-change.

## Limitations and unverified claims

- **No mutation run.** The contract's named mutation for (a) (revert to
  scoring unclipped predictions) was not run by me as acceptance evidence.
- **The C++ CV path still selects on the raw metric.** Spec-memo item 8
  asks the orchestrator to choose between forcing bernoulli to the R
  backend (option a) and the status quo (option b); pending that decision I
  implemented the §A2-conservative option (b), so the gate's invariant
  "selection score = deployed metric" holds on the R CV path only. The
  legacy path is reachable via `design.basis = "monomial"` + singleton
  `ridge = 0` + `ridge.condition.max = Inf` with coordinates, and is
  documented in the roxygen. The GATE runs `backend = "R"`.
- **The pre-fix discrepancy is demonstrated from the post-fix object.** The
  raw column (`cv.rmse.observed`) is computed unchanged, and the test
  asserts its argmin (the old selection rule) differs from the deployed
  argmin; I did not execute the pre-change selection code itself.
- **The dominance operationalization is mine.** The spec says "demonstrably
  dominated by a single confident-wrong point"; memo addendum 11b records
  why the sum-of-all-others comparison cannot hold under G6's
  `[0.05, 0.95]` probability floor at `n = 400` and states the implemented
  definition (unique binder; > 99.9 % of the cross-clip change; > 5×
  largest single contributor). The orchestrator has not yet ratified the
  addendum.
- **The confident-wrong prediction is produced by the event-rate fallback**
  (all-zero neighborhood ⇒ prediction exactly 0), not by a converged IRLS
  solve. That is the deployed predictive path for such supports, but the
  demonstration therefore exercises the fallback, not extreme converged
  probabilities.
- **An existing GE7 assertion is now conditionally true.**
  `test-ge7-lps-api.R:67` pins `cv.brier.observed == cv.rmse.observed^2`;
  post-fix this holds only because that fixture's raw CV predictions stay
  inside `[0, 1]` (clip is the identity there). The assertion passes
  unchanged and I did not edit it; it no longer expresses the general
  contract.
- **One number in commit `5065a18`'s message is wrong:** it says "245
  out-of-range raw CV predictions"; the realized count on the committed
  fixture is 263 (245 belonged to a different exploratory seed). The test
  asserts only `> 0`; the bundle records 263. The commit message cannot be
  amended without rewriting pushed history, so the discrepancy is recorded
  here.
- **Warning accounting.** The full-suite run shows 66 warnings
  suite-wide; I verified my diff adds no `warning()` call and the battery
  files report `warning=0` in the bundle, but I did not re-run the full
  suite at the base commit to compare the suite-wide warning count.
- **Single environment** (macOS arm64 / vecLib; `sessionInfo.txt`,
  `blas.txt` in the bundle). The (a) ranking margins are ~`1e-3`–`1e-4`,
  comfortably above plausible BLAS jitter, but I did not verify on a second
  platform. `LPS_TIER0_FULL=1` was not exercised in this gate's bundle.
- The earlier same-day bundle `083751Z` (pre-pin-test) is retained on disk;
  nothing in it contradicts `084642Z`.
