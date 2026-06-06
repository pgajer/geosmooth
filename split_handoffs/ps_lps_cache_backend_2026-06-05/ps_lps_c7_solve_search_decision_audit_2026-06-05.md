# PS-LPS C7 Solve/Search Decision Audit

Date: 2026-06-05

Audited handoff:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/ps_lps_c7_solve_search_decision_handoff_2026-06-05.md`

Repository:

- `/Users/pgajer/current_projects/geosmooth`

## Verdict

Accepted. C7 provides a sound diagnostic basis for routing the next phase toward
a lambda-search policy prototype rather than immediately doing invasive sparse
solver work.

I found no correctness blockers. The generated timing evidence supports the
central claim: on the FB14 local.auto stress case, the remaining exported
`fit.ps.lps()` cost is meaningfully and approximately linear in the number of
positive `lambda.sync` candidates. The low-level solve layer still matters, but
skipping whole candidate bundles has a larger immediate payoff target.

## Scope Reviewed

Reviewed:

- `scripts/profile_ps_lps_c7_decision.R`
- generated report:
  `split_handoffs/ps_lps_cache_backend_2026-06-05/c7_solve_search_decision_2026-06-05/ps_lps_c7_solve_search_decision_report.html`
- generated C7 tables and figures under:
  `split_handoffs/ps_lps_cache_backend_2026-06-05/c7_solve_search_decision_2026-06-05/`
- relevant C5/C6 PS-LPS cache-aware fitter behavior
- focused PS-LPS tests and full package test target

## Audit Checks

### Diagnostic design

The C7 script uses the intended stress case:

- `FB14`, `SYN-RANK-BLOCKS-N600-P100`;
- `chart_dim_rule = local.auto`;
- `support.size = 35`;
- `degree = 2`;
- `kernel = gaussian`;
- `lambda.ridge = 1e-8`;
- `sync.neighbor.size = 3`.

The script separates:

- one-time frame/sync/cache setup costs;
- isolated cached full-data solve cost as the positive lambda grid grows;
- per-layer cached solve timing;
- full end-to-end exported `fit.ps.lps()` cost as the positive lambda grid
  grows.

This is the right diagnostic decomposition for the C7 decision. It connects the
C6 Rprof lead to concrete marginal costs and distinguishes low-level solve cost
from whole-candidate cost in the exported fitter.

### Reproducibility check

I reran:

```sh
Rscript scripts/profile_ps_lps_c7_decision.R
```

The script completed successfully and regenerated the C7 HTML report and CSV
tables.

The rerun timings differ slightly from the handoff, as expected, but the
decision is stable:

- isolated cached full-data solve median slope: about `0.419` seconds per
  positive lambda;
- end-to-end exported `fit.ps.lps()` median slope: about `1.853` seconds per
  positive lambda;
- all end-to-end runs used `cache.backend = "component"`;
- layer timing remained stable across lambda values.

### Refreshed timing summary

Setup timings from the rerun:

| Phase | Elapsed sec |
|---|---:|
| prepare frames | 1.405 |
| prepare sync rows | 0.034 |
| prepare full component cache | 0.307 |
| prepare fold component caches | 1.213 |

Isolated cached full-data solve medians:

| Grid size | Median sec | IQR sec | Median sec per lambda |
|---:|---:|---:|---:|
| 1 | 0.423 | 0.018 | 0.423 |
| 3 | 1.215 | 0.005 | 0.405 |
| 7 | 2.908 | 0.064 | 0.415 |
| 11 | 4.599 | 0.066 | 0.418 |

End-to-end exported `fit.ps.lps()` medians:

| Grid size | Median sec | IQR sec | Median sec per lambda |
|---:|---:|---:|---:|
| 1 | 5.218 | 0.158 | 5.218 |
| 3 | 8.829 | 0.104 | 2.943 |
| 7 | 16.319 | 0.322 | 2.331 |

Layer medians from the rerun:

- normal-matrix combination: about `0.048` to `0.051` sec;
- cached solve wall time: about `0.239` to `0.243` sec;
- reported ridge-normal formation: about `0.040` to `0.044` sec;
- reported `Matrix::solve`: about `0.190` to `0.191` sec;
- reported diagnostics: about `0.007` to `0.008` sec.

These values preserve the handoff's interpretation. Low-level sparse solves are
visible, but the end-to-end marginal candidate cost is much larger than the
isolated full-data solve cost because each candidate carries fold solves,
diagnostics, and final-selection implications.

## Interpretation

C7's recommendation to prototype search policy next is justified.

The strongest evidence is not the exact fitted slope, but the gap between:

- roughly `0.4` sec per positive lambda for isolated cached full-data solves;
  and
- roughly `1.8` sec per positive lambda for the exported fitter path on the
  stress case.

This means reducing candidate count can skip whole bundles of fold and
diagnostic work. Even a useful sparse-solve speedup would have to be large and
low-risk to beat a conservative search policy that avoids several unnecessary
positive candidates.

## Caveats

1. The end-to-end grid-size timings use nested prefixes of the positive lambda
   grid, not multiple candidate layouts with fixed optima.

   This is fine for marginal timing, but it is not evidence that a search policy
   will recover the best candidate. C8 must evaluate search correctness against
   full-grid selection and CV RMSE regret.

2. Setup timing is single-shot.

   It is adequate for context, but C8 optimization decisions should be based on
   repeated timings or medians, as C7 does for solve and end-to-end timings.

3. C7 is a decision profile, not a solver optimization proof.

   The layer timings indicate where sparse-solve cost lives, but they do not yet
   identify a low-risk sparse representation or factorization change. That is
   exactly why search-policy prototyping is the better next move.

## Required C8 Guardrails

C8 should include:

- a full-grid reference path using the C5 component cache;
- a candidate-count and elapsed-time comparison against the full-grid reference;
- CV RMSE regret relative to full grid as the primary correctness guard;
- selected-lambda agreement where the CV curve has a clear unique minimum;
- explicit handling of `lambda.sync = 0` when requested;
- boundary guards so a bracketed/coarse search does not silently miss edge
  optima;
- examples where the full-grid optimum is left boundary, right boundary, and
  interior;
- a practical-tie rule for near-flat CV curves.

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

C7 profiling script:

```sh
Rscript scripts/profile_ps_lps_c7_decision.R
```

Result:

- completed successfully;
- regenerated `ps_lps_c7_solve_search_decision_report.html`;
- regenerated setup, micro, layer, and end-to-end timing tables.

## Gate Decision

C7 passes audit. Proceed to C8: PS-LPS lambda-search policy prototype, with the
guardrails above.
