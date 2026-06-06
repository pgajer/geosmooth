#' Fit a Local Polynomial Smoother
#'
#' Fits a local polynomial smoother (LPS) and selects its support size,
#' polynomial degree, and kernel by cross-validation.  By default, the smoother
#' works in the observed ambient coordinates: each prediction point uses its
#' nearest training points in Euclidean distance, centers the support at the
#' prediction point, fits a weighted local polynomial, and uses the fitted
#' intercept as the prediction.
#'
#' The optional \code{coordinate.method = "local.pca"} mode keeps the same
#' support and kernel weighting rule, but builds the local polynomial in a local
#' PCA chart centered at each prediction point.  With \code{chart.dim = "auto"},
#' the chart dimension is estimated as one global scalar from observed
#' \code{X} only, using the same shared local-PCA dimension helper used by
#' LPL-TF and S-LPL-TF.  The experimental
#' \code{chart.dim = "local.auto"} mode estimates an input-only local chart
#' dimension separately for each prediction anchor.
#'
#' @param X Numeric design/coordinate matrix with one observation per row.
#' @param y Numeric response vector with length \code{nrow(X)}.
#' @param foldid Optional positive integer vector assigning rows to CV folds.
#' @param support.grid Integer candidate neighborhood sizes.
#' @param degree.grid Integer polynomial degrees. Currently degrees 0, 1, and 2
#'   are supported.
#' @param kernel.grid Candidate kernels. Supported kernels are
#'   \code{"gaussian"}, \code{"tricube"}, \code{"epanechnikov"}, and
#'   \code{"triangular"}.
#' @param cv.folds Number of folds used when \code{foldid} is not supplied.
#' @param cv.seed Random seed used to generate folds when \code{foldid} is not
#'   supplied.
#' @param X.eval Optional matrix of prediction locations. Defaults to \code{X}.
#' @param coordinate.method Local coordinate system. \code{"coordinates"} uses
#'   centered ambient coordinates. \code{"local.pca"} uses a local PCA chart.
#' @param chart.dim Chart dimension for \code{coordinate.method = "local.pca"}.
#'   If \code{NULL}, defaults to \code{ncol(X)}. The special value
#'   \code{"auto"} estimates one global chart dimension from observed
#'   \code{X} only. The experimental special value \code{"local.auto"}
#'   estimates a local chart dimension separately for each prediction anchor in
#'   the ordinary local-PCA R backend.
#' @param local.chart.method Local chart constructor used when
#'   \code{coordinate.method = "local.pca"}. \code{"pca"} preserves the ordinary
#'   local-PCA chart path. \code{"second.order.svd"} uses an experimental
#'   curvature-corrected second-order local SVD chart and records compact chart
#'   fallback diagnostics. This option is opt-in and does not affect ambient
#'   coordinate fits.
#' @param auto.chart.support.metric Support system used when
#'   \code{chart.dim = "auto"} or \code{"local.auto"}. Included for
#'   consistency with LPL-TF and S-LPL-TF; because this smoother uses
#'   coordinate supports,
#'   \code{"operator"} is equivalent to \code{"coordinates"}.
#' @param auto.chart.selection.metric Which auto chart-dimension diagnostic to
#'   select when both diagnostics are requested.
#' @param backend Computation backend. \code{"auto"} uses the C++ backend for
#'   \code{coordinate.method = "coordinates"} and the R reference backend for
#'   \code{coordinate.method = "local.pca"}. \code{"R"} always uses the
#'   reference implementation. \code{"cpp"} requires ambient coordinates.
#'   \code{"cpp.local.pca"} is an opt-in prototype backend for
#'   \code{coordinate.method = "local.pca"} with
#'   \code{local.chart.method = "pca"}.
#' @return A list of class \code{"lps"} with fitted values, selected
#'   parameters, a candidate CV table, the requested
#'   \code{local.chart.method}, and the effective chart method used for
#'   reporting.
#' @export
fit.lps <- function(
    X, y, foldid = NULL,
    support.grid = c(10L, 15L, 20L),
    degree.grid = 0:2,
    kernel.grid = c("gaussian", "tricube"),
    cv.folds = 5L,
    cv.seed = 1L,
    X.eval = NULL,
    coordinate.method = c("coordinates", "local.pca"),
    chart.dim = NULL,
    local.chart.method = c("pca", "second.order.svd"),
    auto.chart.support.metric = c("coordinates", "operator", "both"),
    auto.chart.selection.metric = c("coordinates", "operator"),
    backend = c("auto", "R", "cpp", "cpp.local.pca")) {

    X <- as.matrix(X)
    y <- as.numeric(y)
    if (!is.numeric(X) || !length(X) || any(!is.finite(X))) {
        stop("'X' must be a finite numeric matrix.", call. = FALSE)
    }
    if (length(y) != nrow(X) || any(!is.finite(y))) {
        stop("'y' must be a finite numeric vector with length nrow(X).",
             call. = FALSE)
    }
    X.eval <- if (is.null(X.eval)) X else as.matrix(X.eval)
    if (ncol(X.eval) != ncol(X) || any(!is.finite(X.eval))) {
        stop("'X.eval' must be a finite matrix with ncol(X.eval) = ncol(X).",
             call. = FALSE)
    }
    coordinate.method <- match.arg(coordinate.method)
    local.chart.method <- match.arg(local.chart.method)
    if (identical(coordinate.method, "coordinates") &&
        identical(local.chart.method, "second.order.svd")) {
        stop("'local.chart.method = \"second.order.svd\"' requires ",
             "coordinate.method = 'local.pca'.", call. = FALSE)
    }
    local.chart.method.effective <- if (identical(coordinate.method,
                                                  "coordinates")) {
        "none"
    } else {
        local.chart.method
    }
    backend <- match.arg(backend)
    auto.chart.support.metric <- match.arg(auto.chart.support.metric)
    auto.chart.selection.metric <- match.arg(auto.chart.selection.metric)
    backend.used <- .klp.resolve.backend(
        coordinate.method,
        backend,
        local.chart.method.effective
    )
    if (.klp.is.local.auto.chart.dim(chart.dim)) {
        if (!identical(coordinate.method, "local.pca")) {
            stop("'chart.dim = \"local.auto\"' requires ",
                 "coordinate.method = 'local.pca'.", call. = FALSE)
        }
        if (!identical(local.chart.method.effective, "pca")) {
            stop("'chart.dim = \"local.auto\"' currently supports only ",
                 "local.chart.method = 'pca'.", call. = FALSE)
        }
        if (identical(backend.used, "cpp.local.pca")) {
            stop("'chart.dim = \"local.auto\"' currently uses the R ",
                 "local-PCA backend; use backend = 'auto' or 'R'.",
                 call. = FALSE)
        }
    }
    support.grid <- .klp.clean.support.grid(support.grid, nrow(X))
    degree.grid <- .klp.clean.degree.grid(degree.grid)
    kernel.grid <- .klp.clean.kernel.grid(kernel.grid)
    foldid <- .klp.prepare.foldid(nrow(X), foldid, cv.folds, cv.seed)

    cand <- expand.grid(
        support.size = support.grid,
        degree = degree.grid,
        kernel = kernel.grid,
        KEEP.OUT.ATTRS = FALSE,
        stringsAsFactors = FALSE
    )
    cv.result <- .klp.cv.table(
        X = X,
        y = y,
        foldid = foldid,
        cand = cand,
        coordinate.method = coordinate.method,
        chart.dim = chart.dim,
        local.chart.method = local.chart.method.effective,
        auto.chart.support.metric = auto.chart.support.metric,
        auto.chart.selection.metric = auto.chart.selection.metric,
        backend = backend.used
    )
    cv.table <- cv.result$cv.table
    best.idx <- .klp.select.best.idx(cv.table)
    selected <- cv.table[best.idx, , drop = FALSE]
    selected.dim <- .klp.resolve.chart.dim(
        X = X,
        support.size = selected$support.size[[1L]],
        degree = selected$degree[[1L]],
        coordinate.method = coordinate.method,
        chart.dim = chart.dim,
        auto.chart.support.metric = auto.chart.support.metric,
        auto.chart.selection.metric = auto.chart.selection.metric
    )
    selected.pred.dim <- .klp.resolve.prediction.chart.dim(
        X.train = X,
        X.eval = X.eval,
        support.size = selected$support.size[[1L]],
        degree = selected$degree[[1L]],
        coordinate.method = coordinate.method,
        chart.dim = chart.dim,
        auto.chart.support.metric = auto.chart.support.metric,
        auto.chart.selection.metric = auto.chart.selection.metric,
        summary.dim = selected.dim$chart.dim
    )
    fitted.result <- .klp.predict.local.polynomial(
        X.train = X,
        y.train = y,
        X.eval = X.eval,
        support.size = selected$support.size[[1L]],
        degree = selected$degree[[1L]],
        kernel = selected$kernel[[1L]],
        coordinate.method = coordinate.method,
        chart.dim = selected.pred.dim$chart.dim,
        chart.dim.by.eval = selected.pred.dim$chart.dim.by.eval,
        local.chart.method = local.chart.method.effective,
        backend = backend.used,
        return.chart.diagnostics = identical(local.chart.method.effective,
                                             "second.order.svd")
    )
    fitted <- if (is.list(fitted.result) &&
                  !is.null(fitted.result$predictions)) {
        fitted.result$predictions
    } else {
        fitted.result
    }
    chart.diagnostics <- if (is.list(fitted.result)) {
        fitted.result$chart.diagnostics
    } else {
        NULL
    }
    chart.diagnostics.summary <- if (is.list(fitted.result)) {
        fitted.result$chart.diagnostics.summary
    } else {
        .klp.local.chart.diagnostics.summary(
            NULL,
            local.chart.method.effective
        )
    }
    out <- list(
        method.id = "lps",
        method.family = "local_polynomial_smoother",
        method.label = "LPS",
        X = X,
        y = y,
        X.eval = X.eval,
        fitted.values = fitted,
        selected = selected,
        cv.table = cv.table,
        foldid = foldid,
        coordinate.method = coordinate.method,
        local.chart.method = local.chart.method,
        local.chart.method.effective = local.chart.method.effective,
        requested.chart.dim = chart.dim,
        chart.dim = selected.dim$chart.dim,
        local.chart.diagnostics = chart.diagnostics,
        local.chart.diagnostics.summary = chart.diagnostics.summary,
        auto.chart.dim = .klp.is.auto.chart.dim(chart.dim),
        auto.chart.dim.local = .klp.is.local.auto.chart.dim(chart.dim),
        chart.dim.mode = .klp.chart.dim.mode(chart.dim, coordinate.method),
        chart.dim.by.eval = selected.pred.dim$chart.dim.by.eval,
        auto.chart.dim.diagnostics = selected.dim$diagnostics,
        auto.chart.support.metric = auto.chart.support.metric,
        auto.chart.selection.metric = auto.chart.selection.metric,
        backend = backend,
        backend.used = backend.used,
        call = match.call()
    )
    class(out) <- c("lps", "list")
    out
}

