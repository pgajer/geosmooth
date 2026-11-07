## Update draft

This draft concerns geosmooth 0.2.0, updating CRAN 0.1.0. It is not ready for
submission. The update consolidates refitting and smoother-matrix extraction,
uses dgraphs for geometry and sampling, and adds native trend-filtering methods.
NEWS and function help describe changed names, behavior and migration.

## Validation

The geosmooth 0.2.0 source archive was built and checked on 2026-11-07 using
R-devel (2026-06-24 r90190) on macOS arm64: 0 errors, 0 warnings, 0 notes.
The test suite recorded 16,485 passing expectations, no failures or warnings,
and one expected skip: the source-tree runner contract is unavailable inside
the built archive. Examples, vignette rebuilds, and PDF/HTML manual checks
passed. This check used development dependencies.

The checked graph-heat repair and regression tests are in commit
`0569572b7c81f8393c236eddd30bfd631f764f10`. The
[validation record](dev/methods/metric_graph_lowpass/heat_agreement_2026-11-07.md)
and accompanying JSON record preserve numerical comparisons, source hashes and
platform results. Subsequent validation-report and CRAN-draft changes were
excluded from the package archive. The later dependency-bound and NEWS updates
described below have not undergone a new full package check.

The [platform matrix for that revision](https://github.com/pgajer/geosmooth/actions/runs/42376015873)
completed successfully on Windows release, Intel macOS release, and Ubuntu
release, oldrel-1 and devel. Each reported Status: OK, with no test failures
or warnings. Intel macOS and all Ubuntu jobs recorded 16,485 passing
expectations and the expected source-tree-only skip. Windows recorded 16,484
passing expectations and two expected skips: the same source-tree-only check
and the existing Windows exclusion for a graph-parallelism test.

## Submission prerequisites

DESCRIPTION now requires dgraphs >= 0.4.0 in Imports and LinkingTo, grip >= 0.3.0
in Suggests, and R >= 4.1.0 to match dgraphs' minimum. Earlier dgraphs builds
labeled 0.3.0.9000 can lack the required C++ header; that development-version
bound was insufficient. Both layout adapters require grip's dot-delimited
argument interface and reject the older grip 0.2.0 signatures.

On 2026-11-07 the maintainer confirmed that dgraphs 0.4.0 has been submitted
to CRAN and is awaiting manual review. The required grip 0.3.0 release is also
still pending. Neither submission nor local installation establishes CRAN
availability. The package-check and website workflows now use CRAN dependencies
without GitHub overrides. Their next builds and the final CRAN-only validation
remain pending until both required dependency releases are published.

After publication, run `Rscript scripts/check_cran_dependencies.R`, build a
fresh geosmooth 0.2.0 source archive, and repeat the full archive and platform
checks using only released dependencies. Confirm the published versions meet
the declared bounds, then replace this draft with results for that exact archive.

The earlier Windows/Intel macOS graph-heat numerical-agreement failure is
resolved by evaluating the observed Schur complement through its residual
factor, with unchanged acceptance tolerances. The successful platform matrix
above still uses pinned development dependencies; a final CRAN-only archive
check remains necessary after compatible dependency releases are available.

The 0.2.0 NEWS entries are consolidated under one version heading and the API
count is updated to 71 explicit exports. These metadata and documentation
changes do not alter numerical implementations or replace final archive checks.
The metadata pass verified DESCRIPTION bounds, workflow YAML and dependency
gates, and API-guide coverage (71 exports and 106 S3 registrations). The NEWS
page rendered successfully; Pandoc reported deprecation notices for `--mathml`.

## Previous review fixes retained

Method references, return-value documentation, executable examples, and ANN,
Eigen and Spectra attribution remain present. The earlier compiler-warning
suppression remains removed. Source-only tests use the shared source locator
and distinguish checkout checks from source-tarball checks.
