#' Fit Prediction-Synchronized Local Polynomial Smoothing
#'
#' Experimental R reference implementation of prediction-synchronized local
#' polynomial smoothing (PS-LPS).  For fixed local polynomial parameters, PS-LPS
#' fits one local polynomial chart per anchor and adds a quadratic penalty that
#' synchronizes chart predictions on overlap points.
#'
#' @param X Numeric covariate matrix.
#' @param y Numeric response vector.
#' @param foldid Optional integer cross-validation fold assignment.
#' @param support.size Optional single neighborhood size for the fixed local
#'   setup path. Use \code{support.grid} for CV selection over neighborhood
#'   sizes.
#' @param degree Single local polynomial degree for the fixed local setup path.
#'   Use \code{degree.grid} for CV selection over degrees.
#' @param kernel Single kernel name for the fixed local setup path. Use
#'   \code{kernel.grid} for CV selection over kernels.
#' @param chart.dim Chart dimension for the local PCA charts. A scalar fixes
#'   one dimension for all anchors; an integer vector supplies one local chart
#'   dimension per anchor. The special value \code{"auto"} estimates one global
#'   chart dimension from observed \code{X} only. The experimental special
#'   value \code{"local.auto"} estimates one local chart dimension per anchor,
#'   using the same local-PCA dimension rule as \code{\link{fit.lps}}.
#' @param support.grid Candidate neighborhood sizes. When supplied, PS-LPS
#'   selects over support size, degree, kernel, and synchronization strength by
#'   materialized-fold CV. If both \code{support.size} and \code{support.grid}
#'   are absent, defaults to \code{c(10L, 15L, 20L)}, matching
#'   \code{\link{fit.lps}}.
#' @param degree.grid Candidate local polynomial degrees for grid selection.
#'   Defaults to the scalar \code{degree}.
#' @param kernel.grid Candidate kernels for grid selection. Defaults to the
#'   scalar \code{kernel}.
#' @param auto.chart.support.metric Support system used when
#'   \code{chart.dim = "auto"} or \code{"local.auto"}. Because PS-LPS uses
#'   coordinate supports, \code{"operator"} is equivalent to
#'   \code{"coordinates"}.
#' @param auto.chart.selection.metric Which auto chart-dimension diagnostic to
#'   select when both diagnostics are requested.
#' @param lambda.sync.grid Candidate synchronization strengths.
#' @param lambda.sync.search Lambda-search policy.  \code{"grid"} evaluates the
#'   supplied grid exactly.  \code{"guarded"} uses an experimental guarded
#'   coarse-to-refine search with boundary expansion.
#' @param lambda.sync.search.control Optional list controlling guarded search.
#'   Supported fields are \code{coarse.size} (default \code{5}),
#'   \code{refine.radius} (default \code{2}), \code{rel.tol} (default
#'   \code{0.002}), \code{boundary.guard.rel.tol} (default \code{0.01}),
#'   \code{boundary.expand} (default \code{TRUE}), \code{boundary.factor}
#'   (default \code{3}), \code{max.boundary.expansions} (default \code{2}),
#'   and \code{max.candidates} (default \code{25}).  Boundary expansion may
#'   evaluate positive candidates outside the supplied \code{lambda.sync.grid}.
#'   \code{max.candidates} is a global cap on distinct evaluated candidates; a
#'   very small cap can prevent local refinement or boundary expansion.
#' @param lambda.ridge Nonnegative scale-relative ridge used in the chart
#'   coefficient solve. Use \code{0} for the unregularized least-squares model.
#' @param sync.neighbor.size Number of nearby anchor pairs considered for
#'   synchronization from each anchor support.
#' @param overlap.weight Overlap weighting rule.
#' @param cv.folds Number of folds when \code{foldid} is absent.
#' @param cv.seed Fold seed when \code{foldid} is absent.
#' @return A list with fitted values, selected lambda, CV table, diagnostics,
#'   and fitted chart coefficients.
#' @keywords internal
#' @export
fit.ps.lps <- function(
    X, y, foldid = NULL,
    support.size = NULL,
    degree = 2L,
    kernel = "gaussian",
    chart.dim,
    support.grid = NULL,
    degree.grid = NULL,
    kernel.grid = NULL,
    auto.chart.support.metric = c("coordinates", "operator", "both"),
    auto.chart.selection.metric = c("coordinates", "operator"),
    lambda.sync.grid = c(0, 1e-3, 1e-2, 1e-1, 1, 10),
    lambda.sync.search = c("grid", "guarded"),
    lambda.sync.search.control = list(),
    lambda.ridge = 1e-8,
    sync.neighbor.size = NULL,
    overlap.weight = c("normalized.product", "product"),
    cv.folds = 5L,
    cv.seed = 1L) {

    X <- as.matrix(X)
    y <- as.numeric(y)
    if (!is.numeric(X) || !length(X) || any(!is.finite(X))) {
        stop("'X' must be a finite numeric matrix.", call. = FALSE)
    }
    if (length(y) != nrow(X) || any(!is.finite(y))) {
        stop("'y' must be finite and have length nrow(X).", call. = FALSE)
    }
    auto.chart.support.metric <- match.arg(auto.chart.support.metric)
    auto.chart.selection.metric <- match.arg(auto.chart.selection.metric)
    lambda.sync.search <- match.arg(lambda.sync.search)
    overlap.weight <- match.arg(overlap.weight)
    lambda.sync.grid <- sort(unique(as.numeric(lambda.sync.grid)))
    if (!length(lambda.sync.grid) || any(!is.finite(lambda.sync.grid)) ||
        any(lambda.sync.grid < 0)) {
        stop("'lambda.sync.grid' must contain finite nonnegative values.",
             call. = FALSE)
    }
    lambda.ridge <- as.numeric(lambda.ridge[[1L]])
    if (!is.finite(lambda.ridge) || lambda.ridge < 0) {
        stop("'lambda.ridge' must be a finite nonnegative scalar.",
             call. = FALSE)
    }
    foldid <- .klp.prepare.foldid(nrow(X), foldid, cv.folds, cv.seed)
    local.grid <- .ps.lps.resolve.local.grid(
        support.size = support.size,
        support.grid = support.grid,
        degree = degree,
        degree.grid = degree.grid,
        kernel = kernel,
        kernel.grid = kernel.grid,
        n = nrow(X)
    )
    if (nrow(local.grid) > 1L) {
        return(.ps.lps.fit.local.grid(
            X = X,
            y = y,
            foldid = foldid,
            local.grid = local.grid,
            chart.dim = chart.dim,
            auto.chart.support.metric = auto.chart.support.metric,
            auto.chart.selection.metric = auto.chart.selection.metric,
            lambda.sync.grid = lambda.sync.grid,
            lambda.sync.search = lambda.sync.search,
            lambda.sync.search.control = lambda.sync.search.control,
            lambda.ridge = lambda.ridge,
            sync.neighbor.size = sync.neighbor.size,
            overlap.weight = overlap.weight,
            cv.folds = cv.folds,
            cv.seed = cv.seed
        ))
    }
    support.size <- local.grid$support.size[[1L]]
    degree <- local.grid$degree[[1L]]
    kernel <- local.grid$kernel[[1L]]
    sync.neighbor.size <- .ps.lps.resolve.sync.neighbor.size(
        sync.neighbor.size,
        support.size
    )
    chart.dim.info <- .ps.lps.resolve.chart.dim(
        X = X,
        support.size = support.size,
        degree = degree,
        chart.dim = chart.dim,
        auto.chart.support.metric = auto.chart.support.metric,
        auto.chart.selection.metric = auto.chart.selection.metric
    )
    chart.dim.by.anchor <- chart.dim.info$chart.dim.by.anchor
    frames <- .ps.lps.prepare.frames(
        X = X,
        y = y,
        support.size = support.size,
        degree = degree,
        kernel = kernel,
        chart.dim.by.anchor = chart.dim.by.anchor
    )
    sync.rows <- .ps.lps.prepare.sync.rows(
        frames = frames,
        sync.neighbor.size = sync.neighbor.size,
        overlap.weight = overlap.weight
    )
    folds <- sort(unique(foldid))
    has.positive.sync <- any(lambda.sync.grid > 0)
    fold.component.caches <- vector("list", length(folds))
    names(fold.component.caches) <- as.character(folds)
    full.component.cache <- NULL
    if (has.positive.sync) {
        system.cache <- .ps.lps.prepare.system.cache(frames, sync.rows)
        for (fold in folds) {
            response.weights <- as.numeric(foldid != fold)
            fold.component.caches[[as.character(fold)]] <-
                .ps.lps.prepare.component.cache(
                    cache = system.cache,
                    y = y,
                    response.weights = response.weights
                )
        }
        full.component.cache <- .ps.lps.prepare.component.cache(
            cache = system.cache,
            y = y,
            response.weights = rep(1, length(y))
        )
    }

    evaluate.lambda <- function(lambda) {
        pred <- rep(NA_real_, length(y))
        for (fold in folds) {
            response.weights <- as.numeric(foldid != fold)
            fit.fold <- if (lambda > 0) {
                .ps.lps.solve.component.cached(
                    component.cache = fold.component.caches[[as.character(fold)]],
                    lambda.sync = lambda,
                    lambda.ridge = lambda.ridge
                )
            } else {
                .ps.lps.solve(
                    frames = frames,
                    y = y,
                    response.weights = response.weights,
                    lambda.sync = lambda,
                    lambda.ridge = lambda.ridge,
                    sync.rows = sync.rows
                )
            }
            pred[foldid == fold] <- fit.fold$fitted.values[foldid == fold]
        }
        cv.rmse <- .klp.rmse(pred, y)
        fit.diag <- if (lambda > 0) {
            .ps.lps.solve.component.cached(
                component.cache = full.component.cache,
                lambda.sync = lambda,
                lambda.ridge = lambda.ridge,
                coefficients.only = TRUE
            )
        } else {
            .ps.lps.solve(
                frames = frames,
                y = y,
                response.weights = rep(1, length(y)),
                lambda.sync = lambda,
                lambda.ridge = lambda.ridge,
                sync.rows = sync.rows,
                coefficients.only = TRUE
            )
        }
        data.frame(
            lambda.sync = lambda,
            lambda.ridge = lambda.ridge,
            cv.rmse.observed = cv.rmse,
            total.local.gcv.ps = fit.diag$total.local.gcv.ps,
            sync.energy = fit.diag$sync.energy,
            mean.sync.squared.disagreement =
                fit.diag$mean.sync.squared.disagreement,
            ridge.median = fit.diag$ridge.median,
            ridge.max = fit.diag$ridge.max,
            stringsAsFactors = FALSE
        )
    }

    if (identical(lambda.sync.search, "guarded")) {
        search.out <- .ps.lps.search.lambda.sync(
            evaluate = evaluate.lambda,
            lambda.grid = lambda.sync.grid,
            control = lambda.sync.search.control
        )
        cv.table <- search.out$evaluated
        selected <- search.out$selected
        search.telemetry <- search.out$telemetry
    } else {
        cv.table <- do.call(rbind, lapply(lambda.sync.grid, evaluate.lambda))
        cv.table <- cv.table[order(cv.table$lambda.sync), , drop = FALSE]
        selected <- .ps.lps.select.lambda.table(cv.table, rel.tol = 0)
        search.telemetry <- .ps.lps.grid.search.telemetry(lambda.sync.grid)
    }

    final <- if (selected$lambda.sync[[1L]] > 0) {
        .ps.lps.solve.component.cached(
            component.cache = full.component.cache,
            lambda.sync = selected$lambda.sync[[1L]],
            lambda.ridge = lambda.ridge
        )
    } else {
        .ps.lps.solve(
            frames = frames,
            y = y,
            response.weights = rep(1, length(y)),
            lambda.sync = selected$lambda.sync[[1L]],
            lambda.ridge = lambda.ridge,
            sync.rows = sync.rows
        )
    }
    out <- c(
        list(
            method.id = "ps_lps",
            method.label = "PS-LPS",
            X = X,
            y = y,
            support.size = support.size,
            support.grid = support.size,
            degree = degree,
            degree.grid = degree,
            kernel = kernel,
            kernel.grid = kernel,
            requested.chart.dim = chart.dim,
            chart.dim = if (length(unique(chart.dim.by.anchor)) == 1L) {
                unique(chart.dim.by.anchor)
            } else {
                stats::median(chart.dim.by.anchor)
            },
            chart.dim.mode = chart.dim.info$chart.dim.mode,
            chart.dim.by.anchor = chart.dim.by.anchor,
            auto.chart.dim = chart.dim.info$auto.chart.dim,
            auto.chart.dim.diagnostics =
                chart.dim.info$auto.chart.dim.diagnostics,
            auto.chart.support.metric = auto.chart.support.metric,
            auto.chart.selection.metric = auto.chart.selection.metric,
            lambda.sync.grid = lambda.sync.grid,
            lambda.sync.search = lambda.sync.search,
            lambda.sync.search.telemetry = search.telemetry,
            lambda.ridge = lambda.ridge,
            selected = selected,
            cv.table = cv.table,
            foldid = foldid,
            sync.neighbor.size = sync.neighbor.size,
            overlap.weight = overlap.weight,
            cache.backend = if (has.positive.sync) {
                "component"
            } else {
                "independent"
            }
        ),
        final
    )
    class(out) <- c("ps_lps", "list")
    out
}

