# geosmooth 0.2.0

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