#' @method predict lps
#' @export
predict.lps <- function(object, newdata = NULL, ...) {
    dots <- list(...)
    if (length(dots)) {
        stop("Unused arguments: ", paste(names(dots), collapse = ", "),
             call. = FALSE)
    }
    X.eval <- if (is.null(newdata)) object$X.eval else as.matrix(newdata)
    local.chart.method.effective <- if (!is.null(
        object$local.chart.method.effective
    )) {
        object$local.chart.method.effective
    } else if (identical(object$coordinate.method, "coordinates")) {
        "none"
    } else if (is.null(object$local.chart.method)) {
        "pca"
    } else {
        object$local.chart.method
    }
    pred.dim <- .klp.resolve.prediction.chart.dim(
        X.train = object$X,
        X.eval = X.eval,
        support.size = object$selected$support.size[[1L]],
        degree = object$selected$degree[[1L]],
        coordinate.method = object$coordinate.method,
        chart.dim = object$requested.chart.dim,
        auto.chart.support.metric = object$auto.chart.support.metric %||%
            "coordinates",
        auto.chart.selection.metric = object$auto.chart.selection.metric %||%
            "coordinates",
        summary.dim = object$chart.dim
    )
    .klp.predict.local.polynomial(
        X.train = object$X,
        y.train = object$y,
        X.eval = X.eval,
        support.size = object$selected$support.size[[1L]],
        degree = object$selected$degree[[1L]],
        kernel = object$selected$kernel[[1L]],
        coordinate.method = object$coordinate.method,
        chart.dim = pred.dim$chart.dim,
        chart.dim.by.eval = pred.dim$chart.dim.by.eval,
        local.chart.method = local.chart.method.effective,
        backend = if (is.null(object$backend.used)) "R" else object$backend.used
    )
}

