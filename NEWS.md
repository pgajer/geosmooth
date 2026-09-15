# geosmooth 0.2.0

## Solver reliability

- Hessian L1 ADMM uses an operator-scale initial penalty by default
  (`admm.rho = NULL`) and adapts it during its initial iterations. An explicit
  positive `admm.rho` still sets the initial value; use
  `admm.adaptive.rho = FALSE` to hold it fixed. Numerical stabilization now
  preserves the requested objective instead of adding an unintended ridge.
- ADMM convergence also checks stationarity of the original objective.
  Incomplete fixed fits warn and print their status. CV excludes candidates
  with any unsuccessful fold and errors if none qualify or the selected
  full-data ADMM refit is incomplete. Fold diagnostics are retained, including
  on the no-eligible-candidate error. Generalized-lasso warnings are retained.
- The shared PTTF L1 solver receives the same safeguards. Hessian L1 objective
  reporting now accounts for the penalty actually used with row scaling;
  the unscaled Hessian norm remains available separately.

- Generalized-lasso Hessian paths now propose penalties only: all returned
  coefficients and CV candidates are solved by ADMM on the original objective.
  Finite path coefficients can be suboptimal for nearly rank-deficient operators;
  missing-label path coefficients can include an extra ridge. The path remains
  diagnostic, with its original objectives in `solver$path.objective` and the
  refined route labeled `genlasso_admm_refined`. Default Hessian ADMM stopping
  tolerances are now `1e-6` absolute and `1e-5` relative. Fitted values and selected
  penalties can change; difficult candidates may require a larger iteration cap.

## Uncertainty and result interpretation

- `lps.pointwise.band()` now estimates noise variance using residual noise
  degrees of freedom `sum((I - S)^2) = n - 2*tr(S) + sum(S^2)`. The former
  `n - tr(S)` denominator is available as `variance.method = "legacy"`.
  `df` still reports `tr(S)`; `residual.df` is returned separately. Bands remain
  pointwise, conditional on a fixed smoother, and uncorrected for smoothing bias.
- Regression families support `fitted()` and `residuals()` with their existing
  vector/matrix and missing-label contracts. Residuals at other evaluation
  coordinates are rejected. Tracked harmonic fitted values use `fitted()`; density mass
  stays `$rho`. No new out-of-sample prediction or reusable-refit contract is implied.
- Lifting, synchronized lifting, density, prediction-synchronized, chart-kernel,
  and local-likelihood fits print bounded diagnostics. Structured `summary()`
  methods cover the main regression families. Unavailable convergence information
  is labeled explicitly, and density accounting and local fallbacks remain visible.
- The existing guides now include interpreted first-fit and graph workflows,
  embedded figures with text alternatives, and clear latent/ambient synthetic
  views. `plot.synthetic_dataset()` adds named `view`, `legend`, and `col`
  controls while preserving automatic view selection. Point-color keys now
  describe the displayed values; region coloring requires region labels.
- Graph adaptation uses dgraphs' public distance API and accepts both transitional
  graph lists and the forthcoming `dgraph` representation, without restoring
  retired geometry re-exports.

## Input validation and harmonic diagnostics

- Density methods now reject misspelled, duplicated, or unsupported controls
  and unused terminal arguments. Logical controls require `TRUE` or `FALSE`.
  Recognized controls forwarded to subject-occupation smoothers remain supported.
- Graph low-pass, density, and harmonic methods validate finite integer vertex
  indices before conversion. Fractional indices and iteration counts now error
  instead of silently selecting a different vertex or truncating a control.
- Harmonic smoothing documents the actual boundary rule: a region vertex must
  have a neighbor outside the region; graph leaves are not automatically fixed.
  The basic function still leaves a boundary-free region unchanged, while the
  tracked function still relaxes it. Both now report explicit numerical status.
- `harmonic.smoother()` reports extrema-stability detection separately from
  numerical convergence. `stable_iteration` is now `NA_integer_` when no
  stability window was detected; check `stability_detected` before using it.
  It returns update/residual histories and actual recorded iteration numbers,
  always records the final state, and uses those numbers in plots. Stability
  of recorded extrema does not establish convergence or optimal smoothing.

