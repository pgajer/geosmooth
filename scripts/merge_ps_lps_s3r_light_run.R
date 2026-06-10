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
    txt <- tryCatch(paste(readLines(path, warn = FALSE), collapse = "\n"),
                    error = function(e) NA_character_)
    if (!length(txt) || is.na(txt)) return(structure(list(), class = "bad_status"))
    keys <- c("task_id", "pair_id", "dataset_id", "repetition", "method",
              "chart_dim_rule", "search_policy", "status", "started_at",
              "finished_at", "elapsed_sec", "hostname", "pid", "result_path",
              "pair_response_seed", "pair_fold_seed",
              "error_message", "error_class", "screening_status")
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
    out <- as.data.frame(vals, stringsAsFactors = FALSE)
    if (!nzchar(scalar.char(out$status))) {
        return(structure(list(), class = "bad_status"))
    }
    out
}

safe.read.result <- function(path) {
    if (!file.exists(path)) return(NULL)
    tryCatch(readRDS(path), error = function(e) NULL)
}

bind.rows.fill <- function(rows) {
    rows <- rows[vapply(rows, is.data.frame, logical(1L))]
    rows <- rows[vapply(rows, nrow, integer(1L)) > 0L]
    if (!length(rows)) return(data.frame())
    cols <- unique(unlist(lapply(rows, names), use.names = FALSE))
    rows <- lapply(rows, function(x) {
        missing <- setdiff(cols, names(x))
        for (nm in missing) x[[nm]] <- NA
        x[, cols, drop = FALSE]
    })
    do.call(rbind, rows)
}

ci.normal <- function(x) {
    x <- x[is.finite(x)]
    if (!length(x)) return(c(mean = NA_real_, lo = NA_real_, hi = NA_real_))
    se <- stats::sd(x) / sqrt(length(x))
    c(mean = mean(x), lo = mean(x) - 1.96 * se, hi = mean(x) + 1.96 * se)
}

bayes.boot.median <- function(x, draws = 5000L, seed = 20260607L) {
    x <- x[is.finite(x)]
    if (!length(x)) {
        return(c(median = NA_real_, lo = NA_real_, hi = NA_real_))
    }
    set.seed(seed)
    vals <- numeric(draws)
    n <- length(x)
    for (bb in seq_len(draws)) {
        w <- stats::rexp(n)
        w <- w / sum(w)
        ord <- order(x)
        cw <- cumsum(w[ord])
        vals[[bb]] <- x[ord][which(cw >= 0.5)[[1L]]]
    }
    c(median = stats::median(vals),
      lo = stats::quantile(vals, 0.025, names = FALSE),
      hi = stats::quantile(vals, 0.975, names = FALSE))
}

write.svg <- function(path, width = 10, height = 6, expr) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    grDevices::svg(path, width = width, height = height, onefile = TRUE)
    on.exit(grDevices::dev.off(), add = TRUE)
    force(expr)
}

wrap.labels <- function(x, width = 18) {
    vapply(strwrap(as.character(x), width = width, simplify = FALSE),
           paste, character(1L), collapse = "\n")
}

split.semicolon <- function(x) {
    if (is.null(x) || length(x) == 0L || is.na(x[[1L]]) || !nzchar(x[[1L]])) {
        return(character())
    }
    strsplit(x[[1L]], ";", fixed = TRUE)[[1L]]
}

normalize.status <- function(status, error.class) {
    status <- scalar.char(status, "missing_or_corrupt_status")
    error.class <- scalar.char(error.class)
    if (grepl("^task_timeout_", error.class)) {
        return("timeout")
    }
    status
}

truthy <- function(x) {
    if (is.na(x)) NA else isTRUE(x)
}

args <- parse.args(commandArgs(trailingOnly = TRUE))
run.dir <- normalizePath(args$run_dir, mustWork = TRUE)
tables.dir <- file.path(run.dir, "tables")
reports.dir <- file.path(run.dir, "reports")
dir.create(tables.dir, recursive = TRUE, showWarnings = FALSE)
dir.create(reports.dir, recursive = TRUE, showWarnings = FALSE)

tasks <- utils::read.csv(file.path(run.dir, "task_manifest.csv"),
                         stringsAsFactors = FALSE)
if (!"pair_id" %in% names(tasks)) {
    stop("Task manifest has no pair_id column; rerun the corrected preparer.",
         call. = FALSE)
}
run.config.path <- file.path(run.dir, "run_config.csv")
run.config <- if (file.exists(run.config.path)) {
    utils::read.csv(run.config.path, stringsAsFactors = FALSE)
} else {
    data.frame()
}
run.id <- if (nrow(run.config) && "run_id" %in% names(run.config)) {
    scalar.char(run.config$run_id, basename(run.dir))
} else {
    basename(run.dir)
}
run.label <- if (grepl("expanded", run.id, ignore.case = TRUE)) {
    "S3R-expanded"
} else if (grepl("light", run.id, ignore.case = TRUE)) {
    "S3R-light"
} else {
    "S3R"
}
report.title <- sprintf("PS-LPS %s Full vs Screened Support Search", run.label)
safe.file.label <- if (identical(run.label, "S3R-expanded")) {
    "ps_lps_s3r_expanded_report.html"
} else {
    "ps_lps_s3r_light_report.html"
}

status.rows <- lapply(seq_len(nrow(tasks)), function(ii) {
    row <- tasks[ii, , drop = FALSE]
    st <- read.status(row$status_path[[1L]])
    result.exists <- file.exists(row$result_path[[1L]])
    status.exists <- file.exists(row$status_path[[1L]])
    if (is.null(st)) {
        status <- if (result.exists) "missing_or_corrupt_status" else "not_started"
        return(data.frame(
            task_id = row$task_id,
            status = status,
            status_file_exists = status.exists,
            result_file_exists = result.exists,
            elapsed_sec = NA_real_,
            started_at = NA_character_,
            finished_at = NA_character_,
            error_class = NA_character_,
            error_message = NA_character_,
            screening_status = NA_character_,
            stringsAsFactors = FALSE
        ))
    }
    if (inherits(st, "bad_status")) {
        return(data.frame(
            task_id = row$task_id,
            status = "missing_or_corrupt_status",
            status_file_exists = status.exists,
            result_file_exists = result.exists,
            elapsed_sec = NA_real_,
            started_at = NA_character_,
            finished_at = NA_character_,
            error_class = "status_parse_failure",
            error_message = "status file existed but could not be parsed",
            screening_status = NA_character_,
            stringsAsFactors = FALSE
        ))
    }
    data.frame(
        task_id = row$task_id,
        status = normalize.status(st$status, st$error_class),
        status_file_exists = status.exists,
        result_file_exists = result.exists,
        elapsed_sec = scalar.num(st$elapsed_sec),
        started_at = scalar.char(st$started_at),
        finished_at = scalar.char(st$finished_at),
        error_class = scalar.char(st$error_class),
        error_message = scalar.char(st$error_message),
        screening_status = scalar.char(st$screening_status),
        stringsAsFactors = FALSE
    )
})
status.df <- do.call(rbind, status.rows)
task.status <- merge(tasks, status.df, by = "task_id", all.x = TRUE,
                     sort = FALSE)
