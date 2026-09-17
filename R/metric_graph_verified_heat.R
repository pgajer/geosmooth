# Opt-in, double-precision cross-check of the observed-data heat calculation.
# This is an agreement test, not a forward-error or interval certificate.
.metric.graph.verified.policy <- function(object) {
    identical(object$parameters$numerical.policy, "verified.fallback")
}

.metric.graph.verified.limits <- function() {
    c(candidate.residual = 1e-8, reference.residual = 1e-9,
      operator.error = 1e-7, nullspace.error = 1e-7,
      prediction.error = 1e-7, df.error = 1e-7,
      gcv.scaled.error = 1)
}

.metric.graph.verify.agreement <- function(diagnostics) {
    limits <- .metric.graph.verified.limits()
    x <- unlist(diagnostics[names(limits)], use.names = TRUE)
    if (length(x) != length(limits) || any(!is.finite(x)) ||
        any(x < 0) || any(x > limits)) {
        failed <- names(limits)[!is.finite(x) | x < 0 | x > limits]
        stop(paste0("Verified heat fallback failed numerical agreement: ",
                    paste(failed, collapse = ", "), ". No fit accepted."), call. = FALSE)
    }
    invisible(TRUE)
}

.metric.graph.gcv.tuning <- function(scores, status, grid) {
    use <- which(status == "valid" & is.finite(scores) & grid > 0)
    if (!length(use)) return(list(status = "no_valid_candidate", best.idx = NA_integer_,
                                 lower.endpoint = FALSE, upper.endpoint = FALSE,
                                 bracketed = FALSE, near.minimum.indices = integer()))
    best <- use[which.min(scores[use])]
    # Absolute tolerance is in squared response units. It identifies unresolved
    # tuning, rather than claiming equality of the underlying mathematical curve.
    tolerance <- 1e-10 + 1e-7 * abs(scores[best])
    near <- use[scores[use] - scores[best] <= tolerance]
    flat <- length(use) > 1L && length(near) == length(use)
    label <- if (flat) "unresolved_flat_gcv" else if (length(use) == 1L) {
        "single_candidate"
    } else if (length(near) > 1L) "multiple_near_minima" else "unique_grid_minimum"
    lower <- best == use[which.min(grid[use])]
    upper <- best == use[which.max(grid[use])]
    list(status = label, best.idx = if (flat) NA_integer_ else best,
         lower.endpoint = if (flat) NA else lower,
         upper.endpoint = if (flat) NA else upper,
         bracketed = !flat && length(near) == 1L && !lower && !upper,
         near.minimum.indices = near, tolerance = tolerance)
}

.metric.graph.require.tuning <- function(tuning) {
    if (!is.null(tuning) && tuning$status == "unresolved_flat_gcv") {
        stop("GCV is flat within numerical tolerance: no smoothing time selected. Inspect apply.metric.graph.lowpass.path() or use a prespecified time.",
             call. = FALSE)
    }
}

.metric.graph.verified.reference <- function(basis) {
    if (!isTRUE(basis$spectral$is.complete) ||
        basis$operator$laplacian.type != "unnormalized") {
        stop("verified.fallback requires a complete spectrum and the unnormalized Laplacian.", call. = FALSE)
    }
    # Recompute from the actual operator using base R LAPACK, not the candidate
    # eigenvectors. Scale first to retain behavior under global conductance changes.
    L <- basis$operator$laplacian$matrix
    unit <- max(abs(L))
    if (unit == 0) unit <- 1
    eig <- eigen(as.matrix(L / unit), symmetric = TRUE)
    ix <- rev(seq_along(eig$values))
    ref <- list(eigenvalues = eig$values[ix] * unit,
                eigenvectors = eig$vectors[, ix, drop = FALSE])
    .check.metric.graph.lowpass.spectrum(ref, basis$operator, "full")
}

