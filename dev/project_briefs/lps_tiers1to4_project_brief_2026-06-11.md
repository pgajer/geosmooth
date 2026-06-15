# LPS Tiers 1–4 — Shared Project Brief

Date: 2026-06-11
Audience: the **implementer agent**, the **auditor agent**, and the orchestrator. Read this in full before touching code or writing an audit. It is context, not a contract — the binding gates live in the Tier 1–4 contract (§3) and the frozen spec.

Authoritative documents (read in this order):

1. Frozen science spec: `project_briefs/lps_experimental_plan_2026-06-09.tex` (Tiers 0–4, the DGP library, conventions).
2. Tier 1–4 contract (the tightening layer): `audit_contracts/lps_tiers1to4/lps_tiers1to4_contract_2026-06-11.md`.
3. Worker-auditor workflow + **Audit Charter**: `/Users/pgajer/.codex/notes/workflows/worker_auditor_workflow.md`.
4. Tier-0 execution-artifact contract (the pattern to reuse): `audit_contracts/lps_tier0/lps_tier0_execution_artifact_contract_2026-06-10.md`.

## 0. Roles and the orchestration model

| Role | Who | Mandate |
|---|---|---|
| **Orchestrator** | the human investigator + Claude | Owns the contract and scope; freezes gates; adjudicates audit findings and reasoned disagreements; approves contract amendments. The auditee never sets audit scope; the auditor never sets the implementer's plan. |
| **Implementer** | agent #1 | Designs, implements estimator features and tests/studies, runs validation, writes **factual** handoffs (evidence + admissions only). |
| **Auditor** | agent #2 | Independently audits per the Audit Charter; reproduces ≥1 number from raw outputs; tries to break the main claim; writes the verdict. Must not have authored the code under audit. |

Both agents may raise spec questions and objections — **in writing, to the orchestrator** — during a bounded spec-questions phase before implementing, and the auditor may flag an untestable/vacuous spec as a *finding*. Genuine issues become **versioned contract amendments** owned by the orchestrator, never ad-hoc reinterpretation and never settled between the two agents. Post-hoc threshold changes after results are seen invalidate the gate.

## 1. The estimator under development (LPS)

LPS (`fit.lps`) is **local weighted polynomial regression performed in local-PCA tangent charts** — manifold local polynomial regression. For a query point it selects a $K$-NN support, builds local coordinates (ambient, or a local-PCA chart of intrinsic dimension `chart.dim`), fits a weighted polynomial of `degree` in a chosen `design.basis`, and predicts. Selection over `(support, degree, kernel[, ...])` is by cross-validation on an explicit `foldid`.

Signature (defaults shown; **every non-default argument must be pinned in any gate/study**):

```r
fit.lps(X, y, foldid = NULL,
        support.grid = c(10L,15L,20L), degree.grid = 0:2,
        kernel.grid = c("gaussian","tricube"),
        cv.folds = 5L, cv.seed = 1L, X.eval = NULL,
        coordinate.method = c("coordinates","local.pca"),
        chart.dim = NULL,
        local.chart.method = c("pca","second.order.svd"),
        auto.chart.support.metric = c("coordinates","operator","both"),
        auto.chart.selection.metric = c("coordinates","operator"),
        backend = c("auto","R","cpp","cpp.local.pca"),
        design.basis = c("orthogonal.polynomial.drop","monomial","weighted.qr","weighted.qr.drop"),
        design.drop.tol = 1e-8,
        ridge.multiplier.grid = c(0,1e-10,1e-8), ridge.condition.max = 1e12,
        unstable.action = c("na","mean"),
        outcome.family = c("gaussian","bernoulli","binomial"))
# predict.lps(object, newdata = NULL, type = c("response","raw"))
```

Facts both agents will rely on (validated in Tier 0):

- **Linear smoother at a fixed configuration.** With singleton grids and numeric `chart.dim`, $\hat y = S y$ with $S$ independent of $y$; $\mathrm{df}=\operatorname{tr}S$. Never assert linearity on the CV-selected pipeline (the selected $\hat\theta(y)$ depends on $y$).
- **Outcome families.** `gaussian` (least squares); `bernoulli` (local least squares, predictions clipped to $[0,1]$, Brier/log-loss diagnostics); `binomial` (local logistic IRLS, **R backend only**). For binary modes `fitted.values` are probabilities in $[0,1]$; `NA` under `unstable.action="na"` is the sanctioned guarded output.
- **Backend constraints** (`.klp.resolve.backend`): `cpp`/`cpp.local.pca` require `design.basis="monomial"`, `ridge.multiplier.grid=0`, `ridge.condition.max=Inf`; anything else forces the R backend. `binomial` is R-only.
- **PS-LPS (`fit.ps.lps`) is OUT OF SCOPE** for this program (per the plan) — Tiers 1–4 concern LPS alone.

## 2. Code and asset inventory (exact paths)

