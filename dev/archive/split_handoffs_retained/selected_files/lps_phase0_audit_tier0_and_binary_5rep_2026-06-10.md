# Phase-0 Independent Audit — LPS Tier-0 Run & Binary GM/FF 5-Rep Run

Date: 2026-06-10 (ET)
Auditor mandate: `~/.codex/notes/workflows/worker_auditor_workflow.md` (Audit Charter)
Audited handoffs (evidence bundles only — they do not set scope or verdict):

- `~/current_projects/geosmooth/split_handoffs/lps_tier0_correctness_tests_implementer_handoff_10-06-2026.md`
- `~/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_telemetry_valid_5rep_20260609_001/lps_binary_gm_ff_5rep_implementer_handoff_10-06-2026.md`

Charter principle applied throughout: **report rendered ≠ data valid ≠ phase accepted.** I verified against primary sources (the actual test code and the raw run CSVs), reproduced at least one number per run from raw outputs, and tried to break each run's main claim before forming a verdict. Both handoffs are charter-compliant (each states it is evidence-only and suggests no verdict); I confirm that and it is noted to the implementer's credit.

---

## Verdicts at a glance

| Run | Verdict | One-line basis |
|---|---|---|
| **Tier-0 correctness** | **ACCEPTED-PARTIAL — Phase-0 gate NOT met** | The two implemented gates (E0.1, E0.2) are correct and non-vacuous, but only **2 of 8** Tier-0 gates exist, and the pass was not independently executed (no R in the audit env) on a clean tree. |
| **Binary GM/FF 5-rep** | **ACCEPTED-WITH-REQUIRED-REVISION** | The telemetry fix is real and verified; performing the stratification the report defers shows the headline "logistic loses by 0.0076" is a **mixture of opposite fallback regimes** — the report must be re-framed before its conclusions stand. |
| **Phase 0 overall** | **NOT YET ACCEPTED** | Neither piece clears the gate; both have a bounded, well-defined punch-list (below). Downstream phases (PS-LPS, dimension field) should not start until cleared. |

---

## Audit-environment limitation (stated up front)

The audit sandbox has **no R/Rscript**, so I could not execute the Tier-0 `testthat` file or re-run any LPS fit. For Tier-0 this means I audited the **test logic and implementation** by reading the primary source (which is the substance of a correctness-test audit) but did **not** independently reproduce the pass/fail. For the binary run this limitation does **not** bind: that run's outputs are CSVs, which I re-analyzed directly with Python, so the binary reproduction and stratification below are fully independent.

---

## Run 1 — LPS Tier-0 correctness tests

**Primary artifact audited:** `tests/testthat/test-lps-tier0-correctness.R` (267 lines, 4 `test_that` blocks), read in full against `R/lps.R`.

### What the file actually contains (verified, not taken from the handoff)

It implements **E0.1** (polynomial reproduction) and **E0.2** (linear-smoother identity), each in an ambient and an intrinsic/local-PCA variant. It does **not** implement E0.3–E0.8. The four blocks are:

1. **E0.1 ambient** — 64 cases (`ambient.dim ∈ {2,3}` × `degree ∈ {1,2}` × 4 kernels × 4 design bases). Truth is a genuine polynomial: degree-1 = `0.7 + 0.4x₁ − 0.3x₂ + 0.2x₃`; degree-2 adds `0.5x₁² − 0.25x₁x₂ + 0.35x₂² − 0.18x₃² + 0.12x₁x₃`. Support is over-determined (`≥ 4 ×` column count). Asserts no NA, `max|fit − y| < tol`, single-row CV table.
2. **E0.1 intrinsic** — 64 cases on **flat** embedded subspaces (`X = U Qᵀ`, `Q` an orthonormal frame), truth defined in intrinsic coords, fit with `coordinate.method="local.pca"`, `chart.dim = intrinsic.dim`. Additionally asserts the chart method recorded as `pca` and `fallback.count == 0`.
3. **E0.2 ambient** (n=36, 2-D) — extracts the smoother `S` column-by-column via `fit(eⱼ)`, then asserts `S·y = fit(y)` for two random `y` and a linear combination `y₃ = 0.6y₁ − 1.4y₂` (all to 1e-10), bump-perturbation columns match `S[,j]`, `tr(S)` finite and `> 0`, and `tr(S)` equals the summed pointwise bump response.
4. **E0.2 local-PCA** (n=34, 1-D line in 2-D) — same identity/df checks under `coordinate.method="local.pca"`.

