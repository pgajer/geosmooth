#' Test Constancy and Assess Logistic Trend-Filtering Prediction
#'
#' Assess whether an order-2 logistic trend filter detects a nonconstant binary
#' probability, and separately estimate predictive improvement over a constant.
#' This is an additional assessment, not an option that changes the fitted
#' objective or supplies confidence bands.
#'
#' @param object A `logistic.trend.filtering.fit` with independent binary
#'   observations, unit weights, no covariates and no offset. Predictor choice,
#'   penalty path, ridge penalties and solver settings must have been specified
#'   independently of the outcomes. Backend and explicit penalties are reused.
#' @param permutations Number of random outcome permutations, at least one.
#'   The default 999 gives a minimum possible p-value of 0.001. Small values in
#'   examples illustrate usage only.
#' @param inner.folds Number of balanced, outcome-independent tuning folds.
#'   Used for the global test and within each outer training set.
#' @param outer.folds Number of outer folds for predictive assessment.
#' @param seed Nonnegative integer random seed. The caller's RNG state is
#'   restored. Realized folds, permutation seeds and RNG kind are returned.
#' @param predictive Whether to run nested CV in addition to the global test.
#' @param warn Warn if the observed fit, any permutation, or an outer fit fails.
#'
#' @details The null is a common unknown Bernoulli probability at all observed
#'   predictor locations. The constant estimate is the sample event rate, not
#'   a uniformly weighted integral over the continuous predictor domain.
#'   Independent observations must be exchangeable under this null. Repeated
#'   participants, serial dependence, confounding adjustment and grouped
#'   binomial counts require other null procedures and are not supported here.
#'   Independence cannot be established from a fitted object.
#'
#'   The input object's selected penalty and fold labels are not reused: those
#'   labels may depend on outcomes. A new outcome-independent fold assignment
#'   selects a penalty from the supplied path, including a full-data refit.
#'   Every permutation repeats this complete selection procedure on the same
#'   folds with the same solver settings. The statistic is the nonnegative
#'   part of twice the ordinary binomial log-likelihood improvement over the
#'   constant. It is not a penalized-objective difference and is not compared
#'   with a chi-squared distribution. Lambda order determines selection ties.
#'   Changing the path after inspecting the assessment invalidates the stated
#'   test unless that additional selection is included in the randomization.
#'
#'   Outcomes are shuffled uniformly with the predictor fixed, preserving the
#'   total event count. With B successful permutations the Monte Carlo p-value
#'   is `(1 + sum(permuted.statistic >= observed.statistic))/(B + 1)`.
#'   Under exchangeability this is a valid conditional randomization test,
#'   subject to Monte Carlo discreteness. For numerical ties, comparisons allow
#'   a conservative tolerance of `1e-10 * max(1, abs(observed.statistic))`.
#'   A failed candidate is ineligible under the fitter's usual CV rule. If no
#'   candidate is eligible, that replicate fails. Failed replicates are never
#'   dropped or retried: the point p-value is NA and `p.value.bounds` gives the
#'   smallest/largest possible Monte Carlo p-value counting each missing
#'   statistic as a nonexceedance/exceedance. These bounds are not a confidence
#'   interval. An observed-fit failure leaves both bounds unavailable.
#'
#'   Predictive assessment uses separate outer folds. Each outer training set
#'   tunes the path using only its inner folds and predicts its outer test set.
#'   The constant predictor is that outer training set's event rate. Both use
#'   identical test observations. Pooled mean natural-log loss and Brier score
#'   are reported; improvements are constant loss minus trend-filtering loss,
#'   so positive values favor the smoother. These assess training on the outer
#'   training-set size, not the full sample. No standard error is computed from
#'   overlapping CV folds. Incomplete smoother predictions leave its overall
#'   scores and improvements unavailable rather than scoring a selected subset.
#'
#'   Computation is sequential. A complete run uses approximately
#'   `(permutations + 1) * (inner.folds + 1)` native path fits for the test,
#'   plus `outer.folds * (inner.folds + 1)` for prediction. Per-replicate
#'   diagnostics are retained, but full permuted fitted objects are not.
#'   Rejecting constancy is evidence of association, not necessarily
#'   nonlinearity, predictive usefulness or a causal effect.
#'
#' @return A `logistic.trend.filtering.assessment` list containing `statistic`,
#'   `p.value`, `p.value.bounds`, `status`, `null.probability`, the newly tuned
#'   observed `fit`, permutation statistics and diagnostic records, optional
#'   nested-CV `prediction`, realized `folds`, seeds and solver settings.
#'   `prediction$scores` contains model losses; `prediction$improvement`
#'   contains baseline-minus-smoother gains; `prediction$predictions` and
#'   `prediction$diagnostics` retain row-level and fold-level evidence.
#' @references
#' Ojala and Garriga (2010). Permutation Tests for Studying Classifier Performance.
#' \url{https://www.jmlr.org/papers/v11/ojala10a.html}
#'
#' Phipson and Smyth (2010). Permutation p-values should never be zero.
#' \doi{10.2202/1544-6115.1585}
#' @seealso \code{\link{fit.logistic.trend.filtering}}
#' @examples
#' x <- seq(0, 1, length.out = 60)
#' y <- rep(c(0, 1, 0, 1, 1), 12)
#' fit <- fit.logistic.trend.filtering(x, y, lambda = c(Inf, 0.01),
#'     backend = "banded", curve.ridge = 0.1)
#' # Only nine permutations for a quick illustration; use more for inference.
#' assessment <- assess.logistic.trend.filtering(fit, permutations = 9,
#'     inner.folds = 3, outer.folds = 3, seed = 42)
#' print(assessment)
#' assessment$prediction$improvement
#' @export
assess.logistic.trend.filtering <- function(object, permutations = 999L,
    inner.folds = 5L, outer.folds = 5L, seed = 1L, predictive = TRUE, warn = TRUE) {
    call <- match.call()
    if (!inherits(object, "logistic.trend.filtering.fit"))
        stop("object must be a logistic.trend.filtering.fit.", call. = FALSE)
    if (any(!object$y %in% c(0, 1)) || any(object$weights != 1) ||
        ncol(object$covariates) != 0L || isTRUE(object$offset.used) || any(object$offset != 0))
        stop("Assessment requires independent binary observations with unit weights, no covariates and no offset.",
             call. = FALSE)
    integer.scalar <- function(value, name, minimum) {
        if (!is.numeric(value) || length(value) != 1L || !is.finite(value) ||
            value != floor(value) || value < minimum || value >= .Machine$integer.max)
            stop(name, " must be an integer >= ", minimum, " and < .Machine$integer.max.", call. = FALSE)
        as.integer(value)
    }
    permutations <- integer.scalar(permutations, "permutations", 1L)
    inner.folds <- integer.scalar(inner.folds, "inner.folds", 2L)
    outer.folds <- integer.scalar(outer.folds, "outer.folds", 2L)
    seed <- integer.scalar(seed, "seed", 0L)
    for (name in c("predictive", "warn")) {
        value <- get(name)
        if (!is.logical(value) || length(value) != 1L || is.na(value))
            stop(name, " must be TRUE or FALSE.", call. = FALSE)
    }
    n <- length(object$y)
    if (inner.folds > n || (predictive && outer.folds > n))
        stop("Fold counts must not exceed the number of observations.", call. = FALSE)
    existed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (existed) previous <- get(".Random.seed", envir = .GlobalEnv)
    on.exit(if (existed) assign(".Random.seed", previous, envir = .GlobalEnv) else
        if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
            rm(".Random.seed", envir = .GlobalEnv))
    set.seed(seed)
    streams <- sample.int(.Machine$integer.max, 3L)
    set.seed(streams[1L])
    tuning <- .logistic.tf.assessment.folds(object$x, inner.folds)
    outer <- inner <- NULL
    if (predictive) {
        set.seed(streams[2L])
        outer <- .logistic.tf.assessment.folds(object$x, outer.folds)
        inner <- lapply(seq_len(outer.folds), function(k) {
            rows <- which(outer != k)
            labels <- .logistic.tf.assessment.folds(object$x[rows], inner.folds)
            stats::setNames(labels, rows)
        })
    }
    set.seed(streams[3L])
    permutation.seeds <- sample.int(.Machine$integer.max, permutations, replace = TRUE)
    observed <- .logistic.tf.assessment.refit(object, object$y, seq_len(n), tuning)
    reference <- observed$record$statistic
    records <- vector("list", permutations)
    for (b in seq_len(permutations)) {
        set.seed(permutation.seeds[b])
        shuffled <- object$y[sample.int(n)]
        result <- .logistic.tf.assessment.refit(object, shuffled, seq_len(n), tuning)
        records[[b]] <- result$record
    }
    statistics <- vapply(records, `[[`, numeric(1), "statistic")
    valid <- is.finite(statistics)
    tolerance <- if (is.finite(reference)) 1e-10 * max(1, abs(reference)) else NA_real_
    exceedances <- if (is.finite(reference)) sum(statistics[valid] >= reference - tolerance) else NA_integer_
    missing <- sum(!valid)
    bounds <- if (is.finite(reference))
        c(lower = (1 + exceedances)/(permutations + 1),
          upper = (1 + exceedances + missing)/(permutations + 1)) else c(lower = NA_real_, upper = NA_real_)
    status <- if (!is.finite(reference)) "observed_fit_failed" else
        if (missing) "incomplete_permutations" else "complete"
    prediction <- if (predictive)
        .logistic.tf.assessment.prediction(object, outer, inner) else NULL
    if (warn && (status != "complete" || (predictive && prediction$status != "complete")))
        warning("Assessment has failed fits; inspect status, permutation diagnostics and prediction diagnostics. No failed replicate is discarded.",
                call. = FALSE)
    out <- list(call = call, statistic = reference,
        p.value = if (status == "complete") unname(bounds["upper"]) else NA_real_,
        p.value.bounds = bounds, status = status, null.probability = mean(object$y),
        fit = observed$fit, observed = observed$record,
        permutations = data.frame(replicate = seq_len(permutations), statistic = statistics,
            selected.lambda = vapply(records, `[[`, numeric(1), "selected.lambda"),
            eligible.candidates = vapply(records, `[[`, integer(1), "eligible.candidates"),
            status = vapply(records, `[[`, character(1), "status")),
        permutation.diagnostics = records,
        permutation.summary = list(requested = permutations, completed = sum(valid),
            failed = missing, exceedances = exceedances, resolution = 1/(permutations + 1),
            comparison.tolerance = tolerance),
        prediction = prediction, folds = list(tuning = tuning, outer = outer, inner = inner),
        seeds = list(seed = seed, streams = streams, permutations = permutation.seeds,
                     rng.kind = RNGkind()),
        settings = list(lambda = object$lambda, backend = object$backend,
            control = object$control, nuisance.ridge = object$nuisance.ridge,
            curve.ridge = object$curve.ridge, inner.folds = inner.folds,
            outer.folds = if (predictive) outer.folds else NULL,
            null = "Independent Bernoulli observations with a common probability"))
    class(out) <- "logistic.trend.filtering.assessment"
    out
}