.ps.lps.resolve.local.grid <- function(support.size = NULL,
                                       support.grid = NULL,
                                       degree = 2L,
                                       degree.grid = NULL,
                                       kernel = "gaussian",
                                       kernel.grid = NULL,
                                       n) {
    if (!is.null(support.size) && !is.null(support.grid)) {
        stop("Use either 'support.size' or 'support.grid', not both.",
             call. = FALSE)
    }
    if (is.null(support.grid)) {
        support.grid <- if (is.null(support.size)) {
            c(10L, 15L, 20L)
        } else {
            support.size
        }
    }
    if (is.null(degree.grid)) degree.grid <- degree
    if (is.null(kernel.grid)) kernel.grid <- kernel
    support.grid <- .klp.clean.support.grid(support.grid, n)
    degree.grid <- .klp.clean.degree.grid(degree.grid)
    kernel.grid <- .klp.clean.kernel.grid(kernel.grid)
    cand <- expand.grid(
        support.size = support.grid,
        degree = degree.grid,
        kernel = kernel.grid,
        KEEP.OUT.ATTRS = FALSE,
        stringsAsFactors = FALSE
    )
    cand[order(cand$support.size, cand$degree, cand$kernel), , drop = FALSE]
}

.ps.lps.resolve.sync.neighbor.size <- function(sync.neighbor.size,
                                               support.size) {
    if (is.null(sync.neighbor.size)) {
        sync.neighbor.size <- min(8L, as.integer(support.size) - 1L)
    }
    sync.neighbor.size <- as.integer(sync.neighbor.size[[1L]])
    if (!is.finite(sync.neighbor.size) || sync.neighbor.size < 1L ||
        sync.neighbor.size >= support.size) {
        stop("'sync.neighbor.size' must be an integer in [1, support.size - 1].",
             call. = FALSE)
    }
    sync.neighbor.size
}

