# geosmooth GE5 Graph Dependency Boundary Handoff

Date: 2026-06-03

## Scope

GE5 formalizes the package boundary between `geosmooth` and `gflow` after the
initial smoother migration.

The decision for GE5 is explicit:

- `geosmooth` owns smoother APIs and package-local coordinate/fixed-k
  computation paths.
- `gflow` remains the owner of graph construction, rKNN graph construction, and
  graph-geodesic helper utilities.
- `geosmooth` graph-dependent paths deliberately bridge to `gflow` at runtime
  instead of copying graph infrastructure into this package.

This means GE5 is not a graph-construction migration phase. It is a boundary
and contract phase.

## Boundary Contract

Package-local `geosmooth` paths include:

- LPS / `kernel.local.polynomial.cv()` in coordinate and local-PCA modes.
- MALPS coordinate-support paths.
- LPL-TF and SLPLiFT coordinate-support paths.
- SSRHE fixed-k neighborhoods.
- SSRHE supplied-neighborhood operators.

Graph-dependent paths include:

- MALPS graph-geodesic support construction.
- LPL-TF and SLPLiFT graph-geodesic support construction.
- SSRHE adaptive-radius neighborhoods, which currently use
  `gflow::create.rknn.graph()`.

Those graph-dependent paths require a compatible split-era `gflow`
installation. If `gflow` is absent, the error message now says that graph
construction and graph-geodesic utilities remain owned by `gflow`, and suggests
using coordinate/fixed-k `geosmooth` paths when graph support is not intended.

## Changes Made

- Replaced the stale "temporarily requires gflow" bridge message with an
  explicit graph-dependency boundary message.
- Added helper-existence checks for bridged `gflow` functions so stale or
  incompatible `gflow` installations fail clearly.
- Labeled bridge call sites by feature, including graph-geodesic validation,
  graph-geodesic support extraction, shortest-path support, and
  adaptive-radius SSRHE support construction.
- Updated roxygen source documentation for MALPS, LPL-TF, and SSRHE to say that
  graph construction and graph-geodesic utilities remain owned by `gflow`.
- Updated the README split status and graph dependency boundary section.
- Added GE5 tests covering package-local coordinate/fixed-k paths, explicit
  bridge error reporting, and deliberate adaptive-radius bridging.

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
- `make test`: 334 passed assertions, 0 failures, 0 warnings, 0 skips.
- `make check-fast`: completed with 1 NOTE.

The `R CMD check` NOTE is the expected early-development package status: new
submission/development version and `gflow` listed as a non-mainstream suggested
package.

## Deferred Work

- Decide later whether graph construction remains permanently in `gflow` or is
  split into another graph-focused package. GE5 does not move it.
- Keep API naming cleanup separate from the dependency-boundary work.
- If downstream users need graph paths without `gflow`, that should be designed
  as a separate package architecture decision, not as an implicit smoother
  migration side effect.

## Recommended Next Step

After GE5 passes package checks, the next useful split phase is package-facing
API and dependency cleanup: review exported names, examples, and vignettes now
that the first smoother payload is package-local and the graph boundary is
explicit.
