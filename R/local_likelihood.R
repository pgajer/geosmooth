#' Fit a Local-Likelihood Density/Intensity Smoother
#'
#' Fits a local likelihood model at each evaluation point and reads off one raw
#' fitted value at that evaluation anchor.  Density workflows should convert
#' the returned fitted field with \code{\link{normalize.density}}.
#'
#' The first implemented branch is \code{likelihood.family = "density"}.  It
#' uses a local exponential tilt of the chart reference measure.  The
#' \code{"bernoulli"} branch is reserved in the API but is not implemented yet.
#'
#' @param X Numeric matrix with one row per source/support point.
#' @param y Numeric response vector.  For \code{likelihood.family = "density"},
#'   this must be a nonnegative mass/intensity vector with positive total mass.
#' @param X.eval Optional numeric matrix of evaluation points. Defaults to
#'   \code{X}.
#' @param likelihood.family Local likelihood family.  Only \code{"density"} is
#'   implemented in this phase.
#' @param support.size Number of source points in each local support.
#' @param degree Local chart feature degree.  Supported values are 0, 1, and 2.
#'   The feature map omits an intercept because the intercept is not
#'   identifiable in the normalized local density likelihood.
#' @param kernel Kernel name. Supported values are \code{"gaussian"},
#'   \code{"tricube"}, \code{"epanechnikov"}, and \code{"triangular"}.
#' @param bandwidth.multiplier Positive multiplier applied to the local support
#'   radius.
#' @param coordinate.method Local coordinate method. \code{"coordinates"} uses
#'   centered ambient coordinates. \code{"local.pca"} projects centered support
#'   points onto a local PCA basis.
#' @param chart.dim Local PCA dimension when \code{coordinate.method =
#'   "local.pca"}. If \code{NULL}, the dimension is
#'   \code{min(ncol(X), support.size - 1)}.
#' @param quadrature.weights Optional positive reference-measure weights.
#'   Defaults to unit weights.
#' @param lambda.ridge Nonnegative ridge penalty on identifiable coefficients.
#' @param min.local.mass Minimum local kernel-weighted mass needed before
#'   attempting a higher-degree local fit.
#' @param min.nonzero.mass Minimum number of locally weighted positive-mass
#'   source points needed before attempting a higher-degree local fit.
#' @param fallback Fallback policy for underidentified or failed higher-degree
#'   local fits.  Zero local mass always uses \code{"zero"}.
#' @param optimizer Optimizer for nonzero-degree density fits.  \code{"newton"}
#'   is implemented; \code{"optim"} is accepted and delegates to BFGS.
#' @param max.iter Maximum optimizer iterations.
#' @param tol Convergence tolerance for gradient norm and step norm.
#' @param return.details Logical; if \code{TRUE}, keep per-evaluation
#'   diagnostics.
#'
#' @return A list with class \code{"local_likelihood"} containing
#'   \code{fitted.values}, selected controls, and local solver diagnostics.
#' @export
fit.local.likelihood <- function(
    X,
    y,
    X.eval = NULL,
    likelihood.family = c("density", "bernoulli"),
    support.size = min(15L, nrow(X)),
    degree = 1L,
    kernel = c("gaussian", "tricube", "epanechnikov", "triangular"),
    bandwidth.multiplier = 1,
    coordinate.method = c("coordinates", "local.pca"),
    chart.dim = NULL,
    quadrature.weights = NULL,
    lambda.ridge = 1e-8,
    min.local.mass = sqrt(.Machine$double.eps),
    min.nonzero.mass = 1L,
    fallback = c("degree0", "zero", "chart_kernel", "na"),
    optimizer = c("newton", "optim"),
    max.iter = 50L,
    tol = 1e-8,
    return.details = TRUE) {

    prepared <- .local.chart.prepare.X.eval(X, X.eval)
    X <- prepared$X
    X.eval <- prepared$X.eval
    n <- nrow(X)
    p <- ncol(X)
    likelihood.family <- match.arg(likelihood.family)
    if (identical(likelihood.family, "bernoulli")) {
        stop("fit.local.likelihood(likelihood.family = \"bernoulli\") is reserved but not implemented yet.",
             call. = FALSE)
    }
    y <- .local.chart.validate.response(y, n, nonnegative = TRUE)
    if (sum(y) <= 0) {
        stop("y must have positive total mass for likelihood.family = \"density\".",
             call. = FALSE)
    }
    support.size <- .local.chart.validate.support.size(support.size, n)
    degree <- .local.likelihood.validate.degree(degree)
    kernel <- match.arg(kernel)
    bandwidth.multiplier <- .local.chart.validate.positive.scalar(
        bandwidth.multiplier, "bandwidth.multiplier"
    )
    coordinate.method <- match.arg(coordinate.method)
    chart.dim <- .local.chart.validate.chart.dim(
        chart.dim = chart.dim,
        coordinate.method = coordinate.method,
        p = p,
        support.size = support.size
    )
    quadrature.weights <- .local.chart.validate.quadrature(
        quadrature.weights, n
    )
    lambda.ridge <- .local.chart.validate.nonnegative.scalar(
        lambda.ridge, "lambda.ridge"
    )
    min.local.mass <- .local.chart.validate.nonnegative.scalar(
        min.local.mass, "min.local.mass"
    )
    min.nonzero.mass <- .local.chart.validate.positive.integer(
        min.nonzero.mass, "min.nonzero.mass"
    )
    fallback <- match.arg(fallback)
    optimizer <- match.arg(optimizer)
    max.iter <- .local.chart.validate.positive.integer(max.iter, "max.iter")
    tol <- .local.chart.validate.positive.scalar(tol, "tol")

    ne <- nrow(X.eval)
    fitted <- numeric(ne)
    status <- character(ne)
    local.mass <- numeric(ne)
    n.nonzero.local <- integer(ne)
    effective.support <- integer(ne)
    degree.used <- integer(ne)
    resolved.chart.dim <- integer(ne)
    iterations <- integer(ne)
    objective <- numeric(ne)
    gradient.norm <- numeric(ne)
    normalization.constant <- numeric(ne)
    bandwidth <- numeric(ne)
    fallback.used <- logical(ne)

    for (ii in seq_len(ne)) {
        local <- .local.likelihood.density.fit(
            X = X,
            y = y,
            x0 = X.eval[ii, ],
            support.size = support.size,
            degree = degree,
            kernel = kernel,
            bandwidth.multiplier = bandwidth.multiplier,
            coordinate.method = coordinate.method,
            chart.dim = chart.dim,
            quadrature.weights = quadrature.weights,
            lambda.ridge = lambda.ridge,
            min.local.mass = min.local.mass,
            min.nonzero.mass = min.nonzero.mass,
            fallback = fallback,
            optimizer = optimizer,
            max.iter = max.iter,
            tol = tol
        )
        fitted[[ii]] <- local$value
        status[[ii]] <- local$status
        local.mass[[ii]] <- local$local.mass
        n.nonzero.local[[ii]] <- local$n.nonzero.local
        effective.support[[ii]] <- local$effective.support
        degree.used[[ii]] <- local$degree.used
        resolved.chart.dim[[ii]] <- local$chart.dim
        iterations[[ii]] <- local$iterations
        objective[[ii]] <- local$objective
        gradient.norm[[ii]] <- local$gradient.norm
        normalization.constant[[ii]] <- local$normalization.constant
        bandwidth[[ii]] <- local$bandwidth
        fallback.used[[ii]] <- local$fallback.used
    }

    diagnostics <- list(
        status.counts = as.list(table(factor(
            status,
            levels = c("ok", "zero_mass_fallback", "degree0_fallback",
                       "chart_kernel_fallback", "optimizer_failed",
                       "nonfinite_fit")
        ))),
        fallback.count = sum(fallback.used),
        fallback.fraction = mean(fallback.used),
        min.local.mass = min(local.mass),
        median.local.mass = stats::median(local.mass),
        min.normalization.constant = suppressWarnings(
            min(normalization.constant, na.rm = TRUE)
        ),
        median.normalization.constant = suppressWarnings(
            stats::median(normalization.constant, na.rm = TRUE)
        ),
        degree.used.summary = summary(degree.used),
        chart.dim.summary = summary(resolved.chart.dim)
    )
    if (isTRUE(return.details)) {
        diagnostics$per.eval <- data.frame(
            eval.index = seq_len(ne),
            status = status,
            M.local = local.mass,
            n.nonzero.local = n.nonzero.local,
            support.size = support.size,
            effective.support = effective.support,
            chart.dim = resolved.chart.dim,
            degree.requested = degree,
            degree.used = degree.used,
            lambda.ridge = lambda.ridge,
            iterations = iterations,
            objective = objective,
            gradient.norm = gradient.norm,
            normalization.constant = normalization.constant,
            bandwidth = bandwidth,
            raw.fitted = fitted,
            fallback.used = fallback.used
        )
    }

    out <- list(
        method.id = "local_likelihood",
        likelihood.family = likelihood.family,
        X = X,
        X.eval = X.eval,
        y = y,
        fitted.values = fitted,
        selected = list(
            likelihood.family = likelihood.family,
            support.size = support.size,
            degree = degree,
            kernel = kernel,
            bandwidth.multiplier = bandwidth.multiplier,
            coordinate.method = coordinate.method,
            chart.dim = chart.dim,
            lambda.ridge = lambda.ridge,
            min.local.mass = min.local.mass,
            min.nonzero.mass = min.nonzero.mass,
            fallback = fallback,
            optimizer = optimizer,
            max.iter = max.iter,
            tol = tol
        ),
        quadrature.weights = quadrature.weights,
        diagnostics = diagnostics,
        call = match.call()
    )
    class(out) <- c("local_likelihood", "list")
    out
}

