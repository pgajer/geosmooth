# Tier 2 — Implementer spec questions and API decisions (to the orchestrator)

Date: 2026-06-11
From: implementer agent (Tier 2 — binary path & numerical hygiene; worktree
`geosmooth-t2`, branch `codex/geosmooth-t2-binary-hygiene`, base `b86b796`)
To: orchestrator
Status: submitted **before implementation**, per the spec-questions phase.
Items marked **[proposal]** need orchestrator ratification (contract §H
amendment or explicit no-objection); items marked **[info]** are factual
readings I will follow unless corrected. Realized numbers below were measured
on the pre-change source at `b86b796` with replicated solver internals (the
solver has no trace hooks yet); the implemented GATEs will re-measure on the
actual routine.

Sequencing per the assignment: E2.14 first, then E2.12; **E2.13 does not start
until item 12 (§G4) is resolved**. Items 1–5 (E2.14) and 6–11 (E2.12) are
blocking only for their own gate.

## E2.14 — local logistic robustness (separation)

### 1. Implementation site and step-halving rule **[info]**

The local logistic IRLS is `.klp.solve.local.logistic` (`R/lps.R:1614`): plain
Newton/IRLS, every step accepted unconditionally, no deviance tracking;
convergence is on the coefficient step (`1e-7`, matching the plan §tol), cap
`max.iter = 50`, retried over `ridge.multiplier.grid`. I add deviance-based
step-halving inside the iteration loop:

- deviance = weighted binomial deviance
  `-2 * sum(w_i * (y_i*log(mu_i) + (1-y_i)*log1p(-mu_i)))`, with `mu` computed
  from the **existing** eta clamp `plogis(pmax(-35, pmin(35, eta)))` so logs
  stay finite (the clamp predates this change; documented in roxygen);
- a Newton candidate is accepted only if `dev(candidate) <= dev(current) +
  1e-8` (the contract's per-step slack); otherwise the candidate is halved
  toward the current iterate, up to a cap I propose as **30 halvings**;
- if the cap is exhausted and the deviance still increases, the solve stops
  with status `"step_halving_failed"` → non-convergence → the **existing**
  documented fallback in `.klp.fit.logistic.prob.design` (`R/lps.R:1575`)
  fires exactly as it does today for `"not_converged"`.

The convergence criterion itself is unchanged (coefficient step, `1e-7`).

### 2. New solver return fields (additive) **[proposal]**

`.klp.solve.local.logistic` returns a list; I add to it, in **both** the
converged and failed branches: `converged` (logical), `iterations` (accepted
Newton steps), `step.halvings` (total), `deviance.trace` (numeric vector:
initial deviance, then the deviance of each accepted iterate). These are
per-solve fields read by the GATE, which calls the solver directly per the
plan ("call the local logistic solver … directly on the constructed support;
record per-iteration deviance"). The trace is bounded by `max.iter + 1`
doubles; it is always populated (no flag), since the per-solve list is built
anyway and `fit.lps` does not retain it.

The **aggregate** telemetry the contract names (`converged`, `fallback.path`,
`event.rate.fallback`) already exists with exactly those names
(`.klp.logistic.telemetry.new`, `R/lps.R:717`), is surfaced per fit as
`logistic.diagnostics$cv` / `$final`, and is **unchanged** by this work. I
read the contract's "telemetered fallback (`converged`, `fallback.path`,
`event.rate.fallback`)" as binding to these existing fields plus the new
per-solve fields above. Please correct me if a different surface was intended.

### 3. Always-on vs opt-in (§A2 reading) **[proposal]**

I read contract §C / E2.14 "Implements: IRLS **step-halving**" as a mandated,
always-on robustness fix: **no new `fit.lps` argument**. The §A2 tension is
limited and structural: when every Newton step already satisfies the deviance
slack — every well-behaved solve — the halving check accepts the *identical*
Newton iterate, so those solves are numerically identical to current behavior
(the added deviance evaluations are read-only). Behavior changes **only** on
solves where a Newton step increases the deviance, i.e. exactly the defect
class the gate targets; on those, current behavior is oscillation →
non-convergence → event-rate fallback, and post-fix behavior is either a
genuine converged local logistic fit or the same fallback. Consequence I will
verify and report: binomial fits in Tier-0 E0.6 can change where supports are
(near-)degenerate; E0.6's assertions are statistical (slope CIs, calibration
bands, fallback fractions), and I will rerun the full Tier-0 battery after the
change and report the realized numbers in the handoff. **Confirm always-on is
the intended reading.**

