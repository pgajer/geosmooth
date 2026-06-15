# E1.9 implementer handoff — bandwidth multiplier GATEs

Date: 2026-06-11
Author: implementer agent (E1.9)
Contract: `project_briefs/lps_tiers1to4_contract_2026-06-11.md` §B / E1.9 (resolved §G1/§G2/§G5; Amendment 1)
Frozen spec: `project_briefs/lps_experimental_plan_2026-06-09.tex`, E1.9
Spec memo (pre-implementation): `audit_contracts/lps_tiers1to4/e1_9_spec_questions_implementer_2026-06-11.md`

## 1. Scope delivered

E1.9 sub-items (a) ESS/K + last-weight characterization GATE and (b) `b = 1`
backward-compatibility GATE, plus the `bandwidth.multiplier.grid` feature they
gate. Sub-item (c), the benefit STUDY → PROMOTION over G3a/G3d, is **not
delivered**: per the assignment it is deferred until Amendment 1 binds the
consolidated DGP generators; no study script was written and no one-off
generator was improvised.

## 2. Branch, worktree, and commits

Work lives on branch `codex/geosmooth-e1-9-bandwidth-multiplier`, developed in
a dedicated git worktree at `/Users/pgajer/current_projects/geosmooth-e19`
(created after concurrent-session interference in the shared main tree; see
§8 item 8). Commits, oldest first:

| Commit | Content |
|---|---|
| `8490def` | Tracks the four Tiers 1–4 program documents under `project_briefs/`. |
| `609750b` | "Adjust E0.6 binary support schedule" — committed by a concurrent automation, duplicating `b86b796` on `codex/geosmooth-tier0-bucket2-isolated` (same patch, different hash). |
| `de38a17` | v1 of the spec memo, the E1.9 fixture helper, and the pinning script — committed by a concurrent automation from my in-flight files. |
| `fe582b1` | Spec memo v2 (supersedes the v1 text in `de38a17`). |
| `c70ed5f` | Pinned pre-change reference fits (`tests/testthat/helper-lps-e1-9-reference.R`), generated at `fe582b1` against unmodified `R/lps.R` (sha256 `8bc0abdb…f27549`, blob `779d000a`). |
| `bd5358d` | The `bandwidth.multiplier.grid` implementation in `R/lps.R` (only file changed; no C++ touched). |
| `72d03d9` | `tests/testthat/test-lps-bandwidth-multiplier.R` (8 tests). |
| `f0eeb7a` | `scripts/ci/run_e1_9_execution_artifact.sh` + `scripts/ci/e1_9_realized_quantities_probe.R`. Bundle generated at this head. |

## 3. Files changed or created

- `R/lps.R` — modified (the only package-source change; +121/−20):
  `fit.lps` gains `bandwidth.multiplier.grid = 1` (appended last in the
  signature) with roxygen; `.klp.kernel.weights` gains
  `bandwidth.multiplier = 1` applied as
  `u <- distances / (b * h + sqrt(.Machine$double.eps))`;
  new `.klp.clean.bandwidth.multiplier.grid` and `.klp.weight.key`;
  `bandwidth.multiplier` joins `expand.grid`, the CV weight map (per
  kernel × multiplier), and the selection tie-break (after `kernel`,
  ascending); `.klp.resolve.backend` forces R for grids ≠ `c(1)` (explicit
  `cpp`/`cpp.local.pca` error); guards added in the two cpp cv-table branches
  and the cpp predict branch; selected multiplier returned in
  `$selected$bandwidth.multiplier`, grid stored on the fit object;
  `predict.lps` falls back to `b = 1` for pre-change objects; `print.lps`
  prints the multiplier only when ≠ 1; `lps.backend.diagnostics` gains
  `selected.bandwidth.multiplier` and `bandwidth.multiplier.grid` columns.
- `tests/testthat/helper-lps-e1-9.R` — fixture constructors (datasets seeded
  4101–4105; configurations A multi-candidate ambient, B strict singleton
  ambient, C local-PCA singleton; the fixed characterization distance vector
  `sqrt(seq_len(20)/20)`).
- `tests/testthat/helper-lps-e1-9-reference.R` — generated pre-change
  reference values (hex floats; provenance header records generation commit,
  `R/lps.R` sha256, R 4.5.2, BLAS = Apple Accelerate vecLib).
- `tests/testthat/test-lps-bandwidth-multiplier.R` — the GATEs (8 tests).
- `validation/e1_9_pin_reference_fits.R` — reference generator (refuses a
  dirty `R/lps.R` unless `FORCE=1`).
- `scripts/ci/run_e1_9_execution_artifact.sh`,
  `scripts/ci/e1_9_realized_quantities_probe.R` — bundle harness + probe.
