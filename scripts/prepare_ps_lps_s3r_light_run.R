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

sanitize.id <- function(x) {
    gsub("[^A-Za-z0-9_]+", "_", x)
}

make.pair.id <- function(dataset.id, repetition, chart.rule) {
    paste(
        sanitize.id(dataset.id),
        sprintf("r%02d", as.integer(repetition)),
        gsub("\\.", "_", chart.rule),
        sep = "__"
    )
}

validate.manifest <- function(tasks, asset.manifest, expected.tasks) {
    required.cols <- c(
        "task_id", "pair_id", "dataset_id", "repetition", "chart_dim_rule",
        "search_policy", "asset_path", "source_sha256", "response_seed",
        "fold_seed"
    )
    missing.cols <- setdiff(required.cols, names(tasks))
    if (length(missing.cols)) {
        stop("Manifest is missing required columns: ",
             paste(missing.cols, collapse = ", "), call. = FALSE)
    }

    pair.split <- split(tasks, tasks$pair_id)
    arm.count <- vapply(pair.split, nrow, integer(1L))
    full.count <- vapply(pair.split, function(x) sum(x$search_policy == "full"),
                         integer(1L))
    screened.count <- vapply(pair.split, function(x) {
        sum(x$search_policy == "screened")
    }, integer(1L))
    response.seed.count <- vapply(pair.split, function(x) {
        length(unique(x$response_seed))
    }, integer(1L))
    fold.seed.count <- vapply(pair.split, function(x) {
        length(unique(x$fold_seed))
    }, integer(1L))

    asset.paths <- tasks$asset_path
    source.hashes <- tasks$source_sha256
    malformed.hashes <- is.na(source.hashes) |
        !grepl("^[0-9a-fA-F]{64}$", source.hashes)
    missing.assets <- is.na(asset.paths) | !file.exists(asset.paths)

    balance <- as.data.frame(xtabs(
        ~dataset_id + repetition + chart_dim_rule + search_policy,
        tasks
    ), stringsAsFactors = FALSE)
    names(balance) <- c(
        "dataset_id", "repetition", "chart_dim_rule", "search_policy", "n"
    )

    summary <- data.frame(
        check = c(
            "planned_task_count",
            "planned_pair_count",
            "two_arms_per_pair",
            "one_full_arm_per_pair",
            "one_screened_arm_per_pair",
            "response_seed_matched_per_pair",
            "fold_seed_matched_per_pair",
            "asset_paths_present",
            "source_hashes_malformed",
            "balanced_dataset_rep_chart_search_counts"
        ),
        observed = c(
            nrow(tasks),
            length(pair.split),
            sum(arm.count == 2L),
            sum(full.count == 1L),
            sum(screened.count == 1L),
            sum(response.seed.count == 1L),
            sum(fold.seed.count == 1L),
            sum(!missing.assets),
            sum(malformed.hashes),
            sum(balance$n == 1L)
        ),
        expected = c(
            expected.tasks,
            expected.tasks / 2L,
            length(pair.split),
            length(pair.split),
            length(pair.split),
            length(pair.split),
            length(pair.split),
            nrow(tasks),
            0L,
            nrow(balance)
        ),
        passed = c(
            nrow(tasks) == expected.tasks,
            length(pair.split) == expected.tasks / 2L,
            all(arm.count == 2L),
            all(full.count == 1L),
            all(screened.count == 1L),
            all(response.seed.count == 1L),
            all(fold.seed.count == 1L),
            all(!missing.assets),
            !any(malformed.hashes),
            all(balance$n == 1L)
        ),
        stringsAsFactors = FALSE
    )

    list(
        summary = summary,
        pair_details = data.frame(
            pair_id = names(pair.split),
            arms = arm.count,
            full_arms = full.count,
            screened_arms = screened.count,
            response_seed_values = response.seed.count,
            fold_seed_values = fold.seed.count,
            stringsAsFactors = FALSE
        ),
        balance = balance,
        pass = all(summary$passed)
    )
}

args <- parse.args(commandArgs(trailingOnly = TRUE))
repo <- normalizePath(args$repo %||% getwd(), mustWork = TRUE)
freeze.dir <- normalizePath(
    args$freeze_dir %||%
        file.path(repo, "split_handoffs",
                  "lps_local_auto_nonmanifold_first_batch_2026-06-05"),
    mustWork = TRUE
)
run.id <- args$run_id %||%
    paste0("ps_lps_s3r_light_", format(Sys.time(), "%Y%m%d_%H%M%S"))
