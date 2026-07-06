.local.chart.prepare.X.eval <- function(X, X.eval = NULL) {
    X <- .state.density.validate.X(X)
    if (is.null(X.eval)) {
        X.eval <- X
    } else {
        X.eval <- .state.density.validate.X(X.eval)
        if (ncol(X.eval) != ncol(X)) {
            stop("X.eval must have the same number of columns as X.",
                 call. = FALSE)
        }
    }
    list(X = X, X.eval = X.eval)
}

.local.chart.validate.response <- function(y, n, name = "y",
                                           nonnegative = FALSE) {
    if (!is.numeric(y) || length(y) != n || any(!is.finite(y))) {
        stop(name, " must be a finite numeric vector with length nrow(X).",
             call. = FALSE)
    }
    y <- as.numeric(y)
    if (isTRUE(nonnegative) && any(y < 0)) {
        stop(name, " must be nonnegative.", call. = FALSE)
    }
    y
}

.local.chart.validate.quadrature <- function(quadrature.weights, n) {
    if (is.null(quadrature.weights)) {
        return(rep(1, n))
    }
    if (!is.numeric(quadrature.weights) ||
        length(quadrature.weights) != n ||
        any(!is.finite(quadrature.weights)) ||
        any(quadrature.weights <= 0)) {
        stop("quadrature.weights must be NULL or a positive finite numeric vector with length nrow(X).",
             call. = FALSE)
    }
    as.numeric(quadrature.weights)
}

.local.chart.validate.support.size <- function(support.size, n) {
    if (!is.numeric(support.size) || length(support.size) != 1L ||
        !is.finite(support.size)) {
        stop("support.size must be one finite integer.", call. = FALSE)
    }
    support.size <- as.integer(round(support.size))
    if (support.size < 1L) {
        stop("support.size must be at least 1.", call. = FALSE)
    }
    min(support.size, n)
}

.local.chart.validate.positive.scalar <- function(x, name) {
    if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x <= 0) {
        stop(name, " must be one positive finite numeric value.",
             call. = FALSE)
    }
    as.numeric(x)
}

.local.chart.validate.nonnegative.scalar <- function(x, name) {
    if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < 0) {
        stop(name, " must be one finite nonnegative numeric value.",
             call. = FALSE)
    }
    as.numeric(x)
}

.local.chart.validate.nonnegative.integer <- function(x, name) {
    if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) {
        stop(name, " must be one finite nonnegative integer.", call. = FALSE)
    }
    x <- as.integer(round(x))
    if (x < 0L) {
        stop(name, " must be nonnegative.", call. = FALSE)
    }
    x
}

.local.chart.validate.positive.integer <- function(x, name) {
    if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) {
        stop(name, " must be one finite positive integer.", call. = FALSE)
    }
    x <- as.integer(round(x))
    if (x < 1L) {
        stop(name, " must be positive.", call. = FALSE)
    }
    x
}

.local.chart.validate.chart.dim <- function(chart.dim,
                                            coordinate.method,
                                            p,
                                            support.size) {
    if (identical(coordinate.method, "coordinates")) {
        if (!is.null(chart.dim)) {
            warning("chart.dim is ignored when coordinate.method = \"coordinates\".",
                    call. = FALSE)
        }
        return(p)
    }
    if (is.null(chart.dim)) {
        return(max(1L, min(p, support.size - 1L)))
    }
    if (!is.numeric(chart.dim) || length(chart.dim) != 1L ||
        !is.finite(chart.dim)) {
        stop("chart.dim must be NULL or one finite integer for local.pca.",
             call. = FALSE)
    }
    chart.dim <- as.integer(round(chart.dim))
    if (chart.dim < 1L) {
        stop("chart.dim must be at least 1.", call. = FALSE)
    }
    min(chart.dim, p, support.size)
}

.local.chart.requested.chart.dim.label <- function(chart.dim) {
    if (is.null(chart.dim)) {
        return(NA_character_)
    }
    if (is.character(chart.dim)) {
        return(as.character(chart.dim[[1L]]))
    }
    as.character(as.integer(round(chart.dim[[1L]])))
}

.local.chart.dim.mode <- function(chart.dim, coordinate.method) {
    .klp.chart.dim.mode(
        chart.dim = chart.dim,
        coordinate.method = coordinate.method
    )
}

