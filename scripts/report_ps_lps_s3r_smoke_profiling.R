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

scalar.char <- function(x, default = NA_character_) {
    if (is.null(x) || length(x) == 0L) return(default)
    x <- as.character(x[[1L]])
    if (!length(x) || is.na(x)) default else x
}

scalar.num <- function(x, default = NA_real_) {
    if (is.null(x) || length(x) == 0L) return(default)
    out <- suppressWarnings(as.numeric(x[[1L]]))
    if (!length(out)) default else out
}

html.escape <- function(x) {
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    gsub(">", "&gt;", x, fixed = TRUE)
}

fmt <- function(x, digits = 4) {
    ifelse(is.na(x), "NA",
           ifelse(is.finite(x), formatC(x, format = "fg", digits = digits),
                  as.character(x)))
}

table.html <- function(df, digits = 4, max.rows = Inf) {
    if (!nrow(df)) return("<p>No rows.</p>")
    if (is.finite(max.rows) && nrow(df) > max.rows) {
        df <- utils::head(df, max.rows)
    }
    dff <- df
    for (nm in names(dff)) {
        if (is.numeric(dff[[nm]])) dff[[nm]] <- fmt(dff[[nm]], digits)
    }
    header <- paste0("<tr>", paste0("<th>", html.escape(names(dff)), "</th>",
                                   collapse = ""), "</tr>")
    body <- apply(dff, 1L, function(row) {
        paste0("<tr>", paste0("<td>", html.escape(row), "</td>", collapse = ""),
               "</tr>")
    })
    paste0("<table>", header, paste(body, collapse = "\n"), "</table>")
}

read.status <- function(path) {
    if (!file.exists(path)) return(NULL)
    if (requireNamespace("jsonlite", quietly = TRUE)) {
        out <- tryCatch(jsonlite::fromJSON(path), error = function(e) NULL)
        if (!is.null(out)) {
            df <- tryCatch(as.data.frame(out, stringsAsFactors = FALSE),
                           error = function(e) NULL)
            if (!is.null(df)) return(df)
        }
    }
    txt <- paste(readLines(path, warn = FALSE), collapse = "\n")
    keys <- c("task_id", "dataset_id", "repetition", "method",
              "chart_dim_rule", "search_policy", "status", "started_at",
              "finished_at", "elapsed_sec", "hostname", "pid", "result_path",
              "error_message", "error_class")
    vals <- lapply(keys, function(key) {
        pattern <- paste0('"', key, '"[[:space:]]*:[[:space:]]*',
                          '("[^"]*"|null|true|false|-?[0-9.]+)')
        m <- regexec(pattern, txt)
        hit <- regmatches(txt, m)[[1L]]
        if (length(hit) < 2L) return(NA_character_)
        val <- hit[[2L]]
        if (identical(val, "null")) return(NA_character_)
        if (grepl('^"', val)) {
            return(gsub('\\"', '"', sub('"$', "", sub('^"', "", val))))
        }
        val
    })
    names(vals) <- keys
    as.data.frame(vals, stringsAsFactors = FALSE)
}

safe.read.result <- function(path) {
    if (!file.exists(path)) return(NULL)
    tryCatch(readRDS(path), error = function(e) NULL)
}

write.svg <- function(path, width = 10, height = 5.5, expr) {
    grDevices::svg(path, width = width, height = height, onefile = TRUE)
    on.exit(grDevices::dev.off(), add = TRUE)
    force(expr)
}

make.stacked.status.plot <- function(df, path) {
    tab <- xtabs(n ~ dataset_id + status, df)
    status.order <- c("ok", "stopped_by_user", "not_started", "missing",
                      "error", "nonfinite_fit", "timeout")
    status.order <- intersect(status.order, colnames(tab))
    tab <- tab[, status.order, drop = FALSE]
    pal <- c(ok = "#009E73", stopped_by_user = "#E69F00",
             not_started = "#999999", missing = "#999999",
             error = "#D55E00", nonfinite_fit = "#CC79A7",
             timeout = "#0072B2")
    cols <- pal[colnames(tab)]
    write.svg(path, width = 11, height = 6.5, {
        old <- par(mar = c(9, 5, 2, 1))
        on.exit(par(old), add = TRUE)
        barplot(t(tab), col = cols, las = 2, ylab = "Task count",
                border = NA, cex.names = 0.75,
                main = "Manifest-backed task accounting by dataset")
        legend("topright", legend = colnames(tab), fill = cols, bty = "n",
               cex = 0.85)
    })
}