Tolerances: **1e-6** for the `monomial` basis, **1e-8** otherwise (reproduction); **1e-10** for the linearity/df identities.

### Findings by charter layer

- **Data generation (sound).** The reproduction truths are genuine degree-`p` polynomials with non-zero high-order and cross terms, so a degree-`p` reproduction is a real, falsifiable property — not a constant the smoother could pass trivially. The intrinsic cases use a **flat** linear embedding, which is the correct construction: a curved embedding would induce legitimate approximation bias and the reproduction would (correctly) fail. This avoids the trap I would have flagged.
- **Measurement / identity (sound, and stronger than the handoff claims).** The handoff is over-modest in calling E0.2 "empirical, not an analytic proof." For a *fixed* configuration the LPS smoother is a linear operator that depends on `X` only; `fit(eⱼ)` therefore **is** column `j` of the true `S` by definition, and the test then verifies `S·y = fit(y)` on a spanning set plus an independent combination. That is a complete linearity verification, not a sampled approximation.
- **Selection fairness — the key correctness point, handled correctly.** E0.2 uses **singleton** grids (`support.grid=18`, `degree.grid=1`, `kernel.grid="tricube"`), so there is no CV model selection and the map stays genuinely linear. Had it extracted `S` from the CV-selected pipeline (where the chosen config depends on `y`), the "linear smoother" claim would be false. The test correctly avoids this. The local-PCA block further confirms a non-obvious property: charts are `y`-independent, so the smoother is linear even with data-adaptive charts.
- **Implementation (sound).** Consistent with the `R/lps.R` design-matrix + weighted-least-squares solve I audited previously; `ridge.multiplier.grid=0`, `ridge.condition.max=Inf`, `unstable.action="na"` make NA-on-failure visible rather than silently masked.

### Falsification attempt

I tried to make E0.1 pass vacuously (constant truth, loose tolerance, mismatched degree) and could not: the truth is a real degree-`p` polynomial, tol is tight, degree is matched, support is over-determined — a buggy design or solve would fail it. I tried to break E0.2 via the CV-nonlinearity trap and could not: the config is singleton/fixed. The tests resist falsification.

### Findings that block the Phase-0 gate

1. **Scope: 2 of 8 Tier-0 gates.** E0.3 (LOO shortcut), E0.4 (boundary bias), E0.5 (consistency), E0.6 (binary calibration), E0.7 (CV no-leakage), E0.8 (degenerate geometry) are **absent**. The Phase-0 gate as defined in the program plan = the Tier-0 battery passes; 25% of the battery does not clear it. (Honestly disclosed by the handoff.)
2. **Pass not independently reproduced.** The "row of dots" is the implementer's run; the audit env cannot execute R. The gate should require an independent green run.
3. **Dirty / uncommitted tree.** I confirmed `git status`: `R/lps.R` is **modified** and the test file is **untracked**. The pass therefore corresponds to no committed state. The gate run must be on a clean, committed tree.
4. **R backend only; native/C++ path unaudited for reproduction.** `backend="R"` throughout — the production C++ path is not exercised by these reproduction/identity tests.

### Minor / strengthening (non-blocking)

- Add a **negative control**: a degree-(p−1) fit on a degree-`p` truth should *fail* to reproduce. Present tests confirm the property holds where expected but never confirm it can fail — a cheap, decisive non-vacuity guard.
- **Log realized errors** (not just `< tol`): if realized error sits at ~1e-7 against a 1e-6 monomial tol, headroom is thin and worth seeing.

