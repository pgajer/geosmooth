#!/usr/bin/env Rscript

parse.args <- function(args) {
    out <- list()
    for (arg in args) {
        if (!grepl("^--", arg)) next
        kv <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1L]]
        out[[kv[[1L]]]] <- if (length(kv) > 1L) {
            paste(kv[-1L], collapse = "=")
        } else {
            TRUE
        }
    }
    out
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

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

write.status <- function(path, fields) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    body <- paste(
        sprintf('  "%s": %s', names(fields),
                vapply(fields, json.value, character(1L))),
        collapse = ",\n"
    )
    writeLines(c("{", body, "}"), path)
}

parse.numeric.grid <- function(x) {
    if (identical(x, "Inf")) return(Inf)
    as.numeric(strsplit(x, ";", fixed = TRUE)[[1L]])
}

parse.integer.grid <- function(x) {
    if (grepl(":", x, fixed = TRUE)) {
        z <- as.integer(strsplit(x, ":", fixed = TRUE)[[1L]])
        return(seq.int(z[[1L]], z[[2L]]))
    }
    as.integer(strsplit(x, ";", fixed = TRUE)[[1L]])
}

parse.local.candidate.search.control <- function(x) {
    if (is.null(x) || length(x) == 0L || is.na(x[[1L]]) ||
        !nzchar(x[[1L]])) {
        return(list())
    }
    parts <- strsplit(x[[1L]], ";", fixed = TRUE)[[1L]]
    out <- list()
    for (part in parts) {
        kv <- strsplit(part, "=", fixed = TRUE)[[1L]]
        if (length(kv) != 2L) next
        key <- kv[[1L]]
        value <- kv[[2L]]
        if (identical(key, "guard.support.quantiles")) {
            out[[key]] <- as.numeric(strsplit(value, "|", fixed = TRUE)[[1L]])
        } else if (key %in% c("top.n", "max.candidates",
                              "neighbor.radius")) {
            out[[key]] <- as.integer(value)
        } else {
            out[[key]] <- value
        }
    }
    out
}

rmse <- function(x, y) {
    sqrt(mean((as.numeric(x) - as.numeric(y))^2))
}

finite.or.na <- function(x) {
    if (is.null(x) || length(x) == 0L || !is.finite(x[[1L]])) NA_real_ else x[[1L]]
}

first.or.na <- function(x) {
    if (is.null(x) || length(x) == 0L) NA else x[[1L]]
}

make.foldid <- function(n, folds, seed) {
    set.seed(seed)
    sample(rep(seq_len(folds), length.out = n))
}

summarize.chart.dim <- function(fit) {
    vals <- fit$chart.dim.by.anchor %||% fit$chart.dim.by.eval %||% fit$chart.dim
    vals <- suppressWarnings(as.numeric(vals))
    vals <- vals[is.finite(vals)]
    if (!length(vals)) {
        return(list(n = NA_integer_, min = NA_real_, median = NA_real_,
                    max = NA_real_, unique = NA_integer_))
    }
    list(n = length(vals), min = min(vals), median = stats::median(vals),
         max = max(vals), unique = length(unique(vals)))
}