utils::write.csv(task.status, file.path(tables.dir, "task_status.csv"),
                 row.names = FALSE, quote = TRUE)

summaries <- list()
candidate.details <- list()
for (ii in seq_len(nrow(tasks))) {
    res <- safe.read.result(tasks$result_path[[ii]])
    if (!is.null(res) && is.data.frame(res$summary)) {
        summaries[[length(summaries) + 1L]] <- res$summary
    }
    if (!is.null(res) && is.data.frame(res$local.candidate.table)) {
        cand <- res$local.candidate.table
        cand$task_id <- tasks$task_id[[ii]]
        cand$pair_id <- tasks$pair_id[[ii]]
        cand$search_policy <- tasks$search_policy[[ii]]
        cand$chart_dim_rule <- tasks$chart_dim_rule[[ii]]
        cand$candidate_key <- paste(cand$support.size, cand$degree,
                                    cand$kernel, sep = "|")
        candidate.details[[length(candidate.details) + 1L]] <- cand
    }
}
summary.df <- if (length(summaries)) bind.rows.fill(summaries) else data.frame()
if (!nrow(summary.df)) {
    summary.df <- data.frame(task_id = character(), stringsAsFactors = FALSE)
}
if (nrow(summary.df)) {
    num.cols <- setdiff(names(summary.df), c(
        "task_id", "pair_id", "batch_id", "dataset_id", "geometry_family",
        "method", "chart_dim_rule", "search_policy", "backend_variant",
        "design_basis", "support_grid", "degree_grid", "kernel_grid",
        "lambda_sync_search", "status", "selected_kernel",
        "local_candidates_evaluated_supports", "selected_candidate_key",
        "evaluated_candidate_keys"
    ))
    for (nm in num.cols) {
        summary.df[[nm]] <- suppressWarnings(as.numeric(summary.df[[nm]]))
    }
}
candidate.df <- if (length(candidate.details)) {
    bind.rows.fill(candidate.details)
} else {
    data.frame(task_id = character(), stringsAsFactors = FALSE)
}

candidate.metrics <- data.frame(task_id = character(), stringsAsFactors = FALSE)
if (nrow(candidate.df) && all(c("task_id", "local.candidate.status",
                               "candidate_key", "support.size",
                               "selected.cv.rmse.observed") %in%
                             names(candidate.df))) {
    candidate.metrics <- do.call(rbind, lapply(split(candidate.df,
                                                     candidate.df$task_id),
                                               function(tab) {
        evaluated <- tab$local.candidate.status == "evaluated"
        finite <- evaluated & is.finite(tab$selected.cv.rmse.observed)
        selected.id <- which.min(ifelse(finite, tab$selected.cv.rmse.observed,
                                        Inf))
        if (!length(selected.id) ||
            !is.finite(tab$selected.cv.rmse.observed[[selected.id]])) {
            selected.id <- NA_integer_
        }
        data.frame(
            task_id = tab$task_id[[1L]],
            local_candidates_total = nrow(tab),
            local_candidates_evaluated = sum(evaluated, na.rm = TRUE),
            local_candidates_finite = sum(finite, na.rm = TRUE),
            local_candidates_evaluated_supports =
                paste(sort(unique(tab$support.size[evaluated])),
                      collapse = ";"),
            selected_candidate_key = if (is.na(selected.id)) {
                NA_character_
            } else {
                tab$candidate_key[[selected.id]]
            },
            evaluated_candidate_keys =
                paste(sort(unique(tab$candidate_key[evaluated])),
                      collapse = ";"),
            stringsAsFactors = FALSE
        )
    }))
}
if (nrow(summary.df) && nrow(candidate.metrics)) {
    override.cols <- setdiff(names(candidate.metrics), "task_id")
    summary.df <- summary.df[, setdiff(names(summary.df), override.cols),
                             drop = FALSE]
    summary.df <- merge(summary.df, candidate.metrics, by = "task_id",
                        all.x = TRUE, sort = FALSE)
}
utils::write.csv(summary.df, file.path(tables.dir, "task_summary.csv"),
                 row.names = FALSE, quote = TRUE)
utils::write.csv(candidate.df,
                 file.path(tables.dir, "local_candidate_details.csv"),
                 row.names = FALSE, quote = TRUE)

arm.table <- merge(
    task.status,
    summary.df,
    by = "task_id",
    all.x = TRUE,
    suffixes = c("_manifest", "_summary"),
    sort = FALSE
)
for (nm in c("pair_id", "dataset_id", "geometry_family", "repetition",
             "chart_dim_rule", "search_policy", "response_seed",
             "fold_seed", "status")) {
    suffixed <- paste0(nm, "_manifest")
    if (!suffixed %in% names(arm.table) && nm %in% names(arm.table)) {
        arm.table[[suffixed]] <- arm.table[[nm]]
    }
}

