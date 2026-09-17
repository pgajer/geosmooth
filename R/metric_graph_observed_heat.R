# Explicit graph weight semantics and observed-data heat regression.
# Kept separate from public orchestration so the numerical model is reviewable.
.prepare.metric.graph.lowpass.graph <- function(adj, weights, weight.type) {
    if (weight.type == "length") {
        return(.validate.metric.graph.lowpass.graph(adj, weights))
    }
    if (!is.list(weights) || any(vapply(weights, function(w) {
        !is.numeric(w) || any(!is.finite(w)) || any(w < 0)
    }, logical(1)))) {
        stop("Conductances must be finite nonnegative numeric weights.", call. = FALSE)
    }
    # Validate indices/reciprocity before removing explicit zero edges.
    positive <- lapply(weights, function(w) pmax(w, .Machine$double.xmin))
    checked <- .validate.metric.graph.lowpass.graph(adj, positive)
    for (i in seq_along(adj)) {
        for (k in seq_along(adj[[i]])) {
            j <- adj[[i]][k]
            a <- weights[[i]][k]
            b <- weights[[j]][match(i, adj[[j]])]
            if ((a == 0) != (b == 0) || abs(a - b) > 1e-12 * max(a, b)) {
                stop("Reciprocal conductances must agree, including zero support.", call. = FALSE)
            }
        }
    }
    keep <- lapply(weights, function(w) w > 0)
    adj <- Map(function(x, k) x[k], checked$adj.list, keep)
    weights <- Map(function(x, k) as.double(x[k]), weights, keep)
    .validate.metric.graph.lowpass.graph(adj, weights)
}

.label.metric.graph.lowpass.weights <- function(operator, weight.type) {
    operator$weight.type <- weight.type
    operator$parameters$weight.type <- weight.type
    if (weight.type == "conductance") {
        operator$edge.table$input.weight <- operator$edge.table$conductance
        operator$edge.table$length <- NA_real_
    }
    operator
}

.metric.graph.lowpass.components <- function(adj) {
    n <- length(adj)
    labels <- integer(n)
    nc <- 0L
    for (start in seq_len(n)) {
        if (labels[start] != 0L) next
        nc <- nc + 1L
        queue <- integer(n)
        queue[1L] <- start
        labels[start] <- nc
        head <- 1L
        tail <- 1L
        while (head <= tail) {
            v <- queue[head]
            head <- head + 1L
            for (w in adj[[v]]) {
                if (labels[w] == 0L) {
                    labels[w] <- nc
                    tail <- tail + 1L
                    queue[tail] <- w
                }
            }
        }
    }
    labels
}

.check.metric.graph.lowpass.spectrum <- function(spectral, operator, spectrum) {
    n <- operator$graph$n.vertices
    V <- spectral$eigenvectors
    lambda <- spectral$eigenvalues
    if (nrow(V) != n || ncol(V) != length(lambda) ||
        (spectrum == "full" && length(lambda) != n)) {
        stop("Eigensolver did not return the requested spectrum dimension.", call. = FALSE)
    }
    L <- operator$laplacian$matrix
    scale <- max(1, max(abs(Matrix::rowSums(abs(L)))))
    tol <- 1e-8
    if (any(lambda < -tol * scale)) {
        stop("Laplacian eigensystem has materially negative eigenvalues.", call. = FALSE)
    }
    # Graph topology identifies exact zero modes, without zeroing small positive modes.
    components <- .metric.graph.lowpass.components(operator$graph$adj.list)
    nullity <- max(components)
    zeros <- seq_len(min(nullity, length(lambda)))
    if (any(abs(lambda[zeros]) > tol * scale)) {
        stop("Eigensystem does not resolve the graph's nullspace.", call. = FALSE)
    }
    lambda[zeros] <- 0
    lambda <- pmax(lambda, 0)
    spectral$eigenvalues <- lambda
    spectral$components <- components
    spectral$nullity <- nullity
    if (length(lambda) == n) {
        orth <- max(abs(crossprod(V) - diag(n)))
        residual <- max(abs(as.matrix(L %*% V) - sweep(V, 2L, lambda, `*`))) / scale
        if (!is.finite(orth) || !is.finite(residual) || orth > tol || residual > tol) {
            stop("Full eigensystem failed orthogonality or residual verification.", call. = FALSE)
        }
        spectral$verification <- list(orthogonality.error = orth,
                                     relative.residual = residual, tolerance = tol)
    }
    spectral
}