.ps.lps.fit.local.grid <- function(
    X, y, foldid, local.grid, chart.dim, auto.chart.support.metric,
    auto.chart.selection.metric, lambda.sync.grid, lambda.sync.search,
    lambda.sync.search.control, lambda.ridge, sync.neighbor.size,
    overlap.weight, cv.folds, cv.seed) {

    fits <- vector("list", nrow(local.grid))
    candidate.rows <- vector("list", nrow(local.grid))
    lambda.rows <- vector("list", nrow(local.grid))
    for (ii in seq_len(nrow(local.grid))) {
        row <- local.grid[ii, , drop = FALSE]
        fit <- fit.ps.lps(
            X = X,
            y = y,
            foldid = foldid,
            support.size = row$support.size[[1L]],
            degree = row$degree[[1L]],
            kernel = row$kernel[[1L]],
            chart.dim = chart.dim,
            support.grid = NULL,
            degree.grid = NULL,
            kernel.grid = NULL,
            auto.chart.support.metric = auto.chart.support.metric,
            auto.chart.selection.metric = auto.chart.selection.metric,
            lambda.sync.grid = lambda.sync.grid,
            lambda.sync.search = lambda.sync.search,
            lambda.sync.search.control = lambda.sync.search.control,
            lambda.ridge = lambda.ridge,
            sync.neighbor.size = sync.neighbor.size,
            overlap.weight = overlap.weight,
            cv.folds = cv.folds,
            cv.seed = cv.seed
        )
        fits[[ii]] <- fit
        selected <- fit$selected[1L, , drop = FALSE]
        candidate.rows[[ii]] <- data.frame(
            local.candidate.id = ii,
            support.size = fit$support.size,
            degree = fit$degree,
            kernel = fit$kernel,
            chart.dim = fit$chart.dim,
            chart.dim.mode = fit$chart.dim.mode,
            selected.lambda.sync = selected$lambda.sync[[1L]],
            selected.lambda.ridge = selected$lambda.ridge[[1L]],
            selected.cv.rmse.observed = selected$cv.rmse.observed[[1L]],
            selected.total.local.gcv.ps = selected$total.local.gcv.ps[[1L]],
            selected.sync.energy = selected$sync.energy[[1L]],
            selected.mean.sync.squared.disagreement =
                selected$mean.sync.squared.disagreement[[1L]],
            evaluated.lambda.count = nrow(fit$cv.table),
            boundary.expansion.count =
                sum(grepl("^boundary_expand_",
                          fit$lambda.sync.search.telemetry$stage)),
            stringsAsFactors = FALSE
        )
        tab <- fit$cv.table
        tab$local.candidate.id <- ii
        tab$support.size <- fit$support.size
        tab$degree <- fit$degree
        tab$kernel <- fit$kernel
        tab$chart.dim <- fit$chart.dim
        tab$chart.dim.mode <- fit$chart.dim.mode
        lambda.rows[[ii]] <- tab[, c(
            "local.candidate.id", "support.size", "degree", "kernel",
            "chart.dim", "chart.dim.mode",
            setdiff(names(tab), c("local.candidate.id", "support.size",
                                  "degree", "kernel", "chart.dim",
                                  "chart.dim.mode"))
        ), drop = FALSE]
    }
    candidate.table <- do.call(rbind, candidate.rows)
    ok <- is.finite(candidate.table$selected.cv.rmse.observed)
    if (!any(ok)) {
        stop("No PS-LPS local candidate produced a finite CV score.",
             call. = FALSE)
    }
    best.order <- order(
        candidate.table$selected.cv.rmse.observed[ok],
        candidate.table$selected.lambda.sync[ok],
        candidate.table$support.size[ok],
        candidate.table$degree[ok],
        candidate.table$kernel[ok]
    )
    ok.idx <- which(ok)
    best.idx <- ok.idx[best.order[[1L]]]
    best.fit <- fits[[best.idx]]
    best.fit$support.grid <- sort(unique(local.grid$support.size))
    best.fit$degree.grid <- sort(unique(local.grid$degree))
    best.fit$kernel.grid <- sort(unique(local.grid$kernel))
    best.fit$local.candidate.table <- candidate.table
    best.fit$lambda.cv.table <- do.call(rbind, lambda.rows)
    best.fit$selected.local.candidate <-
        candidate.table[best.idx, , drop = FALSE]
    best.fit$selection.contract <-
        "materialized_fold_cv_over_support_kernel_degree_with_lambda_sync"
    best.fit$selected <- cbind(
        candidate.table[best.idx, c("local.candidate.id", "support.size",
                                    "degree", "kernel", "chart.dim",
                                    "chart.dim.mode"), drop = FALSE],
        best.fit$selected
    )
    best.fit
}

.ps.lps.select.lambda.table <- function(x, rel.tol = 0) {
    if (!nrow(x)) stop("'x' must contain at least one lambda row.", call. = FALSE)
    rel.tol <- as.numeric(rel.tol[[1L]])
    if (!is.finite(rel.tol) || rel.tol < 0) {
        stop("'rel.tol' must be a finite nonnegative scalar.", call. = FALSE)
    }
    best <- min(x$cv.rmse.observed, na.rm = TRUE)
    if (!is.finite(best)) {
        stop("No finite CV RMSE values are available.", call. = FALSE)
    }
    cutoff <- best * (1 + rel.tol)
    tied <- x[is.finite(x$cv.rmse.observed) &
                  x$cv.rmse.observed <= cutoff, , drop = FALSE]
    tied[order(tied$lambda.sync), , drop = FALSE][1L, , drop = FALSE]
}

.ps.lps.raw.best.lambda.table <- function(x) {
    if (!nrow(x)) stop("'x' must contain at least one lambda row.", call. = FALSE)
    x[order(x$cv.rmse.observed, x$lambda.sync), , drop = FALSE][1L, ,
                                                                drop = FALSE]
}

.ps.lps.search.control <- function(control) {
    defaults <- list(
        coarse.size = 5L,
        refine.radius = 2L,
        rel.tol = 0.002,
        boundary.guard.rel.tol = 0.01,
        boundary.expand = TRUE,
        boundary.factor = 3,
        max.boundary.expansions = 2L,
        max.candidates = 25L
    )
    if (is.null(control)) control <- list()
    if (!is.list(control)) {
        stop("'lambda.sync.search.control' must be a list.", call. = FALSE)
    }
    unknown <- setdiff(names(control), names(defaults))
    if (length(unknown)) {
        stop("Unknown lambda search control field(s): ",
             paste(unknown, collapse = ", "), call. = FALSE)
    }
    out <- utils::modifyList(defaults, control)
    out$coarse.size <- as.integer(out$coarse.size[[1L]])
    out$refine.radius <- as.integer(out$refine.radius[[1L]])
    out$max.boundary.expansions <-
        as.integer(out$max.boundary.expansions[[1L]])
    out$max.candidates <- as.integer(out$max.candidates[[1L]])
    out$rel.tol <- as.numeric(out$rel.tol[[1L]])
    out$boundary.guard.rel.tol <-
        as.numeric(out$boundary.guard.rel.tol[[1L]])
    out$boundary.factor <- as.numeric(out$boundary.factor[[1L]])
    out$boundary.expand <- isTRUE(out$boundary.expand)
    if (!is.finite(out$coarse.size) || out$coarse.size < 2L) {
        stop("'coarse.size' must be an integer at least 2.", call. = FALSE)
    }
    if (!is.finite(out$refine.radius) || out$refine.radius < 1L) {
        stop("'refine.radius' must be a positive integer.", call. = FALSE)
    }
    if (!is.finite(out$max.boundary.expansions) ||
        out$max.boundary.expansions < 0L) {
        stop("'max.boundary.expansions' must be a nonnegative integer.",
             call. = FALSE)
    }
    if (!is.finite(out$max.candidates) || out$max.candidates < 1L) {
        stop("'max.candidates' must be a positive integer.", call. = FALSE)
    }
    if (!is.finite(out$rel.tol) || out$rel.tol < 0) {
        stop("'rel.tol' must be a finite nonnegative scalar.", call. = FALSE)
    }
    if (!is.finite(out$boundary.guard.rel.tol) ||
        out$boundary.guard.rel.tol < 0) {
        stop("'boundary.guard.rel.tol' must be a finite nonnegative scalar.",
             call. = FALSE)
    }
    if (!is.finite(out$boundary.factor) || out$boundary.factor <= 1) {
        stop("'boundary.factor' must be a finite scalar larger than 1.",
             call. = FALSE)
    }
    out
}

.ps.lps.grid.search.telemetry <- function(lambda.grid) {
    lambda.grid <- sort(unique(as.numeric(lambda.grid)))
    data.frame(
        stage = "full_grid",
        lambda.sync = lambda.grid,
        boundary = "none",
        expansion = 0L,
        selected.after.stage = NA_real_,
        stringsAsFactors = FALSE
    )
}