#' @method print lps
#' @export
print.lps <- function(x, ...) {
    cat("Local polynomial smoother (LPS) fit\n")
    cat("  observations:", nrow(x$X), "\n")
    cat("  coordinate method:", x$coordinate.method, "\n")
    if (identical(x$coordinate.method, "local.pca")) {
        cat("  local chart method:",
            if (is.null(x$local.chart.method.effective)) {
                if (is.null(x$local.chart.method)) "pca" else x$local.chart.method
            } else {
                x$local.chart.method.effective
            },
            "\n")
    }
    cat("  backend:", if (is.null(x$backend.used)) "R" else x$backend.used, "\n")
    cat("  selected support.size:", x$selected$support.size[[1L]], "\n")
    cat("  selected degree:", x$selected$degree[[1L]], "\n")
    cat("  selected kernel:", x$selected$kernel[[1L]], "\n")
    cat("  selected CV RMSE:",
        signif(x$selected$cv.rmse.observed[[1L]], 5), "\n")
    invisible(x)
}

#' Report LPS Backend and Chart-Dimension Diagnostics
#'
#' Builds a compact one-row diagnostic table for a fitted local polynomial
#' smoother.  The table records the requested backend, the backend actually
#' used, the requested chart-dimension rule, the resolved chart dimension,
#' selected tuning parameters, and whether the fit follows the current
#' deployable local-PCA auto-dimension contract.
#'
#' The current backend policy is conservative: \code{backend = "auto"} uses the
#' C++ backend for ambient-coordinate LPS, but uses the R reference backend for
#' \code{coordinate.method = "local.pca"}.  The native local-PCA backend
#' \code{"cpp.local.pca"} remains an explicit opt-in backend.  This helper
#' makes that policy visible in reports and downstream experiment manifests
#' without changing the default.
#'
#' For real-data local-PCA runs, the deployable chart-dimension contract is
#' the ordinary \code{local.chart.method = "pca"} path with
#' \code{chart.dim = "auto"} or \code{"local.auto"} and observed-covariate
#' auto-dimension diagnostics.
#' In P7-style experiments this is paired with
#' \code{auto.chart.support.metric = "both"} and
#' \code{auto.chart.selection.metric = "operator"}.  The experimental
#' \code{"second.order.svd"} chart path is reported explicitly but is not
#' certified by this deployable local-PCA contract.  For LPS itself, which uses
#' coordinate supports, the operator-support diagnostic is currently equivalent
#' to the coordinate-support diagnostic; the fields are still recorded so the
#' same manifest schema can be shared with LPL-TF and S-LPL-TF experiments.
#'
#' @param object A fitted \code{"lps"} object.
#' @return A one-row \code{data.frame} with backend, chart-dimension, selection,
#'   candidate-count, and policy fields.
#' @export
lps.backend.diagnostics <- function(object) {
    if (!inherits(object, "lps")) {
        stop("'object' must be a fitted 'lps' object.", call. = FALSE)
    }
    selected <- object$selected
    selected.value <- function(name, default = NA) {
        if (is.null(selected) || !name %in% names(selected) ||
            !length(selected[[name]])) {
            return(default)
        }
        selected[[name]][[1L]]
    }
    requested.chart.dim <- object$requested.chart.dim
    requested.chart.dim.label <- if (is.null(requested.chart.dim)) {
        "NULL"
    } else {
        as.character(requested.chart.dim[[1L]])
    }
    auto.dim <- isTRUE(object$auto.chart.dim)
    local.auto.dim <- isTRUE(object$auto.chart.dim.local)
    coord.method <- object$coordinate.method %||% NA_character_
    backend.requested <- object$backend %||% NA_character_
    backend.used <- object$backend.used %||% NA_character_
    local.chart.method <- object$local.chart.method %||% NA_character_
    local.chart.method.effective <- object$local.chart.method.effective %||%
        NA_character_
    support.metric <- object$auto.chart.support.metric %||% NA_character_
    selection.metric <- object$auto.chart.selection.metric %||% NA_character_
    local.pca.real.data.contract <- identical(coord.method, "local.pca") &&
        identical(local.chart.method.effective, "pca") &&
        auto.dim &&
        identical(support.metric, "both") &&
        identical(selection.metric, "operator")
    backend.auto.policy <- if (identical(backend.requested, "auto")) {
        if (identical(coord.method, "coordinates")) {
            "auto_coordinates_cpp"
        } else if (identical(coord.method, "local.pca")) {
            "auto_local_pca_R_reference"
        } else {
            "auto_unknown"
        }
    } else if (identical(backend.requested, "cpp.local.pca")) {
        "explicit_local_pca_native_opt_in"
    } else {
        paste0("explicit_", backend.requested)
    }
    auto.summary <- object$auto.chart.dim.diagnostics$summary
    data.frame(
        method.id = object$method.id %||% "lps",
        coordinate.method = coord.method,
        local.chart.method = local.chart.method,
        local.chart.method.effective = local.chart.method.effective,
        backend.requested = backend.requested,
        backend.used = backend.used,
        backend.auto.policy = backend.auto.policy,
        requested.chart.dim = requested.chart.dim.label,
        resolved.chart.dim = as.integer(object$chart.dim %||% NA_integer_),
        chart.dim.auto = auto.dim,
        chart.dim.local.auto = local.auto.dim,
        chart.dim.mode = object$chart.dim.mode %||% NA_character_,
        chart.dim.by.eval.n = if (is.null(object$chart.dim.by.eval)) {
            NA_integer_
        } else {
            as.integer(length(object$chart.dim.by.eval))
        },
        chart.dim.by.eval.min = if (is.null(object$chart.dim.by.eval)) {
            NA_integer_
        } else {
            as.integer(min(object$chart.dim.by.eval, na.rm = TRUE))
        },
        chart.dim.by.eval.max = if (is.null(object$chart.dim.by.eval)) {
            NA_integer_
        } else {
            as.integer(max(object$chart.dim.by.eval, na.rm = TRUE))
        },
        auto.chart.support.metric = support.metric,
        auto.chart.selection.metric = selection.metric,
        auto.chart.support.metric.selected =
            auto.summary$support.metric %||% NA_character_,
        auto.chart.fallback.used =
            as.logical(auto.summary$fallback.used %||% NA),
        auto.chart.n.anchors =
            as.integer(auto.summary$n.anchors %||% NA_integer_),
        auto.chart.median.local.dim =
            as.numeric(auto.summary$median.local.dim %||% NA_real_),
        selected.support.size =
            as.integer(selected.value("support.size", NA_integer_)),
        selected.degree = as.integer(selected.value("degree", NA_integer_)),
        selected.kernel = as.character(selected.value("kernel", NA_character_)),
        selected.cv.rmse.observed =
            as.numeric(selected.value("cv.rmse.observed", NA_real_)),
        candidate.count = if (is.null(object$cv.table)) {
            NA_integer_
        } else {
            as.integer(nrow(object$cv.table))
        },
        local.pca.real.data.contract = local.pca.real.data.contract,
        stringsAsFactors = FALSE
    )
}

