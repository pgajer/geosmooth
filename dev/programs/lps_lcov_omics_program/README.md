# LPS / LCov / Omics Program

This program connects local polynomial smoothing (LPS), pointwise-selective
LPS (PS-LPS), local covariance models, compositional synthetic-data models,
temporal 16S community-type analysis, co-abundance group (CAG) construction
and multi-omics association applications. Cross-project exploratory work is
maintained in the external `trend_filtering` research repository; the package
contains the implementation, tests, documentation and method specifications.

## Package methods

- [LPS](../../methods/lps/README.md)
- [PS-LPS](../../methods/ps_lps/README.md)
- [LCov](../../methods/lcov/README.md)

## Shared mathematical foundations

The companion foundation notes address three topics:

- **Effective degrees of freedom:** degrees-of-freedom accounting in local
  smoother diagnostics.
- **Local dimension regularization:** regularization of local dimension and its
  role in LPS-type methods.
- **Chart nerve substrate:** the connection between local charts, chart overlaps
  and the chart-nerve substrate.

These standalone scientific sources are maintained in the sibling
`geosmooth_manuscripts` workspace.
They are not package build inputs. The topic descriptions above remain here to
explain their relationship to the package methods.