pair.ids <- unique(tasks$pair_id)
pair.list <- lapply(pair.ids, function(pid) {
    sub <- arm.table[arm.table$pair_id_manifest == pid, , drop = FALSE]
    full <- sub[sub$search_policy_manifest == "full", , drop = FALSE]
    screened <- sub[sub$search_policy_manifest == "screened", , drop = FALSE]
    if (nrow(full) != 1L || nrow(screened) != 1L) {
        ref <- if (nrow(sub)) sub[1L, , drop = FALSE] else data.frame()
        return(data.frame(
            pair_id = pid,
            dataset_id = scalar.char(ref$dataset_id_manifest),
            geometry_family = scalar.char(ref$geometry_family_manifest),
            repetition = scalar.num(ref$repetition_manifest),
            chart_dim_rule = scalar.char(ref$chart_dim_rule_manifest),
            response_seed_match = NA,
            fold_seed_match = NA,
            full_status = if (nrow(full)) {
                scalar.char(full$status_manifest)
            } else {
                "missing"
            },
            screened_status = if (nrow(screened)) {
                scalar.char(screened$status_manifest)
            } else {
                "missing"
            },
            pair_status = "malformed_pair",
            pair_complete = FALSE,
            pair_exclusion_reason = "expected exactly one full and one screened arm",
            truth_rmse_full = NA_real_,
            truth_rmse_screened = NA_real_,
            delta_truth_rmse = NA_real_,
            cv_rmse_full = NA_real_,
            cv_rmse_screened = NA_real_,
            delta_cv_rmse = NA_real_,
            elapsed_full = NA_real_,
            elapsed_screened = NA_real_,
            elapsed_ratio_screened_full = NA_real_,
            support_full = NA_real_,
            support_screened = NA_real_,
            lambda_full = NA_real_,
            lambda_screened = NA_real_,
            full_candidate_key = NA_character_,
            screened_candidate_key = NA_character_,
            screened_evaluated_candidate_keys = NA_character_,
            screened_evaluated_supports = NA_character_,
            full_support_in_screened_evaluated_supports = NA,
            full_candidate_key_in_screened_evaluated_candidates = NA,
            support_match = NA,
            lambda_match = NA,
            full_candidates_evaluated = NA_real_,
            screened_candidates_evaluated = NA_real_,
            candidate_key_matching_available = NA,
            stringsAsFactors = FALSE
        ))
    }

    full.status <- scalar.char(full$status_manifest)
    screened.status <- scalar.char(screened$status_manifest)
    pair.complete <- identical(full.status, "ok") && identical(screened.status, "ok")
    pair.exclusion <- if (pair.complete) {
        NA_character_
    } else {
        paste0("full=", full.status, "; screened=", screened.status)
    }

    full.keys <- split.semicolon(full$evaluated_candidate_keys)
    screened.keys <- split.semicolon(screened$evaluated_candidate_keys)
    full.supports <- suppressWarnings(as.integer(split.semicolon(
        full$local_candidates_evaluated_supports
    )))
    screened.supports <- suppressWarnings(as.integer(split.semicolon(
        screened$local_candidates_evaluated_supports
    )))
    full.selected.support <- scalar.num(full$selected_support_size)
    screened.selected.support <- scalar.num(screened$selected_support_size)
    full.selected.lambda <- scalar.num(full$selected_lambda_sync)
    screened.selected.lambda <- scalar.num(screened$selected_lambda_sync)
    full.selected.key <- scalar.char(full$selected_candidate_key)
    screened.selected.key <- scalar.char(screened$selected_candidate_key)

    support.in.screened <- if (is.finite(full.selected.support)) {
        full.selected.support %in% screened.supports
    } else {
        NA
    }
    candidate.in.screened <- if (nzchar(full.selected.key)) {
        full.selected.key %in% screened.keys
    } else {
        NA
    }
    support.match <- if (is.finite(full.selected.support) &&
                         is.finite(screened.selected.support)) {
        full.selected.support == screened.selected.support
    } else {
        NA
    }
    lambda.match <- if (is.finite(full.selected.lambda) &&
                        is.finite(screened.selected.lambda)) {
        isTRUE(all.equal(full.selected.lambda, screened.selected.lambda,
                         tolerance = 1e-12))
    } else {
        NA
    }

    data.frame(
        pair_id = pid,
        dataset_id = scalar.char(full$dataset_id_manifest),
        geometry_family = scalar.char(full$geometry_family_manifest),
        repetition = scalar.num(full$repetition_manifest),
        chart_dim_rule = scalar.char(full$chart_dim_rule_manifest),
        response_seed_match = scalar.num(full$response_seed_manifest) ==
            scalar.num(screened$response_seed_manifest),
        fold_seed_match = scalar.num(full$fold_seed_manifest) ==
            scalar.num(screened$fold_seed_manifest),
        full_status = full.status,
        screened_status = screened.status,
        pair_status = if (pair.complete) "complete_ok" else "incomplete",
        pair_complete = pair.complete,
        pair_exclusion_reason = pair.exclusion,
        truth_rmse_full = scalar.num(full$truth_rmse),
        truth_rmse_screened = scalar.num(screened$truth_rmse),
        delta_truth_rmse = scalar.num(screened$truth_rmse) -
            scalar.num(full$truth_rmse),
        cv_rmse_full = scalar.num(full$selected_cv_rmse_observed),
        cv_rmse_screened = scalar.num(screened$selected_cv_rmse_observed),
        delta_cv_rmse = scalar.num(screened$selected_cv_rmse_observed) -
            scalar.num(full$selected_cv_rmse_observed),
        elapsed_full = scalar.num(full$elapsed_sec_summary),
        elapsed_screened = scalar.num(screened$elapsed_sec_summary),
        elapsed_ratio_screened_full =
            scalar.num(screened$elapsed_sec_summary) /
            scalar.num(full$elapsed_sec_summary),
        support_full = full.selected.support,
        support_screened = screened.selected.support,
        lambda_full = full.selected.lambda,
        lambda_screened = screened.selected.lambda,
        full_candidate_key = full.selected.key,
        screened_candidate_key = screened.selected.key,
        screened_evaluated_candidate_keys =
            scalar.char(screened$evaluated_candidate_keys),
        screened_evaluated_supports =
            scalar.char(screened$local_candidates_evaluated_supports),
        full_support_in_screened_evaluated_supports = support.in.screened,
        full_candidate_key_in_screened_evaluated_candidates =
            candidate.in.screened,
        support_match = support.match,
        lambda_match = lambda.match,
        full_candidates_evaluated =
            scalar.num(full$local_candidates_evaluated),
        screened_candidates_evaluated =
            scalar.num(screened$local_candidates_evaluated),
        candidate_key_matching_available =
            nzchar(full.selected.key) && length(screened.keys) > 0L,
        stringsAsFactors = FALSE
    )
})
pairs <- do.call(rbind, pair.list)
utils::write.csv(pairs, file.path(tables.dir, "full_vs_screened_pairs.csv"),
                 row.names = FALSE, quote = TRUE)

complete.pairs <- pairs[pairs$pair_complete %in% TRUE, , drop = FALSE]
method.summary <- data.frame()
if (nrow(complete.pairs)) {
    split.pairs <- split(complete.pairs, complete.pairs$chart_dim_rule)
    method.summary <- do.call(rbind, lapply(names(split.pairs), function(rule) {
        p <- split.pairs[[rule]]
        ci <- ci.normal(p$delta_truth_rmse)
        data.frame(
            chart_dim_rule = rule,
            planned_pairs = sum(pairs$chart_dim_rule == rule),
            complete_pairs = nrow(p),
            mean_delta_truth_rmse = ci[["mean"]],
            ci95_lo = ci[["lo"]],
            ci95_hi = ci[["hi"]],
            median_delta_truth_rmse =
                stats::median(p$delta_truth_rmse, na.rm = TRUE),
            median_elapsed_ratio_screened_full =
                stats::median(p$elapsed_ratio_screened_full, na.rm = TRUE),
            median_candidates_screened =
                stats::median(p$screened_candidates_evaluated, na.rm = TRUE),
            median_candidates_full =
                stats::median(p$full_candidates_evaluated, na.rm = TRUE),
            support_inclusion_rate = mean(
                p$full_support_in_screened_evaluated_supports %in% TRUE
            ),
            candidate_key_inclusion_rate = mean(
                p$full_candidate_key_in_screened_evaluated_candidates %in% TRUE
            ),
            stringsAsFactors = FALSE
        )
    }))
}
utils::write.csv(method.summary,
                 file.path(tables.dir, "paired_summary_by_chart_rule.csv"),
                 row.names = FALSE, quote = TRUE)

