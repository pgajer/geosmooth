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
#' @param design.basis Local polynomial design backend. \code{"monomial"} uses
#'   the ordinary raw monomial design. \code{"weighted.qr"} solves the same
#'   design using an explicit weighted-QR numerical path. \code{"weighted.qr.drop"}
#'   first drops numerically dependent local design columns by weighted QR before
#'   solving. \code{"orthogonal.polynomial.drop"} replaces the local monomial
#'   design by a weighted-orthogonal basis spanning its estimable polynomial
#'   directions, dropping numerically rank-deficient directions first.
#' @param design.drop.tol Relative QR tolerance used by
#'   \code{design.basis = "weighted.qr.drop"} or
#'   \code{design.basis = "orthogonal.polynomial.drop"}.
#' @param ridge.multiplier.grid Nonnegative scale-relative ridge multipliers
#'   tried by the R local-solve backend. The smallest multiplier whose
#'   penalized local normal equations pass \code{ridge.condition.max} is used.
#' @param ridge.condition.max Maximum allowed condition number for the
#'   penalized local normal equations. Use \code{Inf} to disable this guard.
#' @param unstable.action Action when no local solve passes the rank and
#'   condition guards. \code{"mean"} preserves the historical weighted-mean
#'   fallback. \code{"na"} returns \code{NA}, causing CV candidates with
#'   unstable predictions to be avoided.
#' @param outcome.family Response family. \code{"gaussian"} preserves the
#'   ordinary numeric-response LPS behavior. \code{"bernoulli"} treats
#'   \code{0/1} responses as numeric conditional-expectation targets for
#'   \eqn{\Pr(Y=1\mid X)}, keeps the same local least-squares fitting core,
#'   clips reported response-scale probabilities to \code{[0,1]}, and records
#'   Brier/log-loss probability diagnostics. \code{"binomial"} uses local
#'   weighted logistic polynomial fits, selects candidates by observed CV log
#'   loss, and reports probability diagnostics on the fitted probabilities.
#' @param bandwidth.multiplier.grid Nonnegative bandwidth multipliers added to
#'   the CV candidate grid. For a candidate with multiplier \eqn{b}, the local
#'   kernel bandwidth becomes \eqn{h = b \cdot d_{(K)}} where \eqn{d_{(K)}} is
#'   the distance to the \eqn{K}-th nearest support neighbor, decoupling the
#'   kernel scale from the support size. The default \code{1} reproduces the
#'   historical behavior exactly (the bandwidth equals the support radius).
#'   Any grid other than exactly \code{1} requires the R reference backend:
#'   \code{backend = "auto"} then resolves to \code{"R"}, and explicit
#'   \code{backend = "cpp"} or \code{"cpp.local.pca"} is an error. The
#'   selected multiplier is returned in \code{$selected$bandwidth.multiplier}
#'   and as a \code{bandwidth.multiplier} column of \code{cv.table}.
#' @return A list of class \code{"lps"} with response-scale
#'   \code{fitted.values}, unmodified local least-squares
#'   \code{fitted.values.raw}, selected parameters, a candidate CV table, the
#'   requested \code{local.chart.method}, and the effective chart method used
#'   for reporting.  In \code{outcome.family = "bernoulli"} or
#'   \code{"binomial"} mode, \code{fitted.values} are response-scale
#'   probabilities in \code{[0,1]},
#'   \code{fitted.values.raw} are the un-clipped conditional-expectation
#'   estimates for \code{"bernoulli"} and the fitted probabilities for
#'   \code{"binomial"}, \code{cv.table$cv.brier.observed} is
#'   \code{cv.table$cv.rmse.observed^2}, and
#'   \code{probability.diagnostics} records raw/clipped probability ranges,
#'   out-of-range fractions, and Brier/log-loss diagnostics.  The Brier and
#'   log-loss diagnostics are defined only when the fitted predictions have the
#'   same length as the training response, which is the default
#'   \code{X.eval = X} path.  In \code{"binomial"} mode,
#'   \code{logistic.diagnostics} records local logistic solve attempts,
#'   convergence statuses, fallback-path counts, event-rate fallback counts,
#'   and \code{NA} failure counts separately for CV and final fitting.
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
    backend = c("auto", "R", "cpp", "cpp.local.pca"),
    design.basis = c("orthogonal.polynomial.drop", "monomial",
                     "weighted.qr", "weighted.qr.drop"),
    design.drop.tol = 1e-8,
    ridge.multiplier.grid = c(0, 1e-10, 1e-8),
    ridge.condition.max = 1e12,
    unstable.action = c("na", "mean"),
    outcome.family = c("gaussian", "bernoulli", "binomial"),
    bandwidth.multiplier.grid = 1) {

    X <- as.matrix(X)
    y <- as.numeric(y)
    outcome.family <- match.arg(outcome.family)
    if (!is.numeric(X) || !length(X) || any(!is.finite(X))) {
        stop("'X' must be a finite numeric matrix.", call. = FALSE)
    }
    if (length(y) != nrow(X) || any(!is.finite(y))) {
        stop("'y' must be a finite numeric vector with length nrow(X).",
             call. = FALSE)
    }
    .klp.validate.outcome.family(y, outcome.family)
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
    design.basis <- match.arg(design.basis)
    unstable.action <- match.arg(unstable.action)
    design.drop.tol <- .klp.validate.nonnegative.scalar(
        design.drop.tol,
        "design.drop.tol"
    )
    ridge.multiplier.grid <- .klp.clean.ridge.multiplier.grid(
        ridge.multiplier.grid
    )
    ridge.condition.max <- .klp.validate.positive.scalar(
        ridge.condition.max,
        "ridge.condition.max",
        allow.infinite = TRUE
    )
    bandwidth.multiplier.grid <- .klp.clean.bandwidth.multiplier.grid(
        bandwidth.multiplier.grid
    )
    auto.chart.support.metric <- match.arg(auto.chart.support.metric)
    auto.chart.selection.metric <- match.arg(auto.chart.selection.metric)
    backend.used <- .klp.resolve.backend(
        coordinate.method,
        backend,
        local.chart.method.effective,
        design.basis,
        ridge.multiplier.grid,
        ridge.condition.max,
        bandwidth.multiplier.grid
    )
    if (identical(outcome.family, "binomial") &&
        identical(backend, "auto")) {
        backend.used <- "R"
    } else if (identical(outcome.family, "binomial") &&
        !identical(backend.used, "R")) {
        stop("'outcome.family = \"binomial\"' currently uses the R backend; ",
             "use backend = 'R' or backend = 'auto'.", call. = FALSE)
    }
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
        bandwidth.multiplier = bandwidth.multiplier.grid,
        KEEP.OUT.ATTRS = FALSE,
        stringsAsFactors = FALSE
    )
    logistic.cv.telemetry <- .klp.logistic.telemetry.new(outcome.family)
    logistic.final.telemetry <- .klp.logistic.telemetry.new(outcome.family)
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
        backend = backend.used,
        design.basis = design.basis,
        design.drop.tol = design.drop.tol,
        ridge.multiplier.grid = ridge.multiplier.grid,
        ridge.condition.max = ridge.condition.max,
        unstable.action = unstable.action,
        outcome.family = outcome.family,
        logistic.telemetry = logistic.cv.telemetry
    )
    cv.table <- cv.result$cv.table
    cv.table <- .klp.decorate.outcome.cv.table(cv.table, outcome.family)
    score.column <- .klp.selection.score.column(outcome.family)
    best.idx <- .klp.select.best.idx(cv.table, score.column = score.column)
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
        design.basis = design.basis,
        design.drop.tol = design.drop.tol,
        ridge.multiplier.grid = ridge.multiplier.grid,
        ridge.condition.max = ridge.condition.max,
        unstable.action = unstable.action,
        outcome.family = outcome.family,
        logistic.telemetry = logistic.final.telemetry,
        return.chart.diagnostics = TRUE,
        bandwidth.multiplier = selected[["bandwidth.multiplier"]][[1L]]
    )
    fitted <- if (is.list(fitted.result) &&
                  !is.null(fitted.result$predictions)) {
        fitted.result$predictions
    } else {
        fitted.result
    }
    fitted.raw <- as.numeric(fitted)
    fitted.response <- .klp.response.scale(fitted.raw, outcome.family)
    probability.diagnostics <- .klp.probability.diagnostics(
        y = y,
        fitted.raw = fitted.raw,
        fitted.response = fitted.response,
        outcome.family = outcome.family
    )
    logistic.diagnostics <- if (identical(outcome.family, "binomial")) {
        list(
            cv = .klp.logistic.telemetry.summary(logistic.cv.telemetry),
            final = .klp.logistic.telemetry.summary(logistic.final.telemetry)
        )
    } else {
        NULL
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
        fitted.values = fitted.response,
        fitted.values.raw = fitted.raw,
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
        design.basis = design.basis,
        design.drop.tol = design.drop.tol,
        ridge.multiplier.grid = ridge.multiplier.grid,
        ridge.condition.max = ridge.condition.max,
        bandwidth.multiplier.grid = bandwidth.multiplier.grid,
        unstable.action = unstable.action,
        outcome.family = outcome.family,
        probability.diagnostics = probability.diagnostics,
        logistic.diagnostics = logistic.diagnostics,
        call = match.call()
    )
    class(out) <- c("lps", "list")
    out
}