.local.likelihood.validate.degree <- function(degree) {
    degree <- .local.chart.validate.nonnegative.integer(degree, "degree")
    if (!degree %in% 0:2) {
        stop("degree must be 0, 1, or 2 for fit.local.likelihood().",
             call. = FALSE)
    }
    degree
}

.local.likelihood.density.fit <- function(X,
                                          y,
                                          x0,
                                          support.size,
                                          degree,
                                          kernel,
                                          bandwidth.multiplier,
                                          coordinate.method,
                                          chart.dim,
                                          quadrature.weights,
                                          lambda.ridge,
                                          min.local.mass,
                                          min.nonzero.mass,
                                          fallback,
                                          optimizer,
                                          max.iter,
                                          tol) {
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
    r <- kernel.info$weights
    q <- quadrature.weights[idx]
    y.local <- y[idx]
    local.mass <- sum(r * y.local)
    n.nonzero <- sum(y.local > 0 & r > 0)
    base <- q * r

    if (!is.finite(local.mass) || local.mass < min.local.mass) {
        return(.local.likelihood.density.fallback(
            status = "zero_mass_fallback",
            value = 0,
            local.mass = local.mass,
            n.nonzero.local = n.nonzero,
            effective.support = kernel.info$effective.support,
            degree.used = 0L,
            chart.dim = ncol(coords),
            iterations = 0L,
            objective = NA_real_,
            gradient.norm = NA_real_,
            normalization.constant = sum(base),
            bandwidth = kernel.info$bandwidth,
            fallback.used = TRUE
        ))
    }

    features <- .local.chart.feature.matrix(coords, degree)
    if (degree == 0L || ncol(features) == 0L ||
        n.nonzero < min.nonzero.mass ||
        kernel.info$effective.support <= ncol(features) + 1L) {
        return(.local.likelihood.degree0.fit(
            base = base,
            local.mass = local.mass,
            n.nonzero.local = n.nonzero,
            effective.support = kernel.info$effective.support,
            chart.dim = ncol(coords),
            bandwidth = kernel.info$bandwidth,
            status = if (degree == 0L) "ok" else "degree0_fallback",
            fallback.used = degree != 0L
        ))
    }

    solved <- .local.likelihood.density.solve(
        features = features,
        base = base,
        target = r * y.local,
        local.mass = local.mass,
        lambda.ridge = lambda.ridge,
        optimizer = optimizer,
        max.iter = max.iter,
        tol = tol
    )
    if (!isTRUE(solved$converged) || !is.finite(solved$value)) {
        return(.local.likelihood.apply.fallback(
            fallback = fallback,
            base = base,
            r = r,
            q = q,
            y.local = y.local,
            local.mass = local.mass,
            n.nonzero.local = n.nonzero,
            effective.support = kernel.info$effective.support,
            chart.dim = ncol(coords),
            bandwidth = kernel.info$bandwidth,
            iterations = solved$iterations,
            objective = solved$objective,
            gradient.norm = solved$gradient.norm
        ))
    }
    list(
        value = solved$value,
        status = "ok",
        local.mass = local.mass,
        n.nonzero.local = n.nonzero,
        effective.support = kernel.info$effective.support,
        degree.used = degree,
        chart.dim = ncol(coords),
        iterations = solved$iterations,
        objective = solved$objective,
        gradient.norm = solved$gradient.norm,
        normalization.constant = solved$normalization.constant,
        bandwidth = kernel.info$bandwidth,
        fallback.used = FALSE
    )
}