### Verdict — Tier-0: **ACCEPTED-PARTIAL; Phase-0 gate NOT met.**

The implemented E0.1/E0.2 gates are correct, non-vacuous, and well-engineered — genuinely good work. But Tier-0 is the foundation gate and it is 2/8 complete, unexecuted in the audit, and on a dirty tree. **Required to clear:** implement E0.3–E0.8; run the full battery green on a clean committed tree with at least one independent reproduction; extend the reproduction/identity checks to the C++ backend.

---

## Run 2 — LPS Binary GM/FF 5-rep run (`...telemetry_valid_5rep_20260609_001`)

**Primary artifacts audited:** `tables/combined_results.csv` (5,760 rows), the report-side delta/telemetry CSVs, `render_lps_binary_gm_ff_report.R`, and the rendered HTML. All numbers below are **my** recomputation from the raw combined results.

### Fixes from the earlier (full-run) results audit — verified applied

| Earlier finding | Status in this run (independently checked) |
|---|---|
| Fallback telemetry **all-NA** → "logistic loses" uninterpretable | **FIXED.** All 6 logistic telemetry columns hold 2,880 finite values; distribution is non-degenerate (below). |
| `observed_logloss` was **in-sample** but plotted as if diagnostic | **PARTIALLY ADDRESSED.** The misleading figure is removed and a `observed_logloss_scope` column now labels the values `full_data_final_fit_in_sample`. The column is disclosed, not yet recomputed held-out. |
| Pseudo-replicated CIs (scenario clustering ignored) | **ADDRESSED.** Scenario-clustered delta tables present (288 clusters); CIs are cluster-level. |
| Selection-metric asymmetry hidden | **DISCLOSED.** `selection_metric_summary` confirms Bernoulli selects on CV Brier (2880/2880), logistic on CV log-loss (2880/2880). |
| Run accounting / stale strings | **CLEAN.** 5,760 planned = status = result = ok, 0 error/timeout; no stale `11,520` / "ten repetitions" / "Full Run Report" strings. |

### Reproduction (charter requirement — reproduced from raw)

Overall median paired delta (logistic − Brier Truth-RMSE) = **+0.00759** from the raw pairs, matching the handoff's reported ~0.0076 and within the renderer's clustered CrI `[0.00663, 0.00895]`. The dimension×embedding interaction also **replicates** the full run: logistic better in 1-D high-D pad (−0.016), Brier better in 3-D (+0.018), 2-D high-D indistinguishable (CI crosses 0). The headline is reproducible.

### The substantive finding — the now-captured telemetry overturns the naive reading

The report **captures** the fallback telemetry but, in its own words, leaves stratification to a "future audit" and presents fallback only as a data-validity checkmark. Performing that stratification is squarely the auditor's job, so I did it.

Fallback is **pervasive, not incidental.** Final event-rate fallback fraction across logistic fits: mean 0.133, median 0.038, q90 0.472, max 0.972; **84.9%** of logistic fits fell back at least partially, **13.7%** by >25%. It concentrates exactly where intrinsic structure is thin: 1-D-padded-to-100-D has mean fallback **0.526**.

Stratifying the paired delta by that fallback fraction:

| Logistic event-rate fallback fraction | n pairs | median Δ (log − Brier) | logistic-better share |
|---|---:|---:|---:|
| 0 (clean logistic fits) | 435 (15%) | **+0.0031** | 31% |
| (0, 0.05] | 1,174 (41%) | +0.0105 | 8% |
| (0.05, 0.25] | 876 (30%) | +0.0104 | 17% |
| > 0.25 | 395 (14%) | **−0.0177** | 85% |

The pooled "+0.0076, Brier better" is a **mixture of two opposite regimes**:

