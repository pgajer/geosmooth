#' Fit a Density Estimator
#'
#' Dispatches to a dedicated density estimator. Subject-occupation density
#' estimation is one application: construct a sparse mass vector over a fixed
#' support set and call this generic density layer.
#'
#' @param X Numeric matrix with one row per support point.
#' @param weights Optional nonnegative mass/count vector of length
#'   \code{nrow(X)}. Required by count-based density methods.
#' @param method Density method identifier.
#' @param graph Optional precomputed graph object.
#' @param graph.control List of graph-method controls.
#' @param density.control List controlling clipping, normalization, and
#'   accounting checks.  Recognized entries are \code{mass.tol},
#'   \code{neg.tol}, \code{clip.negative}, and \code{renormalize}.
#' @param return.details Logical; if \code{TRUE}, keep diagnostic details in
#'   the result.
#' @param ... Additional method-specific arguments.
#'
#' @return A list of class \code{"density_fit"} with fields
#'   \code{method.id}, \code{status}, \code{rho}, \code{empirical.rho},
#'   \code{fitted.raw}, \code{theta}, \code{accounting},
#'   \code{smoothness}, \code{timing}, \code{diagnostics}, and
#'   \code{warnings}.
#' @export
fit.density <- function(
    X,
    weights = NULL,
    method = c("empirical", "graph_random_walk"),
    graph = NULL,
    graph.control = list(),
    density.control = list(),
    return.details = TRUE,
    ...) {

    method <- match.arg(method)
    X <- .state.density.validate.X(X)
    ctrl <- .state.density.control(density.control)

    switch(
        method,
        empirical = fit.density.empirical(
            X = X,
            weights = weights,
            density.control = ctrl,
            return.details = return.details,
            ...
        ),
        graph_random_walk = fit.density.graph.random.walk(
            X = X,
            weights = weights,
            graph = graph,
            graph.control = graph.control,
            density.control = ctrl,
            return.details = return.details,
            ...
        )
    )
}

#' Fit Empirical Density
#'
#' Normalizes a nonnegative mass/count vector over a fixed support set.
#'
#' @inheritParams fit.density
#' @export
fit.density.empirical <- function(
    X,
    weights,
    density.control = list(),
    return.details = TRUE,
    ...) {

    dots <- .state.density.named.dots(...)
    .state.density.reject.chart.dots(dots, "fit.density.empirical()")
    X <- .state.density.validate.X(X)
    ctrl <- .state.density.control(density.control)
    weights <- .state.density.validate.weights(weights, nrow(X), "weights")
    empirical <- .state.density.normalize.weights(weights)

    .state.density.finalize(
        method.id = "empirical",
        X = X,
        fitted.raw = empirical,
        empirical.rho = empirical,
        theta = list(),
        density.control = ctrl,
        diagnostics = list(input.weight.sum = sum(weights)),
        return.details = return.details
    )
}

#' Fit Graph Random-Walk Density
#'
#' Smooths a nonnegative mass vector by propagating it through a row-stochastic
#' graph random walk.
#'
#' @inheritParams fit.density
#' @export
fit.density.graph.random.walk <- function(
    X,
    weights,
    graph = NULL,
    graph.control = list(),
    density.control = list(),
    return.details = TRUE,
    ...) {

    dots <- .state.density.named.dots(...)
    .state.density.reject.chart.dots(dots, "fit.density.graph.random.walk()")
    X <- .state.density.validate.X(X)
    ctrl <- .state.density.control(density.control)
    weights <- .state.density.validate.weights(weights, nrow(X), "weights")
    empirical <- .state.density.normalize.weights(weights)
    graph <- .state.density.prepare.graph(graph, nrow(X), allow.zero.length = TRUE)
    rw <- .state.density.random.walk(
        empirical = empirical,
        graph = graph,
        graph.control = graph.control
    )

    .state.density.finalize(
        method.id = "graph_random_walk",
        X = X,
        fitted.raw = rw$rho,
        empirical.rho = empirical,
        theta = rw$theta,
        density.control = ctrl,
        adj.list = graph$adj.list,
        diagnostics = list(
            transition = if (isTRUE(return.details)) rw$transition else NULL,
            occupation.by.step = if (isTRUE(return.details)) rw$occupation.by.step else NULL,
            row.strength = if (isTRUE(return.details)) rw$row.strength else NULL,
            transition.metadata = rw$metadata
        ),
        return.details = return.details
    )
}

#' Normalize Fitted Values Into a Density
#'
#' Converts a numeric field or fitted smoother/regression object into a
#' probability mass vector over the evaluation support.  This is the explicit
#' adapter between ordinary smoothers such as \code{\link{fit.lps}},
#' \code{\link{fit.ps.lps}}, and \code{\link{fit.metric.graph.lowpass}} and
#' density or occupation-density workflows.
#'
#' @param x Numeric vector or fitted object with a \code{fitted.values} field.
#' @param X Optional support/evaluation matrix.  If omitted, methods use the
#'   fitted object's stored \code{X.eval} or \code{X} field when available; for
#'   a bare numeric vector, a one-dimensional index support is used.
#' @param density.control List controlling clipping, normalization, and
#'   accounting checks.  See \code{\link{fit.density}}.
#' @param method.id Character method identifier recorded in the returned object.
#' @param keep.source.fit Logical; if \code{TRUE}, retain the source fit in
#'   diagnostics for object methods.
#' @param adj.list Optional adjacency list used to compute graph-local
#'   smoothness diagnostics for the normalized density.
#' @param return.details Logical; if \code{TRUE}, keep diagnostic details in
#'   the result.
#' @param ... Additional arguments passed to methods.
#'
#' @return A list of class \code{"density_fit"}.
#' @export
normalize.density <- function(x, ...) {
    UseMethod("normalize.density")
}

#' @export
normalize.density.numeric <- function(x,
                                      X = NULL,
                                      density.control = list(),
                                      method.id = "normalized_numeric",
                                      keep.source.fit = FALSE,
                                      adj.list = NULL,
                                      empirical.rho = NULL,
                                      return.details = TRUE,
                                      ...) {
    .normalize.density.vector(
        values = x,
        X = X,
        method.id = method.id,
        source.fit = NULL,
        source.class = "numeric",
        density.control = density.control,
        keep.source.fit = keep.source.fit,
        adj.list = adj.list,
        empirical.rho = empirical.rho,
        return.details = return.details
    )
}

#' @export
normalize.density.default <- function(x,
                                      X = NULL,
                                      density.control = list(),
                                      method.id = NULL,
                                      keep.source.fit = TRUE,
                                      adj.list = NULL,
                                      empirical.rho = NULL,
                                      return.details = TRUE,
                                      ...) {
    if (is.null(x$fitted.values)) {
        stop("normalize.density() requires a numeric vector or an object with fitted.values.",
             call. = FALSE)
    }
    .normalize.density.fit(
        x = x,
        X = X,
        density.control = density.control,
        method.id = method.id,
        keep.source.fit = keep.source.fit,
        adj.list = adj.list,
        empirical.rho = empirical.rho,
        return.details = return.details
    )
}

#' @export
normalize.density.lps <- function(x,
                                  X = NULL,
                                  density.control = list(),
                                  method.id = NULL,
                                  keep.source.fit = TRUE,
                                  adj.list = NULL,
                                  empirical.rho = NULL,
                                  return.details = TRUE,
                                  ...) {
    .normalize.density.fit(
        x = x,
        X = X,
        density.control = density.control,
        method.id = method.id,
        keep.source.fit = keep.source.fit,
        adj.list = adj.list,
        empirical.rho = empirical.rho,
        return.details = return.details
    )
}

#' @export
normalize.density.ps_lps <- function(x,
                                     X = NULL,
                                     density.control = list(),
                                     method.id = NULL,
                                     keep.source.fit = TRUE,
                                     adj.list = NULL,
                                     empirical.rho = NULL,
                                     return.details = TRUE,
                                     ...) {
    .normalize.density.fit(
        x = x,
        X = X,
        density.control = density.control,
        method.id = method.id,
        keep.source.fit = keep.source.fit,
        adj.list = adj.list,
        empirical.rho = empirical.rho,
        return.details = return.details
    )
}

#' @export
normalize.density.metric.graph.lowpass.fit <- function(
    x,
    X = NULL,
    density.control = list(),
    method.id = NULL,
    keep.source.fit = TRUE,
    adj.list = NULL,
    empirical.rho = NULL,
    return.details = TRUE,
    ...) {
    .normalize.density.fit(
        x = x,
        X = X,
        density.control = density.control,
        method.id = method.id,
        keep.source.fit = keep.source.fit,
        adj.list = adj.list,
        empirical.rho = empirical.rho,
        return.details = return.details
    )
}

#' @export
normalize.density.metric.graph.lowpass.refit <- function(
    x,
    X = NULL,
    density.control = list(),
    method.id = NULL,
    keep.source.fit = TRUE,
    adj.list = NULL,
    empirical.rho = NULL,
    return.details = TRUE,
    ...) {
    .normalize.density.fit(
        x = x,
        X = X,
        density.control = density.control,
        method.id = method.id,
        keep.source.fit = keep.source.fit,
        adj.list = adj.list,
        empirical.rho = empirical.rho,
        return.details = return.details
    )
}

