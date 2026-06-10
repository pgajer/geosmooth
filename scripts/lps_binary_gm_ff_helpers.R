`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

sanitize.id <- function(x) gsub("[^A-Za-z0-9_]+", "_", x)

json.escape <- function(x) {
    x <- as.character(x %||% "")
    x <- gsub("\\\\", "\\\\\\\\", x)
    x <- gsub('"', '\\"', x, fixed = TRUE)
    x <- gsub("\n", "\\\\n", x, fixed = TRUE)
    x
}

json.value <- function(x) {
    if (is.null(x) || length(x) == 0L || all(is.na(x))) return("null")
    if (is.logical(x)) return(if (isTRUE(x[[1L]])) "true" else "false")
    if (is.numeric(x) || is.integer(x)) {
        if (!is.finite(x[[1L]])) return("null")
        return(format(x[[1L]], scientific = FALSE, digits = 16))
    }
    paste0('"', json.escape(x[[1L]]), '"')
}

write.status.json <- function(path, fields) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    body <- paste(
        sprintf('  "%s": %s', names(fields),
                vapply(fields, json.value, character(1L))),
        collapse = ",\n"
    )
    writeLines(c("{", body, "}"), path)
}

stable.z <- function(f, clip = 4) {
    center <- stats::median(f, na.rm = TRUE)
    scale <- stats::mad(f, center = center, constant = 1, na.rm = TRUE)
    if (!is.finite(scale) || scale <= 0) scale <- stats::sd(f, na.rm = TRUE)
    if (!is.finite(scale) || scale <= 0) scale <- 1
    pmax(-clip, pmin(clip, (f - center) / scale))
}

probability.profile <- function(f, transform = "signed",
                                target.prevalence = 0.5,
                                slope = 1.25,
                                p.floor = 0.02,
                                z.clip = 4) {
    z <- stable.z(f, clip = z.clip)
    h <- switch(
        transform,
        signed = z,
        tail = abs(z),
        central = -abs(z),
        stop("Unknown transform.", call. = FALSE)
    )
    h <- h - stats::median(h, na.rm = TRUE)
    mean.p <- function(alpha) {
        mean(p.floor + (1 - 2 * p.floor) * stats::plogis(alpha + slope * h))
    }
    alpha <- stats::uniroot(
        function(a) mean.p(a) - target.prevalence,
        interval = c(-50, 50)
    )$root
    as.numeric(p.floor + (1 - 2 * p.floor) * stats::plogis(alpha + slope * h))
}

lhs <- function(n, d, seed) {
    set.seed(seed)
    out <- matrix(NA_real_, n, d)
    for (j in seq_len(d)) {
        out[, j] <- (sample.int(n) - stats::runif(n)) / n
    }
    out
}

make.geometry <- function(block, n, seed) {
    if (identical(block, "1d_native_interval")) {
        set.seed(seed)
        u <- sort(stats::runif(n))
        return(list(X = matrix(u, ncol = 1L), latent = matrix(u, ncol = 1L)))
    }
    if (identical(block, "1d_highdim_pad100")) {
        set.seed(seed)
        u <- sort(stats::runif(n))
        set.seed(seed + 900L)
        X <- cbind(u, matrix(stats::rnorm(n * 99L, sd = 0.02), n, 99L))
        X <- scale(X)
        return(list(X = X, latent = matrix(u, ncol = 1L)))
    }
    if (identical(block, "2d_native_square")) {
        uv <- lhs(n, 2L, seed)
        return(list(X = uv, latent = uv))
    }
    if (identical(block, "2d_curved_paraboloid")) {
        uv <- lhs(n, 2L, seed)
        X <- cbind(uv, uv[, 1L]^2 + uv[, 2L]^2)
        return(list(X = X, latent = uv))
    }
    if (identical(block, "2d_curved_saddle")) {
        uv <- lhs(n, 2L, seed)
        X <- cbind(uv, uv[, 1L]^2 - uv[, 2L]^2)
        return(list(X = X, latent = uv))
    }
    if (identical(block, "2d_highdim_diag100")) {
        uv <- lhs(n, 2L, seed)
        set.seed(seed + 1000L)
        X <- cbind(matrix(rep(uv[, 1L], 50L), ncol = 50L),
                   matrix(rep(uv[, 2L], 50L), ncol = 50L))
        X <- X + matrix(stats::rnorm(n * 100L, sd = 0.01), n, 100L)
        X <- scale(X)
        return(list(X = X, latent = uv))
    }
    if (identical(block, "3d_native_cube")) {
        uvw <- lhs(n, 3L, seed)
        return(list(X = uvw, latent = uvw))
    }
    if (identical(block, "3d_highdim_diag99")) {
        uvw <- lhs(n, 3L, seed)
        set.seed(seed + 2000L)
        X <- cbind(matrix(rep(uvw[, 1L], 33L), ncol = 33L),
                   matrix(rep(uvw[, 2L], 33L), ncol = 33L),
                   matrix(rep(uvw[, 3L], 33L), ncol = 33L))
        X <- X + matrix(stats::rnorm(n * 99L, sd = 0.01), n, 99L)
        X <- scale(X)
        return(list(X = X, latent = uvw))
    }
    stop("Unknown geometry block: ", block, call. = FALSE)
}

gaussian.truth <- function(latent, k) {
    d <- ncol(latent)
    centers <- switch(
        paste0(d, "d_", k),
        "1d_2" = matrix(c(0.30, 0.76), ncol = 1L),
        "1d_3" = matrix(c(0.25, 0.55, 0.82), ncol = 1L),
        "1d_4" = matrix(c(0.18, 0.42, 0.68, 0.88), ncol = 1L),
        "2d_2" = matrix(c(0.30, 0.34, 0.68, 0.70),
                        ncol = 2L, byrow = TRUE),
        "2d_3" = matrix(c(0.20, 0.32, 0.58, 0.72, 0.82, 0.24),
                        ncol = 2L, byrow = TRUE),
        "2d_4" = matrix(c(0.18, 0.22, 0.38, 0.78,
                          0.70, 0.32, 0.84, 0.76),
                        ncol = 2L, byrow = TRUE),
        "3d_2" = matrix(c(0.25, 0.30, 0.35, 0.72, 0.68, 0.62),
                        ncol = 3L, byrow = TRUE),
        "3d_3" = matrix(c(0.20, 0.25, 0.35, 0.62, 0.70, 0.28,
                          0.78, 0.30, 0.72),
                        ncol = 3L, byrow = TRUE),
        "3d_4" = matrix(c(0.20, 0.25, 0.35, 0.60, 0.72, 0.30,
                          0.78, 0.30, 0.72, 0.44, 0.50, 0.84),
                        ncol = 3L, byrow = TRUE),
        stop("Unsupported dimension/components combination.", call. = FALSE)
    )
    amps <- switch(as.character(k),
                   "2" = c(1.00, 0.70),
                   "3" = c(1.00, 0.75, 0.55),
                   "4" = c(1.00, 0.78, 0.60, 0.45))
    bw <- switch(as.character(d), "1" = rep(0.075, k),
                 "2" = rep(0.13, k), "3" = rep(0.16, k))
    f <- numeric(nrow(latent))
    for (j in seq_len(k)) {
        dif <- sweep(latent, 2L, centers[j, ], "-")
        f <- f + amps[[j]] * exp(-rowSums(dif^2) / (2 * bw[[j]]^2))
    }
    as.numeric(scale(f))
}

make.folds <- function(n, k = 5L, seed = 1L) {
    set.seed(seed)
    sample(rep(seq_len(k), length.out = n))
}

truth.rmse <- function(pred, p) sqrt(mean((as.numeric(pred) - p)^2))
brier.score <- function(pred, p) mean((as.numeric(pred) - p)^2)
logloss.score <- function(pred, y, eps = 1e-12) {
    pred <- pmin(1 - eps, pmax(eps, as.numeric(pred)))
    -mean(y * log(pred) + (1 - y) * log(1 - pred))
}

first.or.na <- function(x) {
    if (is.null(x) || length(x) == 0L || all(is.na(x))) NA else x[[1L]]
}