make.runtime.policy.plot <- function(summary.df, path) {
    ok <- summary.df[summary.df$status == "ok" &
                         is.finite(summary.df$elapsed_sec), , drop = FALSE]
    if (!nrow(ok)) return(FALSE)
    ok$arm <- paste(ok$search_policy, ok$chart_dim_rule, sep = " / ")
    write.svg(path, width = 9, height = 5.5, {
        old <- par(mar = c(7, 5, 2, 1))
        on.exit(par(old), add = TRUE)
        boxplot(elapsed_sec ~ arm, data = ok, log = "y", las = 2,
                ylab = "Elapsed seconds, log scale",
                main = "Completed task runtimes by search policy and chart rule",
                col = "#D8E8F6", border = "#4C6A88")
        stripchart(elapsed_sec ~ arm, data = ok, vertical = TRUE,
                   method = "jitter", pch = 16, cex = 0.55,
                   col = grDevices::adjustcolor("#333333", 0.45),
                   add = TRUE)
    })
    TRUE
}

make.runtime.tail.plot <- function(summary.df, path) {
    ok <- summary.df[summary.df$status == "ok" &
                         is.finite(summary.df$elapsed_sec), , drop = FALSE]
    if (!nrow(ok)) return(FALSE)
    ok <- ok[order(ok$elapsed_sec, decreasing = TRUE), , drop = FALSE]
    top <- utils::head(ok, 20L)
    top$label <- paste(top$dataset_id, top$chart_dim_rule, top$search_policy,
                       paste0("r", top$repetition), sep = " | ")
    top <- top[order(top$elapsed_sec), , drop = FALSE]
    write.svg(path, width = 11, height = 7, {
        old <- par(mar = c(5, 12, 2, 1))
        on.exit(par(old), add = TRUE)
        yy <- seq_len(nrow(top))
        plot(top$elapsed_sec, yy, pch = 16, yaxt = "n", log = "x",
             xlab = "Elapsed seconds, log scale", ylab = "",
             main = "Top 20 completed runtime tails")
        segments(x0 = min(top$elapsed_sec), x1 = top$elapsed_sec,
                 y0 = yy, y1 = yy, col = "#B8BDC7")
        axis(2, at = yy, labels = top$label, las = 2, cex.axis = 0.65)
        grid(nx = NA, ny = NULL, col = "#E8EAF0")
    })
    TRUE
}

make.dataset_runtime_plot <- function(summary.df, path) {
    ok <- summary.df[summary.df$status == "ok" &
                         is.finite(summary.df$elapsed_sec), , drop = FALSE]
    if (!nrow(ok)) return(FALSE)
    agg <- aggregate(elapsed_sec ~ dataset_id + search_policy, ok,
                     stats::median)
    datasets <- unique(agg$dataset_id)
    x <- seq_along(datasets)
    ymax <- max(agg$elapsed_sec, na.rm = TRUE) * 1.15
    write.svg(path, width = 11, height = 5.8, {
        old <- par(mar = c(9, 5, 2, 1))
        on.exit(par(old), add = TRUE)
        plot(x, rep(NA_real_, length(x)), ylim = c(1, ymax), log = "y",
             xaxt = "n", xlab = "", ylab = "Median elapsed seconds, log scale",
             main = "Median completed runtime by dataset and search policy")
        axis(1, at = x, labels = datasets, las = 2, cex.axis = 0.7)
        for (ii in x) {
            sub <- agg[agg$dataset_id == datasets[[ii]], , drop = FALSE]
            full <- sub$elapsed_sec[sub$search_policy == "full"]
            screened <- sub$elapsed_sec[sub$search_policy == "screened"]
            if (length(full) && length(screened)) {
                segments(ii, full, ii, screened, col = "#777777")
            }
            if (length(full)) points(ii - 0.08, full, pch = 16,
                                     col = "#D55E00")
            if (length(screened)) points(ii + 0.08, screened, pch = 16,
                                         col = "#0072B2")
        }
        legend("topleft", legend = c("full", "screened"),
               pch = 16, col = c("#D55E00", "#0072B2"), bty = "n")
        grid(nx = NA, ny = NULL, col = "#E8EAF0")
    })
    TRUE
}

