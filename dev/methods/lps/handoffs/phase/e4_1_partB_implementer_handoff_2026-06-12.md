# E4.1 Part B — Implementer handoff (acceptance run executed at the ratified K = 20)

Date: 2026-06-12
From: implementer agent (E4.1, Tier 4 — uncertainty), worktree
`~/current_projects/geosmooth-t4`, branch `codex/geosmooth-t4-uncertainty`
Scope: the **Part B coverage acceptance run** (contract §E / E4.1: interior
coverage GATE, known σ and plug-in σ̂; stratified boundary/curvature STUDY) at
the orchestrator-ratified configuration. Part A was separately delivered and
audit-accepted (`audits/e4_1_partA_audit_2026-06-11.md`, tracked at
`0a21eba`).

## 1. Ratified configuration and its provenance chain

- Spec-questions resolution (orchestrator, 2026-06-12):
  `audit_contracts/tiers1to4/e4_1_spec_questions_resolution_orchestrator_2026-06-12.md`
  (committed `a809511`) — pinned kernel `tricube`, DGP row
  `G3a-R1-smooth-s010-n1200`, conditional-on-design coverage, fast path with
  drift guards; required a K calibration before acceptance.
- K calibration + proposal (implementer, 2026-06-12):
  `audit_contracts/tiers1to4/e4_1_k_calibration_proposal_2026-06-12.md`
  (committed `6e717c3`); calibration artifacts
  `dev/methods/lps/audit_artifacts/e4_1_k_calibration_20260612T192750Z/`, confirmatory smokes
  `dev/methods/lps/audit_artifacts/e4_1_kcal_smoke_K22/`, `…_K20/`.
- K ratification (orchestrator, 2026-06-12): **K = 20** —
  `audit_contracts/tiers1to4/e4_1_k_ratification_orchestrator_2026-06-12.md`
  (verbatim copy of the orchestrator's document, SHA-256
  `f0b5fdeb…23dd34`, committed `0f2c086`). The K was selected from the
  pre-declared calibration **before** the acceptance run and ratified in
  writing; the acceptance thresholds were never touched.
- DGP binding: `validation/e4_1_g3a_binding.R` loads `R/dgp_library.R` from
  the audit-accepted DGP-library commit
  `58f5ab93b433b73d60c291fc6daebd53644054e8`, materializes
  `dgp.materialize("G3a", list(n=1200L, R=1, truth="smooth", sigma=0.10,
  seed=1L))`, and hard-verifies `dgp.content.sha256()` against the frozen
  registry value
  `b5a2e07699378e74eecbeeef5fb2b1108e3701a43601c4623babb81a9d204614`
  (mismatch is a stop, not a warning). Verification result in this run:
  `TRUE`.
- Acceptance driver: `validation/e4_1_acceptance_run.R` pins every ratified
  argument in version control; only `out.dir` and `fit.every.replicate` are
  overridable (anything else errors).

## 2. Files changed since the Part A handoff