- **Estimator:** `R/lps.R` (~2380 lines) — the object under test. `R/ps_lps.R` (~2362 lines, out of scope).
- **Tier-0 tests:** `tests/testthat/test-lps-tier0-correctness.R` (E0.1, E0.2 + a negative control), `…-extended.R` (E0.3a, E0.4, E0.5, E0.6, E0.7), `tests/testthat/test-lps-degenerate.R` (E0.8).
- **Execution harness/probe (reuse pattern):** `scripts/ci/run_tier0_execution_artifact.sh`, `scripts/ci/tier0_headroom_probe.R`.
- **CI:** `.github/workflows/tier0-gate.yml`.
- **Contracts & audits:** `audit_contracts/lps_tier0/` (execution-artifact contract, bucket-2 remediation response, 2026-06-11 re-audit).
- **Clean Tier-0 evidence:** `audit_artifacts/tier0_20260611T013246Z` (`cpp`), `…013248Z` (`cpp.local.pca`).
- **Frozen spec:** `project_briefs/lps_experimental_plan_2026-06-09.tex`.
- **DGP / synthetic-dataset assets** (for the gates' DGP library — see contract **Amendment 1**; *consolidate, do not rebuild*): generator helpers `make.flat.dataset()` / `make.quadform.dataset()` / `make.1d.dataset()` / `add.noise()` (`~/current_projects/trend_filtering/development/ssrhe_hessian_energy/ssrhe_order3_l1_validation_helpers.R`); mature quadform `quadform.sample.dataset()` (`~/current_projects/gflow/R/quadform_geodesics.R`); geosmooth's own `scripts/lps_binary_gm_ff_helpers.R` (binary surfaces + curved/native/high-dim geometries) and `scripts/freeze_lps_local_auto_nonmanifold_first_batch.R`; the frozen non-manifold spec + batch `split_handoffs/lps_local_auto_nonmanifold_dataset_specs_2026-06-05.md` (LA-* / SYN-* datasets, registry `FB01`–`FB14`, `…/lps_local_auto_nonmanifold_first_batch_2026-06-05/asset_manifest.csv`); the binary factorial manifest `split_handoffs/experiment_catalogue_20260608/lps_binary_gaussian_factorial_design_manifest.csv`; P7 dataset panels `…/k8_p7_lps_backend_panel_comparison_2026-06-04/tables/k8_dataset_panel.csv` and `…/k11_p7_lps_post_k10_backend_panel_2026-06-04/tables/k11_dataset_panel_spec.csv`; and the reference notes under `~/.codex/notes/references/{synthetic_datasets,quadforms,evaluation_datasets}/`.
- **Implementation history (branches):** `codex/geosmooth-ge0-skeleton → ge1-r-smoothers → ge2-{header-layout, native-lps-pca} → ge3-parity-smoke → ge4-ssrhe → ge5-graph-boundary → ge6-helper-cleanup → ge7-lps-api → ge8-remove-lps-alias → ge9-docs-examples`; current Tier-0 work on `codex/geosmooth-tier0-bucket2-isolated`.

## 3. The frozen science spec (what Tiers 1–4 test)

The plan uses an eight-field template per item — **Claim / Failure mode / DGP / Configuration / Statistic / Acceptance / Validity safeguards / Artifacts** — and distinguishes **Tests** (deterministic `testthat`, must pass in CI) from **Studies** (scripted experiments with predeclared decision rules emitting a machine-readable verdict row).

**DGP library (G-tags; defined once in the plan §sec:dgp):** G1 ambient polynomial; G2 flat embedded subspace; G3a paraboloid (known curvature), G3b sphere cap, G3c 1-D helix, G3d torus patch; G4 stratified/varying-dimension; G5 clustered/repeated-measures; G6 binary surface (prevalence-controlled, clipped to $[0.05,0.95]$); G7 compositional/structural-zeros. Each gate references a tag and overrides only named parameters.

**Tier map (9 gates, Tiers 1–4):**

- **Tier 1 — honest selection & bandwidth.** E1.9 decouple bandwidth from support size (bandwidth multiplier $b$); E1.10 nested + grouped CV; E1.11 stabilize the local intrinsic-dimension estimate.
- **Tier 2 — binary path & numerical hygiene.** E2.12 binary selection-metric consistency + log-loss clipping; E2.13 ridge-penalty structure alignment; E2.14 local logistic robustness under separation.
- **Tier 3 — curvature chart, done right.** E3.1 curvature-chart benefit (degree-1, low-noise, curvature-stratified); E3.2 curvature-bias unit test (theory-anchored $O(\kappa h^2)$).
- **Tier 4 — uncertainty.** E4.1 pointwise variance $\sigma^2\sum_j S_{ij}^2$ and confidence-band coverage.

**Dependency/order (plan §execution order):** Tier 0 first (gates). Tier 1 next (selection/bandwidth underlie every downstream accuracy number; E1.10 before any Truth-unknown real-data claim). **Tier 2 runs in parallel with Tier 1** (independent code paths). Tier 3 depends on E0.1 + the matched-arm protocol; E3.2 on E0.2's bias-extraction style. Tier 4 depends on E0.2 ($S$) and E0.5 (rate).

## 4. Tier-0 status and results (the validated base)

Tier 0 (E0.1–E0.8) is **implemented and smoke-accepted** by the independent auditor (2026-06-11 re-audit). Clean-tree smoke evidence at the reviewed commit, both backend tokens:

- `tests=16 failed=0 error=0 warning=0 skipped=1` (the one skip is the sanctioned E0.3a deferral); gate coverage `E0.1…E0.8`.
- E0.1 max reproduction error `3.3e-15` at `~3.0e6×` headroom; E0.2 identity residual `4.4e-16`, df residual `0`; determinism `0`; backend parity `ok` (`cpp` diff `2.2e-16`, `cpp.local.pca` diff `0`); checksums match; `tree_clean: true`.

**Not yet final-accepted (Phase-0 freeze gates, do not block starting Tier 1):** (1) at least one clean `LPS_TIER0_FULL=1` artifact for both tokens (the full-size E0.5/E0.6 accuracy studies); (2) the mutation/falsification table — **the auditor runs this**, not the implementer, since the implementer authored the gates. Treat Tier 0 as *smoke-accepted, release-pending*.

**Reuse the Tier-0 execution-artifact pattern for every Tier 1–4 gate:** a harness that runs against a **clean, committed** tree and emits a tamper-evident bundle (git head, `tree_clean`, source checksums, `sessionInfo`, per-test results, gate coverage, realized quantities), which the auditor reviews instead of a console "green." Tier 0 also emits the reusable toolkit the later tiers consume: empirical $S$ extraction, $\operatorname{tr}S$/df, and the headroom/determinism/parity probe (E4.1 builds directly on $S$).

## 5. Two-agent workflow and Audit Independence (non-negotiable)

The six cardinal rules (full text in the workflow file): (1) the auditee never sets audit scope; (2) the handoff is evidence, not an agenda — no audit questions, no suggested verdict; (3) the charter is a floor the handoff cannot subtract from; (4) authorship independence — the auditor did not write the code/scripts/tables under audit and reproduces ≥1 end-to-end number from raw outputs; (5) falsification duty — stratify the headline by every quality flag (fallback/convergence/degeneracy), test for hidden interactions/sign reversals, re-run inference under a more conservative dependence assumption; (6) verdict independence — a clean-looking report is never evidence of correctness. If independence can't be met, the work is **unaudited** and the orchestrator must be told.

**Audit Charter layer order (audit data → report, never stop at the first clean layer):** data-generating process → measurement → estimation/selection fairness → statistical inference → artifacts/provenance → estimator/implementation correctness → rendering (last and least).

**Isolation lesson (carry forward):** to run a gate on a clean tree, **commit unrelated work to a WIP branch — do not `git stash --include-untracked`.** A dropped stash loses untracked work; a WIP commit cannot.

## 6. Conventions every gate/study must honor

- **RNG:** `set.seed` immediately before each stochastic draw; replicate $r$ uses seed $s_0+r$; **always** pass `foldid` explicitly (never rely on `cv.seed`); same `foldid` to both arms of a paired comparison.
- **Tolerances:** algebraic identities `1e-10`; reproduction `1e-8` (orthogonal/QR) or `1e-6` (monomial, with the realized condition number reported); IRLS convergence `1e-7`, comparison `1e-6`; Monte-Carlo quantities use a CI/test with $R$ chosen so MC standard error `< (decision threshold)/3` (state the power calc in the script header).
- **Evidence bundle (mandatory):** `sessionInfo()`, `geosmooth` version + git commit hash, BLAS/LAPACK id, full argument list of every `fit.lps` call, seeds. A study artifact lacking these is invalid and re-run.
- **Sub-item typing (defined in the contract):** **GATE** = deterministic CI pass/fail; **STUDY** = predeclared decision rule, verdict recorded but not a CI failure; **PROMOTION** = orchestrator/human decision to move a feature beyond "experimental." Mutation-qualification is required for every correctness GATE.
- **Smoke vs full:** CI runs smoke sizes; release acceptance runs the frozen-spec full sizes (the contract pins both).

## 7. Naming and directory conventions

- Contracts: `audit_contracts/lps_tiers1to4/…`. Per-phase implementer handoffs: `phase_handoffs/<gate>_implementer_handoff_<date>.md` (facts + a mandatory "Limitations and unverified claims" section). Audits: `audits/<gate>_implementation_audit_<date>.md`; responses: `audits/<gate>_implementation_audit_response_<date>.md`. Execution bundles: `audit_artifacts/<gate>_<UTC>/`. Tests: `tests/testthat/test-lps-<feature>.R`. Study scripts/reports: `validation/` and `reports/` per the workflow.
