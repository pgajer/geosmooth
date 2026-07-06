.local.chart.cv.requested <- function(foldid,
                                      support.grid = NULL,
                                      degree.grid = NULL,
                                      kernel.grid = NULL,
                                      bandwidth.multiplier.grid = NULL,
                                      lambda.ridge.grid = NULL) {
    !is.null(foldid) ||
        !is.null(support.grid) ||
        !is.null(degree.grid) ||
        !is.null(kernel.grid) ||
        !is.null(bandwidth.multiplier.grid) ||
        !is.null(lambda.ridge.grid)
}

.local.likelihood.clean.lambda.ridge.grid <- function(lambda.ridge.grid) {
    out <- sort(unique(as.numeric(lambda.ridge.grid)))
    out <- out[is.finite(out) & out >= 0]
    if (!length(out)) {
        stop("'lambda.ridge.grid' must contain at least one finite ",
             "nonnegative value.", call. = FALSE)
    }
    out
}

.local.chart.select.best.idx <- function(cv.table,
                                         score.column = "cv.rmse.observed",
                                         tolerance = 1e-12) {
    if (!score.column %in% names(cv.table)) {
        stop("CV table does not contain selection score column '",
             score.column, "'.", call. = FALSE)
    }
    score <- cv.table[[score.column]]
    finite <- is.finite(score)
    if (!any(finite)) {
        stop("No candidate has a finite selection score in '",
             score.column, "'.", call. = FALSE)
    }
    best <- min(score[finite])
    eligible <- which(
        finite &
            score <= best + max(tolerance, tolerance * abs(best))
    )
    column.or.default <- function(name, default) {
        if (name %in% names(cv.table)) cv.table[[name]][eligible] else default
    }
    eligible[order(
        column.or.default("support.size", rep(0, length(eligible))),
        column.or.default("degree", rep(0, length(eligible))),
        column.or.default("kernel", rep("", length(eligible))),
        column.or.default("bandwidth.multiplier", rep(1, length(eligible))),
        column.or.default("lambda.ridge", rep(0, length(eligible))),
        score[eligible]
    )[[1L]]]
}
