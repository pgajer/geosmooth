# geosmooth GE8 Remove LPS Legacy Alias Handoff

Date: 2026-06-03

## Scope

GE8 removes the short-lived `kernel.local.polynomial.cv()` public API from
`geosmooth`.  The package is still new enough that carrying a compatibility
alias would create more migration debt than value.

The only public LPS entry point is now:

- `fit.lps()`

The only public LPS class is now:

- `"lps"`

## Changes Made

- Removed exported `kernel.local.polynomial.cv()`.
- Removed `predict.kernel.local.polynomial.cv()`.
- Removed `print.kernel.local.polynomial.cv()`.
- Removed the secondary `"kernel.local.polynomial.cv"` object class.
- Updated GE1/GE2 package tests to call `fit.lps()`.
- Updated GE3 parity tests so `geosmooth::fit.lps()` is compared against the
  split-era `gflow::kernel.local.polynomial.cv()` reference.
- Added a negative GE8 API test confirming the old public function and old S3
  methods are absent from the `geosmooth` namespace.
- Updated README and handoff notes to treat `fit.lps()` as the only current LPS
  public API.

## Intent

This is a deliberate early-breaking change.  It forces downstream scripts to
move to `fit.lps()` now, while the number of known callers is still small.

The internal native backend names still contain `kernel_local_polynomial_cv`.
Those names are not public R API and can be cleaned up later if worth the native
symbol churn.

## Validation

Validation commands to run from `/Users/pgajer/current_projects/geosmooth`:

```sh
make document
make test
make check-fast
```

Results should be recorded here after execution.

Observed results:

- `make document`: regenerated Rcpp attributes, NAMESPACE, and Rd files.
- `make test`: 360 passed assertions, 0 failures, 0 warnings, 0 skips.
- `make check-fast`: completed with 1 NOTE.

The `R CMD check` NOTE is the expected early-development package status: new
submission/development version and `gflow` listed as a non-mainstream suggested
package.

## Recommended Next Step

Run a downstream migration pass over the S-LPL-TF/P7 experiment scripts and
reports so they call `geosmooth::fit.lps()` and use `LPS` as the method label.