Commits `a809511` (resolution record, binding, calibration), `6e717c3`
(K proposal), `0a21eba` (auditor's Part A verdict tracked verbatim),
`0f2c086` (ratification record; study emits realized interior mean/max
bias-to-se into verdict rows, strata table, per-point CSV, and console
summary; acceptance driver; harness `E4_ACCEPT` leg + manifest fields).
**No package R/C++ source changed since the Part A delivery** —
`R/lps_uncertainty.R`, `R/lps.R`, and `NAMESPACE` are untouched since
`7e4bd61`; all Part B changes are `validation/` scripts, the CI harness, and
`audit_contracts/` records.

## 3. Exact commands run (this phase)

```sh
# calibration + confirmatory smokes (pre-ratification, sanctioned)
Rscript validation/e4_1_k_calibration.R
Rscript -e 'source("validation/e4_1_k_calibration.R"); lib <- e41.load.audited.dgp.library(); fn <- e41.audited.g3a.dgp.fn(lib); for (K in c(22L, 20L)) run.e4.1.coverage.study(n=1200L, R.replicates=100L, sigma=0.1, support.size=K, kernel="tricube", curvature.radius=1, geometry.seed=1L, dgp.fn=fn, dgp.source="amendment1-g3a (K-calibration smoke)", out.dir=paste0("dev/methods/lps/audit_artifacts/e4_1_kcal_smoke_K", K))'
# study-schema shakeout (tiny, inline)
Rscript validation/e4_1_coverage_study.R n=200 R.replicates=5 support.size=15 drift.check.every=3 out.dir=dev/methods/lps/audit_artifacts/e4_1_dev_tiny2
# ACCEPTANCE bundle (clean committed tree, ratified config)
EXECUTOR="implementer-agent-e4.1@geosmooth-t4" E4_ACCEPT=1 E4_SMOKE=0 bash scripts/ci/run_e4_1_execution_artifact.sh
```

## 4. Acceptance execution bundle

`dev/methods/lps/audit_artifacts/e4_1_20260612T195644Z/` at git head
`0f2c086210b7a8ba5d1862b650e60f99ad233706`, `tree_clean: true`,
`accept_rc: 0`, `accept_context: acceptance-candidate`,
`accept_dgp_source: amendment1-g3a`, executor
`implementer-agent-e4.1@geosmooth-t4`. The manifest records the ratified
configuration line
(`K=20 kernel=tricube dgp=G3a-R1-smooth-s010-n1200 design_seed=1 n=1200
R=500 sigma=0.1 known`), the realized interior mean/max bias-to-se, both
interior coverages, and the three strata rows, as the ratification requires.
The bundle also re-runs the Part A gate battery
(`tests=5 failed=0 error=0 warning=0 skipped=0`, `gate_contexts: E4.1`) and
the headroom probe (`max_S_diff=5.551e-17`, headroom `1.8e6×`,
determinism `0`) at the acceptance commit. The acceptance study leg is under
`acceptance_study/` inside the bundle (results RDS, verdict rows, stratified
summary, per-point CSV, drift-guard table, console summary), all covered by
`BUNDLE_CHECKSUMS.txt`.

## 5. Numerical findings

**GATE results (interior average coverage; n = 1200, R = 500, frozen design
seed 1, replicate-noise seeds 20260611 + r):**

- Known σ = 0.1: **0.9418** ∈ [0.93, 0.97] → **pass**
  (margin +0.0118 over the lower bound; empirical interior-average MC-SE
  0.0007; the calibration's deterministic prediction was 0.9416).
- Plug-in σ̂: **0.9353** ∈ [0.92, 0.98] → **pass** (MC-SE 0.0008). Plug-in
  coverage is slightly below known-σ coverage (−0.0065).

**Realized bias-to-se at the ratified K (deterministic, recorded in the
manifest):** interior mean 0.2162, interior max 0.9133; df = tr S = 200.392.

**STUDY (strata reported separately, never averaged into the interior
headline; known σ / plug-in):**

| stratum | n | coverage known | coverage plug-in | mean bias/se | max bias/se | min per-point cov (known) |
|---|---|---|---|---|---|---|
| interior | 872 | 0.9418 | 0.9353 | 0.216 | 0.913 | 0.842 |
| boundary-within-h | 328 | 0.9380 | 0.9312 | 0.248 | 1.007 | 0.828 |
| top-curvature decile | 120 | 0.9427 | 0.9366 | 0.219 | 0.873 | 0.858 |

Boundary undercoverage magnitude at this configuration: −0.0038 (known)
relative to the interior average, −0.012 relative to the 0.95 nominal; the
top-curvature decile covers at the interior level. Worst single points sit
at 0.842 (interior) and 0.828 (boundary) per-point coverage, consistent with
the deterministic per-point bias/se tail.

**Fast-path integrity:** 21 drift guards (replicates 1, 25, …, 500): max
absolute fitted-value discrepancy ≤ 5.6e-16, band-endpoint discrepancies ≤
6.7e-16, df discrepancy 0 — the S-path and the full
`fit.lps` + `lps.pointwise.band` pipeline agree far below the 1e-10 guard.

## 6. Whether package source was modified; whether tests were run

No package source changed in this phase (§2). The E4.1 gate battery and
probe are green in the acceptance bundle at `0f2c086`. The full package
suite was **not** re-run for Part B: no `R/` code changed since `7e4bd61`,
and the Part A handoff's finding stands — `make test` is red solely from 4
pre-existing `test-ge7-lps-api.R` failures present at base `b86b796`
(verified there in a pristine worktree on 2026-06-11), unrelated to E4.1.

## 7. Limitations and unverified claims

1. **Per-point worst-case coverage is not protected at any K** (variance-only
   band on a curved truth): interior max bias/se is 0.913 at the ratified
   K = 20, and the worst interior point covers at 0.842 across R = 500.
   The orchestrator's disposition stands: the gate is the interior
   *average*; the bias-corrected band is deferred as a future extension
   ("E4.2 — bias-corrected pointwise band") and is **not** part of this
   deliverable.
2. **The fast path was verified at 21 of 500 replicates** (the ratified
   guard schedule), not at every replicate. `fit.every.replicate = TRUE` is
   available and was not exercised at acceptance scale by me.
3. **K was chosen using the same frozen design** the acceptance run uses
   (the calibration is deterministic on that design). This was the
   orchestrator's pre-declared, ratified procedure — calibration before
   acceptance, thresholds untouched — but the K is design-informed by
   construction, and the coverage result should be read as conditional on
   this frozen design, not as a claim across G3a re-draws.
4. **The MC noise stream and the frozen row's noise stream differ by
   design:** the registry row's `y` (seed 1 + offset) is consumed only by
   the SHA-256 verification; replicate noise uses seeds 20260611 + r per
   the RNG convention. The first replicate is therefore not the registry
   row's `y`.
5. The bundle manifest's static `gate:` header line still reads "Part B
   smoke leg is wiring evidence only" — written when the smoke leg was the
   only Part B leg. The acceptance status is carried by the explicit
   `accept_*` manifest fields (`accept_context: acceptance-candidate`);
   the static line is stale wording, left untouched because editing the
   harness after the run would unbind the bundle from its commit.
6. The plug-in variant's lower coverage (0.9353 vs 0.9418) is reported as
   observed; I have not decomposed how much comes from σ̂'s finite-sample
   distribution versus the bias inflation of RSS, beyond noting both gates
   pass.
7. Dev/calibration artifacts under `dev/methods/lps/audit_artifacts/` other than the
   acceptance bundle were produced at interim tree states; each records its
   own provenance and is reproducible from committed scripts and recorded
   seeds. Only `dev/methods/lps/audit_artifacts/e4_1_20260612T195644Z/` is the acceptance
   evidence bundle.
8. I have not run any mutation of the coverage gate or the variance formula
   as acceptance evidence (authorship independence; mutation-qualification
   belongs to the auditor).
