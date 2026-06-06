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

html_escape <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x
}

read_status <- function(path) {
  if (!file.exists(path)) return(NULL)
  txt <- paste(readLines(path, warn = FALSE), collapse = "\n")
  keys <- c("task_id", "dataset_id", "chart_dim_rule", "status",
            "started_at", "finished_at", "elapsed_sec", "hostname", "pid",
            "result_path", "error_message", "error_class")
  vals <- lapply(keys, function(key) {
    pattern <- paste0('"', key, '"[[:space:]]*:[[:space:]]*("[^"]*"|null|true|false|-?[0-9.]+)')
    m <- regexec(pattern, txt)
    hit <- regmatches(txt, m)[[1L]]
    if (length(hit) < 2L) return(NA_character_)
    val <- hit[[2L]]
    if (identical(val, "null")) return(NA_character_)
    if (grepl('^"', val)) return(gsub('\\"', '"', sub('"$', "", sub('^"', "", val))))
    val
  })
  names(vals) <- keys
  as.data.frame(vals, stringsAsFactors = FALSE)
}

rmse <- function(x, y) sqrt(mean((as.numeric(x) - as.numeric(y))^2))

args <- parse_args(commandArgs(trailingOnly = TRUE))
run.dir <- args$run_dir
if (is.null(run.dir)) {
  stop("Usage: Rscript merge_lps_local_auto_first_batch_run.R --run_dir=<path>",
       call. = FALSE)
}
run.dir <- normalizePath(run.dir, mustWork = TRUE)
task.manifest <- file.path(run.dir, "task_manifest.csv")
tasks <- utils::read.csv(task.manifest, stringsAsFactors = FALSE)

status.list <- lapply(tasks$status_path, read_status)
status <- do.call(rbind, status.list[!vapply(status.list, is.null, logical(1L))])
if (is.null(status)) {
  status <- data.frame(
    task_id = character(), dataset_id = character(),
    chart_dim_rule = character(), status = character(),
    started_at = character(), finished_at = character(),
    elapsed_sec = character(), hostname = character(), pid = character(),
    result_path = character(), error_message = character(),
    error_class = character(), stringsAsFactors = FALSE
  )
}
status <- merge(tasks[, c("task_id", "batch_id", "dataset_id",
                          "chart_dim_rule", "result_path", "status_path",
                          "log_path")],
                status,
                by = c("task_id", "dataset_id", "chart_dim_rule",
                       "result_path"),
                all.x = TRUE,
                suffixes = c("", ".status"))
status$status[is.na(status$status)] <- "missing"
status$elapsed_sec <- suppressWarnings(as.numeric(status$elapsed_sec))
utils::write.csv(status, file.path(run.dir, "tables", "task_status.csv"),
                 row.names = FALSE, quote = TRUE)

ok <- status$status == "ok" & file.exists(status$result_path)
results <- lapply(status$result_path[ok], function(path) {
  x <- readRDS(path)
  x$summary
})
combined <- if (length(results)) {
  do.call(rbind, results)
} else {
  data.frame()
}
utils::write.csv(combined, file.path(run.dir, "tables", "combined_results.csv"),
                 row.names = FALSE, quote = TRUE)

if (nrow(combined)) {
  wide <- reshape(
    combined[, c("dataset_id", "chart_dim_rule", "truth_rmse",
                 "observed_rmse", "selected_cv_rmse_observed",
                 "resolved_chart_dim", "chart_dim_by_eval_median",
                 "elapsed_sec")],
    idvar = "dataset_id",
    timevar = "chart_dim_rule",
    direction = "wide"
  )
  utils::write.csv(wide, file.path(run.dir, "tables", "paired_results_wide.csv"),
                   row.names = FALSE, quote = TRUE)
} else {
  wide <- data.frame()
}

status.count <- as.data.frame(table(status$status), stringsAsFactors = FALSE)
names(status.count) <- c("status", "n")
status.html <- paste(
  sprintf("<tr><td>%s</td><td class='num'>%d</td></tr>",
          html_escape(status.count$status), status.count$n),
  collapse = "\n"
)

result.rows <- if (nrow(combined)) {
  ord <- order(combined$dataset_id, combined$chart_dim_rule)
  paste(vapply(ord, function(i) {
    sprintf(
      "<tr><td>%s</td><td>%s</td><td class='num'>%.5f</td><td class='num'>%.5f</td><td class='num'>%.5f</td><td class='num'>%d</td><td class='num'>%.1f</td></tr>",
      html_escape(combined$dataset_id[[i]]),
      html_escape(combined$chart_dim_rule[[i]]),
      combined$truth_rmse[[i]],
      combined$observed_rmse[[i]],
      combined$selected_cv_rmse_observed[[i]],
      as.integer(combined$resolved_chart_dim[[i]]),
      combined$elapsed_sec[[i]]
    )
  }, character(1L)), collapse = "\n")
} else {
  "<tr><td colspan='7'>No completed results yet.</td></tr>"
}

fail.rows <- status[status$status %in% c("error", "missing"), , drop = FALSE]
fail.html <- if (nrow(fail.rows)) {
  paste(vapply(seq_len(nrow(fail.rows)), function(i) {
    sprintf("<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>",
            html_escape(fail.rows$task_id[[i]]),
            html_escape(fail.rows$status[[i]]),
            html_escape(fail.rows$error_message[[i]] %||% ""),
            html_escape(fail.rows$log_path[[i]]))
  }, character(1L)), collapse = "\n")
} else {
  "<tr><td colspan='4'>No errors or missing statuses.</td></tr>"
}

html <- c(
  "<!doctype html>",
  "<html><head><meta charset='utf-8'>",
  "<title>LPS local.auto first-batch run</title>",
  "<style>",
  "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;margin:32px;color:#1f2933}",
  "table{border-collapse:collapse;width:100%;margin:16px 0}",
  "th,td{border:1px solid #d8dee9;padding:7px 9px;text-align:left;font-size:14px}",
  "th{background:#f3f6fa}.num{text-align:right}code{background:#f3f6fa;padding:2px 4px}",
  "</style></head><body>",
  "<h1>LPS local.auto first-batch run</h1>",
  sprintf("<p><b>Run directory:</b> <code>%s</code></p>", html_escape(run.dir)),
  sprintf("<p><b>Generated:</b> %s</p>", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "<h2>Status</h2>",
  "<table><thead><tr><th>Status</th><th class='num'>Tasks</th></tr></thead><tbody>",
  status.html,
  "</tbody></table>",
  "<h2>Completed Results</h2>",
  "<table><thead><tr><th>Dataset</th><th>Chart rule</th><th class='num'>Truth RMSE</th><th class='num'>Observed RMSE</th><th class='num'>CV RMSE</th><th class='num'>Chart dim</th><th class='num'>Elapsed sec</th></tr></thead><tbody>",
  result.rows,
  "</tbody></table>",
  "<h2>Errors and Missing Tasks</h2>",
  "<table><thead><tr><th>Task</th><th>Status</th><th>Error</th><th>Log</th></tr></thead><tbody>",
  fail.html,
  "</tbody></table>",
  "</body></html>"
)
writeLines(html, file.path(run.dir, "reports", "lps_local_auto_first_batch_status.html"))

cat("Status table:", file.path(run.dir, "tables", "task_status.csv"), "\n")
cat("Combined results:", file.path(run.dir, "tables", "combined_results.csv"), "\n")
cat("HTML status:", file.path(run.dir, "reports", "lps_local_auto_first_batch_status.html"), "\n")
cat("Task counts:\n")
print(status.count, row.names = FALSE)