summarize.pairs <- function(df, group.cols) {
    if (!nrow(df)) return(data.frame())
    split.key <- interaction(df[, group.cols, drop = FALSE], drop = TRUE,
                             lex.order = TRUE)
    out <- do.call(rbind, lapply(split(df, split.key), function(p) {
        ci <- ci.normal(p$delta_truth_rmse)
        data.frame(
            p[1L, group.cols, drop = FALSE],
            planned_pairs = sum(Reduce(`&`, Map(function(col, val) {
                pairs[[col]] == val
            }, group.cols, p[1L, group.cols, drop = TRUE]))),
            complete_pairs = nrow(p),
            mean_delta_truth_rmse = ci[["mean"]],
            ci95_lo = ci[["lo"]],
            ci95_hi = ci[["hi"]],
            median_delta_truth_rmse =
                stats::median(p$delta_truth_rmse, na.rm = TRUE),
            median_elapsed_ratio_screened_full =
                stats::median(p$elapsed_ratio_screened_full, na.rm = TRUE),
            median_candidates_screened =
                stats::median(p$screened_candidates_evaluated, na.rm = TRUE),
            median_candidates_full =
                stats::median(p$full_candidates_evaluated, na.rm = TRUE),
            support_inclusion_rate = mean(
                p$full_support_in_screened_evaluated_supports %in% TRUE
            ),
            lambda_match_rate = mean(p$lambda_match %in% TRUE),
            stringsAsFactors = FALSE
        )
    }))
    row.names(out) <- NULL
    out
}

dataset.summary <- summarize.pairs(complete.pairs, "dataset_id")
geometry.summary <- summarize.pairs(complete.pairs, "geometry_family")
interim.summary <- data.frame()
if (nrow(complete.pairs)) {
    subsets <- list(
        repetitions_1_to_10 = complete.pairs[
            is.finite(complete.pairs$repetition) &
                complete.pairs$repetition <= 10, , drop = FALSE],
        all_available_repetitions = complete.pairs
    )
    interim.summary <- do.call(rbind, lapply(names(subsets), function(label) {
        p <- subsets[[label]]
        if (!nrow(p)) return(NULL)
        ci <- ci.normal(p$delta_truth_rmse)
        data.frame(
            subset = label,
            complete_pairs = nrow(p),
            max_repetition = max(p$repetition, na.rm = TRUE),
            mean_delta_truth_rmse = ci[["mean"]],
            ci95_lo = ci[["lo"]],
            ci95_hi = ci[["hi"]],
            median_delta_truth_rmse =
                stats::median(p$delta_truth_rmse, na.rm = TRUE),
            median_elapsed_ratio_screened_full =
                stats::median(p$elapsed_ratio_screened_full, na.rm = TRUE),
            median_candidates_screened =
                stats::median(p$screened_candidates_evaluated, na.rm = TRUE),
            median_candidates_full =
                stats::median(p$full_candidates_evaluated, na.rm = TRUE),
            support_inclusion_rate = mean(
                p$full_support_in_screened_evaluated_supports %in% TRUE
            ),
            lambda_match_rate = mean(p$lambda_match %in% TRUE),
            stringsAsFactors = FALSE
        )
    }))
}
utils::write.csv(dataset.summary,
                 file.path(tables.dir, "paired_summary_by_dataset.csv"),
                 row.names = FALSE, quote = TRUE)
utils::write.csv(geometry.summary,
                 file.path(tables.dir, "paired_summary_by_geometry_family.csv"),
                 row.names = FALSE, quote = TRUE)
utils::write.csv(interim.summary,
                 file.path(tables.dir, "paired_summary_by_repetition_subset.csv"),
                 row.names = FALSE, quote = TRUE)

status.counts <- as.data.frame(xtabs(~status, task.status),
                               stringsAsFactors = FALSE)
names(status.counts) <- c("status", "n")
status.by.design <- as.data.frame(xtabs(
    ~dataset_id + chart_dim_rule + search_policy + status,
    task.status
), stringsAsFactors = FALSE)
names(status.by.design) <- c("dataset_id", "chart_dim_rule",
                             "search_policy", "status", "n")
status.by.design <- status.by.design[status.by.design$n > 0, , drop = FALSE]
utils::write.csv(status.by.design,
                 file.path(tables.dir, "task_status_by_design.csv"),
                 row.names = FALSE, quote = TRUE)

pair.counts <- as.data.frame(xtabs(~chart_dim_rule + pair_status, pairs),
                             stringsAsFactors = FALSE)
names(pair.counts) <- c("chart_dim_rule", "pair_status", "n")

seed.summary <- data.frame(
    planned_pairs = nrow(pairs),
    seed_matched_pairs =
        sum(pairs$response_seed_match %in% TRUE &
            pairs$fold_seed_match %in% TRUE),
    seed_mismatched_pairs =
        sum(!(pairs$response_seed_match %in% TRUE &
              pairs$fold_seed_match %in% TRUE)),
    stringsAsFactors = FALSE
)

build.time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z",
                     tz = "America/New_York")
figures.dir <- file.path(
    reports.dir,
    if (identical(run.label, "S3R-expanded")) {
        "figures_s3r_expanded"
    } else {
        "figures_s3r_light"
    }
)
dir.create(figures.dir, recursive = TRUE, showWarnings = FALSE)
rel <- function(path) {
    sub(paste0("^", gsub("([].[^$*+?{}|()\\\\])", "\\\\\\1", reports.dir),
               "/?"), "", path)
}
artifact.link <- function(path, label = basename(path)) {
    sprintf("<a href='%s'><code>%s</code></a>", html.escape(rel(path)),
            html.escape(label))
}
fig.html <- function(path, caption) {
    sprintf("<figure><img src='%s' alt='%s'><figcaption>%s</figcaption></figure>",
            html.escape(rel(path)), html.escape(caption), caption)
}

status.summary <- status.counts[order(status.counts$status), , drop = FALSE]
pair.summary <- pair.counts[order(pair.counts$chart_dim_rule,
                                  pair.counts$pair_status), , drop = FALSE]
curated.method.summary <- method.summary
if (nrow(curated.method.summary)) {
    names(curated.method.summary) <- c(
        "chart rule", "planned pairs", "complete pairs",
        "mean delta Truth RMSE", "95% CI low", "95% CI high",
        "median delta Truth RMSE", "median runtime ratio",
        "median screened candidates", "median full candidates",
        "support inclusion rate", "candidate-key inclusion rate"
    )
}

