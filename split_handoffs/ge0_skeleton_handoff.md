# geosmooth GE0 Skeleton Handoff

Generated: 2026-06-03

## Scope

GE0 creates the physical `geosmooth` package skeleton and vendors the native
support assets agreed in the SA4 contract.  It does not move public smoother
functions yet.

## Added Package Structure

- `DESCRIPTION`
- `NAMESPACE`
- `R/package.R`
- `src/Makevars`
- `src/Makevars.win`
- `tests/testthat/test-ge0-skeleton.R`
- `inst/COPYRIGHTS`
- `inst/licenses/`
- `inst/include/`
- `split_handoffs/ge0_skeleton_handoff.md`

## Vendored Assets

- ANN source tree from `gflow/src/ANN`
- ANN license notice and LGPL-2.1 text from `gflow/inst/licenses`
- Eigen headers from `gflow/inst/include/Eigen`
- Eigen configuration header copied from
  `gflow/inst/include/gflow/eigen_config.hpp` to
  `geosmooth/inst/include/geosmooth/eigen_config.hpp`

## Deliberate Non-Moves

GE0 does not move:

- LPS / `kernel.local.polynomial.cv`
- MALPS
- LPL-TF
- SLPLiFT / S-LPL-TF
- SSRHE
- Qhull
- graph-geodesic or gradient-flow infrastructure

Those are GE1-GE4 tasks.

## Validation Expectations

GE0 should pass:

- `make test`
- `R CMD build .`

Full package checks may still report that the package has no user-facing
documentation or examples; that is acceptable until GE1 introduces real APIs.

## Next Phase

GE1 should move the R-level smoother cluster and minimal helper R files while
keeping public function names unchanged.