.local.likelihood.degree0.fit <- function(base,
                                          local.mass,
                                          n.nonzero.local,
                                          effective.support,
                                          chart.dim,
                                          bandwidth,
                                          status,
                                          fallback.used) {
    Z <- sum(base)
    value <- if (is.finite(Z) && Z > 0) local.mass / Z else NA_real_
    .local.likelihood.density.fallback(
        status = status,
        value = value,
        local.mass = local.mass,
        n.nonzero.local = n.nonzero.local,
        effective.support = effective.support,
        degree.used = 0L,
        chart.dim = chart.dim,
        iterations = 0L,
        objective = if (is.finite(Z) && Z > 0) local.mass * log(Z) else NA_real_,
        gradient.norm = 0,
        normalization.constant = Z,
        bandwidth = bandwidth,
        fallback.used = fallback.used
    )
}

.local.likelihood.density.fallback <- function(status,
                                               value,
                                               local.mass,
                                               n.nonzero.local,
                                               effective.support,
                                               degree.used,
                                               chart.dim,
                                               iterations,
                                               objective,
                                               gradient.norm,
                                               normalization.constant,
                                               bandwidth,
                                               fallback.used) {
    list(
        value = value,
        status = status,
        local.mass = local.mass,
        n.nonzero.local = n.nonzero.local,
        effective.support = effective.support,
        degree.used = degree.used,
        chart.dim = chart.dim,
        iterations = iterations,
        objective = objective,
        gradient.norm = gradient.norm,
        normalization.constant = normalization.constant,
        bandwidth = bandwidth,
        fallback.used = fallback.used
    )
}