#' Fit Subject-Occupation Density
#'
#' Convenience wrapper that converts subject visit indices into a density
#' input. Density-native methods dispatch to \code{\link{fit.density}}.
#' LPS/PS-LPS methods fit ordinary smoother objects first and then call
#' \code{\link{normalize.density}}; they are subject-occupation workflows, not
#' standalone density-native methods.
#'
#' The \code{"lps_logistic_binary"} method name is historical.  In the current
#' OD workflow it calls \code{fit.lps(..., outcome.family = "bernoulli")}, which
#' fits a clipped probability field with the LPS least-squares core and then
#' converts that field to a density with \code{\link{normalize.density}}.  It is
#' not the \code{outcome.family = "binomial"} local-logistic IRLS path.
#'
#' When \code{od.cv = "visit"}, graph random-walk candidates may pass
#' OD-level grids inside \code{graph.control}: \code{walk.step.grid},
#' \code{affinity.method.grid}, \code{affinity.scale.grid},
#' \code{affinity.epsilon.grid}, and \code{normalize.grid}.  Missing
#' \code{affinity.scale} values mean the usual data-derived affinity scale.
#'
#' When \code{od.cv = "visit"}, chart-based and LPS-family methods may pass
#' \code{chart.dim.grid} through \code{...}.  For \code{"chart_kernel"},
#' \code{"local_likelihood_density"}, \code{"local_likelihood_bernoulli"},
#' \code{"lps_count"}, \code{"lps_logistic_binary"}, and
#' \code{"ps_lps_count"}, this grid compares fixed integer chart dimensions
#' with optional \code{"auto"} and \code{"local.auto"} chart-dimension policies
#' under the same held-out-visit negative-log-occupation score.  For LPS-family
#' OD visit CV, each outer candidate is passed to the source smoother as a
#' scalar local model configuration; this avoids nested row-level
#' multi-candidate selection inside each held-out-visit fold.
#'
#' @inheritParams fit.density
#' @param subject.index Integer row indices of subject visits in \code{X}.
#'   Repeated indices are allowed.
#' @param od.control OD-facing alias for \code{density.control}.
#' @param od.cv OD-level selection mode.  \code{"none"} preserves the direct
#'   fit.  \code{"visit"} holds out subject visits, fits candidates on the
#'   remaining visits, and selects the candidate minimizing held-out negative
#'   log occupation mass.
#' @param visit.foldid Optional positive integer vector assigning subject visits
#'   to OD-level cross-validation folds.  Its length must equal
#'   \code{length(subject.index)}.
#' @param visit.cv.folds Number of visit folds when \code{visit.foldid} is not
#'   supplied.
#' @param visit.cv.seed Random seed for generated visit folds.
#' @param visit.cv.epsilon Positive floor used in held-out
#'   \code{-log(rho[visit])} scoring.
#'
#' @export
fit.subject.od <- function(
    X,
    subject.index,
    method = c("empirical", "graph_random_walk", "lps_count",
               "ps_lps_count", "lps_logistic_binary", "chart_kernel",
               "local_likelihood_density", "local_likelihood_bernoulli"),
    graph = NULL,
    graph.control = list(),
    od.control = list(),
    return.details = TRUE,
    od.cv = c("none", "visit"),
    visit.foldid = NULL,
    visit.cv.folds = 5L,
    visit.cv.seed = 1L,
    visit.cv.epsilon = 1e-15,
    ...) {

    X <- .state.density.validate.X(X)
    subject.index <- .state.density.validate.subject.index(subject.index, nrow(X))
    weights <- .state.density.subject.weights(subject.index, nrow(X))
    method <- match.arg(method)
    od.cv <- match.arg(od.cv)

    if (identical(od.cv, "visit")) {
        dots <- .state.density.named.dots(...)
        return(.state.density.fit.subject.od.visit.cv(
            X = X,
            subject.index = subject.index,
            method = method,
            graph = graph,
            graph.control = graph.control,
            od.control = od.control,
            return.details = return.details,
            visit.foldid = visit.foldid,
            visit.cv.folds = visit.cv.folds,
            visit.cv.seed = visit.cv.seed,
            visit.cv.epsilon = visit.cv.epsilon,
            dots = dots
        ))
    }

    density.methods <- c("empirical", "graph_random_walk")
    out <- if (method %in% density.methods) {
        fit.density(
            X = X,
            weights = weights,
            method = method,
            graph = graph,
            graph.control = graph.control,
            density.control = od.control,
            return.details = return.details,
            ...
        )
    } else {
        .state.density.fit.subject.smoother.od(
            X = X,
            weights = weights,
            method = method,
            graph = graph,
            od.control = od.control,
            return.details = return.details,
            ...
        )
    }
    .state.density.attach.subject(out, subject.index, weights)
}

#' Precheck Density Dependencies
#'
#' Checks that the package-level functions needed by the OD0 contract are
#' available.  Optional benchmark dependencies, such as \pkg{gflow}, are reported
#' rather than loaded as hard package dependencies.
#'
#' @param check.gflow Logical; if \code{TRUE}, check the optional gflow basin
#'   utilities needed by OD4b.
#' @param fail Logical; if \code{TRUE}, stop when required functions are missing.
#'
#' @return A data frame with dependency check rows.
#' @export density.dependency.precheck
density.dependency.precheck <- function(check.gflow = TRUE,
                                              fail = FALSE) {
    rows <- list()
    add <- function(package, symbol, required, available, note = "") {
        rows[[length(rows) + 1L]] <<- data.frame(
            package = package,
            symbol = symbol,
            required = required,
            available = available,
            note = note,
            stringsAsFactors = FALSE
        )
    }

    geosmooth.symbols <- c(
        "fit.lps", "fit.ps.lps", "fit.metric.graph.lowpass",
        "fit.chart.kernel", "fit.local.likelihood",
        "lps.grouped.foldid", "lps.nested.cv",
        "dgp.materialize", "dgp.content.sha256"
    )
    for (sym in geosmooth.symbols) {
        add("geosmooth", sym, TRUE, exists(sym, mode = "function"),
            "package contract")
    }

    if (isTRUE(check.gflow)) {
        gflow.available <- suppressPackageStartupMessages(suppressWarnings(
            requireNamespace("gflow", quietly = TRUE)
        ))
        gflow.namespace <- if (isTRUE(gflow.available)) {
            suppressPackageStartupMessages(suppressWarnings(asNamespace("gflow")))
        } else {
            NULL
        }
        gflow.symbols <- c(
            "compute.basins.of.attraction", "compute.gfc",
            "expand.basins.to.cover", "create.basin.cx"
        )
        for (sym in gflow.symbols) {
            add(
                "gflow", sym, FALSE,
                gflow.available && exists(sym, envir = gflow.namespace,
                                          mode = "function", inherits = FALSE),
                "optional OD4b benchmark dependency"
            )
        }
    }

    out <- do.call(rbind, rows)
    rownames(out) <- NULL
    if (isTRUE(fail)) {
        missing.required <- out$required & !out$available
        if (any(missing.required)) {
            stop("Missing required density dependencies: ",
                 paste(out$symbol[missing.required], collapse = ", "),
                 call. = FALSE)
        }
    }
    out
}

.state.density.fit.subject.od.visit.cv <- function(X,
                                                   subject.index,
                                                   method,
                                                   graph = NULL,
                                                   graph.control = list(),
                                                   od.control = list(),
                                                   return.details = TRUE,
                                                   visit.foldid = NULL,
                                                   visit.cv.folds = 5L,
                                                   visit.cv.seed = 1L,
                                                   visit.cv.epsilon = 1e-15,
                                                   dots = list()) {
    supported <- c("graph_random_walk", "chart_kernel", "local_likelihood_density",
                   "lps_count", "lps_logistic_binary", "ps_lps_count",
                   "local_likelihood_bernoulli")
    if (!method %in% supported) {
        stop(
            "OD-level visit CV is currently implemented for methods: ",
            paste(supported, collapse = ", "), ".",
            call. = FALSE
        )
    }
    if ("foldid" %in% names(dots)) {
        stop(
            "OD-level visit CV uses 'visit.foldid'.  Do not pass row-level ",
            "'foldid' through ... when od.cv = \"visit\".",
            call. = FALSE
        )
    }
    visit.cv.epsilon <- .local.chart.validate.positive.scalar(
        visit.cv.epsilon, "visit.cv.epsilon"
    )
    visit.foldid <- .state.density.prepare.visit.foldid(
        n.visits = length(subject.index),
        visit.foldid = visit.foldid,
        visit.cv.folds = visit.cv.folds,
        visit.cv.seed = visit.cv.seed
    )
    candidate.spec <- .state.density.visit.cv.candidates(
        method = method,
        dots = dots,
        graph.control = graph.control,
        n = nrow(X)
    )
    cv.result <- .state.density.visit.cv.table(
        X = X,
        subject.index = subject.index,
        method = method,
        graph = graph,
        graph.control = graph.control,
        od.control = od.control,
        foldid = visit.foldid,
        candidates = candidate.spec$candidates,
        base.dots = candidate.spec$base.dots,
        epsilon = visit.cv.epsilon
    )
    best.idx <- .local.chart.select.best.idx(
        cv.result$cv.table,
        score.column = "visit.cv.neg.log.rho"
    )
    selected <- cv.result$cv.table[best.idx, , drop = FALSE]
    selected.scalar <- .state.density.visit.cv.scalar.candidate(
        method,
        selected
    )
    final.dots <- c(candidate.spec$base.dots, selected.scalar$dots)
    final.graph.control <- utils::modifyList(
        graph.control,
        selected.scalar$graph.control
    )
    final <- do.call(
        fit.subject.od,
        c(
            list(
                X = X,
                subject.index = subject.index,
                method = method,
                graph = graph,
                graph.control = final.graph.control,
                od.control = od.control,
                return.details = return.details,
                od.cv = "none"
            ),
            final.dots
        )
    )
    final$theta$od.cv <- "visit"
    final$theta$visit.cv.score <- "visit.cv.neg.log.rho"
    final$theta$visit.cv.epsilon <- visit.cv.epsilon
    final$diagnostics$od.visit.cv <- list(
        mode = "visit",
        score = "negative_log_heldout_mass",
        score.column = "visit.cv.neg.log.rho",
        selected.candidate.id = selected$candidate.id[[1L]],
        n.visits = length(subject.index),
        n.folds = length(unique(visit.foldid)),
        epsilon = visit.cv.epsilon
    )
    final$diagnostics$od.visit.cv.selection <- as.list(selected[1, ])
    if (isTRUE(return.details)) {
        final$visit.cv.table <- cv.result$cv.table
        final$visit.foldid <- visit.foldid
        final$visit.cv.predicted.mass <- cv.result$predicted.mass
    }
    final
}

.state.density.prepare.visit.foldid <- function(n.visits,
                                                visit.foldid = NULL,
                                                visit.cv.folds = 5L,
                                                visit.cv.seed = 1L) {
    if (n.visits < 2L) {
        stop("OD-level visit CV requires at least two subject visits.",
             call. = FALSE)
    }
    if (!is.null(visit.foldid) &&
        (!is.numeric(visit.foldid) || length(visit.foldid) != n.visits)) {
        stop("'visit.foldid' must be a positive integer vector with length ",
             "length(subject.index).", call. = FALSE)
    }
    .klp.prepare.foldid(
        n = n.visits,
        foldid = visit.foldid,
        cv.folds = visit.cv.folds,
        cv.seed = visit.cv.seed
    )
}