.klp.rmse <- function(x, y) {
    sqrt(mean((as.numeric(x) - as.numeric(y))^2, na.rm = TRUE))
}

.klp.select.best.idx <- function(cv.table, tolerance = 1e-12) {
    finite <- is.finite(cv.table$cv.rmse.observed)
    if (!any(finite)) {
        return(order(
            cv.table$cv.rmse.observed,
            cv.table$support.size,
            cv.table$degree,
            cv.table$kernel
        )[[1L]])
    }
    best <- min(cv.table$cv.rmse.observed[finite])
    eligible <- which(
        finite &
            cv.table$cv.rmse.observed <=
                best + max(tolerance, tolerance * abs(best))
    )
    eligible[order(
        cv.table$support.size[eligible],
        cv.table$degree[eligible],
        cv.table$kernel[eligible],
        cv.table$cv.rmse.observed[eligible]
    )[[1L]]]
}

.klp.cv.table <- function(X, y, foldid, cand, coordinate.method, chart.dim,
                          local.chart.method = "pca",
                          auto.chart.support.metric,
                          auto.chart.selection.metric,
                          backend = "R") {
    cand$chart.dim <- NA_integer_
    local.auto.dim <- .klp.is.local.auto.chart.dim(chart.dim)
    if (identical(coordinate.method, "coordinates") &&
        identical(backend, "cpp")) {
        cand$chart.dim <- ncol(X)
        cand$cv.rmse.observed <- rcpp_kernel_local_polynomial_cv_coordinates(
            X = X,
            y = y,
            foldid = foldid,
            support_size = cand$support.size,
            degree = cand$degree,
            kernel = cand$kernel
        )
        return(list(cv.table = cand, predictions = NULL))
    }
    dim.lookup <- list()
    combos <- unique(cand[, c("support.size", "degree"), drop = FALSE])
    for (ii in seq_len(nrow(combos))) {
        info <- .klp.resolve.chart.dim(
            X = X,
            support.size = combos$support.size[[ii]],
            degree = combos$degree[[ii]],
            coordinate.method = coordinate.method,
            chart.dim = chart.dim,
            auto.chart.support.metric = auto.chart.support.metric,
            auto.chart.selection.metric = auto.chart.selection.metric
        )
        key <- paste(combos$support.size[[ii]], combos$degree[[ii]], sep = "_")
        dim.lookup[[key]] <- info$chart.dim
    }
    for (rr in seq_len(nrow(cand))) {
        key <- paste(cand$support.size[[rr]], cand$degree[[rr]], sep = "_")
        cand$chart.dim[[rr]] <- dim.lookup[[key]]
    }
    if (identical(coordinate.method, "local.pca") &&
        identical(local.chart.method, "pca") &&
        identical(backend, "cpp.local.pca")) {
        cand$cv.rmse.observed <- rcpp_kernel_local_polynomial_cv_local_pca(
            X = X,
            y = y,
            foldid = foldid,
            support_size = cand$support.size,
            degree = cand$degree,
            kernel = cand$kernel,
            chart_dim = cand$chart.dim
        )
        return(list(cv.table = cand, predictions = NULL))
    }
    pred <- matrix(NA_real_, nrow = length(y), ncol = nrow(cand))
    support.sizes <- sort(unique(cand$support.size))
    max.support.size <- max(support.sizes)
    for (fold in sort(unique(foldid))) {
        test <- which(foldid == fold)
        train <- which(foldid != fold)
        X.train <- X[train, , drop = FALSE]
        y.train <- y[train]
        fold.max.support <- min(max.support.size, length(train))
        for (ii in seq_along(test)) {
            target <- test[[ii]]
            center <- X[target, , drop = TRUE]
            ordered <- .klp.local.order(
                X.train = X.train,
                center = center,
                support.size = fold.max.support
            )
            for (support.size in support.sizes) {
                effective.support <- min(as.integer(support.size),
                                         length(ordered$distances))
                support.rows <- which(cand$support.size == support.size)
                chart.dim.by.degree <- NULL
                if (local.auto.dim) {
                    degrees <- sort(unique(cand$degree[support.rows]))
                    chart.dim.by.degree <- vapply(
                        degrees,
                        function(degree) .klp.local.auto.chart.dim.from.order(
                            X.train = X.train,
                            center = center,
                            ordered = ordered,
                            support.size = support.size,
                            degree = degree
                        ),
                        integer(1L)
                    )
                    names(chart.dim.by.degree) <- as.character(degrees)
                    max.chart.dim <- max(chart.dim.by.degree, na.rm = TRUE)
                } else {
                    max.chart.dim <- max(cand$chart.dim[support.rows],
                                         na.rm = TRUE)
                }
                kernel.names <- unique(cand$kernel[support.rows])
                if (!identical(local.chart.method, "second.order.svd")) {
                    local <- .klp.local.neighborhood.from.order(
                        X.train = X.train,
                        y.train = y.train,
                        center = center,
                        ordered = ordered,
                        support.size = support.size,
                        coordinate.method = coordinate.method,
                        chart.dim = max.chart.dim,
                        local.chart.method = local.chart.method
                    )
                }
                kernel.weights <- lapply(
                    kernel.names,
                    function(kernel) .klp.kernel.weights(
                        ordered$distances[seq_len(effective.support)],
                        kernel
                    )
                )
                names(kernel.weights) <- kernel.names
                if (!identical(local.chart.method, "second.order.svd")) {
                    design.cache <- new.env(parent = emptyenv())
                    for (rr in support.rows) {
                        w <- kernel.weights[[cand$kernel[[rr]]]]
                        fit.chart.dim <- if (local.auto.dim) {
                            chart.dim.by.degree[[as.character(cand$degree[[rr]])]]
                        } else {
                            cand$chart.dim[[rr]]
                        }
                        pred[target, rr] <- .klp.fit.intercept.lazy(
                            z = local$z,
                            y = local$y,
                            weights = w,
                            degree = cand$degree[[rr]],
                            chart.dim = fit.chart.dim,
                            design.cache = design.cache
                        )
                    }
                } else {
                    for (rr in support.rows) {
                        w <- kernel.weights[[cand$kernel[[rr]]]]
                        fit.chart.dim <- cand$chart.dim[[rr]]
                        local <- .klp.local.neighborhood.from.order(
                            X.train = X.train,
                            y.train = y.train,
                            center = center,
                            ordered = ordered,
                            support.size = support.size,
                            coordinate.method = coordinate.method,
                            chart.dim = fit.chart.dim,
                            local.chart.method = local.chart.method,
                            chart.weights = w
                        )
                        pred[target, rr] <- .klp.fit.intercept.lazy(
                            z = local$z,
                            y = local$y,
                            weights = w,
                            degree = cand$degree[[rr]],
                            chart.dim = fit.chart.dim,
                            design.cache = new.env(parent = emptyenv())
                        )
                    }
                }
            }
        }
    }
    cv.table <- cand
    cv.table$cv.rmse.observed <- vapply(
        seq_len(ncol(pred)),
        function(j) .klp.rmse(pred[, j], y),
        numeric(1L)
    )
    list(cv.table = cv.table, predictions = pred)
}

