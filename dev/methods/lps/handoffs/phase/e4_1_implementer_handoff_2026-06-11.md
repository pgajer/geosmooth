# E4.1 — Implementer handoff (Part A delivered; Part B harness built, acceptance pending G3a)

Date: 2026-06-11
From: implementer agent (E4.1, Tier 4 — pointwise variance & confidence-band
coverage), worktree `~/current_projects/geosmooth-t4`, branch
`codex/geosmooth-t4-uncertainty`
Scope of this handoff: **Part A** (variance/band machinery + deterministic
unit GATE, no DGP dependency) as a standalone deliverable, plus the **Part B
coverage harness** (built and smoke-wired only; its acceptance run is gated on
Amendment 1's audited G3a and is **not** part of this deliverable).

## 1. Phase goal

Contract §E / E4.1, split per the orchestrator's assignment:

- Part A (delivered): implement `Var(ŷ_i) = σ² Σ_j S_ij²`,
  `σ̂² = RSS/(n − tr S)`, and the band `ŷ_i ± z_{0.975}·σ·‖S_{i·}‖₂` on the
  E0.2 S-extraction toolkit for the fixed configuration (singleton grids,
  numeric `chart.dim = 2`, degree 1) per spec §sec:smoother, with a
  deterministic unit GATE at algebraic tolerance `1e-10` against an
  independently extracted `S`, and `df = tr S`.
- Part B (harness only): the stratified coverage GATE/STUDY harness, shaken
  out on a smoke run with a temporary inline paraboloid; **no acceptance run
  performed**.

## 2. Spec-questions note (submitted before implementation)

`audit_contracts/tiers1to4/e4_1_spec_questions_implementer_2026-06-11.md`
(commit `b5229b8`). It contains the API proposal, the supported-configuration
envelope, the NA/fallback semantics, the four unpinned Part B knobs
(support size `K`, kernel, G3a curvature radius, boundary-stratum `h`
definition), the fixed-design reading of the coverage statistic, and the
S-fast-path proposal with its drift guard. Items marked [proposal]/[question]
await orchestrator ratification; none block Part A per the assignment.

## 3. Files created or changed

Commit `7e4bd61` ("Add E4.1 Part A variance/band machinery, unit GATE, and
Part B coverage harness"), on top of `b5229b8` (spec questions) and base
`b86b796`:

- `R/lps_uncertainty.R` (new): `lps.smoother.matrix()`,
  `lps.pointwise.band()`, private helpers `.klp.uq.validate.fit()`,
  `.klp.uq.influence.row()`. Roxygen-documented with named return fields.
- `tests/testthat/test-lps-tier4-uncertainty.R` (new): the E4.1 Part A unit
  GATE (5 `test_that` blocks, 53 assertions, all named with "E4.1").
- `validation/e4_1_coverage_study.R` (new): Part B coverage harness
  (`run.e4.1.coverage.study()` + CLI), inline-smoke DGP clearly labeled, the
  audited-G3a seam via `dgp.fn`/`dgp.source`.
- `scripts/ci/e4_1_headroom_probe.R` (new): realized-margin/determinism
  probe for the bundle.
- `scripts/ci/run_e4_1_execution_artifact.sh` (new): execution-artifact
  harness, Tier-0 pattern.
- `NAMESPACE`: +2 generated export lines (`lps.pointwise.band`,
  `lps.smoother.matrix`) via `make document`.
- **`R/lps.R` was not modified.** No `fit.lps` argument, default, or behavior
  changed; `git diff b86b796..7e4bd61 -- R/lps.R` is empty. The contract
  §A2(i) bit-for-bit pin is therefore vacuous-by-construction for this
  deliverable (there is no new estimator behavior to pin).

## 4. What the implementation is

`lps.smoother.matrix(object, check.tol = 1e-10)` reconstructs the linear
smoother `S` (`n_eval × n_train`) analytically from a fitted
fixed-configuration `lps` object: per eval point it rebuilds the identical
KNN support, kernel weights, local chart, and local design through the same
internal helpers the fit used (`.klp.local.order`, `.klp.kernel.weights`,
`.klp.local.coordinates`, `.klp.get.local.design`,
`.klp.orthogonal.polynomial.transform`, `.klp.local.ridge.scale`,
`.klp.local.design.condition`), then computes the influence row
`l = W B̃ (B̃'WB̃ + ρsI)⁻¹ p̃` in the transformed basis and ridge branch the
solve used. Every extraction self-guards: `max|S y − fitted.values.raw|`
must be ≤ `check.tol` (and the `NA` patterns must match) or the function
stops. Supported envelope (validated, else `stop()`): gaussian, R backend,
`design.basis = "orthogonal.polynomial.drop"`, singleton grids, ambient
coordinates or local-PCA with explicit numeric `chart.dim`;
`lps.pointwise.band()` additionally requires `X.eval` identical to `X`.

`lps.pointwise.band(object, sigma = NULL, level = 0.95, check.tol = 1e-10)`
returns named fields `fitted, se, variance, lower, upper, level, z, sigma,
sigma.hat, sigma.source, df, rss, n.train, smoother.row.norm, configuration`;
`sigma` supplied = known-σ variant, `sigma = NULL` = plug-in `σ̂`.

## 5. Exact commands run

```sh
# in ~/current_projects/geosmooth-t4 (branch codex/geosmooth-t4-uncertainty)
make document
Rscript -e 'suppressMessages(pkgload::load_all(".", quiet = TRUE)); testthat::test_file("tests/testthat/test-lps-tier4-uncertainty.R")'
make test
Rscript validation/e4_1_coverage_study.R n=300 R.replicates=8 support.size=20 drift.check.every=4 out.dir=dev/methods/lps/audit_artifacts/e4_1_dev_tiny
Rscript validation/e4_1_coverage_study.R n=1200 R.replicates=100 support.size=30 kernel=tricube sigma=0.1 out.dir=dev/methods/lps/audit_artifacts/e4_1_smoke_dev
for K in 15 20 25; do Rscript validation/e4_1_coverage_study.R n=1200 R.replicates=100 support.size=$K kernel=tricube sigma=0.1 out.dir=dev/methods/lps/audit_artifacts/e4_1_smoke_dev_K$K; done
Rscript scripts/ci/e4_1_headroom_probe.R /tmp/e41_probe_test
EXECUTOR="implementer-agent-e4.1@geosmooth-t4" bash scripts/ci/run_e4_1_execution_artifact.sh
```

## 6. Execution bundle (clean committed tree)

`dev/methods/lps/audit_artifacts/e4_1_20260611T074742Z/` at git head
`7e4bd61ab84b9ec6449bb7090f3e77295f329b2e`, `tree_clean: true`,
`gate_contexts: E4.1`, executor `implementer-agent-e4.1@geosmooth-t4`.
Contents: `execution_manifest.txt`, `source_checksums.txt` (SHA-256 over
`R/lps.R`, `R/lps_uncertainty.R`, the study, the probe, the gate file),
`sessionInfo.txt`, `blas.txt`, `testthat_results.csv` + summary,
`e4_1_probe.csv`, the smoke-study leg under `smoke_study/`, and
`BUNDLE_CHECKSUMS.txt`. (`dev/methods/lps/audit_artifacts/` is gitignored by repository
policy; the bundle lives on this machine at the path above and is
reproducible from the committed scripts and recorded seeds.)

Manifest lines: `testthat_summary: tests=5 failed=0 error=0 warning=0
skipped=0`; `probe_summary: e4_1_probe: ok max_S_diff=5.551e-17
min_headroom=1801439.9x determinism=0`; the smoke leg's two interior-coverage
lines are recorded in the manifest with their `fail` verdicts and the
`smoke-wiring (NOT acceptance evidence)` context string.

## 7. Numerical findings

**Part A gate (deterministic, both fixtures: ambient D=2 n=42 and local-PCA
`chart.dim=2` D=3 n=34, K=18, degree 1, tricube, ridge 0, known σ₀=0.37):**

- 53 assertions pass standalone; in the bundle the battery reports
  `tests=5 failed=0 error=0 warning=0 skipped=0`.
- Probe realized margins (`e4_1_probe.csv`): max |S_analytic − S_probe| =
  `5.551e-17` (headroom ≈ `1.8e6×` vs the `1e-10` tolerance);
  |df − tr S_probe| = 0; max variance discrepancy `1.388e-17`;
  |σ̂² − RSS/(n−tr S)| ≤ `1.110e-16`; max |S y − fitted| ≤ `2.220e-16`;
  repeated extraction bitwise identical (determinism diff exactly 0).
  Realized df: 9.514 (ambient fixture), 7.919 (surface fixture).
- The extraction also reproduces rank-dropped local fits exactly (a
  support-2 fixture where the drop basis reduces the design): self-guard and
  identity hold at `1e-10` (realized 0 in the dedicated test).

**Part B smoke wiring (inline paraboloid, NOT the audited G3a; n=1200,
σ=0.1 known, R=100, tricube, `chart.dim=2`, degree 1; fixed design,
seeds: geometry 20260611, noise 20260611+r):**

| K | interior known [0.93,0.97] | interior plug-in [0.92,0.98] | boundary known | top-curv-decile known |
|---|---|---|---|---|
| 15 | 0.9469 pass | 0.9369 pass | 0.9458 | 0.9503 |
| 20 | 0.9410 pass | 0.9349 pass | 0.9386 | 0.9473 |
| 25 | 0.9316 pass | 0.9279 pass | 0.9216 | 0.9385 |
| 30 | 0.9174 fail | 0.9163 fail | 0.9012 | 0.9286 |

- Empirical MC-SE of the interior average at R=100: ≈ 0.002 (known σ).
- Realized df = tr S at n=1200: 128.8 (K=30); mean |smoothing bias| interior
  0.011 vs mean known-σ se 0.026 at K=30 — the coverage shortfall at larger
  K is bias-driven, consistent with the variance-only band's design.
- Drift guard (S-path vs full `fit.lps` + `lps.pointwise.band` pipeline) at
  replicates {1,25,50,75,100}: max abs fitted/band discrepancies ≤
  `6.66e-16`, df discrepancy 0 (`smoke_study/e4_1_drift_guard.csv`).
- Stratified tables and per-point coverage CSVs in each run directory
  (`dev/methods/lps/audit_artifacts/e4_1_smoke_dev*`, and the bundle's `smoke_study/`).
  Strata are reported separately and never averaged into the interior
  headline.

## 8. Whether package source was modified; whether tests were run

- Package source: one new R file added; `R/lps.R` and all existing R/C++
  sources untouched (`git diff b86b796..7e4bd61 -- R/ src/` shows only the
  new `R/lps_uncertainty.R`); `NAMESPACE` regenerated (+2 exports). No
  default or behavior of any existing function changed.
- E4.1 battery: green in the execution bundle
  (`tests=5 failed=0 error=0 warning=0 skipped=0`) and standalone
  (53 assertions, 0 warnings).
- Full package suite (`make test`) at the delivered commit `7e4bd61`, run
  alone on a clean tree (log `/tmp/e41_full_suite_final.log` on this
  machine): `[ FAIL 4 | WARN 66 | SKIP 1 | PASS 2147 ]`, make exit nonzero.
  The 4 failures are all in the pre-existing `tests/testthat/test-ge7-lps-api.R`
  (lines 322/323/325: logistic-telemetry fallback/NA-failure counts;
  line 682: `.klp.fit.intercept.design` weighted-mean-fallback identity).
  I reproduced the same 4 failures standalone at my commit **and at the
  base commit `b86b796` in a pristine throwaway worktree**
  (`git worktree add --detach /tmp/geosmooth-base-e41check b86b796`;
  `[ FAIL 4 | PASS 186 ]` both there and here) — they are pre-existing on
  the base, involve no E4.1 file, and are unaffected by my change set. I did
  not modify or attempt to fix them (out of my gate's scope; routing is the
  orchestrator's). The 1 skip is the sanctioned E0.3a deferral. None of the
  66 warnings originate in E4.1 files (the E4.1 battery reports
  `warning=0`; sampled warnings are deprecation notices in
  graph-trend-filtering and similar pre-existing files).
- `make check-fast` (R CMD check --as-cran, no tests/examples) at the
  delivered commit: `Status: 1 WARNING, 4 NOTEs`. The WARNING is
  CRAN-incoming boilerplate (new submission, dev version number,
  off-repository `dgraphs` dependency). NOTEs: hidden `.github` directory
  (pre-existing); "unable to verify current time" (environmental);
  undefined global `tail` in `R/ps_lps.R` (pre-existing, in the
  out-of-scope PS-LPS); and "non-standard top-level files/directories",
  whose list (`audit_artifacts`, `audit_contracts`, `phase_handoffs`,
  `scripts`, `validation`) now includes the two directories this
  deliverable introduces (`validation/`, `dev/methods/lps/handoffs/phase/`) alongside
  pre-existing ones — I did not edit `.Rbuildignore` (repo policy, not
  mine to set). The E4.1 Rd files pass all Rd checks.
- **Incident admission:** my first full-suite run was invalid — I launched
  `make check-fast` concurrently, and its build step runs `make clean`,
  deleting `src/*.o`/`src/*.so` out from under the running suite; that
  run's counts are unreliable and its failure detail was additionally lost
  because I piped output through `tail`. The clean re-run reported above is
  the factual record. A concurrent Tier-2 agent harness was active in its
  own worktree (`~/current_projects/geosmooth-t2`) during the re-run; I
  verified by process working directory that it shares only CPU, not files,
  with this worktree.

## 9. Limitations and unverified claims

1. **Part B has no acceptance evidence.** The coverage runs above use an
   inline paraboloid written for wiring; it is not Amendment 1's audited
   G3a generator. No coverage claim is made for E4.1 acceptance. The
   acceptance run waits for the DGP agent's audited G3a and the
   orchestrator's go-ahead.
2. **The contract leaves K, kernel, and the G3a curvature radius unpinned**,
   and interior coverage is materially K-sensitive (the K=30 smoke fails the
   gate band on the inline DGP; K∈{15,20,25} pass). I did not choose an
   acceptance K; that decision is with the orchestrator (spec-questions §4).
   The K-sweep is on the inline generator only and may not transfer
   quantitatively to the audited G3a.
3. **Supported envelope is narrow by design:** gaussian, R backend,
   `orthogonal.polynomial.drop`, singleton grids, explicit numeric chart
   dimension, and (for bands) `X.eval == X`. Other bases, new-point bands,
   and binary families are unimplemented and rejected with errors.
4. **The NA/fallback propagation branches of the extraction are defensive
   and not exercised by the gate.** Within the supported envelope I could
   not construct a partial-NA fit through the public API: an all-NA
   configuration errors inside `fit.lps` at selection ("No candidate has a
   finite selection score"), and the drop-basis transform yields local
   normal equations with condition ≈ 1, so the per-point fallback paths do
   not fire on real fits. Those branches (`NA` rows, weighted-mean rows,
   the plug-in-unavailable stop) are therefore untested beyond construction.
5. **The influence algebra is a different numerical route than the fit's
   coefficient solve** (`solve(normal, p̃)` vs `solve(normal, rhs)`).
   Algebraically identical; agreement is enforced empirically by the
   per-extraction self-guard at `1e-10` and realized at ≈ `5.6e-17` on the
   fixtures, but I claim no formal floating-point error bound, and exactness
   outside the tested configurations is enforced only by the self-guard.
6. **The probe script duplicates the gate fixtures** (same seeds and
   configuration, re-declared) rather than sharing code with the test file;
   a future edit could de-synchronize them. The testthat gate remains the
   authority; the probe is bundle telemetry.
7. **The smoke study's per-replicate fits use the S-matvec fast path**; full
   pipeline agreement is asserted only at guard replicates
   {1, 25, 50, 75, 100} (realized ≤ `6.7e-16`), not at every replicate.
   `fit.every.replicate=TRUE` exists but was not exercised at smoke size.
8. **Mutation-qualification of the gate has not been run by me** (authorship
   independence; contract §A5 assigns it to the auditor).
9. The boundary stratum uses the per-point realized bandwidth `h_i`; the
   global-`h` alternative is recorded as a count (`n.boundary.global.h`) but
   no coverage number was computed under it.
10. The inline DGP's latent-disk sampling (`r = sqrt(U)`) and the
    paraboloid curvature formula
    (`κ_max(r) = (1/R₀)/sqrt(1 + r²/R₀²)`, max at the apex) are my own
    derivations, written for wiring; they have not been independently
    checked and the audited G3a may parametrize curvature differently.
11. Dev-run artifacts under `dev/methods/lps/audit_artifacts/e4_1_dev_tiny`,
    `…/e4_1_smoke_dev`, `…/e4_1_smoke_dev_K{15,20,25}` were produced at
    interim (uncommitted or pre-final) tree states during development; only
    the bundle `dev/methods/lps/audit_artifacts/e4_1_20260611T074742Z/` is bound to the
    clean committed tree. The dev runs are reproducible from the committed
    script and the seeds recorded inside each run's provenance.
12. **The full package suite is red for pre-existing reasons** (§8: 4
    failures in `test-ge7-lps-api.R`, present at base `b86b796`). My green
    claims are scoped to the E4.1 battery, its bundle, and the probe. I
    confirmed presence-at-base in a pristine worktree but did not bisect
    when the failures were introduced, and whether they are already known
    or sanctioned is not determinable from this worktree.
