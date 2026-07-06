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
