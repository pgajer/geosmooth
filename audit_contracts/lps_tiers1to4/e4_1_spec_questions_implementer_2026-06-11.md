# E4.1 — Implementer spec questions and API decisions (to the orchestrator)

Date: 2026-06-11
From: implementer agent (E4.1, pointwise variance & confidence bands; worktree
`geosmooth-t4`, branch `codex/geosmooth-t4-uncertainty`)
To: orchestrator
Status: submitted **before implementation**, per the spec-questions phase.
Items marked **[proposal]** need orchestrator ratification (contract §H
amendment or explicit no-objection); items marked **[info]** are factual
readings I will follow unless corrected; items marked **[question]** block
only what they name. Per the assignment, Part A (variance/band machinery +
deterministic unit GATE) lands now; nothing below blocks it except by
ratification of names. Items 4(a)–4(b) block only Part B's **acceptance run**,
which is in any case gated on Amendment 1's audited G3a.

## 1. API: two standalone exported functions, no `fit.lps` signature change **[proposal]**

- `lps.smoother.matrix(object, check.tol = 1e-10)` — extracts the linear
  smoother matrix `S` (`n_eval × n_train`) **analytically** from a fitted,
  fixed-configuration, gaussian, R-backend `lps` object: per eval point it
  rebuilds the identical KNN support, kernel weights, local chart, and local
  design via the same internal helpers the fit used
  (`.klp.local.order`, `.klp.kernel.weights`, `.klp.local.coordinates`,
  `.klp.get.local.design`, `.klp.orthogonal.polynomial.transform`,
  `.klp.local.ridge.scale`, `.klp.local.design.condition`), then computes the
  influence row `l_ok = w_ok · (B̃ · solve(B̃'WB̃ + ρ·s·I, p̃))` in the exact
  transformed basis and ridge branch the solve used. **Self-guard:** the
  function verifies `max|S %*% y − fitted.values.raw| ≤ check.tol` against the
  object's own stored fit and aborts on violation, so any drift between the
  replica and the estimator is a hard error, never a silent divergence.
- `lps.pointwise.band(object, sigma = NULL, level = 0.95, check.tol = 1e-10)`
  — computes `Var(ŷ_i) = σ² Σ_j S_ij²`, `se_i = σ·‖S_{i·}‖₂`,
  `df = tr S`, `RSS`, `σ̂² = RSS/(n − tr S)`, and the band
  `ŷ_i ± z_{(1+level)/2}·σ·‖S_{i·}‖₂`. `sigma = NULL` uses the plug-in `σ̂`
  (`sigma.source = "plug.in"`); a supplied positive scalar is the known-σ
  variant (`sigma.source = "known"`). Returns named fields:
  `fitted, se, variance, lower, upper, level, z, sigma, sigma.hat,
  sigma.source, df, rss, n.train, smoother.row.norm, configuration`.

Rationale: zero modification of the estimator path — contract §A2's
bit-for-bit default holds **structurally** because no `fit.lps` argument or
behavior changes at all (admitted plainly: the §A2(i) regression pin is
vacuous-by-construction for Part A; there is nothing to pin). The analytic row
algebra is the *implementation* route; the E0.2 column-by-column `fit(e_j)`
probe stays the *independent verification* route in the GATE, so the two
routes to `S` are genuinely different code paths. It also minimizes the merge
surface with E1.9's concurrent edits to `R/lps.R` (new code lives in a new
file `R/lps_uncertainty.R`).

Alternative (not proposed): thread a `return.smoother` flag through
`fit.lps → .klp.predict.local.polynomial → .klp.fit.intercept →
.klp.fit.intercept.design → .klp.solve.local.wls`. More invasive, touches the
CV hot path used by every gate, and would make the GATE's "independent
extraction" partially self-referential.

## 2. Supported configuration envelope **[proposal]**

Both functions `stop()` with an informative message unless the fit satisfies:

- `class` `lps`, `outcome.family = "gaussian"`, `backend.used = "R"`;
- `design.basis = "orthogonal.polynomial.drop"`;
- singleton grids — `nrow(cv.table) == 1` (no candidate selection occurred,
  per the spec §sec:smoother mandatory restriction);
- chart-dimension mode `ambient` (coordinate.method `"coordinates"`) or
  `fixed` with an explicitly numeric `chart.dim` (coordinate.method
  `"local.pca"`); `"auto"` / `"local.auto"` / NULL-default local-PCA modes are
  rejected;
- `lps.pointwise.band` additionally requires `X.eval` identical to `X`
  (`df = tr S` and `RSS` are defined on the square training-fit smoother).
  `lps.smoother.matrix` itself accepts any `X.eval` (rectangular `S`).
- any `ridge.multiplier.grid` / `ridge.condition.max` are accepted: the
  replica reproduces the ridge-selection loop exactly, branch for branch.

Why `orthogonal.polynomial.drop` only: the zero-ridge fast paths for
`weighted.qr`/`weighted.qr.drop`/`monomial` solve by LAPACK QR / `lm.wfit`;
an analytic influence row there would mix numerical routes (normal equations
vs. pivoted QR) and weaken the exactness guarantee. The orthogonal basis
always routes through the normal-equations branch, is numerically
near-orthonormal by construction (so the influence solve is as well-conditioned
as the coefficient solve), and is the basis E0.2 validated and E4.1 pins.
Widening the envelope (other bases, new-point bands, `bernoulli`) would be a
future amendment, not silent scope creep.

## 3. NA/fallback semantics of the extracted rows **[info]**

