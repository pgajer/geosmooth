#!/usr/bin/env Rscript

`%||%` <- function(x, y) if (is.null(x)) y else x

parse_args <- function(args) {
  out <- list()
  for (arg in args) {
    if (!grepl("^--", arg)) next
    kv <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1L]]
    key <- kv[[1L]]
    val <- if (length(kv) >= 2L) paste(kv[-1L], collapse = "=") else TRUE
    out[[key]] <- val
  }
  out
}

json_escape <- function(x) {
  x <- as.character(x %||% "")
  x <- gsub("\\\\", "\\\\\\\\", x)
  x <- gsub('"', '\\"', x, fixed = TRUE)
  x <- gsub("\n", "\\\\n", x, fixed = TRUE)
  x
}

json_value <- function(x) {
  if (is.null(x) || length(x) == 0L || all(is.na(x))) return("null")
  if (is.logical(x)) return(if (isTRUE(x[[1L]])) "true" else "false")
  if (is.numeric(x) || is.integer(x)) {
    if (!is.finite(x[[1L]])) return("null")
    return(format(x[[1L]], scientific = FALSE, digits = 16))
  }
  paste0('"', json_escape(x[[1L]]), '"')
}

write_status <- function(path, fields) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  body <- paste(
    sprintf('  "%s": %s', names(fields), vapply(fields, json_value, character(1L))),
    collapse = ",\n"
  )
  writeLines(c("{", body, "}"), path)
}

rmse <- function(x, y) sqrt(mean((as.numeric(x) - as.numeric(y))^2))

args <- parse_args(commandArgs(trailingOnly = TRUE))
task_manifest <- args$task_manifest
task_id <- args$task_id

if (is.null(task_manifest) || is.null(task_id)) {
  stop("Usage: Rscript run_lps_local_auto_first_batch_task.R ",
       "--task_manifest=<path> --task_id=<task_id>", call. = FALSE)
}

task_manifest <- normalizePath(task_manifest, mustWork = TRUE)
tasks <- utils::read.csv(task_manifest, stringsAsFactors = FALSE)
row <- tasks[tasks$task_id == task_id, , drop = FALSE]
if (nrow(row) != 1L) {
  stop("Expected exactly one task row for task_id=", task_id, call. = FALSE)
}

status_path <- row$status_path[[1L]]
result_path <- row$result_path[[1L]]
started_at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
start_time <- proc.time()[["elapsed"]]

if (isTRUE(as.logical(row$skip_if_complete[[1L]]))) {
  if (file.exists(status_path) && file.exists(result_path)) {
    old_status <- tryCatch(paste(readLines(status_path, warn = FALSE),
                                 collapse = "\n"),
                           error = function(e) "")
    if (grepl('"status"[[:space:]]*:[[:space:]]*"ok"', old_status)) {
      quit(status = 0L)
    }
  }
}

dir.create(dirname(result_path), recursive = TRUE, showWarnings = FALSE)

write_status(status_path, list(
  task_id = task_id,
  dataset_id = row$dataset_id[[1L]],
  chart_dim_rule = row$chart_dim_rule[[1L]],
  status = "running",
  started_at = started_at,
  finished_at = NA_character_,
  elapsed_sec = NA_real_,
  hostname = Sys.info()[["nodename"]],
  pid = Sys.getpid(),
  result_path = result_path,
  error_message = NA_character_,
  error_class = NA_character_
))

result <- tryCatch({
  if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("pkgload is required to load geosmooth from source.", call. = FALSE)
  }
  pkgload::load_all(normalizePath(
    file.path(dirname(task_manifest), "..", "..", "..", ".."),
    mustWork = TRUE
  ),
                    quiet = TRUE)

  asset <- readRDS(row$asset_path[[1L]])
  fit <- fit.lps(
    X = asset$X,
    y = asset$y,
    foldid = asset$foldid,
    support.grid = 15:35,
    degree.grid = 2L,
    kernel.grid = c("gaussian", "tricube"),
    coordinate.method = "local.pca",
    chart.dim = row$chart_dim_rule[[1L]],
    local.chart.method = "pca",
    auto.chart.support.metric = "both",
    auto.chart.selection.metric = "operator",
    backend = "R"
  )
  pred <- as.numeric(fit$fitted.values)
  diag <- lps.backend.diagnostics(fit)
  summary <- data.frame(
    task_id = task_id,
    batch_id = row$batch_id[[1L]],
    dataset_id = row$dataset_id[[1L]],
    chart_dim_rule = row$chart_dim_rule[[1L]],
    n = nrow(asset$X),
    p = ncol(asset$X),
    selected_support_size = fit$selected$support.size[[1L]],
    selected_degree = fit$selected$degree[[1L]],
    selected_kernel = fit$selected$kernel[[1L]],
    selected_cv_rmse_observed = fit$selected$cv.rmse.observed[[1L]],
    observed_rmse = rmse(pred, asset$y),
    truth_rmse = rmse(pred, asset$f),
    resolved_chart_dim = fit$chart.dim,
    chart_dim_by_eval_n = if (is.null(fit$chart.dim.by.eval)) NA_integer_ else length(fit$chart.dim.by.eval),
    chart_dim_by_eval_min = if (is.null(fit$chart.dim.by.eval)) NA_integer_ else min(fit$chart.dim.by.eval),
    chart_dim_by_eval_median = if (is.null(fit$chart.dim.by.eval)) NA_real_ else stats::median(fit$chart.dim.by.eval),
    chart_dim_by_eval_max = if (is.null(fit$chart.dim.by.eval)) NA_integer_ else max(fit$chart.dim.by.eval),
    elapsed_sec = proc.time()[["elapsed"]] - start_time,
    stringsAsFactors = FALSE
  )
  saveRDS(list(
    task = row,
    asset_metadata = asset[c("batch.id", "dataset.id", "geometry.family",
                             "source.kind", "construction", "truth.params",
                             "sigma", "response.seed", "fold.seed")],
    summary = summary,
    backend_diagnostics = diag,
    selected = fit$selected,
    predictions = pred,
    chart_dim_by_eval = fit$chart.dim.by.eval
  ), result_path, compress = "xz")
  summary
}, error = function(e) {
  structure(
    list(message = conditionMessage(e), class = paste(class(e), collapse = "/")),
    class = "task_error"
  )
})

elapsed <- proc.time()[["elapsed"]] - start_time
finished_at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")

if (inherits(result, "task_error")) {
  write_status(status_path, list(
    task_id = task_id,
    dataset_id = row$dataset_id[[1L]],
    chart_dim_rule = row$chart_dim_rule[[1L]],
    status = "error",
    started_at = started_at,
    finished_at = finished_at,
    elapsed_sec = elapsed,
    hostname = Sys.info()[["nodename"]],
    pid = Sys.getpid(),
    result_path = result_path,
    error_message = result$message,
    error_class = result$class
  ))
  quit(status = 0L)
}

write_status(status_path, list(
  task_id = task_id,
  dataset_id = row$dataset_id[[1L]],
  chart_dim_rule = row$chart_dim_rule[[1L]],
  status = "ok",
  started_at = started_at,
  finished_at = finished_at,
  elapsed_sec = elapsed,
  hostname = Sys.info()[["nodename"]],
  pid = Sys.getpid(),
  result_path = result_path,
  error_message = NA_character_,
  error_class = NA_character_
))

quit(status = 0L)