summarize.local.candidates <- function(fit) {
    tab <- fit$local.candidate.table
    if (!is.data.frame(tab) || !nrow(tab)) {
        return(list(total = NA_integer_, evaluated = NA_integer_,
                    finite = NA_integer_, selected.id = NA_integer_,
                    selected.support = NA_integer_, selected.degree = NA_integer_,
                    selected.kernel = NA_character_,
                    selected.lambda = NA_real_, selected.cv = NA_real_,
                    evaluated.supports = NA_character_,
                    selected.key = NA_character_,
                    evaluated.keys = NA_character_))
    }
    evaluated <- rep(TRUE, nrow(tab))
    if ("ps_lps.evaluated" %in% names(tab)) {
        evaluated <- as.logical(tab$ps_lps.evaluated)
    } else if ("candidate.status" %in% names(tab)) {
        evaluated <- tab$candidate.status %in% c("evaluated", "ok")
    }
    finite <- evaluated & is.finite(tab$selected.cv.rmse.observed)
    selected.id <- which.min(ifelse(finite, tab$selected.cv.rmse.observed, Inf))
    if (!length(selected.id) || !is.finite(tab$selected.cv.rmse.observed[[selected.id]])) {
        selected.id <- NA_integer_
    }
    candidate.keys <- paste(tab$support.size, tab$degree, tab$kernel, sep = "|")
    list(
        total = nrow(tab),
        evaluated = sum(evaluated, na.rm = TRUE),
        finite = sum(finite, na.rm = TRUE),
        selected.id = selected.id,
        selected.support = if (is.na(selected.id)) NA_integer_ else
            tab$support.size[[selected.id]],
        selected.degree = if (is.na(selected.id)) NA_integer_ else
            tab$degree[[selected.id]],
        selected.kernel = if (is.na(selected.id)) NA_character_ else
            tab$kernel[[selected.id]],
        selected.lambda = if (is.na(selected.id)) NA_real_ else
            tab$selected.lambda.sync[[selected.id]],
        selected.cv = if (is.na(selected.id)) NA_real_ else
            tab$selected.cv.rmse.observed[[selected.id]],
        evaluated.supports = paste(sort(unique(tab$support.size[evaluated])),
                                   collapse = ";"),
        selected.key = if (is.na(selected.id)) NA_character_ else
            candidate.keys[[selected.id]],
        evaluated.keys = paste(sort(unique(candidate.keys[evaluated])),
                               collapse = ";")
    )
}

args <- parse.args(commandArgs(trailingOnly = TRUE))
task.manifest <- args$task_manifest
task.id <- args$task_id
if (is.null(task.manifest) || is.null(task.id)) {
    stop("Usage: Rscript run_ps_lps_s3r_light_task.R ",
         "--task_manifest=<path> --task_id=<task_id>", call. = FALSE)
}

task.manifest <- normalizePath(task.manifest, mustWork = TRUE)
tasks <- utils::read.csv(task.manifest, stringsAsFactors = FALSE,
                         colClasses = "character")
row <- tasks[tasks$task_id == task.id, , drop = FALSE]
if (nrow(row) != 1L) {
    stop("Expected exactly one task row for task_id=", task.id, call. = FALSE)
}

status.path <- row$status_path[[1L]]
result.path <- row$result_path[[1L]]
started.at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
start.time <- proc.time()[["elapsed"]]

if (isTRUE(as.logical(row$skip_if_complete[[1L]])) &&
    file.exists(status.path) && file.exists(result.path)) {
    old.status <- tryCatch(paste(readLines(status.path, warn = FALSE),
                                 collapse = "\n"),
                           error = function(e) "")
    if (grepl('"status"[[:space:]]*:[[:space:]]*"ok"', old.status) ||
        grepl('"status"[[:space:]]*:[[:space:]]*"nonfinite_fit"', old.status)) {
        quit(status = 0L)
    }
}

write.status(status.path, list(
    task_id = task.id,
    pair_id = row$pair_id[[1L]],
    dataset_id = row$dataset_id[[1L]],
    repetition = as.integer(row$repetition[[1L]]),
    method = row$method[[1L]],
    chart_dim_rule = row$chart_dim_rule[[1L]],
    search_policy = row$search_policy[[1L]],
    status = "running",
    started_at = started.at,
    finished_at = NA_character_,
    elapsed_sec = NA_real_,
    hostname = Sys.info()[["nodename"]],
    pid = Sys.getpid(),
    result_path = result.path,
    pair_response_seed = as.integer(row$pair_response_seed[[1L]]),
    pair_fold_seed = as.integer(row$pair_fold_seed[[1L]]),
    error_message = NA_character_,
    error_class = NA_character_
))

