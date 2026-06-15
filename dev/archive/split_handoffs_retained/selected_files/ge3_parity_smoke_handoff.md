# geosmooth GE3 Parity and Smoke Handoff

Date: 2026-06-03

## Scope

GE3 is a verification phase.  It does not move additional public method payload
from `gflow` into `geosmooth`; instead it adds source-level parity tests that
compare the current `geosmooth` split implementation against the split-era
`gflow` source tree.

The parity helper loads `gflow` from:

1. `GEOSMOOTH_GFLOW_SOURCE`, when set; otherwise
2. `/Users/pgajer/current_projects/gflow`.

If a suitable local `gflow` source tree is unavailable, the parity tests skip
rather than silently comparing against an older installed `gflow` package.

## Added Coverage

GE3 adds tests for:

- LPS R backend parity against `gflow::kernel.local.polynomial.cv`.
- LPS C++ coordinate backend parity against the `gflow` split-era backend.
- MALPS coordinate-mode parity.
- LPL-TF coordinate and local-PCA operator parity.
- SLPLiFT / S-LPL-TF coordinate and local-PCA operator parity.
- Graph-geodesic bridge smoke coverage through MALPS using an explicit path
  graph and graph distance matrix.
- Native symbol hygiene: registered native symbols use the `_geosmooth_` prefix
  and do not expose `_gflow_` symbols.

The graph-geodesic test remains a bridge smoke test because the graph
construction and graph-distance infrastructure has not yet moved into
`geosmooth`.

## Validation

Validation commands run from `/Users/pgajer/current_projects/geosmooth`:

```sh
make test
make check-fast
```

Observed results:

- `make test`: 57 passed assertions, 0 failures, 0 warnings, 0 skips.
- `make check-fast`: completed with 1 NOTE.

The `R CMD check` NOTE is the expected early-development package status:
new submission/development version, `gflow` listed as a non-mainstream
suggested package, and the vendored include tree reported in package size
information.

## Deferred Work

GE3 deliberately leaves the following work for later phases:

- GE4: move the SSRHE public/native backend into `geosmooth`.
- Graph infrastructure: resolve the ownership boundary for graph construction
  and graph-distance helpers bridged through `gflow`. GE5 later formalized
  `gflow` ownership for those utilities.
- API cleanup: rename `.cv` public functions only after the split is stable.
- Broader numerical parity: expand beyond small deterministic smoke fixtures
  after GE4 and graph infrastructure decisions are in place.

## Recommended Next Step

Proceed to GE4: move the SSRHE public/native backend and its focused tests.
