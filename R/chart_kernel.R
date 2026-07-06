#' Fit a Chart-Kernel Smoother
#'
#' Fits a local chart-kernel field by evaluating a Nadaraya--Watson style
#' smoother at each evaluation point. The function is a general fitted-field
#' model, not an occupation-density wrapper: density workflows should call
#' \code{\link{normalize.density}} on the returned fit.
#'
#' For an evaluation point \(x_u\), the prototype chooses a local support
#' \(U_u\), builds either centered ambient coordinates or a local PCA chart, and
#' computes
#' \deqn{
#'   \widehat f(x_u)
#'   =
#'   \frac{\sum_{i\in U_u} y_i K_h(z_{ui})}
#'        {\sum_{i\in U_u} q_i K_h(z_{ui})}.
#' }
#' Here \(z_{ui}\) is the local chart coordinate of \(x_i-x_u\), \(q_i\) is an
#' optional quadrature weight, and \(K_h\) is the selected kernel.
#'
#' @param X Numeric matrix with one row per source/support point.
#' @param y Numeric response or mass vector of length \code{nrow(X)}.
#' @param X.eval Optional numeric matrix of evaluation points. Defaults to
#'   \code{X}.
#' @param support.size Number of source points in each local support.
#' @param kernel Kernel name. Supported values are \code{"gaussian"},
#'   \code{"tricube"}, \code{"epanechnikov"}, and \code{"triangular"}.
#' @param bandwidth.multiplier Positive multiplier applied to the local
#'   support radius.
#' @param support.grid Optional integer candidate neighborhood sizes.  If
#'   supplied, or if \code{foldid} is supplied, the function performs row-wise
#'   cross-validation and refits the selected candidate on all rows.
#' @param kernel.grid Optional kernel candidates for cross-validation.
#' @param bandwidth.multiplier.grid Optional bandwidth-multiplier candidates
#'   for cross-validation.
#' @param foldid Optional positive integer vector assigning source rows to
#'   cross-validation folds.
#' @param cv.folds Number of folds used when \code{foldid} is not supplied.
#' @param cv.seed Random seed used to generate folds when \code{foldid} is not
#'   supplied.
#' @param coordinate.method Local coordinate method. \code{"coordinates"} uses
#'   centered ambient coordinates. \code{"local.pca"} projects centered support
#'   points onto a local PCA basis.
#' @param chart.dim Local PCA dimension when \code{coordinate.method =
#'   "local.pca"}. If \code{NULL}, the dimension is
#'   \code{min(ncol(X), support.size - 1)}.  The deployable input-only
#'   policies \code{"auto"} and \code{"local.auto"} use the same local-PCA
#'   dimension diagnostics as \code{\link{fit.lps}}; \code{"auto"} resolves
#'   one global chart dimension, while \code{"local.auto"} resolves one
#'   dimension per evaluation anchor.
#' @param auto.chart.support.metric Support system used by \code{chart.dim =
#'   "auto"} or \code{"local.auto"}.  Chart-kernel smoothers currently use
#'   coordinate supports for both coordinate and operator diagnostics.
#' @param auto.chart.selection.metric Which auto chart-dimension diagnostic to
#'   use when both coordinate and operator summaries are requested.
#' @param quadrature.weights Optional positive reference-measure weights
#'   \code{q_i}. Defaults to unit weights.
#' @param denominator.floor Positive floor used when the local denominator is
#'   numerically zero.
#' @param return.details Logical; if \code{TRUE}, keep per-evaluation
#'   diagnostics.
#'
#' @return A list with class \code{"chart_kernel"} containing
#'   \code{fitted.values}, source/evaluation supports, selected controls, and
#'   denominator diagnostics.
#' @export
fit.chart.kernel <- function(
    X,
    y,
    X.eval = NULL,
    support.size = min(15L, nrow(X)),
    kernel = c("gaussian", "tricube", "epanechnikov", "triangular"),
    bandwidth.multiplier = 1,
    support.grid = NULL,
    kernel.grid = NULL,
    bandwidth.multiplier.grid = NULL,
    foldid = NULL,
    cv.folds = 5L,
    cv.seed = 1L,
    coordinate.method = c("coordinates", "local.pca"),
    chart.dim = NULL,
    auto.chart.support.metric = c("coordinates", "operator", "both"),
    auto.chart.selection.metric = c("coordinates", "operator"),
    quadrature.weights = NULL,
    denominator.floor = sqrt(.Machine$double.eps),
    return.details = TRUE) {

    prepared <- .local.chart.prepare.X.eval(X, X.eval)
    X <- prepared$X
    X.eval <- prepared$X.eval
    n <- nrow(X)
    p <- ncol(X)
    y <- .local.chart.validate.response(y, n)
    quadrature.weights <- .local.chart.validate.quadrature(
        quadrature.weights, n
    )
    support.size <- .local.chart.validate.support.size(support.size, n)
    kernel <- match.arg(kernel)
    cv.requested <- .local.chart.cv.requested(
        foldid = foldid,
        support.grid = support.grid,
        degree.grid = NULL,
        kernel.grid = kernel.grid,
        bandwidth.multiplier.grid = bandwidth.multiplier.grid,
        lambda.ridge.grid = NULL
    )
    support.grid <- if (is.null(support.grid)) {
        support.size
    } else {
        .klp.clean.support.grid(support.grid, n)
    }
    kernel.grid <- if (is.null(kernel.grid)) {
        kernel
    } else {
        .klp.clean.kernel.grid(kernel.grid)
    }
    coordinate.method <- match.arg(coordinate.method)
    auto.chart.support.metric <- match.arg(auto.chart.support.metric)
    auto.chart.selection.metric <- match.arg(auto.chart.selection.metric)
    bandwidth.multiplier <- .local.chart.validate.positive.scalar(
        bandwidth.multiplier, "bandwidth.multiplier"
    )
    bandwidth.multiplier.grid <- if (is.null(bandwidth.multiplier.grid)) {
        bandwidth.multiplier
    } else {
        .klp.clean.bandwidth.multiplier.grid(bandwidth.multiplier.grid)
    }
    denominator.floor <- .local.chart.validate.positive.scalar(
        denominator.floor, "denominator.floor"
    )
    requested.chart.dim <- chart.dim
    chart.dim.info <- .local.chart.resolve.chart.dim(
        X = X,
        support.size = support.size,
        degree = 1L,
        chart.dim = chart.dim,
        coordinate.method = coordinate.method,
        auto.chart.support.metric = auto.chart.support.metric,
        auto.chart.selection.metric = auto.chart.selection.metric
    )
    chart.dim <- chart.dim.info$chart.dim

    cv.table <- NULL
    cv.predictions <- NULL
    if (isTRUE(cv.requested)) {
        foldid <- .klp.prepare.foldid(n, foldid, cv.folds, cv.seed)
        cand <- expand.grid(
            support.size = support.grid,
            kernel = kernel.grid,
            bandwidth.multiplier = bandwidth.multiplier.grid,
            KEEP.OUT.ATTRS = FALSE,
            stringsAsFactors = FALSE
        )
        cv.result <- .chart.kernel.cv.table(
            X = X,
            y = y,
            foldid = foldid,
            cand = cand,
            coordinate.method = coordinate.method,
            chart.dim = requested.chart.dim,
            auto.chart.support.metric = auto.chart.support.metric,
            auto.chart.selection.metric = auto.chart.selection.metric,
            quadrature.weights = quadrature.weights,
            denominator.floor = denominator.floor
        )
        cv.table <- cv.result$cv.table
        cv.predictions <- cv.result$predictions
        best.idx <- .local.chart.select.best.idx(cv.table)
        selected.row <- cv.table[best.idx, , drop = FALSE]
        support.size <- selected.row$support.size[[1L]]
        kernel <- selected.row$kernel[[1L]]
        bandwidth.multiplier <- selected.row$bandwidth.multiplier[[1L]]
        chart.dim.info <- .local.chart.resolve.chart.dim(
            X = X,
            support.size = support.size,
            degree = 1L,
            coordinate.method = coordinate.method,
            chart.dim = requested.chart.dim,
            auto.chart.support.metric = auto.chart.support.metric,
            auto.chart.selection.metric = auto.chart.selection.metric
        )
        chart.dim <- chart.dim.info$chart.dim
    }

    ne <- nrow(X.eval)
    fitted <- numeric(ne)
    denominator <- numeric(ne)
    raw.denominator <- numeric(ne)
    numerator <- numeric(ne)
    bandwidth <- numeric(ne)
    used.floor <- logical(ne)
    effective.support <- integer(ne)
    resolved.chart.dim <- integer(ne)

    for (ii in seq_len(ne)) {
        local.chart.dim <- .local.chart.resolve.eval.chart.dim(
            X = X,
            x0 = X.eval[ii, ],
            support.size = support.size,
            degree = 1L,
            coordinate.method = coordinate.method,
            chart.dim = requested.chart.dim,
            summary.dim = chart.dim
        )
        local <- .chart.kernel.local.fit(
            X = X,
            y = y,
            x0 = X.eval[ii, ],
            support.size = support.size,
            kernel = kernel,
            bandwidth.multiplier = bandwidth.multiplier,
            coordinate.method = coordinate.method,
            chart.dim = local.chart.dim,
            quadrature.weights = quadrature.weights,
            denominator.floor = denominator.floor
        )
        fitted[[ii]] <- local$value
        denominator[[ii]] <- local$denominator
        raw.denominator[[ii]] <- local$raw.denominator
        numerator[[ii]] <- local$numerator
        bandwidth[[ii]] <- local$bandwidth
        used.floor[[ii]] <- local$used.floor
        effective.support[[ii]] <- local$effective.support
        resolved.chart.dim[[ii]] <- local$chart.dim
    }

    diagnostics <- list(
        denominator.floor = denominator.floor,
        denominator.floor.count = sum(used.floor),
        denominator.floor.fraction = mean(used.floor),
        min.raw.denominator = min(raw.denominator),
        median.raw.denominator = stats::median(raw.denominator),
        min.bandwidth = min(bandwidth),
        median.bandwidth = stats::median(bandwidth),
        effective.support.summary = summary(effective.support),
        chart.dim = .local.chart.dimension.telemetry(
            chart.dim.info = chart.dim.info,
            chart.dim.by.anchor = resolved.chart.dim,
            source.path = "fit.chart.kernel.local.chart_resolution"
        )
    )
    if (isTRUE(return.details)) {
        diagnostics$per.eval <- data.frame(
            eval.index = seq_len(ne),
            numerator = numerator,
            raw.denominator = raw.denominator,
            denominator = denominator,
            bandwidth = bandwidth,
            used.denominator.floor = used.floor,
            effective.support = effective.support
        )
    }

    out <- list(
        method.id = "chart_kernel",
        X = X,
        X.eval = X.eval,
        y = y,
        fitted.values = fitted,
        selected = list(
            support.size = support.size,
            kernel = kernel,
            bandwidth.multiplier = bandwidth.multiplier,
            coordinate.method = coordinate.method,
            requested.chart.dim = requested.chart.dim,
            chart.dim = chart.dim,
            auto.chart.dim = chart.dim.info$auto.chart.dim,
            auto.chart.dim.local = chart.dim.info$auto.chart.dim.local,
            chart.dim.mode = chart.dim.info$chart.dim.mode,
            auto.chart.support.metric = auto.chart.support.metric,
            auto.chart.selection.metric = auto.chart.selection.metric,
            denominator.floor = denominator.floor,
            cv.rmse.observed = if (!is.null(cv.table)) {
                min(cv.table$cv.rmse.observed, na.rm = TRUE)
            } else {
                NA_real_
            }
        ),
        cv.table = cv.table,
        foldid = if (isTRUE(cv.requested)) foldid else NULL,
        cv.predictions = if (isTRUE(return.details)) cv.predictions else NULL,
        quadrature.weights = quadrature.weights,
        diagnostics = diagnostics,
        call = match.call()
    )
    class(out) <- c("chart_kernel", "list")
    out
}

