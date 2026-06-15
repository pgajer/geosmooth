# geosmooth GE1 R-Level Smoothers Handoff

Generated: 2026-06-03

## Scope

GE1 moves the R-level smoother APIs from `gflow` into `geosmooth` while keeping
public names unchanged.  This phase is a package-boundary migration, not an API
rename or algorithm redesign.

## Moved R APIs

- `kernel.local.polynomial.cv`
- `predict.kernel.local.polynomial.cv`
- `fit.malps`
- `predict.malps`
- `refit.malps`
- `malps.smoother.matrix`
- `malps.gcv`
- `bootstrap.malps`
- `lpl.tf.operator`
- `fit.lpl.tf`
- `refit.lpl.tf`
- `predict.lpl_tf`
- `slpl.tf.operator`
- `fit.slpl.tf`
- `refit.slpl.tf`
- `predict.slpl_tf`

## Private Helpers Added

- `R/local_pca_chart_dim.R`
- `R/split_bridge_helpers.R`
- `R/ssrhe_l1_helpers.R`

`R/ssrhe_l1_helpers.R` is a private helper subset used by LPL-TF and SLPLiFT
fitting.  It does not expose the public SSRHE operator API; that remains a GE4
task.

## GE1 Deferred Paths

The following paths intentionally fail with clear GE1/GE2 messages:

- `kernel.local.polynomial.cv(..., backend = "cpp")`
- LPS local-PCA prediction charts
- LPL-TF local-PCA charts

Graph-geodesic modes are bridged to `gflow` through private helper wrappers.
Coordinate-support paths are package-local. GE5 later formalized this as the
intended graph dependency boundary rather than as a graph-migration placeholder.

## Documentation/Namespace

Roxygen now generates:

- public API exports;
- S3 registrations for `predict` and `print` methods;
- `useDynLib(geosmooth, .registration = TRUE)`;
- `utils::head` and `utils::modifyList` imports.

## Validation

Passed:

- `make document`
- `make test`
- `make check-fast`

`make check-fast` reports one expected NOTE for a new development-version
package with `gflow` in `Suggests`.  No warnings or errors remain.

## Next Phase

GE2 should move the native LPS C++ backend and local PCA chart backend, replacing
the GE1 deferred-native guards with package-local implementations.
