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

args <- parse.args(commandArgs(trailingOnly = TRUE))
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x
repo <- normalizePath(args$repo %||%
    file.path(Sys.getenv("HOME"), "current_projects", "geosmooth"),
    mustWork = TRUE)
source(file.path(repo, "scripts", "lps_binary_gm_ff_helpers.R"))

run.id <- args$run_id %||%
    paste0("lps_binary_gm_ff_full_", format(Sys.time(), "%Y%m%d_%H%M%S"))
run.dir <- file.path(repo, "split_handoffs", run.id)
for (subdir in c("logs", "status", "results", "tables", "reports")) {
    dir.create(file.path(run.dir, subdir), recursive = TRUE, showWarnings = FALSE)
}

n.workers <- as.integer(args$n_workers %||% "14")
task.timeout.sec <- as.integer(args$task_timeout_sec %||% "3600")
n.reps <- as.integer(args$n_reps %||% "10")
base.seed <- as.integer(args$base_seed %||% "20260608")

design.path <- args$design_manifest %||%
    file.path(repo, "split_handoffs", "experiment_catalogue_20260608",
              "lps_binary_gaussian_factorial_design_manifest.csv")
design <- utils::read.csv(design.path, stringsAsFactors = FALSE)

methods <- data.frame(
    method.id = c("lps_bernoulli_brier", "lps_binomial_logistic"),
    outcome.family = c("bernoulli", "binomial"),
    selection.score = c("cv.brier.observed", "cv.logloss.observed"),
    stringsAsFactors = FALSE
)
chart.rules <- c("auto", "local.auto")

tasks <- list()
tt <- 0L
for (ii in seq_len(nrow(design))) {
    scenario <- design[ii, , drop = FALSE]
    for (rep.idx in seq_len(n.reps)) {
        for (chart.rule in chart.rules) {
            pair.seed.base <- base.seed + ii * 100000L + rep.idx * 1000L +
                if (identical(chart.rule, "local.auto")) 100L else 0L
            pair.id <- paste(sanitize.id(scenario$scenario.id[[1L]]),
                             sprintf("r%02d", rep.idx),
                             gsub("\\.", "_", chart.rule), sep = "__")
            fold.seed <- pair.seed.base + 1L
            response.seed <- pair.seed.base + 2L
            geometry.seed <- pair.seed.base + 3L
            for (mm in seq_len(nrow(methods))) {
                method <- methods[mm, , drop = FALSE]
                tt <- tt + 1L
                task.id <- sprintf(
                    "bin_gm_ff_%05d__%s__r%02d__%s__%s",
                    tt,
                    sanitize.id(scenario$scenario.id[[1L]]),
                    rep.idx,
                    gsub("\\.", "_", chart.rule),
                    method$method.id[[1L]]
                )
                result.path <- file.path(run.dir, "results",
                                         paste0(task.id, ".csv"))
                status.path <- file.path(run.dir, "status",
                                         paste0(task.id, ".json"))
                log.path <- file.path(run.dir, "logs",
                                      paste0(task.id, ".log"))
                tasks[[tt]] <- data.frame(
                    task_id = task.id,
                    pair_id = pair.id,
                    scenario_id = scenario$scenario.id[[1L]],
                    suite_id = scenario$suite.id[[1L]],
                    geometry_block = scenario$geometry.block[[1L]],
                    source_geometry_id = scenario$source.geometry.id[[1L]],
                    intrinsic_dimension = scenario$intrinsic.dimension[[1L]],
                    ambient_dimension = scenario$ambient.dimension[[1L]],
                    embedding_family = scenario$embedding.family[[1L]],
                    gaussian_components = scenario$gaussian.components[[1L]],
                    truth_family = scenario$truth.family[[1L]],
                    probability_profile = scenario$probability.profile[[1L]],
                    profile_transform = scenario$profile.transform[[1L]],
                    target_prevalence = scenario$target.prevalence[[1L]],
                    profile_score = scenario$profile.score[[1L]],
                    sample_size_policy = scenario$sample.size.policy[[1L]],
                    sample_n = scenario$sample.n.target[[1L]],
                    repetition = rep.idx,
                    chart_dim_rule = chart.rule,
                    method_id = method$method.id[[1L]],
                    outcome_family = method$outcome.family[[1L]],
                    selection_score = method$selection.score[[1L]],
                    geometry_seed = geometry.seed,
                    fold_seed = fold.seed,
                    response_seed = response.seed,
                    support_grid = "15:35",
                    degree_grid = "1:2",
                    kernel_grid = "tricube",
                    design_basis = "orthogonal.polynomial.drop",
                    design_drop_tol = 1e-8,
                    ridge_multiplier_grid = "0;1e-10;1e-8",
                    ridge_condition_max = 1e12,
                    unstable_action = "mean",
                    cv_folds = 5L,
                    result_path = result.path,
                    status_path = status.path,
                    log_path = log.path,
                    skip_if_complete = TRUE,
                    stringsAsFactors = FALSE
                )
            }
        }
    }
}
tasks <- do.call(rbind, tasks)
utils::write.csv(tasks, file.path(run.dir, "task_manifest.csv"),
                 row.names = FALSE)

