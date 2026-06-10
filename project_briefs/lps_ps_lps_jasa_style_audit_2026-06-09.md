# LPS / PS-LPS — pre-submission audit (JASA-reviewer + friendly-auditor read)

Date: 2026-06-09. Auditor brief read: `lps_ps_lps_project_brief_09-06-2026.md`.
Code read in full: `R/lps.R` (2,302 lines), `R/ps_lps.R` (2,553 lines). Tests read:
`tests/testthat/test-ge7-lps-api.R`, `tests/testthat/test-ps-lps.R`,
`tests/testthat/test-ge1-r-smoothers.R`. Design math cross-checked against the four
`.tex`/PDF reports (PS-LPS progress, GCV synchronized-selection design, binary-outcome
progress, pointwise Truth-RMSE decomposition).

This is written the way I'd write a referee report I actually wanted the authors to
win with: what is solid, what a hostile reviewer will attack, and the cheapest fixes
that close each attack.

---

## 0. Overall assessment

The engineering is genuinely good. The numerics are guarded (orthogonal-polynomial
drop, rank/condition telemetry, no silent mean fallbacks by default), the PS-LPS
λ_sync = 0 → ordinary-LPS audit gate is implemented *and* unit-tested, and the
cache layers are proven equivalent to direct solves. That is a stronger starting
position than most methods papers arrive with.

The exposure is almost entirely **statistical**, not computational:

1. The selection machinery (CV score reporting, GCV/df under synchronization, the
   λ_sync grid railing to its boundary) is not yet on firm inferential footing.
2. There is **no uncertainty quantification** and **no statistical-correctness test**
   (unbiasedness on polynomials, consistency, calibration). Every current test is an
   implementation-parity test.
3. The estimand and the role of λ_sync are not characterized — a reviewer will ask
   "what does PS-LPS converge to, and what is the λ_sync → ∞ limit?" and there is no
   answer in the reports.

The single most leveraged observation in this audit: **both LPS (per prediction) and
PS-LPS (globally) are linear smoothers, ŷ = S(θ)·y, with S depending only on the
geometry, weights, and λ — never on y.** That fact, currently unused, simultaneously
fixes the GCV/df problem, gives honest leave-one-out essentially for free, supplies
variance/confidence bands, and yields a degrees-of-freedom-matched way to compare LPS
vs PS-LPS. Most of Section V hangs off it.

---

## I. LPS — algorithmic issues to tighten

**A1. Bandwidth is confounded with support size, and "gaussian" barely downweights.**
`​.klp.kernel.weights` sets the bandwidth to `h = max(distances)` = distance to the
k-th nearest neighbor, then `u = dist/(h+ε)`. Consequences:
- Gaussian weights span only `[exp(-0.5), 1] = [0.607, 1]` across the support — i.e.
  *nearly flat*. The "gaussian" kernel here behaves much more like uniform-over-kNN
  than a textbook Gaussian smoother.
- Compact kernels (tricube, epanechnikov, triangular) send the k-th neighbor to ≈0
  weight, so the **effective support is k−1**, not k.
- Net effect: kernel choice changes the *effective sample size* (k vs k−1) and the
  *effective bandwidth* in ways that are entangled with support-size selection, so
  CV over kernels is partly selecting an effective-n artifact. Recommend either a
  separate bandwidth multiplier on the grid, or an explicit statement of the
  k-NN-bandwidth semantics plus a note that gaussian ≈ flat weighting here.