.klp.clean.support.grid <- function(support.grid, n) {
    out <- sort(unique(as.integer(support.grid)))
    out <- out[is.finite(out) & out >= 2L & out <= n]
    if (!length(out)) {
        stop("'support.grid' has no valid support sizes.", call. = FALSE)
    }
    out
}

.klp.clean.degree.grid <- function(degree.grid) {
    out <- sort(unique(as.integer(degree.grid)))
    out <- out[is.finite(out) & out %in% 0:2]
    if (!length(out)) {
        stop("'degree.grid' must contain at least one of 0, 1, or 2.",
             call. = FALSE)
    }
    out
}

.klp.clean.kernel.grid <- function(kernel.grid) {
    allowed <- c("gaussian", "tricube", "epanechnikov", "triangular")
    out <- unique(as.character(kernel.grid))
    out <- out[nzchar(out)]
    if (!length(out) || any(!out %in% allowed)) {
        stop("'kernel.grid' contains unsupported kernels.", call. = FALSE)
    }
    out
}

.klp.prepare.foldid <- function(n, foldid, cv.folds, cv.seed) {
    if (!is.null(foldid)) {
        if (!is.numeric(foldid) || length(foldid) != n ||
            any(is.na(foldid)) || any(foldid != as.integer(foldid)) ||
            any(foldid < 1L)) {
            stop("'foldid' must be a positive integer vector of length nrow(X).",
                 call. = FALSE)
        }
        return(as.integer(foldid))
    }
    cv.folds <- as.integer(cv.folds)
    if (!is.finite(cv.folds) || cv.folds < 2L || cv.folds > n) {
        stop("'cv.folds' must be an integer between 2 and nrow(X).",
             call. = FALSE)
    }
    set.seed(cv.seed)
    sample(rep(seq_len(cv.folds), length.out = n))
}

.klp.resolve.backend <- function(coordinate.method, backend,
                                 local.chart.method = "none") {
    if (identical(backend, "auto")) {
        return(if (identical(coordinate.method, "coordinates")) "cpp" else "R")
    }
    if (identical(backend, "cpp")) {
        if (!identical(coordinate.method, "coordinates")) {
            stop("'backend = \"cpp\"' currently supports only ",
                 "coordinate.method = 'coordinates'.", call. = FALSE)
        }
    }
    if (identical(backend, "cpp.local.pca")) {
        if (!identical(coordinate.method, "local.pca") ||
            !identical(local.chart.method, "pca")) {
            stop("'backend = \"cpp.local.pca\"' requires ",
                 "coordinate.method = 'local.pca' and ",
                 "local.chart.method = 'pca'.", call. = FALSE)
        }
    }
    backend
}

.klp.is.local.auto.chart.dim <- function(chart.dim) {
    identical(chart.dim, "local.auto")
}

.klp.is.auto.chart.dim <- function(chart.dim) {
    identical(chart.dim, "auto") || .klp.is.local.auto.chart.dim(chart.dim)
}

.klp.chart.dim.mode <- function(chart.dim, coordinate.method) {
    if (!identical(coordinate.method, "local.pca")) return("ambient")
    if (is.null(chart.dim)) return("ambient.default")
    if (identical(chart.dim, "auto")) return("global.auto")
    if (.klp.is.local.auto.chart.dim(chart.dim)) return("local.auto")
    "fixed"
}

.klp.resolve.chart.dim <- function(X, support.size, degree, coordinate.method,
                                   chart.dim, auto.chart.support.metric,
                                   auto.chart.selection.metric) {
    if (identical(coordinate.method, "coordinates")) {
        if (!is.null(chart.dim) &&
            !(length(chart.dim) == 1L && is.numeric(chart.dim) &&
              as.integer(chart.dim) == ncol(X))) {
            stop("'chart.dim' must be NULL when coordinate.method = 'coordinates'.",
                 call. = FALSE)
        }
        return(list(chart.dim = ncol(X), diagnostics = NULL))
    }
    if (is.null(chart.dim)) {
        return(list(chart.dim = ncol(X), diagnostics = NULL))
    }
    if (identical(chart.dim, "auto")) {
        diagnostics <- .local.pca.auto.chart.dim.with.metric(
            X = X,
            support.size = support.size,
            degree = degree,
            operator.support.metric = "coordinates",
            auto.chart.support.metric = auto.chart.support.metric,
            auto.chart.selection.metric = auto.chart.selection.metric
        )
        return(list(chart.dim = diagnostics$chart.dim,
                    diagnostics = diagnostics))
    }
    if (.klp.is.local.auto.chart.dim(chart.dim)) {
        diagnostics <- .local.pca.auto.chart.dim.with.metric(
            X = X,
            support.size = support.size,
            degree = degree,
            max.anchors = nrow(X),
            operator.support.metric = "coordinates",
            auto.chart.support.metric = auto.chart.support.metric,
            auto.chart.selection.metric = auto.chart.selection.metric
        )
        return(list(chart.dim = diagnostics$chart.dim,
                    diagnostics = diagnostics))
    }
    dim <- as.integer(chart.dim)
    if (!is.finite(dim) || dim < 1L || dim > ncol(X)) {
        stop("'chart.dim' must be between 1 and ncol(X), 'auto', ",
             "or 'local.auto'.",
             call. = FALSE)
    }
    list(chart.dim = dim, diagnostics = NULL)
}

