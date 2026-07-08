# PS-LPS Count Runtime Speedup — Follow-up Investigation Handoff

Status: investigation complete; no package code merged
Role: runtime diagnostician / optimization investigator
Date: 2026-07-08
Package repo: `/Users/pgajer/current_projects/geosmooth`
Pipeline repo: `/Users/pgajer/current_projects/vaginal_community_trajectory_types`
Prior handoff: `docs/phase_handoffs/ps_lps_count_runtime_profiling_speedup_handoff_2026-07-06.md`

## Purpose

Follow-up to the 2026-07-06 PS-LPS runtime-profiling phase (which took
`ps_lps_count` from ~111s median to ~5–22s via cache reuse + fold batching +
native helpers, geosmooth commits `75906aa`, `99d8948`, `af8056d`). The question
here was: **can PS-LPS be sped up further?**

The investigation was diagnostic + prototyping only. **No changes were committed
to either repo's tracked source.** All benchmark builds were done in disposable
git worktrees (now removed). The one reusable code asset (an OpenMP prototype
patch) is preserved alongside this handoff.

All measurements below are on an Apple-silicon 16-core machine, geosmooth commit
`af8056d`, built optimized (`-O2`) unless stated. The canonical benchmark cell is
the fixed-candidate PS-LPS OD visit-CV call used by the prior handoff
(`n` design rows, `p` ambient dims, `support.grid=c(15,25,35)`, `degree=1`,
`kernel="tricube"`, `chart.dim="auto"`, `lambda.sync.selection="fixed"`,
5 visit folds). "HD100" = `n=600, p=100`.

## Headline findings, ranked by impact

### 1. The runtime pipeline runs a DEBUG (`-O0`) build — biggest, free win

The OD runtime worker loads geosmooth with
`pkgload::load_all(geosmooth_root, quiet = TRUE)`
(`analysis/101_subject_od_runtime_profile_worker.R:43`). `pkgload`/`pkgbuild`
default to **debug builds (`-O0 -g`)**. `-O0` makes templated Eigen (the local
PCA and normal-equations math) pathologically slow — this is what made the
geometry look like ~60% of runtime in the prior profiling.

Same source, same machine, HD100 fit:

| build | single-thread HD100 | geometry share |
|---|---:|---:|
| `-O0` (what the pipeline uses) | ~10.7 s | ~60% |
| `-O2` (proper optimized) | **2.33 s** (~4.6×) | ~7% |

So the entire "111s → 22s" saga was measured in the slow debug regime; a
properly optimized build is several times faster before any code change.

**Action:** build/install the *current* geosmooth source optimized for the
runtime pipeline (e.g. `R CMD INSTALL`, or `pkgbuild::compile_dll(debug=FALSE)`,
or point `library(geosmooth)` at an `-O2` install). Note the copy currently
installed in the R library is **stale** (no `fit.subject.od`), so `library()` is
not a drop-in until it is reinstalled from current source.

### 2. `chart.dim = "auto"` over-selects dimension — a pure win to fix

On the high-dimensional benchmark assets (2 informative dims + many
low-variance noise dims, exactly how OD4-extended's `embed_high_dim` builds
`HD40/HD100`), `chart.dim = "auto"` resolves to a **large** local chart
dimension, which inflates the sync linear system and **overfits**.

HD100-style cell (`n=600, p=100`, `support.grid=c(15,25,35)`):

| `chart.dim` | resolved dim | coefs/anchor | ncoef (system size) | fit | held-out neg-log-ρ (lower=better) |
|---|---:|---:|---:|---:|---:|
| `"auto"` | 25 | 26 | 15600 | 2.64 s | **20.25** (worst) |
| `2` | 2 | 3 | 1800 | 0.53 s (**~5×**) | 7.27 |
| `1` | 1 | 2 | 1200 | 0.32 s | **7.05** (best) |

This is **not** a speed/accuracy trade-off: the smaller chart dimension is both
faster **and** generalizes far better (auto fits noise in the local charts). The
sparse-Cholesky factorization that dominates the solve scales super-linearly with
`ncoef`, so over-selecting the chart dimension is the primary reason the solve is
expensive.