.state.density.visit.cv.candidates <- function(method,
                                               dots,
                                               graph.control = list(),
                                               n) {
    switch(
        method,
        graph_random_walk =
            .state.density.visit.cv.graph.random.walk.candidates(
                dots = dots,
                graph.control = graph.control
            ),
        chart_kernel = .state.density.visit.cv.chart.kernel.candidates(
            dots = dots,
            n = n
        ),
        lps_count = .state.density.visit.cv.lps.candidates(
            dots = dots,
            n = n
        ),
        lps_logistic_binary = .state.density.visit.cv.lps.candidates(
            dots = dots,
            n = n
        ),
        ps_lps_count = .state.density.visit.cv.ps.lps.candidates(
            dots = dots,
            n = n
        ),
        local_likelihood_density =
            .state.density.visit.cv.local.likelihood.candidates(
                dots = dots,
                n = n
            ),
        local_likelihood_bernoulli =
            .state.density.visit.cv.local.likelihood.candidates(
                dots = dots,
                n = n
            ),
        stop("Unsupported OD-level visit CV method.", call. = FALSE)
    )
}

.state.density.visit.cv.graph.random.walk.candidates <- function(dots,
                                                                  graph.control) {
    if (length(dots)) {
        stop("OD-level visit CV for 'graph_random_walk' takes candidate ",
             "grids through 'graph.control', not through ....",
             call. = FALSE)
    }
    if (is.null(graph.control)) {
        graph.control <- list()
    }
    if (!is.list(graph.control)) {
        stop("'graph.control' must be a list.", call. = FALSE)
    }
    walk.step.grid <- .state.density.graph.control.value(
        graph.control,
        c("walk.step.grid", "walk_step_grid", "walk.steps.grid",
          "walk_steps_grid"),
        NULL
    )
    if (is.null(walk.step.grid)) {
        walk.step.grid <- .state.density.walk.steps(graph.control)
    }
    walk.step.grid <- .state.density.clean.walk.step.grid(walk.step.grid)
    affinity.method <- .state.density.graph.control.value(
        graph.control, c("affinity.method", "affinity_method"),
        "exp_neg_length_over_median"
    )
    affinity.method.grid <- .state.density.graph.control.value(
        graph.control, c("affinity.method.grid", "affinity_method_grid"),
        affinity.method
    )
    affinity.method.grid <- .state.density.clean.affinity.method.grid(
        affinity.method.grid
    )
    affinity.scale <- .state.density.graph.control.value(
        graph.control, c("affinity.scale", "affinity_scale"), NA_real_
    )
    affinity.scale.grid <- .state.density.graph.control.value(
        graph.control, c("affinity.scale.grid", "affinity_scale_grid"),
        affinity.scale
    )
    affinity.scale.grid <- .state.density.clean.affinity.scale.grid(
        affinity.scale.grid
    )
    affinity.epsilon <- .state.density.graph.control.value(
        graph.control, c("affinity.epsilon", "affinity_epsilon"), 1e-12
    )
    affinity.epsilon.grid <- .state.density.graph.control.value(
        graph.control, c("affinity.epsilon.grid", "affinity_epsilon_grid"),
        affinity.epsilon
    )
    affinity.epsilon.grid <- .state.density.clean.affinity.epsilon.grid(
        affinity.epsilon.grid
    )
    normalize <- .state.density.graph.control.value(
        graph.control, c("normalize"), TRUE
    )
    normalize.grid <- .state.density.graph.control.value(
        graph.control, c("normalize.grid"), normalize
    )
    normalize.grid <- .state.density.clean.logical.grid(
        normalize.grid,
        "graph.control$normalize.grid"
    )
    candidates <- expand.grid(
        walk.step = walk.step.grid,
        affinity.method = affinity.method.grid,
        affinity.scale = affinity.scale.grid,
        affinity.epsilon = affinity.epsilon.grid,
        normalize = normalize.grid,
        KEEP.OUT.ATTRS = FALSE,
        stringsAsFactors = FALSE
    )
    inverse <- candidates$affinity.method == "inverse_length"
    if (any(inverse)) {
        candidates$affinity.scale[inverse] <- NA_real_
    }
    candidates <- unique(candidates)
    candidates$candidate.id <- seq_len(nrow(candidates))
    list(
        candidates = candidates[, c("candidate.id", "walk.step",
                                    "affinity.method", "affinity.scale",
                                    "affinity.epsilon", "normalize")],
        base.dots = list()
    )
}

.state.density.clean.walk.step.grid <- function(x) {
    if (!is.numeric(x) || length(x) < 1L || any(!is.finite(x)) ||
        any(x < 0) || any(x != floor(x))) {
        stop("'walk.step.grid' must contain nonnegative integer values.",
             call. = FALSE)
    }
    sort(unique(as.integer(x)))
}

.state.density.clean.affinity.method.grid <- function(x) {
    if (!is.character(x) || length(x) < 1L || any(!nzchar(x))) {
        stop("'affinity.method.grid' must contain affinity method names.",
             call. = FALSE)
    }
    allowed <- c("exp_neg_length_over_median", "inverse_length")
    bad <- setdiff(x, allowed)
    if (length(bad)) {
        stop("'affinity.method.grid' contains unsupported value(s): ",
             paste(bad, collapse = ", "), ".", call. = FALSE)
    }
    unique(x)
}

.state.density.clean.affinity.scale.grid <- function(x) {
    if (is.null(x)) {
        return(NA_real_)
    }
    x <- as.numeric(x)
    if (!length(x) || any(is.nan(x)) ||
        any(!is.na(x) & (!is.finite(x) | x <= 0))) {
        stop("'affinity.scale.grid' must contain positive finite values ",
             "or NA for the data-derived scale.", call. = FALSE)
    }
    unique(x)
}

.state.density.clean.affinity.epsilon.grid <- function(x) {
    x <- as.numeric(x)
    if (!length(x) || any(!is.finite(x)) || any(x <= 0)) {
        stop("'affinity.epsilon.grid' must contain positive finite values.",
             call. = FALSE)
    }
    sort(unique(x))
}

.state.density.clean.logical.grid <- function(x, name) {
    if (!is.logical(x) && !is.numeric(x)) {
        stop(name, " must contain logical values.", call. = FALSE)
    }
    x <- as.logical(x)
    if (!length(x) || anyNA(x)) {
        stop(name, " must contain non-missing logical values.", call. = FALSE)
    }
    unique(x)
}

.state.density.visit.cv.lps.candidates <- function(dots, n) {
    support.grid <- .state.density.null.coalesce(
        dots$support.grid, c(10L, 15L, 20L)
    )
    degree.grid <- .state.density.null.coalesce(dots$degree.grid, 0:2)
    kernel.grid <- .state.density.null.coalesce(
        dots$kernel.grid, c("gaussian", "tricube")
    )
    bandwidth.multiplier.grid <- .state.density.null.coalesce(
        dots$bandwidth.multiplier.grid, 1
    )
    chart.dim.grid <- .local.chart.clean.chart.dim.grid(
        dots$chart.dim.grid,
        chart.dim = dots$chart.dim
    )
    candidates <- expand.grid(
        support.size = .klp.clean.support.grid(support.grid, n),
        degree = .klp.clean.degree.grid(degree.grid),
        kernel = .klp.clean.kernel.grid(kernel.grid),
        bandwidth.multiplier =
            .klp.clean.bandwidth.multiplier.grid(bandwidth.multiplier.grid),
        chart.dim = chart.dim.grid$chart.dim,
        KEEP.OUT.ATTRS = FALSE,
        stringsAsFactors = FALSE
    )
    candidates$chart.dim.rank <- chart.dim.grid$chart.dim.rank[
        match(candidates$chart.dim, chart.dim.grid$chart.dim)
    ]
    candidates$candidate.id <- seq_len(nrow(candidates))
    list(
        candidates = candidates[, c("candidate.id", "support.size", "degree",
                                    "kernel", "bandwidth.multiplier",
                                    "chart.dim", "chart.dim.rank")],
        base.dots = .state.density.drop.dots(
            dots,
            c("support.grid", "degree.grid", "kernel.grid",
              "bandwidth.multiplier.grid", "chart.dim", "chart.dim.grid",
              "cv.folds", "cv.seed")
        )
    )
}

.state.density.visit.cv.ps.lps.candidates <- function(dots, n) {
    if (is.null(dots$chart.dim) && is.null(dots$chart.dim.grid)) {
        stop("OD-level visit CV for 'ps_lps_count' requires 'chart.dim' ",
             "or 'chart.dim.grid'.", call. = FALSE)
    }
    support.size <- .state.density.null.coalesce(dots$support.size, NULL)
    support.grid <- .state.density.null.coalesce(
        dots$support.grid,
        .state.density.null.coalesce(support.size, c(10L, 15L, 20L))
    )
    degree <- .state.density.null.coalesce(dots$degree, 2L)
    degree.grid <- .state.density.null.coalesce(dots$degree.grid, degree)
    kernel <- .state.density.null.coalesce(dots$kernel, "gaussian")
    kernel.grid <- .state.density.null.coalesce(dots$kernel.grid, kernel)
    lambda.sync.grid <- .state.density.null.coalesce(
        dots$lambda.sync.grid, c(0, 1e-3, 1e-2, 1e-1, 1, 10)
    )
    lambda.sync.grid <- sort(unique(as.numeric(lambda.sync.grid)))
    if (!length(lambda.sync.grid) || any(!is.finite(lambda.sync.grid)) ||
        any(lambda.sync.grid < 0)) {
        stop("'lambda.sync.grid' must contain finite nonnegative values.",
             call. = FALSE)
    }
    chart.dim.grid <- .local.chart.clean.chart.dim.grid(
        dots$chart.dim.grid,
        chart.dim = dots$chart.dim
    )
    candidates <- expand.grid(
        support.size = .klp.clean.support.grid(support.grid, n),
        degree = .klp.clean.degree.grid(degree.grid),
        kernel = .klp.clean.kernel.grid(kernel.grid),
        lambda.sync = lambda.sync.grid,
        chart.dim = chart.dim.grid$chart.dim,
        KEEP.OUT.ATTRS = FALSE,
        stringsAsFactors = FALSE
    )
    candidates$chart.dim.rank <- chart.dim.grid$chart.dim.rank[
        match(candidates$chart.dim, chart.dim.grid$chart.dim)
    ]
    candidates$candidate.id <- seq_len(nrow(candidates))
    list(
        candidates = candidates[, c("candidate.id", "support.size", "degree",
                                    "kernel", "lambda.sync", "chart.dim",
                                    "chart.dim.rank")],
        base.dots = .state.density.drop.dots(
            dots,
            c("support.size", "support.grid", "degree", "degree.grid",
              "kernel", "kernel.grid", "lambda.sync.grid",
              "lambda.sync.search", "local.candidate.search",
              "chart.dim", "chart.dim.grid", "cv.folds", "cv.seed")
        )
    )
}