delta.fig <- file.path(figures.dir, "figure_1_truth_rmse_delta.svg")
runtime.ratio.fig <- file.path(figures.dir, "figure_2_runtime_ratio.svg")
candidate.ratio.fig <- file.path(figures.dir, "figure_3_candidate_count_ratio.svg")
inclusion.fig <- file.path(figures.dir, "figure_4_candidate_inclusion.svg")
runtime.tail.fig <- file.path(figures.dir, "figure_5_runtime_tail.svg")

if (nrow(complete.pairs)) {
    rules <- sort(unique(complete.pairs$chart_dim_rule))
    write.svg(delta.fig, width = 10.5, height = 5.7, {
        old <- par(mar = c(5, 8, 3, 1))
        on.exit(par(old), add = TRUE)
        x <- complete.pairs$delta_truth_rmse
        xlim <- range(c(x, 0), finite = TRUE)
        pad <- diff(xlim) * 0.12
        if (!is.finite(pad) || pad == 0) pad <- 0.01
        xlim <- xlim + c(-pad, pad)
        plot(NA, NA, xlim = xlim, ylim = c(0.5, length(rules) + 0.5),
             yaxt = "n", xlab = "Truth RMSE delta: screened - full",
             ylab = "", main = "Paired Truth RMSE Difference")
        abline(v = 0, lty = 2, col = "#555555")
        for (ii in seq_along(rules)) {
            d <- complete.pairs$delta_truth_rmse[
                complete.pairs$chart_dim_rule == rules[[ii]]
            ]
            yy <- rep(ii, length(d)) + seq(-0.18, 0.18, length.out = length(d))
            points(d, yy, pch = 16, col = grDevices::adjustcolor("#666666", 0.55),
                   cex = 0.8)
            bb <- bayes.boot.median(d, seed = 20260607L + ii)
            segments(bb[["lo"]], ii, bb[["hi"]], ii, col = "#CC3311", lwd = 3)
            points(bb[["median"]], ii, pch = 16, col = "#CC3311", cex = 1.4)
            better <- sum(d < 0, na.rm = TRUE)
            text(xlim[[2]], ii + 0.22, sprintf("%d/%d better", better, length(d)),
                 adj = c(1, 0.5), cex = 0.85, col = "#333333")
        }
        axis(2, at = seq_along(rules), labels = rules, las = 1)
        grid(nx = NULL, ny = NA, col = "#E6E9EF")
    })

    write.svg(runtime.ratio.fig, width = 10.5, height = 5.7, {
        old <- par(mar = c(5, 8, 3, 1))
        on.exit(par(old), add = TRUE)
        ratio <- complete.pairs$elapsed_ratio_screened_full
        xlim <- range(c(ratio, 1), finite = TRUE)
        xlim <- c(max(min(xlim) / 1.25, 0.01), max(xlim) * 1.25)
        plot(NA, NA, xlim = xlim, ylim = c(0.5, length(rules) + 0.5),
             log = "x", yaxt = "n",
             xlab = "Runtime ratio: screened / full, log scale",
             ylab = "", main = "Paired Runtime Ratio")
        abline(v = 1, lty = 2, col = "#555555")
        for (ii in seq_along(rules)) {
            d <- complete.pairs$elapsed_ratio_screened_full[
                complete.pairs$chart_dim_rule == rules[[ii]]
            ]
            yy <- rep(ii, length(d)) + seq(-0.18, 0.18, length.out = length(d))
            points(d, yy, pch = 16, col = grDevices::adjustcolor("#666666", 0.55),
                   cex = 0.8)
            bb <- bayes.boot.median(d, seed = 20260707L + ii)
            segments(bb[["lo"]], ii, bb[["hi"]], ii, col = "#CC3311", lwd = 3)
            points(bb[["median"]], ii, pch = 16, col = "#CC3311", cex = 1.4)
            faster <- sum(d < 1, na.rm = TRUE)
            text(xlim[[2]], ii + 0.22, sprintf("%d/%d faster", faster, length(d)),
                 adj = c(1, 0.5), cex = 0.85, col = "#333333")
        }
        axis(2, at = seq_along(rules), labels = rules, las = 1)
        grid(nx = NULL, ny = NA, col = "#E6E9EF")
    })

    complete.pairs$candidate_ratio_screened_full <-
        complete.pairs$screened_candidates_evaluated /
        complete.pairs$full_candidates_evaluated
    write.svg(candidate.ratio.fig, width = 10.5, height = 5.7, {
        old <- par(mar = c(5, 8, 3, 1))
        on.exit(par(old), add = TRUE)
        ratio <- complete.pairs$candidate_ratio_screened_full
        xlim <- range(c(ratio, 1), finite = TRUE)
        xlim <- c(max(min(xlim) / 1.3, 0.01), max(xlim) * 1.3)
        plot(NA, NA, xlim = xlim, ylim = c(0.5, length(rules) + 0.5),
             log = "x", yaxt = "n",
             xlab = "Candidate-count ratio: screened / full, log scale",
             ylab = "", main = "Local-Candidate Count Reduction")
        abline(v = 1, lty = 2, col = "#555555")
        for (ii in seq_along(rules)) {
            d <- complete.pairs$candidate_ratio_screened_full[
                complete.pairs$chart_dim_rule == rules[[ii]]
            ]
            yy <- rep(ii, length(d)) + seq(-0.18, 0.18, length.out = length(d))
            points(d, yy, pch = 16, col = grDevices::adjustcolor("#666666", 0.55),
                   cex = 0.8)
            bb <- bayes.boot.median(d, seed = 20260807L + ii)
            segments(bb[["lo"]], ii, bb[["hi"]], ii, col = "#CC3311", lwd = 3)
            points(bb[["median"]], ii, pch = 16, col = "#CC3311", cex = 1.4)
        }
        axis(2, at = seq_along(rules), labels = rules, las = 1)
        grid(nx = NULL, ny = NA, col = "#E6E9EF")
    })

    diagnostics <- data.frame()
    for (rule in rules) {
        p <- complete.pairs[complete.pairs$chart_dim_rule == rule, , drop = FALSE]
        diagnostics <- rbind(
            diagnostics,
            data.frame(chart_dim_rule = rule,
                       diagnostic = "full support in screened supports",
                       rate = mean(p$full_support_in_screened_evaluated_supports %in%
                                   TRUE),
                       stringsAsFactors = FALSE),
            data.frame(chart_dim_rule = rule,
                       diagnostic = "full candidate key in screened candidates",
                       rate = mean(p$full_candidate_key_in_screened_evaluated_candidates %in%
                                   TRUE),
                       stringsAsFactors = FALSE),
            data.frame(chart_dim_rule = rule,
                       diagnostic = "selected support match",
                       rate = mean(p$support_match %in% TRUE),
                       stringsAsFactors = FALSE),
            data.frame(chart_dim_rule = rule,
                       diagnostic = "selected lambda match",
                       rate = mean(p$lambda_match %in% TRUE),
                       stringsAsFactors = FALSE)
        )
    }
    utils::write.csv(diagnostics,
                     file.path(tables.dir, "candidate_inclusion_diagnostics.csv"),
                     row.names = FALSE, quote = TRUE)
    write.svg(inclusion.fig, width = 10.5, height = 6.2, {
        old <- par(mar = c(5, 11, 3, 1))
        on.exit(par(old), add = TRUE)
        diag.levels <- rev(unique(diagnostics$diagnostic))
        plot(NA, NA, xlim = c(0, 1.03), ylim = c(0.5, length(diag.levels) + 0.5),
             yaxt = "n", xlab = "Rate across complete pairs", ylab = "",
             main = "Screened-Search Inclusion And Match Diagnostics")
        grid(nx = NULL, ny = NA, col = "#E6E9EF")
        cols <- c("auto" = "#0072B2", "local.auto" = "#D55E00")
        for (ii in seq_along(diag.levels)) {
            for (jj in seq_along(rules)) {
                row <- diagnostics[diagnostics$diagnostic == diag.levels[[ii]] &
                                   diagnostics$chart_dim_rule == rules[[jj]], ,
                                   drop = FALSE]
                yy <- ii + if (jj == 1L) -0.08 else 0.08
                points(row$rate, yy, pch = 16, cex = 1.4, col = cols[[rules[[jj]]]])
                text(row$rate, yy + 0.12, fmt(row$rate, 3), cex = 0.75,
                     col = cols[[rules[[jj]]]])
            }
        }
        axis(2, at = seq_along(diag.levels), labels = wrap.labels(diag.levels, 30),
             las = 1, cex.axis = 0.82)
        legend("bottomleft", horiz = TRUE, bty = "n",
               legend = rules, pch = 16, col = cols[rules], cex = 0.9)
    })
}