.chart.kernel.cv.table <- function(X,
                                   y,
                                   foldid,
                                   cand,
                                   coordinate.method,
                                   chart.dim,
                                   auto.chart.support.metric,
                                   auto.chart.selection.metric,
                                   quadrature.weights,
                                   denominator.floor) {
    pred <- matrix(NA_real_, nrow = length(y), ncol = nrow(cand))
    folds <- sort(unique(foldid))
    for (fold in folds) {
        test <- which(foldid == fold)
        train <- which(foldid != fold)
        X.train <- X[train, , drop = FALSE]
        y.train <- y[train]
        q.train <- quadrature.weights[train]
        chart.dim.fold <- if (identical(coordinate.method, "coordinates")) {
            NULL
        } else {
            chart.dim
        }
        for (rr in seq_len(nrow(cand))) {
            fit <- fit.chart.kernel(
                X = X.train,
                y = y.train,
                X.eval = X[test, , drop = FALSE],
                support.size = cand$support.size[[rr]],
                kernel = cand$kernel[[rr]],
                bandwidth.multiplier = cand$bandwidth.multiplier[[rr]],
                coordinate.method = coordinate.method,
                chart.dim = chart.dim.fold,
                auto.chart.support.metric = auto.chart.support.metric,
                auto.chart.selection.metric = auto.chart.selection.metric,
                quadrature.weights = q.train,
                denominator.floor = denominator.floor,
                return.details = FALSE
            )
            pred[test, rr] <- fit$fitted.values
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

.chart.kernel.local.fit <- function(X,
                                    y,
                                    x0,
                                    support.size,
                                    kernel,
                                    bandwidth.multiplier,
                                    coordinate.method,
                                    chart.dim,
                                    quadrature.weights,
                                    denominator.floor) {
    support <- .local.chart.support(X, x0, support.size)
    idx <- support$idx
    coords <- .local.chart.coordinates(
        centered = support$centered,
        coordinate.method = coordinate.method,
        chart.dim = chart.dim
    )
    distances <- sqrt(rowSums(coords^2))
    kernel.info <- .local.chart.kernel(
        distances = distances,
        kernel = kernel,
        bandwidth.multiplier = bandwidth.multiplier
    )
    weights <- kernel.info$weights
    numerator <- sum(weights * y[idx])
    raw.denominator <- sum(weights * quadrature.weights[idx])
    used.floor <- !is.finite(raw.denominator) ||
        raw.denominator <= denominator.floor
    denominator <- if (isTRUE(used.floor)) {
        denominator.floor
    } else {
        raw.denominator
    }
    list(
        value = numerator / denominator,
        numerator = numerator,
        raw.denominator = raw.denominator,
        denominator = denominator,
        bandwidth = kernel.info$bandwidth,
        used.floor = used.floor,
        effective.support = kernel.info$effective.support,
        chart.dim = ncol(coords)
    )
}