.klp.resolve.prediction.chart.dim <- function(
    X.train, X.eval, support.size, degree, coordinate.method, chart.dim,
    auto.chart.support.metric, auto.chart.selection.metric, summary.dim) {

    if (!.klp.is.local.auto.chart.dim(chart.dim)) {
        return(list(chart.dim = as.integer(summary.dim),
                    chart.dim.by.eval = NULL))
    }
    dims <- vapply(seq_len(nrow(X.eval)), function(i) {
        ordered <- .klp.local.order(
            X.train = X.train,
            center = X.eval[i, , drop = TRUE],
            support.size = support.size
        )
        .klp.local.auto.chart.dim.from.order(
            X.train = X.train,
            center = X.eval[i, , drop = TRUE],
            ordered = ordered,
            support.size = support.size,
            degree = degree
        )
    }, integer(1L))
    dims[!is.finite(dims) | dims < 1L] <- as.integer(summary.dim)
    list(
        chart.dim = as.integer(max(dims, na.rm = TRUE)),
        chart.dim.by.eval = as.integer(dims)
    )
}

.klp.local.auto.chart.dim.from.order <- function(
    X.train, center, ordered, support.size, degree) {

    support.size <- min(as.integer(support.size), length(ordered$index))
    if (!is.finite(support.size) || support.size < 1L) return(1L)
    idx <- ordered$index[seq_len(support.size)]
    centered <- sweep(X.train[idx, , drop = FALSE], 2L, center, "-")
    sv <- tryCatch(svd(centered, nu = 0L, nv = 0L)$d,
                   error = function(e) numeric(0))
    row <- .local.pca.auto.chart.dim.from.singular.values(
        sv = sv,
        n.support = length(idx),
        degree = degree,
        ambient.dim = ncol(X.train),
        support.metric = "coordinates",
        anchor = 1L
    )
    dim <- as.integer(row$selected.local.dim[[1L]])
    if (!is.finite(dim) || dim < 1L) {
        dim <- min(
            ncol(X.train),
            .local.pca.max.chart.dim.for.support(
                n.support = max(1L, length(idx) - 1L),
                degree = degree,
                ambient.dim = ncol(X.train)
            )
        )
    }
    as.integer(max(1L, min(ncol(X.train), dim)))
}

.klp.predict.local.polynomial <- function(X.train, y.train, X.eval,
                                          support.size, degree, kernel,
                                          coordinate.method, chart.dim,
                                          chart.dim.by.eval = NULL,
                                          local.chart.method = "pca",
                                          backend = "R",
                                          return.chart.diagnostics = FALSE) {
    X.train <- as.matrix(X.train)
    X.eval <- as.matrix(X.eval)
    y.train <- as.numeric(y.train)
    support.size <- min(as.integer(support.size), nrow(X.train))
    if (identical(coordinate.method, "coordinates") &&
        identical(backend, "cpp")) {
        return(rcpp_kernel_local_polynomial_predict_coordinates(
            X_train = X.train,
            y_train = y.train,
            X_eval = X.eval,
            support_size = support.size,
            degree = as.integer(degree),
            kernel = kernel
        ))
    }
    if (identical(coordinate.method, "local.pca") &&
        identical(local.chart.method, "pca") &&
        identical(backend, "cpp.local.pca") &&
        is.null(chart.dim.by.eval) &&
        !return.chart.diagnostics) {
        return(rcpp_kernel_local_polynomial_predict_local_pca(
            X_train = X.train,
            y_train = y.train,
            X_eval = X.eval,
            support_size = support.size,
            degree = as.integer(degree),
            kernel = kernel,
            chart_dim = as.integer(chart.dim)
        ))
    }
    out <- rep(NA_real_, nrow(X.eval))
    diagnostics <- vector("list", nrow(X.eval))
    for (i in seq_len(nrow(X.eval))) {
        fit.chart.dim <- if (is.null(chart.dim.by.eval)) {
            as.integer(chart.dim)
        } else {
            as.integer(chart.dim.by.eval[[i]])
        }
        center <- X.eval[i, , drop = TRUE]
        d <- sqrt(rowSums((X.train -
            matrix(center, nrow(X.train), ncol(X.train), byrow = TRUE))^2))
        idx <- order(d, seq_along(d))[seq_len(support.size)]
        local.d <- d[idx]
        weights <- .klp.kernel.weights(local.d, kernel)
        if (!any(weights > 0)) weights[] <- 1
        local.coords <- .klp.local.coordinates(
            X.support = X.train[idx, , drop = FALSE],
            center = center,
            coordinate.method = coordinate.method,
            chart.dim = fit.chart.dim,
            local.chart.method = local.chart.method,
            weights = weights,
            return.chart = return.chart.diagnostics
        )
        if (is.list(local.coords) &&
            !is.null(local.coords$coordinates)) {
            z <- local.coords$coordinates
            diagnostics[[i]] <- .klp.local.chart.diagnostics.row(
                eval.index = i,
                chart = local.coords$chart
            )
        } else {
            z <- local.coords
        }
        design <- .local.polynomial.design.matrix(z, degree)
        design.ok <- rowSums(is.finite(design)) == ncol(design)
        ok <- is.finite(y.train[idx]) & is.finite(weights) &
            weights > 0 & design.ok
        if (sum(ok) < ncol(design)) {
            out[[i]] <- stats::weighted.mean(y.train[idx], weights,
                                             na.rm = TRUE)
            next
        }
        fit <- tryCatch(
            stats::lm.wfit(design[ok, , drop = FALSE],
                           y.train[idx][ok], weights[ok]),
            error = function(e) NULL
        )
        out[[i]] <- if (is.null(fit) || !length(fit$coefficients) ||
                         !is.finite(fit$coefficients[[1L]])) {
            stats::weighted.mean(y.train[idx], weights, na.rm = TRUE)
        } else {
            fit$coefficients[[1L]]
        }
    }
    if (!return.chart.diagnostics) return(out)
    diagnostics <- do.call(rbind, diagnostics)
    list(
        predictions = out,
        chart.diagnostics = diagnostics,
        chart.diagnostics.summary = .klp.local.chart.diagnostics.summary(
            diagnostics,
            local.chart.method
        )
    )
}