.ps.lps.search.lambda.sync <- function(evaluate, lambda.grid, control = list()) {
    if (!is.function(evaluate)) {
        stop("'evaluate' must be a function.", call. = FALSE)
    }
    ctl <- .ps.lps.search.control(control)
    lambda.grid <- sort(unique(as.numeric(lambda.grid)))
    if (!length(lambda.grid) || any(!is.finite(lambda.grid)) ||
        any(lambda.grid < 0)) {
        stop("'lambda.grid' must contain finite nonnegative values.",
             call. = FALSE)
    }
    positive <- lambda.grid[lambda.grid > 0]
    if (!length(positive)) {
        row <- evaluate(0)
        return(list(
            evaluated = row,
            selected = row,
            telemetry = data.frame(
                stage = "zero_only",
                lambda.sync = 0,
                boundary = "zero",
                expansion = 0L,
                selected.after.stage = 0,
                stringsAsFactors = FALSE
            )
        ))
    }

    eval.env <- new.env(parent = emptyenv())
    evaluated.count <- function() length(ls(eval.env, all.names = TRUE))
    eval.one <- function(lambda, stage, boundary = "none", expansion = 0L) {
        lambda <- as.numeric(lambda[[1L]])
        key <- sprintf("%.17g", lambda)
        if (!exists(key, envir = eval.env, inherits = FALSE)) {
            assign(key, evaluate(lambda), envir = eval.env)
        }
        row <- get(key, envir = eval.env, inherits = FALSE)
        row$stage <- stage
        row$boundary <- boundary
        row$expansion <- as.integer(expansion)
        row
    }
    collect.evaluated <- function() {
        keys <- ls(eval.env, all.names = TRUE)
        if (!length(keys)) {
            return(data.frame())
        }
        out <- do.call(rbind, lapply(keys, function(key) {
            get(key, envir = eval.env, inherits = FALSE)
        }))
        out[order(out$lambda.sync), , drop = FALSE]
    }
    append.telemetry <- function(rows, selected, telemetry) {
        if (!nrow(rows)) return(telemetry)
        add <- data.frame(
            stage = rows$stage,
            lambda.sync = rows$lambda.sync,
            boundary = rows$boundary,
            expansion = rows$expansion,
            selected.after.stage = selected$lambda.sync[[1L]],
            stringsAsFactors = FALSE
        )
        rbind(telemetry, add)
    }

    if (0 %in% lambda.grid) {
        eval.set <- 0
    } else {
        eval.set <- numeric(0)
    }
    remaining <- max(0L, ctl$max.candidates - length(eval.set))
    coarse.n <- min(length(positive), ctl$coarse.size, remaining)
    if (coarse.n > 0L) {
        coarse.idx <- unique(round(seq(1, length(positive),
                                       length.out = coarse.n)))
        coarse <- positive[coarse.idx]
        eval.set <- sort(unique(c(eval.set, coarse)))
    }
    telemetry <- data.frame(
        stage = character(),
        lambda.sync = numeric(),
        boundary = character(),
        expansion = integer(),
        selected.after.stage = numeric(),
        stringsAsFactors = FALSE
    )
    stage.rows <- do.call(rbind, lapply(eval.set, eval.one,
                                        stage = "coarse"))
    selected <- .ps.lps.select.lambda.table(
        collect.evaluated(),
        rel.tol = ctl$rel.tol
    )
    telemetry <- append.telemetry(stage.rows, selected, telemetry)

    coarse.raw.best <- .ps.lps.raw.best.lambda.table(collect.evaluated())
    refine.anchor <- if (coarse.raw.best$lambda.sync[[1L]] > 0) {
        coarse.raw.best$lambda.sync[[1L]]
    } else {
        selected$lambda.sync[[1L]]
    }
    if (refine.anchor > 0) {
        best.idx <- which(positive == refine.anchor)
        if (length(best.idx)) {
            lo <- max(1L, best.idx - ctl$refine.radius)
            hi <- min(length(positive), best.idx + ctl$refine.radius)
            refine <- positive[lo:hi]
        } else {
            log.grid <- log10(positive)
            nearest <- which.min(abs(log.grid - log10(refine.anchor)))
            lo <- max(1L, nearest - ctl$refine.radius)
            hi <- min(length(positive), nearest + ctl$refine.radius)
            refine <- positive[lo:hi]
        }
        already <- collect.evaluated()$lambda.sync
        refine <- refine[!refine %in% already]
        remaining <- max(0L, ctl$max.candidates - evaluated.count())
        refine <- head(refine, remaining)
        if (length(refine)) {
            stage.rows <- do.call(rbind, lapply(refine, eval.one,
                                                stage = "refine"))
            selected <- .ps.lps.select.lambda.table(
                collect.evaluated(),
                rel.tol = ctl$rel.tol
            )
            telemetry <- append.telemetry(stage.rows, selected, telemetry)
        }
    }

    expansion <- 0L
    while (ctl$boundary.expand && expansion < ctl$max.boundary.expansions &&
           evaluated.count() < ctl$max.candidates &&
           any(collect.evaluated()$lambda.sync > 0)) {
        evaluated <- collect.evaluated()
        positive.evaluated <- evaluated$lambda.sync[evaluated$lambda.sync > 0]
        if (!length(positive.evaluated)) break
        raw.best <- .ps.lps.raw.best.lambda.table(evaluated)
        best.cv <- raw.best$cv.rmse.observed[[1L]]
        left.lambda <- min(positive.evaluated)
        right.lambda <- max(positive.evaluated)
        left.row <- evaluated[evaluated$lambda.sync == left.lambda, ,
                              drop = FALSE][1L, , drop = FALSE]
        right.row <- evaluated[evaluated$lambda.sync == right.lambda, ,
                               drop = FALSE][1L, , drop = FALSE]
        near.left <- is.finite(left.row$cv.rmse.observed[[1L]]) &&
            left.row$cv.rmse.observed[[1L]] <=
            best.cv * (1 + ctl$boundary.guard.rel.tol)
        near.right <- is.finite(right.row$cv.rmse.observed[[1L]]) &&
            right.row$cv.rmse.observed[[1L]] <=
            best.cv * (1 + ctl$boundary.guard.rel.tol)
        boundary <- "none"
        candidate <- NA_real_
        if (raw.best$lambda.sync[[1L]] > 0 &&
            raw.best$lambda.sync[[1L]] == left.lambda) {
            boundary <- "left"
            candidate <- raw.best$lambda.sync[[1L]] / ctl$boundary.factor
        } else if (raw.best$lambda.sync[[1L]] > 0 &&
                   raw.best$lambda.sync[[1L]] == right.lambda) {
            boundary <- "right"
            candidate <- raw.best$lambda.sync[[1L]] * ctl$boundary.factor
        } else if (selected$lambda.sync[[1L]] > 0 &&
                   selected$lambda.sync[[1L]] == left.lambda) {
            boundary <- "left"
            candidate <- selected$lambda.sync[[1L]] / ctl$boundary.factor
        } else if (selected$lambda.sync[[1L]] > 0 &&
                   selected$lambda.sync[[1L]] == right.lambda) {
            boundary <- "right"
            candidate <- selected$lambda.sync[[1L]] * ctl$boundary.factor
        } else if (near.right) {
            boundary <- "right"
            candidate <- right.lambda * ctl$boundary.factor
        } else if (near.left) {
            boundary <- "left"
            candidate <- left.lambda / ctl$boundary.factor
        }
        if (!is.finite(candidate) || boundary == "none" || candidate <= 0 ||
            candidate %in% evaluated$lambda.sync) {
            break
        }
        expansion <- expansion + 1L
        stage.rows <- eval.one(
            candidate,
            stage = paste0("boundary_expand_", boundary),
            boundary = boundary,
            expansion = expansion
        )
        selected <- .ps.lps.select.lambda.table(
            collect.evaluated(),
            rel.tol = ctl$rel.tol
        )
        telemetry <- append.telemetry(stage.rows, selected, telemetry)
    }

    evaluated <- collect.evaluated()
    list(
        evaluated = evaluated,
        selected = selected,
        telemetry = telemetry
    )
}

.ps.lps.prepare.chart.dim <- function(chart.dim, n, p) {
    if (length(chart.dim) == 1L) {
        out <- rep(as.integer(chart.dim), n)
    } else {
        out <- as.integer(chart.dim)
    }
    if (length(out) != n || any(!is.finite(out)) || any(out < 1L) ||
        any(out > p)) {
        stop("'chart.dim' must be a scalar or length-n integer vector in [1, ncol(X)].",
             call. = FALSE)
    }
    out
}

.ps.lps.resolve.chart.dim <- function(
    X, support.size, degree, chart.dim, auto.chart.support.metric,
    auto.chart.selection.metric) {

    if (identical(chart.dim, "auto")) {
        info <- .klp.resolve.chart.dim(
            X = X,
            support.size = support.size,
            degree = degree,
            coordinate.method = "local.pca",
            chart.dim = chart.dim,
            auto.chart.support.metric = auto.chart.support.metric,
            auto.chart.selection.metric = auto.chart.selection.metric
        )
        dim <- as.integer(info$chart.dim)
        return(list(
            chart.dim.by.anchor = rep(dim, nrow(X)),
            chart.dim.mode = "global.auto",
            auto.chart.dim = dim,
            auto.chart.dim.diagnostics = info$diagnostics
        ))
    }
    if (.klp.is.local.auto.chart.dim(chart.dim)) {
        info <- .klp.resolve.chart.dim(
            X = X,
            support.size = support.size,
            degree = degree,
            coordinate.method = "local.pca",
            chart.dim = chart.dim,
            auto.chart.support.metric = auto.chart.support.metric,
            auto.chart.selection.metric = auto.chart.selection.metric
        )
        pred.info <- .klp.resolve.prediction.chart.dim(
            X.train = X,
            X.eval = X,
            support.size = support.size,
            degree = degree,
            coordinate.method = "local.pca",
            chart.dim = chart.dim,
            auto.chart.support.metric = auto.chart.support.metric,
            auto.chart.selection.metric = auto.chart.selection.metric,
            summary.dim = info$chart.dim
        )
        dims <- .ps.lps.prepare.chart.dim(
            chart.dim = pred.info$chart.dim.by.eval,
            n = nrow(X),
            p = ncol(X)
        )
        return(list(
            chart.dim.by.anchor = dims,
            chart.dim.mode = "local.auto",
            auto.chart.dim = as.integer(info$chart.dim),
            auto.chart.dim.diagnostics = info$diagnostics
        ))
    }
    list(
        chart.dim.by.anchor = .ps.lps.prepare.chart.dim(
            chart.dim,
            nrow(X),
            ncol(X)
        ),
        chart.dim.mode = "fixed",
        auto.chart.dim = NA_integer_,
        auto.chart.dim.diagnostics = NULL
    )
}

