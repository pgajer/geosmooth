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
#' @param coordinate.method Local coordinate method. \code{"coordinates"} uses
#'   centered ambient coordinates. \code{"local.pca"} projects centered support
#'   points onto a local PCA basis.
#' @param chart.dim Local PCA dimension when \code{coordinate.method =
#'   "local.pca"}. If \code{NULL}, the dimension is
#'   \code{min(ncol(X), support.size - 1)}.
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
    coordinate.method = c("coordinates", "local.pca"),
    chart.dim = NULL,
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
    coordinate.method <- match.arg(coordinate.method)
    bandwidth.multiplier <- .local.chart.validate.positive.scalar(
        bandwidth.multiplier, "bandwidth.multiplier"
    )
    denominator.floor <- .local.chart.validate.positive.scalar(
        denominator.floor, "denominator.floor"
    )
    chart.dim <- .local.chart.validate.chart.dim(
        chart.dim = chart.dim,
        coordinate.method = coordinate.method,
        p = p,
        support.size = support.size
    )

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
        local <- .chart.kernel.local.fit(
            X = X,
            y = y,
            x0 = X.eval[ii, ],
            support.size = support.size,
            kernel = kernel,
            bandwidth.multiplier = bandwidth.multiplier,
            coordinate.method = coordinate.method,
            chart.dim = chart.dim,
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
        chart.dim.summary = summary(resolved.chart.dim)
    )
    if (isTRUE(return.details)) {
        diagnostics$per.eval <- data.frame(
            eval.index = seq_len(ne),
            numerator = numerator,
            raw.denominator = raw.denominator,
            denominator = denominator,
            bandwidth = bandwidth,
            used.denominator.floor = used.floor,
            effective.support = effective.support,
            chart.dim = resolved.chart.dim
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
            chart.dim = chart.dim,
            denominator.floor = denominator.floor
        ),
        quadrature.weights = quadrature.weights,
        diagnostics = diagnostics,
        call = match.call()
    )
    class(out) <- c("chart_kernel", "list")
    out
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