.local.chart.resolve.chart.dim <- function(
    X,
    support.size,
    degree,
    coordinate.method,
    chart.dim,
    auto.chart.support.metric = c("coordinates", "operator", "both"),
    auto.chart.selection.metric = c("coordinates", "operator")) {

    auto.chart.support.metric <- match.arg(auto.chart.support.metric)
    auto.chart.selection.metric <- match.arg(auto.chart.selection.metric)
    p <- ncol(X)
    support.size <- .local.chart.validate.support.size(support.size, nrow(X))

    if (identical(coordinate.method, "coordinates")) {
        if (!is.null(chart.dim)) {
            warning("chart.dim is ignored when coordinate.method = \"coordinates\".",
                    call. = FALSE)
        }
        return(list(
            chart.dim = p,
            requested.chart.dim = chart.dim,
            chart.dim.mode = "ambient",
            auto.chart.dim = FALSE,
            auto.chart.dim.local = FALSE,
            auto.chart.dim.diagnostics = NULL,
            auto.chart.support.metric = auto.chart.support.metric,
            auto.chart.selection.metric = auto.chart.selection.metric
        ))
    }

    if (is.null(chart.dim)) {
        dim <- max(1L, min(p, support.size - 1L))
        return(list(
            chart.dim = as.integer(dim),
            requested.chart.dim = chart.dim,
            chart.dim.mode = "ambient.default",
            auto.chart.dim = FALSE,
            auto.chart.dim.local = FALSE,
            auto.chart.dim.diagnostics = NULL,
            auto.chart.support.metric = auto.chart.support.metric,
            auto.chart.selection.metric = auto.chart.selection.metric
        ))
    }

    if (identical(chart.dim, "auto") || identical(chart.dim, "local.auto")) {
        diagnostics <- .local.pca.auto.chart.dim.with.metric(
            X = X,
            support.size = support.size,
            degree = degree,
            max.anchors = if (identical(chart.dim, "local.auto")) {
                nrow(X)
            } else {
                60L
            },
            operator.support.metric = "coordinates",
            auto.chart.support.metric = auto.chart.support.metric,
            auto.chart.selection.metric = auto.chart.selection.metric
        )
        dim <- max(1L, min(p, support.size, diagnostics$chart.dim))
        return(list(
            chart.dim = as.integer(dim),
            requested.chart.dim = chart.dim,
            chart.dim.mode = .local.chart.dim.mode(chart.dim,
                                                   coordinate.method),
            auto.chart.dim = TRUE,
            auto.chart.dim.local = identical(chart.dim, "local.auto"),
            auto.chart.dim.diagnostics = diagnostics,
            auto.chart.support.metric = auto.chart.support.metric,
            auto.chart.selection.metric = auto.chart.selection.metric
        ))
    }

    if (!is.numeric(chart.dim) || length(chart.dim) != 1L ||
        !is.finite(chart.dim)) {
        stop("chart.dim must be NULL, one finite integer, \"auto\", ",
             "or \"local.auto\" for local.pca.",
             call. = FALSE)
    }
    dim <- as.integer(round(chart.dim))
    if (dim < 1L) {
        stop("chart.dim must be at least 1.", call. = FALSE)
    }
    dim <- min(dim, p, support.size)
    list(
        chart.dim = as.integer(dim),
        requested.chart.dim = chart.dim,
        chart.dim.mode = "fixed",
        auto.chart.dim = FALSE,
        auto.chart.dim.local = FALSE,
        auto.chart.dim.diagnostics = NULL,
        auto.chart.support.metric = auto.chart.support.metric,
        auto.chart.selection.metric = auto.chart.selection.metric
    )
}

.local.chart.resolve.eval.chart.dim <- function(
    X,
    x0,
    support.size,
    degree,
    coordinate.method,
    chart.dim,
    summary.dim) {

    if (!identical(coordinate.method, "local.pca") ||
        !identical(chart.dim, "local.auto")) {
        return(as.integer(summary.dim))
    }
    ordered <- .klp.local.order(
        X.train = X,
        center = x0,
        support.size = support.size
    )
    dim <- .klp.local.auto.chart.dim.from.order(
        X.train = X,
        center = x0,
        ordered = ordered,
        support.size = support.size,
        degree = degree
    )
    if (!is.finite(dim) || dim < 1L) {
        dim <- as.integer(summary.dim)
    }
    as.integer(max(1L, min(ncol(X), support.size, dim)))
}

.local.chart.support <- function(X, x0, support.size) {
    d2 <- rowSums((X - matrix(x0, nrow = nrow(X), ncol = ncol(X),
                              byrow = TRUE))^2)
    ord <- order(d2, seq_along(d2))
    idx <- ord[seq_len(support.size)]
    list(
        idx = idx,
        centered = sweep(X[idx, , drop = FALSE], 2L, x0, "-"),
        ambient.distances = sqrt(d2[idx])
    )
}

.local.chart.coordinates <- function(centered, coordinate.method, chart.dim) {
    if (identical(coordinate.method, "coordinates")) {
        return(centered)
    }
    d <- min(chart.dim, ncol(centered), nrow(centered))
    if (d < 1L) {
        return(matrix(0, nrow = nrow(centered), ncol = 1L))
    }
    sv <- svd(centered, nu = 0L, nv = d)
    centered %*% sv$v[, seq_len(d), drop = FALSE]
}

.local.chart.kernel <- function(distances, kernel, bandwidth.multiplier = 1) {
    weights <- .klp.kernel.weights(
        distances = distances,
        kernel = kernel,
        bandwidth.multiplier = bandwidth.multiplier
    )
    h <- max(distances[is.finite(distances)], 0)
    if (!is.finite(h) || h <= 0) {
        h <- 1
    }
    list(
        weights = weights,
        bandwidth = bandwidth.multiplier * h,
        effective.support = sum(weights > 0)
    )
}

.local.chart.feature.matrix <- function(coords, degree) {
    degree <- .local.chart.validate.nonnegative.integer(degree, "degree")
    n <- nrow(coords)
    d <- ncol(coords)
    if (degree == 0L) {
        return(matrix(numeric(0), nrow = n, ncol = 0L))
    }
    out <- coords
    if (degree >= 2L) {
        quad <- vector("list", d * (d + 1L) / 2L)
        kk <- 0L
        for (aa in seq_len(d)) {
            for (bb in aa:d) {
                kk <- kk + 1L
                quad[[kk]] <- coords[, aa] * coords[, bb]
            }
        }
        out <- cbind(out, do.call(cbind, quad))
    }
    out
}