### 4. GATE fixtures and realized pre/post behavior **[info]**

Both fixtures are deterministic (no RNG), in the plan's stated family
(`z ∈ R`, `y = 1{z>0}`, gaussian weights, degree 1), called with singleton
`rho = 0` and `ridge.condition.max = Inf`:

- **Near-separable** (one flipped label): `z = c(seq(-0.20, -0.04, by =
  0.02), 6)`, `y = 1{z>0}` with `y[2]` flipped to `1`. Two classes,
  not linearly separable (the flipped positive sits inside the negative
  cluster), exactly separable once the flip is removed. Realized pre-fix
  (replicated internals): the deviance trajectory **increases by ≈ 4.9e2 at
  step 2**, oscillates (8 increases > 1e-8), and does not converge within 50
  iterations (today this support silently degrades to the event-rate
  fallback). Realized post-fix: 1 halving at the critical step, trajectory
  non-increasing within `1e-8`, converged at iteration 9, `beta =
  (2.866, -6.355)` finite, `p_hat(center) ≈ 0.125 ∈ (0,1)`. The contract's
  mutation (disable step-halving) therefore reddens the trajectory assertion
  on this fixture. Fixture sensitivity I will document in the test file: the
  overshoot requires the flipped label near the **edge** of the negative
  cluster (a mid-cluster flip yields a monotone plain-Newton trajectory —
  measured), so the fixture is pinned exactly.
- **Exactly separable** (no flip): same `z`, `y = 1{z>0}`. Pre- and post-fix
  behavior coincide (no halving triggers): deviance decreases monotonically
  toward 0, no convergence within the cap, solver status `"not_converged"`,
  the documented fallback fires and is recorded in the telemetry (no NaN, no
  unbounded loop — the cap is the loop bound). The GATE asserts the fallback
  path and its telemetry, not a converged fit, for this fixture.

The GATE will additionally assert `step.halvings >= 1` on the near-separable
fixture (the feature demonstrably engaged) — stricter than the contract's
assertion list; flag if unwanted.

### 5. Pre-fix demonstration in the same file **[info]**

E2.14's contract text does not require a pre-fix demonstration (only E2.12's
and E2.13's do), but the near-separable fixture's pre-fix trajectory is the
natural motivating case. I will document the measured pre-fix behavior in the
test file as comments with the replication script committed under
`validation/`, not as a runtime assertion against deleted code.

## E2.12 — binary selection-metric consistency & log-loss clipping

### 6. Bernoulli selection column (the (a) fix) **[proposal]**

Facts: bernoulli selection currently scores `cv.rmse.observed` =
`.klp.rmse(pred_raw, y)` over **raw** CV predictions (`R/lps.R:1035`,
selection column per `.klp.selection.score.column`, `R/lps.R:808`), while
deployment clips to `[0,1]` (`fitted.values` via `.klp.response.scale`;
diagnostics report `brier.clipped`). `cv.brier.observed` is currently a
post-hoc decoration `cv.rmse.observed^2` (`R/lps.R:800`) — also raw.

Proposed fix: in `.klp.cv.table`'s R path, compute for bernoulli
`cv.brier.observed[j] = mean((y - clip01(pred[,j]))^2)` if all predictions for
candidate `j` are finite, `Inf` otherwise — i.e. the **deployed clipped Brier
with the current selection's NA semantics preserved** (`.klp.rmse` scores
`Inf` for any non-finite prediction today; a candidate that was unselectable
under `unstable.action = "na"` stays unselectable, so the fix changes ranking
only through clipping, never through NA treatment). The bernoulli selection
column becomes `cv.brier.observed`. `cv.rmse.observed` keeps its current
definition (raw RMSE) and remains in the table as a reported diagnostic. The
`rmse^2` decoration is removed for the R path (the column is now computed
directly); `print.lps` and `lps.backend.diagnostics` already read
`cv.brier.observed` by name and need no change. Binomial's `cv.brier.observed`
(`.klp.brier` on IRLS probabilities, which are already in `[0,1]`) is
unchanged; binomial selection stays on log-loss.