.ps.lps.prepare.frames <- function(X, y, support.size, degree, kernel,
                                   chart.dim.by.anchor) {
    n <- nrow(X)
    frames <- vector("list", n)
    for (ii in seq_len(n)) {
        d <- chart.dim.by.anchor[[ii]]
        ordered <- .klp.local.order(
            X.train = X,
            center = X[ii, , drop = TRUE],
            support.size = support.size
        )
        idx <- ordered$index
        dist <- ordered$distances
        weights <- .klp.kernel.weights(dist, kernel)
        if (!any(weights > 0)) weights[] <- 1
        coords <- .klp.local.coordinates(
            X.support = X[idx, , drop = FALSE],
            center = X[ii, , drop = TRUE],
            coordinate.method = "local.pca",
            chart.dim = d,
            local.chart.method = "pca",
            weights = weights,
            return.chart = FALSE
        )
        design <- .local.polynomial.design.matrix(coords, degree)
        anchor.design <- .local.polynomial.design.matrix(
            matrix(0, nrow = 1L, ncol = d),
            degree
        )
        row.names <- as.character(idx)
        row.by.point <- seq_along(idx)
        names(row.by.point) <- row.names
        xw <- design * sqrt(weights)
        rank <- qr(xw, LAPACK = TRUE)$rank
        frames[[ii]] <- list(
            anchor = ii,
            index = idx,
            distances = dist,
            weights = weights,
            design = design,
            anchor.design = anchor.design,
            chart.dim = d,
            q = ncol(design),
            rank = as.integer(rank),
            row.by.point = row.by.point
        )
    }
    q <- vapply(frames, `[[`, integer(1L), "q")
    offsets <- cumsum(c(0L, head(q, -1L)))
    for (ii in seq_along(frames)) frames[[ii]]$offset <- offsets[[ii]]
    attr(frames, "ncoef") <- sum(q)
    frames
}

.ps.lps.prepare.sync.rows <- function(frames, sync.neighbor.size,
                                      overlap.weight) {
    n <- length(frames)
    pair.keys <- character(0)
    for (ii in seq_len(n)) {
        nbr <- frames[[ii]]$index[frames[[ii]]$index != ii]
        nbr <- head(nbr, max(0L, as.integer(sync.neighbor.size)))
        if (!length(nbr)) next
        lo <- pmin(ii, nbr)
        hi <- pmax(ii, nbr)
        pair.keys <- c(pair.keys, paste(lo, hi, sep = "_"))
    }
    pair.keys <- unique(pair.keys)
    out <- vector("list", length(pair.keys))
    keep <- logical(length(pair.keys))
    for (pp in seq_along(pair.keys)) {
        pair <- as.integer(strsplit(pair.keys[[pp]], "_", fixed = TRUE)[[1L]])
        ii <- pair[[1L]]
        jj <- pair[[2L]]
        overlap <- intersect(frames[[ii]]$index, frames[[jj]]$index)
        if (!length(overlap)) next
        row.i <- frames[[ii]]$row.by.point[as.character(overlap)]
        row.j <- frames[[jj]]$row.by.point[as.character(overlap)]
        prod <- frames[[ii]]$weights[row.i] * frames[[jj]]$weights[row.j]
        if (identical(overlap.weight, "normalized.product")) {
            omega <- length(overlap) * prod / (sum(prod) + sqrt(.Machine$double.eps))
        } else {
            omega <- prod
        }
        ok <- is.finite(omega) & omega > 0
        if (!any(ok)) next
        out[[pp]] <- list(
            i = ii,
            j = jj,
            point = overlap[ok],
            row.i = as.integer(row.i[ok]),
            row.j = as.integer(row.j[ok]),
            omega = as.numeric(omega[ok])
        )
        keep[[pp]] <- TRUE
    }
    out[keep]
}

.ps.lps.prepare.system.cache <- function(frames, sync.rows) {
    data.blocks <- lapply(frames, function(fr) {
        qseq <- seq_len(fr$q)
        list(
            index = fr$index,
            weights = fr$weights,
            design = fr$design,
            q = fr$q,
            cols = fr$offset + qseq
        )
    })
    sync.blocks <- vector("list", length(sync.rows))
    if (length(sync.rows)) {
        for (ss in seq_along(sync.rows)) {
            sr <- sync.rows[[ss]]
            fi <- frames[[sr$i]]
            fj <- frames[[sr$j]]
            qi <- seq_len(fi$q)
            qj <- seq_len(fj$q)
            sync.blocks[[ss]] <- list(
                i = sr$i,
                j = sr$j,
                point = sr$point,
                omega.sqrt = sqrt(sr$omega),
                cols.i = fi$offset + qi,
                cols.j = fj$offset + qj,
                values.i = fi$design[sr$row.i, qi, drop = FALSE],
                values.j = fj$design[sr$row.j, qj, drop = FALSE],
                q.i = fi$q,
                q.j = fj$q
            )
        }
    }
    structure(
        list(
            frames = frames,
            sync.rows = sync.rows,
            data.blocks = data.blocks,
            sync.blocks = sync.blocks,
            ncoef = attr(frames, "ncoef")
        ),
        class = "ps_lps_system_cache"
    )
}

.ps.lps.prepare.normal.cache <- function(cache, y, response.weights,
                                         lambda.sync) {
    if (!inherits(cache, "ps_lps_system_cache")) {
        stop("'cache' must be a PS-LPS system cache.", call. = FALSE)
    }
    lambda.sync <- as.numeric(lambda.sync[[1L]])
    if (!is.finite(lambda.sync) || lambda.sync <= 0) {
        stop("'lambda.sync' must be positive for a PS-LPS normal cache.",
             call. = FALSE)
    }
    elapsed <- function(start) unname((proc.time() - start)[["elapsed"]])
    t.native <- proc.time()
    assembled <- rcpp_ps_lps_assemble_cached_system(
        cache = cache,
        y = y,
        response_weights = response.weights,
        lambda_sync = lambda.sync
    )
    phase.native.sec <- elapsed(t.native)
    t.sparse <- proc.time()
    A <- Matrix::sparseMatrix(
        i = assembled$rows,
        j = assembled$cols,
        x = assembled$vals,
        dims = c(assembled$nrow, assembled$ncol)
    )
    phase.sparse.sec <- elapsed(t.sparse)
    t.cross <- proc.time()
    cross <- Matrix::crossprod(A)
    phase.cross.sec <- elapsed(t.cross)
    t.rhs <- proc.time()
    rhs.cross <- Matrix::crossprod(A, assembled$rhs)
    phase.rhs.sec <- elapsed(t.rhs)
    scale <- max(Matrix::diag(cross), na.rm = TRUE)
    if (!is.finite(scale) || scale <= 0) scale <- 1
    timings <- list(
        phase_count_sec = NA_real_,
        phase_fill_triplets_sec = phase.native.sec,
        phase_sparse_matrix_sec = phase.sparse.sec,
        phase_assembly_sec = phase.native.sec + phase.sparse.sec,
        phase_crossprod_sec = phase.cross.sec,
        phase_rhs_crossprod_sec = phase.rhs.sec,
        phase_ridge_normal_sec = NA_real_,
        phase_solve_sec = NA_real_,
        phase_fallback_solve_sec = 0,
        phase_diagnostics_sec = NA_real_,
        phase_fitted_sec = NA_real_,
        phase_normal_cache_sec = phase.native.sec + phase.sparse.sec +
            phase.cross.sec + phase.rhs.sec
    )
    structure(
        list(
            frames = cache$frames,
            sync.rows = cache$sync.rows,
            y = y,
            response.weights = response.weights,
            lambda.sync = lambda.sync,
            cross = cross,
            rhs.cross = rhs.cross,
            scale = scale,
            n.system.rows = assembled$nrow,
            n.system.cols = assembled$ncol,
            n.system.nnz = assembled$nnz,
            solve.phase.timings = timings
        ),
        class = "ps_lps_normal_cache"
    )
}