.select.metric.graph.lowpass.candidates <- function(fitted, scores, df, status, grid) {
    eligible <- which(status == "valid" & is.finite(scores))
    if (!length(eligible)) {
        stop("No valid GCV candidate: use positive smoothing times with residual degrees of freedom.",
             call. = FALSE)
    }
    best <- eligible[which.min(scores[eligible])]
    fitted <- matrix(fitted, nrow = dim(fitted)[1L])
    list(y.hat = fitted[, best], eta.optimal = grid[best],
         gcv.min = scores[best], effective.df = df[best], best.idx = best,
         gcv.scores = scores, df.grid = df, status = status)
}

.select.eta.gcv.single <- function(y.obs, y.spectral, V,
                                  filter.weights.matrix, eta.grid,
                                  eigenvalues = NULL, filter.type = NULL) {
    n <- length(y.obs)
    m <- ncol(V)
    complete <- m == n
    weights <- filter.weights.matrix
    complement <- if (identical(filter.type, "heat_kernel")) {
        -expm1(-outer(eigenvalues, eta.grid))
    } else {
        1 - weights
    }
    fitted <- V %*% (y.spectral * weights)
    scores <- rep(NA_real_, length(eta.grid))
    status <- rep("degenerate_residual_operator", length(eta.grid))
    df <- colSums(weights)
    omitted <- if (complete) rep(0, n) else y.obs - as.vector(V %*% y.spectral)
    for (j in seq_along(eta.grid)) {
        if (eta.grid[j] == 0) {
            fitted[, j] <- y.obs
            df[j] <- n
            status[j] <- "identity_undefined_gcv"
            next
        }
        a <- complement[, j]
        s <- if (complete) max(a) else max(1, a)
        if (!is.finite(s) || s <= 0) next
        # Normalize before squaring: tiny positive heat times have a finite GCV limit.
        r <- omitted / s + as.vector(V %*% ((a / s) * y.spectral))
        trace.residual <- (n - m) / s + sum(a / s)
        if (!is.finite(trace.residual) || trace.residual <= 0) next
        score <- n * sum((r / trace.residual)^2)
        if (!is.finite(score)) next
        scores[j] <- score
        status[j] <- "valid"
        if (complete) fitted[, j] <- y.obs - s * r
    }
    .select.metric.graph.lowpass.candidates(fitted, scores, df, status, eta.grid)
}

.metric.graph.observed.heat.path <- function(basis, Y, grid, filter.type) {
    if (filter.type != "heat_kernel" || !isTRUE(basis$spectral$is.complete)) {
        stop("Missing responses require heat_kernel and a complete spectrum (spectrum = 'full').",
             call. = FALSE)
    }
    V <- basis$spectral$eigenvectors
    lambda <- basis$spectral$eigenvalues
    n <- nrow(Y)
    p <- ncol(Y)
    J <- length(grid)
    labels <- basis$spectral$components
    if (is.null(labels)) labels <- .metric.graph.lowpass.components(basis$graph$adj.list)
    fitted <- array(NA_real_, c(n, J, p))
    gcv <- df <- matrix(NA_real_, J, p)
    status <- matrix("degenerate_residual_operator", J, p)
    n.obs <- colSums(!is.na(Y))
    for (col in seq_len(p)) {
        O <- which(!is.na(Y[, col]))
        if (length(unique(labels[O])) != length(unique(labels))) {
            stop("Each connected component needs an observed response; an unobserved component is unidentified.",
                 call. = FALSE)
        }
    }
    for (j in seq_len(J)) {
        if (grid[j] == 0) {
            fitted[, j, ] <- Y
            df[j, ] <- n.obs
            status[j, ] <- "identity_undefined_gcv"
            next
        }
        a <- -expm1(-grid[j] * lambda)
        scale <- max(a)
        if (!is.finite(scale) || scale <= 0) next
        A <- tcrossprod(sweep(V, 2L, a / scale, `*`), V)
        A <- (A + t(A)) / 2
        for (col in seq_len(p)) {
            O <- which(!is.na(Y[, col]))
            U <- which(is.na(Y[, col]))
            q <- length(O)
            y <- Y[O, col]
            K <- A[O, O, drop = FALSE]
            if (length(U)) {
                AUU <- A[U, U, drop = FALSE]
                AUO <- A[U, O, drop = FALSE]
                ch <- tryCatch(chol(AUU), error = function(e) NULL)
                if (is.null(ch)) stop("Observed heat block is numerically singular; no ridge was added.", call. = FALSE)
                solved <- backsolve(ch, forwardsolve(t(ch), AUO))
                err <- max(abs(AUU %*% solved - AUO)) /
                    max(1, max(abs(AUO)), max(rowSums(abs(AUU))) * max(abs(solved)))
                if (!is.finite(err) || err > 1e-8) {
                    stop("Observed heat block solve failed residual verification.", call. = FALSE)
                }
                fitted[U, j, col] <- -as.vector(solved %*% y)
                K <- K - t(AUO) %*% solved
            }
            K <- (K + t(K)) / 2
            r <- as.vector(K %*% y)
            tr <- sum(diag(K))
            fitted[O, j, col] <- y - scale * r
            df[j, col] <- q - scale * tr
            # This is a precision guard, not a replacement denominator.
            if (q <= length(unique(labels)) ||
                !is.finite(tr) || tr <= 128 * .Machine$double.eps * q) next
            score <- q * sum((r / tr)^2)
            if (is.finite(score)) {
                gcv[j, col] <- score
                status[j, col] <- "valid"
            }
        }
    }
    positive <- which(grid > 0)
    if (length(positive) && any(!is.finite(fitted[, positive, , drop = FALSE]))) {
        stop("Observed heat path produced unresolved or non-finite fitted values.", call. = FALSE)
    }
    list(fitted = fitted, gcv = gcv, df = df, status = status, n.observed = n.obs)
}

