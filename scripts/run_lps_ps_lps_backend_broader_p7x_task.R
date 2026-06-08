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

summarize.frame.design <- function(fit) {
    fs <- fit$frame.design.summary
    if (!is.data.frame(fs) || !nrow(fs)) {
        return(list(cols.min = NA_real_, cols.med = NA_real_, cols.max = NA_real_,
                    kept.min = NA_real_, kept.med = NA_real_, kept.max = NA_real_))
    }
    cols <- if ("design.cols" %in% names(fs)) fs$design.cols else NA_real_
    kept <- if ("design.cols.kept" %in% names(fs)) {
        fs$design.cols.kept
    } else {
        NA_real_
    }
    list(cols.min = suppressWarnings(min(cols, na.rm = TRUE)),
         cols.med = suppressWarnings(stats::median(cols, na.rm = TRUE)),
         cols.max = suppressWarnings(max(cols, na.rm = TRUE)),
         kept.min = suppressWarnings(min(kept, na.rm = TRUE)),
         kept.med = suppressWarnings(stats::median(kept, na.rm = TRUE)),
         kept.max = suppressWarnings(max(kept, na.rm = TRUE)))
}

args <- parse.args(commandArgs(trailingOnly = TRUE))
task.manifest <- args$task_manifest
task.id <- args$task_id
if (is.null(task.manifest) || is.null(task.id)) {
    stop("Usage: Rscript run_lps_ps_lps_backend_broader_p7x_task.R ",
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
    if (grepl('"status"[[:space:]]*:[[:space:]]*"ok"', old.status)) {
        quit(status = 0L)
    }
}

write.status(status.path, list(
    task_id = task.id,
    dataset_id = row$dataset_id[[1L]],
    method = row$method[[1L]],
    chart_dim_rule = row$chart_dim_rule[[1L]],
    backend_variant = row$backend_variant[[1L]],
    status = "running",
    started_at = started.at,
    finished_at = NA_character_,
    elapsed_sec = NA_real_,
    hostname = Sys.info()[["nodename"]],
    pid = Sys.getpid(),
    result_path = result.path,
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
    support.grid <- parse.integer.grid(row$support_grid[[1L]])
    degree.grid <- parse.integer.grid(row$degree_grid[[1L]])
    kernel.grid <- strsplit(row$kernel_grid[[1L]], ";", fixed = TRUE)[[1L]]
    lambda.sync.grid <- parse.numeric.grid(row$lambda_sync_grid[[1L]])
    local.candidate.search <- row$local_candidate_search[[1L]] %||% NA_character_
    if (is.na(local.candidate.search) || !nzchar(local.candidate.search)) {
        local.candidate.search <- "screened"
    }
    local.candidate.search.control <- parse.local.candidate.search.control(
        row$local_candidate_search_control
    )
    ridge.multiplier.grid <- parse.numeric.grid(
        row$ridge_multiplier_grid[[1L]]
    )
    ridge.condition.max <- parse.numeric.grid(row$ridge_condition_max[[1L]])[[1L]]
    design.drop.tol <- as.numeric(row$design_drop_tol[[1L]])

    fit <- if (identical(row$method[[1L]], "lps")) {
        fit.lps(
            X = asset$X,
            y = asset$y,
            foldid = asset$foldid,
            support.grid = support.grid,
            degree.grid = degree.grid,
            kernel.grid = kernel.grid,
            coordinate.method = "local.pca",
            chart.dim = row$chart_dim_rule[[1L]],
            local.chart.method = "pca",
            auto.chart.support.metric = "both",
            auto.chart.selection.metric = "operator",
            backend = "R",
            design.basis = row$design_basis[[1L]],
            design.drop.tol = design.drop.tol,
            ridge.multiplier.grid = ridge.multiplier.grid,
            ridge.condition.max = ridge.condition.max,
            unstable.action = "na"
        )
    } else {
        fit.ps.lps(
            X = asset$X,
            y = asset$y,
            foldid = asset$foldid,
            support.grid = support.grid,
            degree.grid = degree.grid,
            kernel.grid = kernel.grid,
            chart.dim = row$chart_dim_rule[[1L]],
            auto.chart.support.metric = "both",
            auto.chart.selection.metric = "operator",
            lambda.sync.grid = lambda.sync.grid,
            lambda.sync.search = row$lambda_sync_search[[1L]],
            local.candidate.search = local.candidate.search,
            local.candidate.search.control = local.candidate.search.control,
            lambda.ridge = 0,
            design.basis = row$design_basis[[1L]],
            design.drop.tol = design.drop.tol,
            ridge.multiplier.grid = ridge.multiplier.grid,
            ridge.condition.max = ridge.condition.max
        )
    }

    pred <- as.numeric(fit$fitted.values)
    truth.rmse <- rmse(pred, asset$f)
    observed.rmse <- rmse(pred, asset$y)
    selected <- fit$selected[1L, , drop = FALSE]
    chart <- summarize.chart.dim(fit)
    frame <- summarize.frame.design(fit)
    status <- if (!is.finite(truth.rmse) ||
                  !is.finite(selected$cv.rmse.observed[[1L]])) {
        "nonfinite_fit"
    } else {
        "ok"
    }

    summary <- data.frame(
        task_id = task.id,
        batch_id = row$batch_id[[1L]],
        dataset_id = row$dataset_id[[1L]],
        geometry_family = row$geometry_family[[1L]],
        n = nrow(asset$X),
        p = ncol(asset$X),
        method = row$method[[1L]],
        chart_dim_rule = row$chart_dim_rule[[1L]],
        backend_variant = row$backend_variant[[1L]],
        design_basis = row$design_basis[[1L]],
        design_drop_tol = design.drop.tol,
        ridge_multiplier_grid = row$ridge_multiplier_grid[[1L]],
        ridge_condition_max = ridge.condition.max,
        support_grid = row$support_grid[[1L]],
        degree_grid = row$degree_grid[[1L]],
        kernel_grid = row$kernel_grid[[1L]],
        lambda_sync_search = if (identical(row$method[[1L]], "ps_lps")) {
            row$lambda_sync_search[[1L]]
        } else {
            NA_character_
        },
        status = status,
        truth_rmse = truth.rmse,
        observed_rmse = observed.rmse,
        selected_cv_rmse_observed =
            finite.or.na(selected$cv.rmse.observed),
        selected_support_size = first.or.na(selected$support.size),
        selected_degree = first.or.na(selected$degree),
        selected_kernel = first.or.na(selected$kernel),
        selected_lambda_sync = finite.or.na(selected$lambda.sync),
        finite_cv_candidates = sum(is.finite(fit$cv.table$cv.rmse.observed)),
        total_cv_candidates = nrow(fit$cv.table),
        chart_dim_n = chart$n,
        chart_dim_min = chart$min,
        chart_dim_median = chart$median,
        chart_dim_max = chart$max,
        chart_dim_unique = chart$unique,
        frame_cols_min = frame$cols.min,
        frame_cols_median = frame$cols.med,
        frame_cols_max = frame$cols.max,
        frame_kept_min = frame$kept.min,
        frame_kept_median = frame$kept.med,
        frame_kept_max = frame$kept.max,
        ridge_multiplier_selected = fit$ridge.multiplier.selected %||%
            finite.or.na(selected$ridge.multiplier.selected),
        ridge_condition = fit$ridge.condition %||% NA_real_,
        ridge_status = fit$ridge.status %||% NA_character_,
        elapsed_sec = proc.time()[["elapsed"]] - start.time,
        stringsAsFactors = FALSE
    )
    saveRDS(list(
        task = row,
        summary = summary,
        selected = fit$selected,
        cv.table = fit$cv.table,
        frame.design.summary = fit$frame.design.summary,
        predictions = pred,
        truth = asset$f,
        y = asset$y,
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
        dataset_id = row$dataset_id[[1L]],
        method = row$method[[1L]],
        chart_dim_rule = row$chart_dim_rule[[1L]],
        backend_variant = row$backend_variant[[1L]],
        status = "error",
        started_at = started.at,
        finished_at = finished.at,
        elapsed_sec = elapsed,
        hostname = Sys.info()[["nodename"]],
        pid = Sys.getpid(),
        result_path = result.path,
        error_message = result$message,
        error_class = result$class
    ))
    quit(status = 0L)
}

write.status(status.path, list(
    task_id = task.id,
    dataset_id = row$dataset_id[[1L]],
    method = row$method[[1L]],
    chart_dim_rule = row$chart_dim_rule[[1L]],
    backend_variant = row$backend_variant[[1L]],
    status = result$status[[1L]],
    started_at = started.at,
    finished_at = finished.at,
    elapsed_sec = elapsed,
    hostname = Sys.info()[["nodename"]],
    pid = Sys.getpid(),
    result_path = result.path,
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