.ps.lps.prepare.component.cache <- function(cache, y, response.weights) {
    if (!inherits(cache, "ps_lps_system_cache")) {
        stop("'cache' must be a PS-LPS system cache.", call. = FALSE)
    }
    y <- as.numeric(y)
    response.weights <- as.numeric(response.weights)
    if (length(y) != length(response.weights) ||
        any(!is.finite(y)) || any(!is.finite(response.weights))) {
        stop("'y' and 'response.weights' must be finite vectors of equal length.",
             call. = FALSE)
    }
    ncoef <- cache$ncoef
    elapsed <- function(start) unname((proc.time() - start)[["elapsed"]])

    t.data.native <- proc.time()
    data.assembled <- rcpp_ps_lps_assemble_cached_system(
        cache = cache,
        y = y,
        response_weights = response.weights,
        lambda_sync = 0
    )
    phase.data.native.sec <- elapsed(t.data.native)
    t.data.sparse <- proc.time()
    A.data <- Matrix::sparseMatrix(
        i = data.assembled$rows,
        j = data.assembled$cols,
        x = data.assembled$vals,
        dims = c(data.assembled$nrow, data.assembled$ncol)
    )
    phase.data.sparse.sec <- elapsed(t.data.sparse)
    t.data.cross <- proc.time()
    cross.data <- Matrix::crossprod(A.data)
    phase.data.cross.sec <- elapsed(t.data.cross)
    t.data.rhs <- proc.time()
    rhs.data <- Matrix::crossprod(A.data, data.assembled$rhs)
    phase.data.rhs.sec <- elapsed(t.data.rhs)

    sync.nrow <- 0L
    sync.nnz <- 0L
    cross.sync <- Matrix::sparseMatrix(
        i = integer(),
        j = integer(),
        x = numeric(),
        dims = c(ncoef, ncoef)
    )
    phase.sync.native.sec <- 0
    phase.sync.sparse.sec <- 0
    phase.sync.cross.sec <- 0
    if (length(cache$sync.blocks)) {
        t.sync.native <- proc.time()
        sync.assembled <- rcpp_ps_lps_assemble_cached_system(
            cache = cache,
            y = y,
            response_weights = rep(0, length(y)),
            lambda_sync = 1
        )
        phase.sync.native.sec <- elapsed(t.sync.native)
        sync.nrow <- sync.assembled$sync_nrow
        sync.nnz <- sync.assembled$nnz
        t.sync.sparse <- proc.time()
        A.sync <- Matrix::sparseMatrix(
            i = sync.assembled$rows,
            j = sync.assembled$cols,
            x = sync.assembled$vals,
            dims = c(sync.assembled$nrow, sync.assembled$ncol)
        )
        phase.sync.sparse.sec <- elapsed(t.sync.sparse)
        t.sync.cross <- proc.time()
        cross.sync <- Matrix::crossprod(A.sync)
        phase.sync.cross.sec <- elapsed(t.sync.cross)
    }

    timings <- list(
        phase_data_native_sec = phase.data.native.sec,
        phase_data_sparse_matrix_sec = phase.data.sparse.sec,
        phase_data_crossprod_sec = phase.data.cross.sec,
        phase_data_rhs_crossprod_sec = phase.data.rhs.sec,
        phase_sync_native_sec = phase.sync.native.sec,
        phase_sync_sparse_matrix_sec = phase.sync.sparse.sec,
        phase_sync_crossprod_sec = phase.sync.cross.sec,
        phase_component_cache_sec = phase.data.native.sec +
            phase.data.sparse.sec + phase.data.cross.sec +
            phase.data.rhs.sec + phase.sync.native.sec +
            phase.sync.sparse.sec + phase.sync.cross.sec
    )

    structure(
        list(
            frames = cache$frames,
            sync.rows = cache$sync.rows,
            y = y,
            response.weights = response.weights,
            cross.data = cross.data,
            cross.sync = cross.sync,
            rhs.data = rhs.data,
            n.system.cols = ncoef,
            data.nrow = data.assembled$data_nrow,
            data.nnz = data.assembled$nnz,
            sync.nrow = sync.nrow,
            sync.nnz = sync.nnz,
            solve.phase.timings = timings
        ),
        class = "ps_lps_component_cache"
    )
}

.ps.lps.component.normal.cache <- function(component.cache, lambda.sync) {
    if (!inherits(component.cache, "ps_lps_component_cache")) {
        stop("'component.cache' must be a PS-LPS component cache.",
             call. = FALSE)
    }
    lambda.sync <- as.numeric(lambda.sync[[1L]])
    if (!is.finite(lambda.sync) || lambda.sync <= 0) {
        stop("'lambda.sync' must be positive for a PS-LPS component normal cache.",
             call. = FALSE)
    }
    elapsed <- function(start) unname((proc.time() - start)[["elapsed"]])
    t.combine <- proc.time()
    cross <- component.cache$cross.data +
        lambda.sync * component.cache$cross.sync
    scale <- max(Matrix::diag(cross), na.rm = TRUE)
    if (!is.finite(scale) || scale <= 0) scale <- 1
    phase.combine.sec <- elapsed(t.combine)
    timings <- c(
        component.cache$solve.phase.timings,
        list(
            phase_component_combine_sec = phase.combine.sec,
            phase_count_sec = NA_real_,
            phase_fill_triplets_sec = NA_real_,
            phase_sparse_matrix_sec = NA_real_,
            phase_assembly_sec = NA_real_,
            phase_crossprod_sec = NA_real_,
            phase_rhs_crossprod_sec = NA_real_,
            phase_ridge_normal_sec = NA_real_,
            phase_solve_sec = NA_real_,
            phase_fallback_solve_sec = 0,
            phase_diagnostics_sec = NA_real_,
            phase_fitted_sec = NA_real_,
            phase_normal_cache_sec = phase.combine.sec
        )
    )
    structure(
        list(
            frames = component.cache$frames,
            sync.rows = component.cache$sync.rows,
            y = component.cache$y,
            response.weights = component.cache$response.weights,
            lambda.sync = lambda.sync,
            cross = cross,
            rhs.cross = component.cache$rhs.data,
            scale = scale,
            n.system.rows = component.cache$data.nrow + component.cache$sync.nrow,
            n.system.cols = component.cache$n.system.cols,
            n.system.nnz = component.cache$data.nnz + component.cache$sync.nnz,
            solve.phase.timings = timings
        ),
        class = "ps_lps_normal_cache"
    )
}

.ps.lps.solve.component.cached <- function(component.cache, lambda.sync,
                                          lambda.ridge = 1e-8,
                                          coefficients.only = FALSE) {
    normal.cache <- .ps.lps.component.normal.cache(
        component.cache = component.cache,
        lambda.sync = lambda.sync
    )
    .ps.lps.solve.normal.cached(
        normal.cache = normal.cache,
        lambda.ridge = lambda.ridge,
        coefficients.only = coefficients.only
    )
}

.ps.lps.solve.cached <- function(cache, y, response.weights, lambda.sync,
                                 lambda.ridge = 1e-8,
                                 coefficients.only = FALSE) {
    if (!inherits(cache, "ps_lps_system_cache")) {
        stop("'cache' must be a PS-LPS system cache.", call. = FALSE)
    }
    frames <- cache$frames
    sync.rows <- cache$sync.rows
    n <- length(frames)
    elapsed <- function(start) unname((proc.time() - start)[["elapsed"]])
    if (lambda.sync == 0) {
        solve.start <- proc.time()
        independent <- .ps.lps.solve.independent(
            frames = frames,
            y = y,
            response.weights = response.weights,
            lambda.ridge = lambda.ridge
        )
        diagnostics <- .ps.lps.diagnostics(
            frames = frames,
            y = y,
            beta = independent$coefficients,
            sync.rows = sync.rows,
            ridge.values = independent$ridge.values
        )
        timings <- list(
            phase_count_sec = NA_real_,
            phase_fill_triplets_sec = NA_real_,
            phase_sparse_matrix_sec = NA_real_,
            phase_assembly_sec = NA_real_,
            phase_crossprod_sec = NA_real_,
            phase_rhs_crossprod_sec = NA_real_,
            phase_ridge_normal_sec = NA_real_,
            phase_solve_sec = elapsed(solve.start),
            phase_fallback_solve_sec = 0,
            phase_diagnostics_sec = NA_real_,
            phase_fitted_sec = NA_real_
        )
        diagnostics <- c(diagnostics, list(solve.phase.timings = timings))
        if (coefficients.only) return(diagnostics)
        return(c(independent, diagnostics))
    }
    normal.cache <- .ps.lps.prepare.normal.cache(
        cache = cache,
        y = y,
        response.weights = response.weights,
        lambda.sync = lambda.sync
    )
    .ps.lps.solve.normal.cached(
        normal.cache = normal.cache,
        lambda.ridge = lambda.ridge,
        coefficients.only = coefficients.only
    )
}

