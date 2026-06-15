# LPS Tiers 1–4 — Implementation & Validation Contract

Date: 2026-06-11
Owner: orchestrator (human investigator + Claude). Status: **frozen at issue**; changes are versioned amendments (§H).

This contract **layers on** the frozen science spec `dev/methods/lps/specs/lps_experimental_plan_2026-06-09.tex` (the source of truth for each gate's Claim / DGP / Statistic / Acceptance / Safeguards). It does **not** restate the science; it supplies the four things the plan leaves open and that an implementer needs to proceed without fuzziness:

1. the **API of each new estimator feature** a gate presupposes;
2. the **execution-discipline layer** (asset/G-library bindings, evidence bundle, smoke/full sizing);
3. **sub-item typing** — every acceptance item is exactly one of **GATE**, **STUDY**, **PROMOTION**;
4. the **mutation-qualification** requirement for correctness gates.

Read with the shared brief: `project_briefs/lps_tiers1to4_project_brief_2026-06-11.md`.

## A. Conventions binding every gate

**A1. Typing.** **GATE** = deterministic `testthat` assertion that must pass in CI (pass/fail). **STUDY** = scripted experiment with a predeclared decision rule; emits a one-row machine-readable verdict; a "negative" verdict is recorded, not a CI failure. **PROMOTION** = an orchestrator/human decision to move a feature beyond "experimental"; never automatic.

**A2. New-feature API discipline.** Every new argument or behavior change must (i) have a default that **reproduces current behavior bit-for-bit** (regression-pinned by a GATE), (ii) be documented in the `fit.lps` roxygen, (iii) surface any new diagnostic in the return object under a named field. API names below are **orchestrator proposals**; the implementer may counter-propose via amendment (§H) before implementing, but not change them silently.

**A3. Evidence bundle (every GATE and STUDY).** Reuse the Tier-0 harness pattern (`scripts/ci/run_tier0_execution_artifact.sh`): run on a **clean, committed** tree; emit git head, `tree_clean`, source checksums, `sessionInfo`, BLAS id, full `fit.lps` arg lists, seeds, per-test results, and realized quantities. The auditor reviews the bundle, not a console line.

**A4. Smoke vs full.** CI runs **smoke** sizes (below); **release acceptance** runs the frozen-spec **full** sizes, gated behind `LPS_TIERS_FULL=1`. Both are pinned per gate; smoke must never silently stand in for full.

**A5. Mutation-qualification (correctness GATEs only).** A correctness GATE is accepted only after the auditor confirms it **turns red** under the named mutation (break the feature → the gate must fail). The implementer may not run their own mutation as acceptance evidence (authorship independence).

**A6. Matching (every STUDY that compares arms).** Hold fixed across arms: geometry $X$, truth, realized $y$ (same noise draw), `foldid`, and all of `(support, degree, kernel, chart.dim)` except the single axis under study. Report median $\Delta$ with a paired test (sign-test/Wilcoxon) and the full per-case table; pooled summaries must be stratified by every quality flag (fallback/convergence/degeneracy).

## B. Tier 1 — honest selection & bandwidth

### E1.9 — Decouple bandwidth from support size
- **Implements (new API, proposed):** `bandwidth.multiplier.grid = 1` (numeric ≥ 0; default `1` reproduces current behavior). Effective bandwidth $h = b\cdot(K\text{-th NN distance})$; added to the CV selection grid; selected value returned in `$selected$bandwidth.multiplier`.
- **Binds to:** `R/lps.R` kernel-weight routine (implementer confirms the exact internal symbol, e.g. `.klp.*weight*`, in the handoff — see §G1); the characterization test must call that **actual** routine, not a re-implementation.
- **Sub-items & type:** (a) ESS/K + last-weight characterization — **GATE** (pins current behavior). (b) `b=1` backward-compat exactness — **GATE**. (c) selection over $(K)$ vs $(K,b)$, $b\in\{0.5,1,2,4\}$ — **STUDY → PROMOTION**.
- **Frozen thresholds:** ESS$/K>0.9$ (`gaussian`), $<0.85$ (`tricube`), $w_{(K)}/\max_j w_j<10^{-6}$ (compact kernels); `b=1` fits equal current within $\tau_{\mathrm{alg}}=10^{-10}$; promote iff median $\Delta$ Truth-RMSE $>5\%$ with Wilcoxon $p<0.05$ **and** runtime reported.
- **Smoke/full:** benefit STUDY on G3a/G3d, $n=600$, $\sigma\in\{0.03,0.1\}$; $R$: smoke 8, full 30.
- **Mutation (for b1 GATE):** perturb the multiplier application so `b=1`≠current → GATE reddens.
- **Deps:** none (Tier-1 entry). Note E1.9's $b$ is a prerequisite for reaching curvature scale in Tier 3.

### E1.10 — Nested and grouped cross-validation
- **Implements:** a validation utility `validation/e1_10_nested_grouped_cv.R` (outer 5-fold / inner 5-fold nested CV; grouped `foldid` by cluster id). No `fit.lps` signature change (uses explicit `foldid`).
- **Sub-items & type:** (a) nested-CV corrects selection optimism — **STUDY** (numeric acceptance, verdict recorded). (b) leave-cluster-out closes the random-fold gap — **STUDY**.
- **Frozen thresholds:** (a) nested relative error $<0.10$ **and** nested $\ge$ selected-min in expectation (optimism sign correct); (b) random-fold relative error exceeds cluster-fold by $>0.10$ at $\rho=0.6$, and cluster-fold within $0.10$ of fresh-cluster test error.
- **Smoke/full:** (a) G3a, $n=800$ train + 4000 test; (b) G5, $K=40$, $m=20$, $\rho\in\{0.3,0.6\}$, disjoint test clusters; $R$: smoke 10, full 40.
- **Deps:** must be in place before any Truth-unknown real-data claim (Tiers 3–4 real-geometry probes).

### E1.11 — Stabilizing the local intrinsic-dimension estimate
- **Implements (proposed):** `chart.dim.stabilizer = c("none","shrink.global","knn.vote")` (default `"none"` = current) as a post-processor of `chart.dim.by.eval`; plus a **points-per-parameter gate** that assigns a non-finite/penalized CV score to a degree-2 candidate whose $K < 1.5\,c_2$ (with $c_2=1+d+\binom{d+1}{2}$).
- **Sub-items & type:** (a) per-anchor variance decay with $K$ — **STUDY** (characterization). (b) a stabilizer reduces homogeneous misclassification without smearing the G4 boundary — **STUDY → PROMOTION**. (c) the points-per-parameter gate blocks degree-2-in-high-dim — **GATE** (with positive control: without the gate, the candidate is selectable).
- **Frozen thresholds:** (b) homogeneous misclassification reduced $>30\%$ at $K=10$ **and** G4 boundary-straddling misclassification not worsened by $>5$ percentage points **and** Truth-RMSE non-inferior (CI of $\Delta$ excludes a $>2\%$ degradation); (c) offending candidate receives a non-finite score with the gate, selectable without it.
- **Smoke/full:** G3a ($d=2$), $n\in\{200,800\}$, $K\in\{10,20,40\}$; G4 boundary test **mandatory**; $R$: smoke 12, full 50.
- **Mutation (for the (c) GATE):** disable the points-per-parameter penalty → the degree-2-in-high-dim candidate becomes selectable (gate reddens).
- **Deps:** none (Tier-1 entry); the G4 boundary safeguard is non-waivable.

## C. Tier 2 — binary path & numerical hygiene (parallel to Tier 1)

### E2.12 — Binary selection-metric consistency & log-loss clipping
- **Implements:** Bernoulli-mode selection scores the **deployed (clipped)** metric; pin the log-loss truncation at $10^{-6}$ (from $10^{-15}$).
- **Sub-items & type:** (a) selection score == deployed clipped metric — **GATE** (pre-fix discrepancy demonstrated in the same file as a documented motivating case). (b) adopt-and-pin clip $10^{-6}$ — **GATE**; cross-clip selection stability over $\{10^{-6},10^{-3}\}$ — **STUDY** (reported, **not gated**: near-ties may legitimately reselect).
- **Frozen thresholds:** (a) post-fix equality within comparison tolerance $10^{-6}$; (b) demonstrate the $10^{-15}$ score is dominated by a single confident-wrong point; pin $10^{-6}$.
- **Smoke/full:** constructed G6 cases ($n=400$); deterministic — no replication.
- **Mutation (for (a)):** revert to scoring unclipped predictions → the constructed ranking-flip case reddens the gate.
- **Deps:** none.

### E2.13 — Ridge-penalty structure alignment
- **Implements:** in the orthogonal basis, **leave the constant direction unpenalized**, so large ridge shrinks toward the local weighted mean, not toward $0$.
- **Sub-items & type:** (a) large-ridge shrinks to local weighted mean — **GATE**; (b) tiny-ridge prediction-invariance — **GATE**. A pre-fix test documents the shrink-to-zero behavior.
- **Frozen thresholds:** with `design.basis="orthogonal.polynomial.drop"`, `ridge.condition.max=Inf`, singleton $\rho\in\{0,10^{-8},10^{-2},1,10^2\}$: $|\hat f_{\rho=10^2}-\bar y^{w}|$ small relative to $|\hat f_{\rho=10^2}-0|$; $|\hat f_{\rho=10^{-8}}-\hat f_{\rho=0}|<10^{-6}$.
- **Smoke/full:** G1, $D=2$, $n=150$; deterministic.
- **Mutation:** revert the alignment (penalize the constant) → large-ridge shrinks toward 0, gate (a) reddens.
- **Deps:** none. (Note: this interacts with the Tier-0 default `unstable.action`/ridge settings; coordinate the default change with the orchestrator.)

### E2.14 — Local logistic robustness (separation)
- **Implements:** IRLS **step-halving**; deterministic, **telemetered** fallback on non-convergence (`converged`, `fallback.path`, `event.rate.fallback`).
- **Sub-items & type:** deviance monotonicity + bounded output + fallback behavior — **GATE** (assert on the deviance **trajectory**, not just the endpoint).
- **Frozen thresholds:** with step-halving, per-step deviance non-increasing to within $10^{-8}$; final $\hat p\in(0,1)$, $|\hat\beta|<\infty$; on non-convergence within the iteration cap the documented fallback fires and is recorded; **exact** separation hits the fallback (no loop/NaN).
- **Smoke/full:** single near-separable support ($+1$ flipped label) and the exactly-separable case; deterministic.
- **Mutation:** disable step-halving → deviance trajectory becomes non-monotone under near-separation, gate reddens.
- **Deps:** binary path is R-backend only.

## D. Tier 3 — curvature chart, done right
*Tier-entry note:* Tier 3 starts only after E0.1 is final-accepted and E1.9 (bandwidth multiplier) has landed (reaching curvature scale needs $b$). The $K$-sweeps and curvature-knob settings below are **frozen at Tier-3 entry**, re-confirmed against the then-current estimator.

### E3.1 — Curvature-chart benefit (degree-1, low-noise, curvature-stratified)
- **Implements:** uses the existing `local.chart.method="second.order.svd"`; no new feature, but **matched** arms differing only in `local.chart.method` ∈ {`pca`,`second.order.svd`}, fixed degree $=1$, `chart.dim`=true $d$, $K\ge 3q_2$ ($q_2=d+\binom{d+1}{2}$; $d=2\Rightarrow K\ge20$, sweep $K\in\{25,40,60\}$); plus a degree-2+`pca` reference arm.
- **Sub-items & type:** high-curvature-decile benefit — **STUDY → PROMOTION**; degree-1+2nd ≈ degree-2+pca redundancy — **STUDY** (reported).
- **Frozen thresholds (promotion):** median over cases of $\Delta^{\mathrm{hi}}=\rmse^{\mathrm{hi}}_{\mathrm{pca}}-\rmse^{\mathrm{hi}}_{\mathrm{2nd}}>10\%$ relative with sign-test $p<0.05$, **and** runtime ratio reported, **and** fallback rate (chart dim = ambient / rank-deficient) $<10\%$ in the promoted regime.
- **Smoke/full:** G3a/G3b/G3d, low/high curvature, $n\in\{400,1600\}$, $\sigma\in\{0.01,0.03\}$; $R$: smoke 8, full 30; plus the VALENCIA-derived real-geometry probe as an external check.
- **Deps:** E0.1, E1.9, matched-arm protocol (§A6).

### E3.2 — Curvature-bias unit test (theory-anchored)
- **Implements:** correctness test of the curvature correction (no new feature).
- **Sub-items & type:** $O(\kappa h^2)$ scaling and leading-term removal — **GATE** (correctness).
- **Frozen thresholds:** noiseless G3a, $f_{\mathrm{lin}}(u)=u_1$, $\kappa=1/R$, $R\in\{1,2,4,8\}$, $h$ fixed across $R$: $|\bar\beta_{\mathrm{pca}}|$ vs $\kappa h^2$ slope significantly $>0$ with $R^2>0.9$, and $|\bar\beta_{\mathrm{2nd}}|/|\bar\beta_{\mathrm{pca}}|<0.3$ at highest curvature.
- **Mutation:** replace the second-order correction with a no-op (return the pca chart) → the ratio stays $\approx 1$, gate reddens.
- **Deps:** E0.2 bias-extraction style.

## E. Tier 4 — uncertainty
*Tier-entry note:* starts after E0.2 final-accepted and E0.5 (rate). Reuses the Tier-0 $S$-extraction toolkit.

### E4.1 — Pointwise variance & confidence-band coverage
- **Implements:** band $\hat y_i\pm z_{0.975}\,\hat\sigma\,\lVert S_{i\cdot}\rVert_2$, $\hat\sigma^2=\mathrm{RSS}/(n-\tr S)$, from the extracted $S$ (fixed config, singleton grids, `chart.dim=2`, degree 1).
- **Sub-items & type:** interior coverage — **GATE** (known $\sigma$) / **STUDY** (plug-in $\hat\sigma$); boundary & high-curvature coverage — **STUDY** (reported stratified, **never** averaged into the interior headline).
- **Frozen thresholds:** interior average coverage $\in[0.93,0.97]$ (known $\sigma$), $\in[0.92,0.98]$ (plug-in); boundary/high-curvature undercoverage reported with magnitude.
- **Smoke/full:** G3a, $\sigma=0.1$ known, $n=1200$; $R$: smoke 100, full 500 (full gives coverage MC-SE $\approx0.01$).
- **Mutation:** use a wrong variance (e.g. drop the $\sum_j S_{ij}^2$ term, use a constant) → interior coverage leaves $[0.93,0.97]$, gate reddens.
- **Deps:** E0.2 ($S$), E0.5 (rate).

## F. Per-gate acceptance checklist (the gate format)

A Tier 1–4 gate is **accepted** only when, on a clean committed tree: (1) all its **GATE** sub-items pass with the evidence bundle (§A3); (2) every correctness GATE is **mutation-qualified** by the auditor (§A5); (3) **STUDY** items have a recorded verdict row with safeguards met (a study whose safeguards were not met is *inconclusive*, never evidence); (4) **PROMOTION** items are decided by the orchestrator with runtime + fallback accounting; (5) an independent auditor pass against the Audit Charter exists. *Report rendered ≠ data valid ≠ gate accepted.*

## G. Open spec-questions seeded for the agents (express opinions here)

These are genuine ambiguities the orchestrator wants the implementer/auditor to resolve **in writing, as amendment proposals**, during the spec-questions phase — not silently:

1. **Kernel-weight routine — RESOLVED.** E1.9's characterization GATE must call `geosmooth:::.klp.kernel.weights(distances, kernel)` (`R/lps.R:2366`; the LPS `.klp.` namespace — **not** the sibling `.malps.kernel.weights` / `.lpl.tf.kernel.weights` / `.slpl.tf.inclusive.kernel.weights` of other methods). It supports `gaussian` / `tricube` / `epanechnikov` / `triangular`, and sets bandwidth `h = max(distances)` (= the K-th NN distance) with `u = distances/h`, so it directly evidences E1.9's premise that bandwidth is tied to support size. The multiplier `b` enters by replacing `h` with `b·h` at `R/lps.R:2370`; weights are returned **unnormalized** (the WLS solve normalizes), so `b` cleanly rescales the bandwidth (this also answers §G5). The C++ backend has its own kernel (`rcpp_kernel_local_polynomial_*`, `R/RcppExports.R`); the R characterization runs on the R routine.
2. **DGP library — RESOLVED (see Amendment 1).** The generators are *not* a green-field build: most already exist — flat / quadform / 1-D / binary / compositional — partly in geosmooth's own scripts and partly as reusable helpers in `gflow` / `trend_filtering`, plus a frozen non-manifold batch (`FB01`–`FB14`) and registries. The data-enabler is a **consolidate-and-bind** task, scoped as **Amendment 1**; it remains a prerequisite for every STUDY but is not green-field. E1.9 is *not* blocked — its G3a/G3d generators already exist.
3. **E1.11 stabilizer surface:** a `fit.lps` argument vs a standalone post-processor utility — which fits the codebase better?
4. **E2.13 / Tier-0 default coupling:** the ridge alignment touches defaults the Tier-0 audit already flagged; confirm the intended default state before changing it.
5. **Bandwidth multiplier vs existing kernel semantics** (E1.9): confirm $h=b\cdot(K\text{-NN distance})$ composes correctly with each kernel's existing normalization.

## H. Amendment process

Any change to an API name, threshold, sizing, or typing is a numbered amendment appended here with date and rationale, approved by the orchestrator. The contract version is this file's git commit. An artifact generated under an older version is read against the version in force at its timestamp.

### Amendment 1 — DGP library: consolidate existing generators, do not build from scratch (2026-06-11)

Resolves §G2. The shared DGP library is the program's cross-cutting data enabler and is a prerequisite for every STUDY, but the build is a **consolidation**, not green-field. **Deliverable** (its own implementer handoff + independent audit, before any Tier-1/2 STUDY consumes it): a geosmooth-local, plan-conformant DGP module (e.g. `R/dgp_library.R`) exposing **one function per plan G-tag** with the plan's exact parametrization, each emitting the standard dataset object (intrinsic `U`/`Z`, observed `X`, noiseless `truth`, noisy `y`, `seed`, region labels — per the non-manifold spec's common contract), plus a **frozen registry** with seeds and SHA-256 checksums (reuse the Tier-0 evidence-bundle discipline).

**Consolidate these existing assets (do not reinvent):**

- Helpers (`~/current_projects/trend_filtering/development/ssrhe_hessian_energy/ssrhe_order3_l1_validation_helpers.R`): `make.flat.dataset()`, `make.quadform.dataset()`, `make.1d.dataset()`, `quadform.embed()`, `coeff.base()`, `add.noise()` (homoskedastic / heteroskedastic / Laplace+outliers).
- Mature quadform (`~/current_projects/gflow/R/quadform_geodesics.R`): `quadform.sample.dataset(n,dim,index.k,domain.shape,curvature,…)`.
- geosmooth's own: `scripts/lps_binary_gm_ff_helpers.R` (binary surfaces + curved/native/high-dim geometries); `scripts/freeze_lps_local_auto_nonmanifold_first_batch.R`.
- Frozen non-manifold spec + batch: `split_handoffs/lps_local_auto_nonmanifold_dataset_specs_2026-06-05.md` (datasets LA-D1/D2/D3-RAW/HC, LA-13K-SUB; SYN-PARA-LINE, SYN-SADDLE-LINE, SYN-TWO-PLANES, SYN-SIMPLEX-FACES, SYN-RANK-BLOCKS, …; registry `FB01`–`FB14` + `split_handoffs/lps_local_auto_nonmanifold_first_batch_2026-06-05/asset_manifest.csv` with SHA-256).
- Binary factorial + panels: `split_handoffs/experiment_catalogue_20260608/lps_binary_gaussian_factorial_design_manifest.csv`; `split_handoffs/k8_p7_lps_backend_panel_comparison_2026-06-04/tables/k8_dataset_panel.csv`; `split_handoffs/k11_p7_lps_post_k10_backend_panel_2026-06-04/tables/k11_dataset_panel_spec.csv`; per-run `task_manifest.csv` under `split_handoffs/*`.
- P7 frozen registries + contracts (`~/current_projects/trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite/`): `config/p7_geometry_registry.csv`, `config/p7_synthetic_truth_registry.csv`, `geometry_registry_contract.md`, `synthetic_truth_family_contract.md`, `scripts/p7_truth_materialization_helpers.R`.
- Reference notes (`~/.codex/notes/references/`): `synthetic_datasets/synthetic_regression_dataset_suite.md`, `quadforms/quadform_dataset_usage_recommendations.md`, `evaluation_datasets/{method_evaluation_dataset_asset_index.md, frank_friedman_style_factorial_design_for_method_evaluation.md}`.

**G-tag binding (✓ exists / + add):**

| Plan tag | Bind to | Status |
|---|---|---|
| G1 ambient polynomial | `make.flat.dataset()` + plan polynomial truth | ✓ |
| G2 flat embedded ($X=Qu$) | flat helper + random orthonormal frame | + (~3 lines) |
| G3a paraboloid + curvature | `make.quadform.dataset(dim=2,…)` / `quadform.sample.dataset()` / geosmooth `2d_curved_paraboloid` | ✓ |
| G3b sphere cap | quadform approximation or explicit cap | + |
| G3c 1-D helix | new | + (~3 lines) |
| G3d torus patch | quadform saddle / geosmooth `2d_curved_saddle` (+ torus) | + (saddle ✓) |
| G4 stratified / varying-dim | SYN-RANK-BLOCKS (FB14), SYN-TWO-PLANES (FB12), SYN-PARA/SADDLE-LINE (FB10/11) | ✓ (bind) |
| G5 clustered / repeated | SYN-DISK-CLUSTERS + a repeated-measures cluster generator | + (G5 noise model) |
| G6 binary surface | `scripts/lps_binary_gm_ff_helpers.R` + factorial manifest | ✓ |
| G7 compositional / zeros | LA-* (FB01–FB09), SYN-SIMPLEX-FACES (FB13), LA-13K-SUB | ✓ |

**Acceptance:** each generator emits the standard dataset object with the plan's exact DGP parametrization; the registry is frozen with seeds + checksums; an independent audit confirms each generator matches the plan's DGP definition (not a hand-rolled variant). Only then may a STUDY consume it. E1.9's G3a/G3d bindings are sufficient for E1.9 to proceed once this module exposes them.