args <- parse.args(commandArgs(trailingOnly = TRUE))
run.dir <- normalizePath(
    args$run_dir %||%
        "/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_20260607_001",
    mustWork = TRUE
)
tables.dir <- file.path(run.dir, "tables")
reports.dir <- file.path(run.dir, "reports")
figures.dir <- file.path(reports.dir, "figures_s3r_smoke")
dir.create(tables.dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figures.dir, recursive = TRUE, showWarnings = FALSE)

build.time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
manifest <- utils::read.csv(file.path(run.dir, "task_manifest.csv"),
                            stringsAsFactors = FALSE)
statuses <- lapply(manifest$status_path, read.status)
status.df <- do.call(rbind, lapply(seq_len(nrow(manifest)), function(ii) {
    st <- statuses[[ii]]
    row <- manifest[ii, , drop = FALSE]
    if (is.null(st)) {
        data.frame(task_id = row$task_id, status = "not_started",
                   elapsed_sec = NA_real_, started_at = NA_character_,
                   finished_at = NA_character_, error_class = NA_character_,
                   error_message = NA_character_, stringsAsFactors = FALSE)
    } else {
        data.frame(task_id = row$task_id,
                   status = scalar.char(st$status),
                   elapsed_sec = scalar.num(st$elapsed_sec),
                   started_at = scalar.char(st$started_at),
                   finished_at = scalar.char(st$finished_at),
                   error_class = scalar.char(st$error_class),
                   error_message = scalar.char(st$error_message),
                   stringsAsFactors = FALSE)
    }
}))
task.status <- merge(manifest, status.df, by = "task_id", all.x = TRUE,
                     sort = FALSE)
utils::write.csv(task.status,
                 file.path(tables.dir, "s3r_smoke_manifest_backed_status.csv"),
                 row.names = FALSE, quote = TRUE)

summary.list <- list()
timing.list <- list()
candidate.list <- list()
for (ii in seq_len(nrow(manifest))) {
    res <- safe.read.result(manifest$result_path[[ii]])
    if (is.null(res)) next
    if (is.data.frame(res$summary)) {
        summary.list[[length(summary.list) + 1L]] <- res$summary
    }
    if (is.list(res$ps.lps.timing)) {
        timing.list[[length(timing.list) + 1L]] <- data.frame(
            task_id = manifest$task_id[[ii]],
            phase = names(res$ps.lps.timing),
            value = suppressWarnings(as.numeric(unlist(res$ps.lps.timing))),
            stringsAsFactors = FALSE
        )
    }
    if (is.data.frame(res$local.candidate.table)) {
        cand <- res$local.candidate.table
        cand$task_id <- manifest$task_id[[ii]]
        candidate.list[[length(candidate.list) + 1L]] <- cand
    }
}
summary.df <- if (length(summary.list)) do.call(rbind, summary.list) else
    data.frame()
timing.df <- if (length(timing.list)) do.call(rbind, timing.list) else
    data.frame()
candidate.df <- if (length(candidate.list)) do.call(rbind, candidate.list) else
    data.frame()
if (nrow(summary.df)) {
    numeric.cols <- c("elapsed_sec", "truth_rmse", "observed_rmse",
                      "selected_cv_rmse_observed",
                      "selected_support_size", "selected_lambda_sync",
                      "local_candidates_total", "local_candidates_evaluated",
                      "finite_cv_candidates", "total_cv_candidates",
                      "chart_dim_median")
    for (nm in intersect(numeric.cols, names(summary.df))) {
        summary.df[[nm]] <- suppressWarnings(as.numeric(summary.df[[nm]]))
    }
}
utils::write.csv(summary.df,
                 file.path(tables.dir, "s3r_smoke_completed_task_summary.csv"),
                 row.names = FALSE, quote = TRUE)
utils::write.csv(timing.df,
                 file.path(tables.dir, "s3r_smoke_fit_timing_long.csv"),
                 row.names = FALSE, quote = TRUE)

task.counts <- as.data.frame(xtabs(~ status, task.status),
                             stringsAsFactors = FALSE)