.logistic.tf.assessment.folds <- function(x, k) {
    if (k > length(x)) stop("Too many inner folds for an outer training set.", call. = FALSE)
    labels <- sample(rep(seq_len(k), length.out = length(x)))
    if (any(vapply(seq_len(k), function(j) length(unique(x[labels != j])) < 4L, logical(1))))
        stop("Each training split needs at least four distinct predictor locations; change fold counts or use more data.",
             call. = FALSE)
    labels
}

.logistic.tf.binary.loss <- function(y, eta) {
    ifelse(y == 1, pmax(-eta, 0), pmax(eta, 0)) + log1p(exp(-abs(eta)))
}

.logistic.tf.assessment.refit <- function(object, y, rows, folds) {
    fit <- tryCatch(fit.logistic.trend.filtering(object$x[rows], y[rows], object$lambda,
        lambda.selection = "cv", foldid = folds, backend = object$backend,
        nuisance.ridge = object$nuisance.ridge, curve.ridge = object$curve.ridge,
        control = object$control, warn = FALSE), error = function(e) e)
    record <- list(status = "fit_error", statistic = NA_real_, selected.lambda = NA_real_,
        selected.index = NA_integer_, eligible.candidates = 0L, message = NULL,
        diagnostics = NULL, cv.table = NULL, cv.fold.status = NULL,
        cv.fold.loss.sums = NULL)
    if (inherits(fit, "error")) {
        record$message <- conditionMessage(fit)
        return(list(fit = NULL, record = record))
    }
    record$diagnostics <- fit$diagnostics
    record$cv.table <- fit$cv.table
    record$cv.fold.status <- fit$cv.fold.status
    record$cv.fold.loss.sums <- fit$cv.fold.loss.sums
    record$eligible.candidates <- as.integer(sum(fit$cv.table$eligible))
    record$status <- "no_eligible_candidate"
    if (!is.null(fit$selected.index)) {
        eta <- as.numeric(stats::predict(fit, type = "link", lambda.index = fit$selected.index))
        if (all(is.finite(eta))) {
            yy <- y[rows]
            null.loss <- sum(.logistic.tf.binary.loss(yy, stats::qlogis(mean(yy))))
            fitted.loss <- sum(.logistic.tf.binary.loss(yy, eta))
            record$statistic <- max(0, 2 * (null.loss - fitted.loss))
            record$selected.lambda <- fit$lambda[fit$selected.index]
            record$selected.index <- fit$selected.index
            record$status <- "complete"
        } else record$status <- "nonfinite_prediction"
    }
    list(fit = fit, record = record)
}