### 7. Log-loss clip pin (the (b) fix) **[proposal]**

Change the single definition `.klp.clip.probability(p, eps = 1e-15)`
(`R/lps.R:645`) to `eps = 1e-6`. Its only caller is `.klp.logloss`
(binomial selection score + the `logloss.clipped` diagnostic); the logistic
init at `R/lps.R:1671` already passes `eps = 1e-6` explicitly and is
unaffected. The GATE pins the constant by asserting the realized clip bounds.
Per the contract, the `1e-15` defect is demonstrated (one confident-wrong
point dominates the score) in the same file; cross-clip stability over
`{1e-6, 1e-3}` is the non-gated STUDY with a one-row verdict CSV.

### 8. Backend scope of the (a) fix **[proposal — needs a decision]**

The clipped selection score needs per-point CV predictions. The C++ CV
kernels (`rcpp_kernel_local_polynomial_cv_*`) return only the aggregate raw
RMSE per candidate (`R/lps.R:869`, `:901`), and bernoulli mode **can** reach
them today (`.klp.resolve.backend` ignores `outcome.family`; reachable with
`design.basis = "monomial"`, singleton `ridge = 0`, `ridge.condition.max =
Inf`, coordinates — not the defaults, but a legal configuration). Options:

- **(a) — recommended:** resolve bernoulli to the R backend always (parallel
  to the existing binomial rule at `R/lps.R:183`): `backend = "auto"` →
  `"R"`; explicit `backend = "cpp"` / `"cpp.local.pca"` with
  `outcome.family = "bernoulli"` errors with the same wording style as the
  binomial error. This makes the gate's invariant ("selection scores the
  deployed metric") unconditional. Cost: a narrow existing configuration
  (bernoulli + monomial + unguarded ridge + cpp) loses its fast path and is
  **not** bit-for-bit (it errors); every default-path bernoulli fit already
  runs the R backend and is unaffected.
- **(b):** keep the cpp path selecting on raw RMSE, document the
  inconsistency in roxygen. Bit-for-bit everywhere, but the gate's claim
  holds only for the R backend, and the train/deploy mismatch survives in a
  documented corner.

I recommend **(a)** and will implement it on sign-off; (b) is the fallback if
you weigh §A2 strictly. The GATE itself runs `backend = "R"` either way.