.ps.lps.solve.normal.cached <- function(normal.cache, lambda.ridge = 1e-8,
                                        coefficients.only = FALSE) {
    if (!inherits(normal.cache, "ps_lps_normal_cache")) {
        stop("'normal.cache' must be a PS-LPS normal cache.", call. = FALSE)
    }
    elapsed <- function(start) unname((proc.time() - start)[["elapsed"]])
    frames <- normal.cache$frames
    sync.rows <- normal.cache$sync.rows
    y <- normal.cache$y
    cross <- normal.cache$cross
    rhs.cross <- normal.cache$rhs.cross
    ncoef <- normal.cache$n.system.cols
    n <- length(frames)
    t.ridge <- proc.time()
    scale <- normal.cache$scale
    ridge <- lambda.ridge * scale
    normal <- cross + Matrix::Diagonal(ncoef, x = ridge)
    phase.ridge.sec <- elapsed(t.ridge)
    t.solve <- proc.time()
    fallback.sec <- 0
    beta <- tryCatch(
        as.numeric(Matrix::solve(normal, rhs.cross)),
        error = function(e) rep(NA_real_, ncoef)
    )
    phase.solve.sec <- elapsed(t.solve)
    if (any(!is.finite(beta))) {
        t.fallback <- proc.time()
        ridge <- sqrt(.Machine$double.eps) * scale
        normal <- cross + Matrix::Diagonal(ncoef, x = ridge)
        beta <- as.numeric(Matrix::solve(normal, rhs.cross))
        fallback.sec <- elapsed(t.fallback)
    }
    t.diagnostics <- proc.time()
    diagnostics <- .ps.lps.diagnostics(
        frames = frames,
        y = y,
        beta = beta,
        sync.rows = sync.rows,
        ridge.values = ridge
    )
    phase.diagnostics.sec <- elapsed(t.diagnostics)
    timings <- normal.cache$solve.phase.timings
    timings$phase_ridge_normal_sec <- phase.ridge.sec
    timings$phase_solve_sec <- phase.solve.sec
    timings$phase_fallback_solve_sec <- fallback.sec
    timings$phase_diagnostics_sec <- phase.diagnostics.sec
    timings$phase_fitted_sec <- NA_real_
    diagnostics <- c(diagnostics, list(solve.phase.timings = timings))
    if (coefficients.only) return(diagnostics)
    t.fitted <- proc.time()
    fitted <- vapply(seq_len(n), function(ii) {
        fr <- frames[[ii]]
        idx <- fr$offset + seq_len(fr$q)
        sum(fr$anchor.design[1L, ] * beta[idx])
    }, numeric(1L))
    diagnostics$solve.phase.timings$phase_fitted_sec <- elapsed(t.fitted)
    c(
        list(
            coefficients = beta,
            fitted.values = fitted,
            n.system.rows = normal.cache$n.system.rows,
            n.system.cols = ncoef,
            lambda.ridge = lambda.ridge
        ),
        diagnostics
    )
}

.ps.lps.solve <- function(frames, y, response.weights, lambda.sync, sync.rows,
                          lambda.ridge = 1e-8,
                          coefficients.only = FALSE) {
    elapsed <- function(start) unname((proc.time() - start)[["elapsed"]])
    if (lambda.sync == 0) {
        solve.start <- proc.time()
        independent <- .ps.lps.solve.independent(
            frames = frames,
            y = y,
            response.weights = response.weights,
            lambda.ridge = lambda.ridge
        )
        diagnostics <- .ps.lps.diagnostics(
            frames = frames,
            y = y,
            beta = independent$coefficients,
            sync.rows = sync.rows,
            ridge.values = independent$ridge.values
        )
        timings <- list(
            phase_count_sec = NA_real_,
            phase_fill_triplets_sec = NA_real_,
            phase_sparse_matrix_sec = NA_real_,
            phase_assembly_sec = NA_real_,
            phase_crossprod_sec = NA_real_,
            phase_rhs_crossprod_sec = NA_real_,
            phase_ridge_normal_sec = NA_real_,
            phase_solve_sec = elapsed(solve.start),
            phase_fallback_solve_sec = 0,
            phase_diagnostics_sec = NA_real_,
            phase_fitted_sec = NA_real_
        )
        diagnostics <- c(diagnostics, list(solve.phase.timings = timings))
        if (coefficients.only) return(diagnostics)
        return(c(independent, diagnostics))
    }
    n <- length(frames)
    ncoef <- attr(frames, "ncoef")
    t.count <- proc.time()
    data.nrows <- 0L
    data.nnz <- 0L
    for (ii in seq_len(n)) {
        fr <- frames[[ii]]
        rw <- response.weights[fr$index]
        ww <- rw * fr$weights
        ok <- is.finite(rw) & is.finite(ww) & ww > 0
        if (any(ok)) {
            n.ok <- sum(ok)
            data.nrows <- data.nrows + n.ok
            data.nnz <- data.nnz + n.ok * fr$q
        }
    }
    sync.nrows <- 0L
    sync.nnz <- 0L
    if (lambda.sync > 0 && length(sync.rows)) {
        for (sr in sync.rows) {
            n.sr <- length(sr$point)
            if (!n.sr) next
            fi <- frames[[sr$i]]
            fj <- frames[[sr$j]]
            sync.nrows <- sync.nrows + n.sr
            sync.nnz <- sync.nnz + n.sr * (fi$q + fj$q)
        }
    }
    phase.count.sec <- elapsed(t.count)
    rr <- data.nrows + sync.nrows
    nnz <- data.nnz + sync.nnz
    if (!rr || !nnz) stop("PS-LPS system has no rows.", call. = FALSE)
    t.fill <- proc.time()
    rows <- integer(nnz)
    cols <- integer(nnz)
    vals <- numeric(nnz)
    rhs <- numeric(rr)
    row.pos <- 0L
    nz.pos <- 0L
    for (ii in seq_len(n)) {
        fr <- frames[[ii]]
        qseq <- seq_len(fr$q)
        rw <- response.weights[fr$index]
        ww <- rw * fr$weights
        ok <- is.finite(rw) & is.finite(ww) & ww > 0
        if (!any(ok)) next
        for (aa in which(ok)) {
            point <- fr$index[[aa]]
            sw <- sqrt(ww[[aa]])
            row.pos <- row.pos + 1L
            next.nz <- nz.pos + fr$q
            idx <- seq.int(nz.pos + 1L, next.nz)
            rows[idx] <- row.pos
            cols[idx] <- fr$offset + qseq
            vals[idx] <- sw * fr$design[aa, qseq]
            rhs[[row.pos]] <- sw * y[[point]]
            nz.pos <- next.nz
        }
    }
    if (lambda.sync > 0 && length(sync.rows)) {
        for (sr in sync.rows) {
            n.sr <- length(sr$point)
            if (!n.sr) next
            fi <- frames[[sr$i]]
            fj <- frames[[sr$j]]
            qi <- seq_len(fi$q)
            qj <- seq_len(fj$q)
            scale <- sqrt(lambda.sync * sr$omega)
            for (aa in seq_len(n.sr)) {
                row.pos <- row.pos + 1L
                len.i <- fi$q
                len.j <- fj$q
                next.nz.i <- nz.pos + len.i
                idx.i <- seq.int(nz.pos + 1L, next.nz.i)
                rows[idx.i] <- row.pos
                cols[idx.i] <- fi$offset + qi
                vals[idx.i] <- scale[[aa]] * fi$design[sr$row.i[[aa]], qi]
                next.nz.j <- next.nz.i + len.j
                idx.j <- seq.int(next.nz.i + 1L, next.nz.j)
                rows[idx.j] <- row.pos
                cols[idx.j] <- fj$offset + qj
                vals[idx.j] <- -scale[[aa]] * fj$design[sr$row.j[[aa]], qj]
                nz.pos <- next.nz.j
            }
        }
    }
    if (row.pos != rr || nz.pos != nnz) {
        stop("Internal PS-LPS sparse assembly count mismatch.", call. = FALSE)
    }
    phase.fill.sec <- elapsed(t.fill)
    t.sparse <- proc.time()
    A <- Matrix::sparseMatrix(
        i = rows,
        j = cols,
        x = vals,
        dims = c(rr, ncoef)
    )
    phase.sparse.sec <- elapsed(t.sparse)
    t.cross <- proc.time()
    cross <- Matrix::crossprod(A)
    phase.cross.sec <- elapsed(t.cross)
    t.ridge <- proc.time()
    scale <- max(Matrix::diag(cross), na.rm = TRUE)
    if (!is.finite(scale) || scale <= 0) scale <- 1
    ridge <- lambda.ridge * scale
    normal <- cross + Matrix::Diagonal(ncoef, x = ridge)
    phase.ridge.sec <- elapsed(t.ridge)
    t.rhs <- proc.time()
    rhs.cross <- Matrix::crossprod(A, rhs)
    phase.rhs.sec <- elapsed(t.rhs)
    t.solve <- proc.time()
    fallback.sec <- 0
    beta <- tryCatch(
        as.numeric(Matrix::solve(normal, rhs.cross)),
        error = function(e) rep(NA_real_, ncoef)
    )
    phase.solve.sec <- elapsed(t.solve)
    if (any(!is.finite(beta))) {
        t.fallback <- proc.time()
        ridge <- sqrt(.Machine$double.eps) * scale
        normal <- cross + Matrix::Diagonal(ncoef, x = ridge)
        beta <- as.numeric(Matrix::solve(normal, rhs.cross))
        fallback.sec <- elapsed(t.fallback)
    }
    t.diagnostics <- proc.time()
    diagnostics <- .ps.lps.diagnostics(
        frames = frames,
        y = y,
        beta = beta,
        sync.rows = sync.rows,
        ridge.values = ridge
    )
    phase.diagnostics.sec <- elapsed(t.diagnostics)
    timings <- list(
        phase_count_sec = phase.count.sec,
        phase_fill_triplets_sec = phase.fill.sec,
        phase_sparse_matrix_sec = phase.sparse.sec,
        phase_assembly_sec = phase.count.sec + phase.fill.sec + phase.sparse.sec,
        phase_crossprod_sec = phase.cross.sec,
        phase_rhs_crossprod_sec = phase.rhs.sec,
        phase_ridge_normal_sec = phase.ridge.sec,
        phase_solve_sec = phase.solve.sec,
        phase_fallback_solve_sec = fallback.sec,
        phase_diagnostics_sec = phase.diagnostics.sec,
        phase_fitted_sec = NA_real_
    )
    diagnostics <- c(diagnostics, list(solve.phase.timings = timings))
    if (coefficients.only) return(diagnostics)
    t.fitted <- proc.time()
    fitted <- vapply(seq_len(n), function(ii) {
        fr <- frames[[ii]]
        idx <- fr$offset + seq_len(fr$q)
        sum(fr$anchor.design[1L, ] * beta[idx])
    }, numeric(1L))
    diagnostics$solve.phase.timings$phase_fitted_sec <- elapsed(t.fitted)
    c(
        list(
            coefficients = beta,
            fitted.values = fitted,
            n.system.rows = rr,
            n.system.cols = ncoef,
            lambda.ridge = lambda.ridge
        ),
        diagnostics
    )
}

