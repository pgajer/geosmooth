#!/usr/bin/env Rscript

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

`%||%` <- function(x, y) if (is.null(x)) y else x

sanitize_id <- function(x) gsub("[^A-Za-z0-9_]+", "_", x)

args <- parse_args(commandArgs(trailingOnly = TRUE))
repo <- normalizePath(args$repo %||% getwd(), mustWork = TRUE)
freeze.dir <- normalizePath(
  args$freeze_dir %||%
    file.path(repo, "split_handoffs",
              "lps_local_auto_nonmanifold_first_batch_2026-06-05"),
  mustWork = TRUE
)
run.id <- args$run_id %||%
  paste0("lps_local_auto_fb_", format(Sys.time(), "%Y%m%d_%H%M%S"))
n.workers <- as.integer(args$n_workers %||% "10")
if (!is.finite(n.workers) || n.workers < 1L) {
  stop("'n_workers' must be a positive integer.", call. = FALSE)
}

run.dir <- file.path(freeze.dir, "runs", run.id)
dir.create(file.path(run.dir, "logs"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(run.dir, "status"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(run.dir, "results"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(run.dir, "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(run.dir, "reports"), recursive = TRUE, showWarnings = FALSE)

asset.manifest <- utils::read.csv(file.path(freeze.dir, "asset_manifest.csv"),
                                  stringsAsFactors = FALSE)
rules <- c("auto", "local.auto")
tasks <- do.call(rbind, lapply(seq_len(nrow(asset.manifest)), function(i) {
  a <- asset.manifest[i, , drop = FALSE]
  do.call(rbind, lapply(rules, function(rule) {
    task.id <- paste0(a$batch.id, "__", sanitize_id(a$dataset.id), "__chart_",
                      gsub("\\.", "_", rule))
    data.frame(
      task_id = task.id,
      batch_id = a$batch.id,
      dataset_id = a$dataset.id,
      chart_dim_rule = rule,
      asset_path = a$asset.path,
      result_path = file.path(run.dir, "results", paste0(task.id, ".rds")),
      status_path = file.path(run.dir, "status", paste0(task.id, ".json")),
      log_path = file.path(run.dir, "logs", paste0(task.id, ".log")),
      skip_if_complete = TRUE,
      stringsAsFactors = FALSE
    )
  }))
}))

task.manifest.path <- file.path(run.dir, "task_manifest.csv")
utils::write.csv(tasks, task.manifest.path, row.names = FALSE, quote = TRUE)

run.config <- data.frame(
  run_id = run.id,
  repo = repo,
  freeze_dir = freeze.dir,
  run_dir = run.dir,
  n_workers = n.workers,
  task_count = nrow(tasks),
  created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  stringsAsFactors = FALSE
)
utils::write.csv(run.config, file.path(run.dir, "run_config.csv"),
                 row.names = FALSE, quote = TRUE)

worker <- file.path(repo, "scripts", "run_lps_local_auto_first_batch_task.R")
merge <- file.path(repo, "scripts", "merge_lps_local_auto_first_batch_run.R")
launcher <- file.path(run.dir, "launch_local.sh")

launcher.lines <- c(
  "#!/usr/bin/env bash",
  "set -euo pipefail",
  sprintf("RUN_DIR=%s", shQuote(run.dir)),
  sprintf("TASK_MANIFEST=%s", shQuote(task.manifest.path)),
  sprintf("WORKER=%s", shQuote(worker)),
  sprintf("MERGE_SCRIPT=%s", shQuote(merge)),
  sprintf("N_WORKERS=${N_WORKERS:-%d}", n.workers),
  "export RUN_DIR TASK_MANIFEST WORKER MERGE_SCRIPT",
  "mkdir -p \"${RUN_DIR}/logs\" \"${RUN_DIR}/status\" \"${RUN_DIR}/results\" \"${RUN_DIR}/tables\" \"${RUN_DIR}/reports\"",
  "cut -d, -f1 \"${TASK_MANIFEST}\" | tail -n +2 | \\",
  "  xargs -n 1 -P \"${N_WORKERS}\" bash -c '",
  "    set -u",
  "    task_id=\"$1\"",
  "    log=\"${RUN_DIR}/logs/${task_id}.log\"",
  "    status_path=\"${RUN_DIR}/status/${task_id}.json\"",
  "    Rscript \"${WORKER}\" --task_manifest=\"${TASK_MANIFEST}\" --task_id=\"${task_id}\" > \"${log}\" 2>&1 || rc=$?",
  "    rc=${rc:-0}",
  "    if [ \"${rc}\" -ne 0 ]; then",
  "      now=$(date +\"%Y-%m-%d %H:%M:%S %Z\")",
  "      cat > \"${status_path}\" <<EOF",
  "{",
  "  \"task_id\": \"${task_id}\",",
  "  \"dataset_id\": null,",
  "  \"chart_dim_rule\": null,",
  "  \"status\": \"error\",",
  "  \"started_at\": null,",
  "  \"finished_at\": \"${now}\",",
  "  \"elapsed_sec\": null,",
  "  \"hostname\": \"$(hostname)\",",
  "  \"pid\": null,",
  "  \"result_path\": null,",
  "  \"error_message\": \"worker process exited nonzero; see task log\",",
  "  \"error_class\": \"worker_exit_${rc}\"",
  "}",
  "EOF",
  "    fi",
  "    exit 0",
  "  ' _",
  "Rscript \"${MERGE_SCRIPT}\" --run_dir=\"${RUN_DIR}\" > \"${RUN_DIR}/logs/merge_after_launch.log\" 2>&1 || true"
)
writeLines(launcher.lines, launcher)
Sys.chmod(launcher, mode = "0755")

cat("Prepared run directory:\n", run.dir, "\n", sep = "")
cat("Task manifest:\n", task.manifest.path, "\n", sep = "")
cat("Launcher:\n", launcher, "\n", sep = "")
cat("Tasks:", nrow(tasks), "\n")
cat("Workers:", n.workers, "\n")