.klp.local.neighborhood <- function(X.train, y.train, center, support.size,
                                    coordinate.method, chart.dim,
                                    local.chart.method = "pca",
                                    chart.weights = NULL,
                                    return.chart = FALSE) {
    ordered <- .klp.local.order(
        X.train = X.train,
        center = center,
        support.size = support.size
    )
    .klp.local.neighborhood.from.order(
        X.train = X.train,
        y.train = y.train,
        center = center,
        ordered = ordered,
        support.size = support.size,
        coordinate.method = coordinate.method,
        chart.dim = chart.dim,
        local.chart.method = local.chart.method,
        chart.weights = chart.weights,
        return.chart = return.chart
    )
}

.klp.local.order <- function(X.train, center, support.size) {
    d <- sqrt(rowSums((X.train -
        matrix(center, nrow(X.train), ncol(X.train), byrow = TRUE))^2))
    idx <- order(d, seq_along(d))[seq_len(min(as.integer(support.size),
                                             nrow(X.train)))]
    list(index = idx, distances = d[idx])
}

.klp.local.neighborhood.from.order <- function(X.train, y.train, center,
                                               ordered, support.size,
                                               coordinate.method, chart.dim,
                                               local.chart.method = "pca",
                                               chart.weights = NULL,
                                               return.chart = FALSE) {
    support.size <- min(as.integer(support.size), length(ordered$index))
    idx <- ordered$index[seq_len(support.size)]
    distances <- ordered$distances[seq_len(support.size)]
    coords <- .klp.local.coordinates(
        X.support = X.train[idx, , drop = FALSE],
        center = center,
        coordinate.method = coordinate.method,
        chart.dim = chart.dim,
        local.chart.method = local.chart.method,
        weights = chart.weights,
        return.chart = return.chart
    )
    z <- if (is.list(coords) && !is.null(coords$coordinates)) {
        coords$coordinates
    } else {
        coords
    }
    list(
        index = idx,
        distances = distances,
        y = y.train[idx],
        z = z,
        chart = if (is.list(coords)) coords$chart else NULL
    )
}

.klp.fit.intercept <- function(z, y, weights, degree) {
    .klp.fit.intercept.lazy(
        z = z,
        y = y,
        weights = weights,
        degree = degree,
        chart.dim = ncol(z),
        design.cache = new.env(parent = emptyenv())
    )
}

.klp.fit.intercept.lazy <- function(z, y, weights, degree, chart.dim,
                                    design.cache) {
    ok <- is.finite(y) & is.finite(weights) & weights > 0
    if (!any(weights > 0)) {
        weights[] <- 1
        ok <- is.finite(y) & is.finite(weights) & weights > 0
    }
    n.design <- .klp.design.ncol(degree, chart.dim)
    if (sum(ok) < n.design) {
        return(stats::weighted.mean(y, weights, na.rm = TRUE))
    }
    design <- .klp.get.local.design(z, degree, chart.dim, design.cache)
    .klp.fit.intercept.design(design, y, weights)
}

.klp.fit.intercept.design <- function(design, y, weights) {
    design.ok <- rowSums(is.finite(design)) == ncol(design)
    ok <- is.finite(y) & is.finite(weights) & weights > 0 & design.ok
    if (!any(weights > 0)) {
        weights[] <- 1
        ok <- is.finite(y) & is.finite(weights) & weights > 0 & design.ok
    }
    if (sum(ok) < ncol(design)) {
        return(stats::weighted.mean(y, weights, na.rm = TRUE))
    }
    fit <- tryCatch(
        stats::lm.wfit(design[ok, , drop = FALSE], y[ok], weights[ok]),
        error = function(e) NULL
    )
    if (is.null(fit) || !length(fit$coefficients) ||
        !is.finite(fit$coefficients[[1L]])) {
        stats::weighted.mean(y, weights, na.rm = TRUE)
    } else {
        fit$coefficients[[1L]]
    }
}

.klp.design.ncol <- function(degree, chart.dim) {
    degree <- as.integer(degree)
    chart.dim <- as.integer(chart.dim)
    if (degree == 0L) return(1L)
    if (degree == 1L) return(1L + chart.dim)
    if (degree == 2L) return(1L + chart.dim + chart.dim * (chart.dim + 1L) / 2L)
    stop("Unsupported local polynomial degree: ", degree, call. = FALSE)
}

.klp.design.cache.key <- function(degree, chart.dim) {
    paste(as.integer(degree), as.integer(chart.dim), sep = "_")
}

.klp.get.local.design <- function(z, degree, chart.dim, design.cache) {
    key <- .klp.design.cache.key(degree, chart.dim)
    if (!exists(key, envir = design.cache, inherits = FALSE)) {
        design <- .local.polynomial.design.matrix(
            z[, seq_len(chart.dim), drop = FALSE],
            degree
        )
        assign(key, design, envir = design.cache)
    }
    get(key, envir = design.cache, inherits = FALSE)
}

.klp.local.design.cache <- function(z, cand, rows) {
    combos <- unique(cand[rows, c("degree", "chart.dim"), drop = FALSE])
    out <- new.env(parent = emptyenv())
    for (ii in seq_len(nrow(combos))) {
        dim <- combos$chart.dim[[ii]]
        degree <- combos$degree[[ii]]
        .klp.get.local.design(z, degree, dim, out)
    }
    out
}

.klp.local.coordinates <- function(X.support, center, coordinate.method,
                                   chart.dim, local.chart.method = "pca",
                                   weights = NULL,
                                   return.chart = FALSE) {
    centered <- sweep(X.support, 2L, center, "-")
    if (identical(coordinate.method, "coordinates")) {
        if (return.chart) {
            return(list(coordinates = centered, chart = NULL))
        }
        return(centered)
    }
    if (identical(local.chart.method, "second.order.svd")) {
        chart <- rcpp_local_second_order_svd_chart(
            X_support = X.support,
            center = center,
            chart_dim = as.integer(chart.dim),
            center_mode = "anchor",
            weights = weights,
            rebase_to_anchor = TRUE,
            orient_basis = FALSE
        )
    } else {
        chart <- rcpp_local_pca_chart(
            X_support = X.support,
            center = center,
            chart_dim = as.integer(chart.dim),
            center_mode = "anchor",
            dim_rule = "fixed",
            rebase_to_anchor = TRUE,
            orient_basis = FALSE
        )
    }
    if (return.chart) {
        return(list(coordinates = chart$coordinates, chart = chart))
    }
    chart$coordinates
}