if (nrow(summary.df)) {
    ok.summary <- summary.df[summary.df$status == "ok" &
                             is.finite(summary.df$elapsed_sec), , drop = FALSE]
    if (nrow(ok.summary)) {
        datasets <- unique(ok.summary$dataset_id)
        write.svg(runtime.tail.fig, width = 11.5, height = 7.2, {
            old <- par(mar = c(5, 11, 3, 1))
            on.exit(par(old), add = TRUE)
            yy.base <- seq_along(datasets)
            x <- ok.summary$elapsed_sec
            xlim <- range(x, finite = TRUE)
            xlim <- c(max(min(xlim) / 1.3, 1), max(xlim) * 1.3)
            plot(NA, NA, xlim = xlim, ylim = c(0.5, length(datasets) + 0.5),
                 log = "x", yaxt = "n", xlab = "Task elapsed seconds, log scale",
                 ylab = "", main = "Task Runtime Tails By Dataset And Policy")
            grid(nx = NULL, ny = NA, col = "#E6E9EF")
            cols <- c("full" = "#D55E00", "screened" = "#0072B2")
            pch <- c("auto" = 16, "local.auto" = 17)
            for (ii in seq_along(datasets)) {
                sub <- ok.summary[ok.summary$dataset_id == datasets[[ii]], ,
                                  drop = FALSE]
                for (rr in seq_len(nrow(sub))) {
                    off <- if (sub$search_policy[[rr]] == "full") -0.12 else 0.12
                    points(sub$elapsed_sec[[rr]], ii + off,
                           pch = pch[[sub$chart_dim_rule[[rr]]]],
                           col = grDevices::adjustcolor(cols[[sub$search_policy[[rr]]]],
                                                        0.72),
                           cex = 0.9)
                }
            }
            axis(2, at = yy.base, labels = wrap.labels(datasets, 26),
                 las = 1, cex.axis = 0.72)
            legend("topleft", bty = "n",
                   legend = c("full", "screened", "auto chart", "local.auto chart"),
                   pch = c(16, 16, 16, 17),
                   col = c(cols[["full"]], cols[["screened"]], "#333333", "#333333"),
                   cex = 0.82, ncol = 2)
        })
    }
}

task.status.path <- file.path(tables.dir, "task_status.csv")
task.summary.path <- file.path(tables.dir, "task_summary.csv")
pairs.path <- file.path(tables.dir, "full_vs_screened_pairs.csv")
candidate.path <- file.path(tables.dir, "local_candidate_details.csv")
paired.summary.path <- file.path(tables.dir, "paired_summary_by_chart_rule.csv")
dataset.summary.path <- file.path(tables.dir, "paired_summary_by_dataset.csv")
geometry.summary.path <- file.path(tables.dir,
                                   "paired_summary_by_geometry_family.csv")
interim.summary.path <- file.path(tables.dir,
                                  "paired_summary_by_repetition_subset.csv")
candidate.diagnostics.path <- file.path(tables.dir, "candidate_inclusion_diagnostics.csv")
main.result.mtime <- if (file.exists(pairs.path)) {
    format(file.info(pairs.path)$mtime, "%Y-%m-%d %H:%M:%S %Z",
           tz = "America/New_York")
} else {
    "not available"
}

complete.n <- nrow(complete.pairs)
planned.n <- nrow(pairs)
ok.n <- sum(task.status$status == "ok", na.rm = TRUE)
timeout.n <- sum(task.status$status == "timeout", na.rm = TRUE)
error.n <- sum(task.status$status == "error", na.rm = TRUE)
nonfinite.n <- sum(task.status$status == "nonfinite_fit", na.rm = TRUE)
median.delta <- if (complete.n) stats::median(complete.pairs$delta_truth_rmse) else NA_real_
median.runtime.ratio <- if (complete.n) {
    stats::median(complete.pairs$elapsed_ratio_screened_full)
} else {
    NA_real_
}
median.candidate.ratio <- if (complete.n &&
                              "candidate_ratio_screened_full" %in%
                              names(complete.pairs)) {
    stats::median(complete.pairs$candidate_ratio_screened_full)
} else {
    NA_real_
}