Per-point fallbacks are reproduced honestly: a weighted-mean fallback
(`unstable.action = "mean"`) yields the exact linear row `w/Σw`; an
`unstable.action = "na"` non-fit yields an all-`NA` row, which propagates to
`NA` variance/band at that point. The E4.1 fixed configuration (ridge grid
`0`, `ridge.condition.max = Inf`, `unstable.action = "na"`) produces no
fallbacks on healthy data; the Part A GATE fixture asserts zero `NA`s, so a
fallback firing there is a test failure, not a masked degradation.

## 4. E4.1 knobs the spec/contract leave unpinned **[question — blocks only Part B acceptance]**

(a) **Support size `K` and kernel** of the fixed configuration. The spec pins
singleton grids, `chart.dim = 2`, degree 1, `n = 1200`, `σ = 0.1`, `R = 500`
— but neither `K` nor the kernel. Interior coverage is bias-sensitive through
`K` (the band is variance-only, so an over-smoothed fit under-covers even in
the interior). I propose the orchestrator pins `(K, kernel)` together with
Amendment 1's G3a freeze, before the acceptance run. The smoke harness
parameterizes both and records them; its defaults are `K = 30`,
`kernel = "tricube"`.

(b) **G3a curvature knob** (`R` in `X = (u₁, u₂, (u₁²+u₂²)/(2R))`). G3a calls
`R` "the curvature knob" with no default and E4.1 does not name a value. I
assume Amendment 1's frozen G3a registry fixes it; the smoke harness
parameterizes it (`curvature.radius`, default 1) and records it.

(c) **Geometry fixed across replicates** **[info-reading]**: "per eval point,
empirical coverage of `f(x_i)` across replicates" reads as
conditional-on-design coverage — one frozen `X` (its own recorded seed),
noise redrawn per replicate with seed `s₀ + r` per §sec:rng. The harness is
built this way; if the orchestrator intends design redrawn per replicate, the
harness needs a one-line change and the coverage target changes meaning.

(d) **Boundary stratum's `h`** **[proposal]**: "x within `h` of the disk
edge" — I implement per-eval-point realized bandwidth `h_i` (the `K`-th NN
ambient distance at `x_i`), flagging point `i` as boundary iff
`1 − ‖u_i‖ < h_i`, and additionally report the stratum size under the global
alternative (`h = median_i h_i`) so the choice is visible. Strata
(interior / boundary / top-curvature-decile) are reported separately and
never averaged into the interior headline, per the safeguard.

## 5. Coverage-study fast path **[proposal]**

`S` depends only on `(X, configuration)`, not on `y`; with the geometry fixed
across replicates (4c), the harness extracts `S` once and computes each
replicate's fit as `ŷ_r = S y_r` (the E0.2-pinned identity), instead of
calling `fit.lps` 500 times. Drift guard: at replicate 1 and every 25th
replicate (and the last), the harness ALSO runs the full `fit.lps` call and
asserts `max|fitted − S y_r| ≤ 1e-10`, aborting the study on violation. A
`fit.every.replicate = TRUE` flag forces full per-replicate fits if the
orchestrator wants acceptance evidence without the shortcut; runtime is the
only difference claimed.

## 6. Part A GATE fixture **[info]**

`tests/testthat/test-lps-tier4-uncertainty.R`, all test names carrying
"E4.1" for gate-coverage extraction. Deterministic, seeded, no DGP-library
dependency: (i) an ambient-coordinates case (`D = 2`, the E0.2 G1-style
seeded uniform cloud) and (ii) a `local.pca` `chart.dim = 2` case on a seeded
inline quadratic surface in `D = 3` (a unit *fixture*, not a DGP-library
bypass — no STUDY consumes it). Singleton configuration (`K = 18`, degree 1,
tricube, explicit `foldid`, ridge `0`, `ridge.condition.max = Inf`,
`unstable.action = "na"`), known `σ₀ = 0.37` (arbitrary positive constant).
Reference `S` is extracted **column-by-column through the public API**
(`fit.lps(e_j)`, the E0.2 protocol, implemented test-locally). Assertions, all
max-abs `≤ τ_alg = 1e-10`: per-point variance vs `σ₀² Σ_j S_ij²`;
`‖S_{i·}‖₂`; `df` vs `tr S`; `σ̂²` vs `RSS/(n − tr S)` recomputed from the
probe `S`; band endpoints vs `ŷ_i ± z_{0.975}·σ·se_i` under both known-σ and
plug-in variants; plus `ŷ = S y` consistency and zero-`NA` assertions, and
negative controls (non-singleton grids, auto chart modes, `X.eval ≠ X`,
non-gaussian family, non-orthogonal basis each `stop()`).

## 7. Execution bundle **[info]**

`scripts/ci/run_e4_1_execution_artifact.sh`, patterned on the Tier-0 harness:
clean-committed-tree binding, source checksums over `R/lps.R`,
`R/lps_uncertainty.R`, and the gate file, `sessionInfo`/BLAS capture, full
testthat results CSV, gate-context extraction by regex `E4[.]1`, manifest +
bundle checksums. The bundle also runs the Part B smoke harness at smoke size
with `dgp.source = "inline-smoke"` recorded in its verdict row — wiring
evidence only, never acceptance evidence; the manifest says so explicitly.

## 8. Naming **[info]**

Dot-delimited per repository convention; `lps.`-prefixed exports parallel to
`lps.backend.diagnostics`. If the orchestrator prefers different names
(e.g., `lps.variance.band`), renaming before Part B acceptance is a trivial
amendment; after the Part A audit it would require a versioned one.
