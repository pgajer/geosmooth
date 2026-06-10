#!/usr/bin/env Rscript

parse.args <- function(args) {
    out <- list()
    for (arg in args) {
        if (!grepl("^--", arg)) next
        kv <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1L]]
        out[[kv[[1L]]]] <- if (length(kv) > 1L) {
            paste(kv[-1L], collapse = "=")
        } else TRUE
    }
    out
}

parse.integer.grid <- function(x) {
    if (grepl(":", x, fixed = TRUE)) {
        z <- as.integer(strsplit(x, ":", fixed = TRUE)[[1L]])
        return(seq.int(z[[1L]], z[[2L]]))
    }
    as.integer(strsplit(x, ";", fixed = TRUE)[[1L]])
}

parse.numeric.grid <- function(x) {
    as.numeric(strsplit(x, ";", fixed = TRUE)[[1L]])
}

args <- parse.args(commandArgs(trailingOnly = TRUE))
task.manifest <- args$task_manifest
task.id <- args$task_id
if (is.null(task.manifest) || is.null(task.id)) {
    stop("Usage: Rscript run_lps_binary_gm_ff_task.R ",
         "--task_manifest=<path> --task_id=<task_id>", call. = FALSE)
}

task.manifest <- normalizePath(task.manifest, mustWork = TRUE)
repo <- normalizePath(file.path(dirname(task.manifest), "..", ".."),
                      mustWork = TRUE)
source(file.path(repo, "scripts", "lps_binary_gm_ff_helpers.R"))

suppressPackageStartupMessages({
    if (!requireNamespace("pkgload", quietly = TRUE)) {
        stop("Package 'pkgload' is required.", call. = FALSE)
    }
})
pkgload::load_all(repo, quiet = TRUE)

tasks <- utils::read.csv(task.manifest, stringsAsFactors = FALSE,
                         colClasses = "character")
row <- tasks[tasks$task_id == task.id, , drop = FALSE]
if (nrow(row) != 1L) {
    stop("Expected exactly one task row for task_id=", task.id, call. = FALSE)
}

status.path <- row$status_path[[1L]]
result.path <- row$result_path[[1L]]
started.at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z",
                     tz = "America/New_York")
start.time <- proc.time()[["elapsed"]]

if (isTRUE(as.logical(row$skip_if_complete[[1L]])) &&
    file.exists(status.path) && file.exists(result.path)) {
    old.status <- tryCatch(paste(readLines(status.path, warn = FALSE),
                                 collapse = "\n"),
                           error = function(e) "")
    if (grepl('"status"[[:space:]]*:[[:space:]]*"ok"', old.status)) {
        quit(status = 0L)
    }
}

write.status.json(status.path, list(
    task_id = task.id,
    pair_id = row$pair_id[[1L]],
    scenario_id = row$scenario_id[[1L]],
    geometry_block = row$geometry_block[[1L]],
    sample_n = as.integer(row$sample_n[[1L]]),
    method_id = row$method_id[[1L]],
    chart_dim_rule = row$chart_dim_rule[[1L]],
    status = "running",
    started_at = started.at,
    finished_at = NA_character_,
    elapsed_sec = NA_real_,
    result_path = result.path,
    error_message = NA_character_,
    error_class = NA_character_
))

status <- "ok"
error.message <- ""
error.class <- ""
fit <- NULL
result <- NULL

extract.logistic.telemetry <- function(fit, stage) {
    empty <- list(
        attempted = NA_integer_,
        converged = NA_integer_,
        failed = NA_integer_,
        fallback.path.count = NA_integer_,
        event.rate.fallback.count = NA_integer_,
        na.failure.count = NA_integer_,
        convergence.fraction = NA_real_,
        fallback.path.fraction = NA_real_,
        event.rate.fallback.fraction = NA_real_,
        na.failure.fraction = NA_real_
    )
    diag <- fit$logistic.diagnostics[[stage]] %||% empty
    modifyList(empty, diag)
}