.state.density.visit.cv.chart.kernel.candidates <- function(dots, n) {
    support.size <- .state.density.null.coalesce(
        dots$support.size, min(15L, n)
    )
    support.grid <- .state.density.null.coalesce(
        dots$support.grid, support.size
    )
    kernel <- .state.density.null.coalesce(dots$kernel, "gaussian")
    kernel.grid <- .state.density.null.coalesce(dots$kernel.grid, kernel)
    bandwidth.multiplier <- .state.density.null.coalesce(
        dots$bandwidth.multiplier, 1
    )
    bandwidth.multiplier.grid <- .state.density.null.coalesce(
        dots$bandwidth.multiplier.grid, bandwidth.multiplier
    )
    chart.dim.grid <- .local.chart.clean.chart.dim.grid(
        dots$chart.dim.grid,
        chart.dim = dots$chart.dim
    )
    candidates <- expand.grid(
        support.size = .klp.clean.support.grid(support.grid, n),
        kernel = .klp.clean.kernel.grid(kernel.grid),
        bandwidth.multiplier =
            .klp.clean.bandwidth.multiplier.grid(bandwidth.multiplier.grid),
        chart.dim = chart.dim.grid$chart.dim,
        KEEP.OUT.ATTRS = FALSE,
        stringsAsFactors = FALSE
    )
    candidates$chart.dim.rank <- chart.dim.grid$chart.dim.rank[
        match(candidates$chart.dim, chart.dim.grid$chart.dim)
    ]
    candidates$candidate.id <- seq_len(nrow(candidates))
    list(
        candidates = candidates[, c("candidate.id", "support.size", "kernel",
                                    "bandwidth.multiplier", "chart.dim",
                                    "chart.dim.rank")],
        base.dots = .state.density.drop.dots(
            dots,
            c("support.size", "support.grid", "kernel", "kernel.grid",
              "bandwidth.multiplier", "bandwidth.multiplier.grid",
              "chart.dim", "chart.dim.grid", "cv.folds", "cv.seed")
        )
    )
}

.state.density.visit.cv.local.likelihood.candidates <- function(dots, n) {
    support.size <- .state.density.null.coalesce(
        dots$support.size, min(15L, n)
    )
    support.grid <- .state.density.null.coalesce(
        dots$support.grid, support.size
    )
    degree <- .state.density.null.coalesce(dots$degree, 1L)
    degree.grid <- .state.density.null.coalesce(dots$degree.grid, degree)
    kernel <- .state.density.null.coalesce(dots$kernel, "gaussian")
    kernel.grid <- .state.density.null.coalesce(dots$kernel.grid, kernel)
    bandwidth.multiplier <- .state.density.null.coalesce(
        dots$bandwidth.multiplier, 1
    )
    bandwidth.multiplier.grid <- .state.density.null.coalesce(
        dots$bandwidth.multiplier.grid, bandwidth.multiplier
    )
    lambda.ridge <- .state.density.null.coalesce(dots$lambda.ridge, 1e-8)
    lambda.ridge.grid <- .state.density.null.coalesce(
        dots$lambda.ridge.grid, lambda.ridge
    )
    chart.dim.grid <- .local.chart.clean.chart.dim.grid(
        dots$chart.dim.grid,
        chart.dim = dots$chart.dim
    )
    candidates <- expand.grid(
        support.size = .klp.clean.support.grid(support.grid, n),
        degree = .klp.clean.degree.grid(degree.grid),
        kernel = .klp.clean.kernel.grid(kernel.grid),
        bandwidth.multiplier =
            .klp.clean.bandwidth.multiplier.grid(bandwidth.multiplier.grid),
        lambda.ridge =
            .local.likelihood.clean.lambda.ridge.grid(lambda.ridge.grid),
        chart.dim = chart.dim.grid$chart.dim,
        KEEP.OUT.ATTRS = FALSE,
        stringsAsFactors = FALSE
    )
    candidates$chart.dim.rank <- chart.dim.grid$chart.dim.rank[
        match(candidates$chart.dim, chart.dim.grid$chart.dim)
    ]
    candidates$candidate.id <- seq_len(nrow(candidates))
    list(
        candidates = candidates[, c("candidate.id", "support.size", "degree",
                                    "kernel", "bandwidth.multiplier",
                                    "lambda.ridge", "chart.dim",
                                    "chart.dim.rank")],
        base.dots = .state.density.drop.dots(
            dots,
            c("support.size", "support.grid", "degree", "degree.grid",
              "kernel", "kernel.grid", "bandwidth.multiplier",
              "bandwidth.multiplier.grid", "lambda.ridge",
              "lambda.ridge.grid", "chart.dim", "chart.dim.grid",
              "cv.folds", "cv.seed")
        )
    )
}

.state.density.visit.cv.table <- function(X,
                                          subject.index,
                                          method,
                                          graph,
                                          graph.control,
                                          od.control,
                                          foldid,
                                          candidates,
                                          base.dots,
                                          epsilon) {
    n.visits <- length(subject.index)
    predicted <- matrix(NA_real_, nrow = n.visits, ncol = nrow(candidates))
    error.messages <- rep(NA_character_, nrow(candidates))
    for (cc in seq_len(nrow(candidates))) {
        cand.scalar <- .state.density.visit.cv.scalar.candidate(
            method,
            candidates[cc, , drop = FALSE]
        )
        cand.graph.control <- utils::modifyList(
            graph.control,
            cand.scalar$graph.control
        )
        for (fold in sort(unique(foldid))) {
            test.pos <- which(foldid == fold)
            train.pos <- which(foldid != fold)
            fit <- tryCatch(
                do.call(
                    fit.subject.od,
                    c(
                        list(
                            X = X,
                            subject.index = subject.index[train.pos],
                            method = method,
                            graph = graph,
                            graph.control = cand.graph.control,
                            od.control = od.control,
                            return.details = FALSE,
                            od.cv = "none"
                        ),
                        base.dots,
                        cand.scalar$dots
                    )
                ),
                error = function(e) e
            )
            if (inherits(fit, "error")) {
                error.messages[[cc]] <- conditionMessage(fit)
                predicted[test.pos, cc] <- NA_real_
                next
            }
            predicted[test.pos, cc] <- fit$rho[subject.index[test.pos]]
        }
    }
    score <- apply(
        predicted,
        2L,
        function(x) {
            if (any(!is.finite(x))) {
                return(Inf)
            }
            -mean(log(pmax(x, epsilon)))
        }
    )
    nonfinite.count <- colSums(!is.finite(predicted))
    mean.heldout.mass <- vapply(
        seq_len(ncol(predicted)),
        function(j) {
            if (nonfinite.count[[j]] > 0L) {
                return(NA_real_)
            }
            mean(predicted[, j])
        },
        numeric(1L)
    )
    zero.count <- colSums(is.finite(predicted) & predicted <= 0)
    cv.table <- candidates
    cv.table$visit.cv.neg.log.rho <- score
    cv.table$visit.cv.mean.heldout.rho <- mean.heldout.mass
    cv.table$visit.cv.nonfinite.count <- as.integer(nonfinite.count)
    cv.table$visit.cv.zero.count <- as.integer(zero.count)
    cv.table$visit.cv.status <- ifelse(
        is.finite(score) & nonfinite.count == 0L, "ok", "failed"
    )
    cv.table$visit.cv.error.message <- error.messages
    list(cv.table = cv.table, predicted.mass = predicted)
}

.state.density.visit.cv.scalar.candidate <- function(method, candidate) {
    if (identical(method, "graph_random_walk")) {
        return(list(
            dots = list(),
            graph.control =
                .state.density.visit.cv.scalar.graph.control(candidate)
        ))
    }
    list(
        dots = .state.density.visit.cv.scalar.candidate.dots(
            method,
            candidate
        ),
        graph.control = list()
    )
}

.state.density.visit.cv.scalar.graph.control <- function(candidate) {
    walk.step <- as.integer(candidate$walk.step[[1L]])
    if (!is.finite(walk.step) || walk.step < 0L) {
        stop("Internal graph random-walk candidate has invalid walk.step.",
             call. = FALSE)
    }
    graph.control <- list(
        walk.steps = sort(unique(as.integer(c(0L, walk.step)))),
        affinity.method = as.character(candidate$affinity.method[[1L]]),
        affinity.epsilon = as.numeric(candidate$affinity.epsilon[[1L]]),
        normalize = as.logical(candidate$normalize[[1L]])
    )
    affinity.scale <- as.numeric(candidate$affinity.scale[[1L]])
    if (is.finite(affinity.scale)) {
        graph.control$affinity.scale <- affinity.scale
    }
    graph.control
}