Because OD-CV2 made `chart.dim` a CV candidate axis, the held-out score itself
rejects `auto`:
- `chart.dim.grid = c("1","2","auto")` → CV **selects dim 1** (score 7.05 vs
  auto's 20.25), but total time is still ~2.7 s because the slow `auto` candidate
  is still evaluated.
- `chart.dim.grid = c("1","2","3")` (no `auto`) → **1.22 s** and CV selects
  dim 1 with the best score.
- Fixed `chart.dim = 2` → 0.53 s.

**Action:** stop using `chart.dim = "auto"` on these assets; use a small fixed
`chart.dim` (1–2) or a small-integer `chart.dim.grid` without `auto`. This is
~5× faster **and** more accurate — larger than the `-O2` or OpenMP wins, with no
downside.

**Deeper (package-level, results-changing) angle:** `auto` counting many
tiny-variance ambient-noise directions as real structure is a mild defect in the
auto chart-dimension resolver (`.local.pca.auto.chart.dim.with.metric` in
geosmooth `R/local_pca_charts.*` / `R/local_pca_chart_dim.R`). A guard — an
`auto.chart.dim.max`, or a more conservative variance/eigengap threshold — would
fix it at the source. This changes model behavior, so it is a design decision for
the human, not a drop-in optimization. (Related: the OD-CV1 audit already noted
the auto-dim's coordinate metric can be misled;
`split_handoffs/od_cv1_chart_dimension_auto_contract_audit_2026-07-06.md` in
geosmooth.)

### 3. OpenMP prototype for the per-anchor geometry (bucket 1) — conditional win

I built and measured an OpenMP parallelization of the per-anchor local-PCA loop
(`rcpp_ps_lps_local_pca_supports`). It is **correct** (bit-identical `rho`;
checksum matched the serial build at every thread count) and **scales well** in
isolation:

Isolated geometry (support=35, p=100), `-O2`, by `OMP_THREAD_LIMIT`:

| threads | 1 | 2 | 4 | 8 | 16 |
|---|---:|---:|---:|---:|---:|
| time | 0.053 s | 0.027 s | 0.014 s | 0.007 s | **0.005 s** (~10.6×) |

But its **full-fit** benefit is governed by geometry's *share*, which depends on
**ambient dimension `p`** (geometry cost ≈ O(n²·p); the sync solve is
~p-independent):

| p (n=800) | full fit @1 thread | @16 threads | full-fit speedup |
|---:|---:|---:|---:|
| 100 | ~2.4 s | ~2.4 s | ~1.08× |
| 500 | 8.43 s | 7.23 s | 1.17× |
| 1000 | 6.04 s | 3.66 s | 1.65× |
| 2000 | 8.71 s | 3.79 s | **2.30×** |

Growing **n** at fixed p makes OpenMP *less* useful (the coupled sync solve grows
faster than the parallelizable geometry): n=600 geometry ~7%, n=1500 ~4%.

**Verdict:** for the current assets (`p ≤ 178`) OpenMP gives ~10–20% on the full
fit at `-O2` — modest. It only becomes a real 2×+ win at `p` in the thousands.
Keep it in reserve for high-dimensional embeddings; do **not** prioritize it over
findings 1 and 2. The patch is preserved (see Assets).

### 4. Buckets 2 & 3 (sync solve + fold predictions) — no large pure-solver win

At `-O2` (n=1000, p=100), by direct `trace()` instrumentation:

| step | share | note |
|---|---:|---|
| `visit_predictions` (bucket 3 wrapper) | 50.2% | almost entirely the sync solve it contains |
| `sync_fitted` (bucket 2) | 50.1% | build + solve the sync system |
| ↳ `solve_rhs` (the linear solve) | 36.1% | **100% cold Cholesky factorization** (warm re-solve is 0.012s) |
| ↳ `component_cache` | 10.9% | normal-equations assembly (once per candidate) |
| ↳ `normal_cache` | 5.8% | " |
| ↳ `choose_ridge` | 4.2% | " |
| ↳ `rhs_matrix`, `fitted_matrix` | <0.5% | native, cheap |
| `geometry_cache` (bucket 1) | 17.3% | of which `rcpp_localpca` 7.3% |

Key facts about the solve:
- The normal matrix is **symmetric SPD** (`dsCMatrix`), so `Matrix::solve`
  already uses sparse **Cholesky**, not LU. No `forceSymmetric` win available.
- Folds are batched into **one multi-RHS solve** per candidate — the
  factorization is already shared across the 5 folds.
- The cost is the **cold factorization** of the normal matrix (1.24s for the
  26000×26000 system at auto-dim), which is near-optimal for its size. `dsCMatrix`
  caches its factor in `@factors`, which is why a naive re-timing looked like
  0.012s — beware this trap when benchmarking.
- Each candidate has a different normal (different support), so the 3
  factorizations cannot be shared across candidates. The final refit
  (`od.cv="none"`, via `fit.ps.lps`) re-factorizes the selected candidate's normal
  once more; its normal is identical to that candidate's CV normal, but the two
  paths use different data structures, so reuse is non-trivial plumbing for a
  modest (~1 of 4 factorizations) gain.

**Conclusion:** there is no large, safe, results-preserving optimization inside
the solver/prediction code itself. The solve is expensive because the *system is
big*, and the system is big because of `chart.dim` (finding 2). Fix the dimension
and buckets 2/3 shrink ~5× on their own.

## The `-O2` note (why it matters and how to build it)

`pkgload::load_all()` and `pkgbuild::compile_dll()` default to `debug = TRUE`,
which compiles with `-O0 -g`. Eigen is header-only and template-heavy; at `-O0`
its inner loops are not inlined/vectorized and run ~5–30× slower than `-O2`
(measured: isolated geometry support=35/p=100 was 1.61s at `-O0` vs 0.053s at
`-O2`). Because the analysis worker uses `load_all`, every OD runtime number in
the prior handoff reflects `-O0`.

To build optimized in a worktree/pipeline:
```r
pkgbuild::compile_dll("<geosmooth_root>", debug = FALSE, force = TRUE)
# then load without recompiling:
pkgload::load_all("<geosmooth_root>", recompile = FALSE)
```
or `R CMD INSTALL <geosmooth_root>` and `library(geosmooth)`.
Do **not** hardcode `-O2` in `src/Makevars` for a real build — R/`R CMD INSTALL`
already uses `-O2`; the `-O2` in the preserved prototype patch's Makevars is only
to override `pkgload`'s dev-mode `-O0` for a fair benchmark and must be dropped
before any merge.

## Assets

### OpenMP prototype patch (preserved, tracked)
`dev/methods/ps_lps/patches/ps_lps_openmp_prototype_2026-07-08.patch`
- Applies to geosmooth at commit `af8056d` (`git apply` clean there; rebase for
  later HEADs — `R/state_density.R` has since gained ~288 lines, but
  `src/ps_lps_cache_rcpp.cpp` and `R/ps_lps.R` were unchanged as of this work).
- Changes: `src/ps_lps_cache_rcpp.cpp` (two-phase restructure of
  `rcpp_ps_lps_local_pca_supports`: parallel per-anchor local-PCA into plain
  C++/Eigen buffers with per-anchor `try/catch` so no `Rcpp::stop` crosses the
  OpenMP boundary, then serial R-list assembly; `std::sort`→`std::partial_sort`;
  removed two now-dead helpers) and `src/Makevars` (`-fopenmp`; plus the
  benchmark-only `-O2`).
- Before merging: regenerate `RcppExports` (signature unchanged, so optional),
  drop the `-O2`, gate OpenMP flags on `SHLIB_OPENMP_CXXFLAGS` for portability
  (macOS needs Homebrew `libomp`; here `/opt/homebrew/opt/libomp`), and add a
  correctness test asserting identical `rho` vs serial.

### Reproduction / benchmark scripts (ephemeral session scratchpad)
These were in the session scratchpad
(`/private/tmp/claude-502/.../scratchpad/`, **not persisted**). Recreate from the
canonical fit config above. The essential ones:
- `prof_pslps.R` / `prof3.R` — `Rprof` breakdown (see caveat below).
- `instr2.R` — `trace()`-based per-function timing (the reliable method here).
- `probe_solve.R` — capture and benchmark the sync normal matrix; demonstrates
  the `@factors` warm/cold trap.
- `frames.R` / `cd.R` / `quality.R` / `grid.R` — chart-dim → system-size,
  timing, and held-out-score comparisons.
- `bign.R` / `highp.R` — n- and p-scaling of OpenMP.
- `bench.R` / `baseline.R` — `-O0` vs `-O2` full-fit timing.

### Worktrees (created and removed)
`geosmooth-omp`, `geosmooth-omp2`, `geosmooth-b2` under the session scratchpad —
all `git worktree add --detach <path> af8056d`, built `-O2`, benchmarked, then
`git worktree remove --force`. None remain. The main geosmooth checkout was never
modified.

## Caveats and gotchas for the next agent

- **`Rprof` crashes on this workload** (silent, no output). Cause: `SIGPROF`
  sampling colliding with a multithreaded BLAS (the `Matrix` Cholesky) and/or
  OpenMP worker threads. Use `trace()`-based wall-time instrumentation instead
  (as in `instr2.R`), or force single-threaded BLAS — even that did not fully fix
  it here.
- **`dsCMatrix` caches its Cholesky factor in `@factors`.** Re-timing
  `Matrix::solve(A, b)` on the same object measures warm back-substitution
  (~100× too fast). Strip `A@factors` (or use a fresh copy) to time the real
  cold factorization.
- **`OMP_NUM_THREADS` was force-set to core count** by something in R startup on
  this machine; it did not vary the OpenMP thread count. Use `OMP_THREAD_LIMIT`
  (a hard ceiling) to control threads for benchmarking.
- **PS-LPS (`fit.ps.lps`) does not accept `coordinate.method`** (it is inherently
  local-PCA); passing it errors. Chart-kernel / local-likelihood do accept it.
- Shared-tree churn: the geosmooth main checkout moves under concurrent agents
  (HEAD went `af8056d` → `932c46e` during this work). Benchmark in a pinned
  worktree, not the live checkout.

## Recommendations (ordered by value)

1. **Build geosmooth `-O2` for the runtime pipeline** (finding 1). Free, ~4.6×,
   helps every method, no code change.
2. **Replace `chart.dim="auto"` with a bounded sparse/geometric
   `chart.dim.grid` without `auto`** for the high-dim assets (finding 2).
   Follow-up measurements favored grids such as `c(1, 2, 4, 8)` or
   `c(1, 2, 3, 5, 8, 12)` over both dense `1:15` grids and input-only `auto`.
3. **Add package-level PCA-coordinate reuse for chart-dimension grids.** For a
   fixed support size, the local PCA directions are nested: the top-8 local
   coordinates contain the top-4, top-2, and top-1 coordinates. The current path
   recomputes local PCA for each `(support.size, chart.dim)` pair. The next
   package optimization should compute local PCA once per support at the maximum
   requested grid dimension and slice columns for smaller dimensions, rebuilding
   only the cheap polynomial/design layer per candidate.
4. **Treat support size and chart dimension as coupled tuning parameters.** The
   current `support.grid = c(15, 25, 35)` is a useful runtime heuristic, but it is
   not a final selection strategy. A serious OD/PS-LPS run should include either
   a broader support search, a screened support policy, or a two-stage
   support/dimension refinement that records the interaction between selected
   support size and selected chart dimension.
5. Re-run the OD5c-expanded lane only after (1), (2), and preferably the
   chart-dimension-grid telemetry are in place. The combined effect should take
   HD100 from the pipeline's ~22s toward well under 1s, but it should be
   remeasured on the current geosmooth HEAD before being quoted.
6. **(Optional, high-p only)** finish and merge the OpenMP patch if you expect
   `p` in the hundreds-to-thousands (finding 3).
7. **(Optional, design decision)** add an `auto.chart.dim.max` guard or tighten
   the auto-dim thresholds in geosmooth so `auto` is robust to ambient noise
   (finding 2, deeper angle). Results-changing; needs human sign-off.

## 2026-07-08 addendum: refined chart-dimension guidance

After this handoff was generated, a follow-up benchmark compared `auto` with
bounded grids on the same HD100-style cell:

| config | time | CV-selected dim | held-out score (lower is better) |
|---|---:|---:|---:|
| `auto` | 2.78 s | 25 | 20.25 |
| grid `1:5` | 1.94 s | 1 | 7.05 |
| grid `1:10` | 4.23 s | 1 | 7.05 |
| grid `1:15` | 8.28 s | 1 | 7.05 |
| grid `c(1,2,4,8)` | 1.64 s | 1 | 7.05 |
| grid `c(1,2,4,8,auto)` | 3.21 s | 1 | 7.05 |

The updated recommendation is therefore not "use a dense small-integer grid."
It is: use a bounded sparse/geometric grid that caps the largest admissible
dimension while letting held-out score choose among plausible dimensions. Dense
grids can be slower than `auto`; sparse grids can be faster and more accurate.

The follow-up also identified an unexploited nested-PCA optimization. For a
fixed support size, local PCA does not need to be recomputed for every candidate
dimension. Compute the coordinates once at the largest grid dimension and slice
them for smaller dimensions. This optimization is more directly aligned with
the bounded-grid strategy than OpenMP, and should be considered before merging
the OpenMP prototype.

## Limitations / unverified

- Numbers are single-machine, single-config point measurements at `af8056d`, not
  a controlled multi-run OD5c-expanded sweep. Re-baseline before quoting ratios.
- The chart.dim finding was demonstrated on the synthetic high-dim assets
  (`2 informative + noise`), which match OD4-extended's construction. Behavior on
  genuinely high-intrinsic-dimension real data may differ; validate on the actual
  OD5c assets.
- The OpenMP patch was validated for numerical equivalence and thread-scaling but
  not run through `make test-ps-lps` / `make test-od` (built via `pkgbuild` in a
  worktree, not installed). Do that before merge.
- No package source was modified or committed. The only file added by this phase
  is this handoff plus the preserved `.patch`.
