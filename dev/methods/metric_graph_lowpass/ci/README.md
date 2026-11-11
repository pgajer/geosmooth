# Graph heat numerical checks

The package test suite checks independent dense heat-penalty equations,
policy overrides, graph permutations, mixed response masks, extreme response
scales and the frozen weak-chain tolerance-boundary example. These checks live
in `tests/testthat/test-metric-graph-lowpass-*.R`; the frozen input is in
`tests/fixtures/metric-graph-heat-tolerance-boundary.rds`.

For a broader check, `check-weak-chain-tuning.R` generates 80 connected chains
with four to nine vertices, one weak edge and two observed endpoint responses.
It retains seed 6172026, the original edge-weight distribution and the twelve
smoothing times from 0.001 to 10000. Every numerically accepted path must report
`unresolved_flat_gcv`: with two observations, the criterion cannot identify a
smoothing time. Numerically rejected paths remain explicit rows; they are not
successful fits.

Run from the package root after `make check`, using the checked package and
its dependencies. Set the TSV destination to a directory outside the checkout:

```sh
R_LIBS="$(pwd)/build/geosmooth.Rcheck:$R_LIBS" Rscript \
  dev/methods/metric_graph_lowpass/ci/check-weak-chain-tuning.R /path/to/results.tsv
```

Use one numerical thread. The output retains graph sizes, edge weights,
acceptance or rejection, tuning status, and score errors. This is a numerical
stress check, not an assessment of predictive performance on a cohort.
