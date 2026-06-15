# PS-LPS C6 Cache-Aware Profile Audit

Date: 2026-06-05

Audited handoff:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/ps_lps_c6_cache_aware_profile_handoff_2026-06-05.md`

Repository:

- `/Users/pgajer/current_projects/geosmooth`

## Verdict

Accepted. C6 successfully profiles the cache-aware exported `fit.ps.lps()` path
against a reconstructed direct tuning loop, validates numerical parity on the
profiled cases, and provides enough evidence to move to the proposed C7
solve-path/search-policy decision phase.

I found no correctness blockers. The main caveat is interpretive: the C6 Rprof
target is useful for prioritizing the next investigation, but it should not be
treated as final proof that a specific low-level sparse operation is the next
best optimization. C7 should confirm the bottleneck with more targeted
instrumentation before implementing invasive solver changes.

## Scope Reviewed

Reviewed:

- `scripts/profile_ps_lps_cache_aware_c6.R`
- `split_handoffs/ps_lps_cache_backend_2026-06-05/c6_cache_aware_profile_2026-06-05/ps_lps_c6_cache_aware_profile_report.html`
- generated C6 tables and figures under
  `split_handoffs/ps_lps_cache_backend_2026-06-05/c6_cache_aware_profile_2026-06-05/`
- relevant C5 cache-aware fitter logic in `R/ps_lps.R`
- focused PS-LPS tests and full package test target

## Audit Checks

### Direct-versus-cache comparison design

The profiling script constructs a fair direct-loop baseline:

- It loads the same frozen first-batch assets and prior LPS-selected
  configuration used by the cache-aware fitter.
- It prepares the same PS-LPS frames and synchronization rows.
- For every fold and every `lambda.sync`, it calls `.ps.lps.solve()` directly.
- It performs a full-data diagnostic solve for each candidate and a final
  full-data solve at the selected candidate.

The cache-aware path calls exported `fit.ps.lps()` with the same `X`, `y`,
`foldid`, support size, degree, kernel, chart dimensions, lambda grid, ridge
value, and synchronization-neighbor size.

This is the right comparison for C6: it measures the C5 exported fitter path
against the pre-cache direct assembly pattern, not against an artificially
stripped-down internal solve.

### Numerical parity

I reran the C6 script from the current package state:

```sh
Rscript scripts/profile_ps_lps_cache_aware_c6.R
```

The regenerated summary preserved the parity claims:

- selected `lambda.sync` matched in all 6 profiled case/grid combinations;
- all cache-aware runs reported `cache.backend = "component"`;
- maximum CV RMSE delta: `4.888229e-09`;
- maximum final fitted-value delta: `5.281886e-13`.

The high-dimensional FB09 case has the largest CV delta, but the magnitude is
still small enough for a numerical parity profile and does not change selection.

### Timing results

The rerun produced the following end-to-end speedups:

| Case | Grid | Direct sec | Cache sec | Speedup |
|---|---:|---:|---:|---:|
| FB01 auto | mixed_4 | 2.878 | 0.663 | 4.34 |
| FB01 auto | positive_7 | 5.815 | 0.911 | 6.38 |
| FB09 auto | mixed_4 | 1.951 | 1.336 | 1.46 |
| FB09 auto | positive_7 | 3.598 | 1.673 | 2.15 |
| FB14 local.auto | mixed_4 | 13.398 | 9.336 | 1.44 |
| FB14 local.auto | positive_7 | 27.393 | 16.462 | 1.66 |

These timings differ slightly from the handoff, as expected for one-shot
elapsed measurements, but the qualitative conclusion is unchanged: C5 improves
the exported fitter path end to end, with larger gains on larger positive
lambda grids and smaller gains when local-auto/high-dimensional costs dominate.

### Rprof interpretation

The regenerated Rprof target is FB14 local.auto with the seven-positive-lambda
grid. Its top rows include:

- `.ps.lps.solve.component.cached`: about `80.5%` total sampled time;
- `.ps.lps.solve.normal.cached`: about `67.0%`;
- `.Call`: about `64.2%` self time;
- `Matrix::solve` / `Cholesky`: about `50.8%` total sampled time;
- sparse arithmetic/coercion around `+`, `forceSymmetric`, `.Arith.Csparse`,
  and `.M2C`.

This supports the handoff's conclusion that the bottleneck has moved away from
triplet assembly/crossproduct recomputation and toward repeated normal-matrix
combination plus sparse factorization/solve.

The caution is that base `Rprof` aggregates native `.Call` time and wrapper
frames coarsely. C7 should use targeted timers, smaller isolated benchmarks, or
native/Matrix-specific instrumentation before deciding whether to optimize
matrix combination, ridge insertion, factorization reuse, or candidate-search
policy.

## Verification Performed

Focused PS-LPS tests:

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-ps-lps.R")'
```

Result:

- `FAIL 0 | WARN 0 | SKIP 0 | PASS 50`

Full package test target:

```sh
make test
```

Result:

- `FAIL 0 | WARN 0 | SKIP 0 | PASS 990`

C6 profiling script:

```sh
Rscript scripts/profile_ps_lps_cache_aware_c6.R
```

Result:

- completed successfully;
- regenerated `ps_lps_c6_cache_aware_profile_report.html`;
- regenerated C6 timing, parity, final-solve timing, and Rprof tables.

## Nonblocking Recommendations

1. In C7, use repeated timing or medians for any optimization decision.

   C6 uses one elapsed run per case/grid. That is adequate for a development
   profile, especially since all speedups are above 1, but C7 should use
   repeated measurements for close comparisons.

2. Separate solver-path timing from candidate-search timing in C7.

   The current recommendation correctly asks whether to optimize sparse solves
   or reduce candidate count. C7 should explicitly estimate marginal cost per
   additional positive `lambda.sync`, because that directly determines whether
   smarter search policy can beat lower-level solve optimization.

3. Treat `.Call` and `Matrix::solve` Rprof rows as leads, not final diagnoses.

   The Rprof evidence is directionally useful, but more granular instrumentation
   is needed before changing sparse representation, factorization, or normal
   matrix construction internals.

## Gate Decision

C6 passes audit. Proceed to C7: solve-path and search-policy decision phase.