#' Predict from an LPS Fit
#'
#' @param object A fitted \code{"lps"} object.
#' @param newdata Optional prediction matrix. Defaults to the fitted object's
#'   stored \code{X.eval}.
#' @param type Prediction scale. \code{"response"} returns response-scale
#'   predictions; for \code{outcome.family = "bernoulli"} or
#'   \code{"binomial"} these are probabilities in \code{[0,1]}. \code{"raw"}
#'   returns the unmodified local least-squares predictions for
#'   \code{"bernoulli"} and the fitted probabilities for \code{"binomial"}.
#' @param ... Unused.
#' @return A numeric vector of predictions.
#' @method predict lps
#' @export
predict.lps <- function(object, newdata = NULL, type = c("response", "raw"),
                        ...) {
    dots <- list(...)
    if (length(dots)) {
        stop("Unused arguments: ", paste(names(dots), collapse = ", "),
             call. = FALSE)
    }
    type <- match.arg(type)
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
    selected.bandwidth.multiplier <- object$selected[["bandwidth.multiplier"]]
    bandwidth.multiplier <- if (is.null(selected.bandwidth.multiplier) ||
                                !length(selected.bandwidth.multiplier)) {
        1
    } else {
        as.numeric(selected.bandwidth.multiplier[[1L]])
    }
    pred <- .klp.predict.local.polynomial(
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
        backend = if (is.null(object$backend.used)) "R" else object$backend.used,
        design.basis = object$design.basis %||%
            "orthogonal.polynomial.drop",
        design.drop.tol = object$design.drop.tol %||% 1e-8,
        ridge.multiplier.grid = object$ridge.multiplier.grid %||%
            c(0, 1e-10, 1e-8),
        ridge.condition.max = object$ridge.condition.max %||% 1e12,
        unstable.action = object$unstable.action %||% "mean",
        outcome.family = object$outcome.family %||% "gaussian",
        bandwidth.multiplier = bandwidth.multiplier
    )
    if (identical(type, "raw")) {
        return(pred)
    }
    .klp.response.scale(pred, object$outcome.family %||% "gaussian")
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
    if (!is.null(x$outcome.family) &&
        !identical(x$outcome.family, "gaussian")) {
        cat("  outcome family:", x$outcome.family, "\n")
    }
    cat("  selected support.size:", x$selected$support.size[[1L]], "\n")
    cat("  selected degree:", x$selected$degree[[1L]], "\n")
    cat("  selected kernel:", x$selected$kernel[[1L]], "\n")
    selected.bandwidth.multiplier <- x$selected[["bandwidth.multiplier"]]
    if (!is.null(selected.bandwidth.multiplier) &&
        length(selected.bandwidth.multiplier) &&
        is.finite(selected.bandwidth.multiplier[[1L]]) &&
        selected.bandwidth.multiplier[[1L]] != 1) {
        cat("  selected bandwidth.multiplier:",
            selected.bandwidth.multiplier[[1L]], "\n")
    }
    cat("  selected CV RMSE:",
        signif(x$selected$cv.rmse.observed[[1L]], 5), "\n")
    if (identical(x$outcome.family, "bernoulli") &&
        "cv.brier.observed" %in% names(x$selected)) {
        cat("  selected CV Brier:",
            signif(x$selected$cv.brier.observed[[1L]], 5), "\n")
    }
    if (identical(x$outcome.family, "binomial") &&
        "cv.logloss.observed" %in% names(x$selected)) {
        cat("  selected CV log loss:",
            signif(x$selected$cv.logloss.observed[[1L]], 5), "\n")
    }
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
            if (identical(backend.used, "cpp")) {
                "auto_coordinates_cpp"
            } else {
                "auto_coordinates_R_guarded_design"
            }
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
        outcome.family = object$outcome.family %||% "gaussian",
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
        selected.bandwidth.multiplier =
            as.numeric(selected.value("bandwidth.multiplier", 1)),
        selected.cv.rmse.observed =
            as.numeric(selected.value("cv.rmse.observed", NA_real_)),
        selected.cv.brier.observed =
            as.numeric(selected.value("cv.brier.observed", NA_real_)),
        selected.cv.logloss.observed =
            as.numeric(selected.value("cv.logloss.observed", NA_real_)),
        design.basis = object$design.basis %||%
            "orthogonal.polynomial.drop",
        design.drop.tol = as.numeric(object$design.drop.tol %||% NA_real_),
        ridge.multiplier.grid = paste(
            object$ridge.multiplier.grid %||% c(0, 1e-10, 1e-8),
            collapse = ";"
        ),
        ridge.condition.max =
            as.numeric(object$ridge.condition.max %||% 1e12),
        bandwidth.multiplier.grid = paste(
            object$bandwidth.multiplier.grid %||% 1,
            collapse = ";"
        ),
        unstable.action = object$unstable.action %||% NA_character_,
        candidate.count = if (is.null(object$cv.table)) {
            NA_integer_
        } else {
            as.integer(nrow(object$cv.table))
        },
        local.pca.real.data.contract = local.pca.real.data.contract,
        stringsAsFactors = FALSE
    )
}