.state.density.visit.cv.scalar.candidate.dots <- function(method, candidate) {
    names.to.keep <- switch(
        method,
        chart_kernel = c("support.size", "kernel", "bandwidth.multiplier",
                         "chart.dim"),
        lps_count = c("support.size", "degree", "kernel",
                      "bandwidth.multiplier", "chart.dim"),
        lps_logistic_binary = c("support.size", "degree", "kernel",
                                "bandwidth.multiplier", "chart.dim"),
        ps_lps_count = c("support.size", "degree", "kernel",
                         "lambda.sync", "chart.dim"),
        local_likelihood_density = c(
            "support.size", "degree", "kernel", "bandwidth.multiplier",
            "lambda.ridge", "chart.dim"
        ),
        local_likelihood_bernoulli = c(
            "support.size", "degree", "kernel", "bandwidth.multiplier",
            "lambda.ridge", "chart.dim"
        ),
        character(0)
    )
    names.to.keep <- intersect(names.to.keep, names(candidate))
    out <- as.list(candidate[1, names.to.keep, drop = FALSE])
    if ("support.size" %in% names(out)) {
        out$support.size <- as.integer(out$support.size)
    }
    if ("degree" %in% names(out)) {
        out$degree <- as.integer(out$degree)
    }
    if ("chart.dim" %in% names(out)) {
        decoded <- .local.chart.decode.chart.dim(out$chart.dim)
        if (is.null(decoded)) {
            out$chart.dim <- NULL
        } else {
            out$chart.dim <- decoded
        }
    }
    if (method %in% c("lps_count", "lps_logistic_binary")) {
        if ("support.size" %in% names(out)) {
            out$support.grid <- out$support.size
            out$support.size <- NULL
        }
        if ("degree" %in% names(out)) {
            out$degree.grid <- out$degree
            out$degree <- NULL
        }
        if ("kernel" %in% names(out)) {
            out$kernel.grid <- out$kernel
            out$kernel <- NULL
        }
        if ("bandwidth.multiplier" %in% names(out)) {
            out$bandwidth.multiplier.grid <- out$bandwidth.multiplier
            out$bandwidth.multiplier <- NULL
        }
    } else if (identical(method, "ps_lps_count")) {
        if ("lambda.sync" %in% names(out)) {
            out$lambda.sync.grid <- out$lambda.sync
            out$lambda.sync <- NULL
        }
        out$lambda.sync.search <- "grid"
        out$local.candidate.search <- "full"
    }
    out
}

.state.density.drop.dots <- function(dots, names.to.drop) {
    dots[setdiff(names(dots), names.to.drop)]
}

.state.density.fit.subject.smoother.od <- function(X,
                                                   weights,
                                                   method,
                                                   graph = NULL,
                                                   od.control = list(),
                                                   return.details = TRUE,
                                                   ...) {
    empirical <- .state.density.normalize.weights(weights)
    binary <- as.numeric(weights > 0)
    smoothness.adj.list <- .state.density.optional.graph.adj.list(
        graph = graph,
        n = nrow(X)
    )
    if (method %in% c("local_likelihood_density",
                      "local_likelihood_bernoulli")) {
        dots <- .state.density.named.dots(...)
        .state.density.reject.reserved.dots(
            dots,
            reserved = c("likelihood.family"),
            context = paste0("fit.subject.od(method = \"", method, "\")")
        )
    }
    switch(
        method,
        lps_count = .state.density.fit.lps.od(
            X = X,
            response = empirical,
            empirical = empirical,
            method.id = "lps_count",
            response.type = "normalized_count_mass",
            outcome.family = "gaussian",
            adj.list = smoothness.adj.list,
            od.control = od.control,
            return.details = return.details,
            ...
        ),
        lps_logistic_binary = .state.density.fit.lps.od(
            X = X,
            response = binary,
            empirical = empirical,
            method.id = "lps_logistic_binary",
            response.type = "binary_visit_indicator",
            outcome.family = "bernoulli",
            adj.list = smoothness.adj.list,
            od.control = od.control,
            return.details = return.details,
            ...
        ),
        ps_lps_count = .state.density.fit.ps.lps.od(
            X = X,
            response = empirical,
            empirical = empirical,
            method.id = "ps_lps_count",
            response.type = "normalized_count_mass",
            adj.list = smoothness.adj.list,
            od.control = od.control,
            return.details = return.details,
            ...
        ),
        chart_kernel = .state.density.fit.chart.kernel.od(
            X = X,
            response = empirical,
            empirical = empirical,
            method.id = "chart_kernel",
            response.type = "normalized_count_mass",
            adj.list = smoothness.adj.list,
            od.control = od.control,
            return.details = return.details,
            ...
        ),
        local_likelihood_density = .state.density.fit.local.likelihood.od(
            X = X,
            response = empirical,
            empirical = empirical,
            method.id = "local_likelihood_density",
            response.type = "normalized_count_mass",
            likelihood.family = "density",
            adj.list = smoothness.adj.list,
            od.control = od.control,
            return.details = return.details,
            ...
        ),
        local_likelihood_bernoulli = .state.density.fit.local.likelihood.od(
            X = X,
            response = binary,
            empirical = empirical,
            method.id = "local_likelihood_bernoulli",
            response.type = "binary_visit_indicator",
            likelihood.family = "bernoulli",
            adj.list = smoothness.adj.list,
            od.control = od.control,
            return.details = return.details,
            ...
        )
    )
}

.state.density.fit.lps.od <- function(X,
                                      response,
                                      empirical,
                                      method.id,
                                      response.type,
                                      outcome.family,
                                      adj.list = NULL,
                                      od.control = list(),
                                      return.details = TRUE,
                                      ...) {
    dots <- .state.density.named.dots(...)
    .state.density.reject.reserved.dots(
        dots,
        reserved = c("X", "y", "outcome.family"),
        context = paste0("fit.subject.od(method = \"", method.id, "\")")
    )
    fit <- do.call(
        fit.lps,
        c(list(X = X, y = response, outcome.family = outcome.family), dots)
    )
    out <- normalize.density(
        fit,
        X = X,
        density.control = od.control,
        method.id = method.id,
        keep.source.fit = return.details,
        adj.list = adj.list,
        empirical.rho = empirical,
        return.details = return.details
    )
    .state.density.decorate.smoother.od(
        out = out,
        empirical = empirical,
        method.id = method.id,
        source.method = "fit.lps",
        response = response,
        response.type = response.type,
        source.fit = fit,
        return.details = return.details
    )
}

.state.density.fit.ps.lps.od <- function(X,
                                         response,
                                         empirical,
                                         method.id,
                                         response.type,
                                         adj.list = NULL,
                                         od.control = list(),
                                         return.details = TRUE,
                                         ...) {
    dots <- .state.density.named.dots(...)
    .state.density.reject.reserved.dots(
        dots,
        reserved = c("X", "y"),
        context = paste0("fit.subject.od(method = \"", method.id, "\")")
    )
    fit <- do.call(fit.ps.lps, c(list(X = X, y = response), dots))
    out <- normalize.density(
        fit,
        X = X,
        density.control = od.control,
        method.id = method.id,
        keep.source.fit = return.details,
        adj.list = adj.list,
        empirical.rho = empirical,
        return.details = return.details
    )
    .state.density.decorate.smoother.od(
        out = out,
        empirical = empirical,
        method.id = method.id,
        source.method = "fit.ps.lps",
        response = response,
        response.type = response.type,
        source.fit = fit,
        return.details = return.details
    )
}

.state.density.fit.chart.kernel.od <- function(X,
                                               response,
                                               empirical,
                                               method.id,
                                               response.type,
                                               adj.list = NULL,
                                               od.control = list(),
                                               return.details = TRUE,
                                               ...) {
    dots <- .state.density.named.dots(...)
    .state.density.reject.reserved.dots(
        dots,
        reserved = c("X", "y"),
        context = paste0("fit.subject.od(method = \"", method.id, "\")")
    )
    fit <- do.call(fit.chart.kernel, c(list(X = X, y = response), dots))
    fit$empirical.rho <- empirical
    out <- normalize.density(
        fit,
        X = X,
        density.control = od.control,
        method.id = method.id,
        keep.source.fit = return.details,
        adj.list = adj.list,
        empirical.rho = empirical,
        return.details = return.details
    )
    .state.density.decorate.smoother.od(
        out = out,
        empirical = empirical,
        method.id = method.id,
        source.method = "fit.chart.kernel",
        response = response,
        response.type = response.type,
        source.fit = fit,
        return.details = return.details
    )
}

.state.density.fit.local.likelihood.od <- function(X,
                                                   response,
                                                   empirical,
                                                   method.id,
                                                   response.type,
                                                   likelihood.family,
                                                   adj.list = NULL,
                                                   od.control = list(),
                                                   return.details = TRUE,
                                                   ...) {
    dots <- .state.density.named.dots(...)
    .state.density.reject.reserved.dots(
        dots,
        reserved = c("X", "y", "likelihood.family"),
        context = paste0("fit.subject.od(method = \"", method.id, "\")")
    )
    fit <- do.call(
        fit.local.likelihood,
        c(
            list(
                X = X,
                y = response,
                likelihood.family = likelihood.family
            ),
            dots
        )
    )
    fit$empirical.rho <- empirical
    out <- normalize.density(
        fit,
        X = X,
        density.control = od.control,
        method.id = method.id,
        keep.source.fit = return.details,
        adj.list = adj.list,
        empirical.rho = empirical,
        return.details = return.details
    )
    .state.density.decorate.smoother.od(
        out = out,
        empirical = empirical,
        method.id = method.id,
        source.method = "fit.local.likelihood",
        response = response,
        response.type = response.type,
        source.fit = fit,
        return.details = return.details
    )
}

.state.density.decorate.smoother.od <- function(out,
                                                empirical,
                                                method.id,
                                                source.method,
                                                response,
                                                response.type,
                                                source.fit,
                                                return.details = TRUE) {
    out$empirical.rho <- empirical
    out$theta$od.workflow <- method.id
    out$theta$source.method <- source.method
    out$theta$response.type <- response.type
    out$diagnostics$od.workflow <- method.id
    out$diagnostics$source.method <- source.method
    out$diagnostics$response.summary <- list(
        type = response.type,
        sum = sum(response),
        min = min(response),
        max = max(response),
        nonzero = sum(response != 0)
    )
    if (inherits(source.fit, "lps")) {
        out$diagnostics$selection <- source.fit$selected
        out$diagnostics$outcome.family <- source.fit$outcome.family
        out$diagnostics$probability.diagnostics <-
            source.fit$probability.diagnostics
        out$diagnostics$logistic.diagnostics <-
            source.fit$logistic.diagnostics
        if (identical(method.id, "lps_logistic_binary") &&
            identical(source.fit$outcome.family, "bernoulli")) {
            out$diagnostics$binary.workflow <- list(
                method.id = method.id,
                implementation.family = "bernoulli",
                probability.link = "identity_lps_least_squares_clipped",
                density.adapter = "normalize.density_clip_and_renormalize",
                note = paste(
                    "Historical method id; this OD workflow uses",
                    "fit.lps(..., outcome.family = \"bernoulli\"), not the",
                    "outcome.family = \"binomial\" local-logistic IRLS path."
                )
            )
        }
    } else if (inherits(source.fit, "ps_lps")) {
        out$diagnostics$selection <- source.fit$selected
        out$diagnostics$sync.energy <- source.fit$sync.energy
        out$diagnostics$mean.sync.squared.disagreement <-
            source.fit$mean.sync.squared.disagreement
        out$diagnostics$lambda.sync.search.telemetry <-
            source.fit$lambda.sync.search.telemetry
        out$diagnostics$lambda.search.summary <-
            source.fit$lambda.search.summary
    } else if (inherits(source.fit, "chart_kernel")) {
        out$diagnostics$selection <- source.fit$selected
        out$diagnostics$chart.kernel <- source.fit$diagnostics
    } else if (inherits(source.fit, "local_likelihood")) {
        out$diagnostics$selection <- source.fit$selected
        out$diagnostics$likelihood.family <- source.fit$likelihood.family
        out$diagnostics$local.likelihood <- source.fit$diagnostics
    }
    if (!isTRUE(return.details)) {
        out$diagnostics <- list()
    }
    out
}

