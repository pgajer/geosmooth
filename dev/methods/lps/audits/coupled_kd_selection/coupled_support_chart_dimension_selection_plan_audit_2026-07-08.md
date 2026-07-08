# Coupled Support-Size × Chart-Dimension Selection — Plan Audit

Date: 2026-07-08
Auditor role: independent auditor (worker-auditor workflow)
Repository: `/Users/pgajer/current_projects/geosmooth`
Artifact under audit: `dev/methods/lps/specs/coupled_support_chart_dimension_selection_plan_2026-07-08.md`
Charter: `/Users/pgajer/.codex/notes/workflows/worker_auditor_workflow.md`
(Charter layer 6: "Implementation plans before coding.")

This audits a **design/spec document**, not code. I verified the plan's technical
claims against the actual reuse implementation I audited on the same day
(`ps_lps_pca_coordinate_reuse_audit_2026-07-08.md`, commit `7454453`) and against
the PS-LPS runtime measurements from the prior investigation
(`vaginal_community_trajectory_types/docs/phase_handoffs/ps_lps_count_runtime_speedup_investigation_handoff_2026-07-08.md`).

## Verdict

**Sound plan — approve proceeding with CSD0 and CSD1, with the refinements
below folded in before CSD2+.**

The statistical motivation is legitimate, the reuse-contract reasoning is
technically correct (I confirmed it against the code), and the phasing, rigor
practices, and risk register are strong. There is one substantive design issue
(the `d_auto` seed is uncapped and can defeat the very cost model the plan is
built on) and three lesser clarifications. None is a correctness landmine — the
"no default change until audited" discipline (acceptance criterion 6) keeps the
experiment safe — but the `d_auto` issue should be resolved before it is baked
into CSD2+.

## What the plan gets right (verified)

- **The k–d coupling motivation is sound.** Support size sets the neighborhood
  scale; chart dimension sets how much of it is treated as signal geometry. A
  large `k` can carry a larger `d`; a small `k` needs a smaller `d` for a stable
  local polynomial fit. Searching them separately can pick individually-plausible
  but jointly-poor pairs. This is a real, well-posed problem.
- **The reuse-contract distinction (lines 50–58) is technically correct and
  matches the code.** I verified: `rcpp_ps_lps_local_pca_supports()` computes the
  support `distances` and kernel `weights` from **ambient** distances (dimension-
  independent), so LPS/PS-LPS can reuse the whole native support object and slice
  only `coordinates`. Chart-kernel and local-likelihood compute their kernel
  weights (and adaptive bandwidth) from **chart-space** distances, which change
  when coordinates are sliced to `d` — so those must be recomputed. The plan
  states this exactly.
- **The cache-key split is right.** `(support.size, kernel, max.numeric.chart.dim)`
  for LPS/PS-LPS (weights are baked into the cached object, so kernel matters);
  `(support.size, max.numeric.chart.dim)` for chart-kernel/local-likelihood
  (support indices and PCA coordinates are kernel-independent; weights are
  recomputed). Both are correct.
- **Rigor practices align with the charter:** record planned vs evaluated
  candidates and infeasible pairs rather than silently dropping them (CSD0,
  acceptance 3); parity tests that cached == uncached scores (CSD1, acceptance 1 —
  this is exactly what I measured at 1.8e-15 for the existing reuse); a full-grid
  oracle reference so the sparse policy can be judged (acceptance 5); no default
  behavior change until an auditor accepts the report (acceptance 6). Guard
  candidates that probe whether the optimum is boundary-driven are good
  statistical hygiene.

## Findings and refinements

### F1 (substantive) — the uncapped `d_auto` seed defeats the plan's own cost model
The sparse dimension skeleton is `D0 = {1, 2, d_auto, d_hi}` with `d_hi` a
*bounded* high guard (`min(6, p, k − margin)`), and `d_auto` proposed as "the
current global auto estimate" resolved to a numeric candidate (lines 122, 164).
The problem: **`d_auto` is not bounded by `d_hi`.** From the runtime
investigation, `chart.dim="auto"` systematically **over-selects** on high-
dimensional / noisy assets (resolved to **25** on the OD4-extended HD100 cell,
vs a CV-optimal dimension of 1–2), and that over-selection is both far slower and
*less accurate* (held-out neg-log-ρ 20.2 vs 7.0).

Because the reuse builds the local PCA at `max(numeric d in the group)`, injecting
a numeric `d_auto = 25` makes the shared PCA build at dimension 25 — reintroducing
the exact cost the plan's `d_hi ≤ 6` bound was meant to prevent. Worse for
PS-LPS: the sync-solve cost is per-candidate and scales super-linearly with `d`
(the PCA reuse does **not** amortize the solve — see F2), so a `d_auto = 25`
candidate is expensive to *solve* and then loses anyway.

