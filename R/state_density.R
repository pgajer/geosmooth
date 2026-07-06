#' Fit a State-Density Estimator
#'
#' Dispatches to a dedicated state-density estimator.  Subject-occupation
#' density estimation is one application: construct a sparse mass vector over a
#' fixed state set and call this generic state-density layer.
#'
#' @param X Numeric matrix with one row per state-space point.
#' @param weights Optional nonnegative mass/count vector of length
#'   \code{nrow(X)}. Required by count-based density methods.
#' @param method State-density method identifier.
#' @param binary Optional binary response vector of length \code{nrow(X)} used
#'   by binary/logistic density methods.
#' @param graph Optional precomputed graph object.
#' @param graph.control,chart.control,smoother.control Lists of method-specific
#'   controls.  They are accepted at the dispatcher layer and forwarded to the
#'   dedicated method.
#' @param density.control List controlling clipping, normalization, and
#'   accounting checks.  Recognized entries are \code{mass.tol},
#'   \code{neg.tol}, \code{clip.negative}, and \code{renormalize}.
#' @param return.details Logical; if \code{TRUE}, keep diagnostic details in
#'   the result.
#' @param ... Additional method-specific arguments.
#'
#' @return A list of class \code{"state_density_fit"} with fields
#'   \code{method.id}, \code{status}, \code{rho}, \code{empirical.rho},
#'   \code{fitted.raw}, \code{theta}, \code{accounting},
#'   \code{smoothness}, \code{timing}, \code{diagnostics}, and
#'   \code{warnings}.
#' @export
fit.state.density <- function(
    X,
    weights = NULL,
    method = c("empirical", "graph_random_walk", "graph_heat_kernel",
               "lps_count", "ps_lps_count", "lps_logistic_binary",
               "chart_kernel", "local_likelihood"),
    binary = NULL,
    graph = NULL,
    graph.control = list(),
    chart.control = list(),
    smoother.control = list(),
    density.control = list(),
    return.details = TRUE,
    ...) {

    method <- match.arg(method)
    X <- .state.density.validate.X(X)
    ctrl <- .state.density.control(density.control)

    switch(
        method,
        empirical = fit.state.density.empirical(
            X = X,
            weights = weights,
            density.control = ctrl,
            return.details = return.details,
            ...
        ),
        graph_random_walk = fit.state.density.graph.random.walk(
            X = X,
            weights = weights,
            graph = graph,
            graph.control = graph.control,
            density.control = ctrl,
            return.details = return.details,
            ...
        ),
        graph_heat_kernel = fit.state.density.graph.heat.kernel(
            X = X,
            weights = weights,
            graph = graph,
            graph.control = graph.control,
            density.control = ctrl,
            return.details = return.details,
            ...
        ),
        lps_count = fit.state.density.lps(
            X = X,
            weights = weights,
            chart.control = chart.control,
            smoother.control = smoother.control,
            density.control = ctrl,
            return.details = return.details,
            ...
        ),
        ps_lps_count = fit.state.density.ps.lps(
            X = X,
            weights = weights,
            chart.control = chart.control,
            smoother.control = smoother.control,
            density.control = ctrl,
            return.details = return.details,
            ...
        ),
        lps_logistic_binary = fit.state.density.lps.logistic(
            X = X,
            binary = binary,
            chart.control = chart.control,
            smoother.control = smoother.control,
            density.control = ctrl,
            return.details = return.details,
            ...
        ),
        chart_kernel = fit.state.density.chart.kernel(
            X = X,
            weights = weights,
            chart.control = chart.control,
            density.control = ctrl,
            return.details = return.details,
            ...
        ),
        local_likelihood = fit.state.density.local.likelihood(
            X = X,
            weights = weights,
            chart.control = chart.control,
            smoother.control = smoother.control,
            density.control = ctrl,
            return.details = return.details,
            ...
        )
    )
}

