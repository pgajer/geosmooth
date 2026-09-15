# geosmooth API signature appendix

Generated from the current source by `Rscript scripts/audit_api_guide.R --write`.
Companion to [the API review](api-review-2026-09-14.md).

There are 60 explicit exports: 60 local functions and 0 dgraphs re-exports; 95 S3 registrations are counted separately.

Counts below include `...` as one argument and exclude arguments forwarded through it.
Defaults are unevaluated source expressions. The guide is checked for exactly one catalog row per export.

## Local signatures

### apply.metric.graph.lowpass.path

8 arguments. Source: [R/metric_graph_lowpass.R](../../../R/metric_graph_lowpass.R#L560).

```r
apply.metric.graph.lowpass.path(basis, y, eta.grid, filter.type = c("heat_kernel", "tikhonov", "cubic_spline", "gaussian",
    "exponential", "butterworth"), block.size = NULL, truncation.tol = 1e-04, unresolved.action = c("warn",
    "error", "allow"), exact.zero = TRUE)
```

### bootstrap.malps

11 arguments. Source: [R/malps.R](../../../R/malps.R#L954).

```r
bootstrap.malps(object, B = 200L, weight.type = c("bayesian", "multinomial"), y = NULL, probs = NULL,
    conf.level = 0.95, seed = NULL, max.failures = max(10L, B), keep.weights = FALSE, verbose = FALSE,
    ...)
```

### compare.synthetic.dataset

3 arguments. Source: [R/synthetic_dataset.R](../../../R/synthetic_dataset.R#L493).

```r
compare.synthetic.dataset(x, y, tolerance = c(1e-12, 1e-10))
```

### fit.chart.kernel

23 arguments. Source: [R/chart_kernel.R](../../../R/chart_kernel.R#L86).

```r
fit.chart.kernel(X, y, X.eval = NULL, support.size = min(15L, nrow(X)), kernel = c("gaussian", "tricube",
    "epanechnikov", "triangular"), bandwidth.multiplier = 1, support.grid = NULL, kernel.grid = NULL,
    bandwidth.multiplier.grid = NULL, foldid = NULL, cv.folds = 5L, cv.seed = 1L, coordinate.method = c("coordinates",
        "local.pca"), chart.dim = NULL, chart.dim.grid = NULL, selection.strategy = c("grid",
        "sparse_kd", "plateau_kd"), chart.dim.max = NULL, geometry.margin = 0L, auto.chart.support.metric = c("coordinates",
        "operator", "both"), auto.chart.selection.metric = c("coordinates", "operator"),
    quadrature.weights = NULL, denominator.floor = sqrt(.Machine$double.eps), return.details = TRUE)
```

### fit.density

8 arguments. Source: [R/state_density.R](../../../R/state_density.R#L35).

```r
fit.density(X, weights = NULL, method = c("empirical", "graph_random_walk"), graph = NULL, graph.control = list(),
    density.control = list(), return.details = TRUE, ...)
```

### fit.graph.trend.filtering

20 arguments. Source: [R/graph_trend_filtering.R](../../../R/graph_trend_filtering.R#L213).

```r
fit.graph.trend.filtering(adj.list, weight.list = NULL, y, order = 0L, lambda.grid = NULL, lambda.selection = c("cv",
    "fixed"), weight.rule = c("conductance", "sqrt.conductance", "unit"), operator.family = c("graph.laplacian.recursive",
    "path.divided.difference"), path.family = c("branch.continuation", "all.simple"), path.weighting = c("unit",
    "anchor.mean"), n.lambda = 40L, nfolds = 5L, foldid = NULL, maxsteps = 2000L, minlam = 0,
    approx = FALSE, rtol = 1e-07, btol = 1e-07, eps = 1e-04, verbose = FALSE)
```

### fit.local.likelihood

33 arguments. Source: [R/local_likelihood.R](../../../R/local_likelihood.R#L99).

```r
fit.local.likelihood(X, y, X.eval = NULL, likelihood.family = c("density", "bernoulli"), support.size = min(15L,
    nrow(X)), degree = 1L, kernel = c("gaussian", "tricube", "epanechnikov", "triangular"),
    bandwidth.multiplier = 1, support.grid = NULL, degree.grid = NULL, kernel.grid = NULL,
    bandwidth.multiplier.grid = NULL, lambda.ridge.grid = NULL, foldid = NULL, cv.folds = 5L,
    cv.seed = 1L, coordinate.method = c("coordinates", "local.pca"), chart.dim = NULL, chart.dim.grid = NULL,
    selection.strategy = c("grid", "sparse_kd", "plateau_kd"), chart.dim.max = NULL, design.margin = 2L,
    auto.chart.support.metric = c("coordinates", "operator", "both"), auto.chart.selection.metric = c("coordinates",
        "operator"), quadrature.weights = NULL, lambda.ridge = 1e-08, min.local.mass = sqrt(.Machine$double.eps),
    min.nonzero.mass = 1L, fallback = c("degree0", "zero", "chart_kernel", "na"), optimizer = c("newton",
        "optim"), max.iter = 50L, tol = 1e-08, return.details = TRUE)
```

### fit.lpl.tf

27 arguments. Source: [R/lpl_tf.R](../../../R/lpl_tf.R#L349).

```r
fit.lpl.tf(X = NULL, y, operator = NULL, adj.list = NULL, weight.list = NULL, graph = NULL,
    degree = 2L, lambda.grid = NULL, lambda = NULL, lambda.selection = c("cv", "fixed"),
    operator.grid = NULL, foldid = NULL, cv.folds = 5L, cv.loss = c("mse", "rmse", "mae"),
    cv.seed = NULL, cv.repeats = 1L, solver = c("genlasso"), selection = c("min", "one.se"),
    n.lambda = 80L, maxsteps = 2000L, minlam = 0, approx = FALSE, rtol = 1e-07, btol = 1e-07,
    eps = 1e-04, verbose = FALSE, ...)
```

### fit.lps

31 arguments. Source: [R/lps.R](../../../R/lps.R#L234).

```r
fit.lps(X, y, foldid = NULL, support.grid = c(10L, 15L, 20L), degree.grid = 0:2, kernel.grid = c("gaussian",
    "tricube"), cv.folds = 5L, cv.seed = 1L, X.eval = NULL, coordinate.method = c("coordinates",
    "local.pca"), chart.dim = NULL, chart.dim.grid = NULL, local.chart.method = c("pca",
    "second.order.svd"), auto.chart.support.metric = c("coordinates", "operator", "both"),
    auto.chart.selection.metric = c("coordinates", "operator"), backend = c("auto", "R",
        "cpp", "cpp.local.pca"), design.basis = c("orthogonal.polynomial.drop", "monomial",
        "weighted.qr", "weighted.qr.drop"), design.drop.tol = 1e-08, ridge.multiplier.grid = c(0,
        1e-10, 1e-08), ridge.condition.max = 1e+12, unstable.action = c("na", "mean"), outcome.family = c("gaussian",
        "bernoulli", "binomial"), bandwidth.multiplier.grid = 1, keep.cv.predictions = FALSE,
    ridge.shrinkage.target = c("zero", "local.mean"), selection.strategy = c("grid", "sparse_kd",
        "plateau_kd"), chart.activation = c("none", "subject.od"), chart.activation.response = NULL,
    chart.activation.control = list(), chart.dim.max = NULL, design.margin = 2L)
```

### fit.malps

41 arguments. Source: [R/malps.R](../../../R/malps.R#L192).

```r
fit.malps(X, y, graph = NULL, adj.list = NULL, weight.list = NULL, graph.stage = "final",
    anchor.index = NULL, anchor.coordinates = NULL, degree = 2L, degree.grid = NULL, support.type = c("adaptive.radius",
        "knn", "fixed.radius"), support.size = NULL, support.grid = NULL, radius = NULL,
    radius.grid = NULL, min.support = NULL, min.support.grid = NULL, support.buffer = 3L,
    kernel = c("epanechnikov", "triangular", "gaussian", "tricube"), kernel.grid = NULL,
    model.weight.rule = c("none", "condition", "support", "boundary", "quality"), duplicate.action = c("keep",
        "error"), coordinate.method = c("coordinates", "local.pca"), chart.dim = NULL, support.metric = c("auto",
        "coordinates", "graph.geodesic"), auto.chart.support.metric = c("coordinates", "operator",
        "both"), auto.chart.selection.metric = c("coordinates", "operator"), support.selection = c("fixed",
        "cv", "gcv"), foldid = NULL, cv.folds = 5L, cv.loss = c("rmse", "mae", "mse"), cv.repeats = 1L,
    cv.seed = NULL, cv.one.se = FALSE, gcv.exact.max.n = 1000L, local.solver = c("auto",
        "normal.equations", "qr", "svd"), normal.equations.max.condition = 1e+08, robust.iterations = 0L,
    robust.tuning.constant = 6, verbose = FALSE, ...)
```

### fit.metric.graph.lowpass

25 arguments. Source: [R/metric_graph_lowpass.R](../../../R/metric_graph_lowpass.R#L888).

```r
fit.metric.graph.lowpass(adj.list, weight.list, y, conductance.rule = c("inverse.length.power", "exp.length",
    "exp.length.squared", "self.tuned.gaussian"), conductance.epsilon = 1e-08, conductance.alpha = 1,
    conductance.sigma = NULL, conductance.sigma.rule = c("edge.quantile", "median", "local.k"),
    conductance.sigma.quantile = 0.75, conductance.local.k = 5L, laplacian.type = c("unnormalized",
        "symmetric.normalized"), n.eigenpairs = 50L, filter.type = c("heat_kernel", "tikhonov",
        "cubic_spline", "gaussian", "exponential", "butterworth"), eta.grid = NULL, n.candidates = 40L,
    eigen.solver = c("auto", "sparse", "dense"), dense.eigen.threshold = 200L, dense.fallback.threshold = 5000L,
    dense.fallback = c("auto", "never", "always"), verbose = FALSE, eta.search = c("fixed",
        "guarded.gcv"), eta.expansion.factor = 3, eta.max.expansions = 3L, eta.identity.departure = 0.01,
    eta.truncation.tol = 1e-04)
```

### fit.ps.lps

37 arguments. Source: [R/ps_lps.R](../../../R/ps_lps.R#L140).

```r
fit.ps.lps(X, y, foldid = NULL, support.size = NULL, degree = 2L, kernel = "gaussian", chart.dim = NULL,
    support.grid = NULL, degree.grid = NULL, kernel.grid = NULL, auto.chart.support.metric = c("coordinates",
        "operator", "both"), auto.chart.selection.metric = c("coordinates", "operator"),
    chart.dim.grid = NULL, selection.strategy = c("grid", "sparse_kd", "plateau_kd"), chart.dim.max = NULL,
    design.margin = 2L, lambda.sync.grid = c(0, 0.001, 0.01, 0.1, 1, 10), lambda.sync.search = c("grid",
        "guarded"), lambda.sync.selection = c("cv", "fixed"), local.candidate.search = c("screened",
        "full", "subgrid"), local.candidate.search.control = list(), lambda.sync.search.control = list(),
    lambda.diagnostics = c("all", "selected"), lambda.ridge = 1e-08, design.basis = c("monomial",
        "weighted.qr", "weighted.qr.drop", "orthogonal.polynomial.drop"), design.drop.tol = sqrt(.Machine$double.eps),
    ridge.multiplier.grid = NULL, ridge.condition.max = Inf, sync.neighbor.size = NULL, overlap.weight = c("normalized.product",
        "product"), chart.activation = c("none", "subject.od"), chart.activation.response = NULL,
    chart.activation.control = list(), ps.lps.geometry.cache = NULL, ps.lps.local.pca.supports = NULL,
    cv.folds = 5L, cv.seed = 1L)
```

### fit.pttf.trend.filtering

34 arguments. Source: [R/pttf_fit.R](../../../R/pttf_fit.R#L70).

```r
fit.pttf.trend.filtering(geometry = NULL, operator = NULL, X = NULL, y, derivative.order = 3L, penalty = c("l1",
    "l2"), lambda.grid = NULL, lambda.selection = c("cv", "fixed"), n.lambda = 80L, nfolds = 5L,
    foldid = NULL, cv.loss = c("mse", "mae"), selection = c("min", "one.se"), lambda.extension = c("none",
        "auto"), solver = c("genlasso", "admm", "auto"), operator.row.policy = c("all", "drop.line.boundary",
        "diagnostic.only"), line.order = NULL, boundary.trim = NULL, row.mass.rule = c("none",
        "node.mass"), row.normalize = c("none", "l2"), weights = NULL, maxsteps = 2000L,
    minlam = 0, approx = FALSE, rtol = 1e-07, btol = 1e-07, eps = 1e-04, admm.rho = NULL,
    admm.maxiter = 2000L, admm.abstol = 1e-04, admm.reltol = 0.001, verbose = FALSE, admm.adaptive.rho = TRUE,
    ...)
```

### fit.slpl.tf

24 arguments. Source: [R/slpl_tf.R](../../../R/slpl_tf.R#L221).

```r
fit.slpl.tf(X = NULL, y, operator = NULL, lambda1 = NULL, lambda2 = 0, lambda1.grid = NULL,
    lambda2.grid = NULL, lambda.selection = c("fixed", "cv"), operator.grid = NULL, foldid = NULL,
    cv.folds = 5L, cv.loss = c("mse", "rmse", "mae"), cv.seed = NULL, cv.repeats = 1L, solver = c("genlasso"),
    selection = c("min", "one.se"), maxsteps = 2000L, minlam = 0, approx = FALSE, rtol = 1e-07,
    btol = 1e-07, eps = 1e-04, verbose = FALSE, ...)
```

### fit.ssrhe.hessian.l1.regression

47 arguments. Source: [R/ssrhe_hessian_energy.R](../../../R/ssrhe_hessian_energy.R#L2740).

```r
fit.ssrhe.hessian.l1.regression(X, y, k = NULL, tangent.dim, lambda.grid = NULL, lambda.selection = c("cv", "fixed"),
    weights = NULL, n.lambda = 40L, nfolds = 5L, fold.id = NULL, loss = c("mse", "mae"),
    selection = c("min", "one.se"), nn.index = NULL, neighborhood.type = c("knn", "adaptive.radius",
        "supplied"), support.index = NULL, adaptive.k.scale = NULL, radius.rule = c("geomean",
        "max", "min"), radius.factor = 1.25, min.support = NULL, max.support = NULL, support.buffer = 2L,
    support.topup = c("nearest", "none"), tangent.dim.rule = c("fixed", "eigen.cumulative"),
    eigen.tolerance = 0.95, derivative.order = 2L, pinv.tol = sqrt(.Machine$double.eps),
    local.solver = c("auto", "normal.equations", "svd", "qr"), normal.equations.max.condition = 10000,
    solver = c("genlasso", "admm", "auto"), row.scaling = c("none", "l2"), admm.rho = NULL,
    admm.maxiter = 2000L, admm.abstol = 1e-06, admm.reltol = 1e-05, maxsteps = 2000L, minlam = 0,
    approx = FALSE, rtol = 1e-07, btol = 1e-07, eps = 1e-04, support.selection = c("rule",
        "cv"), support.grid = NULL, support.cv.max.candidates = 8L, return.local.diagnostics = FALSE,
    return.timing = FALSE, verbose = FALSE, admm.adaptive.rho = TRUE)
```

### fit.ssrhe.hessian.regression

34 arguments. Source: [R/ssrhe_hessian_energy.R](../../../R/ssrhe_hessian_energy.R#L1178).

```r
fit.ssrhe.hessian.regression(X, y, k = NULL, tangent.dim, lambda1, lambda2 = 0, weights = NULL, nn.index = NULL,
    neighborhood.type = c("knn", "adaptive.radius", "supplied"), support.index = NULL, adaptive.k.scale = NULL,
    radius.rule = c("geomean", "max", "min"), radius.factor = 1.25, min.support = NULL, max.support = NULL,
    support.buffer = 2L, support.topup = c("nearest", "none"), tangent.dim.rule = c("fixed",
        "eigen.cumulative"), eigen.tolerance = 0.95, derivative.order = 2L, stabilizer = lambda2 >
        0, pinv.tol = sqrt(.Machine$double.eps), local.solver = c("auto", "normal.equations",
        "svd", "qr"), normal.equations.max.condition = 10000, ridge = 0, return.A = TRUE,
    return.local.diagnostics = FALSE, return.timing = FALSE, verbose = FALSE, lambda.selection = c("fixed",
        "cv", "gcv"), lambda1.grid = NULL, lambda2.grid = NULL, cv.control = list(), gcv.control = list())
```

### fit.subject.od

13 arguments. Source: [R/state_density.R](../../../R/state_density.R#L397).

```r
fit.subject.od(X, subject.index, method = c("empirical", "graph_random_walk", "lps_count", "ps_lps_count",
    "lps_logistic_binary", "chart_kernel", "local_likelihood_density", "local_likelihood_bernoulli"),
    graph = NULL, graph.control = list(), od.control = list(), return.details = TRUE, od.cv = c("none",
        "visit"), visit.foldid = NULL, visit.cv.folds = 5L, visit.cv.seed = 1L, visit.cv.epsilon = 1e-15,
    ...)
```

### get.region.boundary

2 arguments. Source: [R/harmonic_smoother.R](../../../R/harmonic_smoother.R#L743).

```r
get.region.boundary(adj.list, region)
```

### graph.trend.filtering.operator

8 arguments. Source: [R/graph_trend_filtering.R](../../../R/graph_trend_filtering.R#L52).

```r
graph.trend.filtering.operator(adj.list, weight.list = NULL, order = 0L, weight.rule = c("conductance", "sqrt.conductance",
    "unit"), operator.family = c("graph.laplacian.recursive", "path.divided.difference"),
    path.family = c("branch.continuation", "all.simple"), path.weighting = c("unit", "anchor.mean"),
    return.sparse = TRUE)
```

### harmonic.smoother

9 arguments. Source: [R/harmonic_smoother.R](../../../R/harmonic_smoother.R#L243).

```r
harmonic.smoother(adj.list, weight.list, values, region.vertices, max.iterations = 100, tolerance = 1e-06,
    record.frequency = 1, stability.window = 3, stability.threshold = 0.05)
```

### lpl.tf.operator

27 arguments. Source: [R/lpl_tf.R](../../../R/lpl_tf.R#L95).

```r
lpl.tf.operator(X, adj.list = NULL, weight.list = NULL, graph = NULL, graph.stage = "final", anchor.index = NULL,
    anchor.coordinates = NULL, degree = 2L, support.type = c("adaptive.radius", "knn", "fixed.radius"),
    support.size = NULL, radius = NULL, min.support = NULL, support.buffer = 3L, kernel = c("epanechnikov",
        "triangular", "gaussian", "tricube"), coordinate.method = c("coordinates", "local.pca"),
    chart.dim = NULL, support.metric = c("auto", "coordinates", "graph.geodesic"), auto.chart.support.metric = c("coordinates",
        "operator", "both"), auto.chart.selection.metric = c("coordinates", "operator"),
    exclude.self = TRUE, row.normalize = c("l2", "none", "l1"), local.solver = c("auto",
        "normal.equations", "qr", "svd"), normal.equations.max.condition = 1e+08, duplicate.action = c("keep",
        "error"), drop.rank.deficient = TRUE, verbose = FALSE, ...)
```

### lps.backend.diagnostics

1 arguments. Source: [R/lps.R](../../../R/lps.R#L803).

```r
lps.backend.diagnostics(object)
```

### lps.grouped.foldid

3 arguments. Source: [R/lps_cv_utils.R](../../../R/lps_cv_utils.R#L34).

```r
lps.grouped.foldid(cluster.id, v = 5L, shuffle.seed = NULL)
```

### lps.nested.cv

8 arguments. Source: [R/lps_cv_utils.R](../../../R/lps_cv_utils.R#L153).

```r
lps.nested.cv(X, y, outer.foldid, fit.args = list(), inner.folds = 5L, cluster.id = NULL, inner.foldid.method = c("round.robin",
    "grouped"), inner.shuffle.seed = NULL)
```

### lps.pointwise.band

5 arguments. Source: [R/lps_uncertainty.R](../../../R/lps_uncertainty.R#L343).

```r
lps.pointwise.band(object, sigma = NULL, level = 0.95, check.tol = 1e-10, variance.method = c("residual",
    "legacy"))
```

### malps.gcv

7 arguments. Source: [R/malps.R](../../../R/malps.R#L825).

```r
malps.gcv(object, y = NULL, smoother.matrix = NULL, include.loocv = TRUE, max.n = 1000L, allow.robust = FALSE,
    ...)
```

### materialize.synthetic

5 arguments. Source: [R/synthetic_materialize.R](../../../R/synthetic_materialize.R#L181).

```r
materialize.synthetic(spec, n = NULL, seed, rng.policy = c("named.stream.v1", "legacy"), validate = TRUE)
```

### materialize.synthetic.instance

2 arguments. Source: [R/synthetic_registry.R](../../../R/synthetic_registry.R#L850).

```r
materialize.synthetic.instance(instance.id, validate = TRUE)
```

### metric.graph.heat.eta.grid

6 arguments. Source: [R/metric_graph_lowpass.R](../../../R/metric_graph_lowpass.R#L275).

```r
metric.graph.heat.eta.grid(basis, rule = c("spectral_guarded", "w1_inverse_spectrum"), n.initial = 40L, include.zero = FALSE,
    truncation.tol = 1e-04, equilibrium.tol = 1e-04)
```

### metric.graph.heat.extend.lower

9 arguments. Source: [R/metric_graph_lowpass.R](../../../R/metric_graph_lowpass.R#L386).

```r
metric.graph.heat.extend.lower(basis, eta.grid, endpoint.status = c("active", "inactive", "unresolved"), expansion.factor = 3,
    max.expansions = 3L, expansions.completed = 0L, identity.departure = 0.01, truncation.tol = 1e-04,
    unresolved.action = c("error", "mark"))
```

### metric.graph.lowpass.basis

16 arguments. Source: [R/metric_graph_lowpass.R](../../../R/metric_graph_lowpass.R#L141).

```r
metric.graph.lowpass.basis(adj.list, weight.list, conductance.rule = c("inverse.length.power", "exp.length",
    "exp.length.squared", "self.tuned.gaussian"), conductance.epsilon = 1e-08, conductance.alpha = 1,
    conductance.sigma = NULL, conductance.sigma.rule = c("edge.quantile", "median", "local.k"),
    conductance.sigma.quantile = 0.75, conductance.local.k = 5L, laplacian.type = c("unnormalized",
        "symmetric.normalized"), n.eigenpairs = 50L, eigen.solver = c("auto", "sparse", "dense"),
    dense.eigen.threshold = 200L, dense.fallback.threshold = 5000L, dense.fallback = c("auto",
        "never", "always"), verbose = FALSE)
```

### metric.graph.lowpass.operator

12 arguments. Source: [R/metric_graph_lowpass.R](../../../R/metric_graph_lowpass.R#L62).

```r
metric.graph.lowpass.operator(adj.list, weight.list, conductance.rule = c("inverse.length.power", "exp.length",
    "exp.length.squared", "self.tuned.gaussian"), conductance.epsilon = 1e-08, conductance.alpha = 1,
    conductance.sigma = NULL, conductance.sigma.rule = c("edge.quantile", "median", "local.k"),
    conductance.sigma.quantile = 0.75, conductance.local.k = 5L, laplacian.type = c("unnormalized",
        "symmetric.normalized"), return.sparse = TRUE, verbose = FALSE)
```

### normalize.density

2 arguments. Source: [R/state_density.R](../../../R/state_density.R#L176).

```r
normalize.density(x, ...)
```

### perform.harmonic.smoothing

6 arguments. Source: [R/harmonic_smoother.R](../../../R/harmonic_smoother.R#L64).

```r
perform.harmonic.smoothing(adj.list, weight.list, values, region.vertices, max.iterations = 100, tolerance = 1e-06)
```

### pttf.geometry

17 arguments. Source: [R/pttf_geometry.R](../../../R/pttf_geometry.R#L61).

```r
pttf.geometry(X, adj.list = NULL, weight.list = NULL, graph = c("rknn", "supplied"), tangent.dim,
    local.support = c("graph.disk", "neighbors"), min.support = NULL, max.hops = 3L, support.k = NULL,
    graph.k.scale = 1L, graph.radius.factor = 1, graph.radius.rule = "geomean", transport.rule = c("procrustes"),
    synchronize.orientation = TRUE, density.method = c("support.radius"), alpha = 1, diagnostics = TRUE)
```

### pttf.operator

14 arguments. Source: [R/pttf_operator.R](../../../R/pttf_operator.R#L63).

```r
pttf.operator(geometry, derivative.order = 3L, edge.status.policy = c("ok.only", "frame.fallback"),
    regression.weight.rule = c("inverse.length.squared", "inverse.length", "unit"), edge.length.epsilon = 1e-08,
    tensor.scaling = c("hs", "raw"), row.mass.rule = c("node.mass", "none"), row.normalize = c("none",
        "l2"), min.operator.rank.tol = 1e-10, max.operator.condition = 1e+08, return.intermediate = TRUE,
    return.A = TRUE, return.B = TRUE, diagnostics = TRUE)
```

### pttf.operator.filter.rows

4 arguments. Source: [R/pttf_operator.R](../../../R/pttf_operator.R#L772).

```r
pttf.operator.filter.rows(operator, rows, reason = NULL, preserve.original = TRUE)
```

### refit

3 arguments. Source: [R/model_generics.R](../../../R/model_generics.R#L62).

```r
refit(object, y, ...)
```

### slpl.tf.operator

28 arguments. Source: [R/slpl_tf.R](../../../R/slpl_tf.R#L23).

```r
slpl.tf.operator(X, adj.list = NULL, weight.list = NULL, graph = NULL, graph.stage = "final", anchor.index = NULL,
    anchor.coordinates = NULL, degree = 2L, support.type = c("adaptive.radius", "knn", "fixed.radius"),
    support.size = NULL, radius = NULL, min.support = NULL, support.buffer = 3L, kernel = c("epanechnikov",
        "triangular", "gaussian", "tricube"), coordinate.method = c("coordinates", "local.pca"),
    chart.dim = NULL, support.metric = c("auto", "coordinates", "graph.geodesic"), auto.chart.support.metric = c("coordinates",
        "operator", "both"), auto.chart.selection.metric = c("coordinates", "operator"),
    row.normalize = c("l2", "none", "l1"), local.solver = c("auto", "normal.equations", "qr",
        "svd"), normal.equations.max.condition = 1e+08, duplicate.action = c("keep", "error"),
    drop.rank.deficient = TRUE, sync.row.normalize = c("l2"), sync.min.norm = 1e-12, verbose = FALSE,
    ...)
```

### smoother.matrix

2 arguments. Source: [R/model_generics.R](../../../R/model_generics.R#L116).

```r
smoother.matrix(object, ...)
```

### ssrhe.hessian.operator

27 arguments. Source: [R/ssrhe_hessian_energy.R](../../../R/ssrhe_hessian_energy.R#L168).

```r
ssrhe.hessian.operator(X, k = NULL, tangent.dim, nn.index = NULL, neighborhood.type = c("knn", "adaptive.radius",
    "supplied"), support.index = NULL, adaptive.k.scale = NULL, radius.rule = c("geomean",
    "max", "min"), radius.factor = 1.25, min.support = NULL, max.support = NULL, support.buffer = 2L,
    support.topup = c("nearest", "none"), tangent.dim.rule = c("fixed", "eigen.cumulative"),
    eigen.tolerance = 0.95, derivative.order = 2L, stabilizer = FALSE, pinv.tol = sqrt(.Machine$double.eps),
    local.solver = c("auto", "normal.equations", "svd", "qr"), normal.equations.max.condition = 10000,
    return.A = TRUE, return.B = TRUE, return.BS = stabilizer, return.sparse = TRUE, return.local.diagnostics = TRUE,
    return.timing = FALSE, verbose = FALSE)
```

### ssrhe.support.grid

5 arguments. Source: [R/ssrhe_hessian_energy.R](../../../R/ssrhe_hessian_energy.R#L553).

```r
ssrhe.support.grid(n, tangent.dim, derivative.order = 2L, support.buffer = 2L, max.candidates = 8L)
```

### synthetic.dataset.checksum

1 arguments. Source: [R/synthetic_dataset.R](../../../R/synthetic_dataset.R#L478).

```r
synthetic.dataset.checksum(x)
```

### synthetic.registry.ids

0 arguments. Source: [R/synthetic_registry.R](../../../R/synthetic_registry.R#L729).

```r
synthetic.registry.ids()
```

### synthetic.registry.seed

4 arguments. Source: [R/synthetic_registry.R](../../../R/synthetic_registry.R#L810).

```r
synthetic.registry.seed(recipe.id, replicate = 1L, n = NULL, base.seed = 273001L)
```

### synthetic.registry.spec

2 arguments. Source: [R/synthetic_registry.R](../../../R/synthetic_registry.R#L785).

```r
synthetic.registry.spec(recipe.id, parameters = list())
```

### synthetic.response.bernoulli

2 arguments. Source: [R/synthetic_response.R](../../../R/synthetic_response.R#L109).

```r
synthetic.response.bernoulli(minimum.positive = 0L, maximum.attempts = 1L)
```

### synthetic.response.clustered.gaussian

2 arguments. Source: [R/synthetic_response.R](../../../R/synthetic_response.R#L86).

```r
synthetic.response.clustered.gaussian(residual.sd, intraclass.correlation)
```

### synthetic.response.gaussian

1 arguments. Source: [R/synthetic_response.R](../../../R/synthetic_response.R#L19).

```r
synthetic.response.gaussian(sd)
```

### synthetic.response.heteroskedastic.gaussian

2 arguments. Source: [R/synthetic_response.R](../../../R/synthetic_response.R#L32).

```r
synthetic.response.heteroskedastic.gaussian(base.sd, truth.multiplier)
```

### synthetic.response.laplace.outlier

6 arguments. Source: [R/synthetic_response.R](../../../R/synthetic_response.R#L54).

```r
synthetic.response.laplace.outlier(laplace.scale, outlier.fraction, outlier.sd, minimum.outliers = 0L, count.rounding = "round",
    laplace.algorithm = "uniform.inverse.v1")
```

### synthetic.sampling.stratified

2 arguments. Source: [R/synthetic_sampling.R](../../../R/synthetic_sampling.R#L20).

```r
synthetic.sampling.stratified(fraction.a = 0.5, algorithm = c("stratum.sequential.v1", "legacy.g4.stratum.sequential.v1"))
```

### synthetic.spec

8 arguments. Source: [R/synthetic_spec.R](../../../R/synthetic_spec.R#L162).

```r
synthetic.spec(geometry, sampling, truth, response, recipe.id = NULL, registry.tag = NULL, compatibility = NULL,
    metadata = list())
```

### synthetic.truth.gaussian.mixture

5 arguments. Source: [R/synthetic_truth.R](../../../R/synthetic_truth.R#L109).

```r
synthetic.truth.gaussian.mixture(centers, scales, weights, normalize = c("none", "sample.max"), evaluation.coordinates = "latent")
```

### synthetic.truth.logit

3 arguments. Source: [R/synthetic_truth.R](../../../R/synthetic_truth.R#L221).

```r
synthetic.truth.logit(amplitude = 1.5, target.prevalence = 0.5, clip = c(0.05, 0.95))
```

### synthetic.truth.named

2 arguments. Source: [R/synthetic_truth.R](../../../R/synthetic_truth.R#L62).

```r
synthetic.truth.named(id, parameters = list())
```

### synthetic.truth.occupation.mixture

6 arguments. Source: [R/synthetic_truth.R](../../../R/synthetic_truth.R#L180).

```r
synthetic.truth.occupation.mixture(centers, covariances, weights, gamma = 1, probability.maximum = 0.65, normalization = "design.maximum")
```

### synthetic.truth.polynomial

2 arguments. Source: [R/synthetic_truth.R](../../../R/synthetic_truth.R#L82).

```r
synthetic.truth.polynomial(coefficients, evaluation.coordinates = "latent")
```

### transported.graph.hessian.operator

52 arguments. Source: [R/transported_graph_hessian.R](../../../R/transported_graph_hessian.R#L213).

```r
transported.graph.hessian.operator(adj.list, weight.list = NULL, transport.order = 2L, transport.rule = c("exact.coordinate",
    "local.embedding.soft", "edge.angle.hard", "edge.angle.soft", "regression.gradient"),
    coordinates = NULL, direction.labels = NULL, polynomial.probes = NULL, local.embedding.method = c("auto",
        "coordinates", "grip.edge.kk", "mds.edge.kk", "cmdscale"), local.embedding.dim = 2L,
    local.disk.hops = 1L, local.max.vertices = 50L, return.sparse = TRUE, tol = 1e-08, soft.angle.scale = NULL,
    soft.length.scale = NULL, soft.bandwidth = 0.25, max.match.angle = NULL, max.length.relative.error = NULL,
    min.match.margin = NULL, max.effective.matches = NULL, match.threshold.rule = c("none",
        "fixed", "local.quantile", "local.robust.z"), match.score.quantile = 0.25, match.margin.quantile = 0.5,
    min.best.score.z = 1, min.margin.z = 0, max.effective.match.fraction = NULL, edge.angle.scale = NULL,
    edge.length.scale = NULL, edge.angle.bandwidth = 0.35, edge.angle.max.angle.difference = NULL,
    edge.angle.max.length.relative.error = NULL, gradient.coordinate.method = c("coordinates",
        "local.embedding"), gradient.embedding.method = c("grip.edge.kk", "mds.edge.kk",
        "cmdscale"), gradient.embedding.dim = NULL, gradient.disk.hops = local.disk.hops,
    gradient.max.vertices = local.max.vertices, gradient.disk.rule = c("hops", "metric.diameter.fraction",
        "metric.local.scale"), gradient.disk.radius.fraction = 0.1, gradient.disk.local.scale.method = c("knn.distance",
        "median.incident.length", "quantile.incident.length"), gradient.disk.local.scale.k = 8L,
    gradient.disk.local.scale.quantile = 0.75, gradient.disk.local.scale.multiplier = 2,
    gradient.disk.min.vertices = 0L, gradient.chart.selection = c("fixed", "adaptive"), gradient.embedding.candidates = c("cmdscale",
        "mds.edge.kk"), gradient.disk.rule.candidates = c("hops", "metric.diameter.fraction",
        "metric.local.scale"), gradient.disk.hops.candidates = 1:5, gradient.disk.radius.fraction.candidates = c(0.05,
        0.075, 0.1, 0.15, 0.2), gradient.disk.local.scale.multiplier.candidates = c(1, 1.5,
        2, 3, 4), gradient.ridge = 1e-08, gradient.quadratic.disk.hops = 2L, gradient.quadratic.max.vertices = gradient.max.vertices)
```

### validate.synthetic.dataset

1 arguments. Source: [R/synthetic_dataset.R](../../../R/synthetic_dataset.R#L271).

```r
validate.synthetic.dataset(x)
```

## Related dgraphs functions (not geosmooth exports)

These geometry and sampling functions are owned by dgraphs. Call them with dgraphs::; they are imported for internal recipe construction but not re-exported.

- `dgraphs::edge.lengths.synthetic.geometry()`
- `dgraphs::embed.synthetic.geometry()`
- `dgraphs::quadform.gradient()`
- `dgraphs::quadform.metric()`
- `dgraphs::synthetic.circle()`
- `dgraphs::synthetic.helix()`
- `dgraphs::synthetic.point.line.junction()`
- `dgraphs::synthetic.quadform()`
- `dgraphs::synthetic.sampling.clustered()`
- `dgraphs::synthetic.sampling.dirichlet.zeros()`
- `dgraphs::synthetic.sampling.gapped.uniform()`
- `dgraphs::synthetic.sampling.grid.interval()`
- `dgraphs::synthetic.sampling.truncated.normal()`
- `dgraphs::synthetic.sampling.uniform.box()`
- `dgraphs::synthetic.sampling.uniform.disk()`
- `dgraphs::synthetic.sampling.uniform.interval()`
- `dgraphs::synthetic.sampling.uniform.rectangle()`
- `dgraphs::synthetic.simplex()`
- `dgraphs::synthetic.sphere.cap()`
- `dgraphs::synthetic.stratified()`
- `dgraphs::synthetic.stratum.point()`
- `dgraphs::synthetic.stratum.rectangle()`
- `dgraphs::synthetic.stratum.segment()`
- `dgraphs::synthetic.torus.patch()`
- `dgraphs::synthetic.trefoil()`

## Registered S3 methods

Use the corresponding generic; these registrations are not additional explicit exports.

```r
S3method(as.data.frame,synthetic_dataset)
S3method(fitted,chart_kernel)
S3method(fitted,graph.trend.filtering.fit)
S3method(fitted,harmonic_smoother)
S3method(fitted,local_likelihood)
S3method(fitted,lpl_tf)
S3method(fitted,lps)
S3method(fitted,malps)
S3method(fitted,metric.graph.lowpass.fit)
S3method(fitted,metric.graph.lowpass.refit)
S3method(fitted,ps_lps)
S3method(fitted,pttf.trend.filtering.fit)
S3method(fitted,slpl_tf)
S3method(fitted,ssrhe.hessian.fit)
S3method(fitted,ssrhe.hessian.l1.fit)
S3method(fitted,ssrhe.hessian.refit)
S3method(normalize.density,default)
S3method(normalize.density,lps)
S3method(normalize.density,metric.graph.lowpass.fit)
S3method(normalize.density,metric.graph.lowpass.refit)
S3method(normalize.density,numeric)
S3method(normalize.density,ps_lps)
S3method(plot,harmonic_smoother)
S3method(plot,synthetic_dataset)
S3method(predict,lpl_tf)
S3method(predict,lps)
S3method(predict,malps)
S3method(predict,slpl_tf)
S3method(print,chart_kernel)
S3method(print,density_fit)
S3method(print,graph.trend.filtering.fit)
S3method(print,harmonic_smoother)
S3method(print,local_likelihood)
S3method(print,lpl_tf)
S3method(print,lpl_tf_operator)
S3method(print,lps)
S3method(print,malps)
S3method(print,malps_bootstrap)
S3method(print,metric.graph.lowpass.fit)
S3method(print,metric.graph.lowpass.refit)
S3method(print,ps_lps)
S3method(print,pttf.trend.filtering.fit)
S3method(print,pttf_operator)
S3method(print,slpl_tf)
S3method(print,slpl_tf_operator)
S3method(print,ssrhe.hessian.cv.fit)
S3method(print,ssrhe.hessian.fit)
S3method(print,ssrhe.hessian.gcv.fit)
S3method(print,ssrhe.hessian.l1.fit)
S3method(print,ssrhe.hessian.operator)
S3method(print,ssrhe.hessian.refit)
S3method(print,summary.geosmooth_fit)
S3method(print,summary.harmonic_smoother)
S3method(print,synthetic_dataset)
S3method(print,transported.graph.hessian.operator)
S3method(refit,default)
S3method(refit,lpl_tf)
S3method(refit,malps)
S3method(refit,metric.graph.lowpass.fit)
S3method(refit,slpl_tf)
S3method(refit,ssrhe.hessian.fit)
S3method(refit,ssrhe.hessian.l1.fit)
S3method(residuals,chart_kernel)
S3method(residuals,graph.trend.filtering.fit)
S3method(residuals,local_likelihood)
S3method(residuals,lpl_tf)
S3method(residuals,lps)
S3method(residuals,malps)
S3method(residuals,metric.graph.lowpass.fit)
S3method(residuals,metric.graph.lowpass.refit)
S3method(residuals,ps_lps)
S3method(residuals,pttf.trend.filtering.fit)
S3method(residuals,slpl_tf)
S3method(residuals,ssrhe.hessian.fit)
S3method(residuals,ssrhe.hessian.l1.fit)
S3method(residuals,ssrhe.hessian.refit)
S3method(smoother.matrix,default)
S3method(smoother.matrix,lps)
S3method(smoother.matrix,malps)
S3method(summary,chart_kernel)
S3method(summary,density_fit)
S3method(summary,graph.trend.filtering.fit)
S3method(summary,harmonic_smoother)
S3method(summary,local_likelihood)
S3method(summary,lpl_tf)
S3method(summary,lps)
S3method(summary,malps)
S3method(summary,metric.graph.lowpass.fit)
S3method(summary,metric.graph.lowpass.refit)
S3method(summary,ps_lps)
S3method(summary,pttf.trend.filtering.fit)
S3method(summary,slpl_tf)
S3method(summary,ssrhe.hessian.fit)
S3method(summary,ssrhe.hessian.l1.fit)
S3method(summary,ssrhe.hessian.refit)
```