result <- tryCatch({
    if (!requireNamespace("pkgload", quietly = TRUE)) {
        stop("pkgload is required to load geosmooth from source.",
             call. = FALSE)
    }
    repo <- normalizePath(file.path(dirname(task.manifest), "..", ".."),
                          mustWork = TRUE)
    pkgload::load_all(repo, quiet = TRUE)

    asset <- readRDS(row$asset_path[[1L]])
    n <- nrow(asset$X)
    sigma <- suppressWarnings(as.numeric(asset$sigma[[1L]]))
    if (!is.finite(sigma) || sigma <= 0) {
        sigma <- stats::sd(as.numeric(asset$y) - as.numeric(asset$f))
    }
    if (!is.finite(sigma) || sigma <= 0) sigma <- 0.1
    set.seed(as.integer(row$response_seed[[1L]]))
    y <- as.numeric(asset$f) + stats::rnorm(n, sd = sigma)
    foldid <- make.foldid(n, folds = 5L,
                          seed = as.integer(row$fold_seed[[1L]]))

    support.grid <- parse.integer.grid(row$support_grid[[1L]])
    degree.grid <- parse.integer.grid(row$degree_grid[[1L]])
    kernel.grid <- strsplit(row$kernel_grid[[1L]], ";", fixed = TRUE)[[1L]]
    lambda.sync.grid <- parse.numeric.grid(row$lambda_sync_grid[[1L]])
    local.candidate.search.control <- parse.local.candidate.search.control(
        row$local_candidate_search_control
    )
    ridge.multiplier.grid <- parse.numeric.grid(
        row$ridge_multiplier_grid[[1L]]
    )
    ridge.condition.max <- parse.numeric.grid(row$ridge_condition_max[[1L]])[[1L]]
    design.drop.tol <- as.numeric(row$design_drop_tol[[1L]])

    fit <- fit.ps.lps(
        X = asset$X,
        y = y,
        foldid = foldid,
        support.grid = support.grid,
        degree.grid = degree.grid,
        kernel.grid = kernel.grid,
        chart.dim = row$chart_dim_rule[[1L]],
        auto.chart.support.metric = "both",
        auto.chart.selection.metric = "operator",
        lambda.sync.grid = lambda.sync.grid,
        lambda.sync.search = row$lambda_sync_search[[1L]],
        local.candidate.search = row$local_candidate_search[[1L]],
        local.candidate.search.control = local.candidate.search.control,
        lambda.ridge = 0,
        design.basis = row$design_basis[[1L]],
        design.drop.tol = design.drop.tol,
        ridge.multiplier.grid = ridge.multiplier.grid,
        ridge.condition.max = ridge.condition.max
    )

    pred <- as.numeric(fit$fitted.values)
    truth.rmse <- rmse(pred, asset$f)
    observed.rmse <- rmse(pred, y)
    selected <- fit$selected[1L, , drop = FALSE]
    chart <- summarize.chart.dim(fit)
    local <- summarize.local.candidates(fit)
    status <- if (!is.finite(truth.rmse) ||
                  !is.finite(selected$cv.rmse.observed[[1L]])) {
        "nonfinite_fit"
    } else {
        "ok"
    }

    timing <- fit$ps.lps.timing %||% list()
    summary <- data.frame(
        task_id = task.id,
        pair_id = row$pair_id[[1L]],
        batch_id = row$batch_id[[1L]],
        dataset_id = row$dataset_id[[1L]],
        geometry_family = row$geometry_family[[1L]],
        n = nrow(asset$X),
        p = ncol(asset$X),
        repetition = as.integer(row$repetition[[1L]]),
        pair_seed_base = as.integer(row$pair_seed_base[[1L]]),
        pair_response_seed = as.integer(row$pair_response_seed[[1L]]),
        pair_fold_seed = as.integer(row$pair_fold_seed[[1L]]),
        response_seed = as.integer(row$response_seed[[1L]]),
        fold_seed = as.integer(row$fold_seed[[1L]]),
        sigma = sigma,
        method = row$method[[1L]],
        chart_dim_rule = row$chart_dim_rule[[1L]],
        search_policy = row$search_policy[[1L]],
        backend_variant = row$backend_variant[[1L]],
        design_basis = row$design_basis[[1L]],
        support_grid = row$support_grid[[1L]],
        degree_grid = row$degree_grid[[1L]],
        kernel_grid = row$kernel_grid[[1L]],
        lambda_sync_search = row$lambda_sync_search[[1L]],
        status = status,
        truth_rmse = truth.rmse,
        observed_rmse = observed.rmse,
        selected_cv_rmse_observed =
            finite.or.na(selected$cv.rmse.observed),
        selected_support_size = first.or.na(selected$support.size),
        selected_degree = first.or.na(selected$degree),
        selected_kernel = first.or.na(selected$kernel),
        selected_lambda_sync = finite.or.na(selected$lambda.sync),
        selected_total_local_gcv_ps =
            finite.or.na(selected$total.local.gcv.ps),
        selected_sync_energy = finite.or.na(selected$sync.energy),
        finite_cv_candidates = sum(is.finite(fit$cv.table$cv.rmse.observed)),
        total_cv_candidates = nrow(fit$cv.table),
        local_candidates_total = local$total,
        local_candidates_evaluated = local$evaluated,
        local_candidates_finite = local$finite,
        local_candidates_evaluated_supports = local$evaluated.supports,
        selected_candidate_key = local$selected.key,
        evaluated_candidate_keys = local$evaluated.keys,
        chart_dim_n = chart$n,
        chart_dim_min = chart$min,
        chart_dim_median = chart$median,
        chart_dim_max = chart$max,
        chart_dim_unique = chart$unique,
        timing_frame_prep_sec =
            finite.or.na(timing$frame.prep.elapsed.sec),
        timing_system_cache_sec =
            finite.or.na(timing$system.cache.elapsed.sec),
        timing_fold_cache_sec =
            finite.or.na(timing$fold.component.cache.elapsed.sec),
        timing_lambda_search_sec =
            finite.or.na(timing$lambda.search.elapsed.sec),
        timing_final_solve_sec =
            finite.or.na(timing$final.solve.elapsed.sec),
        timing_total_fit_sec =
            finite.or.na(timing$total.fit.elapsed.sec),
        elapsed_sec = proc.time()[["elapsed"]] - start.time,
        stringsAsFactors = FALSE
    )
    saveRDS(list(
        task = row,
        summary = summary,
        selected = fit$selected,
        cv.table = fit$cv.table,
        local.candidate.table = fit$local.candidate.table,
        lambda.sync.search.telemetry = fit$lambda.sync.search.telemetry,
        ps.lps.timing = fit$ps.lps.timing,
        predictions = pred,
        truth = asset$f,
        y = y,
        foldid = foldid,
        chart.dim.by.anchor = fit$chart.dim.by.anchor %||%
            fit$chart.dim.by.eval %||% NULL
    ), result.path, compress = "xz")
    summary
}, error = function(e) {
    structure(list(message = conditionMessage(e),
                   class = paste(class(e), collapse = "/")),
              class = "task_error")
})

