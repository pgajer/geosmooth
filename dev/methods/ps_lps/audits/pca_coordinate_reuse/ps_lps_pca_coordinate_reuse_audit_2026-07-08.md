# PS-LPS PCA-Coordinate Reuse Optimization — Implementation Audit

Date: 2026-07-08
Auditor role: independent auditor (worker-auditor workflow)
Repository: `/Users/pgajer/current_projects/geosmooth`
Audited commit: `7454453 Reuse PS-LPS local PCA supports across chart dims`
Base: `63cf3fc`
Charter: `/Users/pgajer/.codex/notes/workflows/worker_auditor_workflow.md`
Handoff: `dev/methods/ps_lps/handoffs/phase/ps_lps_pca_coordinate_reuse_optimization_handoff_2026-07-08.md`

## Auditor-independence note

I originated this optimization idea (compute local PCA once at the max grid
dimension, slice for smaller dims) during the prior PS-LPS runtime investigation,
but I did **not** write the implementation under audit. Because I had a prior
hypothesis (~2× on the grid), I deliberately audited to *falsify* the
implementation — targeting numerical divergence and edge cases — rather than to
confirm it. Findings below are derived from an independent `-O2` build of the
audited commit and from raw fits, not from the handoff's tables.

## Verdict

**Accepted.**

The optimization is correct, effective, and safely scoped. Reused (sliced-from-
max-dim) coordinates produce **bit-identical** fits to direct per-dimension
computation across every case I tried, including the rank-deficient edge case I
expected to break it. The call-count reduction is real, the candidate grouping is
correct, fallbacks are honored, and there is no regression. I additionally
verified the wall-clock speedup the implementer left unmeasured (~1.7× on the
target grid). Four nonblocking observations, none gating.

## What I verified from primary sources

Built the audited commit `7454453` at `-O2` in a throwaway worktree (removed).
`R/ps_lps.R` and `R/state_density.R` are unchanged between `7454453` and current
`HEAD` (`b9d071c`), so this audits the live code.

### Correctness — reuse == direct (the central claim)
Compared the visit-CV score of a `chart.dim` candidate computed two ways: sliced
from a larger max-dim PCA vs. computed directly at that dimension.

- Generic data (n=500, p=100): `score(dim2 sliced-from-8)` vs
  `score(dim2 direct)` — **max abs diff 1.78e-15** (bit-identical to rounding).
- Multi-axis grid (`chart.dim.grid=c(1,2,4)` × `kernel.grid=c(gaussian,tricube)`
  × `degree.grid=0:1`, 2 supports): all 8 overlapping `dim2` cells match direct
  to **1.78e-15**. Reuse does not corrupt across kernels or degrees.
- `lambda.sync = 0` and `0.1` both covered by the implementer's equality test,
  which I re-ran (passes).

### The rank-deficiency edge — my main falsification target, resolved
I expected the reuse `stop("… fewer columns than the requested chart dimension")`
guard (`R/ps_lps.R:1510`) to fire on rank-deficient anchors (local support near a
low-dimensional manifold) where a candidate's `chart.dim` exceeds the local rank,
diverging from the direct path. It does **not**, because
`rcpp_ps_lps_local_pca_supports()` **always returns exactly `chart_dim`
columns** — it pads a rank-deficient support with (near-)zero trailing columns
(verified directly: exactly rank-3 data, 3 informative + 57 zero-variance dims,
requested at dim 8, returns 8 coordinate columns for every anchor). Consequently
the `ncol(coords) < d` guard is effectively unreachable via this native path, and
direct vs reuse produce **identical** scores even on exactly rank-deficient data
(`10.76315` both ways). No divergence.

### Call-count reduction and grouping
`rcpp_ps_lps_local_pca_supports()` is invoked once per `(support.size, kernel)`
group, not per candidate:
- `chart.dim.grid=c(1,2,4,8)` × 2 supports → **2** calls (would be 8 without
  reuse).
- `chart.dim.grid=c(1,2,4)` × 2 kernels × 2 supports × 2 degrees (24 candidates)
  → **4** calls (2 supports × 2 kernels), correctly independent of `degree`,
  `lambda`, and `chart.dim`. This grouping is sound: the local PCA coordinates
  depend only on `(X, support.size, kernel)` and the max dimension; degree/ridge/
  lambda affect only the downstream design and solve.
