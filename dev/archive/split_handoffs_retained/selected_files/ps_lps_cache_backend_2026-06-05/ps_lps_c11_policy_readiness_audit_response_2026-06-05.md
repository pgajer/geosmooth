# PS-LPS C11 Policy-Readiness Audit Response

Response time: 2026-06-05 22:03:00 EDT

Responding to:

`~/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/ps_lps_c11_policy_readiness_audit_2026-06-05.md`

## Summary

The audit verdict is accepted.  The auditor accepted C11 as evidence for using
`guarded_default` as the experiment-facing PS-LPS `lambda.sync` search policy
in the next prospective campaign, while keeping exact grid search as the
package API default and audit reference.

The auditor found one required correction: the explicit control list in the C11
handoff did not match the active defaults used by
`.ps.lps.search.control(list())`.

## Correction Made

Updated:

`~/current_projects/geosmooth/split_handoffs/ps_lps_cache_backend_2026-06-05/ps_lps_c11_policy_readiness_handoff_2026-06-05.md`

The handoff now recommends either:

```r
lambda.sync.search = "guarded"
lambda.sync.search.control = list()
```

or the equivalent explicit current defaults:

```r
lambda.sync.search.control = list(
  coarse.size = 5L,
  refine.radius = 2L,
  rel.tol = 0.002,
  boundary.guard.rel.tol = 0.01,
  boundary.expand = TRUE,
  boundary.factor = 3,
  max.boundary.expansions = 2L,
  max.candidates = 25L
)
```

This resolves the mismatch with the package implementation in `R/ps_lps.R`.

## Interpretation

The audit strengthens the C11 conclusion rather than weakening it.  The auditor
reran the C11 profiling script from scratch and reproduced the substantive
results:

- 28 cases from 14 datasets by two chart-dimension rules;
- no failures;
- 112 policy-metric rows;
- 8 selected-lambda mismatches;
- all selected-lambda mismatches had lower Truth RMSE for the guarded variant
  than for the exact expanded-grid reference;
- focused PS-LPS tests, documentation, full package tests, and whitespace
  checks passed during the audit.

The required correction was a reproducibility/specification issue in the
handoff, not a problem with the C11 run or package implementation.

## Status

C11 is ready to support C12 after this correction.

Recommended C12 framing remains:

- freeze `guarded_default` for prospective PS-LPS experiments;
- keep exact grid search as the package API default;
- use exact-grid subset audits in future reports;
- persist guarded-search telemetry in every prospective run.
