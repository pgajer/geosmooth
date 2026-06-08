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

args <- parse.args(commandArgs(trailingOnly = TRUE))
repo <- normalizePath(args$repo %||% getwd(), mustWork = TRUE)
freeze.dir <- normalizePath(
    args$freeze_dir %||%
        file.path(repo, "split_handoffs",
                  "lps_local_auto_nonmanifold_first_batch_2026-06-05"),
    mustWork = TRUE
)
run.id <- args$run_id %||%
    paste0("lps_ps_lps_backend_p7x_", format(Sys.time(), "%Y%m%d_%H%M%S"))
n.workers <- as.integer(args$n_workers %||% "14")
if (!is.finite(n.workers) || n.workers < 1L) {
    stop("'n_workers' must be a positive integer.", call. = FALSE)
}
task.timeout.sec <- as.integer(args$task_timeout_sec %||% "5400")
if (!is.finite(task.timeout.sec) || task.timeout.sec < 1L) {
    stop("'task_timeout_sec' must be a positive integer.", call. = FALSE)
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
methods <- c("lps", "ps_lps")
backend.variants <- data.frame(
    backend_variant = c(
        "monomial_tiny_ridge",
        "orthogonal_drop_adaptive_tiny"
    ),
    design_basis = c(
        "monomial",
        "orthogonal.polynomial.drop"
    ),
    design_drop_tol = c(1e-8, 1e-8),
    ridge_multiplier_grid = c("1e-8", "0;1e-10;1e-8"),
    ridge_condition_max = c("Inf", "1e12"),
    stringsAsFactors = FALSE
)

task.list <- list()
tt <- 0L
for (ii in seq_len(nrow(asset.manifest))) {
    asset <- asset.manifest[ii, , drop = FALSE]
    for (chart.rule in chart.rules) {
        for (method.id in methods) {
            for (vv in seq_len(nrow(backend.variants))) {
                variant <- backend.variants[vv, , drop = FALSE]
                tt <- tt + 1L
                task.id <- sprintf(
                    "bp7x_%04d__%s__%s__%s__%s",
                    tt,
                    sanitize.id(asset$dataset.id[[1L]]),
                    gsub("\\.", "_", chart.rule),
                    method.id,
                    variant$backend_variant[[1L]]
                )
                task.list[[tt]] <- data.frame(
                    task_id = task.id,
                    batch_id = asset$batch.id[[1L]],
                    dataset_id = asset$dataset.id[[1L]],
                    geometry_family = asset$geometry.family[[1L]],
                    n = asset$n[[1L]],
                    p = asset$p[[1L]],
                    asset_path = asset$asset.path[[1L]],
                    source_sha256 = asset$sha256[[1L]],
                    chart_dim_rule = chart.rule,
                    method = method.id,
                    backend_variant = variant$backend_variant[[1L]],
                    design_basis = variant$design_basis[[1L]],
                    design_drop_tol = variant$design_drop_tol[[1L]],
                    ridge_multiplier_grid =
                        variant$ridge_multiplier_grid[[1L]],
                    ridge_condition_max = variant$ridge_condition_max[[1L]],
                    support_grid = "15:35",
                    degree_grid = "2",
                    kernel_grid = "tricube",
                    lambda_sync_grid = "0;0.001;0.01;0.1;1;10",
                    lambda_sync_search = "guarded",
                    local_candidate_search = if (identical(method.id, "ps_lps")) {
                        "screened"
                    } else {
                        NA_character_
                    },
                    local_candidate_search_control = if (identical(method.id, "ps_lps")) {
                        "top.n=8;max.candidates=12;neighbor.radius=1;guard.support.quantiles=0|0.5|1"
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
    cpu_policy = "local-only; 14 workers on 16 logical cores (~87.5%)",
    support_grid = "15:35",
    ps_lps_local_candidate_search = "screened",
    ps_lps_local_candidate_search_control =
        "top.n=8;max.candidates=12;neighbor.radius=1;guard.support.quantiles=0|0.5|1",
    chart_dim_rules = paste(chart.rules, collapse = ";"),
    methods = paste(methods, collapse = ";"),
    backend_variants = paste(backend.variants$backend_variant, collapse = ";"),
    created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    stringsAsFactors = FALSE
)
utils::write.csv(run.config, file.path(run.dir, "run_config.csv"),
                 row.names = FALSE, quote = TRUE)

launcher <- file.path(run.dir, "launch_python_supervisor.sh")
launcher.lines <- c(
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    sprintf("RUN_DIR=%s", shQuote(run.dir)),
    sprintf("N_WORKERS=${N_WORKERS:-%d}", n.workers),
    sprintf("TASK_TIMEOUT_SEC=${TASK_TIMEOUT_SEC:-%d}", task.timeout.sec),
    sprintf("cd %s", shQuote(repo)),
    "python3 scripts/launch_lps_ps_lps_backend_broader_p7x_run.py \\",
    "  --run_dir \"${RUN_DIR}\" \\",
    "  --workers \"${N_WORKERS}\" \\",
    "  --task_timeout_sec \"${TASK_TIMEOUT_SEC}\""
)
writeLines(launcher.lines, launcher)
Sys.chmod(launcher, mode = "0755")

cat("Prepared broader P7X-style backend comparison run\n")
cat("Run directory: ", run.dir, "\n", sep = "")
cat("Task manifest: ", task.manifest.path, "\n", sep = "")
cat("Launcher: ", launcher, "\n", sep = "")
cat("Tasks: ", nrow(tasks), "\n", sep = "")
cat("Workers: ", n.workers, "\n", sep = "")
cat("Task timeout sec: ", task.timeout.sec, "\n", sep = "")
