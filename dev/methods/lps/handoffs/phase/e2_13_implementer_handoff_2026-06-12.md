# E2.13 — Implementer handoff (ridge-penalty structure alignment)

Date: 2026-06-12
From: implementer agent (Tier 2, worktree `geosmooth-t2`, branch
`codex/geosmooth-t2-binary-hygiene`)
Gate: E2.13 (contract §C; plan §E2.13) — correctness GATEs, built under the
§G4 resolution (`project_briefs/lps_g4_ridge_resolution_2026-06-12.md`,
ratifying spec-memo item 12; recorded as memo addendum 12b) and the work
order `project_briefs/lps_t2_e2_13_work_order_2026-06-12.md`.

## Goal

Opt-in aligned ridge: `ridge.shrinkage.target = c("zero", "local.mean")`,
default `"zero"` preserving the historical penalty bit-for-bit;
`"local.mean"` leaves the constant direction unpenalized via
weighted-centering reparametrization so large ridge shrinks the local
prediction toward the local weighted mean. Gaussian/least-squares solve
only; the binomial logistic solver's penalty is out of scope per §G4.

## Files changed or created

- Commit `c796408`: `validation/e2_13_pin_reference_fits.R` (new) +
  `reports/e2_13_reference_fits.csv` (committed reference, generated with
  `R/lps.R` in its pre-E2.13 state at HEAD `c621e2f` — the recorded commit
  inside the CSV — immediately before this commit); memo addenda 12b/11c.
- Commit `b79d041`:
  - `R/lps.R`: the new `fit.lps` argument (appended at the signature end,
    `match.arg`-validated, stored in the returned object, printed by
    `print.lps` only when non-default, honored by `predict.lps` with
    `"zero"` fallback for pre-change objects); threading through
    `.klp.cv.table` → `.klp.fit.intercept.lazy` → `.klp.fit.intercept.design`
    → `.klp.solve.local.wls` and the prediction path
    (`.klp.predict.local.polynomial` → `.klp.fit.intercept`); the aligned
    branch in `.klp.solve.local.wls` (weighted-centered design/response,
    all centered directions penalized, prediction = local weighted mean +
    centered-prediction-row · solution; active only for the orthogonal
    bases and `rho > 0`; `rho = 0` falls through to the unchanged legacy
    solve); a warning when `outcome.family = "binomial"` is combined with
    `"local.mean"`; roxygen for all of it.
  - `tests/testthat/test-lps-ridge-alignment.R` (new): the E2.13 GATEs,
    4 tests / 20 assertions.
  - `scripts/ci/run_tier2_execution_artifact.sh`: E2.13 gate file added to
    the battery.

## Fixture and configuration (per plan §E2.13)

G1, `D = 2`, `n = 150`, degree-2 polynomial truth, mild noise (sd 0.1),
seed 1301; singleton grids (support 30, degree 1, gaussian),
`design.basis = "orthogonal.polynomial.drop"`, `ridge.condition.max = Inf`,
`backend = "R"`, singleton `rho ∈ {0, 1e-8, 1e-2, 1, 1e2}`, paired across
`rho` on the same data/foldid. Per-anchor local weighted means are computed
through the actual package internals (`.klp.local.order` +
`.klp.kernel.weights`), not a re-implementation.

## Exact commands run

```sh
Rscript validation/e2_13_pin_reference_fits.R       # at pre-change source
Rscript -e '...test_file("tests/testthat/test-lps-ridge-alignment.R")'
Rscript -e '...test_dir("tests/testthat", ...)'      # full suite
EXECUTOR="implementer-agent-t2" bash scripts/ci/run_tier2_execution_artifact.sh
```

## Result artifacts

Execution bundle `dev/methods/lps/audit_artifacts/tier2_20260612T201926Z/`:
`git_head = b79d041…`, `tree_clean: true`, `testthat_summary: tests=27
failed=0 error=0 warning=0 skipped=1` (the sanctioned E0.3a skip),
`gate_contexts: E0.1;…;E0.8;E2.12;E2.12a;E2.12b;E2.13;E2.14`,
`probe_rc: 0`, `study_rc: 0`.

## Numerical findings (realized, in the GATE comments and bundle)

- Aligned arm: tiny-ridge invariance `max|f(1e-8) − f(0)| = 6.95e-09`
  (contract threshold `1e-6`); `rho = 0` coincides with the legacy path
  exactly (`identical()`); at `rho = 1e2` the fit sits on the local
  weighted mean — median per-anchor `|f − ȳ_w|/|f − 0| = 0.0018`
  (threshold 0.05), max over the 116 anchors with `|ȳ_w| > 0.2` is
  `0.0114` (threshold 0.1), `mean|f| = 0.5006` vs `mean|ȳ_w| = 0.4997`;
  the approach to the mean is monotone in `rho`; degree-0 aligned ridge
  equals the local weighted mean to `1e-10` (exactness property of the
  centering construction).
- Legacy arm (default `"zero"`, documented pre-fix behavior): at
  `rho = 1e2` the fit collapses toward zero — `mean|f| = 0.0060`,
  `max|f| = 0.0178` — and differs from the aligned arm by up to `1.16`.
- §A2 pin: default-configuration gaussian and bernoulli fits (default
  ridge grid `c(0, 1e-10, 1e-8)`, default basis, argument not supplied)
  reproduce all 308 committed pre-change reference values exactly
  (17-significant-digit string equality, a lossless round trip for
  doubles). Rerunning the pinning script post-change reproduces every
  value byte-identically (only the recorded-commit column changes).
- Full Tier-0 battery green at `b79d041`; the E0.6 realized statistics
  are unchanged from the accepted values (the printed per-cell lines are
  identical).

## Whether source/tests were run

Yes — gate file standalone (20/20), the full battery inside the bundle on
a clean committed tree, and the full package suite (the four pre-existing
`test-ge7-lps-api.R` failures only, unchanged from the base commit).

## Limitations and unverified claims

- **No mutation run** (the §G4 doc names two: a wrong alignment that still
  pulls `f(1e2)` toward 0 must redden the aligned GATE; altering the
  `"zero"` path must redden the §A2 pin). Both are the auditor's.
- **The reference pin was generated on the same machine/BLAS** as the
  GATE run (vecLib, recorded in the CSV's generating commit and the
  bundle's `blas.txt`). On a different BLAS the §A2 17-digit string
  comparison may legitimately fail even though the default path is
  unchanged; the pin certifies bit-for-bit on this platform. The
  pinning script is committed for regeneration on any platform.
- **Threshold provenance:** the contract gives no number for "small
  relative to"; the 0.05 / 0.1 ratio thresholds and the 0.2 anchor
  restriction were chosen from the realized values (8–28× margins) and
  are documented in the test header. The `|ȳ_w| > 0.2` restriction
  excludes 34 of 150 anchors from the max-ratio assertion (near-zero
  weighted means make the ratio denominators uninformative); the
  median-ratio assertion covers all anchors.
- The aligned solve's `coefficients` field holds centered-basis deviation
  coefficients (documented in-code); callers in the package use
  `$prediction`, but any future caller reading `coefficients[[1L]]` as an
  intercept would be wrong in aligned mode.
- `ridge.shrinkage.target` is a single value, not a CV'd grid; the
  argument is not surfaced in `cv.table` (nothing varies over it).
- The bernoulli arm of the §A2 pin exercises the least-squares path the
  alignment touches; binomial fits are untouched by construction (the
  logistic solver never sees the argument) and additionally warn, but I
  did not pin binomial numerics for E2.13 (E2.14/E2.12 gates cover that
  path at this commit).
