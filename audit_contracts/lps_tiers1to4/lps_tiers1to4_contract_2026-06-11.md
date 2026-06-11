# LPS Tiers 1–4 — Implementation & Validation Contract

Date: 2026-06-11
Owner: orchestrator (human investigator + Claude). Status: **frozen at issue**; changes are versioned amendments (§H).

This contract **layers on** the frozen science spec `project_briefs/lps_experimental_plan_2026-06-09.tex` (the source of truth for each gate's Claim / DGP / Statistic / Acceptance / Safeguards). It does **not** restate the science; it supplies the four things the plan leaves open and that an implementer needs to proceed without fuzziness:

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

1. **Internal weight-routine symbol** for E1.9's characterization test (must be the real routine).
2. **Do canonical G1–G7 generators exist in code**, or is building a shared DGP-library asset a prerequisite (the program's "cross-cutting data enabler")? If absent, that is amendment #1 and blocks every study.
3. **E1.11 stabilizer surface:** a `fit.lps` argument vs a standalone post-processor utility — which fits the codebase better?
4. **E2.13 / Tier-0 default coupling:** the ridge alignment touches defaults the Tier-0 audit already flagged; confirm the intended default state before changing it.
5. **Bandwidth multiplier vs existing kernel semantics** (E1.9): confirm $h=b\cdot(K\text{-NN distance})$ composes correctly with each kernel's existing normalization.

## H. Amendment process

Any change to an API name, threshold, sizing, or typing is a numbered amendment appended here with date and rationale, approved by the orchestrator. The contract version is this file's git commit. An artifact generated under an older version is read against the version in force at its timestamp.