- `audit_contracts/lps_tiers1to4/e1_9_spec_questions_implementer_2026-06-11.md`
  — pre-implementation spec memo (9 items; backend coupling, grid validation,
  tie-breaking, bit-for-bit interpretation, schema additions, fixed distance
  vector, STUDY deferral, naming/position).

## 4. Exact commands run (in the worktree)

```sh
# reference pinning (pre-change source; HEAD = fe582b1 at the time)
Rscript validation/e1_9_pin_reference_fits.R

# gate file
Rscript -e 'pkgload::load_all("."); testthat::test_file("tests/testthat/test-lps-bandwidth-multiplier.R")'

# full suite, post-change (and pre-change at c70ed5f in a temp worktree)
Rscript -e 'pkgload::load_all("."); testthat::test_dir("tests/testthat", stop_on_failure = FALSE)'

# roxygen syntax validation (tracked tree unchanged afterwards)
Rscript -e 'roxygen2::roxygenise(".")'

# execution bundle (clean committed tree, HEAD = f0eeb7a)
EXECUTOR="implementer-agent-e19-worktree" bash scripts/ci/run_e1_9_execution_artifact.sh
```

## 5. Artifacts

- Execution bundle: `audit_artifacts/e1_9_20260611T061704Z/` **in the
  worktree** (`/Users/pgajer/current_projects/geosmooth-e19`; `audit_artifacts/`
  is gitignored). Manifest: `git_head f0eeb7a`, `tree_clean true`,
  `testthat_rc 0`, `probe_rc 0`, gate contexts
  `E0.1;E0.2;E0.3a;E0.4;E0.5;E0.6;E0.7;E0.8;E1.9;E1.9a;E1.9b`.
  Contains per-test results CSV, probe CSVs
  (`e19_characterization.csv`, `e19_b1_exactness.csv`,
  `e19_probe_summary.csv`), full argument-list/seed provenance
  (`e19_provenance.txt`), `sessionInfo`, BLAS id, source checksums, bundle
  checksums.

## 6. Numerical findings

- **Characterization (E1.9a)** on `sqrt(seq_len(20)/20)`, K = 20, actual
  routine `geosmooth:::.klp.kernel.weights`: gaussian ESS/K = **0.97973**
  (threshold > 0.9); tricube ESS/K = **0.52195** (threshold < 0.85);
  last-weight ratios w₍K₎/max w: tricube **9.24e-23**, epanechnikov
  **3.137e-08**, triangular **1.919e-08** (threshold < 1e-6; epanechnikov is
  the binding margin, ≈ 32×).
- **b = 1 exactness (E1.9b)**: max |Δ fitted| and max |Δ cv.rmse| vs the
  pre-change pinned references are **exactly 0** (bit-identical) for all three
  configurations on this machine; contract tolerance 1e-10. Default call and
  explicit `bandwidth.multiplier.grid = 1` are bit-identical (fitted values,
  cv.table, selected). Selection (support 20/2/gaussian for A; 18/1/tricube
  for B; 16/1/gaussian for C) matches the references.
- **Determinism**: repeated identical fits differ by 0.
- **Multiplier liveness**: `b = 2` shifts config-B fitted values by max
  1.33e-01 vs `b = 1`; multi-grid `b ∈ {0.5, 1, 2, 4}` on config B yields CV
  RMSE {0.40551, 0.14525, 0.18308, 0.19221}, selected b = 1.
- **Backend coupling**: `backend = "auto"` + `b = 2` resolves to R;
  `backend = "auto"` + default resolves to cpp (unchanged); explicit
  `backend = "cpp"` + `b = 2` errors.
- **Gate battery (bundle)**: 24 tests, 0 failed, 0 errors, 0 warnings,
  1 skipped (the sanctioned E0.3a deferral). All Tier-0 gates green at the
  new default.
- **Full suite parity**: pre-change (at `c70ed5f`) and post-change (at
  `bd5358d`+) both give files=19, tests=212, **failed=4**, error=0,
  **warning=66**, skipped=1, with byte-identical failure identities: 3
  failures in "LPS binomial mode uses local logistic fits and log-loss
  selection" and 1 in "LPS local WLS falls back on nearly saturated
  ill-conditioned designs" (both `test-ge7-lps-api.R`), and all 66 warnings
  from `test-graph-trend-filtering.R`. These pre-date the change on this
  machine (macOS / Accelerate BLAS) and are unaffected by it.

## 7. Source / test execution declarations

- Package R source modified: **yes** (`R/lps.R` only). C++ source modified:
  **no**. NAMESPACE: unchanged (no new exports); roxygen re-ran cleanly with
  zero tracked-file changes (`man/` is gitignored).