elapsed <- proc.time()[["elapsed"]] - start.time
finished.at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")

if (inherits(result, "task_error")) {
    write.status(status.path, list(
        task_id = task.id,
        pair_id = row$pair_id[[1L]],
        dataset_id = row$dataset_id[[1L]],
        repetition = as.integer(row$repetition[[1L]]),
        method = row$method[[1L]],
        chart_dim_rule = row$chart_dim_rule[[1L]],
        search_policy = row$search_policy[[1L]],
        status = "error",
        started_at = started.at,
        finished_at = finished.at,
        elapsed_sec = elapsed,
        hostname = Sys.info()[["nodename"]],
        pid = Sys.getpid(),
        result_path = result.path,
        pair_response_seed = as.integer(row$pair_response_seed[[1L]]),
        pair_fold_seed = as.integer(row$pair_fold_seed[[1L]]),
        error_message = result$message,
        error_class = result$class
    ))
    quit(status = 0L)
}

write.status(status.path, list(
    task_id = task.id,
    pair_id = row$pair_id[[1L]],
    dataset_id = row$dataset_id[[1L]],
    repetition = as.integer(row$repetition[[1L]]),
    method = row$method[[1L]],
    chart_dim_rule = row$chart_dim_rule[[1L]],
    search_policy = row$search_policy[[1L]],
    status = result$status[[1L]],
    started_at = started.at,
    finished_at = finished.at,
    elapsed_sec = elapsed,
    hostname = Sys.info()[["nodename"]],
    pid = Sys.getpid(),
    result_path = result.path,
    pair_response_seed = as.integer(row$pair_response_seed[[1L]]),
    pair_fold_seed = as.integer(row$pair_fold_seed[[1L]]),
    error_message = if (identical(result$status[[1L]], "ok")) {
        NA_character_
    } else {
        "fit completed but selected fit or observed CV score was nonfinite"
    },
    error_class = if (identical(result$status[[1L]], "ok")) {
        NA_character_
    } else {
        "nonfinite_fit"
    }
))

quit(status = 0L)
