# Coupled Support-Size × Chart-Dimension Selection — Plan RE-Audit

Date: 2026-07-08
Auditor role: independent auditor (worker-auditor workflow)
Repository: `/Users/pgajer/current_projects/geosmooth`
Artifact under audit: `dev/methods/lps/specs/coupled_support_chart_dimension_selection_plan_2026-07-08.md` (revised; ~18K, mtime 13:27)
First audit: `dev/methods/lps/audits/coupled_kd_selection/coupled_support_chart_dimension_selection_plan_audit_2026-07-08.md`
Charter: `/Users/pgajer/.codex/notes/workflows/worker_auditor_workflow.md`

Two-part re-audit as requested: (1) verify my prior findings were resolved;
(2) re-read the revised plan fresh for remaining issues.

## Part 1 — resolution of prior findings

All prior findings are resolved, several more thoroughly than I asked.

| Finding | Status | Where |
|---|---|---|
| **F1** uncapped `d_auto` seed defeats the cost model | **Resolved (beyond ask)** | New `d_auto.clipped(k) = min(d_auto.raw(k), d_hi(k))` (l.165, 190); `d_hi(k)=min(chart.dim.max, p, d_feasible.max(k,g))` (l.172); telemetry `chart.dim.raw/clipped/seed.clipped` (l.193–194, 272–274); acceptance criterion 5 (l.444); runtime-risk entry (l.468–472). |
| **F2** reuse amortizes PCA, not the PS-LPS solve | **Resolved** | Purpose l.14–20 and CSD4 l.373–385, with the exact `n × q(d,g)` cost statement. |
| **F3** feasibility rule undefined | **Resolved** | New "Feasibility Rule" section: `q(d,g)=choose(d+g,g)`, `k ≥ q + design.margin`, `design.margin=2`, `d_feasible.max(k,g)`; explicitly a prefit screen, not a rank/condition check. |
| **F4** reconcile with existing OD-CV2 `chart.dim.grid` | **Resolved** | CSD1 l.302–306: a candidate layer feeding the existing cached evaluator, "not a parallel selection implementation." |
| minor: degree shouldn't split reuse groups | Resolved | CSD1 l.308–310. |
| minor: recompute adaptive bandwidth after slicing | Resolved | CSD3 l.357–359. |
| minor: local.auto max-local-dimension cache | Resolved | l.248–250. |

Two responses deserve credit for exceeding the finding: the revision correctly
**rejected my "cap d_hi at 6" suggestion** as a universal statistical cap and
instead made `chart.dim.max` an explicit, recorded experiment/caller budget
(l.175–183) — the right design. And the feasibility rule is now a precise,
testable contract with dedicated CSD0 schema columns (`design.ncol`,
`design.margin`) and unit tests (CSD0 deliverables).

## Part 2 — fresh read: remaining issues

The revision is strong. One substantive item and three minor ones remain; none
blocks starting CSD0/CSD1.

### R1 (substantive, CSD5) — the strategy comparison needs an *outer* held-out evaluation and matched folds/score, or it is confounded
CSD5 compares `auto`, `local.auto`, the coupled sparse `(k,d)` selector, and an
optional full-grid oracle (l.252–257, 406–419), asking "does it improve over
independent/one-axis selection?" and "does it recover the best full-grid
candidate?". But the plan never states **how the arms are scored against each
other.** This is a selection-fairness / measurement gap (charter layers 2–3):

- If strategies are compared by the **inner CV score they each select on**, the
  comparison is circular. The coupled selector evaluates *more* candidates, so by
  chance it attains a lower inner held-out score than a one-axis search — it will
  look better even if it does not generalize better. "Best inner score" rewards
  search breadth, not model quality.
- A fair comparison needs an **outer** evaluation that none of the strategies
  optimized against: nested CV (inner folds select `(k,d)`; a held-out outer fold
  scores the selection), or a separate held-out set / known truth on the
  synthetic examples. "Regret vs full-grid oracle" must likewise be measured on
  that outer target, and the oracle defined as the outer-best (or true-best on
  synthetic truth), not merely the inner-CV winner.
- All arms must use **identical folds and the identical held-out metric** so
  differences are attributable to the selection strategy, not to scoring or fold
  variation.

Recommendation: add to CSD5 an explicit evaluation protocol — nested/outer
held-out scoring, matched folds and metric across arms, and (on synthetic cells
where truth is available) report accuracy against the true field, not only the
inner CV score. The synthetic OD4-expanded / P7X cells make this feasible since a
ground-truth density exists.

### R2 (minor) — dimension skeleton is degree-dependent; notation says `D0(k)` but feasibility is `d_feasible.max(k, g)`
`d_hi(k)` and `d_feasible.max` depend on degree `g`, and the plan allows a small
degree guard set (l.83–84). So the skeleton is really `D0(k, g)`. This is
harmless for the PCA reuse (the PCA is degree-independent, so the group builds at
`max` feasible `d` across degrees), but the spec should write `D0(k, g)` and state
that the reuse group's `max.numeric.chart.dim` is the max feasible dim across the
degrees present, so CSD1's grouping helper is unambiguous.

### R3 (minor) — local-refine `h=2` vs skeleton spacing ~10 leaves coverage gaps
With `K0={15,25,35}` (gap 10) and refine `k ∈ {k_best−2, k_best, k_best+2}`, the
support axis between the skeleton points is largely unexplored (e.g. k=20 is
reachable by neither the skeleton nor a refine around 25). This is within the
acknowledged "sparse grids miss narrow optima" risk, mitigated by guard
candidates and the full-grid oracle, so it is acceptable for a first policy — but
worth a one-line note that `h` should scale with the skeleton spacing (e.g.
`h ≈ gap/2`) to tile the support axis, or that a second refine round may be
warranted if the winner sits between skeleton points.

### R4 (minor) — `q(d,g)` uses the full monomial count; confirm this is intended vs the deployed `orthogonal.polynomial.drop` basis
The feasibility screen uses `q(d,g)=choose(d+g,g)`, the full pre-drop monomial
count (stated at l.113). That is the conservative, correct choice for a *prefit*
screen (the deployed `orthogonal.polynomial.drop` basis only ever has ≤ that many
columns), and the plan already says numerical rank/condition are checked
separately. No change needed — just confirming the intent is "screen on the
maximal possible column count," which is right.

## Verdict

**Revision accepted. Proceed with CSD0 and CSD1 as the plan recommends.**

The prior findings are all resolved (F1 and F3 notably well). Fold R1 into the
CSD5 evaluation protocol *before* CSD5 is executed — it is the one item that
could otherwise produce a misleading "coupled is better" conclusion — and add the
R2–R4 clarifications to the spec at convenience. None of these gates CSD0/CSD1,
which remain the correct, independently-auditable starting point. The plan's
acceptance criteria (cached==uncached parity, one-build-per-support, telemetry
for skipped/clipped candidates, no default change until audited, full-grid
reference) are the right gates; R1 strengthens criterion 6 by making the
comparison itself fair.