Note this is a **new behavior** the plan proposes: the current reuse code
(`.state.density.ps.lps.chart.dim.reuse.plan`) explicitly excludes `"auto"` from
`max.numeric.chart.dim` (it decodes to a non-numeric label and is filtered out),
routing it to the direct path. The plan's proposal to resolve `auto` into a
numeric grid entry is what creates the exposure.

Recommendation: cap the auto seed to the same bound, e.g. use
`min(d_auto(k), d_hi)` as the seed, or keep `d_auto` only as a *starting point for
the local-refine stage* (CSD step 4) rather than as a raw skeleton candidate that
can raise the group max. At minimum, make `max.numeric.chart.dim` in the reuse
group bounded by an explicit `chart.dim.max`, and record in telemetry when a seed
was clipped.

### F2 (clarification) — reuse amortizes the PCA, not the solve; state this for PS-LPS
The plan's efficiency premise (lines 8–13) is that PCA-coordinate reuse makes the
sparse `k × d` search "much less wasteful." True for the **geometry** (one PCA per
support group, sliced for smaller `d`). But for PS-LPS the dominant cost at
non-trivial `d` is the **sparse-Cholesky factorization of the sync system**, whose
size is `n × (coefs per anchor)` and grows with `d` — and that is **per candidate**,
not shared by the reuse. Measured split: at small `d` the geometry dominates (reuse
helps a lot, ~1.7× confirmed); at large `d` the solve dominates (reuse barely
helps). CSD4 already defers PS-LPS and notes its "expensive solve path," but the
plan should state explicitly that reuse does not reduce the per-candidate solve, so
the sparse grid's PS-LPS cost is governed by *how many high-`d` candidates it
solves* — another reason to keep `d_hi` (and the `d_auto` seed, per F1) small.

### F3 (clarification) — define the feasibility constraint precisely in CSD0
The plan repeatedly relies on "feasible (k,d)" and a "design margin" (lines 126,
196, 207) but never defines it. The governing constraint is that the local
polynomial design must be over-determined: for degree `g` in `d` chart dims the
design has `choose(d+g, g)` columns (before drop), which must be `< k` (with
margin). CSD0's schema should encode this exact rule so `feasible`/`skip.reason`
are computed deterministically, and so `d_hi = min(6, p, k − margin)` has a
precise `margin`.

### F4 (clarification) — reconcile with the existing OD-CV2 `chart.dim.grid` axis
OD-CV2 already exposes `chart.dim` as a numeric CV candidate axis with the reuse
path (audited). The coupled selector overlaps with it. The plan should state
whether the coupled `(k,d)` selector is a new candidate-generation layer feeding
the *existing* reuse evaluator (most consistent with CSD1's "generalize the
current OD visit-CV reuse helpers"), or a parallel path. Making this explicit
avoids two divergent selection code paths.

## Minor notes

- The reuse group can vary `degree` freely (the PCA is degree-independent; degree
  only affects the design). CSD1's grouping helper should exploit this so a
  `(k,d) × degree` guard set doesn't split reuse groups unnecessarily. (The
  existing code already keys on `(support, kernel)` only, so this is naturally
  supported.)
- CSD3 correctly requires recomputing chart-space distances *and* the adaptive
  bandwidth after slicing; make the bandwidth part explicit, since for chart-kernel
  the bandwidth is derived from the (now-changed) chart distances.
- `local.auto` deferral (lines 168–171) is the right call; note it could still use
  a *max-local-dimension* PCA cache later (slice each anchor to its own dim from a
  single build), which the plan already hints at.

## Charter-layer assessment

- **Estimation & selection fairness (the plan's core):** the design is fair —
  it searches `(k,d)` jointly, keeps an oracle full-grid reference, and probes
  boundary-driven optima. F1 is the one place where a poorly-chosen seed could
  bias cost (not correctness).
- **Implementation correctness (design level):** the reuse-semantics distinction
  is correct; the main engineering risk (reusing chart-space kernel weights) is
  correctly identified and guarded.
- **Artifacts/provenance & rendering:** CSD5 points at the HTML/report style and
  figure-QC guides and asks the right evaluation questions (oracle regret,
  runtime, homogeneous vs non-manifold behavior — the last is exactly where auto's
  over-selection shows up).
- Data/measurement/inference layers: N/A at plan stage.

## Recommendation

Approve starting CSD0 + CSD1 as the plan recommends (schema + reuse-aware backend
are small and independently auditable). Before CSD2 integration, fold in F1 (cap
the `d_auto` seed / bound the group max dimension) and F3 (precise feasibility
rule), and add the F2/F4 clarifications to the spec. Keep the "no default change
until audited" gate. When CSD1 lands, the parity test I would insist on is the
same one that passed for the existing reuse: cached vs uncached scores identical
to ~1e-9 across dims, kernels, degrees, and at least one exactly rank-deficient
support.