tryCatch({
    n <- as.integer(row$sample_n[[1L]])
    geometry.seed <- as.integer(row$geometry_seed[[1L]])
    fold.seed <- as.integer(row$fold_seed[[1L]])
    response.seed <- as.integer(row$response_seed[[1L]])
    k <- as.integer(row$gaussian_components[[1L]])

    geom <- make.geometry(row$geometry_block[[1L]], n, geometry.seed)
    f <- gaussian.truth(geom$latent, k)
    prob <- probability.profile(
        f,
        transform = row$profile_transform[[1L]],
        target.prevalence = as.numeric(row$target_prevalence[[1L]])
    )
    set.seed(response.seed)
    y <- stats::rbinom(length(prob), size = 1L, prob = prob)
    foldid <- make.folds(length(prob), k = as.integer(row$cv_folds[[1L]]),
                         seed = fold.seed)

    fit <- fit.lps(
        geom$X,
        y,
        foldid = foldid,
        support.grid = parse.integer.grid(row$support_grid[[1L]]),
        degree.grid = parse.integer.grid(row$degree_grid[[1L]]),
        kernel.grid = strsplit(row$kernel_grid[[1L]], ";", fixed = TRUE)[[1L]],
        cv.folds = as.integer(row$cv_folds[[1L]]),
        cv.seed = fold.seed,
        coordinate.method = "local.pca",
        chart.dim = row$chart_dim_rule[[1L]],
        auto.chart.support.metric = "both",
        auto.chart.selection.metric = "operator",
        backend = "R",
        design.basis = row$design_basis[[1L]],
        design.drop.tol = as.numeric(row$design_drop_tol[[1L]]),
        ridge.multiplier.grid = parse.numeric.grid(
            row$ridge_multiplier_grid[[1L]]
        ),
        ridge.condition.max = as.numeric(row$ridge_condition_max[[1L]]),
        unstable.action = row$unstable_action[[1L]],
        outcome.family = row$outcome_family[[1L]]
    )
    pred <- pmin(1, pmax(0, as.numeric(fit$fitted.values)))
    selected <- fit$selected
    logistic.cv <- extract.logistic.telemetry(fit, "cv")
    logistic.final <- extract.logistic.telemetry(fit, "final")
    result <- data.frame(
        task_id = task.id,
        pair_id = row$pair_id[[1L]],
        scenario_id = row$scenario_id[[1L]],
        geometry_block = row$geometry_block[[1L]],
        sample_n = n,
        gaussian_components = k,
        probability_profile = row$probability_profile[[1L]],
        target_prevalence = as.numeric(row$target_prevalence[[1L]]),
        repetition = as.integer(row$repetition[[1L]]),
        chart_dim_rule = row$chart_dim_rule[[1L]],
        method_id = row$method_id[[1L]],
        outcome_family = row$outcome_family[[1L]],
        status = "ok",
        truth_rmse_probability = truth.rmse(pred, prob),
        brier_truth_probability = brier.score(pred, prob),
        observed_logloss = logloss.score(pred, y),
        observed_event_rate = mean(y),
        realized_mean_probability = mean(prob),
        selected_support_size = first.or.na(selected$support.size),
        selected_degree = first.or.na(selected$degree),
        selected_kernel = first.or.na(selected$kernel),
        selected_score = first.or.na(selected[[row$selection_score[[1L]]]]),
        selected_cv_brier_observed = first.or.na(selected$cv.brier.observed),
        selected_cv_logloss_observed = first.or.na(selected$cv.logloss.observed),
        observed_logloss_scope = "full_data_final_fit_in_sample",
        logistic_cv_attempted = logistic.cv$attempted,
        logistic_cv_converged = logistic.cv$converged,
        logistic_cv_failed = logistic.cv$failed,
        logistic_cv_fallback_path_count = logistic.cv$fallback.path.count,
        logistic_cv_event_rate_fallback_count =
            logistic.cv$event.rate.fallback.count,
        logistic_cv_na_failure_count = logistic.cv$na.failure.count,
        logistic_cv_convergence_fraction = logistic.cv$convergence.fraction,
        logistic_cv_fallback_path_fraction =
            logistic.cv$fallback.path.fraction,
        logistic_cv_event_rate_fallback_fraction =
            logistic.cv$event.rate.fallback.fraction,
        logistic_cv_na_failure_fraction = logistic.cv$na.failure.fraction,
        logistic_final_attempted = logistic.final$attempted,
        logistic_final_converged = logistic.final$converged,
        logistic_final_failed = logistic.final$failed,
        logistic_final_fallback_path_count =
            logistic.final$fallback.path.count,
        logistic_final_event_rate_fallback_count =
            logistic.final$event.rate.fallback.count,
        logistic_final_na_failure_count = logistic.final$na.failure.count,
        logistic_final_convergence_fraction =
            logistic.final$convergence.fraction,
        logistic_final_fallback_path_fraction =
            logistic.final$fallback.path.fraction,
        logistic_final_event_rate_fallback_fraction =
            logistic.final$event.rate.fallback.fraction,
        logistic_final_na_failure_fraction =
            logistic.final$na.failure.fraction,
        logistic_cv_fallback_event_rate =
            logistic.cv$event.rate.fallback.fraction,
        logistic_final_fallback_event_rate =
            logistic.final$event.rate.fallback.fraction,
        stringsAsFactors = FALSE
    )
    dir.create(dirname(result.path), recursive = TRUE, showWarnings = FALSE)
    utils::write.csv(result, result.path, row.names = FALSE)
    if (!all(is.finite(pred))) {
        status <<- "nonfinite_fit"
    }
}, error = function(e) {
    status <<- "error"
    error.message <<- conditionMessage(e)
    error.class <<- class(e)[[1L]]
})

elapsed <- proc.time()[["elapsed"]] - start.time
finished.at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z",
                      tz = "America/New_York")

if (!identical(status, "ok") && is.null(result)) {
    result <- data.frame(
        task_id = task.id,
        pair_id = row$pair_id[[1L]],
        scenario_id = row$scenario_id[[1L]],
        geometry_block = row$geometry_block[[1L]],
        sample_n = as.integer(row$sample_n[[1L]]),
        gaussian_components = as.integer(row$gaussian_components[[1L]]),
        probability_profile = row$probability_profile[[1L]],
        target_prevalence = as.numeric(row$target_prevalence[[1L]]),
        repetition = as.integer(row$repetition[[1L]]),
        chart_dim_rule = row$chart_dim_rule[[1L]],
        method_id = row$method_id[[1L]],
        outcome_family = row$outcome_family[[1L]],
        status = status,
        error_message = error.message,
        stringsAsFactors = FALSE
    )
    dir.create(dirname(result.path), recursive = TRUE, showWarnings = FALSE)
    utils::write.csv(result, result.path, row.names = FALSE)
}

write.status.json(status.path, list(
    task_id = task.id,
    pair_id = row$pair_id[[1L]],
    scenario_id = row$scenario_id[[1L]],
    geometry_block = row$geometry_block[[1L]],
    sample_n = as.integer(row$sample_n[[1L]]),
    method_id = row$method_id[[1L]],
    chart_dim_rule = row$chart_dim_rule[[1L]],
    status = status,
    started_at = started.at,
    finished_at = finished.at,
    elapsed_sec = elapsed,
    result_path = result.path,
    error_message = error.message,
    error_class = error.class
))

if (!identical(status, "ok")) quit(status = 1L)
