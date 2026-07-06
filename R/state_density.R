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
#' @inheritParams fit.density
#' @param subject.index Integer row indices of subject visits in \code{X}.
#'   Repeated indices are allowed.
#' @param od.control OD-facing alias for \code{density.control}.
#'
#' @export
fit.subject.od <- function(
    X,
    subject.index,
    method = c("empirical", "graph_random_walk", "lps_count",
               "ps_lps_count", "lps_logistic_binary"),
    graph = NULL,
    graph.control = list(),
    od.control = list(),
    return.details = TRUE,
    ...) {

    X <- .state.density.validate.X(X)
    subject.index <- .state.density.validate.subject.index(subject.index, nrow(X))
    weights <- .state.density.subject.weights(subject.index, nrow(X))
    method <- match.arg(method)

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
        "lps.grouped.foldid", "lps.nested.cv", "dgp.materialize",
        "dgp.content.sha256"
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
    } else if (inherits(source.fit, "ps_lps")) {
        out$diagnostics$selection <- source.fit$selected
        out$diagnostics$sync.energy <- source.fit$sync.energy
        out$diagnostics$mean.sync.squared.disagreement <-
            source.fit$mean.sync.squared.disagreement
        out$diagnostics$lambda.sync.search.telemetry <-
            source.fit$lambda.sync.search.telemetry
        out$diagnostics$lambda.search.summary <-
            source.fit$lambda.search.summary
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
    adj.list <- .state.density.resolve.smoothness.adj.list(
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
            adj.list = adj.list
        ),
        raw.basin.size.summary = summary$raw.basin.size.summary,
        raw.basin.mass.summary = summary$raw.basin.mass.summary
    )
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
        nb <- adj.list[[i]]
        if (length(nb) == 0L ||
            all(values[[i]] > values[as.integer(nb)], na.rm = FALSE)) {
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