**Addendum 8b (2026-06-11, post-audit): RESOLVED as option (a).** The
independent audit (`audits/tier2_audit_2026-06-11.md`) accepted E2.12 with a
required fix — make the deployed-metric claim unconditional by either
forcing bernoulli to the R backend or implementing clipped scoring in the
C++ path — and the orchestrator forwarded the audit for action. Implemented
as option (a): `backend = "auto"` with `outcome.family = "bernoulli"`
resolves to `"R"` (exactly like `"binomial"`), an explicit C++ backend
errors, the now-unreachable raw-RMSE selection fallback in `fit.lps` is
removed, and `.klp.decorate.outcome.cv.table` fails loudly instead of
silently decorating a missing deployed-metric column. Gate coverage added in
`tests/testthat/test-lps-binary-metric-consistency.R` ("bernoulli always
uses the R CV path"), including a gaussian control pinning that the C++
fast path remains available outside the binary families.

### 9. `keep.cv.predictions` opt-in argument **[proposal]**

`fit.lps` currently discards the per-candidate CV prediction matrix
(`cv.result$predictions`). The (a) GATE asserts "selection score equals the
deployed clipped metric"; the strong form recomputes the deployed metric from
the **actual** CV predictions rather than from a test-side CV
re-implementation. I propose a new `fit.lps` argument `keep.cv.predictions =
FALSE` (default → bit-for-bit; §A2-compliant), which when `TRUE` stores the
`n × n.candidates` matrix as `$cv.predictions`. Appended at the end of the
signature (positional safety, same convention as E1.9's item 9). Also
generally useful to the auditor. If rejected, the GATE falls back to a manual
CV loop over internal helpers (weaker: asserts against a re-implementation).

### 10. G6 motivating fixture for the ranking flip **[info]**

Per the plan's DGP rules ("references a tag and overrides only the parameters
it names"), the (a) fixture is G6 with named overrides: `n = 400`,
deterministic seed, and a **sharp** log-odds surface (override of the default
`eta(x) = 1.5*sin(pi*x1)`, e.g. a steep tanh cliff; exact form pinned in the
test file) so degree-2 local fits near the cliff extrapolate raw predictions
outside `[0,1]`, making clipped vs raw Brier rank two candidates differently.
The flip is verified "real, not a tie" by asserting the cross-candidate score
margin exceeds `100×` the comparison tolerance `1e-6` on both metrics. The
pre-fix discrepancy is demonstrated **in the same file** from the post-fix
fit object: the cv.table retains the raw scores (`cv.rmse.observed`), so the
test asserts `argmin raw ≠ argmin clipped`, that the fitted object selected
the clipped winner, and (as documentation of the old rule) that the raw
argmin is the candidate the pre-fix selection rule would have returned. I
will construct the exact fixture during implementation; if no clean ranking
flip materializes within G6 overrides, I will report back here rather than
stretch the DGP.

### 11. Binomial NA-handling asymmetry — observation only **[info]**

While reading the selection path I noted: gaussian/bernoulli selection scores
`Inf` for a candidate with any non-finite CV prediction (`.klp.rmse`), but
binomial selection (`.klp.logloss`) **drops** non-finite pairs, so a binomial
candidate predicting `NA` on most points is scored on the remainder and can
win. This is outside E2.12's contract scope; I am **not** changing it. Flag
for a possible future amendment; happy to file it as a separate finding.

### 11b. Addendum (2026-06-11, before the E2.12 tests landed): corrected
### dominance definition for the (b) demonstration **[info]**

Item 10's parenthetical proposed defining "dominated by a single
confident-wrong point" as *that point's contribution exceeding the sum of
all other contributions* at clip `1e-15`. Measured on the constructed G6
fixture this definition is unachievable for `n = 400`: G6 pins
`p ∈ [0.05, 0.95]`, so the irreducible per-point log-loss is on the order of
`-log(0.95) … -log(0.05)` and the 399 other points sum to roughly 40–140,
while the single point's maximum possible contribution is `-log(1e-15) ≈
34.5`. Implemented (and asserted) definition instead, stated before the test
was written: at clip `1e-15` the deliberately confident-wrong point (i) is
the **unique** point whose wrong-side clip binds at `1e-6` (its realized CV
prediction is exactly `0`, the all-zero-neighborhood event-rate fallback);
(ii) accounts for **> 99.9 %** of the score change between clips `1e-15`
and `1e-6` (realized: 100.000 % on both candidates — no other prediction
lies outside `[1e-6, 1 - 1e-6]`); and (iii) is the **largest single
contributor** to the `1e-15` score by a factor `> 5` on the selected
candidate (realized: `34.54` vs `4.03`, ratio `8.6`). This is the defect the
spec names — the score's clip-sensitive component is one point — without the
impossible sum comparison. Flag if you want a different operationalization;
the fixture and assertions are otherwise per contract.

## E2.13 — ridge-penalty alignment (§G4)

### 12. §G4 resolution — proposed default state **[proposal — blocking E2.13]**

Facts (current source, `b86b796`): the ridge penalty in the **orthogonal**
basis penalizes every transformed direction including the constant —
`penalty.base = diag(1, p)` in both the WLS solver
(`.klp.solve.local.wls`, `R/lps.R:2026–2031`) and the logistic solver
(`.klp.solve.local.logistic`, `R/lps.R:1674–1679`) — so large `rho` shrinks
the local prediction toward **0**, not toward the local weighted mean. The
non-orthogonal branch (`monomial`, `weighted.qr*`) already leaves column 1
(the constant) unpenalized via `diag(c(0, 1, …))`. The defect is specific to
the orthogonal-basis branch, which is the **default** `design.basis` and the
one Tier-0's accepted ridge defaults (`ridge.multiplier.grid = c(0, 1e-10,
1e-8)`, `ridge.condition.max = 1e12`) run through.

Proposal, per the assignment's strong preference and §A2:

- New `fit.lps` argument **`ridge.shrinkage.target = c("zero",
  "local.mean")`**, default `"zero"` = current behavior **bit-for-bit**
  (the default path does not even compute anything new). `"local.mean"`
  activates the aligned solve. Name rationale: the user-visible semantics is
  the shrinkage target, not the penalty's matrix structure; happy to take
  `ridge.penalty.alignment` or another name instead.
- Scope: the **gaussian/WLS solver only** (E2.13's plan section is G1 +
  weighted-mean target). The logistic solver's identical penalty structure is
  explicitly **out of scope** for E2.13 unless you say otherwise — aligning
  it changes the binomial path E2.14 just stabilized, and its natural target
  (shrink eta toward `qlogis(weighted event rate)`) deserves its own
  gate/typing decision. The argument signature will not promise logistic
  behavior it does not implement (documented in roxygen).
- Implementation of `"local.mean"` (for transparency, decided now, details at
  implementation): weighted-centering reparametrization — solve the
  penalized system on the weighted-centered response and the non-constant
  directions, add back the local weighted mean — which is the standard
  equivalent of leaving the constant function unpenalized; as `rho → ∞` the
  prediction tends to the local weighted mean exactly, and at `rho = 0` the
  solve is the unpenalized WLS (the GATE's `1e-6` tiny-ridge invariance then
  has structural slack). If you want the literal "unpenalized constant
  direction in the transformed basis" construction instead (project the
  penalty off the transformed image of the constant column), say so — the
  two differ only in how the non-constant penalty directions are weighted,
  and the GATE's assertions hold for both.
- Tier-0 coupling: **none at the default.** The accepted Tier-0 base keeps
  `ridge.shrinkage.target = "zero"` bit-for-bit; no Tier-0 test changes. The
  E2.13 GATEs run the opt-in `"local.mean"` arm; the contract's "pre-fix
  test documents the shrink-to-zero behavior" becomes a **permanent**
  regression pin of the default arm (`rho = 1e2` under `"zero"` shrinks
  toward 0), which simultaneously serves as the §A2 regression GATE for the
  new argument.

**Request: sign off on (i) the argument name and default `"zero"`, (ii) the
gaussian-only scope, (iii) the centering construction — or amend.** I will
not start E2.13 (including its tests) before this lands as a §H amendment or
an explicit no-objection.

## Cross-cutting

### 13. Evidence bundles and Tier-0 reruns **[info]**

Per gate: a Tier-2 variant of the Tier-0 harness
(`scripts/ci/run_tier0_execution_artifact.sh` pattern: clean committed tree,
git head, source checksums, `sessionInfo`, BLAS id, per-test results, gate
coverage, realized quantities, full `fit.lps`/solver argument lists, seeds)
writing to `audit_artifacts/<gate>_<UTC>/`. After each gate's source change I
rerun the **full** Tier-0 battery in the same bundle and report any movement
in E0.6's realized statistics in the handoff (E2.12's selection change and
E2.14's solver change can legitimately move them; the assertions are
statistical). Handoffs at `phase_handoffs/<gate>_implementer_handoff_<date>.md`,
facts + limitations only. No self-run mutation as acceptance evidence.

### 14. Tie-break note for the bernoulli selection switch **[info]**

`.klp.select.best.idx` breaks score ties by ascending `(support.size, degree,
kernel)` and is column-agnostic; switching the bernoulli score column does
not alter tie-break semantics. Score ties across candidates under the clipped
metric resolve exactly as they do today under the raw metric.