pair.split <- split(tasks, tasks$pair_id)
pair.qa <- data.frame(
    pair_id = names(pair.split),
    arms = vapply(pair.split, nrow, integer(1L)),
    methods = vapply(pair.split, function(x) length(unique(x$method_id)),
                     integer(1L)),
    response_seeds = vapply(pair.split, function(x) length(unique(x$response_seed)),
                            integer(1L)),
    fold_seeds = vapply(pair.split, function(x) length(unique(x$fold_seed)),
                        integer(1L)),
    stringsAsFactors = FALSE
)
utils::write.csv(pair.qa, file.path(run.dir, "manifest_pair_qa.csv"),
                 row.names = FALSE)
summary <- data.frame(
    check = c("task_count", "pair_count", "two_arms_per_pair",
              "method_matched_pairs", "response_seed_matched_pairs",
              "fold_seed_matched_pairs"),
    observed = c(nrow(tasks), length(pair.split),
                 sum(pair.qa$arms == 2L),
                 sum(pair.qa$methods == 2L),
                 sum(pair.qa$response_seeds == 1L),
                 sum(pair.qa$fold_seeds == 1L)),
    expected = c(nrow(design) * n.reps * 2L * 2L,
                 nrow(design) * n.reps * 2L,
                 nrow(pair.qa), nrow(pair.qa), nrow(pair.qa), nrow(pair.qa)),
    stringsAsFactors = FALSE
)
summary$passed <- summary$observed == summary$expected
utils::write.csv(summary, file.path(run.dir, "manifest_qa_summary.csv"),
                 row.names = FALSE)

run.config <- data.frame(
    run_id = run.id,
    run_dir = run.dir,
    design_manifest = design.path,
    n_workers = n.workers,
    task_timeout_sec = task.timeout.sec,
    n_reps = n.reps,
    base_seed = base.seed,
    planned_tasks = nrow(tasks),
    planned_pairs = length(pair.split),
    qa_passed = all(summary$passed),
    stringsAsFactors = FALSE
)
utils::write.csv(run.config, file.path(run.dir, "run_config.csv"),
                 row.names = FALSE)

writeLines(c(
    "# LPS-BIN-GM-FF Full Overnight Run",
    "",
    paste0("Prepared: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z",
                                tz = "America/New_York")),
    "",
    paste0("Run directory: `", run.dir, "`"),
    "",
    paste0("- planned tasks: ", nrow(tasks)),
    paste0("- planned pairs: ", length(pair.split)),
    paste0("- workers: ", n.workers),
    paste0("- task timeout seconds: ", task.timeout.sec),
    paste0("- QA passed: ", all(summary$passed)),
    "",
    "Use `scripts/launch_lps_binary_gm_ff_run.py` to execute the run."
), file.path(run.dir, "README.md"))

cat("Prepared run:", run.dir, "\n")
print(run.config)
if (!all(summary$passed)) quit(status = 1L)