- Package tests run: **yes** — the new gate file, the four-file gate battery
  via the bundle harness on a clean committed tree, and the full
  `tests/testthat` suite both pre-change (temp worktree at `c70ed5f`) and
  post-change.

## 8. Limitations and unverified claims

1. **Sub-item (c) is not delivered.** The benefit STUDY (and its PROMOTION
   decision) over G3a/G3d does not exist yet; nothing here evidences that the
   multiplier improves Truth-RMSE on curved truths. E1.9 is therefore
   **partially delivered by design** (two GATEs of three sub-items).
2. **No mutation qualification was run by me.** Per contract §A5 the
   mutation (perturb the multiplier application so `b = 1` ≠ current) is the
   auditor's to run; the GATEs are not yet mutation-qualified, and I did not
   execute any mutation as acceptance evidence.
3. **Bit-identity claims are single-machine.** "Exactly 0" residuals and all
   `identical()` results were observed on macOS arm64, R 4.5.2, Apple
   Accelerate BLAS — the same environment that generated the pinned
   references. Cross-platform (e.g. Linux/OpenBLAS CI) reproduction was not
   attempted; the GATE's 1e-10 tolerance is intended to absorb BLAS
   differences but this is unverified.
4. **Pre-existing test failures on this machine.** The 4 `test-ge7-lps-api.R`
   failures and 66 `test-graph-trend-filtering.R` warnings exist identically
   pre- and post-change (§6) but I did not diagnose their root cause; they
   may be environment-specific (conditioning thresholds under Accelerate).
   The gate battery itself is unaffected (0 failures, 0 warnings).
5. **The `cpp.local.pca` b≠1 guard inside `.klp.cv.table` is not directly
   exercised by a test.** The backend-coupling test exercises the
   `.klp.resolve.backend` error for explicit `cpp` and the auto→R resolution;
   the defensive `stop()` branches inside `.klp.cv.table` (both cpp tokens)
   and `.klp.predict.local.polynomial` (cpp) are reachable only by direct
   internal calls that bypass `fit.lps` and are untested.
6. **`b = 0` is accepted but degenerate.** Per the contract's "numeric ≥ 0" I
   allow 0; all weights then underflow to ~0 and the pre-existing
   all-zero-weight guard (flat weights) or `unstable.action` path engages.
   This behavior is inherited, not separately tested; spec memo §2 flags the
   alternative (require > 0) for the orchestrator.
7. **Small-`b` compact-kernel behavior is inherited, not gated.** For
   `b < 1`, compact kernels zero points beyond `b·h`, shrinking the effective
   solve support (zero-weight points are excluded by the existing `ok`
   filter); with very small `b` the flat-weight guard can engage. The benefit
   STUDY's `b = 0.5` arm will exercise this; no dedicated test pins it now.
8. **Concurrent-session interference occurred during this work.** While I
   worked in the shared main tree, a concurrent automation (a) committed v1
   of my in-flight scaffolding files to my branch (`de38a17`) and an E0.6
   patch (`609750b`, duplicating `b86b796`), and (b) committed near-identical
   copies of the same scaffolding to `codex/geosmooth-tier0-bucket2-isolated`
   (`3e40fe1`, including a reference file generated at `ba70fea` whose header
   commit does not contain the generating script). I then isolated E1.9 in
   the dedicated worktree, regenerated the references self-containedly at
   `fe582b1` (values bit-identical to the earlier generation), and restored
   the main tree to a clean state at its own HEAD. The duplicate scaffolding
   on the Tier-0 branch and the duplicated E0.6 patch remain to be reconciled
   at merge; the copies on the Tier-0 branch (memo v1, `ba70fea`-headed
   reference) are superseded by `fe582b1`/`c70ed5f` on this branch.
9. **`print.lps` output with a non-default multiplier is not
   snapshot-tested**; only the default-path byte-identity is implied by the
   b=1 GATEs (the new line prints only when the selected multiplier ≠ 1).
10. **Characterization margins are tied to the chosen fixed distance
    vector.** Other distance profiles give different ESS/K values (e.g.
    gaussian stays ≈ 0.98, tricube ranged 0.52–0.68 across profiles I
    probed); the GATE pins the committed vector only, and the epanechnikov
    last-weight margin (≈ 32×) depends on the additive
    `sqrt(.Machine$double.eps)` in the denominator.
11. **Runtime cost of multi-`b` grids was not measured.** The contract's
    runtime-reporting obligation attaches to the deferred STUDY/PROMOTION,
    but no timing of the enlarged candidate grid exists yet.