.state.density.named.dots <- function(...) {
    dots <- list(...)
    if (!length(dots)) {
        return(dots)
    }
    dot.names <- names(dots)
    if (is.null(dot.names) || any(!nzchar(dot.names))) {
        stop("OD smoother workflow arguments passed through ... must be named.",
             call. = FALSE)
    }
    dots
}

.state.density.reject.reserved.dots <- function(dots, reserved, context) {
    duplicated <- intersect(names(dots), reserved)
    if (length(duplicated)) {
        stop(
            context, " controls reserved argument(s): ",
            paste(duplicated, collapse = ", "),
            ". Supply only method-specific tuning controls through ....",
            call. = FALSE
        )
    }
    invisible(NULL)
}

.state.density.reject.chart.dots <- function(dots, context) {
    chart.args <- intersect(names(dots), c("chart.dim", "chart.dim.grid"))
    if (length(chart.args)) {
        stop(
            context, " does not use local charts; unsupported argument(s): ",
            paste(chart.args, collapse = ", "),
            ". Use chart-dimension controls only with chart-based OD methods.",
            call. = FALSE
        )
    }
    invisible(NULL)
}

.state.density.chart.dim.telemetry <- function(source.fit, n = NULL) {
    if (is.null(source.fit) || is.null(source.fit$diagnostics$chart.dim)) {
        return(NULL)
    }
    telemetry <- source.fit$diagnostics$chart.dim
    dims <- as.integer(telemetry$by.anchor)
    if (!length(dims) || anyNA(dims) || any(dims < 1L) ||
        (!is.null(n) && length(dims) != n)) {
        return(NULL)
    }
    telemetry$by.anchor <- dims
    telemetry
}

.state.density.attach.subject <- function(out, subject.index, weights) {
    out$subject <- list(
        n.visits = length(subject.index),
        n.unique.visited = sum(weights > 0),
        max.multiplicity = max(weights),
        repeat.fraction = if (sum(weights > 0) == 0) {
            NA_real_
        } else {
            sum(weights > 1) / sum(weights > 0)
        }
    )
    out
}

.state.density.optional.graph.adj.list <- function(graph, n) {
    if (is.null(graph)) {
        return(NULL)
    }
    .state.density.prepare.graph(
        graph = graph,
        n = n,
        allow.zero.length = TRUE
    )$adj.list
}

.state.density.control <- function(density.control = list()) {
    if (is.null(density.control)) {
        density.control <- list()
    }
    if (!is.list(density.control)) {
        stop("density.control must be a list.", call. = FALSE)
    }
    ctrl <- utils::modifyList(
        list(
            mass.tol = 1e-8,
            neg.tol = 1e-12,
            clip.negative = TRUE,
            renormalize = TRUE
        ),
        density.control
    )
    ctrl$mass.tol <- .state.density.validate.nonnegative.scalar(
        ctrl$mass.tol, "density.control$mass.tol"
    )
    ctrl$neg.tol <- .state.density.validate.nonnegative.scalar(
        ctrl$neg.tol, "density.control$neg.tol"
    )
    ctrl$clip.negative <- isTRUE(ctrl$clip.negative)
    ctrl$renormalize <- isTRUE(ctrl$renormalize)
    ctrl
}

.state.density.validate.nonnegative.scalar <- function(x, name) {
    if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < 0) {
        stop(name, " must be one finite nonnegative numeric value.", call. = FALSE)
    }
    as.numeric(x)
}

.state.density.validate.X <- function(X) {
    if (is.data.frame(X)) {
        X <- as.matrix(X)
    }
    if (is.null(dim(X))) {
        X <- matrix(X, ncol = 1L)
    }
    if (!is.matrix(X) || !is.numeric(X)) {
        stop("X must be a numeric matrix or coercible numeric vector.",
             call. = FALSE)
    }
    if (nrow(X) < 1L || ncol(X) < 1L) {
        stop("X must have at least one row and one column.", call. = FALSE)
    }
    if (any(!is.finite(X))) {
        stop("X contains non-finite values.", call. = FALSE)
    }
    X
}

.state.density.validate.weights <- function(weights, n, name) {
    if (is.null(weights)) {
        stop(name, " must be supplied.", call. = FALSE)
    }
    if (!is.numeric(weights) || length(weights) != n) {
        stop(name, " must be a numeric vector with length nrow(X).",
             call. = FALSE)
    }
    if (any(!is.finite(weights))) {
        stop(name, " contains non-finite values.", call. = FALSE)
    }
    if (any(weights < 0)) {
        stop(name, " must be nonnegative.", call. = FALSE)
    }
    if (sum(weights) <= 0) {
        stop(name, " must have positive total mass.", call. = FALSE)
    }
    as.numeric(weights)
}

.state.density.validate.binary <- function(binary, n, name) {
    if (is.null(binary)) {
        stop(name, " must be supplied.", call. = FALSE)
    }
    if (!is.numeric(binary) && !is.logical(binary)) {
        stop(name, " must be a numeric or logical 0/1 vector.", call. = FALSE)
    }
    binary <- as.numeric(binary)
    if (length(binary) != n || any(!is.finite(binary)) ||
        any(!binary %in% c(0, 1))) {
        stop(name, " must be a finite 0/1 vector with length nrow(X).",
             call. = FALSE)
    }
    binary
}

.state.density.validate.subject.index <- function(subject.index, n) {
    if (length(subject.index) < 1L) {
        stop("subject.index must contain at least one visit.", call. = FALSE)
    }
    if (!is.numeric(subject.index) && !is.integer(subject.index)) {
        stop("subject.index must be an integer vector.", call. = FALSE)
    }
    if (any(!is.finite(subject.index)) ||
        any(subject.index != as.integer(subject.index))) {
        stop("subject.index must contain integer row indices.", call. = FALSE)
    }
    subject.index <- as.integer(subject.index)
    if (any(subject.index < 1L | subject.index > n)) {
        stop("subject.index contains row indices outside 1:nrow(X).",
             call. = FALSE)
    }
    subject.index
}

.state.density.subject.weights <- function(subject.index, n) {
    as.numeric(tabulate(subject.index, nbins = n))
}

.state.density.normalize.weights <- function(weights) {
    weights / sum(weights)
}

.normalize.density.support <- function(X, n, source.fit = NULL) {
    if (!is.null(X)) {
        return(.state.density.validate.X(X))
    }
    if (!is.null(source.fit$X.eval)) {
        return(.state.density.validate.X(source.fit$X.eval))
    }
    if (!is.null(source.fit$X)) {
        return(.state.density.validate.X(source.fit$X))
    }
    matrix(seq_len(n), ncol = 1L)
}

.normalize.density.method.id <- function(source.fit, method.id) {
    if (!is.null(method.id)) {
        return(method.id)
    }
    if (inherits(source.fit, c("metric.graph.lowpass.fit",
                               "metric.graph.lowpass.refit"))) {
        return("normalized_metric_graph_lowpass")
    }
    source.method <- .state.density.null.coalesce(source.fit$method.id,
                                                  class(source.fit)[[1L]])
    source.method <- gsub("[^A-Za-z0-9]+", "_", source.method)
    source.method <- sub("_$", "", source.method)
    paste0("normalized_", source.method)
}

.normalize.density.fit <- function(x,
                                   X = NULL,
                                   density.control = list(),
                                   method.id = NULL,
                                   keep.source.fit = TRUE,
                                   adj.list = NULL,
                                   empirical.rho = NULL,
                                   return.details = TRUE) {
    values <- x$fitted.values
    if (is.null(values)) {
        stop("source fit does not contain fitted.values.", call. = FALSE)
    }
    if (is.matrix(values) || is.data.frame(values)) {
        if (NCOL(values) != 1L) {
            stop("normalize.density() currently supports one fitted response.",
                 call. = FALSE)
        }
        values <- as.vector(values)
    }
    if (is.null(empirical.rho) && !is.null(x$empirical.rho)) {
        empirical.rho <- x$empirical.rho
    }
    .normalize.density.vector(
        values = values,
        X = X,
        method.id = .normalize.density.method.id(x, method.id),
        source.fit = x,
        source.class = class(x)[[1L]],
        density.control = density.control,
        keep.source.fit = keep.source.fit,
        adj.list = adj.list,
        empirical.rho = empirical.rho,
        return.details = return.details
    )
}

.normalize.density.vector <- function(values,
                                      X = NULL,
                                      method.id,
                                      source.fit = NULL,
                                      source.class = "numeric",
                                      density.control = list(),
                                      keep.source.fit = TRUE,
                                      adj.list = NULL,
                                      empirical.rho = NULL,
                                      return.details = TRUE) {
    if (!is.numeric(values)) {
        stop("density normalization requires numeric fitted values.",
             call. = FALSE)
    }
    if (length(values) < 1L || any(!is.finite(values))) {
        stop("density normalization requires finite fitted values.",
             call. = FALSE)
    }
    X <- .normalize.density.support(X, length(values), source.fit)
    if (nrow(X) != length(values)) {
        stop("support size must match the number of fitted values.",
             call. = FALSE)
    }
    diagnostics <- list(source.class = source.class)
    if (isTRUE(keep.source.fit) && !is.null(source.fit)) {
        diagnostics$source.fit <- source.fit
    }
    chart.telemetry <- .state.density.chart.dim.telemetry(
        source.fit = source.fit,
        n = length(values)
    )
    if (!is.null(chart.telemetry)) {
        diagnostics$chart.dim <- chart.telemetry
    }
    empirical.rho <- .state.density.adapter.empirical.rho(
        empirical.rho = empirical.rho,
        n = length(values)
    )
    .state.density.finalize(
        method.id = method.id,
        X = X,
        fitted.raw = values,
        empirical.rho = empirical.rho,
        theta = list(source.class = source.class),
        density.control = density.control,
        adj.list = adj.list,
        diagnostics = diagnostics,
        return.details = return.details
    )
}