.klp.validate.outcome.family <- function(y, outcome.family) {
    if (!outcome.family %in% c("bernoulli", "binomial")) {
        return(invisible(TRUE))
    }
    ok <- y %in% c(0, 1)
    if (!all(ok)) {
        stop("'outcome.family = \"", outcome.family,
             "\"' requires y values in {0, 1}.",
             call. = FALSE)
    }
    if (length(unique(y)) < 2L) {
        warning("'outcome.family = \"", outcome.family,
                "\"' received only one observed ",
                "class; fitted probabilities are still computed as numeric ",
                "probability estimates.", call. = FALSE)
    }
    invisible(TRUE)
}

.klp.clip.probability <- function(p, eps = 1e-15) {
    p <- as.numeric(p)
    pmin(1 - eps, pmax(eps, p))
}

.klp.response.scale <- function(pred, outcome.family) {
    pred <- as.numeric(pred)
    if (!outcome.family %in% c("bernoulli", "binomial")) {
        return(pred)
    }
    pmin(1, pmax(0, pred))
}

.klp.brier <- function(y, p) {
    if (length(y) != length(p)) return(NA_real_)
    ok <- is.finite(y) & is.finite(p)
    if (!any(ok)) return(NA_real_)
    mean((y[ok] - p[ok])^2)
}

.klp.logloss <- function(y, p) {
    if (length(y) != length(p)) return(NA_real_)
    ok <- is.finite(y) & is.finite(p)
    if (!any(ok)) return(NA_real_)
    p <- .klp.clip.probability(p[ok])
    -mean(y[ok] * log(p) + (1 - y[ok]) * log1p(-p))
}

.klp.probability.diagnostics <- function(y, fitted.raw, fitted.response,
                                         outcome.family) {
    if (!outcome.family %in% c("bernoulli", "binomial")) {
        return(NULL)
    }
    finite.raw <- is.finite(fitted.raw)
    n <- length(fitted.raw)
    below <- finite.raw & fitted.raw < 0
    above <- finite.raw & fitted.raw > 1
    list(
        diagnostic.scope = if (length(y) == length(fitted.raw)) {
            "labeled_predictions"
        } else {
            "unlabeled_eval_predictions"
        },
        n.labels = length(y),
        n.predictions = length(fitted.raw),
        brier.denominator = if (length(y) == length(fitted.raw)) {
            sum(is.finite(y) & is.finite(fitted.response))
        } else {
            NA_integer_
        },
        raw.min = if (any(finite.raw)) min(fitted.raw[finite.raw]) else NA_real_,
        raw.max = if (any(finite.raw)) max(fitted.raw[finite.raw]) else NA_real_,
        clipped.min = if (any(is.finite(fitted.response))) {
            min(fitted.response[is.finite(fitted.response)])
        } else {
            NA_real_
        },
        clipped.max = if (any(is.finite(fitted.response))) {
            max(fitted.response[is.finite(fitted.response)])
        } else {
            NA_real_
        },
        n.below.zero = sum(below),
        n.above.one = sum(above),
        fraction.below.zero = if (n) mean(below) else NA_real_,
        fraction.above.one = if (n) mean(above) else NA_real_,
        brier.raw = .klp.brier(y, fitted.raw),
        brier.clipped = .klp.brier(y, fitted.response),
        logloss.clipped = .klp.logloss(y, fitted.response)
    )
}

.klp.logistic.telemetry.new <- function(outcome.family) {
    if (!identical(outcome.family, "binomial")) {
        return(NULL)
    }
    env <- new.env(parent = emptyenv())
    env$attempted <- 0L
    env$converged <- 0L
    env$fallback.path <- 0L
    env$event.rate.fallback <- 0L
    env$na.failure <- 0L
    env$status <- list()
    env
}

.klp.logistic.telemetry.record <- function(telemetry, status,
                                           fallback.path = FALSE,
                                           event.rate.fallback = FALSE,
                                           na.failure = FALSE) {
    if (is.null(telemetry)) {
        return(invisible(NULL))
    }
    status <- as.character(status %||% "unknown")[[1L]]
    telemetry$attempted <- as.integer(telemetry$attempted %||% 0L) + 1L
    if (identical(status, "ok") && !isTRUE(fallback.path)) {
        telemetry$converged <- as.integer(telemetry$converged %||% 0L) + 1L
    }
    if (isTRUE(fallback.path)) {
        telemetry$fallback.path <-
            as.integer(telemetry$fallback.path %||% 0L) + 1L
    }
    if (isTRUE(event.rate.fallback)) {
        telemetry$event.rate.fallback <-
            as.integer(telemetry$event.rate.fallback %||% 0L) + 1L
    }
    if (isTRUE(na.failure)) {
        telemetry$na.failure <-
            as.integer(telemetry$na.failure %||% 0L) + 1L
    }
    old <- telemetry$status[[status]] %||% 0L
    telemetry$status[[status]] <- as.integer(old) + 1L
    invisible(NULL)
}

.klp.logistic.telemetry.summary <- function(telemetry) {
    if (is.null(telemetry)) {
        return(NULL)
    }
    status <- telemetry$status %||% list()
    status.counts <- if (length(status)) {
        counts <- unlist(status, use.names = TRUE)
        counts[order(names(counts))]
    } else {
        integer(0L)
    }
    attempted <- as.integer(telemetry$attempted %||% 0L)
    converged <- as.integer(telemetry$converged %||% 0L)
    fallback.path <- as.integer(telemetry$fallback.path %||% 0L)
    event.rate.fallback <-
        as.integer(telemetry$event.rate.fallback %||% 0L)
    na.failure <- as.integer(telemetry$na.failure %||% 0L)
    list(
        attempted = attempted,
        converged = converged,
        failed = max(0L, attempted - converged),
        fallback.path.count = fallback.path,
        event.rate.fallback.count = event.rate.fallback,
        na.failure.count = na.failure,
        convergence.fraction = if (attempted > 0L) converged / attempted else NA_real_,
        fallback.path.fraction = if (attempted > 0L) fallback.path / attempted else NA_real_,
        event.rate.fallback.fraction = if (attempted > 0L) {
            event.rate.fallback / attempted
        } else {
            NA_real_
        },
        na.failure.fraction = if (attempted > 0L) na.failure / attempted else NA_real_,
        status.counts = status.counts
    )
}

.klp.decorate.outcome.cv.table <- function(cv.table, outcome.family) {
    if (!outcome.family %in% c("bernoulli", "binomial")) {
        return(cv.table)
    }
    cv.table$cv.brier.observed <- cv.table$cv.rmse.observed^2
    if (identical(outcome.family, "binomial") &&
        !"cv.logloss.observed" %in% names(cv.table)) {
        cv.table$cv.logloss.observed <- NA_real_
    }
    cv.table
}

.klp.selection.score.column <- function(outcome.family) {
    if (identical(outcome.family, "binomial")) {
        "cv.logloss.observed"
    } else {
        "cv.rmse.observed"
    }
}

.klp.rmse <- function(x, y) {
    x <- as.numeric(x)
    y <- as.numeric(y)
    ok <- is.finite(x) & is.finite(y)
    if (!all(ok) || !any(ok)) return(Inf)
    sqrt(mean((x - y)^2))
}