.metric.graph.observed.path.object <- function(basis, Y, grid, filter.type, names, parameters) {
    path <- .metric.graph.observed.heat.path(basis, Y, grid, filter.type)
    single <- ncol(Y) == 1L
    fit <- if (single) matrix(path$fitted[, , 1L], nrow(Y)) else path$fitted
    if (!single) dimnames(fit) <- list(NULL, eta = format(grid), response = names)
    out <- list(fitted.values = fit, eta.grid = grid, filter.type = filter.type,
                effective.df = if (single) path$df[, 1L] else path$df,
                gcv.scores = if (single) path$gcv[, 1L] else path$gcv,
                status = if (single) path$status[, 1L] else path$status,
                n.observed = path$n.observed, observed = !is.na(Y),
                spectral = basis$spectral, basis.complete = TRUE,
                basis = basis, parameters = parameters,
                n.responses = ncol(Y), response.names = names,
                resolution = data.frame(
                    eta = grid, retained.cutoff.weight = exp(-grid * max(basis$spectral$eigenvalues)),
                    spectrally.resolved = TRUE, exact.identity = grid == 0))
    class(out) <- c("metric.graph.lowpass.path", "list")
    out
}

.refit.metric.graph.observed.heat <- function(object, Y, select, grid, n.candidates, names) {
    basis <- list(spectral = object$spectral, graph = object$graph,
                  operator = object$operator)
    class(basis) <- c("metric.graph.lowpass.basis", "list")
    filter <- object$spectral$filter.type
    if (select) {
        grid <- .prepare.metric.graph.lowpass.eta.grid(grid, object$spectral$eigenvalues,
                                                      filter, n.candidates)
    } else {
        grid <- object$spectral$eta.optimal
    }
    path <- .metric.graph.observed.heat.path(basis, Y, grid, filter)
    n <- nrow(Y)
    p <- ncol(Y)
    idx <- rep(1L, p)
    if (select) {
        for (j in seq_len(p)) {
            best <- .select.metric.graph.lowpass.candidates(
                path$fitted[, , j, drop = FALSE], path$gcv[, j],
                path$df[, j], path$status[, j], grid)
            idx[j] <- best$best.idx
        }
    }
    fit <- matrix(NA_real_, n, p, dimnames = list(NULL, names))
    for (j in seq_len(p)) fit[, j] <- path$fitted[, idx[j], j]
    at <- cbind(idx, seq_len(p))
    out <- list(fitted.values = if (p == 1L) fit[, 1L] else fit,
                residuals = if (p == 1L) Y[, 1L] - fit[, 1L] else Y - fit,
                n.responses = p, per.column.gcv = select,
                filter.type = filter, n.observed = path$n.observed,
                effective.df = path$df[at], gcv.scores = path$gcv[at],
                gcv.status = path$status[at], n.cores.used = 1L)
    if (select) {
        out$eta.optimal <- grid[idx]
        out$eta.grid <- grid
        out$best.idx <- idx
    } else out$eta.used <- grid
    class(out) <- c("metric.graph.lowpass.refit", "list")
    out
}