- The implementer's OD regression test (`3` dims × `2` supports → `2` builds) is
  a valid guard; it and the equality test pass (`140` + `69` assertions).

### Selection and final fit unaffected
Because per-candidate scores are bit-identical, the CV argmin selection is
unchanged. The final refit runs through the `od.cv="none"` path (no reuse plan),
so `rho` is produced by the unmodified direct path; `sum(rho)=1` confirmed.

### Fallbacks
`chart.dim="auto"` (and, by construction, `"local.auto"`, `"NULL"`, and
non-scalar cases) correctly bypass the reuse plan and run the prior direct path
(verified `auto` still fits, `sum(rho)=1`).

### Regression
OD test lane green at the audited commit (0 failures); the two focused test files
pass (140 + 69); the handoff reports `make test` exit 0.

### Wall-clock speedup (unmeasured by the implementer — verified here)
`chart.dim.grid=c(1,2,4,8)` × `support.grid=c(15,25,35)`, n=600/p=100:
**1.02 s** vs the **~1.73 s** pre-optimization baseline for the identical config
= **~1.7×**. `c(1,2,4)` × same supports = 0.68 s. The optimization delivers its
runtime goal (geometry was ~66% of this small-dim grid and is now shared).

## Findings by charter layer

- **Data-generating process / measurement / inference:** N/A (pure code
  optimization; no synthetic truth, metrics, or intervals introduced).
- **Estimation & selection fairness — PASS:** candidate scores and CV selection
  are bit-identical to the pre-optimization path; the optimization is invisible
  to model selection.
- **Artifacts & provenance — PASS:** commit `7454453` in history; files unchanged
  since; tests committed; handoff independence-clean (admissions-only, no
  suggested verdict).
- **Implementation correctness — PASS:** slicing the coordinate matrix (not the
  design) is the correct approach for `orthogonal.polynomial.drop`; grouping key
  is correct; guards and fallbacks are sound.
- **Rendering — N/A.**

## Nonblocking observations

1. **Handoff omitted the wall-clock speedup**, which is the whole point of the
   change (it reports only call-count + equality). My audit closes this (~1.7×),
   but future optimization handoffs should include a before/after wall-clock
   number for the target config.
2. **The `ncol(coords) < d` guard (`R/ps_lps.R:1510`) is effectively dead code**
   given the native builder always returns exactly `chart_dim` columns. It is
   harmless defensive code; leave it, but note the rank-deficient-anchor scenario
   it anticipates does not occur through `rcpp_ps_lps_local_pca_supports()`.
3. **The final refit (`od.cv="none"`) does not reuse** the selected candidate's
   already-built PCA; it recomputes it once. A minor missed optimization (one
   extra local-PCA build per fit), correct and outside the stated scope.
4. **Scope is narrow by design:** the win applies only to grids with multiple
   numeric chart dimensions sharing a `(support, kernel)`. Single fixed
   `chart.dim`, `auto`, and `local.auto` see no benefit (and correctly no harm).
   This is documented; combine with the prior runtime recommendation (use a
   bounded sparse numeric grid, not `auto`) to actually exercise the win.

## Validation commands run

```sh
git worktree add --detach <wt> 7454453; pkgbuild::compile_dll(<wt>, debug=FALSE)
testthat::test_file("tests/testthat/test-ps-lps.R")                       # 140 pass
testthat::test_file("tests/testthat/test-state-density-odcv3-lps-outer-visit-cv.R")  # 69 pass
make test-od                                                             # 0 fail
# independent falsification: equality (generic + multi-kernel/degree),
#   exact rank-3 data direct-vs-reuse, call-count, auto fallback, wall-clock.
git worktree remove --force <wt>
```

## Recommendation

Accept the optimization. Carry the four nonblocking notes forward; none require
changes before merge (it is already merged at `7454453`). To realize the win in
the OD5c runtime lane, pair it with the `-O2` build and a bounded numeric
`chart.dim.grid` (per the PS-LPS runtime investigation handoff).