.klp.select.best.idx <- function(cv.table, tolerance = 1e-12,
                                 score.column = "cv.rmse.observed") {
    if (!score.column %in% names(cv.table)) {
        stop("CV table does not contain selection score column '",
             score.column, "'.", call. = FALSE)
    }
    score <- cv.table[[score.column]]
    finite <- is.finite(score)
    if (!any(finite)) {
        stop("No candidate has a finite selection score in '",
             score.column, "'.  Check local-design conditioning, ",
             "support sizes, degree, backend, and unstable.action.",
             call. = FALSE)
    }
    best <- min(score[finite])
    eligible <- which(
        finite &
            score <=
                best + max(tolerance, tolerance * abs(best))
    )
    bandwidth.multiplier <- if (is.null(cv.table$bandwidth.multiplier)) {
        rep(1, length(eligible))
    } else {
        cv.table$bandwidth.multiplier[eligible]
    }
    eligible[order(
        cv.table$support.size[eligible],
        cv.table$degree[eligible],
        cv.table$kernel[eligible],
        bandwidth.multiplier,
        score[eligible]
    )[[1L]]]
}

.klp.cv.table <- function(X, y, foldid, cand, coordinate.method, chart.dim,
                          local.chart.method = "pca",
                          auto.chart.support.metric,
                          auto.chart.selection.metric,
                          backend = "R",
                          design.basis = "orthogonal.polynomial.drop",
                          design.drop.tol = 1e-8,
                          ridge.multiplier.grid = c(0, 1e-10, 1e-8),
                          ridge.condition.max = 1e12,
                          unstable.action = "mean",
                          outcome.family = "gaussian",
                          logistic.telemetry = NULL) {
    if (is.null(cand$bandwidth.multiplier)) {
        cand$bandwidth.multiplier <- 1
    }
    cand$chart.dim <- NA_integer_
    local.auto.dim <- .klp.is.local.auto.chart.dim(chart.dim)
    if (identical(coordinate.method, "coordinates") &&
        identical(backend, "cpp")) {
        if (any(cand$bandwidth.multiplier != 1)) {
            stop("The 'cpp' backend does not support bandwidth multipliers ",
                 "other than 1.", call. = FALSE)
        }
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
        if (any(cand$bandwidth.multiplier != 1)) {
            stop("The 'cpp.local.pca' backend does not support bandwidth ",
                 "multipliers other than 1.", call. = FALSE)
        }
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
                weight.specs <- unique(
                    cand[support.rows,
                         c("kernel", "bandwidth.multiplier"),
                         drop = FALSE]
                )
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
                    seq_len(nrow(weight.specs)),
                    function(ss) .klp.kernel.weights(
                        ordered$distances[seq_len(effective.support)],
                        weight.specs$kernel[[ss]],
                        weight.specs$bandwidth.multiplier[[ss]]
                    )
                )
                names(kernel.weights) <- .klp.weight.key(
                    weight.specs$kernel,
                    weight.specs$bandwidth.multiplier
                )
                if (!identical(local.chart.method, "second.order.svd")) {
                    design.cache <- new.env(parent = emptyenv())
                    for (rr in support.rows) {
                        w <- kernel.weights[[.klp.weight.key(
                            cand$kernel[[rr]],
                            cand$bandwidth.multiplier[[rr]]
                        )]]
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
                            design.cache = design.cache,
                            design.basis = design.basis,
                            design.drop.tol = design.drop.tol,
                            ridge.multiplier.grid = ridge.multiplier.grid,
                            ridge.condition.max = ridge.condition.max,
                            unstable.action = unstable.action,
                            outcome.family = outcome.family,
                            logistic.telemetry = logistic.telemetry
                        )
                    }
                } else {
                    for (rr in support.rows) {
                        w <- kernel.weights[[.klp.weight.key(
                            cand$kernel[[rr]],
                            cand$bandwidth.multiplier[[rr]]
                        )]]
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
                            design.cache = new.env(parent = emptyenv()),
                            design.basis = design.basis,
                            design.drop.tol = design.drop.tol,
                            ridge.multiplier.grid = ridge.multiplier.grid,
                            ridge.condition.max = ridge.condition.max,
                            unstable.action = unstable.action,
                            outcome.family = outcome.family,
                            logistic.telemetry = logistic.telemetry
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
    if (identical(outcome.family, "binomial")) {
        cv.table$cv.brier.observed <- vapply(
            seq_len(ncol(pred)),
            function(j) .klp.brier(y, pred[, j]),
            numeric(1L)
        )
        cv.table$cv.logloss.observed <- vapply(
            seq_len(ncol(pred)),
            function(j) .klp.logloss(y, pred[, j]),
            numeric(1L)
        )
    }
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
                                 local.chart.method = "none",
                                 design.basis =
                                     "orthogonal.polynomial.drop",
                                 ridge.multiplier.grid =
                                     c(0, 1e-10, 1e-8),
                                 ridge.condition.max = 1e12,
                                 bandwidth.multiplier.grid = 1) {
    needs.r.backend <- !identical(design.basis, "monomial") ||
        length(ridge.multiplier.grid) != 1L ||
        !identical(as.numeric(ridge.multiplier.grid[[1L]]), 0) ||
        is.finite(ridge.condition.max) ||
        length(bandwidth.multiplier.grid) != 1L ||
        !identical(as.numeric(bandwidth.multiplier.grid[[1L]]), 1)
    if (identical(backend, "auto")) {
        return(if (identical(coordinate.method, "coordinates") &&
                   !needs.r.backend) {
            "cpp"
        } else {
            "R"
        })
    }
    if (identical(backend, "cpp")) {
        if (!identical(coordinate.method, "coordinates")) {
            stop("'backend = \"cpp\"' currently supports only ",
                 "coordinate.method = 'coordinates'.", call. = FALSE)
        }
        if (needs.r.backend) {
            stop("'backend = \"cpp\"' does not support non-monomial design ",
                 "bases, guarded ridge solves, or bandwidth multipliers ",
                 "other than 1; use backend = 'auto' or 'R'.",
                 call. = FALSE)
        }
    }
    if (identical(backend, "cpp.local.pca")) {
        if (!identical(coordinate.method, "local.pca") ||
            !identical(local.chart.method, "pca")) {
            stop("'backend = \"cpp.local.pca\"' requires ",
                 "coordinate.method = 'local.pca' and ",
                 "local.chart.method = 'pca'.", call. = FALSE)
        }
        if (needs.r.backend) {
            stop("'backend = \"cpp.local.pca\"' does not support non-monomial ",
                 "design bases, guarded ridge solves, or bandwidth ",
                 "multipliers other than 1; use backend = 'auto' or 'R'.",
                 call. = FALSE)
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
                                          design.basis =
                                              "orthogonal.polynomial.drop",
                                          design.drop.tol = 1e-8,
                                          ridge.multiplier.grid =
                                              c(0, 1e-10, 1e-8),
                                          ridge.condition.max = 1e12,
                                          unstable.action = "mean",
                                          outcome.family = "gaussian",
                                          logistic.telemetry = NULL,
                                          return.chart.diagnostics = FALSE,
                                          bandwidth.multiplier = 1) {
    X.train <- as.matrix(X.train)
    X.eval <- as.matrix(X.eval)
    y.train <- as.numeric(y.train)
    support.size <- min(as.integer(support.size), nrow(X.train))
    if (identical(coordinate.method, "coordinates") &&
        identical(backend, "cpp")) {
        if (!identical(as.numeric(bandwidth.multiplier[[1L]]), 1)) {
            stop("The 'cpp' backend does not support bandwidth multipliers ",
                 "other than 1.", call. = FALSE)
        }
        return(rcpp_kernel_local_polynomial_predict_coordinates(
            X_train = X.train,
            y_train = y.train,
            X_eval = X.eval,
            support_size = support.size,
            degree = as.integer(degree),
            kernel = kernel
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
        weights <- .klp.kernel.weights(local.d, kernel, bandwidth.multiplier)
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
        } else {
            z <- local.coords
        }
        if (return.chart.diagnostics) {
            diagnostics[[i]] <- .klp.local.fit.diagnostics.row(
                eval.index = i,
                local.chart.method = local.chart.method,
                local.distances = local.d,
                weights = weights,
                z = z,
                degree = degree,
                design.drop.tol = design.drop.tol,
                chart = if (is.list(local.coords)) local.coords$chart else NULL
            )
        }
        out[[i]] <- .klp.fit.intercept(
            z = z,
            y = y.train[idx],
            weights = weights,
            degree = degree,
            design.basis = design.basis,
            design.drop.tol = design.drop.tol,
            ridge.multiplier.grid = ridge.multiplier.grid,
            ridge.condition.max = ridge.condition.max,
            unstable.action = unstable.action,
            outcome.family = outcome.family,
            logistic.telemetry = logistic.telemetry
        )
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

.klp.fit.intercept <- function(z, y, weights, degree,
                               design.basis = "orthogonal.polynomial.drop",
                               design.drop.tol = 1e-8,
                               ridge.multiplier.grid = c(0, 1e-10, 1e-8),
                               ridge.condition.max = 1e12,
                               unstable.action = "mean",
                               outcome.family = "gaussian",
                               logistic.telemetry = NULL) {
    .klp.fit.intercept.lazy(
        z = z,
        y = y,
        weights = weights,
        degree = degree,
        chart.dim = ncol(z),
        design.cache = new.env(parent = emptyenv()),
        design.basis = design.basis,
        design.drop.tol = design.drop.tol,
        ridge.multiplier.grid = ridge.multiplier.grid,
        ridge.condition.max = ridge.condition.max,
        unstable.action = unstable.action,
        outcome.family = outcome.family,
        logistic.telemetry = logistic.telemetry
    )
}

.klp.fit.intercept.lazy <- function(z, y, weights, degree, chart.dim,
                                    design.cache,
                                    design.basis =
                                        "orthogonal.polynomial.drop",
                                    design.drop.tol = 1e-8,
                                    ridge.multiplier.grid =
                                        c(0, 1e-10, 1e-8),
                                    ridge.condition.max = 1e12,
                                    unstable.action = "mean",
                                    outcome.family = "gaussian",
                                    logistic.telemetry = NULL) {
    ok <- is.finite(y) & is.finite(weights) & weights > 0
    if (!any(weights > 0)) {
        weights[] <- 1
        ok <- is.finite(y) & is.finite(weights) & weights > 0
    }
    n.design <- .klp.design.ncol(degree, chart.dim)
    if (!identical(outcome.family, "binomial") &&
        !design.basis %in% c("weighted.qr.drop", "orthogonal.polynomial.drop") &&
        sum(ok) < n.design) {
        return(if (identical(unstable.action, "na")) {
            NA_real_
        } else {
            stats::weighted.mean(y, weights, na.rm = TRUE)
        })
    }
    design <- .klp.get.local.design(z, degree, chart.dim, design.cache)
    if (identical(outcome.family, "binomial")) {
        return(.klp.fit.logistic.prob.design(
            design,
            y,
            weights,
            design.basis = design.basis,
            design.drop.tol = design.drop.tol,
            ridge.multiplier.grid = ridge.multiplier.grid,
            ridge.condition.max = ridge.condition.max,
            unstable.action = unstable.action,
            logistic.telemetry = logistic.telemetry
        ))
    }
    .klp.fit.intercept.design(
        design,
        y,
        weights,
        design.basis = design.basis,
        design.drop.tol = design.drop.tol,
        ridge.multiplier.grid = ridge.multiplier.grid,
        ridge.condition.max = ridge.condition.max,
        unstable.action = unstable.action
    )
}

.klp.fit.intercept.design <- function(design, y, weights,
                                      design.basis =
                                          "orthogonal.polynomial.drop",
                                      design.drop.tol = 1e-8,
                                      ridge.multiplier.grid =
                                          c(0, 1e-10, 1e-8),
                                      ridge.condition.max = 1e12,
                                      unstable.action = "mean") {
    design.ok <- rowSums(is.finite(design)) == ncol(design)
    ok <- is.finite(y) & is.finite(weights) & weights > 0 & design.ok
    if (!any(weights > 0)) {
        weights[] <- 1
        ok <- is.finite(y) & is.finite(weights) & weights > 0 & design.ok
    }
    fallback <- function() {
        if (identical(unstable.action, "na")) {
            NA_real_
        } else {
            stats::weighted.mean(y, weights, na.rm = TRUE)
        }
    }
    if (sum(ok) < 1L) return(fallback())
    prediction.row <- matrix(c(1, rep(0, ncol(design) - 1L)), nrow = 1L)
    solved <- .klp.solve.local.wls(
        design = design[ok, , drop = FALSE],
        y = y[ok],
        weights = weights[ok],
        design.basis = design.basis,
        design.drop.tol = design.drop.tol,
        ridge.multiplier.grid = ridge.multiplier.grid,
        ridge.condition.max = ridge.condition.max,
        prediction.row = prediction.row
    )
    if (!is.null(solved) && isTRUE(solved$ok) &&
        length(solved$prediction) && is.finite(solved$prediction[[1L]])) {
        return(solved$prediction[[1L]])
    }
    if (!is.null(solved) && isTRUE(solved$ok) &&
        length(solved$coefficients) && is.finite(solved$coefficients[[1L]])) {
        return(solved$coefficients[[1L]])
    }
    fallback()
}

.klp.fit.logistic.prob.design <- function(design, y, weights,
                                          design.basis =
                                              "orthogonal.polynomial.drop",
                                          design.drop.tol = 1e-8,
                                          ridge.multiplier.grid =
                                              c(0, 1e-10, 1e-8),
                                          ridge.condition.max = 1e12,
                                          unstable.action = "mean",
                                          logistic.telemetry = NULL) {
    design.ok <- rowSums(is.finite(design)) == ncol(design)
    ok <- is.finite(y) & y %in% c(0, 1) &
        is.finite(weights) & weights > 0 & design.ok
    if (!any(weights > 0)) {
        weights[] <- 1
        ok <- is.finite(y) & y %in% c(0, 1) &
            is.finite(weights) & weights > 0 & design.ok
    }
    fallback <- function(status) {
        .klp.logistic.telemetry.record(
            logistic.telemetry,
            status = status,
            fallback.path = TRUE,
            event.rate.fallback = !identical(unstable.action, "na"),
            na.failure = identical(unstable.action, "na")
        )
        if (identical(unstable.action, "na")) {
            NA_real_
        } else {
            .klp.response.scale(stats::weighted.mean(y, weights, na.rm = TRUE),
                                "binomial")
        }
    }
    if (sum(ok) < 1L) return(fallback("no_valid_rows"))
    prediction.row <- matrix(c(1, rep(0, ncol(design) - 1L)), nrow = 1L)
    solved <- .klp.solve.local.logistic(
        design = design[ok, , drop = FALSE],
        y = y[ok],
        weights = weights[ok],
        design.basis = design.basis,
        design.drop.tol = design.drop.tol,
        ridge.multiplier.grid = ridge.multiplier.grid,
        ridge.condition.max = ridge.condition.max,
        prediction.row = prediction.row
    )
    if (!is.null(solved) && isTRUE(solved$ok) &&
        length(solved$prediction) && is.finite(solved$prediction[[1L]])) {
        .klp.logistic.telemetry.record(
            logistic.telemetry,
            status = solved$status %||% "ok",
            fallback.path = FALSE
        )
        return(solved$prediction[[1L]])
    }
    fallback(if (!is.null(solved)) solved$status else "solve_failed")
}

.klp.solve.local.logistic <- function(design, y, weights,
                                      design.basis =
                                          "orthogonal.polynomial.drop",
                                      design.drop.tol = 1e-8,
                                      ridge.multiplier.grid =
                                          c(0, 1e-10, 1e-8),
                                      ridge.condition.max = 1e12,
                                      prediction.row = NULL,
                                      max.iter = 50L,
                                      tolerance = 1e-7) {
    design <- as.matrix(design)
    y <- as.numeric(y)
    weights <- as.numeric(weights)
    prediction.row <- if (is.null(prediction.row)) {
        NULL
    } else {
        as.matrix(prediction.row)
    }
    original.ncol <- ncol(design)
    kept.columns <- seq_len(original.ncol)
    if (!nrow(design) || ncol(design) < 1L) {
        return(list(ok = FALSE, status = "empty_design"))
    }
    if (identical(design.basis, "weighted.qr.drop")) {
        keep <- .klp.weighted.qr.keep.columns(design, weights,
                                              design.drop.tol)
        if (!length(keep)) {
            return(list(ok = FALSE, status = "rank_zero"))
        }
        kept.columns <- keep
        design <- design[, keep, drop = FALSE]
        if (!is.null(prediction.row)) {
            prediction.row <- prediction.row[, keep, drop = FALSE]
        }
    }
    orthogonal.basis <- design.basis %in%
        c("orthogonal.polynomial.drop", "orthogonal.polynomial.transformed")
    if (identical(design.basis, "orthogonal.polynomial.drop")) {
        transformed <- .klp.orthogonal.polynomial.transform(
            design = design,
            weights = weights,
            prediction.rows = prediction.row,
            design.drop.tol = design.drop.tol
        )
        if (!isTRUE(transformed$ok)) {
            return(list(ok = FALSE,
                        status = transformed$status %||%
                            "orthogonal_transform_failed"))
        }
        design <- transformed$design
        prediction.row <- transformed$prediction.rows
        kept.columns <- seq_len(ncol(design))
    }
    if (nrow(design) < ncol(design)) {
        return(list(ok = FALSE, status = "underdetermined"))
    }
    ybar <- stats::weighted.mean(y, weights, na.rm = TRUE)
    ybar <- .klp.clip.probability(ybar, eps = 1e-6)
    beta0 <- rep(0, ncol(design))
    beta0[[1L]] <- stats::qlogis(ybar)
    penalty.base <- if (isTRUE(orthogonal.basis)) {
        diag(1, nrow = ncol(design))
    } else {
        diag(c(0, rep(1, max(0L, ncol(design) - 1L))),
             nrow = ncol(design))
    }
    last.status <- "not_run"
    for (rho in ridge.multiplier.grid) {
        beta <- beta0
        converged <- FALSE
        ridge.used <- NA_real_
        cond.used <- NA_real_
        for (iter in seq_len(as.integer(max.iter))) {
            eta <- as.numeric(design %*% beta)
            mu <- stats::plogis(pmax(-35, pmin(35, eta)))
            variance <- pmax(mu * (1 - mu), 1e-8)
            working.weights <- weights * variance
            z <- eta + (y - mu) / variance
            xw <- design * sqrt(working.weights)
            zw <- z * sqrt(working.weights)
            cross <- crossprod(xw)
            rhs <- crossprod(xw, zw)
            scale <- .klp.local.ridge.scale(cross)
            ridge <- as.numeric(rho) * scale
            normal <- cross + ridge * penalty.base
            cond <- .klp.local.design.condition(normal)
            ridge.used <- ridge
            cond.used <- cond
            if (is.finite(ridge.condition.max) &&
                (!is.finite(cond) || cond > ridge.condition.max)) {
                last.status <- "ridge_condition_failed"
                break
            }
            beta.new <- tryCatch(
                as.numeric(solve(normal, rhs)),
                error = function(e) rep(NA_real_, ncol(normal))
            )
            if (!length(beta.new) || any(!is.finite(beta.new))) {
                last.status <- "logistic_solve_failed"
                break
            }
            if (max(abs(beta.new - beta)) <
                tolerance * (1 + max(abs(beta)))) {
                beta <- beta.new
                converged <- TRUE
                last.status <- "ok"
                break
            }
            beta <- beta.new
            last.status <- "not_converged"
        }
        if (isTRUE(converged) && all(is.finite(beta))) {
            pred <- if (is.null(prediction.row)) {
                NA_real_
            } else {
                stats::plogis(as.numeric(prediction.row %*% beta))
            }
            return(list(
                ok = length(pred) && is.finite(pred[[1L]]),
                status = "ok",
                coefficients = beta,
                ridge.multiplier = rho,
                ridge.lambda = ridge.used,
                condition = cond.used,
                prediction = pred,
                kept.columns = kept.columns,
                original.ncol = original.ncol
            ))
        }
    }
    list(
        ok = FALSE,
        status = last.status,
        kept.columns = kept.columns,
        original.ncol = original.ncol
    )
}

.klp.local.design.is.safe <- function(design, weights,
                                      min.rows.per.column = 1.25,
                                      max.condition = 1e4) {
    design <- as.matrix(design)
    weights <- as.numeric(weights)
    ok <- rowSums(is.finite(design)) == ncol(design) &
        is.finite(weights) & weights > 0
    if (sum(ok) < ncol(design)) return(FALSE)
    if (sum(ok) < ceiling(min.rows.per.column * ncol(design))) {
        return(FALSE)
    }
    xw <- design[ok, , drop = FALSE] * sqrt(weights[ok])
    sv <- tryCatch(svd(xw, nu = 0L, nv = 0L)$d,
                   error = function(e) numeric(0))
    if (!length(sv) || any(!is.finite(sv))) return(FALSE)
    tol <- max(dim(xw)) * max(sv) * .Machine$double.eps
    if (sum(sv > tol) < ncol(design)) return(FALSE)
    smallest <- min(sv)
    if (!is.finite(smallest) || smallest <= 0) return(FALSE)
    condition <- max(sv) / smallest
    is.finite(condition) && condition <= max.condition
}

.klp.validate.nonnegative.scalar <- function(x, name) {
    x <- as.numeric(x[[1L]])
    if (!is.finite(x) || x < 0) {
        stop("'", name, "' must be a finite nonnegative scalar.",
             call. = FALSE)
    }
    x
}

.klp.validate.positive.scalar <- function(x, name,
                                          allow.infinite = FALSE) {
    x <- as.numeric(x[[1L]])
    ok <- if (allow.infinite) {
        (is.finite(x) && x > 0) || identical(x, Inf)
    } else {
        is.finite(x) && x > 0
    }
    if (!ok) {
        stop("'", name, "' must be a positive",
             if (allow.infinite) " scalar or Inf." else " finite scalar.",
             call. = FALSE)
    }
    x
}

.klp.clean.ridge.multiplier.grid <- function(x) {
    out <- sort(unique(as.numeric(x)))
    out <- out[is.finite(out) & out >= 0]
    if (!length(out)) {
        stop("'ridge.multiplier.grid' must contain at least one finite ",
             "nonnegative value.", call. = FALSE)
    }
    out
}

.klp.clean.bandwidth.multiplier.grid <- function(x) {
    out <- sort(unique(as.numeric(x)))
    out <- out[is.finite(out) & out >= 0]
    if (!length(out)) {
        stop("'bandwidth.multiplier.grid' must contain at least one finite ",
             "nonnegative value.", call. = FALSE)
    }
    out
}

.klp.local.design.condition <- function(cross) {
    sv <- tryCatch(svd(as.matrix(cross), nu = 0L, nv = 0L)$d,
                   error = function(e) numeric(0))
    if (!length(sv) || any(!is.finite(sv))) return(Inf)
    positive <- sv[sv > max(dim(cross)) * max(sv) * .Machine$double.eps]
    if (!length(positive)) return(Inf)
    max(sv) / min(positive)
}

.klp.weighted.qr.keep.columns <- function(design, weights,
                                          design.drop.tol) {
    xw <- design * sqrt(weights)
    qr.fit <- tryCatch(qr(xw, LAPACK = TRUE, tol = design.drop.tol),
                       error = function(e) NULL)
    if (is.null(qr.fit) || !length(qr.fit$pivot)) {
        return(integer(0))
    }
    rank <- as.integer(qr.fit$rank)
    if (!is.finite(rank) || rank < 1L) return(integer(0))
    keep <- qr.fit$pivot[seq_len(min(rank, ncol(design)))]
    if (!1L %in% keep) {
        keep <- unique(c(1L, keep))
    }
    sort(as.integer(keep))
}

.klp.orthogonal.polynomial.transform <- function(design, weights,
                                                 prediction.rows = NULL,
                                                 design.drop.tol =
                                                     sqrt(.Machine$double.eps)) {
    design <- as.matrix(design)
    weights <- as.numeric(weights)
    prediction.rows <- if (is.null(prediction.rows)) {
        NULL
    } else {
        as.matrix(prediction.rows)
    }
    if (!nrow(design) || !ncol(design)) {
        return(list(ok = FALSE, status = "empty_design"))
    }
    xw <- design * sqrt(weights)
    sv <- tryCatch(svd(xw, nu = 0L, nv = ncol(xw)),
                   error = function(e) NULL)
    if (is.null(sv) || !length(sv$d) || any(!is.finite(sv$d))) {
        return(list(ok = FALSE, status = "svd_failed"))
    }
    cutoff <- max(sv$d) * design.drop.tol
    rank <- sum(sv$d > cutoff)
    if (!is.finite(rank) || rank < 1L) {
        return(list(ok = FALSE, status = "rank_zero"))
    }
    V <- sv$v[, seq_len(rank), drop = FALSE]
    transform <- sweep(V, 2L, sv$d[seq_len(rank)], "/")
    out.design <- design %*% transform
    out.pred <- if (is.null(prediction.rows)) {
        NULL
    } else {
        prediction.rows %*% transform
    }
    list(
        ok = TRUE,
        status = "ok",
        design = out.design,
        prediction.rows = out.pred,
        transform = transform,
        rank = as.integer(rank),
        original.ncol = ncol(design),
        condition = if (rank > 0L) max(sv$d) / min(sv$d[seq_len(rank)]) else Inf
    )
}

.klp.local.ridge.scale <- function(cross) {
    diag.scale <- diag(cross)
    scale <- if (length(diag.scale) > 1L) {
        mean(diag.scale[-1L], na.rm = TRUE)
    } else {
        mean(diag.scale, na.rm = TRUE)
    }
    if (!is.finite(scale) || scale <= 0) {
        scale <- mean(diag.scale, na.rm = TRUE)
    }
    if (!is.finite(scale) || scale <= 0) scale <- 1
    scale
}

.klp.solve.local.wls <- function(design, y, weights,
                                 design.basis = "orthogonal.polynomial.drop",
                                 design.drop.tol = 1e-8,
                                 ridge.multiplier.grid = c(0, 1e-10, 1e-8),
                                 ridge.condition.max = 1e12,
                                 prediction.row = NULL) {
    design <- as.matrix(design)
    y <- as.numeric(y)
    weights <- as.numeric(weights)
    prediction.row <- if (is.null(prediction.row)) {
        NULL
    } else {
        as.matrix(prediction.row)
    }
    original.ncol <- ncol(design)
    kept.columns <- seq_len(original.ncol)
    if (!nrow(design) || ncol(design) < 1L) {
        return(list(
            ok = FALSE,
            status = "empty_design",
            kept.columns = integer(0),
            original.ncol = original.ncol
        ))
    }
    if (identical(design.basis, "weighted.qr.drop")) {
        keep <- .klp.weighted.qr.keep.columns(design, weights,
                                              design.drop.tol)
        if (!length(keep)) {
            return(list(
                ok = FALSE,
                status = "rank_zero",
                kept.columns = integer(0),
                original.ncol = original.ncol
            ))
        }
        kept.columns <- keep
        design <- design[, keep, drop = FALSE]
        if (!is.null(prediction.row)) {
            prediction.row <- prediction.row[, keep, drop = FALSE]
        }
    }
    orthogonal.basis <- design.basis %in%
        c("orthogonal.polynomial.drop", "orthogonal.polynomial.transformed")
    if (identical(design.basis, "orthogonal.polynomial.drop")) {
        transformed <- .klp.orthogonal.polynomial.transform(
            design = design,
            weights = weights,
            prediction.rows = prediction.row,
            design.drop.tol = design.drop.tol
        )
        if (!isTRUE(transformed$ok)) {
            return(list(
                ok = FALSE,
                status = transformed$status %||% "orthogonal_transform_failed",
                kept.columns = integer(0),
                original.ncol = original.ncol
            ))
        }
        design <- transformed$design
        prediction.row <- transformed$prediction.rows
        kept.columns <- seq_len(ncol(design))
    }
    if (nrow(design) < ncol(design)) {
        return(list(
            ok = FALSE,
            status = "underdetermined",
            kept.columns = kept.columns,
            original.ncol = original.ncol
        ))
    }
    xw <- design * sqrt(weights)
    yw <- y * sqrt(weights)
    cross <- crossprod(xw)
    rhs <- crossprod(xw, yw)
    if (design.basis %in% c("weighted.qr", "weighted.qr.drop") &&
        length(ridge.multiplier.grid) == 1L &&
        ridge.multiplier.grid[[1L]] == 0 &&
        !is.finite(ridge.condition.max)) {
        qr.fit <- tryCatch(qr(xw, LAPACK = TRUE, tol = design.drop.tol),
                           error = function(e) NULL)
        coef <- if (is.null(qr.fit)) {
            rep(NA_real_, ncol(design))
        } else {
            tryCatch(as.numeric(qr.coef(qr.fit, yw)),
                     error = function(e) rep(NA_real_, ncol(design)))
        }
        return(list(
            ok = length(coef) && is.finite(coef[[1L]]),
            status = if (length(coef) && is.finite(coef[[1L]])) "ok" else
                "weighted_qr_failed",
            coefficients = coef,
            ridge.multiplier = 0,
            ridge.lambda = 0,
            condition = .klp.local.design.condition(cross),
            prediction = if (is.null(prediction.row)) {
                NA_real_
            } else {
                as.numeric(prediction.row %*% coef)
            },
            kept.columns = kept.columns,
            original.ncol = original.ncol
        ))
    }
    if (identical(design.basis, "monomial") &&
        length(ridge.multiplier.grid) == 1L &&
        ridge.multiplier.grid[[1L]] == 0 &&
        !is.finite(ridge.condition.max)) {
        if (!.klp.local.design.is.safe(design, weights)) {
            return(list(ok = FALSE, status = "unsafe_monomial_design"))
        }
        fit <- tryCatch(stats::lm.wfit(design, y, weights),
                        error = function(e) NULL)
        coef <- if (is.null(fit)) numeric(0) else fit$coefficients
        return(list(
            ok = length(coef) && is.finite(coef[[1L]]),
            status = if (length(coef) && is.finite(coef[[1L]])) "ok" else
                "lm_wfit_failed",
            coefficients = coef,
            ridge.multiplier = 0,
            ridge.lambda = 0,
            condition = .klp.local.design.condition(cross),
            prediction = if (is.null(prediction.row)) {
                NA_real_
            } else {
                as.numeric(prediction.row %*% coef)
            },
            kept.columns = kept.columns,
            original.ncol = original.ncol
        ))
    }
    scale <- .klp.local.ridge.scale(cross)
    penalty.base <- if (isTRUE(orthogonal.basis)) {
        diag(1, nrow = ncol(cross))
    } else {
        diag(c(0, rep(1, max(0L, ncol(cross) - 1L))),
             nrow = ncol(cross))
    }
    for (rho in ridge.multiplier.grid) {
        ridge <- rho * scale
        normal <- cross + ridge * penalty.base
        cond <- .klp.local.design.condition(normal)
        if (is.finite(ridge.condition.max) &&
            (!is.finite(cond) || cond > ridge.condition.max)) {
            next
        }
        coef <- tryCatch(as.numeric(solve(normal, rhs)),
                         error = function(e) rep(NA_real_, ncol(normal)))
        if (length(coef) && all(is.finite(coef)) &&
            is.finite(coef[[1L]])) {
            return(list(
                ok = TRUE,
                status = "ok",
                coefficients = coef,
                ridge.multiplier = rho,
                ridge.lambda = ridge,
                condition = cond,
                prediction = if (is.null(prediction.row)) {
                    NA_real_
                } else {
                    as.numeric(prediction.row %*% coef)
                },
                kept.columns = kept.columns,
                original.ncol = original.ncol
            ))
        }
    }
    list(
        ok = FALSE,
        status = "ridge_condition_failed",
        kept.columns = kept.columns,
        original.ncol = original.ncol
    )
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

.klp.local.fit.diagnostics.row <- function(eval.index, local.chart.method,
                                           local.distances, weights, z,
                                           degree, design.drop.tol,
                                           chart = NULL) {
    z <- as.matrix(z)
    chart.dim <- ncol(z)
    design <- .local.polynomial.design.matrix(
        z[, seq_len(chart.dim), drop = FALSE],
        degree
    )
    design.ok <- rowSums(is.finite(design)) == ncol(design)
    ok <- is.finite(weights) & weights > 0 & design.ok
    rank <- NA_integer_
    condition <- NA_real_
    if (any(ok)) {
        xw <- design[ok, , drop = FALSE] * sqrt(weights[ok])
        sv <- tryCatch(svd(xw, nu = 0L, nv = 0L)$d,
                       error = function(e) numeric(0))
        if (length(sv) && all(is.finite(sv))) {
            cutoff <- max(sv) * design.drop.tol
            rank <- as.integer(sum(sv > cutoff))
            positive <- sv[sv > max(dim(xw)) * max(sv) * .Machine$double.eps]
            condition <- if (length(positive)) max(sv) / min(positive) else Inf
        }
    }
    zero.bandwidth <- all(is.finite(local.distances)) &&
        length(local.distances) > 0L &&
        max(local.distances) <= sqrt(.Machine$double.eps)
    row <- data.frame(
        eval.index = as.integer(eval.index),
        local.chart.method = local.chart.method,
        fallback.used = FALSE,
        fallback.reason = "none",
        primary.failure.reason = NA_character_,
        effective.support = as.integer(length(local.distances)),
        quadratic.ncol = NA_integer_,
        design.rank = rank,
        design.condition = condition,
        fit.method = NA_character_,
        ridge.lambda = NA_real_,
        fit.residual.frobenius = NA_real_,
        curvature.fitted.frobenius = NA_real_,
        corrected.residual.frobenius = NA_real_,
        first.rank = NA_integer_,
        second.rank = NA_integer_,
        plain.pca.fallback.feasible = NA,
        status = if (is.finite(rank) && rank > 0L) "ok" else "rank_unavailable",
        zero.bandwidth = zero.bandwidth,
        stringsAsFactors = FALSE
    )
    chart.row <- .klp.local.chart.diagnostics.row(eval.index, chart)
    if (identical(local.chart.method, "second.order.svd") &&
        !is.null(chart.row)) {
        common <- intersect(names(row), names(chart.row))
        row[common] <- chart.row[common]
    }
    row
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
            max.design.condition = NA_real_,
            zero.bandwidth.fraction = NA_real_
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
    zero.bandwidth <- if ("zero.bandwidth" %in% names(diagnostics)) {
        as.logical(diagnostics$zero.bandwidth)
    } else {
        rep(NA, nrow(diagnostics))
    }
    zero.bandwidth <- zero.bandwidth[!is.na(zero.bandwidth)]
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
        },
        zero.bandwidth.fraction = if (length(zero.bandwidth)) {
            mean(zero.bandwidth)
        } else {
            NA_real_
        }
    )
}

.klp.kernel.weights <- function(distances, kernel, bandwidth.multiplier = 1) {
    if (!length(distances)) return(numeric(0))
    h <- max(distances[is.finite(distances)], 0)
    if (!is.finite(h) || h <= 0) h <- 1
    b <- as.numeric(bandwidth.multiplier[[1L]])
    u <- as.numeric(distances) / (b * h + sqrt(.Machine$double.eps))
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

.klp.weight.key <- function(kernel, bandwidth.multiplier) {
    paste(
        as.character(kernel),
        sprintf("%.17g", as.numeric(bandwidth.multiplier)),
        sep = "|"
    )
}
