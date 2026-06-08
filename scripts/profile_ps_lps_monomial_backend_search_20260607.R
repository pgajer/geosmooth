#!/usr/bin/env Rscript

repo.dir <- normalizePath("/Users/pgajer/current_projects/geosmooth",
                          mustWork = TRUE)
run.dir <- file.path(
    repo.dir,
    "split_handoffs",
    "lps_ps_lps_backend_p7x_20260606_001"
)
out.dir <- file.path(
    repo.dir,
    "split_handoffs",
    "ps_lps_monomial_backend_profile_2026-06-07"
)
table.dir <- file.path(out.dir, "tables")
prof.dir <- file.path(out.dir, "profiles")
dir.create(table.dir, recursive = TRUE, showWarnings = FALSE)
dir.create(prof.dir, recursive = TRUE, showWarnings = FALSE)

need <- c("pkgload")
missing <- need[!vapply(need, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
    stop("Missing required packages: ", paste(missing, collapse = ", "),
         call. = FALSE)
}
pkgload::load_all(repo.dir, quiet = TRUE)

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

html.escape <- function(x) {
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    gsub(">", "&gt;", x, fixed = TRUE)
}

fmt <- function(x, digits = 5) {
    ifelse(is.na(x), "NA",
           ifelse(is.finite(x), formatC(x, format = "fg", digits = digits),
                  as.character(x)))
}

table.html <- function(df, digits = 5) {
    dff <- df
    for (nm in names(dff)) {
        if (is.numeric(dff[[nm]])) dff[[nm]] <- fmt(dff[[nm]], digits)
    }
    header <- paste0("<tr>", paste0("<th>", html.escape(names(dff)), "</th>",
                                   collapse = ""), "</tr>")
    body <- apply(dff, 1L, function(row) {
        paste0("<tr>", paste0("<td>", html.escape(row), "</td>",
                              collapse = ""), "</tr>")
    })
    paste0("<table>", header, paste(body, collapse = "\n"), "</table>")
}

parse.integer.grid <- function(x) {
    x <- as.character(x[[1L]])
    if (grepl(":", x, fixed = TRUE)) {
        parts <- as.integer(strsplit(x, ":", fixed = TRUE)[[1L]])
        return(seq(parts[[1L]], parts[[2L]]))
    }
    as.integer(strsplit(x, ";", fixed = TRUE)[[1L]])
}

parse.numeric.grid <- function(x) {
    x <- as.character(x[[1L]])
    as.numeric(strsplit(x, ";", fixed = TRUE)[[1L]])
}

safe.id <- function(x) gsub("[^A-Za-z0-9_]+", "_", x)

time.block <- function(expr) {
    gc()
    start <- proc.time()
    value <- force(expr)
    elapsed <- unname((proc.time() - start)[["elapsed"]])
    list(value = value, elapsed = elapsed)
}

profile.task <- function(task.row) {
    asset <- readRDS(task.row$asset_path[[1L]])
    support.grid <- parse.integer.grid(task.row$support_grid[[1L]])
    degree.grid <- parse.integer.grid(task.row$degree_grid[[1L]])
    kernel.grid <- strsplit(task.row$kernel_grid[[1L]], ";",
                            fixed = TRUE)[[1L]]
    lambda.sync.grid <- parse.numeric.grid(task.row$lambda_sync_grid[[1L]])
    ridge.multiplier.grid <- parse.numeric.grid(
        task.row$ridge_multiplier_grid[[1L]]
    )
    ridge.condition.max <- parse.numeric.grid(
        task.row$ridge_condition_max[[1L]]
    )[[1L]]
    design.drop.tol <- as.numeric(task.row$design_drop_tol[[1L]])

    prof.path <- file.path(
        prof.dir,
        paste0(safe.id(task.row$task_id[[1L]]), "_Rprof.out")
    )
    Rprof(prof.path, interval = 0.01)
    timed <- time.block(fit.ps.lps(
        X = asset$X,
        y = asset$y,
        foldid = asset$foldid,
        support.grid = support.grid,
        degree.grid = degree.grid,
        kernel.grid = kernel.grid,
        chart.dim = task.row$chart_dim_rule[[1L]],
        auto.chart.support.metric = "both",
        auto.chart.selection.metric = "operator",
        lambda.sync.grid = lambda.sync.grid,
        lambda.sync.search = task.row$lambda_sync_search[[1L]],
        lambda.ridge = 0,
        design.basis = task.row$design_basis[[1L]],
        design.drop.tol = design.drop.tol,
        ridge.multiplier.grid = ridge.multiplier.grid,
        ridge.condition.max = ridge.condition.max
    ))
    Rprof(NULL)
    fit <- timed$value

    prof <- utils::summaryRprof(prof.path)
    by.total <- as.data.frame(prof$by.total)
    by.total$function_name <- row.names(by.total)
    by.total <- by.total[, c("function_name",
                             setdiff(names(by.total), "function_name"))]
    prof.csv <- file.path(
        table.dir,
        paste0(safe.id(task.row$task_id[[1L]]), "_Rprof_by_total.csv")
    )
    utils::write.csv(head(by.total, 60L), prof.csv, row.names = FALSE)

    lambda.table <- fit$lambda.cv.table %||% fit$cv.table
    candidate.table <- fit$local.candidate.table %||% data.frame()
    if (nrow(candidate.table)) {
        candidate.csv <- file.path(
            table.dir,
            paste0(safe.id(task.row$task_id[[1L]]),
                   "_local_candidate_timing.csv")
        )
        utils::write.csv(candidate.table, candidate.csv, row.names = FALSE)
    } else {
        candidate.csv <- NA_character_
    }
    telemetry <- fit$lambda.sync.search.telemetry %||% data.frame()
    solve.timings <- fit$solve.phase.timings %||% list()
    local.grid.timings <- fit$ps.lps.local.grid.timing %||% list()
    timing.table <- data.frame(
        task_id = task.row$task_id[[1L]],
        phase = names(solve.timings),
        elapsed_sec = as.numeric(unlist(solve.timings, use.names = FALSE)),
        stringsAsFactors = FALSE
    )
    timing.csv <- file.path(
        table.dir,
        paste0(safe.id(task.row$task_id[[1L]]), "_solve_phase_timings.csv")
    )
    utils::write.csv(timing.table, timing.csv, row.names = FALSE)

    data.frame(
        task_id = task.row$task_id[[1L]],
        dataset_id = task.row$dataset_id[[1L]],
        chart_dim_rule = task.row$chart_dim_rule[[1L]],
        n = nrow(asset$X),
        p = ncol(asset$X),
        support_grid = task.row$support_grid[[1L]],
        n_support_values = length(support.grid),
        n_local_candidates_planned =
            length(support.grid) * length(degree.grid) * length(kernel.grid),
        n_local_candidates_evaluated = if (nrow(candidate.table)) {
            sum(candidate.table$local.candidate.status == "evaluated",
                na.rm = TRUE)
        } else {
            1L
        },
        local_grid_total_elapsed_sec =
            as.numeric(local.grid.timings$total.elapsed.sec %||% NA),
        local_grid_screening_sec =
            as.numeric(local.grid.timings$phase_screening_sec %||% NA),
        local_grid_candidate_loop_sec =
            as.numeric(local.grid.timings$phase_candidate_loop_sec %||% NA),
        n_lambda_rows = nrow(lambda.table),
        n_unique_lambda = length(unique(lambda.table$lambda.sync)),
        lambda_search_stages = if (nrow(telemetry)) {
            paste(unique(telemetry$stage), collapse = ";")
        } else {
            NA_character_
        },
        selected_support_size = fit$selected$support.size[[1L]],
        selected_lambda_sync = fit$selected$lambda.sync[[1L]],
        selected_cv_rmse_observed = fit$selected$cv.rmse.observed[[1L]],
        elapsed_sec = timed$elapsed,
        cache_backend = fit$cache.backend %||% NA_character_,
        phase_component_cache_sec =
            as.numeric(solve.timings[["phase_component_cache_sec"]] %||% NA),
        phase_component_combine_sec =
            as.numeric(solve.timings[["phase_component_combine_sec"]] %||% NA),
        phase_ridge_normal_sec =
            as.numeric(solve.timings[["phase_ridge_normal_sec"]] %||% NA),
        phase_solve_sec =
            as.numeric(solve.timings[["phase_solve_sec"]] %||% NA),
        phase_fitted_sec =
            as.numeric(solve.timings[["phase_fitted_sec"]] %||% NA),
        rprof_top_csv = prof.csv,
        solve_phase_csv = timing.csv,
        local_candidate_timing_csv = candidate.csv,
        stringsAsFactors = FALSE
    )
}

task.manifest <- utils::read.csv(file.path(run.dir, "task_manifest.csv"),
                                 stringsAsFactors = FALSE)
status <- utils::read.csv(file.path(run.dir, "tables", "task_status.csv"),
                          stringsAsFactors = FALSE)
eligible <- merge(
    task.manifest,
    status[, c("task_id", "status", "elapsed_sec")],
    by = "task_id",
    all.x = TRUE,
    suffixes = c("", ".prior")
)
eligible <- eligible[
    eligible$method == "ps_lps" &
        eligible$backend_variant == "monomial_tiny_ridge" &
        eligible$status == "ok",
    ,
    drop = FALSE
]

target.ids <- c(
    "bp7x_0016__LA_D1_HC_Li_N500__auto__ps_lps__monomial_tiny_ridge",
    "bp7x_0112__SYN_PARA_LINE_N500__auto__ps_lps__monomial_tiny_ridge",
    "bp7x_0148__SYN_SIMPLEX_FACES_N600__auto__ps_lps__monomial_tiny_ridge"
)
targets <- eligible[match(target.ids, eligible$task_id), , drop = FALSE]
if (any(is.na(targets$task_id))) {
    stop("One or more target tasks are missing from the completed P7X run.",
         call. = FALSE)
}

message("Profiling ", nrow(targets), " PS-LPS monomial backend tasks.")
summary.rows <- lapply(seq_len(nrow(targets)), function(ii) {
    message("Profiling task: ", targets$task_id[[ii]])
    profile.task(targets[ii, , drop = FALSE])
})
summary.table <- do.call(rbind, summary.rows)
summary.csv <- file.path(table.dir, "ps_lps_monomial_profile_summary.csv")
utils::write.csv(summary.table, summary.csv, row.names = FALSE)

html <- paste0(
    "<!doctype html><html><head><meta charset='utf-8'>",
    "<title>PS-LPS Monomial Backend/Search Profile</title>",
    "<style>body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;",
    "max-width:1100px;margin:32px auto;color:#222b35;line-height:1.5}",
    "table{border-collapse:collapse;width:100%;font-size:12px}",
    "th,td{border-bottom:1px solid #dfe3e8;padding:6px;text-align:left;",
    "vertical-align:top}th{background:#eef1f5}code{background:#eef1f5;",
    "padding:1px 4px;border-radius:4px}.note{background:#eef6ff;",
    "border-left:4px solid #2c7fb8;padding:12px 14px}</style></head><body>",
    "<h1>PS-LPS Monomial Backend/Search Profile</h1>",
    "<p><strong>Run directory:</strong> <code>", html.escape(out.dir),
    "</code></p>",
    "<p>This profile reruns selected completed P7X tasks using the practical ",
    "PS-LPS backend candidate <code>monomial_tiny_ridge</code>. It records ",
    "public-fit elapsed time, support-grid candidate counts, lambda-search ",
    "candidate counts, selected parameters, solver phase timings, and Rprof ",
    "function-level profiles.</p>",
    "<div class='note'>This is an immediate profiling pass on one fast case and ",
    "one medium case. It is intended to identify likely optimization targets ",
    "before profiling hour-scale high-dimensional tasks.</div>",
    "<h2>Profile Summary</h2>",
    table.html(summary.table),
    "<h2>Linked Tables</h2><ul>",
    "<li><a href='tables/ps_lps_monomial_profile_summary.csv'>summary CSV</a></li>",
    paste0("<li><a href='", html.escape(file.path(
               "tables",
               basename(summary.table$rprof_top_csv)
           )),
           "'>Rprof top functions: ", html.escape(summary.table$dataset_id),
           " / ", html.escape(summary.table$chart_dim_rule), "</a></li>",
           collapse = ""),
    paste0("<li><a href='", html.escape(file.path(
               "tables",
               basename(summary.table$solve_phase_csv)
           )),
           "'>solve phase timings: ", html.escape(summary.table$dataset_id),
           " / ", html.escape(summary.table$chart_dim_rule), "</a></li>",
           collapse = ""),
    paste0("<li><a href='", html.escape(file.path(
               "tables",
               basename(summary.table$local_candidate_timing_csv)
           )),
           "'>local candidate timing: ", html.escape(summary.table$dataset_id),
           " / ", html.escape(summary.table$chart_dim_rule), "</a></li>",
           collapse = ""),
    "</ul>",
    "</body></html>"
)
html.path <- file.path(out.dir, "ps_lps_monomial_backend_search_profile.html")
writeLines(html, html.path, useBytes = TRUE)

cat("Summary CSV:", summary.csv, "\n")
cat("HTML profile:", html.path, "\n")
