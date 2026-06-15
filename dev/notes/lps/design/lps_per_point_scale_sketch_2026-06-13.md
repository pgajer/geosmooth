# Sketch — per-point / co-regularized chart scale for LPS

Date: 2026-06-13. A design sketch (not a spec) for making the support size a **per-anchor field**,
co-regularized with the local-dimension field. Grounded in the current `R/lps.R` /
`R/local_pca_chart_dim.R`. It reuses, rather than reinvents, E1.9 (bandwidth machinery), E1.11
(dimension-field stabilization), the Phase-1b ℓ1/graph-cut solver, the Phase-2b chart nerve, and the
E0.2/E4.1 `S`-toolkit.

## 1. The problem, precisely

Today the scale is **one global K** chosen by CV over `support.grid`
(`.klp.cv.table` → `.klp.select.best.idx` → `selected$support.size`), applied identically at every
anchor in `.klp.predict.local.polynomial` (the loop uses a scalar `support.size`). The **dimension**
is per-anchor (`chart.dim.by.eval` from `.klp.resolve.prediction.chart.dim` →
`.klp.local.auto.chart.dim.from.order`), estimated at that fixed K, with the points-per-parameter cap
`.local.pca.max.chart.dim.for.support` (`choose(d+p,p) ≤ K`).

The locally MSE-optimal scale `h_i*` depends on local curvature, density, noise σ², **and** the local
dimension `d_i` — and `d_i` is read off the neighborhood spectrum *at scale `h_i`*. The two are
genuinely coupled, so they want to be solved **jointly** (or alternated to a fixed point). A single
global K is suboptimal wherever the local regime departs from the dataset average — exactly the
heteroscale / heterodimension case.

## 2. The one decision that governs everything: X-only vs y-aware scale

This determines whether the entire E0.2/E4.1 toolkit survives.

- **X-only scale.** `K_i` (or per-anchor `b_i`) depends on **X only** — geometry/density, never the
  response. Then for a *fixed* field `{K_i, d_i}` the fitted vector is still **linear in y**
  (`ŷ = S y`, `S` depends only on `X` and the field), so `df = tr S`, the analytic LOO/GCV, and the
  E4.1 bands all hold **unchanged** — the scale field is just another `y`-independent map, exactly as
  the dimension field already is. This is the clean route, and it is §A2-safe.
- **y-aware scale.** `K_i` minimizes a local *out-of-sample error on y* (local GCV/LOO, or Lepski).
  This adapts to the **response's** smoothness → better MSE, but makes `S` depend on `y`. The
  fixed-config linearity breaks (same reason the current CV-selected global K is only toolkit-valid at
  a singleton grid, per `§sec:smoother`), so `df` and bands become **selection-aware** (the E1.10
  nested-CV / E4.1-conditional path), and honest generalization error needs nested evaluation.

**Recommendation:** build both behind a flag; **default X-only** (keeps the toolkit and a bit-for-bit
fallback), with **y-aware as the opt-in** that explicitly routes through the selection-aware df/band
path. Note the asymmetry with today: the current *dimension* is X-only, but the current *global scale*
is y-aware (CV). A per-anchor X-only scale would actually make the whole chart field `y`-independent
and restore exact linearity end-to-end.

## 3. The per-anchor scale criterion

**X-only options** (any of these gives a `y`-independent `K_i`):
- target **effective sample size** `ESS_i` (Kish) at the chosen kernel — ties directly to E1.9's ESS
  characterization; grow K until `ESS_i` hits a target;
- target **design condition number** — grow K until the local polynomial design is well-conditioned
  (reuses `ridge.condition.max` semantics); this is the most natural "enough points for this degree and
  dimension" rule and it is *inherently* scale–dimension coupled;
- target **local fill** — `K_i` so the K-th-NN radius is a fixed multiple of the local inter-point
  spacing (density-adaptive).

**y-aware options:**
- **Local GCV / LOO.** Per anchor, over the K-grid, score `GCV_i(K)` from the local leverage `S_ii`
  (cheap — the influence row is already implemented in `R/lps_uncertainty.R` / `lps.smoother.matrix`);
  take the argmin. O(n·|grid|) leverage evals.
- **Lepski multiscale (more principled for *spatial* scale).** Pick the **largest** `K_i` whose
  estimate stays within a confidence band of every smaller-scale estimate; near-minimax adaptive, no
  smoothness input needed, and — the elegant part — it **re-estimates `d` at each scale**, so the
  scale–dimension coupling is handled *by construction* rather than bolted on.

**Honest caveat (do not paper over).** `§sec:smoother` already flags that **response-removal LOO ≠
training-removal LOO** for a k-NN-bandwidth smoother: removing a point changes the K-th-NN radius, so
the cheap `(ŷ_i − S_ii y_i)/(1−S_ii)` shortcut is a **biased** proxy for *scale* selection. So the
local-GCV route needs either a correction, a small leave-a-block-out within the neighborhood, or — best
— Lepski, which compares scales directly and sidesteps the shortcut.

## 4. Co-regularization over the chart nerve

Purely-local `K_i`, `d_i` are high-variance. Couple them spatially and to each other:

> minimize over the fields `{K_i, d_i}`:  Σ_i ℓ_i(K_i, d_i)  +  λ_K · TV_G(K)  +  λ_d · TV_G(d)
> subject to  `choose(d_i + p, p) ≤ K_i`  (the points-per-parameter constraint, already the code's cap).

- `G` = the **chart nerve** (anchors adjacent iff their charts overlap) — Phase-2b's substrate.
- **TV (ℓ1)** denoises the fields while *preserving genuine scale/dimension boundaries* (the
  ℓ1-keeps-the-boundary property the Phase-1b dimension work already validates); ℓ2 would blur a real
  regime change.
- Solve with the **same graph-cut / proximal machinery** Phase 1b builds for the dimension field;
  alternate `K` and `d` (or solve the coupled field). The constraint makes the points-per-parameter cap
  a *joint* property of the two fields instead of a per-anchor afterthought.

This is the concrete content of the program plan's Phase-2b line "co-regularize chart **size** and
dimension over the nerve."

## 5. Identifiability and degeneracy guards

- **Scale–dimension trade-off** (a fit can read as small-K/low-d *or* large-K/higher-d): disambiguate
  with (i) the hard points-per-parameter constraint, (ii) a documented parsimony tie-break — smallest
  `d`, then largest `K` for variance — and (iii) the joint TV penalty preferring coherent fields.
- **Interpolation collapse** (`K_i → K_min` everywhere drives *training* error to 0): never select on
  in-sample RSS; the out-of-sample criterion (GCV/LOO/Lepski) penalizes over-localization. This is the
  same trap E1.10 guards globally, now per anchor.
- **Boundary anchors:** one-sided neighborhoods; don't over-shrink `K` there, and let the nerve
  smoothing borrow scale from interior neighbors (a boundary safeguard mirroring E1.11's).

## 6. Implementation in `geosmooth`

- Promote `support.size` from a scalar to a **per-anchor field**: a `chart.scale = "local.auto"` mode
  and a `support.size.by.eval` vector, exactly paralleling `chart.dim = "local.auto"` /
  `chart.dim.by.eval`.
- New `.klp.resolve.prediction.support.size` (mirror of `.klp.resolve.prediction.chart.dim`) returns
  `K_i`; for the joint mode, a single `.klp.resolve.prediction.scale.and.dim` that runs §4.
- `.klp.predict.local.polynomial` already loops per eval point and reads `chart.dim.by.eval[[i]]`
  (≈ lines 1307–1360) — replace the scalar `support.size` with `support.size.by.eval[[i]]`; everything
  downstream (`.klp.local.order`, weights, `.klp.local.coordinates`, `.klp.fit.intercept`) is already
  per-point.
- The local criterion reuses **`R/lps_uncertainty.R`** (the influence row / `S_ii`) and **E1.9's**
  per-anchor bandwidth `b_i`; the co-reg module is a new file paralleling the dimension field, on the
  nerve graph, reusing the Phase-1b TV solver.
- **Backward-compat (§A2):** default stays the current global K, **bit-for-bit**; the field mode is
  opt-in. R backend first (as `local.auto` already is); `cpp.local.pca` later.
- If **y-aware:** route `df`/bands through the selection-aware path — E1.10 nested CV for honest error,
  E4.1 bands conditional on the selected field.

## 7. Validation gates (the program's discipline carries over)

- **New DGP — "varying scale":** a manifold with a localized region of finer structure / higher
  curvature (known scale change), plus reuse **G4** (varying dimension) and **G3** (curved).
- **GATE (reduction):** on a homogeneous truth, the field collapses to ≈ the global K with no spurious
  spatial variation (near bit-for-bit vs global-K LPS).
- **GATE (tracking):** on the varying-scale DGP, `K_i` is smaller in the fine region (tracks the known
  change); `d_i` tracks G4's stratum dims; the ℓ1 co-reg does **not** blur the true boundary.
- **STUDY (benefit):** Truth-RMSE vs global-K LPS at **matched df**, on heteroscale/heterodim DGPs;
  promote only past the contract's material threshold.
- **Linearity guard:** X-only mode preserves the E0.2 `ŷ = S y` identity (a GATE — `S` stays
  `y`-independent); y-aware mode explicitly does not, and says so, using nested error instead.

## 8. Cost

Per-anchor criterion: O(n · |K-grid|) influence-row evaluations (cheap; the row is already built).
Co-reg solve: O(n) per iteration on the nerve graph (like the dimension field). Feasible R-first.

## 9. Decisions I'd want from you

1. **Default mode:** X-only (keeps the toolkit + bit-for-bit) with y-aware opt-in — my recommendation —
   or y-aware as the headline?
2. **Criterion:** local GCV (cheap, reuses `S_ii`) vs **Lepski** (more principled for spatial scale and
   handles the scale–dim coupling natively). I lean Lepski for the field, GCV as a fast baseline.
3. **Sequencing:** fold this into **E1.11** as a *joint* scale+dimension field (they share the solver
   and the coupling is intrinsic), or land the dimension field first and add scale as E1.12? Joint is
   cleaner statistically; staged is lower-risk for the gate structure.