**A2. Reported CV score is selection-optimistic (winner's curse).** `fit.lps` reports
`selected$cv.rmse.observed`, the *minimum* over the candidate grid. As a generalization
estimate it is biased downward. On synthetic suites this is harmless because you report
Truth-RMSE; on **real omics data, where truth is unknown, the headline CV/Brier/log-loss
number needs an outer (nested) CV loop**, or it will be challenged as optimistic. Make
nested CV the contract for any real-data performance claim.

**A3. Random K-fold CV is optimistic for a neighbor-based smoother on dependent data.**
`​.klp.prepare.foldid` does plain random folds. For a kNN smoother, a held-out point's
neighbors routinely sit in the training folds, so random K-fold underestimates error
whenever samples are spatially/biologically dependent. 16S data are exactly this case
(subjects with repeated visits, technical replicates, family/cohort structure). Use
**grouped / blocked CV** (leave-subject-out, leave-site-out) as the default for omics,
and say so. This applies identically to PS-LPS λ_sync selection.

**A4. Bernoulli/Brier mode selects on *unclipped* predictions but deploys *clipped*
ones.** In `​.klp.cv.table`, `cv.rmse.observed` (hence `cv.brier.observed =
cv.rmse.observed^2`) is computed from the raw least-squares `pred`, which can fall
outside [0,1]; the reported fit and the deployed predictions are clipped to [0,1].
Clipping is monotone but not rank-preserving across candidates, so selection and
deployment are mildly inconsistent. Select on the metric you ship (clipped Brier).
Separately: Bernoulli mode selects by RMSE/Brier while binomial selects by log-loss;
Brier-optimal ≠ log-loss-optimal, so a clean paired comparison should hold the
selection metric fixed (or report both for both modes).

**A5. log-loss clip ε = 1e-15 is too aggressive.** `​.klp.logloss` clips at 1e-15
(`log(1e-15) ≈ −34.5`), so a single confidently-wrong point can dominate the score,
making log-loss a high-variance selection criterion. Use a documented, larger
truncation (1e-6 is standard) and/or report both truncated and Winsorized log-loss.

**A6. Intrinsic-dimension estimation from k = 10–20 points is unstable, and it is
unsupervised.** The auto / local.auto chart dimension comes from singular-value gaps of
a 10–20-point neighborhood (`​.klp.local.auto.chart.dim.from.order`), estimated from X
only. Your own FB01 decomposition shows dimension-3 selections (over-estimation) doing
the most damage. Two cheap mitigations: (i) shrink the local-dimension field toward the
global `auto` value and/or smooth it over the neighborhood graph (your Formulation-2
idea — promote it from "future" to "default"); (ii) gate degree-2-in-dim-3 candidates
behind a points-per-parameter floor (degree 2 in dim 3 needs 10 coefficients; with k=10
and a compact kernel you are at interpolation). The orthogonal-drop machinery rescues
the *numerics* there, but the *candidate* should usually not have been entertained.

**A7. Global `auto` dimension is computed once on the full X before CV (transductive).**
`​.klp.cv.table` builds `dim.lookup` from all of X, then uses it inside folds. It is
unsupervised (no response leak), so it is defensible as a transductive choice — but
state it explicitly, or re-estimate within folds, so a reviewer cannot call it leakage.

**A8. Orthogonal-basis ridge penalizes the constant direction.** In
`​.klp.solve.local.wls`, the monomial path uses `penalty = diag(0,1,…,1)` (intercept
unpenalized — correct), but the orthogonal path uses `penalty = I` (all directions,
including the one carrying the local mean). Because ρ is tiny this is currently only a
numerical guard, but it shrinks the *prediction* toward 0 rather than toward the local
mean, and would bite if anyone raised ρ. Align the penalty structure or document that
the orthogonal ridge is strictly a conditioning device, never a statistical shrinkage.

---

## II. PS-LPS — algorithmic issues to tighten

**B1. (Most important.) The GCV degrees-of-freedom do not depend on λ_sync, so GCV
cannot see synchronization.** `​.ps.lps.diagnostics` uses `denom = 1 − rank_i / m_i`
where `rank_i` is the *standalone* numerical rank of chart i's design — fixed,
independent of λ_sync. As λ_sync grows, charts agree more and in-chart RSS rises, so
`total.local.gcv.ps` rises monotonically and **mechanically prefers λ_sync = 0**. This
is very likely why GCV "preliminarily" tracks Truth-RMSE but you cannot trust it, and it
is entangled with the boundary-railing in B3.

The fix is exact and cheap because **PS-LPS is linear in y**: assembling rows
`√(w)·φ` (data) and `√(λω)·[φ_i | −φ_j]` (sync, RHS 0), the solution is
`β = (AᵀA + R)⁻¹ Aᵀ D y` and the fitted vector is `ŷ = S(λ_sync)·y` with
`S = C(AᵀA+R)⁻¹AᵀD`, depending only on geometry/weights/λ. Therefore:
- the **honest effective df is `tr S(λ_sync)`** (compute selected diagonal entries by
  solving against the anchor-selector columns, or estimate `tr S` by Hutchinson); use
  it in GCV instead of `rank_i`. Now df *decreases* with λ_sync and GCV can express a
  real interior optimum.
- **leave-one-out is closed form**: `LOOCV_i = (y_i − ŷ_i)/(1 − S_ii)` from a *single*
  full-data solve; K-fold has the analogous block-inverse shortcut. This replaces the
  current K-solves-per-λ-per-candidate materialized-fold loop and is both faster and
  more honest.

**B2. Regularization-path discontinuity at λ_sync = 0.** The λ = 0 branch
(`​.ps.lps.solve.independent`) regularizes each chart with its *own* local ridge
(`scale_i` = mean local diagonal, intercept unpenalized), while the λ > 0 branch adds a
*single global* ridge `λ_ridge·max(diag(global cross))·I` applied uniformly across all
charts and all directions. So λ → 0⁺ does **not** continuously approach the λ = 0 fit
when the ridge regimes differ, and "λ_ridge = 0" rows are not exactly unregularized (a
`sqrt(eps)` fallback ridge can fire). The discrete audit gate (λ_sync = 0 *exactly*
equals LPS) holds and is tested; the *continuity* of the path does not. Use one
consistent ridge treatment across the path, and keep reporting realized ridge
(`ridge_median/max`, already present).

**B3. λ_sync rails to the grid boundary (median selected = 10 = grid max).** The guarded
boundary-expansion search is a reasonable patch, but the underlying problem is B1: with
no df-aware criterion, nothing internal distinguishes "genuine interior optimum" from
"monotone CV improvement that the grid happens to truncate." Fix B1 and report the
**df-vs-λ_sync and Truth-RMSE-vs-λ_sync profiles** together; that settles the boundary
question honestly rather than by grid extension.

**B4. The synchronization graph is a fixed, untuned, kNN-rank threshold.**
`​.ps.lps.prepare.sync.rows` couples anchor i to its first `sync.neighbor.size`
neighbors (default `min(8, k−1)`), de-duplicated. So coupling is decided by
neighbor-rank, not by overlap size or geometry, and `sync.neighbor.size` is never
selected. Two anchors with large overlap but rank > 8 are not synchronized; the coupling
topology is an invisible modeling choice. At minimum document and run a sensitivity
sweep; better, couple on overlap size / chart distance and treat the coupling scale as
part of the model.

**B5. State the estimand and characterize the two endpoints of the λ_sync path.** λ = 0
is independent LPS. λ → ∞ forces exact agreement of every overlapping pair on every
shared point — what is that limit? It is effectively a single consensus surface
constrained to be locally polynomial across charts, closely related to a
partition-of-unity / graph-Laplacian-penalized smoother. A JASA reviewer will want
(a) the target functional PS-LPS estimates, (b) at least a heuristic bias–variance or
consistency argument under a smoothness assumption, and (c) the identity of the
λ → ∞ limit. Right now the method is defined operationally but not characterized.

**B6. Name the penalty for what it is, and reconsider ℓ2 vs ℓ1.** `S(β)` is an
ℓ2 graph-quadratic penalty on the *chart-prediction field* — i.e. PS-LPS = local
polynomial fit + Laplacian/roughness penalty on overlapping predictions. That places it
squarely in an existing, citable literature (Laplacian smoothing, graph trend filtering,
fused/network lasso, consensus ADMM, partition-of-unity smoothers) — and you already own
graph-TF/harmonic-smoother machinery in this package. Two implications: frame and cite it
there (strengthens the paper and pre-empts "isn't this just…?"), and revisit the ℓ2
choice. PS-LPS is S-LPL-TF with the ℓ1 lifting term dropped; but **ℓ1 (fusion/TF)
coupling adapts sharply at nonmanifold junctions and dimension changes** — exactly the
regime you built local.auto for. An ℓ1-coupled variant is a natural, well-motivated
sibling, not a detour.

---

## III. Inference and uncertainty (gap that matters for the omics use case)

**C1. No uncertainty quantification anywhere.** Both estimators are linear smoothers, so
pointwise variance `σ̂²·‖Sᵢ·‖²` and approximate confidence bands are essentially free
once S exists (B1). For omics, conditional-expectation estimates usually feed downstream
inference (taxon–covariate association, differential abundance, mediation). Shipping
point estimates with no SE/band will be flagged. Add band construction; for PS-LPS,
σ̂² can come from the in-chart residuals with the df from `tr S`.

**C2. Calibration for the binary modes.** The reports propose calibration diagnostics
"if needed" — for recovering P(Y=1|X) calibration *is* the property of interest, so make
reliability curves and calibration slope/intercept first-class outputs for both Bernoulli
and binomial modes, and report them alongside Brier/log-loss.

---

## IV. Test-suite issues to tighten

The suite is strong where it exists: parity (orthogonal basis == monomial span,
C++ == R), the λ_sync = 0 → LPS audit gate (exact, `tol 1e-10`), positive-ridge/zero-sync
nesting ridge-LPS, cache-equivalence at every layer, lambda-search boundary behavior, and
telemetry. **But every assertion is an implementation-correctness or equivalence check —
the `sin`/`cos`/polynomial truths are used only as data generators, never as accuracy
targets.** Missing, in rough priority:

- **T1 — Polynomial reproduction (cheap, fundamental, currently absent).** A degree-p
  LPS must reproduce any global polynomial of degree ≤ p with ≈0 error, for *any*
  bandwidth. This pins the core bias property and would catch design/centering
  regressions instantly.
- **T2 — Consistency smoke test.** Truth-RMSE decreases as n grows on a fixed nonlinear
  truth, for both LPS and PS-LPS.
- **T3 — PS-LPS actually helps somewhere.** A controlled case where optimal λ_sync > 0
  strictly beats λ_sync = 0 in Truth-RMSE. Today only the λ = 0 lower bound and the
  machinery are tested; a refactor could silently neutralize the method's entire reason
  for existing and every test would still pass.
- **T4 — Probability calibration / recovery** on a known surface for both binary modes.
- **T5 — CV no-leakage assertion.** Perturb a held-out `y_i`; its own out-of-fold
  prediction must not change. Directly asserts the honesty of materialized-fold CV
  (currently only implied by the λ = 0 test).
- **T6 — GCV/df numeric correctness** against a hand-computed small example; after B1,
  assert `tr S` equals a finite-difference df (`∂Σŷ/∂y`).
- **T7 — Degenerate-geometry pathologies:** duplicate points (h handling), exactly
  collinear supports, zero-variance y, extreme class imbalance (logistic fallback
  numerics, not just telemetry), and **simplex-boundary / structural-zero inputs**
  (directly relevant to 16S).

Minor doc-accuracy note: the brief points an auditor to `tests/testthat/test-lps.R`, but
the LPS tests actually live in `test-ge7-lps-api.R` (and `test-ge1-r-smoothers.R`); there
is no `test-lps.R`. Update the brief's entry points.

---

## V. Other ideas / extensions

Several echo the reports' own open questions; I have starred the ones I think are highest
value and not yet on your list.

- **E1 ★ — Exploit linearity end-to-end (the B1 dividend).** Analytic LOOCV/GCV, exact
  `tr S` degrees of freedom, variance/bands, and — importantly — **df-matched LPS-vs-PS-LPS
  comparison**: compare the two at equal `tr S`, not at equal λ or equal nominal
  parameters. A reviewer's first instinct is "PS-LPS just buys accuracy with extra
  effective parameters"; df-matching is how you prove it doesn't.
- **E2 ★ — Compositional front end for 16S/metagenomics.** Today supports/charts use
  Euclidean ambient coordinates. Relative-abundance data live on the simplex; Euclidean
  kNN there is geometrically wrong and structural zeros break it. Add a compositional
  geometry (CLR/ILR transform, or Aitchison distance) before local PCA, with explicit
  zero handling (pseudocount or zero-aware metric). This is the single most important
  domain adaptation for the stated application; your VALENCIA dCST space already gestures
  at it.
- **E3 ★ — Synchronize binary PS-LPS on the link scale.** When you build the deferred
  binary PS-LPS objective, couple charts on η = logit p, not on p. Agreement of log-odds
  is the natural geometry for logistic local fits, keeps the penalty well-behaved near
  0/1, and avoids the clipping pathologies of probability-scale agreement.
- **E4 ★ — Multi-feature amortization.** Omics wants conditional expectations for *many*
  taxa/genes at once. The geometry — supports, charts, overlaps, and the smoother S — is
  **shared across response features**. Assemble once, solve for a y-matrix (many columns)
  in one factorization, and optionally borrow strength across features. This is a large
  constant-factor win and turns "one feature" into "the whole table" cheaply.
- **E5 — Overdispersion / repeated structure.** 16S counts are overdispersed and often
  have repeated measures per subject; Bernoulli/binomial local likelihoods understate
  variance. Consider beta-binomial or quasi-likelihood local fits, and pair with
  subject-level CV folds (ties to A3).
- **E6 — ℓ1 / trend-filtering coupling variant** (the B6 sibling) for sharp adaptation at
  nonmanifold junctions; reuse the package's TF operators.
- **E7 — Principled λ_sync selection** once `tr S` exists: GCV/AIC on the global linear
  smoother, or honest nested/grouped CV, with the df-vs-λ profile reported to retire the
  boundary-rail question.
- **E8 — Heteroskedasticity-aware local weights** (local variance estimate) for both
  better bands and count data where variance tracks the mean.
- **E9 — Scalability** for omics n: anchor mini-batching (already proposed) composes with
  E4 (multi-feature) and with the fact that S is geometry-only, so it can be precomputed
  once per (k, kernel, dim, λ) and reused across all features and CV blocks.

---

## VI. Friend-auditing, pre-submission priority list

If the goal is a defensible JASA submission, I would order the work like this:

1. **B1 + E1** — make the estimator's linearity do the work: exact df (`tr S`), analytic
   LOOCV/GCV, df-matched LPS-vs-PS-LPS comparison. This is the keystone; it also retires
   B3 and most of the GCV uncertainty.
2. **B5 + B6** — write the estimand, the λ → ∞ limit, and the one-paragraph placement in
   the graph-penalty / partition-of-unity literature. This is what turns "a procedure
   that works on our suites" into "a method."
3. **C1/C2** — uncertainty bands and binary calibration; cheap given (1), expected by
   reviewers, and load-bearing for the omics application.
4. **T1–T5** — add the statistical-correctness tests (polynomial reproduction,
   consistency, PS-LPS-helps, calibration, no-leakage). Inexpensive, and they protect the
   claims through revision.
5. **A2/A3** — nested + grouped CV as the real-data contract; without it the headline
   number on microbiome data is contestable.
6. **E2/E3/E4** — the omics-specific adaptations (compositional geometry, link-scale
   binary sync, multi-feature amortization) for the applied half of the paper.

Items A1, A4–A8, B2, B4 are tightening/hygiene: individually minor, collectively the
difference between a clean referee report and a death-by-a-thousand-caveats one.