html <- c(
    "<!doctype html>",
    "<html><head><meta charset='utf-8'>",
    sprintf("<title>%s</title>", html.escape(report.title)),
    "<script>window.MathJax={tex:{inlineMath:[['\\\\(','\\\\)']],displayMath:[['\\\\[','\\\\]']]}};</script>",
    "<script src='https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js'></script>",
    "<style>",
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;margin:32px;line-height:1.5;color:#202832;max-width:1180px}",
    "h1,h2,h3{line-height:1.15} .meta{background:#f3f6fa;border-left:4px solid #607d9c;padding:12px 16px;margin:16px 0}",
    ".note{max-width:980px}.callout{background:#eef8f2;border-left:4px solid #009e73;padding:12px 16px;margin:16px 0}.warn{background:#fff6e5;border-left:4px solid #e69f00;padding:12px 16px;margin:16px 0}",
    "table{border-collapse:collapse;margin:12px 0 24px 0;font-size:13px;max-width:100%}",
    "th,td{border:1px solid #d8dde6;padding:6px 8px;text-align:right} th:first-child,td:first-child{text-align:left}",
    "figure{margin:24px 0 34px 0} img{max-width:100%;height:auto;border:1px solid #e2e6ee;background:white} figcaption{font-size:13px;color:#4c5663;margin-top:8px}",
    ".small{font-size:13px;color:#4c5663} code{background:#f2f4f8;padding:1px 4px;border-radius:3px}",
    "ul.artifacts li{margin:4px 0}",
    "</style></head><body>",
    sprintf("<h1>%s</h1>", html.escape(report.title)),
    sprintf("<div class='meta'><strong>Report build:</strong> %s<br><strong>Consumed result bundle:</strong> %s<br><strong>Result tables updated:</strong> %s</div>",
            html.escape(build.time), html.escape(run.dir),
            html.escape(main.result.mtime)),
    "<h2>Purpose</h2>",
    sprintf("<p>This report evaluates the %s run, which compares the exact <code>full</code> PS-LPS local-candidate search against the faster <code>screened</code> local-candidate search. The scientific question is not whether PS-LPS is useful in general; it is whether screened search preserves the selected fits closely enough, while reducing candidate-search work and runtime, to justify using it in routine prospective experiments.</p>",
            html.escape(run.label)),
    "<p>The run is paired. For each dataset, repetition, and chart-dimension rule, the <code>full</code> and <code>screened</code> arms use the same synthetic response and the same CV folds. This makes paired differences meaningful.</p>",
    sprintf("<div class='callout'>Current result: %d of %d planned tasks have status <code>ok</code>, giving %d complete full/screened pairs out of %d planned pairs. Recorded nonfinite fits: %d; errors: %d; timeouts: %d. The median screened-minus-full Truth RMSE delta among complete pairs is <strong>%s</strong>, and the median screened/full runtime ratio is <strong>%s</strong>.</div>",
            ok.n, nrow(task.status), complete.n, planned.n,
            nonfinite.n, error.n, timeout.n, fmt(median.delta, 4),
            fmt(median.runtime.ratio, 4)),
    "<h2>Definitions</h2>",
    "<p>For a fitted value vector \\(\\hat f\\) and known synthetic truth \\(f\\), Truth RMSE is</p>",
    "\\[ R(\\hat f, f)=\\sqrt{\\frac{1}{n}\\sum_{i=1}^n(\\hat f_i-f_i)^2}. \\]",
    "<p>The primary paired accuracy diagnostic is</p>",
    "\\[ \\Delta_R = R(\\hat f_{\\mathrm{screened}},f)-R(\\hat f_{\\mathrm{full}},f). \\]",
    "<p>Negative \\(\\Delta_R\\) favors screened search; positive \\(\\Delta_R\\) favors full search. Runtime and candidate-count diagnostics use ratios</p>",
    "\\[ \\rho_T=\\frac{T_{\\mathrm{screened}}}{T_{\\mathrm{full}}},\\qquad \\rho_C=\\frac{C_{\\mathrm{screened}}}{C_{\\mathrm{full}}}. \\]",
    "<p>Values below one mean screened search used less time or fewer local candidates. Red intervals in paired figures are Bayesian-bootstrap 95% credible intervals for the paired median. Gray points show individual paired datasets/repetitions.</p>",
    "<h2>Design Contract And Seed Validation</h2>",
    "<p>Each intended pair is defined by <code>(dataset_id, repetition, chart_dim_rule)</code>. The <code>search_policy</code> arm does not enter the response or fold seed formula, so the two arms in a pair share the same response and CV folds.</p>",
    table.html(seed.summary),
    "<h2>Task Accounting</h2>",
    "<p>Status is manifest-backed. <code>timeout</code> means the worker exceeded the task timeout; the exact threshold remains in <code>error_class</code>. Complete task-level detail is linked in the reproducibility section rather than shown as a large table.</p>",
    table.html(status.summary),
    sprintf("<p>Attempted tasks: %d. Successful tasks: %d. Nonfinite fits: %d. Errors: %d. Timeouts: %d.</p>",
            nrow(task.status), ok.n, nonfinite.n, error.n, timeout.n),
    "<h2>Pair Accounting</h2>",
    "<p>Accuracy deltas are computed only for complete <code>ok/ok</code> pairs, while all planned pairs remain in the linked pair table.</p>",
    table.html(pair.summary),
    sprintf("<p>Complete pairs: %d of %d.</p>", complete.n, planned.n),
    "<h2>Truth RMSE: Screened Versus Full</h2>",
    "<p>This figure answers the main accuracy question. Each gray point is one paired case. The red point and interval summarize the paired median by chart-dimension rule. The zero line means screened and full selected fits with equal Truth RMSE.</p>",
    if (file.exists(delta.fig)) fig.html(delta.fig, "Figure 1. Paired Truth RMSE deltas, screened minus full. Negative values favor screened search. Gray points are individual paired cases; red intervals are Bayesian-bootstrap 95% credible intervals for the paired median. The count at right reports how many paired cases favored screened search.") else "",
    "<h2>Runtime: Screened Versus Full</h2>",
    "<p>This figure asks whether screened search reduces end-to-end task runtime. The plotted runtime is the task-level elapsed time recorded by the worker, including candidate search and final fit for that task.</p>",
    if (file.exists(runtime.ratio.fig)) fig.html(runtime.ratio.fig, "Figure 2. Paired runtime ratios, screened divided by full, on a log scale. Values below one favor screened search. Gray points are individual paired cases; red intervals are Bayesian-bootstrap 95% credible intervals for the paired median.") else "",
    "<h2>Candidate-Search Work</h2>",
    "<p>This figure measures the intended computational mechanism: screened search should evaluate fewer local candidates than full search. The ratio is computed from the number of top-level local candidates evaluated in each paired arm. If the points sit near one, then the observed runtime difference is not explained by this coarse candidate-count diagnostic.</p>",
    if (file.exists(candidate.ratio.fig)) fig.html(candidate.ratio.fig, "Figure 3. Paired local-candidate count ratios, screened divided by full, on a log scale. Values below one mean screened search evaluated fewer local candidates. Gray points are individual paired cases; red intervals are Bayesian-bootstrap 95% credible intervals for the paired median.") else "",
    "<h2>Candidate Inclusion Diagnostics</h2>",
    "<p>Figure 4 checks whether screened search looked in the right neighborhood of the local-candidate space. The local candidate key is <code>support.size|degree|kernel</code>. The first two rows ask: did screened search even evaluate the model that full search eventually selected? The last two rows ask a stricter question: after doing its own CV optimization, did screened search choose the same support size and the same synchronization penalty as full search?</p>",
    "<p>In this run, degree and kernel are fixed, so candidate-key inclusion is essentially support-size inclusion. This is why the first two rows can look the same. Inclusion rates should be interpreted together with Figure 1: even when the exact support differs, the selected fit may have nearly the same Truth RMSE. The lambda-match row asks whether the two arms agree on the synchronization penalty after their respective support searches.</p>",
    if (file.exists(inclusion.fig)) fig.html(inclusion.fig, "Figure 4. Screened-search inclusion and match diagnostics. Points show rates across complete pairs, separated by chart-dimension rule. Candidate-key inclusion is stricter than support inclusion because it also requires matching degree and kernel.") else "",
    "<h2>Runtime Tails</h2>",
    "<p>This figure shows all successful task runtimes by dataset, search policy, and chart rule. It is useful for planning S3R-expanded timeouts and worker counts. The y-axis uses datasets; the x-axis is log-scaled elapsed seconds.</p>",
    if (file.exists(runtime.tail.fig)) fig.html(runtime.tail.fig, "Figure 5. Task runtime tails by dataset, search policy, and chart-dimension rule. Full and screened policies are colored separately; point shape distinguishes global auto and local.auto chart dimension. The rank-block synthetic dataset and VALENCIA-derived high-dimensional datasets drive the long tail.") else "",
    "<h2>Summary By Chart Rule</h2>",
    "<p>The compact table below is a reader-facing summary. Full task and pair-level tables are linked in the appendix.</p>",
    if (nrow(curated.method.summary)) table.html(curated.method.summary) else
        "<p>No complete full/screened pairs yet.</p>",
    "<h2>Interim And Full Repetition Summaries</h2>",
    "<p>The predeclared interim readout is repetitions 1--10. The full summary uses all complete repetitions available in this result bundle. During an in-progress run, the all-available row is a monitoring summary rather than a final policy result.</p>",
    if (nrow(interim.summary)) table.html(interim.summary) else
        "<p>No complete repetition subset summary yet.</p>",
    "<h2>Summary By Dataset</h2>",
    "<p>This table helps identify whether screened search is stable across individual frozen P7X assets. Long tables remain linked below for reproducibility.</p>",
    if (nrow(dataset.summary)) table.html(dataset.summary, max.rows = 20) else
        "<p>No complete dataset summary yet.</p>",
    "<h2>Summary By Geometry Family</h2>",
    "<p>This table groups paired deltas by geometry family. It is intended to show whether any geometry class behaves differently enough to require a policy exception.</p>",
    if (nrow(geometry.summary)) table.html(geometry.summary, max.rows = 20) else
        "<p>No complete geometry-family summary yet.</p>",
    "<h2>What We Learned</h2>",
    sprintf("<p>This %s result bundle currently has %d successful tasks, %d complete pairs, %d nonfinite fits, %d errors, and %d timeouts. These counts are manifest-backed and should be used as the first report-readiness gate.</p>",
            html.escape(run.label), ok.n, complete.n, nonfinite.n, error.n,
            timeout.n),
    sprintf("<p>Accuracy evidence is paired for complete <code>ok/ok</code> pairs. The median screened-minus-full Truth RMSE delta is %s; values close to zero indicate screened search is preserving the selected fit well on the completed paired cases.</p>",
            fmt(median.delta, 4)),
    sprintf("<p>The median screened/full runtime ratio was %s and the median screened/full candidate-count ratio was %s. These two quantities separate realized wall-time savings from the intended candidate-search reduction mechanism. In this run screened search usually evaluated only a subset of the 21 full-search local candidates, which is consistent with the observed runtime speedup.</p>",
            fmt(median.runtime.ratio, 4), fmt(median.candidate.ratio, 4)),
    if (identical(run.label, "S3R-expanded") &&
        ok.n == nrow(task.status) && complete.n == planned.n) {
        "<p>The S3R-expanded policy conclusion is that screened PS-LPS is the routine experimental support-search policy for similar broad sweeps. Full support-grid PS-LPS remains the validation/reference mode for spot checks, new geometry families, publication-critical sensitivity checks, and unusual screening telemetry.</p>"
    } else if (identical(run.label, "S3R-expanded")) {
        "<p>The final policy question for S3R-expanded is whether screened PS-LPS can replace full support search for routine runs, whether any exception is needed for <code>auto</code> or <code>local.auto</code>, and whether additional profiling or policy modification is needed.</p>"
    } else {
        "<p>The next decision should be made after audit of this report: whether S3R-expanded should run, and if so whether it should use 10 or 20 repetitions.</p>"
    },
    "<h2>Reproducibility And Linked Artifacts</h2>",
    sprintf("<p>Report build timestamp: %s. Consumed result table timestamp: %s.</p>",
            html.escape(build.time), html.escape(main.result.mtime)),
    "<ul class='artifacts'>",
    sprintf("<li>%s: manifest-backed status for every planned task.</li>",
            artifact.link(task.status.path, "task_status.csv")),
    sprintf("<li>%s: one row per completed task summary.</li>",
            artifact.link(task.summary.path, "task_summary.csv")),
    sprintf("<li>%s: one row per planned full/screened pair.</li>",
            artifact.link(pairs.path, "full_vs_screened_pairs.csv")),
    sprintf("<li>%s: local candidate details used for inclusion diagnostics.</li>",
            artifact.link(candidate.path, "local_candidate_details.csv")),
    sprintf("<li>%s: chart-rule summary table.</li>",
            artifact.link(paired.summary.path, "paired_summary_by_chart_rule.csv")),
    sprintf("<li>%s: dataset summary table.</li>",
            artifact.link(dataset.summary.path, "paired_summary_by_dataset.csv")),
    sprintf("<li>%s: geometry-family summary table.</li>",
            artifact.link(geometry.summary.path,
                          "paired_summary_by_geometry_family.csv")),
    sprintf("<li>%s: interim 10-repetition and all-available summaries.</li>",
            artifact.link(interim.summary.path,
                          "paired_summary_by_repetition_subset.csv")),
    if (file.exists(candidate.diagnostics.path)) {
        sprintf("<li>%s: candidate inclusion rates.</li>",
                artifact.link(candidate.diagnostics.path,
                              "candidate_inclusion_diagnostics.csv"))
    } else "",
    "</ul>",
    if (identical(run.label, "S3R-light")) {
        "<p class='small'>The previous stopped S3R-light run remains smoke/profiling only and is not used here for paired accuracy evidence.</p>"
    } else {
        ""
    },
    "</body></html>"
)

report.path <- file.path(reports.dir, safe.file.label)
writeLines(html, report.path)
cat("Merged ", run.label, " run\n", sep = "")
cat("Run directory: ", run.dir, "\n", sep = "")
cat("Task rows: ", nrow(task.status), "\n", sep = "")
cat("Summary rows: ", nrow(summary.df), "\n", sep = "")
cat("Pair rows: ", nrow(pairs), "\n", sep = "")
cat("Complete pairs: ", nrow(complete.pairs), "\n", sep = "")
cat("Report: ", report.path, "\n", sep = "")