names(task.counts) <- c("status", "n")
dataset.counts <- as.data.frame(xtabs(~ dataset_id + status, task.status),
                                stringsAsFactors = FALSE)
names(dataset.counts) <- c("dataset_id", "status", "n")
dataset.counts <- dataset.counts[dataset.counts$n > 0, , drop = FALSE]
policy.counts <- as.data.frame(
    xtabs(~ search_policy + chart_dim_rule + status, task.status),
    stringsAsFactors = FALSE
)
names(policy.counts) <- c("search_policy", "chart_dim_rule", "status", "n")
policy.counts <- policy.counts[policy.counts$n > 0, , drop = FALSE]
utils::write.csv(dataset.counts,
                 file.path(tables.dir, "s3r_smoke_status_by_dataset.csv"),
                 row.names = FALSE, quote = TRUE)
utils::write.csv(policy.counts,
                 file.path(tables.dir, "s3r_smoke_status_by_policy_chart.csv"),
                 row.names = FALSE, quote = TRUE)

runtime.summary <- data.frame()
if (nrow(summary.df)) {
    runtime.summary <- do.call(rbind, lapply(
        split(summary.df[summary.df$status == "ok" &
                             is.finite(summary.df$elapsed_sec), , drop = FALSE],
              list(summary.df$search_policy[summary.df$status == "ok" &
                                               is.finite(summary.df$elapsed_sec)],
                   summary.df$chart_dim_rule[summary.df$status == "ok" &
                                                is.finite(summary.df$elapsed_sec)],
                   summary.df$dataset_id[summary.df$status == "ok" &
                                            is.finite(summary.df$elapsed_sec)]),
              drop = TRUE),
        function(x) {
            data.frame(search_policy = x$search_policy[[1L]],
                       chart_dim_rule = x$chart_dim_rule[[1L]],
                       dataset_id = x$dataset_id[[1L]],
                       n = nrow(x),
                       median_elapsed_sec = stats::median(x$elapsed_sec),
                       p90_elapsed_sec = as.numeric(stats::quantile(
                           x$elapsed_sec, 0.9, names = FALSE, type = 7
                       )),
                       max_elapsed_sec = max(x$elapsed_sec),
                       median_candidates_evaluated =
                           stats::median(x$local_candidates_evaluated,
                                         na.rm = TRUE),
                       stringsAsFactors = FALSE)
        }
    ))
}
utils::write.csv(runtime.summary,
                 file.path(tables.dir,
                           "s3r_smoke_runtime_summary_by_dataset_policy.csv"),
                 row.names = FALSE, quote = TRUE)

runtime.tail <- if (nrow(summary.df)) {
    ok <- summary.df[summary.df$status == "ok" &
                         is.finite(summary.df$elapsed_sec), , drop = FALSE]
    ok <- ok[order(ok$elapsed_sec, decreasing = TRUE), , drop = FALSE]
    utils::head(ok[, intersect(names(ok), c(
        "task_id", "dataset_id", "repetition", "chart_dim_rule",
        "search_policy", "elapsed_sec", "local_candidates_evaluated",
        "selected_support_size", "selected_lambda_sync",
        "selected_cv_rmse_observed"
    ))], 25L)
} else {
    data.frame()
}
utils::write.csv(runtime.tail,
                 file.path(tables.dir, "s3r_smoke_runtime_tail_top25.csv"),
                 row.names = FALSE, quote = TRUE)

timing.phase.summary <- data.frame()
if (nrow(timing.df) && nrow(summary.df)) {
    phase.wide <- reshape(timing.df, idvar = "task_id", timevar = "phase",
                          direction = "wide")
    phase <- merge(summary.df[, c("task_id", "dataset_id", "chart_dim_rule",
                                  "search_policy")],
                   phase.wide, by = "task_id", all.x = TRUE)
    phase.cols <- grep("^value[.]", names(phase), value = TRUE)
    timing.phase.summary <- do.call(rbind, lapply(
        split(phase, list(phase$search_policy, phase$chart_dim_rule),
              drop = TRUE),
        function(x) {
            out <- data.frame(search_policy = x$search_policy[[1L]],
                              chart_dim_rule = x$chart_dim_rule[[1L]],
                              n = nrow(x), stringsAsFactors = FALSE)
            for (nm in phase.cols) {
                out[[sub("^value[.]", "median_", nm)]] <-
                    stats::median(x[[nm]], na.rm = TRUE)
            }
            out
        }
    ))
}
utils::write.csv(timing.phase.summary,
                 file.path(tables.dir, "s3r_smoke_phase_timing_summary.csv"),
                 row.names = FALSE, quote = TRUE)

