# E1.9 — Implementer spec questions and API decisions (to the orchestrator)

Date: 2026-06-11
From: implementer agent (E1.9, bandwidth multiplier)
To: orchestrator
Status: submitted **before implementation**, per the spec-questions phase. Items
marked **[proposal]** need orchestrator ratification (contract §H amendment or
explicit no-objection); items marked **[info]** are factual readings I will
follow unless corrected. Already-resolved §G1 / §G2 / §G5 are not re-litigated.

## 1. Backend coupling for `b ≠ 1` **[proposal]**

The C++ backends (`rcpp_kernel_local_polynomial_*`) hard-code the
`h = max(distances)` bandwidth convention internally; the multiplier is an
R-side feature. I propose the same constraint pattern the contract already
documents for ridge/design-basis (brief §1, "Backend constraints"):

- `backend = "auto"` with `bandwidth.multiplier.grid` ≠ exactly `c(1)` resolves
  to the **R backend** (silently, like a non-monomial design basis does).
- Explicit `backend = "cpp"` / `"cpp.local.pca"` with a grid ≠ `c(1)` is an
  **error** (consistent with the existing explicit-backend errors).
- Default grid `1` leaves backend resolution untouched (bit-for-bit).

Alternative (not proposed): implement `b` inside the C++ kernels. More invasive,
duplicates the semantics in two languages, and the contract does not ask for it.

## 2. Grid validation **[proposal]**

Mirror `.klp.clean.ridge.multiplier.grid`: `sort(unique(as.numeric(x)))`, keep
finite values `>= 0`, error if empty. This follows the contract's "numeric ≥ 0"
literally. Note: `b = 0` is degenerate — every `u = d/(0·h + sqrt(eps))` is
huge, so all weights underflow to ~0 and the existing all-zero-weight guard
(`weights[] <- 1` at `R/lps.R:1474`/`:1524`) or the `unstable.action` path
takes over (kernel-dependent flat-weight fallback, not an error). If the
orchestrator prefers, I can require strictly `> 0` instead; I implement `>= 0`
as written until told otherwise, and the STUDY grid `{0.5, 1, 2, 4}` is
unaffected either way.

## 3. Selection tie-breaking **[proposal]**

`.klp.select.best.idx` currently breaks score ties by ascending
`(support.size, degree, kernel)`. I append `bandwidth.multiplier` (ascending)
after `kernel`. Rationale: deterministic selection for multi-`b` grids;
ascending matches the existing prefer-smaller-support spirit. With a singleton
grid the extra key is constant, so the selection is provably unchanged
(adding a constant key to `order()` is a no-op).

## 4. "Bit-for-bit current behavior" — interpretation **[info]**

I read contract §A2(i) as: at the default `bandwidth.multiplier.grid = 1`, all
**numerics** (fitted.values, fitted.values.raw, CV scores, selected
configuration, predictions) are bit-identical to the pre-change code. The
implementation guarantees this structurally: the multiplier enters only as
`u <- distances / (b * h + sqrt(.Machine$double.eps))` at `R/lps.R:2370`, and
IEEE-754 `1 * h` is exactly `h`. The **return object shape** necessarily gains
the new named fields the contract itself requires
(`$selected$bandwidth.multiplier`, a `bandwidth.multiplier` cv.table column, a
stored `bandwidth.multiplier.grid`), per §A2(iii). The b=1 exactness GATE pins
the numerics against full-precision reference values generated at the
pre-change commit (commit hash recorded in the test file), tolerance
τ_alg = 1e-10 per the frozen thresholds; the pinning script is committed so the
generation is reproducible at the recorded commit.

## 5. Additive schema changes outside `fit.lps` **[proposal]**

- `cv.table` / `$selected` gain a `bandwidth.multiplier` column (required by
  the contract's `$selected$bandwidth.multiplier`).
- The fit object stores `bandwidth.multiplier.grid` (parallel to
  `ridge.multiplier.grid`).
- `lps.backend.diagnostics()` gains `selected.bandwidth.multiplier` and
  `bandwidth.multiplier.grid` columns. **Flag:** this widens a one-row manifest
  schema some downstream rbind-style tooling may consume; it is additive only.
- `print.lps` prints the selected multiplier **only when ≠ 1**, keeping default
  printed output byte-identical.
- `predict.lps` on an object fitted before this change (no
  `bandwidth.multiplier` in `$selected`) falls back to `b = 1` (documented).

## 6. `.klp.kernel.weights` signature **[info]**

Gains a third defaulted parameter: `.klp.kernel.weights(distances, kernel,
bandwidth.multiplier = 1)`. The §G1-resolved characterization call
`geosmooth:::.klp.kernel.weights(distances, kernel)` remains valid unchanged.

## 7. Characterization GATE fixed distance vector **[info]**

I use the deterministic vector `distances = sqrt(seq_len(20)/20)` (a 2-D
K-NN-like profile, K = 20, max distance 1, no RNG). Realized values on the
actual routine at the pre-change source: gaussian ESS/K ≈ 0.9797 (> 0.9),
tricube ESS/K ≈ 0.5220 (< 0.85), last-weight ratios tricube ≈ 9.2e-23,
epanechnikov ≈ 3.1e-8, triangular ≈ 1.9e-8 (all < 1e-6). All frozen
thresholds hold with margin; the realized quantities are emitted into the
execution bundle. Note the K-th weight of compact kernels is not exactly 0
because of the additive `sqrt(.Machine$double.eps)` in the denominator — the
spec's `< 1e-6` relative threshold is the right assertion and passes with
≥ 30× margin (epanechnikov is the binding case).

## 8. Benefit STUDY sequencing (E1.9 sub-item (c)) **[info]**

Per the assignment, the two GATEs land now; the STUDY → PROMOTION sub-item is
**deferred until Amendment 1 binds G3a/G3d** in the consolidated DGP module
(its own deliverable + audit). I am not improvising a one-off generator, and I
am not writing the study script against an unbound generator API. E1.9's
handoff will state this sub-item as open.

## 9. Naming **[info]**

No counter-proposal: `bandwidth.multiplier.grid` is consistent with
`ridge.multiplier.grid`, and `$selected$bandwidth.multiplier` follows the
cv-table column convention.
