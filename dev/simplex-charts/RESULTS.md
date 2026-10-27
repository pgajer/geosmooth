# Local simplex charts — validation, 27 October 2026

`fit.local.likelihood()` now provides opt-in intrinsic simplex and Euclidean
Bernoulli charts, with weighted PCA or PLS1 and explicit chart/solver fallbacks.
Default legacy behavior remains unchanged. `unfold.simplex.chart()` is also
available independently for geometric diagnostics. The package vignette
`local-simplex-charts` explains the method, examples and limits.

## Evidence

- **810 held-out synthetic predictions** match the independent Python reference
  within 2e-7, with zero fallback: five scenarios, six queries each, three chart
  methods, three dimensions and three ridge penalties. Each uses 320 training
  points and 60 neighbors. The scenarios have constant, seam, high-variance,
  low-variance and nonlinear response signals. This is implementation parity,
  not a new statistical performance study.
- **1,288 broader regression expectations passed**, without failures, warnings
  or skips: simplex charts, density/local likelihood, chart-dimension selection,
  kernel geometry, model summaries and grouped-CV workflows.
- **440 installed-package expectations passed**, without failures, warnings or
  skips, using an isolated library containing both local packages. New help
  topics resolve. New fitting functions passed codetools usage checks.
- Chart tests cover seam distances, max normalization, tied maxima, corners,
  multiple faces, constant responses, explicit NA fallback and strict optimizer
  failures. CV is compared against separate training-fold fits; flipping held-out
  responses leaves their fixed-parameter predictions unchanged, including PLS.
- Documentation regenerated with `make document`; the API inventory and its
  mutation checks pass. Five pre-existing masked-field exports were missing from
  the catalog; their entries and generated signatures were refreshed alongside
  the new chart export. The new executable HTML vignette renders successfully.

The original 150-dataset Python simulation is not relabeled as an R-package
simulation. Its source reference, frozen here as `reference.py`, has SHA-256
`86cb6656fffc3df82ebd25c455187fff33523f3e94e1ce4ad930d0c97071d9d0`.
It comes from the anatomy_of_vaginal_microbiome project, report sources
`zapps_pressmat_geosmooth_geometry/unfolding/methods.py` (October 27, version 2
study). `make-fixtures.py` reproduces small synthetic-only CSV test fixtures
with NumPy/SciPy. No participant data are included. The first local QA attempt
could not generate fixtures using the default Python (SciPy absent); the existing
research Python environment produced them. A call-expression-only assertion was
corrected to compare fitted objects excluding the deliberately different call.
Original QA logs are retained privately; these were test-harness failures.

## Reproduction

Compile once optimized, then load local dependencies without recompiling. Keep
BLAS/OpenMP single-threaded. The user authorized six workers/30 GiB; the targeted
checks used at most two concurrent R jobs and no new cohort outcome fits.

```r
pkgload::load_all('../dgraphs', recompile=FALSE)
pkgload::load_all('.', recompile=FALSE)
testthat::test_local('.',
  filter='simplex|state-density|coupled-kd|chart-kernel|model-',
  load_package='none', stop_on_failure=TRUE)
rmarkdown::render('vignettes/local-simplex-charts.Rmd')
```

## Limits

Only degree-zero/one Bernoulli likelihood and numeric dimensions/grid CV are
implemented in the new path. Unfolded density measures and higher-degree fits
need separate development. Unsupported charts are recorded and fall back to a
smoothed local proportion or NA. Numerical convergence is not evidence of
clinical validity, uncertainty calibration or general superiority of PLS.
No full CRAN-style release check or performance benchmark was performed.
