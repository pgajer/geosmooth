# e19 reconciliation + GE7 cleanup work order (Phase 2b — the one R/lps.R merge)

Date: 2026-06-14. To the e19 implementer (worktree `geosmooth-e19`, branch
`codex/geosmooth-e1-9-bandwidth-multiplier`, tip `bc733df`). This is the **final integration merge** of
the LPS base: e19 absorbs the already-merged t2 (and t4) and becomes `main`. Refs: integration plan
`project_briefs/lps_integration_plan_2026-06-12.md` (§2b), the Phase-3 Pass-1 audit
`audits/phase3_merged_main_reaudit_2026-06-14.md` (the GE7 follow-ups). `main` is `ffa840a`.

This is the **one** place two branches edit `R/lps.R`. t2 merged first (clean); e19 carries the single
reconciliation, resolved **in this worktree**, then fast-forwards `main`. The union is **additive** — every
new argument defaults bit-for-bit — so this is a union, not a behavior change.

## Step 0 — clean tree

Bank any untracked e19 verdicts/handoffs/closure artifacts (Part B + b′ audits, handoffs) so
`git status --short` is empty before merging. The acceptance bundles (`de0f861`, `92707c0`) are already
committed.

## Step 1 — merge `main` into e19

```sh
cd ~/current_projects/geosmooth-e19
git merge main
```

Expect conflicts in **exactly three regions** of `R/lps.R` (everything else is disjoint and coexists —
e19's kernel-weight/bandwidth body and `lps_cv_utils.R`; t2's IRLS/binary body and selection metric):

## Step 2 — resolve the union (additive)

1. **`fit.lps` signature** — union the non-overlapping new arguments. The common base is identical; the
   only differences are:
   - e19 adds `bandwidth.multiplier.grid = 1`
   - t2 adds `keep.cv.predictions = FALSE` and `ridge.shrinkage.target = c("zero", "local.mean")`

   The merged signature carries **all three**, each at its bit-for-bit default (`= 1`, `= FALSE`,
   `"zero"` first). Order is cosmetic; keep them grouped sensibly.
2. **Per-argument cleaning / validation** — union the cleaning blocks for the three args; order-independent.
3. **CV candidate-grid construction** — combine so the grid spans **both** axes: e19's bandwidth axis ×
   t2's clip/ridge expansion, **without double-counting**. This is the only non-mechanical hunk — make sure
   a default-config run still enumerates exactly the pre-merge candidate set (no spurious extra candidates,
   no dropped ones).

## Step 3 — GE7 test maintenance (fold in here so the suite goes fully green)

The four `tests/testthat/test-ge7-lps-api.R` failures are **pre-existing stale tests** (Phase-3 Pass-1
proved them identical at `b86b796`/`41dc962`/`678565c` — not a t2 regression). Fix them in this branch:

- **Lines 322/323/325** (binomial NA-failure telemetry): the all-ones rank-deficient fixture now converges
  (so the telemetry path isn't exercised). Replace it with the **exact-separation fixture** the Pass-1
  audit supplied, which actually drives `na.failure`:

  ```r
  z <- c(seq(-0.20, -0.04, by = 0.02), 6)
  design <- cbind(1, z)
  y <- as.numeric(z > 0)
  weights <- geosmooth:::.klp.kernel.weights(abs(z), "gaussian")
  telemetry <- geosmooth:::.klp.logistic.telemetry.new("binomial")
  failed <- geosmooth:::.klp.fit.logistic.prob.design(
      design = design, y = y, weights = weights,
      design.basis = "orthogonal.polynomial.drop", design.drop.tol = 1e-8,
      ridge.multiplier.grid = 0, ridge.condition.max = Inf,
      unstable.action = "na", logistic.telemetry = telemetry)
  summary <- geosmooth:::.klp.logistic.telemetry.summary(telemetry)
  expect_true(is.na(failed)); expect_equal(summary$fallback.path.count, 1L)
  expect_equal(summary$event.rate.fallback.count, 0L); expect_equal(summary$na.failure.count, 1L)
  ```

- **Line 682** (nearly-saturated WLS): **[orchestrator-ratified disposition — update the test to the
  current, long-standing behavior]**. The default orthogonal-polynomial ridge path does **not** consult
  `.klp.local.design.is.safe()` to force a weighted-mean fallback (this predates t2). Keep the
  `expect_false(.klp.local.design.is.safe(...))` line; replace the `expect_equal(..., weighted.mean(...))`
  expectation with an assertion of the actual contract — the fit returns a **finite fitted intercept**
  that is **not** the weighted mean — with a comment citing the Pass-1 finding. Use a robust check
  (finite + not-equal-to-weighted-mean), **not** a brittle exact-value pin.
  *Do not* add an `is.safe`→fallback production guard. (That alternative is only if the orchestrator later
  decides unsafe designs must force fallback; it is out of scope here.)

**Out of scope:** the E2.13 §A2 reference extension (the Pass-1 optional item) — deferred to Phase-4; do
not touch `reports/e2_13_reference_fits.csv` here.

## Step 4 — full suite green

```sh
Rscript -e 'pkgload::load_all("."); library(testthat); test_dir("tests/testthat")'
```

Everything green: E1.9a/b + E1.10 + E2.12/13/14/15 + Tier-0 (incl. amended E0.6 + fallback-bound) + dgp +
**ge7-lps-api (now green)** + the bandwidth/CV tests. No failures, no new warnings introduced by the merge.

## Step 5 — fast-forward `main` (local only — do NOT push)

After the resolved merge commit and a green suite:

```sh
git branch -f main codex/geosmooth-e1-9-bandwidth-multiplier
```

`main` now carries the fully-integrated `fit.lps`. **Do not `git push`** — the Phase-3 Pass-2 re-audit
gates the push (the orchestrator pushes after acceptance).

## Step 6 — handoff

Write the reconciliation handoff: the resolved `main` tip SHA (for the Pass-2 auditor to certify), the
three-region resolution summary, confirmation that every new arg defaults bit-for-bit and the CV grid spans
both axes without double-counting, the GE7 fixes, and the green full-suite evidence (clean committed tree,
session info). **Do not run mutations** — the Pass-2 auditor owns them.

When Pass-2 accepts, Tier 1–4 is integration-complete; `main` is pushed and Phase-4 (docs/dev reorg)
follows.