.ps.lps.solve.independent <- function(frames, y, response.weights,
                                      lambda.ridge = 0) {
    n <- length(frames)
    ncoef <- attr(frames, "ncoef")
    beta <- rep(0, ncoef)
    ridge.values <- numeric(n)
    for (ii in seq_len(n)) {
        fr <- frames[[ii]]
        qseq <- seq_len(fr$q)
        w <- fr$weights * response.weights[fr$index]
        ok <- is.finite(y[fr$index]) & is.finite(w) & w > 0
        if (!any(ok)) {
            beta[fr$offset + qseq] <- 0
            ridge.values[[ii]] <- 0
            next
        }
        design <- fr$design[ok, , drop = FALSE]
        yy <- y[fr$index][ok]
        ww <- w[ok]
        if (lambda.ridge == 0) {
            fit <- tryCatch(
                stats::lm.wfit(design, yy, ww),
                error = function(e) NULL
            )
            coef <- if (is.null(fit) || !length(fit$coefficients)) {
                c(stats::weighted.mean(yy, ww), rep(0, fr$q - 1L))
            } else {
                fit$coefficients
            }
            coef[!is.finite(coef)] <- 0
            beta[fr$offset + qseq] <- coef
            ridge.values[[ii]] <- 0
        } else {
            xw <- design * sqrt(ww)
            yw <- yy * sqrt(ww)
            cross <- crossprod(xw)
            scale <- max(diag(cross), na.rm = TRUE)
            if (!is.finite(scale) || scale <= 0) scale <- 1
            ridge <- lambda.ridge * scale
            coef <- tryCatch(
                as.numeric(solve(cross + diag(ridge, fr$q), crossprod(xw, yw))),
                error = function(e) rep(NA_real_, fr$q)
            )
            if (any(!is.finite(coef))) {
                coef <- c(stats::weighted.mean(yy, ww), rep(0, fr$q - 1L))
            }
            beta[fr$offset + qseq] <- coef
            ridge.values[[ii]] <- ridge
        }
    }
    fitted <- vapply(seq_len(n), function(ii) {
        fr <- frames[[ii]]
        idx <- fr$offset + seq_len(fr$q)
        sum(fr$anchor.design[1L, ] * beta[idx])
    }, numeric(1L))
    list(
        coefficients = beta,
        fitted.values = fitted,
        n.system.rows = sum(vapply(frames, function(fr) length(fr$index),
                                   integer(1L))),
        n.system.cols = ncoef,
        lambda.ridge = lambda.ridge,
        ridge.values = ridge.values
    )
}

.ps.lps.diagnostics <- function(frames, y, beta, sync.rows,
                                ridge.values = numeric(0)) {
    n <- length(frames)
    local.gcv <- numeric(n)
    local.rss <- numeric(n)
    df.ratio <- numeric(n)
    for (ii in seq_len(n)) {
        fr <- frames[[ii]]
        idx <- fr$offset + seq_len(fr$q)
        pred <- as.numeric(fr$design %*% beta[idx])
        resid <- y[fr$index] - pred
        rss <- sum(fr$weights * resid^2)
        denom <- 1 - fr$rank / length(fr$index)
        local.rss[[ii]] <- rss
        df.ratio[[ii]] <- fr$rank / length(fr$index)
        local.gcv[[ii]] <- if (denom > 0) {
            (rss / length(fr$index)) / denom^2
        } else {
            Inf
        }
    }
    sync.energy <- 0
    sync.weight <- 0
    if (length(sync.rows)) {
        for (sr in sync.rows) {
            fi <- frames[[sr$i]]
            fj <- frames[[sr$j]]
            bi <- beta[fi$offset + seq_len(fi$q)]
            bj <- beta[fj$offset + seq_len(fj$q)]
            pred.i <- as.numeric(fi$design[sr$row.i, , drop = FALSE] %*% bi)
            pred.j <- as.numeric(fj$design[sr$row.j, , drop = FALSE] %*% bj)
            diff <- pred.i - pred.j
            sync.energy <- sync.energy + 0.5 * sum(sr$omega * diff^2)
            sync.weight <- sync.weight + sum(sr$omega)
        }
    }
    list(
        total.local.gcv.ps = sum(local.gcv[is.finite(local.gcv)]),
        mean.local.gcv.ps = mean(local.gcv[is.finite(local.gcv)]),
        local.gcv.ps = local.gcv,
        local.rss.ps = local.rss,
        local.df.ratio = df.ratio,
        sync.energy = sync.energy,
        mean.sync.squared.disagreement = if (sync.weight > 0) {
            2 * sync.energy / sync.weight
        } else {
            0
        },
        mean.sync.disagreement = if (sync.weight > 0) {
            2 * sync.energy / sync.weight
        } else {
            0
        },
        ridge.min = if (length(ridge.values)) min(ridge.values) else 0,
        ridge.median = if (length(ridge.values)) stats::median(ridge.values) else 0,
        ridge.max = if (length(ridge.values)) max(ridge.values) else 0
    )
}
