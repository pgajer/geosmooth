# E1.10 — Implementer spec questions and API decisions (to the orchestrator)

Date: 2026-06-11
From: implementer agent (E1.10, nested + grouped CV)
To: orchestrator
Status: submitted **before implementation**. **[proposal]** items need
ratification (§H amendment or no-objection); **[info]** items are factual
readings I follow unless corrected.

## 1. Part A API surface — package functions, not script-locals **[proposal]**

Contract §B/E1.10 "Implements" names only a validation utility
(`validation/e1_10_nested_grouped_cv.R`) and no package API change. Part A's
deliverable, however, is deterministic `testthat` GATEs over the nested-CV and
grouped-foldid machinery, and script-local functions are not cleanly testable
(tests would `source()` a non-installed path and break under `R CMD check`).
I counter-propose two **additive** exported functions in `R/lps_cv_utils.R`:

- `lps.grouped.foldid(cluster.id, v = 5L, shuffle.seed = NULL)` — cluster-
  respecting foldid: every cluster wholly inside one fold (size-balanced
  greedy assignment, deterministic tie-breaks; optional seeded cluster
  shuffle, seed recorded by the caller). `v = nlevels(cluster.id)` yields
  leave-cluster-out.
- `lps.nested.cv(X, y, outer.foldid, fit.args = list(), inner.folds = 5L,
  cluster.id = NULL, inner.foldid.method = c("round.robin", "grouped"),
  inner.shuffle.seed = NULL)` — outer-fold loop; per outer fold the inner
  candidate selection is one ordinary `fit.lps` call on the inner-training
  rows with an **explicit inner foldid** and `X.eval` = the outer-test rows;
  returns the pooled nested estimate, the per-fold selected configurations,
  the full-data selected-min arm computed from the **same** `outer.foldid`,
  and complete foldid/index telemetry.

No existing code path is touched: `fit.lps` and its signature are unchanged
(machinery consumes the public API with explicit `foldid` only), so "default
= bit-for-bit current behavior" is vacuous for existing entry points and the
E1.9b reference GATEs — which keep running in the E1.10 bundle — remain the
regression pin. Fallback if the orchestrator rejects package-level API:
define the same functions inside the validation script and `source()` them
from the GATE file (works in this repo's pkgload harness; weaker under
`R CMD check`).

## 2. Pairing enforced structurally **[info]**

`lps.nested.cv` computes the selected-min and nested estimates from the same
`outer.foldid` in one call, and rejects `fit.args` containing any of
`X`, `y`, `foldid`, `X.eval` (error). An arm therefore cannot be handed a
different fold assignment through the back door; the §sec:paired "same
foldid to both arms" obligation for study (a) holds by construction and is
GATE-asserted on the recorded telemetry.

## 3. Inner-fold construction **[info]**

Explicit and recorded, never `cv.seed`: `"round.robin"` assigns
`rep_len(1:inner.folds, n_inner)` over inner-training rows in row order
(deterministic; with `inner.shuffle.seed` the rows are permuted once,
seeded, before assignment — the realized inner foldid is returned either
way); `"grouped"` builds inner folds with `lps.grouped.foldid` on the
inner-training rows' `cluster.id` (grouped nested CV). Every realized inner
foldid is part of the return value, so a study artifact records the exact
folds used.

## 4. Study (b) primary statistic — nested under both foldings **[proposal]**

The plan says "the same [statistic] for random-fold and cluster-fold
estimates" without fixing whether the estimate is the selected-min score or
the nested estimate under that folding. I predeclare the **nested estimate
under each folding as primary**: selection optimism is then corrected
identically in both arms and the contrast isolates the dependence-leakage
axis (the object of claim (b)). The selected-min variant under each folding
is computed and recorded as supplementary, not gated. If the orchestrator
prefers the selected-min reading as primary, this is a one-line change in
the study's predeclared header — please rule before the acceptance run.

## 5. Study (b) fresh-cluster test size **[proposal]**

The spec pins disjoint fresh test clusters but not their count. I predeclare
`K_test = 100` fresh clusters × `m = 20` (n_test = 2000), cluster ids
disjoint from training, identical truth and noise law. Rationale: the
fresh-cluster RMSE is the denominator of both arms' statistics; 2000 points
keeps its MC error well below the 0.10 decision margin.

## 6. Realized ρ reporting **[info]**

Per replicate, realized intra-class correlation is estimated from
`y − truth` by one-way ANOVA variance components over training clusters
(method-of-moments ICC), reported alongside the nominal ρ.

## 7. Smoke fixtures and the registry boundary **[info]**

Part B's harness is built and smoked now on inline pipeline fixtures that
are deliberately **not** the plan DGPs (a 2-D sinusoid surface for the
optimism pipeline, a generic clustered random-effects draw for the grouped
pipeline; both labeled "smoke fixture — never acceptance evidence" in code
and output). The acceptance path consumes only the registry generators
`dgp.g3a` / `dgp.g5` through a single thin adapter shim (their exact
signatures are not visible on this branch yet — the registry is not merged
here) and refuses to run unless the generators resolve **and** the
orchestrator's confirmation is supplied explicitly
(`LPS_E110_ACCEPT=1`), per the assignment's sequencing instruction. No
G3a/G5 logic is hand-rolled.

## 8. Sub-item typing **[info]**

Per contract §A1 the E1.10(a)/(b) acceptance rules are **STUDY** decision
rules emitting one-row machine-readable verdicts (the assignment's "GATE:"
prefix is read as "acceptance criterion of the study"). Part A's
no-leakage / cluster-integrity / paired-discipline tests are deterministic
**GATE**s in `testthat`. If the orchestrator intends (a)/(b) to be CI gates
instead, that needs a §H amendment.

## 9. Part A GATE designs **[info]**

1. **No selection leakage (behavioral invariance):** for each outer fold k,
   replacing the held-out fold's `y` values by an arbitrary large shift (and,
   in a second variant, moving its `X` rows) must leave fold k's inner CV
   table, selected configuration, and (for the y-shift) fold-k predictions
   bit-identical; other folds may legitimately change. This is the invariant
   the named mutation (leak the outer-test fold into inner selection) breaks.
2. **Cluster integrity:** on a fixture with unequal cluster sizes — every
   cluster lies wholly in one fold; folds are nonempty and 1..v; no cluster
   appears in both a fold and its complement's training side; v = #clusters
   reproduces leave-cluster-out; deterministic without a seed and
   reproducible with one; grouped nested mode keeps every inner foldid
   cluster-whole as well.
3. **Paired discipline:** the selected-min and nested legs record identical
   `outer.foldid`; the underlying `fit.lps` objects' `$foldid` round-trip the
   constructed folds exactly; `fit.args` injection of `foldid`/`X`/`y`/
   `X.eval` errors.