status.plot <- file.path(figures.dir, "task_accounting_by_dataset.svg")
runtime.plot <- file.path(figures.dir, "runtime_by_policy_chart.svg")
tail.plot <- file.path(figures.dir, "runtime_tail_top20.svg")
dataset.runtime.plot <- file.path(figures.dir, "median_runtime_by_dataset_policy.svg")
make.stacked.status.plot(dataset.counts, status.plot)
has.runtime <- make.runtime.policy.plot(summary.df, runtime.plot)
has.tail <- make.runtime.tail.plot(summary.df, tail.plot)
has.dataset.runtime <- make.dataset_runtime_plot(summary.df, dataset.runtime.plot)

log.text <- if (file.exists(file.path(run.dir, "logs", "python_launcher.log"))) {
    readLines(file.path(run.dir, "logs", "python_launcher.log"), warn = FALSE)
} else character()
timeout.lines <- grep("timeout", log.text, value = TRUE, ignore.case = TRUE)
kill.lines <- grep("kill|killed|memory|oom|jetsam", log.text, value = TRUE,
                   ignore.case = TRUE)
worker.logs <- list.files(file.path(run.dir, "logs"),
                          pattern = "[.]log$", full.names = TRUE)
worker.problem.lines <- character()
if (length(worker.logs)) {
    for (lf in worker.logs) {
        txt <- readLines(lf, warn = FALSE)
        hits <- grep("Error|Killed|memory|timeout|nonfinite|Warning|failed",
                     txt, value = TRUE, ignore.case = TRUE)
        if (length(hits)) {
            worker.problem.lines <- c(worker.problem.lines,
                                      paste(basename(lf), hits))
        }
    }
}

run.config <- utils::read.csv(file.path(run.dir, "run_config.csv"),
                              stringsAsFactors = FALSE)
total.tasks <- nrow(task.status)
ok.n <- sum(task.status$status == "ok", na.rm = TRUE)
stopped.n <- sum(task.status$status == "stopped_by_user", na.rm = TRUE)
not.started.n <- sum(task.status$status == "not_started", na.rm = TRUE)
error.n <- sum(task.status$status %in% c("error", "nonfinite_fit"),
               na.rm = TRUE)
timeout.n <- sum(grepl("timeout", task.status$status, ignore.case = TRUE) |
                     grepl("timeout", task.status$error_class,
                           ignore.case = TRUE),
                 na.rm = TRUE)
ok.elapsed <- summary.df$elapsed_sec[summary.df$status == "ok" &
                                         is.finite(summary.df$elapsed_sec)]
max.elapsed <- if (length(ok.elapsed)) max(ok.elapsed) else NA_real_
median.elapsed <- if (length(ok.elapsed)) stats::median(ok.elapsed) else NA_real_

rel <- function(path) {
    sub(paste0("^", gsub("([].[^$*+?{}|()\\\\])", "\\\\\\1", reports.dir), "/?"),
        "", path)
}
fig.img <- function(path, caption) {
    sprintf(
        '<figure><img src="%s" alt="%s"><figcaption>%s</figcaption></figure>',
        html.escape(rel(path)), html.escape(caption), caption
    )
}

