## Update draft

This draft concerns geosmooth 0.2.0, updating CRAN 0.1.0. It is not ready for
submission. The update consolidates refitting and smoother-matrix extraction,
uses dgraphs for geometry and sampling, and adds native trend-filtering methods.
NEWS and function help describe changed names, behavior and migration.

## Validation

The geosmooth 0.2.0 source archive was built and checked on 2026-11-07 using
R-devel (2026-06-24 r90190) on macOS arm64: 0 errors, 0 warnings, 0 notes.
The test suite recorded 16,417 passing expectations, no failures or warnings,
and one expected skip: the source-tree runner contract is unavailable inside
the built archive. Examples, vignette rebuilds, and PDF/HTML manual checks
passed. This check used development dependencies.

The checked numerical sources and tests were published in commit
`f3c66e7218f8dfee07b8cb0d84595dec8e19caf9`. The
[QA record](https://github.com/pgajer/trend_filtering/blob/e07b761/development/logistic_tf_stagnation/status/qa.json)
and accompanying provenance record preserve the check results and source hashes.
All 175 recorded package-source hashes still match on 2026-11-07. Subsequent
website and repository-documentation changes are not a new full package check.

## Submission prerequisites

The declared dependency bounds still exceed the available CRAN releases:
dgraphs >= 0.3.0.9000 and grip >= 0.2.0.9001 are required, while the
[CRAN source index](https://cloud.r-project.org/src/contrib/PACKAGES.gz), checked
on 2026-11-07, supplies 0.2.0 for each. Both current layout adapters reject the
older grip 0.2.0 signatures; the required grip update is therefore also necessary.
After compatible releases are available, use their actual released version
bounds and repeat the final archive checks without development overrides.

The [platform check of f3c66e7](https://github.com/pgajer/geosmooth/actions/runs/42368766551)
failed a heat-smoother numerical-agreement test on Windows and Intel macOS;
the three Ubuntu configurations passed. The failure is the nine-vertex
weak-chain case in `test-metric-graph-lowpass-tuning-resolution.R`.
The affected code and test are unchanged in this documentation cleanup.
That failure requires resolution and clean platform checks before submission;
the local result does not establish cross-platform readiness.

## Previous review fixes retained

Method references, return-value documentation, executable examples, and ANN,
Eigen and Spectra attribution remain present. The earlier compiler-warning
suppression remains removed. Source-only tests use the shared source locator
and distinguish checkout checks from source-tarball checks.