run.label <- if (grepl("expanded", run.id, ignore.case = TRUE)) {
    "S3R-expanded"
} else if (grepl("light", run.id, ignore.case = TRUE)) {
    "S3R-light"
} else {
    "S3R"
}
n.workers <- as.integer(args$n_workers %||% "10")
if (!is.finite(n.workers) || n.workers < 1L) {
    stop("'n_workers' must be a positive integer.", call. = FALSE)
}
task.timeout.sec <- as.integer(args$task_timeout_sec %||% "7200")
if (!is.finite(task.timeout.sec) || task.timeout.sec < 1L) {
    stop("'task_timeout_sec' must be a positive integer.", call. = FALSE)
}
n.reps <- as.integer(args$n_reps %||% "3")
if (!is.finite(n.reps) || n.reps < 1L) {
    stop("'n_reps' must be a positive integer.", call. = FALSE)
}
base.seed <- as.integer(args$base_seed %||% "20260607")
if (!is.finite(base.seed)) {
    stop("'base_seed' must be an integer.", call. = FALSE)
}

run.dir <- file.path(repo, "split_handoffs", run.id)
dir.create(file.path(run.dir, "logs"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(run.dir, "status"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(run.dir, "results"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(run.dir, "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(run.dir, "reports"), recursive = TRUE, showWarnings = FALSE)

asset.manifest.path <- file.path(freeze.dir, "asset_manifest.csv")
asset.manifest <- utils::read.csv(asset.manifest.path, stringsAsFactors = FALSE)

chart.rules <- c("auto", "local.auto")
search.policies <- c("full", "screened")
screened.control <- "top.n=8;max.candidates=12;neighbor.radius=1;guard.support.quantiles=0|0.5|1"
expected.tasks <- nrow(asset.manifest) * n.reps * length(chart.rules) *
    length(search.policies)

task.list <- list()
tt <- 0L
for (ii in seq_len(nrow(asset.manifest))) {
    asset <- asset.manifest[ii, , drop = FALSE]
    for (rep.idx in seq_len(n.reps)) {
        for (chart.rule in chart.rules) {
            pair.id <- make.pair.id(asset$dataset.id[[1L]], rep.idx,
                                    chart.rule)

            dataset.seed.component <- ii * 100000L
            repetition.seed.component <- rep.idx * 1000L
            chart.seed.component <- if (identical(chart.rule, "local.auto")) {
                100L
            } else {
                0L
            }
            pair.seed.base <- base.seed + dataset.seed.component +
                repetition.seed.component + chart.seed.component
            pair.fold.seed <- pair.seed.base + 1L
            pair.response.seed <- pair.seed.base + 2L

            for (search.policy in search.policies) {
                tt <- tt + 1L
                task.id <- sprintf(
                    "s3r_%04d__%s__r%02d__%s__%s",
                    tt,
                    sanitize.id(asset$dataset.id[[1L]]),
                    rep.idx,
                    gsub("\\.", "_", chart.rule),
                    search.policy
                )
                task.list[[tt]] <- data.frame(
                    task_id = task.id,
                    pair_id = pair.id,
                    batch_id = asset$batch.id[[1L]],
                    dataset_id = asset$dataset.id[[1L]],
                    geometry_family = asset$geometry.family[[1L]],
                    n = asset$n[[1L]],
                    p = asset$p[[1L]],
                    asset_path = asset$asset.path[[1L]],
                    source_sha256 = asset$sha256[[1L]],
                    repetition = rep.idx,
                    pair_seed_base = pair.seed.base,
                    pair_fold_seed = pair.fold.seed,
                    pair_response_seed = pair.response.seed,
                    replicate_seed = pair.seed.base,
                    fold_seed = pair.fold.seed,
                    response_seed = pair.response.seed,
                    method = "ps_lps",
                    chart_dim_rule = chart.rule,
                    search_policy = search.policy,
                    backend_variant = "monomial_tiny_ridge",
                    design_basis = "monomial",
                    design_drop_tol = "1e-8",
                    ridge_multiplier_grid = "1e-8",
                    ridge_condition_max = "Inf",
                    support_grid = "15:35",
                    degree_grid = "2",
                    kernel_grid = "tricube",
                    lambda_sync_grid = "0;0.001;0.01;0.1;1;10",
                    lambda_sync_search = "guarded",
                    local_candidate_search = search.policy,
                    local_candidate_search_control =
                        if (identical(search.policy, "screened")) {
                            screened.control
                        } else {
                            NA_character_
                        },
                    result_path = file.path(run.dir, "results",
                                            paste0(task.id, ".rds")),
                    status_path = file.path(run.dir, "status",
                                            paste0(task.id, ".json")),
                    log_path = file.path(run.dir, "logs",
                                         paste0(task.id, ".log")),
                    skip_if_complete = TRUE,
                    stringsAsFactors = FALSE
                )
            }
        }
    }
}
tasks <- do.call(rbind, task.list)

qa <- validate.manifest(tasks, asset.manifest, expected.tasks)
utils::write.csv(qa$summary, file.path(run.dir, "manifest_qa_summary.csv"),
                 row.names = FALSE, quote = TRUE)
utils::write.csv(qa$pair_details, file.path(run.dir, "manifest_pair_qa.csv"),
                 row.names = FALSE, quote = TRUE)
utils::write.csv(qa$balance, file.path(run.dir, "manifest_balance_qa.csv"),
                 row.names = FALSE, quote = TRUE)
writeLines(c(
    paste0(run.label, " manifest pre-launch QA"),
    paste0("run_id: ", run.id),
    paste0("run_dir: ", run.dir),
    paste0("planned_tasks: ", nrow(tasks)),
    paste0("planned_pairs: ", length(unique(tasks$pair_id))),
    paste0("seed_matched_pairs: ",
           sum(qa$pair_details$response_seed_values == 1L &
               qa$pair_details$fold_seed_values == 1L)),
    paste0("mismatched_pairs: ",
           sum(qa$pair_details$response_seed_values != 1L |
               qa$pair_details$fold_seed_values != 1L)),
    paste0("qa_passed: ", qa$pass)
), file.path(run.dir, "PRELAUNCH_QA_SUMMARY.txt"))

if (!qa$pass) {
    stop("Manifest pre-launch QA failed. See ",
         file.path(run.dir, "manifest_qa_summary.csv"), call. = FALSE)
}

task.manifest.path <- file.path(run.dir, "task_manifest.csv")
utils::write.csv(tasks, task.manifest.path, row.names = FALSE, quote = TRUE)

run.config <- data.frame(
    run_id = run.id,
    repo = repo,
    freeze_dir = freeze.dir,
    asset_manifest_path = asset.manifest.path,
    run_dir = run.dir,
    n_workers = n.workers,
    task_timeout_sec = task.timeout.sec,
    task_count = nrow(tasks),
    repetitions = n.reps,
    base_seed = base.seed,
    purpose = paste(
        paste(run.label, "repeated full-versus-screened PS-LPS support-search"),
        "comparison over all frozen P7X first-batch assets"
    ),
    cpu_policy = sprintf("local-only; %d workers", n.workers),
    support_grid = "15:35",
    chart_dim_rules = paste(chart.rules, collapse = ";"),
    search_policies = paste(search.policies, collapse = ";"),
    backend_variant = "monomial_tiny_ridge",
    screened_control = screened.control,
    created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    stringsAsFactors = FALSE
)
utils::write.csv(run.config, file.path(run.dir, "run_config.csv"),
                 row.names = FALSE, quote = TRUE)

launcher <- file.path(run.dir, "launch_s3r_light.sh")
launcher.lines <- c(
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    sprintf("RUN_DIR=%s", shQuote(run.dir)),
    sprintf("N_WORKERS=${N_WORKERS:-%d}", n.workers),
    sprintf("TASK_TIMEOUT_SEC=${TASK_TIMEOUT_SEC:-%d}", task.timeout.sec),
    sprintf("cd %s", shQuote(repo)),
    "test -f \"${RUN_DIR}/PRELAUNCH_QA_SUMMARY.txt\"",
    "grep -q \"qa_passed: TRUE\" \"${RUN_DIR}/PRELAUNCH_QA_SUMMARY.txt\"",
    "python3 scripts/launch_ps_lps_s3r_light_run.py \\",
    "  --run_dir \"${RUN_DIR}\" \\",
    "  --workers \"${N_WORKERS}\" \\",
    "  --task_timeout_sec \"${TASK_TIMEOUT_SEC}\""
)
writeLines(launcher.lines, launcher)
Sys.chmod(launcher, mode = "0755")

cat("Prepared ", run.label, " PS-LPS full-versus-screened run\n", sep = "")
cat("Run directory: ", run.dir, "\n", sep = "")
cat("Task manifest: ", task.manifest.path, "\n", sep = "")
cat("Launcher: ", launcher, "\n", sep = "")
cat("Tasks: ", nrow(tasks), "\n", sep = "")
cat("Workers: ", n.workers, "\n", sep = "")
cat("Task timeout sec: ", task.timeout.sec, "\n", sep = "")
