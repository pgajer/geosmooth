# PS-LPS C10 Boundary-Expansion Search Policy Audit

Date: 2026-06-05

Audited handoff:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/ps_lps_c10_boundary_expansion_policy_handoff_2026-06-05.md`

Repository:

- `/Users/pgajer/current_projects/geosmooth`

## Verdict

Accepted with minor nonblocking issues. C10 correctly keeps exact grid search as
the default, exposes the guarded search policy only as an opt-in experimental
path, adds package-side guarded-search helpers and telemetry, and validates the
boundary-expansion policy against an expanded reference grid.

I found no correctness blocker. The C10 validation rerun preserved the handoff's
core result: selected-lambda agreement with expanded reference in all 12 cases,
zero CV RMSE regret, and meaningful candidate-count/time reduction.

## Findings

### Minor: `max.candidates` does not cap coarse/refine candidates

`max.candidates` is validated in `.ps.lps.search.control()`, but
`.ps.lps.search.lambda.sync()` only checks it in the boundary-expansion loop.
The initial coarse and refine phases can exceed a user-supplied
`max.candidates`.

Auditor spot check:

```r
out <- .ps.lps.search.lambda.sync(
  evaluator,
  c(1, 3, 10, 30, 100, 300),
  control = list(max.candidates = 2L, rel.tol = 0)
)
nrow(out$evaluated)
# 6
```

This does not affect the C10 default settings or validation results, because
the default `max.candidates = 25L` is larger than the observed search paths.
However, before documenting the guarded policy for users, either enforce
`max.candidates` as a global cap or rename/document it as a boundary-expansion
cap.

### Minor: guarded-search control fields need user-facing documentation

`fit.ps.lps()` now exposes `lambda.sync.search.control`, but the generated Rd
only says it is an optional list. C11 should document the control fields, their
defaults, and the fact that boundary expansion can evaluate candidates outside
the supplied `lambda.sync.grid`.

This is not a blocker because the policy is explicitly experimental and
opt-in, and C11 is already recommended as a search-integration documentation
phase.

## Scope Reviewed

Reviewed:

- `R/ps_lps.R`
- `tests/testthat/test-ps-lps.R`
- `man/fit.ps.lps.Rd`
- `scripts/profile_ps_lps_c10_boundary_expansion_policy.R`
- generated report:
  `split_handoffs/ps_lps_cache_backend_2026-06-05/c10_boundary_expansion_policy_2026-06-05/ps_lps_c10_boundary_expansion_policy_report.html`
- generated C10 tables and figures under:
  `split_handoffs/ps_lps_cache_backend_2026-06-05/c10_boundary_expansion_policy_2026-06-05/`

## Implementation Checks

### Public API default

`fit.ps.lps()` now accepts:

```r
lambda.sync.search = c("grid", "guarded")
lambda.sync.search.control = list()
```

The default remains exact grid search because `match.arg()` selects `"grid"`.
This satisfies the key C10 safety requirement: existing calls keep exact
candidate-grid semantics unless users explicitly opt into `"guarded"`.

### Guarded search behavior

The guarded helper:

- evaluates zero when it is present in the input grid;
- evaluates a coarse positive grid;
- refines around the raw coarse best;
- selects using the practical tie rule;
- applies boundary expansion when the raw best or tie-rule selection is at an
  evaluated edge;
- adds the C10 near-boundary guard, where a near-best evaluated edge can trigger
  expansion even when the practical tie-rule selection is interior;
- records telemetry with stage, lambda, boundary, expansion number, and
  selected-after-stage fields.

This is a material improvement over the earlier C8 prototype because boundary
expansion is no longer driven solely by the practical tie-rule selection.

### Zero-only and zero-diagnostic behavior

Auditor spot checks confirmed:

- zero-only guarded search selects `0`;
- zero-only guarded search keeps `cache.backend = "independent"`;
- telemetry reports `stage = "zero_only"`;
- unknown control fields fail clearly.

The added tests also check that zero is retained as a diagnostic candidate when
mixed with positive candidates.

## Validation Results

I reran:

```sh
Rscript scripts/profile_ps_lps_c10_boundary_expansion_policy.R
```

The script completed successfully and regenerated the C10 report/tables.

Fresh regenerated summary:

- number of validation cases: `12`;
- selected-lambda agreement with expanded reference: `12 / 12`;
- maximum CV RMSE regret: `0`;
- maximum relative CV RMSE regret: `0`;
- median candidate reduction versus expanded reference: `47.37%`;
- median elapsed speedup: `1.82x`;
- boundary expansion cases: `6 / 12`;
- boundary expansion counts: 6 cases with 0 expansions, 3 with 1 expansion, 3
  with 2 expansions.

The key diagnostic case, `FB09` with `chart_dim_rule = "auto"`, remains covered:
the expanded reference and guarded search both selected `lambda.sync = 2700`.

## Verification Performed

C10 validation script:

```sh
Rscript scripts/profile_ps_lps_c10_boundary_expansion_policy.R
```

Result:

- completed successfully;
- regenerated `ps_lps_c10_boundary_expansion_policy_report.html`;
- regenerated search summary, reference-grid curve, and search-stage tables.

Documentation:

```sh
make document
```

Result:

- passed;
- regenerated package documentation/attributes.

Focused PS-LPS tests:

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE); testthat::test_file("tests/testthat/test-ps-lps.R")'
```

Result:

- `FAIL 0 | WARN 0 | SKIP 0 | PASS 65`

Full package test target:

```sh
make test
```

Result:

- `FAIL 0 | WARN 0 | SKIP 0 | PASS 1005`

Whitespace check:

```sh
git diff --check -- R/ps_lps.R tests/testthat/test-ps-lps.R scripts/profile_ps_lps_c10_boundary_expansion_policy.R man/fit.ps.lps.Rd
```

Result:

- passed.

## C11 Recommendations

C11 should:

- document all guarded-search control fields and defaults;
- clarify that boundary expansion can evaluate candidates outside
  `lambda.sync.grid`;
- decide whether `max.candidates` is a global cap or boundary-expansion cap;
- compare exact grid and guarded search on selected fitted values, not only
  selected lambdas;
- include Truth RMSE and pointwise delta diagnostics for prospective examples;
- keep package API defaults as exact grid search until broader prospective
  validation is complete.

## Gate Decision

C10 passes audit. Proceed to C11 search-integration audit/documentation and
prospective comparison, with the two minor control/documentation issues tracked.
