# geosmooth GE7 LPS Public API Handoff

Date: 2026-06-03

## Scope

GE7 introduces the public naming layer for the local polynomial smoother (LPS).
It does not rename MALPS, LPL-TF, or SLPLiFT public functions.

The canonical LPS entry point is now:

- `fit.lps()`

The compatibility entry point remains:

- `kernel.local.polynomial.cv()`

## Public API Contract

New code should call `fit.lps()` and refer to the method as local polynomial
smoothing (LPS).

For split-era compatibility, `kernel.local.polynomial.cv()` remains exported as
a thin alias to `fit.lps()`. Returned objects inherit from both classes:

```r
c("lps", "kernel.local.polynomial.cv", "list")
```

This lets new code dispatch through `predict.lps()` and `print.lps()`, while
older code that checks `inherits(object, "kernel.local.polynomial.cv")` still
works.

The object metadata now records:

- `method.id = "lps"`;
- `method.family = "local_polynomial_smoother"`;
- `method.label = "LPS"`.

## Changes Made

- Renamed the implementation function from `kernel.local.polynomial.cv()` to
  `fit.lps()`.
- Kept `kernel.local.polynomial.cv()` as an exported compatibility alias.
- Added `predict.lps()` and `print.lps()` as canonical S3 methods.
- Kept `predict.kernel.local.polynomial.cv()` and
  `print.kernel.local.polynomial.cv()` as compatibility S3 methods that
  delegate to the LPS methods.
- Updated README split status and public payload wording.
- Added GE7 tests for the canonical entry point, class order, method metadata,
  prediction, printing, and alias equivalence.

## Explicit Non-Goals

- No soft-deprecation warning yet; old scripts should remain quiet while the
  package split stabilizes.
- No `fit.slplift()` alias yet; SLPLiFT naming should wait until the model name
  is stable across reports and project paths.
- No public rename of `fit.lpl.tf()`, `fit.slpl.tf()`, or `fit.malps()`.

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
- `make test`: 363 passed assertions, 0 failures, 0 warnings, 0 skips.
- `make check-fast`: completed with 1 NOTE.

The `R CMD check` NOTE is the expected early-development package status: new
submission/development version and `gflow` listed as a non-mainstream suggested
package.

## Recommended Next Step

After GE7 passes package checks, the next useful API phase is either:

- GE8 examples/docs polish for the new public surface; or
- a deliberate soft-deprecation plan for `kernel.local.polynomial.cv()` once
  downstream scripts have moved to `fit.lps()`.