#' Fit Empirical State Density
#'
#' Normalizes a nonnegative mass/count vector over a fixed state set.
#'
#' @inheritParams fit.state.density
#' @export
fit.state.density.empirical <- function(
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

#' Fit Graph Random-Walk State Density
#'
#' OD0 exports the method contract and returns a structured
#' \code{"not_implemented"} result.  OD1 will fill in the random-walk smoother.
#'
#' @inheritParams fit.state.density
#' @export
fit.state.density.graph.random.walk <- function(
    X,
    weights,
    graph = NULL,
    graph.control = list(),
    density.control = list(),
    return.details = TRUE,
    ...) {

    .state.density.not.implemented(
        method.id = "graph_random_walk",
        X = X,
        weights = weights,
        theta = list(graph.control = graph.control),
        density.control = density.control,
        return.details = return.details
    )
}

#' Fit Graph Heat-Kernel State Density
#'
#' OD0 exports the method contract and returns a structured
#' \code{"not_implemented"} result.  OD1 will fill in the heat-kernel smoother.
#'
#' @inheritParams fit.state.density
#' @export
fit.state.density.graph.heat.kernel <- function(
    X,
    weights,
    graph = NULL,
    graph.control = list(),
    density.control = list(),
    return.details = TRUE,
    ...) {

    .state.density.not.implemented(
        method.id = "graph_heat_kernel",
        X = X,
        weights = weights,
        theta = list(graph.control = graph.control),
        density.control = density.control,
        return.details = return.details
    )
}

#' Fit LPS Count-Based State Density
#'
#' OD0 exports the method contract and returns a structured
#' \code{"not_implemented"} result.  OD2 will wrap \code{\link{fit.lps}}.
#'
#' @inheritParams fit.state.density
#' @export
fit.state.density.lps <- function(
    X,
    weights,
    chart.control = list(),
    smoother.control = list(),
    density.control = list(),
    return.details = TRUE,
    ...) {

    .state.density.not.implemented(
        method.id = "lps_count",
        X = X,
        weights = weights,
        theta = list(chart.control = chart.control,
                     smoother.control = smoother.control),
        density.control = density.control,
        return.details = return.details
    )
}

#' Fit PS-LPS Count-Based State Density
#'
#' OD0 exports the method contract and returns a structured
#' \code{"not_implemented"} result.  OD2 will wrap \code{\link{fit.ps.lps}}.
#'
#' @inheritParams fit.state.density
#' @export
fit.state.density.ps.lps <- function(
    X,
    weights,
    chart.control = list(),
    smoother.control = list(),
    density.control = list(),
    return.details = TRUE,
    ...) {

    .state.density.not.implemented(
        method.id = "ps_lps_count",
        X = X,
        weights = weights,
        theta = list(chart.control = chart.control,
                     smoother.control = smoother.control),
        density.control = density.control,
        return.details = return.details
    )
}

#' Fit Logistic LPS Binary State Density
#'
#' OD0 exports the method contract and returns a structured
#' \code{"not_implemented"} result.  OD2 will wrap
#' \code{fit.lps(..., outcome.family = "bernoulli")}.
#'
#' @inheritParams fit.state.density
#' @export
fit.state.density.lps.logistic <- function(
    X,
    binary,
    chart.control = list(),
    smoother.control = list(),
    density.control = list(),
    return.details = TRUE,
    ...) {

    X <- .state.density.validate.X(X)
    binary <- .state.density.validate.binary(binary, nrow(X), "binary")
    .state.density.not.implemented(
        method.id = "lps_logistic_binary",
        X = X,
        weights = binary,
        theta = list(chart.control = chart.control,
                     smoother.control = smoother.control),
        density.control = density.control,
        return.details = return.details
    )
}

#' Fit Chart-Kernel State Density
#'
#' OD0 exports the method contract and returns a structured
#' \code{"not_implemented"} result.  A later phase will implement the prototype.
#'
#' @inheritParams fit.state.density
#' @export
fit.state.density.chart.kernel <- function(
    X,
    weights,
    chart.control = list(),
    density.control = list(),
    return.details = TRUE,
    ...) {

    .state.density.not.implemented(
        method.id = "chart_kernel",
        X = X,
        weights = weights,
        theta = list(chart.control = chart.control),
        density.control = density.control,
        return.details = return.details
    )
}

#' Fit Local-Likelihood State Density
#'
#' OD0 exports the method contract and returns a structured
#' \code{"not_implemented"} result.  A later phase will implement the prototype.
#'
#' @inheritParams fit.state.density
#' @export
fit.state.density.local.likelihood <- function(
    X,
    weights,
    chart.control = list(),
    smoother.control = list(),
    density.control = list(),
    return.details = TRUE,
    ...) {

    .state.density.not.implemented(
        method.id = "local_likelihood",
        X = X,
        weights = weights,
        theta = list(chart.control = chart.control,
                     smoother.control = smoother.control),
        density.control = density.control,
        return.details = return.details
    )
}

#' Fit Subject-Occupation Density
#'
#' Convenience wrapper that converts subject visit indices into a state-density
#' input and dispatches to \code{\link{fit.state.density}}.
#'
#' @inheritParams fit.state.density
#' @param subject.index Integer row indices of subject visits in \code{X}.
#'   Repeated indices are allowed.
#' @param od.control OD-facing alias for \code{density.control}.
#'
#' @export
fit.subject.od <- function(
    X,
    subject.index,
    method = c("empirical", "graph_random_walk", "graph_heat_kernel",
               "lps_count", "ps_lps_count", "lps_logistic_binary",
               "chart_kernel", "local_likelihood"),
    graph = NULL,
    graph.control = list(),
    chart.control = list(),
    smoother.control = list(),
    od.control = list(),
    return.details = TRUE,
    ...) {

    X <- .state.density.validate.X(X)
    subject.index <- .state.density.validate.subject.index(subject.index, nrow(X))
    weights <- .state.density.subject.weights(subject.index, nrow(X))
    binary <- as.numeric(weights > 0)
    method <- match.arg(method)

    out <- fit.state.density(
        X = X,
        weights = weights,
        method = method,
        binary = binary,
        graph = graph,
        graph.control = graph.control,
        chart.control = chart.control,
        smoother.control = smoother.control,
        density.control = od.control,
        return.details = return.details,
        ...
    )
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

#' Precheck State-Density Dependencies
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
#' @export
state.density.dependency.precheck <- function(check.gflow = TRUE,
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
            stop("Missing required state-density dependencies: ",
                 paste(out$symbol[missing.required], collapse = ", "),
                 call. = FALSE)
        }
    }
    out
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

.state.density.not.implemented <- function(method.id,
                                           X,
                                           weights = NULL,
                                           theta = list(),
                                           density.control = list(),
                                           return.details = TRUE) {
    X <- .state.density.validate.X(X)
    ctrl <- .state.density.control(density.control)
    empirical <- NULL
    if (!is.null(weights)) {
        weights <- .state.density.validate.weights(weights, nrow(X), "weights")
        empirical <- .state.density.normalize.weights(weights)
    }
    .state.density.result(
        method.id = method.id,
        status = "not_implemented",
        rho = rep(NA_real_, nrow(X)),
        empirical.rho = empirical,
        fitted.raw = rep(NA_real_, nrow(X)),
        theta = theta,
        accounting = list(
            mass = NA_real_,
            min.rho = NA_real_,
            max.rho = NA_real_,
            raw.mass = NA_real_,
            neg.mass = NA_real_,
            clip.mass = NA_real_,
            normalization.constant = NA_real_,
            mass.tol = ctrl$mass.tol,
            neg.tol = ctrl$neg.tol
        ),
        smoothness = .state.density.empty.smoothness(),
        diagnostics = list(reason = "method implementation is deferred"),
        warnings = paste(method.id, "is not implemented in OD0."),
        return.details = return.details
    )
}

.state.density.finalize <- function(method.id,
                                    X,
                                    fitted.raw,
                                    empirical.rho = NULL,
                                    theta = list(),
                                    density.control = list(),
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
        smoothness = .state.density.smoothness.placeholder(corrected$rho),
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
    class(out) <- c("state_density_fit", "list")
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
            all(values[[i]] >= values[as.integer(nb)], na.rm = FALSE)) {
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