.local.likelihood.apply.fallback <- function(fallback,
                                             base,
                                             r,
                                             q,
                                             y.local,
                                             local.mass,
                                             n.nonzero.local,
                                             effective.support,
                                             chart.dim,
                                             bandwidth,
                                             iterations,
                                             objective,
                                             gradient.norm) {
    if (identical(fallback, "zero")) {
        return(.local.likelihood.density.fallback(
            status = "optimizer_failed",
            value = 0,
            local.mass = local.mass,
            n.nonzero.local = n.nonzero.local,
            effective.support = effective.support,
            degree.used = 0L,
            chart.dim = chart.dim,
            iterations = iterations,
            objective = objective,
            gradient.norm = gradient.norm,
            normalization.constant = sum(base),
            bandwidth = bandwidth,
            fallback.used = TRUE
        ))
    }
    if (identical(fallback, "chart_kernel")) {
        denom <- sum(q * r)
        numer <- sum(r * y.local)
        return(.local.likelihood.density.fallback(
            status = "chart_kernel_fallback",
            value = numer / denom,
            local.mass = local.mass,
            n.nonzero.local = n.nonzero.local,
            effective.support = effective.support,
            degree.used = 0L,
            chart.dim = chart.dim,
            iterations = iterations,
            objective = objective,
            gradient.norm = gradient.norm,
            normalization.constant = denom,
            bandwidth = bandwidth,
            fallback.used = TRUE
        ))
    }
    if (identical(fallback, "na")) {
        return(.local.likelihood.density.fallback(
            status = "nonfinite_fit",
            value = NA_real_,
            local.mass = local.mass,
            n.nonzero.local = n.nonzero.local,
            effective.support = effective.support,
            degree.used = 0L,
            chart.dim = chart.dim,
            iterations = iterations,
            objective = objective,
            gradient.norm = gradient.norm,
            normalization.constant = sum(base),
            bandwidth = bandwidth,
            fallback.used = TRUE
        ))
    }
    .local.likelihood.degree0.fit(
        base = base,
        local.mass = local.mass,
        n.nonzero.local = n.nonzero.local,
        effective.support = effective.support,
        chart.dim = chart.dim,
        bandwidth = bandwidth,
        status = "degree0_fallback",
        fallback.used = TRUE
    )
}