- Where logistic actually fits a logistic model (**zero fallback**), Brier wins only **mildly** (+0.0031; logistic still wins 31% of pairs) — far less than the headline.
- Where fallback is heavy (**>0.25**), logistic "wins" (−0.0177) — but in that stratum the "logistic" fits are largely **event-rate fallbacks**, i.e. degenerate intercept-style estimates. That is the **fallback** beating Brier, not logistic fitting.

The dramatic **1-D high-D "logistic sweep" is entirely fallback-driven**: logistic wins 100% of those pairs with mean fallback 0.526. It is not evidence that logistic fitting helps; it is evidence that a stable degenerate fallback beats a Brier fit in a regime where genuine local logistic fitting collapses.

### Falsification attempt

I tried to attribute the whole "Brier better" headline to the selection-metric asymmetry alone — it does not hold: the **clean** stratum still mildly favors Brier (+0.0031), so asymmetry is not the sole driver. I then tried to defend "logistic wins on 1-D high-D" as a real result — falsified by the 0.526 mean fallback there. **Both** directional headlines fail as statements about genuine logistic fitting; each is a fallback/selection artifact.

### Remaining issues

1. **Capture ≠ use (the blocking one).** The five report figures and the conclusion text do not stratify the comparison by fallback; the report still leads with the pooled "Brier better by 0.0076." The conclusion must be **re-framed**: lead with the zero-fallback clean comparison (mild Brier edge), and label the 1-D high-D result as fallback-dominated.
2. **`observed_logloss` still in-sample** (`full_data_final_fit_in_sample`; 12.9% of logistic fits below 0.10, implausible held-out). Acceptable as labeled-and-unplotted, but the held-out version is still owed (ties to Tier-0 E0.6 binary calibration).
3. **Selection asymmetry remains** (correctly framed as a deployed-policy, not equal-objective, comparison). A clean equal-objective comparison (e.g. both scored on the same held-out proper score, or each on its own *and* a common metric) is still future work.
4. **Dirty tree** — same `R/lps.R` uncommitted state as Tier-0; record package source state before any rerun/comparison.
5. The scenario-clustered point estimate was not independently reproduced by the handoff (I reproduced the pooled median; the cluster statistic differs by ~0.001 depending on mean-vs-weighted-median definition — immaterial, same sign, inside the CrI).

### Verdict — Binary 5-rep: **ACCEPTED-WITH-REQUIRED-REVISION.**

The data is valid and the central telemetry fix works exactly as intended — it makes the comparison interpretable for the first time. But interpretability reveals that the **reported conclusions are fallback-confounded**: the report must stratify by fallback and re-frame both directional headlines before its findings can stand. **Required to clear:** add a fallback-stratified delta figure/table and rewrite the conclusion to lead with the zero-fallback comparison; either recompute `observed_logloss` held-out or keep it labeled-and-unplotted; state the deployed-policy caveat in the conclusion, not only the limitations.

---

## Phase-0 gate status and punch-list

**Phase 0 is NOT yet accepted.** What remains is bounded and concrete:

Tier-0 — (a) implement E0.3–E0.8; (b) green run of the full battery on a clean, committed tree with one independent reproduction; (c) extend reproduction/identity checks to the C++ backend; (d) add a degree negative-control and log realized errors.

Binary 5-rep — (e) re-render with a fallback-stratified delta and a conclusion that leads with the clean (zero-fallback) comparison; (f) resolve `observed_logloss` scope; (g) carry the selection-asymmetry caveat into the conclusion.

Until (a)–(g) are addressed, the downstream phases (PS-LPS synchronization, local-dimension ℓ₁ field) should not begin — their go/no-go gate is a clean Phase-0.

What is **already trustworthy** and can be built on: the E0.1/E0.2 correctness machinery (the linear-smoother / `S` / `tr S` extraction is the exact toolkit Phase 0 must emit downstream), the binary run's accounting and now-valid telemetry, and the reproducible dimension×embedding interaction.