## API changes

This release reduces the explicit public API from 93 to 60 exported functions.
The 35 retired names are replaced by dependency-qualified calls, a unified
fitter, or two S3 generics.

- Replace the six exported `refit.*()` functions with the S3 generic
  `refit(object, y, ...)`, covering MALPS, both lifting trend filters,
  metric graph low-pass, quadratic Hessian, and Hessian L1 fits. In old
  calls, rename `fitted.model` to `object` and `y.new` to `y`.
  Method-specific controls, response-shape restrictions, selection behavior,
  and return classes are preserved. Former help names remain available.
- Replace `lps.smoother.matrix()` and `malps.smoother.matrix()` with
  `smoother.matrix(object, ...)`. LPS retains `check.tol` and its
  fixed-configuration requirements; MALPS retains `max.n`, `allow.robust`,
  and its conditional interpretation. The eight former entry points are
  no longer exported. The function-guide vignette documents all supported methods.

- API consolidation (breaking change): retire the 25 transitional synthetic
  geometry and sampling re-exports. Call the same names and arguments with
  `dgraphs::`, for example `dgraphs::synthetic.circle()` and
  `dgraphs::synthetic.sampling.uniform.interval(0, 1)`. Statistical recipe,
  truth, response, materialization, and validation functions remain in
  geosmooth, including its local `synthetic.sampling.stratified()`.
- Consolidate quadratic Hessian regression into
  `fit.ssrhe.hessian.regression()`. Existing fixed calls with `lambda1` and
  `lambda2` are unchanged. Replace the former `.cv()` and `.gcv()` fitters
  with `lambda.selection = "cv"` or `"gcv"` and penalty grids. The old
  function names are no longer exported; their help aliases explain migration.
- CV settings now use `cv.control = list(foldid = ..., cv.folds = ...,
  loss = "mse", selection = "min")`; `foldid` replaces `fold.id` and
  `cv.folds` replaces `nfolds`. GCV trace settings use
  `gcv.control = list(trace.method = "hutchinson", trace.n.probes = 50L,
  trace.seed = ...)`. Both control lists support `support.selection`,
  `support.grid`, and `support.max.candidates` (formerly the mode-specific
  `support.cv.max.candidates` / `support.gcv.max.candidates`). Nonempty controls
  for the wrong mode, unknown control entries, and simultaneous scalar/grid
  penalties are errors. CV still supports missing labels; GCV still requires
  a single fully observed response and strictly positive weights. Existing
  fit classes, CV/GCV tables, and refit support are preserved.

## Dependencies

- Delegate reusable synthetic geometry and point generation to dgraphs
  (>= 0.2.1.9000).
  Statistical recipes, responses, dataset identities and legacy G4 remain
  here. Geometry Lab and maintained geometry reference tools now live in
  the dgraphs development tree.

## Documentation

- Clarify that metric graph low-pass refits process response columns
  sequentially. The retained `n.cores` argument does not enable parallel
  execution, and per-column GCV results report `n.cores.used = 1L`.
- Add "Finding your way around geosmooth", a task-oriented vignette covering
  every exported function, supported prediction/refit workflows, and migration
  to the consolidated API. Link the guide from the package overview and README.
- Update the synthetic-datasets vignette to use geometry and sampling from
  dgraphs. Both vignettes are distributed as HTML with the built package.

# geosmooth 0.1.0

* Initial CRAN release.
* Provides local polynomial and model-averaged local polynomial smoothing,
  local polynomial lifting trend filtering, synchronized local polynomial
  lifting trend filtering, and occupation-density adapters.
* Provides metric-graph low-pass filtering and Hessian-energy regression with
  compiled backends.
* Provides reproducible synthetic geometry and response generators for method
  evaluation.
* Makes synthetic-registry identity verification stable across supported R
  versions by excluding the serializer's producer-version header from the
  checksum contract.
