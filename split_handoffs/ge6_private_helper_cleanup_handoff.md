# geosmooth GE6 Private Helper Cleanup Handoff

Date: 2026-06-03

## Scope

GE6 performs private helper cleanup after the GE5 graph dependency boundary.
It does not introduce public API renaming and does not change smoother
semantics.

The narrow cleanup is to move the local-polynomial design helper away from a
MALPS-specific private name:

- new private helper: `.local.polynomial.design.matrix()`;
- new private column-name helper: `.local.polynomial.design.column.names()`;
- retained compatibility shims:
  `.malps.design.matrix()` and `.malps.design.column.names()`.

## Rationale

The helper is shared by MALPS and LPS code paths, and may remain useful for
future local-polynomial smoother internals. The previous `.malps.*` name was
therefore too narrow for the split package, even though the helper is still
private.

Keeping the `.malps.*` shims avoids breaking any remaining private callers or
downstream development scripts during the split.

## Changes Made

- Added `.local.polynomial.design.matrix()` and
  `.local.polynomial.design.column.names()`.
- Updated MALPS and LPS internal callers to use the generic helper names.
- Kept `.malps.design.matrix()` and `.malps.design.column.names()` as private
  compatibility shims.
- Added GE6 tests asserting equivalence between the new helpers and the legacy
  shims across local polynomial degrees 0, 1, and 2.

## Explicit Non-Goals

- No public function renaming in GE6.
- No class renaming in GE6.
- No change from `kernel.local.polynomial.cv()` to `fit.lps()` yet.
- No LPL-TF/SLPLiFT operator helper rewrite; those paths use a separate
  monomial-power helper and should be evaluated separately if we want a broader
  polynomial-design abstraction.

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
- `make test`: 349 passed assertions, 0 failures, 0 warnings, 0 skips.
- `make check-fast`: completed with 1 NOTE.

The `R CMD check` NOTE is the expected early-development package status: new
submission/development version and `gflow` listed as a non-mainstream suggested
package.

## Recommended Next Step

GE7 should introduce the public naming layer if we are ready:

- `fit.lps()` as the canonical LPS entry point;
- object class `"lps"`;
- `kernel.local.polynomial.cv()` retained as a compatibility alias;
- report label `LPS`;
- no forced rename of SLPLiFT until the model name is settled.