.state.density.adapter.empirical.rho <- function(empirical.rho, n) {
    if (is.null(empirical.rho)) {
        return(rep(NA_real_, n))
    }
    empirical.rho <- as.numeric(empirical.rho)
    if (length(empirical.rho) != n || any(!is.finite(empirical.rho))) {
        stop("empirical.rho must be NULL or a finite numeric vector matching the fitted values.",
             call. = FALSE)
    }
    empirical.rho
}

.state.density.null.coalesce <- function(x, y) {
    if (is.null(x)) y else x
}

.state.density.prepare.graph <- function(graph, n, allow.zero.length = TRUE) {
    if (is.null(graph)) {
        stop("graph must be supplied for graph state-density methods.",
             call. = FALSE)
    }
    adj.list <- .state.density.null.coalesce(graph$adj.list, graph$adj_list)
    weight.list <- .state.density.null.coalesce(graph$weight.list,
                                                graph$weight_list)
    if (is.null(adj.list) || is.null(weight.list)) {
        stop("graph must contain adj.list/weight.list or adj_list/weight_list.",
             call. = FALSE)
    }
    if (!is.list(adj.list) || !is.list(weight.list)) {
        stop("graph adjacency and weight fields must be lists.", call. = FALSE)
    }
    if (length(adj.list) != n || length(weight.list) != n) {
        stop("graph size must match nrow(X).", call. = FALSE)
    }
    adj.norm <- vector("list", n)
    weight.norm <- vector("list", n)
    for (i in seq_len(n)) {
        nb <- adj.list[[i]]
        wt <- weight.list[[i]]
        if (!is.numeric(nb) && !is.integer(nb)) {
            stop(sprintf("graph adjacency for vertex %d must be numeric/integer.", i),
                 call. = FALSE)
        }
        if (!is.numeric(wt)) {
            stop(sprintf("graph weights for vertex %d must be numeric.", i),
                 call. = FALSE)
        }
        nb <- as.integer(nb)
        wt <- as.double(wt)
        if (length(nb) != length(wt)) {
            stop(sprintf("graph adjacency and weight lengths differ at vertex %d.", i),
                 call. = FALSE)
        }
        if (length(nb) == 0L) {
            stop("graph state-density methods require no isolated vertices.",
                 call. = FALSE)
        }
        if (anyNA(nb) || any(nb < 1L | nb > n)) {
            stop(sprintf("graph adjacency for vertex %d has invalid indices.", i),
                 call. = FALSE)
        }
        if (any(nb == i)) {
            stop(sprintf("graph adjacency for vertex %d contains self-loops.", i),
                 call. = FALSE)
        }
        if (anyDuplicated(nb)) {
            stop(sprintf("graph adjacency for vertex %d contains duplicate neighbors.", i),
                 call. = FALSE)
        }
        if (any(!is.finite(wt))) {
            stop(sprintf("graph weights for vertex %d contain non-finite values.", i),
                 call. = FALSE)
        }
        if (isTRUE(allow.zero.length)) {
            if (any(wt < 0)) {
                stop(sprintf("graph weights for vertex %d contain negative values.", i),
                     call. = FALSE)
            }
        } else if (any(wt <= 0)) {
            stop(sprintf("graph weights for vertex %d contain non-positive values.", i),
                 call. = FALSE)
        }
        adj.norm[[i]] <- nb
        weight.norm[[i]] <- wt
    }
    list(
        adj.list = adj.norm,
        weight.list = weight.norm,
        n.vertices = n
    )
}

.state.density.graph.edge.lengths <- function(graph) {
    as.double(unlist(graph$weight.list, use.names = FALSE))
}

.state.density.edge.lengths.to.affinity <- function(edge.lengths,
                                                    method,
                                                    scale = NULL,
                                                    epsilon = 1e-12) {
    method <- match.arg(method, c("exp_neg_length_over_median",
                                  "inverse_length"))
    if (any(!is.finite(edge.lengths)) || any(edge.lengths < 0)) {
        stop("edge lengths must be finite and nonnegative.", call. = FALSE)
    }
    if (!is.numeric(epsilon) || length(epsilon) != 1L ||
        !is.finite(epsilon) || epsilon <= 0) {
        stop("affinity epsilon must be a finite positive scalar.", call. = FALSE)
    }
    if (identical(method, "exp_neg_length_over_median")) {
        if (is.null(scale)) {
            positive <- edge.lengths[edge.lengths > 0]
            if (length(positive) == 0L) {
                stop("cannot infer exponential affinity scale from all-zero edge lengths.",
                     call. = FALSE)
            }
            scale <- stats::median(positive)
        }
        if (!is.numeric(scale) || length(scale) != 1L ||
            !is.finite(scale) || scale <= 0) {
            stop("affinity scale must be a finite positive scalar.", call. = FALSE)
        }
        return(exp(-edge.lengths / scale))
    }
    1 / (edge.lengths + epsilon)
}

.state.density.transition.matrix <- function(graph,
                                             affinity.method,
                                             affinity.scale = NULL,
                                             affinity.epsilon = 1e-12) {
    if (!requireNamespace("Matrix", quietly = TRUE)) {
        stop("Matrix is required for graph random-walk state density.",
             call. = FALSE)
    }
    n <- graph$n.vertices
    degree <- lengths(graph$adj.list)
    rows <- rep(seq_len(n), degree)
    cols <- unlist(graph$adj.list, use.names = FALSE)
    edge.lengths <- .state.density.graph.edge.lengths(graph)
    affinities <- .state.density.edge.lengths.to.affinity(
        edge.lengths = edge.lengths,
        method = affinity.method,
        scale = affinity.scale,
        epsilon = affinity.epsilon
    )
    strength.by.row <- rowsum(affinities, rows, reorder = FALSE)
    row.strength <- numeric(n)
    row.strength[as.integer(rownames(strength.by.row))] <- strength.by.row[, 1]
    if (any(!is.finite(row.strength)) || any(row.strength <= 0)) {
        stop("all graph transition rows must have positive finite affinity strength.",
             call. = FALSE)
    }
    transition <- Matrix::sparseMatrix(
        i = rows,
        j = cols,
        x = affinities / row.strength[rows],
        dims = c(n, n)
    )
    row.sum <- Matrix::rowSums(transition)
    transition <- Matrix::Diagonal(x = 1 / as.numeric(row.sum)) %*% transition
    transition <- methods::as(transition, "dgCMatrix")
    list(
        transition = transition,
        row.strength = row.strength,
        metadata = list(
            n.vertices = n,
            n.directed.entries = length(rows),
            affinity.method = affinity.method,
            affinity.scale = if (is.null(affinity.scale)) {
                positive <- edge.lengths[edge.lengths > 0]
                if (length(positive) > 0L) stats::median(positive) else NA_real_
            } else {
                affinity.scale
            },
            affinity.epsilon = affinity.epsilon,
            edge.length.min = min(edge.lengths),
            edge.length.median = stats::median(edge.lengths),
            edge.length.max = max(edge.lengths),
            row.strength.min = min(row.strength),
            row.strength.median = stats::median(row.strength),
            row.strength.max = max(row.strength),
            transition.row.sum.max.abs.error =
                max(abs(Matrix::rowSums(transition) - 1))
        )
    )
}

.state.density.graph.control.value <- function(graph.control, names, default) {
    for (nm in names) {
        if (!is.null(graph.control[[nm]])) {
            return(graph.control[[nm]])
        }
    }
    default
}

.state.density.walk.steps <- function(graph.control) {
    walk.steps <- .state.density.graph.control.value(
        graph.control, c("walk.steps", "walk_steps"), NULL
    )
    if (is.null(walk.steps)) {
        walk.step <- .state.density.graph.control.value(
            graph.control, c("walk.step", "walk_step"), 1L
        )
        walk.steps <- c(0L, walk.step)
    }
    if (!is.numeric(walk.steps) || length(walk.steps) < 1L ||
        any(!is.finite(walk.steps)) || any(walk.steps < 0) ||
        any(walk.steps != floor(walk.steps))) {
        stop("walk.steps must be nonnegative integer values.", call. = FALSE)
    }
    sort(unique(as.integer(c(0L, walk.steps))))
}

.state.density.random.walk <- function(empirical, graph, graph.control = list()) {
    affinity.method <- .state.density.graph.control.value(
        graph.control, c("affinity.method", "affinity_method"),
        "exp_neg_length_over_median"
    )
    affinity.method <- match.arg(affinity.method,
                                 c("exp_neg_length_over_median", "inverse_length"))
    affinity.scale <- .state.density.graph.control.value(
        graph.control, c("affinity.scale", "affinity_scale"), NULL
    )
    affinity.epsilon <- .state.density.graph.control.value(
        graph.control, c("affinity.epsilon", "affinity_epsilon"), 1e-12
    )
    normalize <- isTRUE(.state.density.graph.control.value(
        graph.control, c("normalize"), TRUE
    ))
    walk.steps <- .state.density.walk.steps(graph.control)
    selected.step <- max(walk.steps)
    tr <- .state.density.transition.matrix(
        graph = graph,
        affinity.method = affinity.method,
        affinity.scale = affinity.scale,
        affinity.epsilon = affinity.epsilon
    )
    current <- Matrix::Matrix(empirical, nrow = 1L, sparse = TRUE)
    by.step <- vector("list", length(walk.steps))
    names(by.step) <- sprintf("r%02d", walk.steps)
    by.step[[sprintf("r%02d", 0L)]] <- current
    requested <- names(by.step)
    max.step <- max(walk.steps)
    if (max.step > 0L) {
        for (step in seq_len(max.step)) {
            current <- current %*% tr$transition
            if (normalize) {
                row.sum <- Matrix::rowSums(current)
                current <- Matrix::Diagonal(x = 1 / as.numeric(row.sum)) %*% current
            }
            key <- sprintf("r%02d", step)
            if (key %in% requested) {
                by.step[[key]] <- methods::as(Matrix::drop0(current), "dgCMatrix")
            }
        }
    }
    selected <- by.step[[sprintf("r%02d", selected.step)]]
    list(
        rho = as.numeric(as.matrix(selected)),
        transition = tr$transition,
        occupation.by.step = by.step,
        row.strength = tr$row.strength,
        metadata = tr$metadata,
        theta = list(
            graph.method = "random_walk",
            walk.steps = walk.steps,
            selected.walk.step = selected.step,
            affinity.method = affinity.method,
            affinity.scale = tr$metadata$affinity.scale,
            affinity.epsilon = affinity.epsilon,
            normalize = normalize
        )
    )
}

