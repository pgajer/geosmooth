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

parse.status.file <- function(path) {
    txt <- paste(readLines(path, warn = FALSE), collapse = "\n")
    get.char <- function(key) {
        pat <- paste0('"', key, '"[[:space:]]*:[[:space:]]*"([^"]*)"')
        m <- regexec(pat, txt)
        z <- regmatches(txt, m)[[1L]]
        if (length(z) < 2L) NA_character_ else z[[2L]]
    }
    get.num <- function(key) {
        pat <- paste0('"', key, '"[[:space:]]*:[[:space:]]*([-+0-9.eE]+)')
        m <- regexec(pat, txt)
        z <- regmatches(txt, m)[[1L]]
        if (length(z) < 2L) NA_real_ else as.numeric(z[[2L]])
    }
    data.frame(
        task_id = get.char("task_id"),
        pair_id = get.char("pair_id"),
        scenario_id = get.char("scenario_id"),
        geometry_block = get.char("geometry_block"),
        sample_n = get.num("sample_n"),
        method_id = get.char("method_id"),
        chart_dim_rule = get.char("chart_dim_rule"),
        status = get.char("status"),
        started_at = get.char("started_at"),
        finished_at = get.char("finished_at"),
        elapsed_sec = get.num("elapsed_sec"),
        result_path = get.char("result_path"),
        error_message = get.char("error_message"),
        error_class = get.char("error_class"),
        stringsAsFactors = FALSE
    )
}

safe.read.csv <- function(path) {
    tryCatch(
        utils::read.csv(path, stringsAsFactors = FALSE),
        error = function(e) NULL
    )
}

args <- parse.args(commandArgs(trailingOnly = TRUE))
run.dir <- args$run_dir
if (is.null(run.dir)) {
    stop("Usage: Rscript summarize_lps_binary_gm_ff_run.R --run_dir=<path>",
         call. = FALSE)
}
run.dir <- normalizePath(run.dir, mustWork = TRUE)
tables.dir <- file.path(run.dir, "tables")
dir.create(tables.dir, recursive = TRUE, showWarnings = FALSE)

task.manifest <- utils::read.csv(file.path(run.dir, "task_manifest.csv"),
                                 stringsAsFactors = FALSE)
status.files <- list.files(file.path(run.dir, "status"), pattern = "\\.json$",
                           full.names = TRUE)
status.rows <- if (length(status.files)) {
    do.call(rbind, lapply(status.files, parse.status.file))
} else {
    data.frame()
}
utils::write.csv(status.rows, file.path(tables.dir, "run_status_rows.csv"),
                 row.names = FALSE)

status.summary <- if (nrow(status.rows)) {
    aggregate(
        task_id ~ status + method_id + chart_dim_rule,
        data = status.rows,
        FUN = length
    )
} else {
    data.frame(status = character(), method_id = character(),
               chart_dim_rule = character(), task_id = integer())
}
names(status.summary)[names(status.summary) == "task_id"] <- "n"
utils::write.csv(status.summary, file.path(tables.dir, "run_status_summary.csv"),
                 row.names = FALSE)

result.files <- list.files(file.path(run.dir, "results"), pattern = "\\.csv$",
                           full.names = TRUE)
result.rows <- Filter(Negate(is.null), lapply(result.files, safe.read.csv))
if (length(result.rows)) {
    all.names <- unique(unlist(lapply(result.rows, names)))
    result.rows <- lapply(result.rows, function(x) {
        missing <- setdiff(all.names, names(x))
        for (nm in missing) x[[nm]] <- NA
        x[, all.names, drop = FALSE]
    })
    results <- do.call(rbind, result.rows)
} else {
    results <- data.frame()
}
utils::write.csv(results, file.path(tables.dir, "combined_results.csv"),
                 row.names = FALSE)

manifest.status <- merge(
    task.manifest[, c("task_id", "pair_id", "scenario_id", "method_id",
                      "chart_dim_rule", "result_path", "status_path")],
    status.rows[, intersect(c("task_id", "status", "elapsed_sec",
                              "error_class", "error_message"),
                            names(status.rows)), drop = FALSE],
    by = "task_id",
    all.x = TRUE
)
manifest.status$status[is.na(manifest.status$status)] <- "not_started"
utils::write.csv(manifest.status,
                 file.path(tables.dir, "manifest_status_snapshot.csv"),
                 row.names = FALSE)

top.summary <- data.frame(
    metric = c("planned_tasks", "status_rows", "result_rows",
               "ok_status_rows", "error_status_rows", "timeout_status_rows",
               "not_started_tasks"),
    value = c(
        nrow(task.manifest),
        nrow(status.rows),
        nrow(results),
        sum(status.rows$status == "ok", na.rm = TRUE),
        sum(status.rows$status == "error", na.rm = TRUE),
        sum(status.rows$status == "timeout", na.rm = TRUE),
        sum(manifest.status$status == "not_started", na.rm = TRUE)
    ),
    stringsAsFactors = FALSE
)
utils::write.csv(top.summary, file.path(tables.dir, "run_topline_summary.csv"),
                 row.names = FALSE)

print(top.summary)