.metric.graph.verified.heat.path <- function(basis, Y, grid, filter.type) {
    if (filter.type != "heat_kernel") {
        stop("verified.fallback supports only heat_kernel.", call. = FALSE)
    }
    reference <- .metric.graph.verified.reference(basis)
    V <- basis$spectral$eigenvectors
    lambda <- basis$spectral$eigenvalues
    W <- reference$eigenvectors
    mu <- reference$eigenvalues
    n <- nrow(Y)
    p <- ncol(Y)
    J <- length(grid)
    labels <- basis$spectral$components
    nc <- basis$spectral$nullity
    Q <- W[, seq_len(nc), drop = FALSE]
    positive <- which(mu > 0)
    fitted <- array(NA_real_, c(n, J, p))
    gcv <- df <- matrix(NA_real_, J, p)
    status <- matrix("degenerate_residual_operator", J, p)
    n.obs <- colSums(!is.na(Y))
    heat.error <- .metric.graph.heat.time.diagnostic(basis$spectral, grid, filter.type)
    keys <- apply(!is.na(Y), 2L, function(x) paste(which(x), collapse = ","))
    groups <- split(seq_len(p), factor(keys, levels = unique(keys)))
    masks <- lapply(groups, function(cols) {
        O <- which(!is.na(Y[, cols[1L]]))
        if (length(unique(labels[O])) != nc) {
            stop("Each connected component needs an observed response; an unobserved component is unidentified.", call. = FALSE)
        }
        list(cols = cols, O = O, U = setdiff(seq_len(n), O))
    })
    diagnostics <- list()
    for (j in seq_len(J)) {
        if (grid[j] == 0) {
            fitted[, j, ] <- Y
            df[j, ] <- n.obs
            status[j, ] <- "identity_undefined_gcv"
            next
        }
        a <- -expm1(-grid[j] * lambda)
        b <- -expm1(-grid[j] * mu)
        s <- max(a)
        sr <- max(b)
        if (s == 0 && sr == 0 && nc == n) {
            fitted[, j, ] <- Y
            df[j, ] <- n.obs
            next
        }
        if (!is.finite(s) || !is.finite(sr) || s <= 0 || sr <= 0) {
            stop("Verified heat fallback cannot resolve the heat complement.", call. = FALSE)
        }
        A <- tcrossprod(sweep(V, 2L, a / s, `*`), V)
        A <- (A + t(A)) / 2
        # The alternative route uses (I-H)^+ and an explicit nullspace border.
        P <- NULL
        if (any(n.obs < n)) {
            P <- tcrossprod(sweep(W[, positive, drop = FALSE], 2L,
                                  sr / b[positive], `*`), W[, positive, drop = FALSE])
        }
        for (k in seq_along(masks)) {
            mask <- masks[[k]]
            O <- mask$O
            U <- mask$U
            cols <- mask$cols
            q <- length(O)
            K <- A[O, O, drop = FALSE]
            candidate.residual <- reference.residual <- 0
            condition <- 1
            T <- matrix(0, n, q)
            Tr <- matrix(0, n, q)
            if (length(U)) {
                B <- A[U, U, drop = FALSE]
                C <- A[U, O, drop = FALSE]
                condition <- rcond(B)
                ch <- tryCatch(chol(B), error = function(e) NULL)
                if (is.null(ch)) stop("Verified heat block is singular; no ridge was added.", call. = FALSE)
                X <- backsolve(ch, forwardsolve(t(ch), C))
                candidate.residual <- max(abs(B %*% X - C)) /
                    max(1, max(abs(C)), max(rowSums(abs(B))) * max(abs(X)))
                T[U, ] <- -X
                K <- K - crossprod(C, X)
                G <- rbind(cbind(P[O, O, drop = FALSE], Q[O, , drop = FALSE]),
                           cbind(t(Q[O, , drop = FALSE]), matrix(0, nc, nc)))
                rhs <- rbind(diag(q), matrix(0, nc, q))
                Z <- tryCatch(solve(G, rhs, tol = 0), error = function(e) NULL)
                if (is.null(Z)) stop("Verified heat reference solve failed.", call. = FALSE)
                reference.residual <- max(abs(G %*% Z - rhs)) /
                    max(1, max(rowSums(abs(G))) * max(abs(Z)))
                Kr <- Z[seq_len(q), , drop = FALSE]
                Tr[U, ] <- P[U, O, drop = FALSE] %*% Kr +
                    Q[U, , drop = FALSE] %*% Z[q + seq_len(nc), , drop = FALSE]
            } else {
                Kr <- tcrossprod(sweep(W, 2L, b / sr, `*`), W)
            }
            K <- (K + t(K)) / 2
            Kr <- (Kr + t(Kr)) / 2
            T[O, ] <- diag(q) - s * K
            Tr[O, ] <- diag(q) - sr * Kr
            tr <- sum(diag(K))
            trr <- sum(diag(Kr))
            d <- q - s * tr
            dr <- q - sr * trr
            values <- Y[O, cols, drop = FALSE]
            # Compare standardized training responses, then return fits in their
            # original units. Training-only scaling avoids held-out leakage.
            centers <- colMeans(values)
            centered <- sweep(values, 2L, centers, `-`)
            scales <- sqrt(colMeans(centered^2))
            scales[scales == 0] <- 1
            standardized <- sweep(centered, 2L, scales, `/`)
            pred <- T %*% standardized
            predr <- Tr %*% standardized
            valid <- q > nc && is.finite(tr) && is.finite(trr) &&
                min(tr, trr) > 128 * .Machine$double.eps * q
            score <- scorer <- rep(NA_real_, length(cols))
            score.error <- 0
            if (valid) {
                score <- q * colSums((K %*% standardized / tr)^2)
                scorer <- q * colSums((Kr %*% standardized / trr)^2)
                score.error <- max(abs(score - scorer) / (1e-10 + 1e-7 * abs(scorer)))
            }
            checks <- list(candidate.residual = candidate.residual,
                           reference.residual = reference.residual,
                           operator.error = max(rowSums(abs(T - Tr))),
                           nullspace.error = max(abs(T %*% Q[O, , drop = FALSE] - Q),
                                                 abs(Tr %*% Q[O, , drop = FALSE] - Q)),
                           prediction.error = max(abs(pred - predr)),
                           df.error = abs(d - dr), gcv.scaled.error = score.error)
            .metric.graph.verify.agreement(checks)
            if (q > nc && !valid) {
                stop("Verified heat fallback has unresolved residual degrees of freedom.", call. = FALSE)
            }
            # Evaluate raw responses, rather than inserting centering corrections
            # into the fitting operator whose agreement was just checked.
            raw <- T %*% values
            raw.score <- if (valid) q * colSums((K %*% values / tr)^2) else rep(NA_real_, length(cols))
            if (any(!is.finite(raw)) || (valid && any(!is.finite(raw.score)))) {
                stop("Verified heat fallback produced non-finite response results.", call. = FALSE)
            }
            fitted[, j, cols] <- raw
            df[j, cols] <- d
            if (valid) {
                gcv[j, cols] <- raw.score
                status[j, cols] <- "valid"
            }
            uncertainty <- heat.error[j] / s + 32 * .Machine$double.eps * n
            old.accept <- is.finite(heat.error[j]) && heat.error[j] <= basis$spectral$verification$tolerance &&
                (!length(U) || (is.finite(condition) && condition > 0 && uncertainty / condition <= 1e-8))
            diagnostics[[length(diagnostics) + 1L]] <- as.data.frame(c(
                list(grid.index = j, eta = grid[j], mask = k, n.observed = q,
                     conservative.guard.passed = old.accept, fallback.used = !old.accept,
                     heat.error = heat.error[j], reciprocal.condition = condition,
                     condition.error = if (length(U)) uncertainty / condition else 0), checks))
        }
    }
    tuning <- lapply(seq_len(p), function(k) .metric.graph.gcv.tuning(gcv[, k], status[, k], grid))
    list(fitted = fitted, gcv = gcv, df = df, status = status, n.observed = n.obs,
         tuning = tuning,
         numerical = list(policy = "verified.fallback", limits = .metric.graph.verified.limits(),
                          reference.verification = reference$verification,
                          diagnostics = if (length(diagnostics)) do.call(rbind, diagnostics) else data.frame(),
                          response.mask = match(keys, unique(keys)),
                          interpretation = "Double-precision agreement; not a rigorous forward-error certificate."))
}