.state.density.finalize <- function(method.id,
                                    X,
                                    fitted.raw,
                                    empirical.rho = NULL,
                                    theta = list(),
                                    density.control = list(),
                                    adj.list = NULL,
                                    basin.assignment = NULL,
                                    diagnostics = list(),
                                    warnings = character(),
                                    return.details = TRUE) {
    X <- .state.density.validate.X(X)
    ctrl <- .state.density.control(density.control)
    fitted.raw <- .state.density.validate.raw(fitted.raw, nrow(X))
    corrected <- .state.density.correct.raw(fitted.raw, ctrl)
    accounting <- corrected$accounting
    status <- .state.density.status(corrected$rho, accounting, ctrl)
    if (!identical(status, "ok")) {
        warnings <- c(warnings, paste("density accounting status:", status))
    }
    .state.density.result(
        method.id = method.id,
        status = status,
        rho = corrected$rho,
        empirical.rho = empirical.rho,
        fitted.raw = fitted.raw,
        theta = theta,
        accounting = accounting,
        smoothness = .state.density.smoothness(
            rho = corrected$rho,
            X = X,
            density.control = ctrl,
            adj.list = adj.list,
            basin.assignment = basin.assignment
        ),
        diagnostics = diagnostics,
        warnings = warnings,
        return.details = return.details
    )
}

.state.density.validate.raw <- function(fitted.raw, n) {
    if (!is.numeric(fitted.raw) || length(fitted.raw) != n) {
        stop("fitted.raw must be a numeric vector with length nrow(X).",
             call. = FALSE)
    }
    as.numeric(fitted.raw)
}

.state.density.correct.raw <- function(fitted.raw, ctrl) {
    raw.mass <- sum(fitted.raw)
    neg.mass <- sum(abs(fitted.raw[fitted.raw < 0]))
    rho <- fitted.raw
    clip.mass <- 0
    if (isTRUE(ctrl$clip.negative)) {
        clip.mass <- neg.mass
        rho <- pmax(rho, 0)
    }
    normalization.constant <- sum(rho)
    if (isTRUE(ctrl$renormalize) && is.finite(normalization.constant) &&
        normalization.constant > 0) {
        rho <- rho / normalization.constant
    }
    list(
        rho = rho,
        accounting = list(
            mass = sum(rho),
            min.rho = suppressWarnings(min(rho)),
            max.rho = suppressWarnings(max(rho)),
            raw.mass = raw.mass,
            neg.mass = neg.mass,
            clip.mass = clip.mass,
            normalization.constant = normalization.constant,
            mass.tol = ctrl$mass.tol,
            neg.tol = ctrl$neg.tol
        )
    )
}

.state.density.status <- function(rho, accounting, ctrl) {
    if (any(!is.finite(rho)) || any(!is.finite(unlist(accounting)))) {
        return("nonfinite")
    }
    if (min(rho) < -ctrl$neg.tol) {
        return("negative_mass_failure")
    }
    if (abs(sum(rho) - 1) > ctrl$mass.tol) {
        return("mass_failure")
    }
    "ok"
}

.state.density.result <- function(method.id,
                                  status,
                                  rho,
                                  empirical.rho,
                                  fitted.raw,
                                  theta,
                                  accounting,
                                  smoothness,
                                  diagnostics,
                                  warnings,
                                  return.details = TRUE) {
    out <- list(
        method.id = method.id,
        status = status,
        rho = rho,
        empirical.rho = empirical.rho,
        fitted.raw = fitted.raw,
        theta = theta,
        accounting = accounting,
        smoothness = smoothness,
        timing = list(),
        diagnostics = diagnostics,
        warnings = warnings
    )
    if (!isTRUE(return.details)) {
        out$diagnostics <- list()
        out$smoothness <- .state.density.empty.smoothness()
    }
    class(out) <- c("density_fit", "list")
    out
}

.state.density.smoothness.placeholder <- function(rho) {
    list(
        n.local.maxima = NA_integer_,
        local.maxima.reason = "not_computed",
        raw.basin.size.summary = data.frame(),
        raw.basin.mass.summary = data.frame()
    )
}

.state.density.empty.smoothness <- function() {
    .state.density.smoothness.placeholder(numeric())
}

.state.density.smoothness <- function(rho,
                                      X = NULL,
                                      density.control = list(),
                                      adj.list = NULL,
                                      basin.assignment = NULL) {
    resolved.adj.list <- .state.density.resolve.smoothness.adj.list(
        X = X,
        density.control = density.control,
        adj.list = adj.list
    )
    summary <- .state.density.raw.basin.summary(
        basin.assignment = basin.assignment,
        rho = rho
    )
    list(
        n.local.maxima = .state.density.local.maxima.count(
            values = rho,
            adj.list = resolved.adj.list
        ),
        local.maxima.reason = .state.density.local.maxima.reason(
            X = X,
            supplied.adj.list = adj.list,
            density.control = density.control,
            resolved.adj.list = resolved.adj.list
        ),
        raw.basin.size.summary = summary$raw.basin.size.summary,
        raw.basin.mass.summary = summary$raw.basin.mass.summary
    )
}

.state.density.local.maxima.reason <- function(X,
                                               supplied.adj.list = NULL,
                                               density.control = list(),
                                               resolved.adj.list = NULL) {
    if (!is.null(resolved.adj.list)) {
        if (!is.null(supplied.adj.list) ||
            !is.null(density.control$smoothness.adj.list)) {
            return("computed_from_supplied_adjacency")
        }
        return("computed_from_auto_1d_path")
    }
    auto.1d <- if (is.null(density.control$smoothness.auto.1d)) {
        TRUE
    } else {
        isTRUE(density.control$smoothness.auto.1d)
    }
    if (!isTRUE(auto.1d)) {
        return("not_computed_auto_1d_disabled_and_no_adjacency")
    }
    if (is.null(X)) {
        return("not_computed_no_support_or_adjacency")
    }
    if (nrow(X) <= 1L) {
        return("not_computed_singleton_support")
    }
    if (ncol(X) > 1L) {
        return("not_computed_no_adjacency_for_multivariate_support")
    }
    "not_computed_no_adjacency"
}

.state.density.resolve.smoothness.adj.list <- function(X,
                                                       density.control = list(),
                                                       adj.list = NULL) {
    if (!is.null(adj.list)) {
        return(.state.density.validate.adj.list(adj.list, length.out = nrow(X)))
    }
    if (!is.null(density.control$smoothness.adj.list)) {
        return(.state.density.validate.adj.list(
            density.control$smoothness.adj.list,
            length.out = nrow(X)
        ))
    }
    auto.1d <- if (is.null(density.control$smoothness.auto.1d)) {
        TRUE
    } else {
        isTRUE(density.control$smoothness.auto.1d)
    }
    if (isTRUE(auto.1d) && !is.null(X) && ncol(X) == 1L && nrow(X) > 1L) {
        return(.state.density.ordered.path.adj.list(X[, 1L]))
    }
    NULL
}

.state.density.validate.adj.list <- function(adj.list, length.out) {
    if (is.null(adj.list)) {
        return(NULL)
    }
    if (!is.list(adj.list) || length(adj.list) != length.out) {
        stop("smoothness adjacency list must be a list with length nrow(X).",
             call. = FALSE)
    }
    lapply(seq_along(adj.list), function(i) {
        nb <- adj.list[[i]]
        if (!is.numeric(nb) && !is.integer(nb)) {
            stop("smoothness adjacency entries must be numeric/integer vectors.",
                 call. = FALSE)
        }
        nb <- as.integer(nb)
        if (anyNA(nb) || any(nb < 1L | nb > length.out)) {
            stop("smoothness adjacency contains invalid vertex indices.",
                 call. = FALSE)
        }
        if (any(nb == i)) {
            stop("smoothness adjacency must not contain self-loops.",
                 call. = FALSE)
        }
        unique(nb)
    })
}

.state.density.ordered.path.adj.list <- function(x) {
    n <- length(x)
    ord <- order(x, seq_along(x))
    adj <- vector("list", n)
    if (n <= 1L) {
        return(adj)
    }
    for (pos in seq_along(ord)) {
        i <- ord[[pos]]
        nb <- integer()
        if (pos > 1L) {
            nb <- c(nb, ord[[pos - 1L]])
        }
        if (pos < n) {
            nb <- c(nb, ord[[pos + 1L]])
        }
        adj[[i]] <- as.integer(nb)
    }
    adj
}

.state.density.local.maxima.count <- function(values, adj.list = NULL) {
    if (is.null(adj.list)) {
        return(NA_integer_)
    }
    if (!is.numeric(values) || length(adj.list) != length(values)) {
        stop("values and adj.list must have matching lengths.", call. = FALSE)
    }
    n.max <- 0L
    for (i in seq_along(values)) {
        if (!is.finite(values[[i]])) {
            next
        }
        nb <- adj.list[[i]]
        if (length(nb) == 0L ||
            all(values[[i]] > values[as.integer(nb)], na.rm = TRUE)) {
            n.max <- n.max + 1L
        }
    }
    n.max
}

.state.density.raw.basin.summary <- function(basin.assignment, rho = NULL) {
    if (is.null(basin.assignment)) {
        return(list(
            raw.basin.size.summary = data.frame(),
            raw.basin.mass.summary = data.frame()
        ))
    }
    basin.assignment <- as.character(basin.assignment)
    size <- as.data.frame(table(basin.assignment), stringsAsFactors = FALSE)
    names(size) <- c("basin", "size")
    if (is.null(rho)) {
        mass <- data.frame()
    } else {
        mass <- stats::aggregate(
            rho,
            by = list(basin = basin.assignment),
            FUN = sum
        )
        names(mass) <- c("basin", "mass")
    }
    list(raw.basin.size.summary = size, raw.basin.mass.summary = mass)
}