.logistic.tf.assessment.prediction <- function(object, outer, inner) {
    n <- length(object$y); k <- length(inner)
    predictions <- data.frame(observation = seq_len(n), fold = outer, y = object$y,
        constant.probability = NA_real_, probability = NA_real_, eta = NA_real_,
        outside.range = NA)
    records <- vector("list", k)
    for (j in seq_len(k)) {
        train <- which(outer != j); test <- which(outer == j)
        predictions$constant.probability[test] <- mean(object$y[train])
        result <- .logistic.tf.assessment.refit(object, object$y, train, unname(inner[[j]]))
        record <- result$record
        record$training.range <- range(object$x[train])
        if (record$status == "complete") {
            eta <- stats::predict(result$fit, object$x[test], type = "link",
                                  lambda.index = record$selected.index)
            if (all(is.finite(eta))) {
                predictions$eta[test] <- as.numeric(eta)
                predictions$probability[test] <- stats::plogis(eta)
                predictions$outside.range[test] <- attr(eta, "outside.range")
            } else record$status <- "nonfinite_prediction"
        }
        records[[j]] <- record
    }
    predictions$constant.log.loss <- .logistic.tf.binary.loss(object$y,
        stats::qlogis(predictions$constant.probability))
    predictions$log.loss <- .logistic.tf.binary.loss(object$y, predictions$eta)
    predictions$constant.brier <- (object$y - predictions$constant.probability)^2
    predictions$brier <- (object$y - predictions$probability)^2
    complete <- all(is.finite(predictions$eta))
    scores <- data.frame(model = c("Constant probability", "Trend filtering"),
        log.loss = c(mean(predictions$constant.log.loss),
                     if (complete) mean(predictions$log.loss) else NA_real_),
        brier = c(mean(predictions$constant.brier),
                  if (complete) mean(predictions$brier) else NA_real_))
    list(status = if (complete) "complete" else "incomplete", scores = scores,
        improvement = c(log.loss = scores$log.loss[1L] - scores$log.loss[2L],
                        brier = scores$brier[1L] - scores$brier[2L]),
        folds = data.frame(fold = seq_len(k), training = tabulate(outer, k) * -1L + n,
            test = tabulate(outer, k),
            selected.lambda = vapply(records, `[[`, numeric(1), "selected.lambda"),
            status = vapply(records, `[[`, character(1), "status")),
        predictions = predictions, diagnostics = records)
}

#' @rdname assess.logistic.trend.filtering
#' @param x A `logistic.trend.filtering.assessment` to print.
#' @param ... Reserved for generic compatibility.
#' @method print logistic.trend.filtering.assessment
#' @export
print.logistic.trend.filtering.assessment <- function(x, ...) {
    cat("Order-2 logistic trend-filtering assessment\n")
    cat("Null: constant binary probability; independent, exchangeable observations\n")
    cat("Global test:", x$status, "\n")
    cat("Likelihood improvement statistic:", format(x$statistic), "\n")
    cat("Permutation p-value:", format(x$p.value), "\n")
    cat("Permutations:", x$permutation.summary$completed, "of",
        x$permutation.summary$requested, "completed\n")
    if (x$status == "incomplete_permutations")
        cat("Possible p-value range:", paste(format(x$p.value.bounds), collapse = " to "), "\n")
    if (!is.null(x$prediction)) {
        cat("Nested-CV prediction:", x$prediction$status, "\n")
        print(x$prediction$scores, row.names = FALSE)
        cat("Improvement (constant minus smoother):\n")
        print(x$prediction$improvement)
    }
    invisible(x)
}