.klp.local.chart.scalar <- function(x, name, default) {
    if (is.null(x) || is.null(x[[name]]) || !length(x[[name]])) {
        return(default)
    }
    x[[name]][[1L]]
}

.klp.local.chart.diagnostics.row <- function(eval.index, chart) {
    if (is.null(chart)) return(NULL)
    diag <- chart$curvature.diagnostics
    data.frame(
        eval.index = as.integer(eval.index),
        local.chart.method = "second.order.svd",
        fallback.used = as.logical(.klp.local.chart.scalar(
            chart, "fallback.used", NA
        )),
        fallback.reason = as.character(.klp.local.chart.scalar(
            chart, "fallback.reason", NA_character_
        )),
        primary.failure.reason = as.character(.klp.local.chart.scalar(
            chart, "primary.failure.reason", NA_character_
        )),
        effective.support = as.integer(.klp.local.chart.scalar(
            diag, "effective.support", NA_integer_
        )),
        quadratic.ncol = as.integer(.klp.local.chart.scalar(
            diag, "quadratic.ncol", NA_integer_
        )),
        design.rank = as.integer(.klp.local.chart.scalar(
            diag, "design.rank", NA_integer_
        )),
        design.condition = as.numeric(.klp.local.chart.scalar(
            diag, "design.condition", NA_real_
        )),
        fit.method = as.character(.klp.local.chart.scalar(
            diag, "fit.method", NA_character_
        )),
        ridge.lambda = as.numeric(.klp.local.chart.scalar(
            diag, "ridge.lambda", NA_real_
        )),
        fit.residual.frobenius = as.numeric(.klp.local.chart.scalar(
            diag, "fit.residual.frobenius", NA_real_
        )),
        curvature.fitted.frobenius = as.numeric(.klp.local.chart.scalar(
            diag, "curvature.fitted.frobenius", NA_real_
        )),
        corrected.residual.frobenius = as.numeric(.klp.local.chart.scalar(
            diag, "corrected.residual.frobenius", NA_real_
        )),
        first.rank = as.integer(.klp.local.chart.scalar(
            diag, "first.rank", NA_integer_
        )),
        second.rank = as.integer(.klp.local.chart.scalar(
            diag, "second.rank", NA_integer_
        )),
        plain.pca.fallback.feasible = as.logical(.klp.local.chart.scalar(
            diag, "plain.pca.fallback.feasible", NA
        )),
        status = as.character(.klp.local.chart.scalar(
            diag, "status", NA_character_
        )),
        stringsAsFactors = FALSE
    )
}

.klp.local.chart.diagnostics.summary <- function(diagnostics,
                                                 local.chart.method) {
    empty.reasons <- data.frame(
        fallback.reason = character(0),
        count = integer(0),
        stringsAsFactors = FALSE
    )
    if (is.null(diagnostics) || !nrow(diagnostics)) {
        return(list(
            local.chart.method = local.chart.method,
            n.charts = 0L,
            fallback.count = 0L,
            fallback.rate = 0,
            fallback.reasons = empty.reasons,
            any.fallback.used = FALSE,
            any.pca.fallback.used = FALSE,
            any.structured.failure = FALSE,
            min.design.rank = NA_integer_,
            median.design.rank = NA_real_,
            max.design.rank = NA_integer_,
            median.design.condition = NA_real_,
            max.design.condition = NA_real_
        ))
    }
    fallback.used <- as.logical(diagnostics$fallback.used)
    fallback.used[is.na(fallback.used)] <- FALSE
    fallback.count <- sum(fallback.used)
    reasons <- diagnostics$fallback.reason[fallback.used]
    reasons <- reasons[!is.na(reasons) & nzchar(reasons)]
    fallback.reasons <- if (length(reasons)) {
        tab <- sort(table(reasons), decreasing = TRUE)
        data.frame(
            fallback.reason = names(tab),
            count = as.integer(tab),
            stringsAsFactors = FALSE
        )
    } else {
        empty.reasons
    }
    condition <- as.numeric(diagnostics$design.condition)
    condition <- condition[is.finite(condition)]
    design.rank <- as.numeric(diagnostics$design.rank)
    design.rank <- design.rank[is.finite(design.rank)]
    pca.fallback.used <- fallback.used &
        !is.na(diagnostics$fallback.reason) &
        diagnostics$fallback.reason != "none" &
        diagnostics$fallback.reason != "plain_pca_fallback_not_feasible"
    structured.failure <- fallback.used &
        !is.na(diagnostics$fallback.reason) &
        diagnostics$fallback.reason == "plain_pca_fallback_not_feasible"
    list(
        local.chart.method = local.chart.method,
        n.charts = nrow(diagnostics),
        fallback.count = as.integer(fallback.count),
        fallback.rate = fallback.count / nrow(diagnostics),
        fallback.reasons = fallback.reasons,
        any.fallback.used = fallback.count > 0L,
        any.pca.fallback.used = any(pca.fallback.used),
        any.structured.failure = any(structured.failure),
        min.design.rank = if (length(design.rank)) {
            as.integer(min(design.rank))
        } else {
            NA_integer_
        },
        median.design.rank = if (length(design.rank)) {
            stats::median(design.rank)
        } else {
            NA_real_
        },
        max.design.rank = if (length(design.rank)) {
            as.integer(max(design.rank))
        } else {
            NA_integer_
        },
        median.design.condition = if (length(condition)) {
            stats::median(condition)
        } else {
            NA_real_
        },
        max.design.condition = if (length(condition)) {
            max(condition)
        } else {
            NA_real_
        }
    )
}

.klp.kernel.weights <- function(distances, kernel) {
    if (!length(distances)) return(numeric(0))
    h <- max(distances[is.finite(distances)], 0)
    if (!is.finite(h) || h <= 0) h <- 1
    u <- as.numeric(distances) / (h + sqrt(.Machine$double.eps))
    w <- switch(
        kernel,
        gaussian = exp(-0.5 * u^2),
        tricube = ifelse(u < 1, (1 - u^3)^3, 0),
        epanechnikov = pmax(0, 1 - u^2),
        triangular = pmax(0, 1 - u)
    )
    w[!is.finite(w)] <- 0
    as.numeric(w)
}
