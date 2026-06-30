# From `trend_filtering` to `geosmooth`

`~/current_projects/trend_filtering` is the exploratory research home for the
program that began as an attempt to generalize one-dimensional trend filtering
to data \(X \subset \mathbb{R}^n\) with arbitrary geometry, graph structure, or
local chart structure.

`~/current_projects/geosmooth` is the R package home for implementation outcomes
from that research line. It should stay lean: exported estimators, package tests,
package documentation, curated contracts/audits, and small provenance pointers.

## Practical rule

When work is exploratory, large, unstable, or argument-building, keep it in
`trend_filtering`.

When a method becomes package-facing, implement and test it in `geosmooth`, then
add a short provenance note linking back to the upstream research reports and
experiments that motivated the implementation.

## Current bridge examples

- LPL-TF and S-LPL-TF/SLPLiFT were explored extensively under
  `trend_filtering/development/lpl_tf` and `trend_filtering/development/slpl_tf`.
  Those experiments helped establish the need for practical local polynomial
  smoothers and synchronized chart models.
- P7/P7X experiments under
  `trend_filtering/development/slpl_tf/experiments/p7_prospective_synthetic_suite`
  compared SLPLiFT, LPS, PS-LPS, graph smoothers, and other baselines on
  controlled geometries and real-geometry synthetic tasks.
- LPS and PS-LPS were then promoted into `geosmooth` as package-facing methods,
  with their current execution history curated under `dev/methods/lps` and
  `dev/methods/ps_lps`.
- LCov is a package-facing extension of the same local-chart program: it uses
  the chart machinery developed for LPS/PS-LPS but targets local conditional
  covariance and association structure rather than only conditional means.

## Do not duplicate bulk assets

For long HTML reports, dense run outputs, parameter sweeps, and generated RDS
artifacts, link to the source location in `trend_filtering` or a frozen external
asset manifest. Do not copy those bundles into `geosmooth/dev`.
