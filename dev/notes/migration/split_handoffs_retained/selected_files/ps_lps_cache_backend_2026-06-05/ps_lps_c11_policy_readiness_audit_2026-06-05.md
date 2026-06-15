# PS-LPS C11 Policy-Readiness Audit

Audit time: 2026-06-05 22:00:02 EDT

Audited handoff:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/ps_lps_c11_policy_readiness_handoff_2026-06-05.md`

Audited code and generated assets:

- `/Users/pgajer/current_projects/geosmooth/R/ps_lps.R`
- `/Users/pgajer/current_projects/geosmooth/man/fit.ps.lps.Rd`
- `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ps-lps.R`
- `/Users/pgajer/current_projects/geosmooth/scripts/profile_ps_lps_c11_policy_readiness.R`
- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/c11_policy_readiness_2026-06-05/`

## Verdict

C11 is accepted as evidence for using `guarded_default` as the experiment-facing
PS-LPS `lambda.sync` search policy in the next prospective campaign, while
keeping exact grid search as the package API default and audit reference.

There is one required correction before C12 freezes or copies the explicit
policy controls: the explicit control list in the C11 handoff is not equivalent
to the current guarded-search defaults.

## Finding

### Required C12 handoff correction: explicit controls do not match defaults

The handoff recommends either:

```r
lambda.sync.search.control = list()
```

or an "equivalent explicit C10 default controls" list with:

```r
coarse.size = 7L
refine.radius = 1L
max.candidates = 30L
```

This is not equivalent to the current package defaults. The active defaults in
`.ps.lps.search.control(list())` are:

```r
coarse.size = 5L
refine.radius = 2L
rel.tol = 0.002
boundary.guard.rel.tol = 0.01
boundary.expand = TRUE
boundary.factor = 3
max.boundary.expansions = 2L
max.candidates = 25L
```

Impact: if C12 or prospective scripts copy the explicit `7/1/30` list, they
will not reproduce the C11 `guarded_default` policy that was audited here.

Resolution required before C12 policy freeze: use
`lambda.sync.search.control = list()` or replace the explicit snippet with the
actual defaults above. If the intended C12 policy is instead `7/1/30`, rerun C11
under those controls and freeze that separately.

## Evidence Checked

The C11 profiling script was rerun from scratch:

```sh
Rscript scripts/profile_ps_lps_c11_policy_readiness.R
```

It completed successfully and regenerated:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/c11_policy_readiness_2026-06-05/ps_lps_c11_policy_readiness_report.html`
- policy metrics, summary, failures, mismatch, and pointwise-delta CSV tables.

Regenerated table checks:

- policy metrics rows: 112
- cases: 28, from 14 datasets by 2 chart-dimension rules
- variants: 28 rows each for `exact_reference`, `guarded_default`,
  `guarded_strict_edge`, and `guarded_one_expansion`
- failures rows: 0
- selected-lambda mismatches: 8
- all selected-lambda mismatches had negative Truth RMSE deltas relative to
  exact reference
- pointwise delta rows: 43,800
- pointwise delta summary rows: 84

Regenerated policy summary:

| Variant | Mean Truth RMSE delta | Median Truth RMSE delta | Max absolute Truth RMSE delta | Mean candidates | Median candidates | Mean elapsed seconds | Median elapsed seconds |
|---|---:|---:|---:|---:|---:|---:|---:|
| `guarded_default` | -0.001638 | 0 | 0.045871 | 9.68 | 10.0 | 3.72 | 1.16 |
| `guarded_strict_edge` | -0.002728 | 0 | 0.045871 | 9.43 | 10.0 | 3.67 | 1.13 |
| `guarded_one_expansion` | -0.006687 | 0 | 0.063499 | 9.43 | 9.5 | 3.53 | 1.17 |

The elapsed-time columns differ slightly from the handoff because the script was
rerun during audit. The substantive selection, failure, mismatch, and Truth RMSE
claims are reproduced.

## Code Checks

The guarded-search implementation now enforces `max.candidates` as a global cap
on distinct evaluated candidates across coarse, refine, and boundary-expansion
stages. This addresses the previous C10 concern that boundary expansion could
exceed the candidate cap.

The focused regression test
`PS-LPS guarded lambda search enforces max.candidates globally` covers this
behavior directly through `.ps.lps.search.lambda.sync()`.

The package default remains exact grid search unless callers explicitly request:

```r
lambda.sync.search = "guarded"
```

## Verification Run

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-ps-lps.R")'
```

Result: 67 passed, 0 failed, 0 warnings, 0 skips.

```sh
make document
```

Result: passed.

```sh
make test
```

Result: 1007 passed, 0 failed, 0 warnings, 0 skips.

```sh
git diff --check -- R/ps_lps.R tests/testthat/test-ps-lps.R scripts/profile_ps_lps_c11_policy_readiness.R man/fit.ps.lps.Rd
```

Result: passed.

No full `R CMD check` was run for this audit.

## Recommendation

Proceed to C12 after correcting the explicit policy-control snippet. C12 should
freeze `guarded_default` for prospective experiments using either the empty
control list or the exact current defaults listed above, persist search
telemetry, and retain exact-grid subset audits in future comparison reports.