html <- c(
    "<!doctype html>",
    "<html><head><meta charset='utf-8'>",
    "<title>PS-LPS S3R-light Smoke/Profiling Report</title>",
    "<style>",
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;margin:32px;line-height:1.48;color:#202832;max-width:1180px}",
    "h1,h2,h3{line-height:1.15} .meta{background:#f3f6fa;border-left:4px solid #607d9c;padding:12px 16px;margin:16px 0}",
    ".warn{background:#fff6e5;border-left:4px solid #e69f00;padding:12px 16px;margin:16px 0}",
    ".good{background:#eef8f2;border-left:4px solid #009e73;padding:12px 16px;margin:16px 0}",
    "table{border-collapse:collapse;margin:12px 0 24px 0;font-size:13px} th,td{border:1px solid #d8dde6;padding:6px 8px;text-align:right} th:first-child,td:first-child{text-align:left}",
    "figure{margin:22px 0 30px 0} img{max-width:100%;height:auto;border:1px solid #e2e6ee} figcaption{font-size:13px;color:#4c5663;margin-top:8px}",
    "code{background:#f2f4f8;padding:1px 4px;border-radius:3px}",
    "</style></head><body>",
    "<h1>PS-LPS S3R-light Smoke/Profiling Report</h1>",
    sprintf("<div class='meta'><strong>Build time:</strong> %s<br><strong>Run directory:</strong> %s<br><strong>Purpose:</strong> profile the stopped S3R-light run; do not use this report for paired accuracy claims.</div>",
            html.escape(build.time), html.escape(run.dir)),
    "<div class='warn'><strong>Validity boundary.</strong> This run is not valid as paired screened-versus-full accuracy evidence because the audited manifest did not consistently match response and fold seeds within full/screened pairs. The report below uses the run only as a smoke/profiling artifact: task accounting, runtime tails, timeout/error behavior, candidate-count behavior, and instrumentation gaps.</div>",
    "<h2>Main Findings</h2>",
    sprintf("<p>The scripts and supervisor survived until manual stop: %d of %d planned tasks completed with status <code>ok</code>, %d active tasks were intentionally marked <code>stopped_by_user</code>, and %d tasks were not started. No task recorded <code>error</code>, <code>nonfinite_fit</code>, or timeout status before the stop.</p>",
            ok.n, total.tasks, stopped.n, not.started.n),
    sprintf("<p>Runtime tails were substantial. Among completed tasks, median elapsed time was %s seconds and the maximum completed elapsed time was %s seconds. The slowest completed rows came from the VALENCIA 13k subset and high-support full-search rows.</p>",
            fmt(median.elapsed), fmt(max.elapsed)),
    "<p>Memory was not continuously instrumented in the run artifacts. The report can say that logs/statuses did not show OOM, killed, timeout, or memory-error events, but it cannot reconstruct per-task peak RSS. The corrected S3R run should add explicit memory telemetry.</p>",
    "<h2>Design And Accounting</h2>",
    "<p>Each planned task is one PS-LPS fit on a frozen P7X first-batch asset, with factors for repetition, chart-dimension rule, and local-candidate search policy. Because this report is manifest-backed, rows without a status file are counted as <code>not_started</code>.</p>",
    table.html(task.counts),
    fig.img(status.plot, "Figure 1. Manifest-backed task accounting by dataset. Green rows completed successfully; orange rows were stopped intentionally after the audit; gray rows were not started."),
    "<h3>Task Accounting By Search Policy And Chart Rule</h3>",
    table.html(policy.counts),
    "<h2>Runtime Tails</h2>",
    "<p>Elapsed time is wall-clock task duration in seconds from each task status JSON or completed result summary. These timings are useful for sizing the corrected seed-matched S3R run even though accuracy deltas from this run are not valid.</p>",
    if (has.runtime) fig.img(runtime.plot, "Figure 2. Completed task runtimes by search policy and chart-dimension rule. The y-axis is logarithmic because full-search and VALENCIA rows create long runtime tails.") else "",
    if (has.dataset.runtime) fig.img(dataset.runtime.plot, "Figure 3. Median completed runtime by dataset and search policy. Lines connect the median full and screened runtime for each dataset when both are available.") else "",
    if (has.tail) fig.img(tail.plot, "Figure 4. Top 20 completed runtime tails. The largest completed rows are useful for timeout planning in the corrected S3R run.") else "",
    "<h3>Top Runtime Tail Rows</h3>",
    table.html(runtime.tail, digits = 4, max.rows = 25),
    "<h2>Timeouts, Stops, And Script Survival</h2>",
    sprintf("<p>Timeout count detected from status/error fields: <strong>%d</strong>. Worker-level error/nonfinite count: <strong>%d</strong>. Manual stop count: <strong>%d</strong>.</p>",
            timeout.n, error.n, stopped.n),
    sprintf("<p>The Python supervisor log contains %d timeout lines and %d kill/memory/OOM-like lines. Worker logs were quiet except for the intentional stopped status updates. This supports the narrow conclusion that the worker/supervisor design survived normal completed rows until manual stop.</p>",
            length(timeout.lines), length(kill.lines)),
    "<h2>Candidate And Phase Timing Diagnostics</h2>",
    "<p>The completed result RDS files contain local-candidate counts and per-fit timing telemetry. Candidate counts distinguish the exact full support search from screened search, while phase timings help identify where future profiling should focus. These diagnostics are descriptive only because the run was stopped and seed pairing was flawed.</p>",
    "<h3>Runtime Summary By Dataset, Policy, And Chart Rule</h3>",
    table.html(runtime.summary, digits = 4, max.rows = 40),
    "<h3>PS-LPS Phase Timing Summary</h3>",
    if (nrow(timing.phase.summary)) table.html(timing.phase.summary, digits = 4) else "<p>No timing phase rows were available.</p>",
    "<h2>Memory Diagnostics</h2>",
    "<p>The run did not record per-task maximum RSS, peak system memory, swap pressure, or sampled memory over time. The only artifact-backed memory statement is negative evidence: no status/log entries indicated OOM, killed workers, jetsam, or timeout before manual stop. The corrected S3R run should add either <code>/usr/bin/time -l</code> around worker tasks or a supervisor-side periodic <code>ps</code> sampler that records PID, RSS, CPU, task id, and timestamp.</p>",
    "<h2>What This Smoke Run Can Still Be Used For</h2>",
    "<ul>",
    "<li>Estimating runtime tails and choosing a conservative timeout for the corrected S3R-light run.</li>",
    "<li>Confirming that one-task workers, status JSONs, result RDS outputs, and the Python supervisor can process a large fraction of the manifest without ordinary numerical failures.</li>",
    "<li>Identifying that VALENCIA-derived rows are a runtime stressor and should be represented in timeout planning.</li>",
    "<li>Identifying missing instrumentation: manifest-backed pair accounting and memory telemetry are required before a larger S3R-expanded run.</li>",
    "</ul>",
    "<h2>What This Smoke Run Must Not Be Used For</h2>",
    "<ul>",
    "<li>Do not use full-versus-screened Truth RMSE deltas from this run as paired support-search evidence.</li>",
    "<li>Do not decide the screened-search default from this run.</li>",
    "<li>Do not infer memory safety beyond the absence of logged OOM/killed events.</li>",
    "</ul>",
    "<h2>Reproducibility And Linked Assets</h2>",
    sprintf("<p>Generated tables are in <code>%s</code>. Figures are in <code>%s</code>.</p>",
            html.escape(tables.dir), html.escape(figures.dir)),
    "<ul>",
    sprintf("<li><code>%s</code></li>", html.escape(file.path(tables.dir, "s3r_smoke_manifest_backed_status.csv"))),
    sprintf("<li><code>%s</code></li>", html.escape(file.path(tables.dir, "s3r_smoke_completed_task_summary.csv"))),
    sprintf("<li><code>%s</code></li>", html.escape(file.path(tables.dir, "s3r_smoke_runtime_summary_by_dataset_policy.csv"))),
    sprintf("<li><code>%s</code></li>", html.escape(file.path(tables.dir, "s3r_smoke_runtime_tail_top25.csv"))),
    sprintf("<li><code>%s</code></li>", html.escape(file.path(tables.dir, "s3r_smoke_phase_timing_summary.csv"))),
    "</ul>",
    "<p>Relevant audit context:</p>",
    "<ul>",
    "<li><code>/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_2026-06-07.md</code></li>",
    "<li><code>/Users/pgajer/current_projects/geosmooth/split_handoffs/p7x_s3r_audit_response_2026-06-07.md</code></li>",
    "<li><code>/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_20260607_001/STOPPED_PROFILING_ONLY_2026-06-07.md</code></li>",
    "</ul>",
    "</body></html>"
)

report.path <- file.path(reports.dir, "ps_lps_s3r_light_smoke_profiling_report.html")
writeLines(html, report.path)
cat("Wrote S3R smoke/profiling report\n")
cat("Report: ", report.path, "\n", sep = "")
cat("Completed ok: ", ok.n, " / ", total.tasks, "\n", sep = "")
cat("Stopped by user: ", stopped.n, "\n", sep = "")
cat("Not started: ", not.started.n, "\n", sep = "")
cat("Timeouts detected: ", timeout.n, "\n", sep = "")