.local.likelihood.density.solve <- function(features,
                                            base,
                                            target,
                                            local.mass,
                                            lambda.ridge,
                                            optimizer,
                                            max.iter,
                                            tol) {
    m <- ncol(features)
    if (m == 0L) {
        Z <- sum(base)
        return(list(
            converged = TRUE,
            value = local.mass / Z,
            iterations = 0L,
            objective = local.mass * log(Z),
            gradient.norm = 0,
            normalization.constant = Z
        ))
    }
    if (identical(optimizer, "optim")) {
        return(.local.likelihood.density.solve.optim(
            features = features,
            base = base,
            target = target,
            local.mass = local.mass,
            lambda.ridge = lambda.ridge,
            max.iter = max.iter,
            tol = tol
        ))
    }
    beta <- numeric(m)
    state <- .local.likelihood.density.state(
        beta, features, base, target, local.mass, lambda.ridge
    )
    converged <- FALSE
    iter <- 0L
    for (iter in seq_len(max.iter)) {
        if (!is.finite(state$objective) ||
            !all(is.finite(state$gradient)) ||
            !all(is.finite(state$hessian))) {
            break
        }
        grad.norm <- sqrt(sum(state$gradient^2))
        if (grad.norm <= tol) {
            converged <- TRUE
            break
        }
        step <- tryCatch(
            solve(state$hessian, state$gradient),
            error = function(e) rep(NA_real_, length(beta))
        )
        if (any(!is.finite(step))) {
            break
        }
        step.scale <- 1
        accepted <- FALSE
        for (hh in seq_len(30L)) {
            candidate <- beta - step.scale * step
            candidate.state <- .local.likelihood.density.state(
                candidate, features, base, target, local.mass, lambda.ridge
            )
            if (is.finite(candidate.state$objective) &&
                candidate.state$objective <= state$objective + 1e-10) {
                beta <- candidate
                state <- candidate.state
                accepted <- TRUE
                break
            }
            step.scale <- step.scale / 2
        }
        if (!isTRUE(accepted)) {
            break
        }
        if (sqrt(sum((step.scale * step)^2)) <= tol) {
            converged <- TRUE
            break
        }
    }
    value <- .local.likelihood.anchor.value(local.mass, state$logZ)
    list(
        converged = converged,
        value = value,
        iterations = as.integer(iter),
        objective = state$objective,
        gradient.norm = sqrt(sum(state$gradient^2)),
        normalization.constant = exp(state$logZ)
    )
}

.local.likelihood.density.solve.optim <- function(features,
                                                  base,
                                                  target,
                                                  local.mass,
                                                  lambda.ridge,
                                                  max.iter,
                                                  tol) {
    fn <- function(beta) {
        .local.likelihood.density.state(
            beta, features, base, target, local.mass, lambda.ridge
        )$objective
    }
    gr <- function(beta) {
        .local.likelihood.density.state(
            beta, features, base, target, local.mass, lambda.ridge
        )$gradient
    }
    fit <- tryCatch(
        stats::optim(
            par = numeric(ncol(features)),
            fn = fn,
            gr = gr,
            method = "BFGS",
            control = list(maxit = max.iter, reltol = tol)
        ),
        error = function(e) NULL
    )
    if (is.null(fit)) {
        return(list(
            converged = FALSE,
            value = NA_real_,
            iterations = 0L,
            objective = NA_real_,
            gradient.norm = NA_real_,
            normalization.constant = NA_real_
        ))
    }
    state <- .local.likelihood.density.state(
        fit$par, features, base, target, local.mass, lambda.ridge
    )
    list(
        converged = fit$convergence == 0L,
        value = .local.likelihood.anchor.value(local.mass, state$logZ),
        iterations = as.integer(fit$counts[["function"]]),
        objective = state$objective,
        gradient.norm = sqrt(sum(state$gradient^2)),
        normalization.constant = exp(state$logZ)
    )
}

.local.likelihood.density.state <- function(beta,
                                            features,
                                            base,
                                            target,
                                            local.mass,
                                            lambda.ridge) {
    eta <- as.numeric(features %*% beta)
    log.weights <- ifelse(base > 0, log(base) + eta, -Inf)
    logZ <- .local.likelihood.logsumexp(log.weights)
    if (!is.finite(logZ)) {
        m <- length(beta)
        return(list(
            objective = Inf,
            gradient = rep(Inf, m),
            hessian = matrix(Inf, m, m),
            logZ = logZ
        ))
    }
    prob <- exp(log.weights - logZ)
    mean.features <- colSums(features * prob)
    weighted.features <- features * matrix(prob, nrow = nrow(features),
                                           ncol = ncol(features))
    second <- crossprod(features, weighted.features)
    cov.features <- second - tcrossprod(mean.features)
    objective <- -sum(target * eta) + local.mass * logZ +
        0.5 * lambda.ridge * sum(beta^2)
    gradient <- -colSums(features * target) + local.mass * mean.features +
        lambda.ridge * beta
    hessian <- local.mass * cov.features +
        diag(lambda.ridge, nrow = length(beta), ncol = length(beta))
    list(
        objective = objective,
        gradient = as.numeric(gradient),
        hessian = hessian,
        logZ = logZ
    )
}

.local.likelihood.anchor.value <- function(local.mass, logZ) {
    if (!is.finite(logZ)) {
        return(NA_real_)
    }
    local.mass * exp(-logZ)
}

.local.likelihood.logsumexp <- function(x) {
    finite <- is.finite(x)
    if (!any(finite)) {
        return(-Inf)
    }
    mx <- max(x[finite])
    mx + log(sum(exp(x[finite] - mx)))
}
