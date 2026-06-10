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

make.pair.id <- function(dataset.id, profile.id, repetition, chart.rule) {
    paste(
        sanitize.id(dataset.id),
        sanitize.id(profile.id),
        sprintf("r%02d", as.integer(repetition)),
        gsub("\\.", "_", chart.rule),
        sep = "__"
    )
}

stable.z <- function(f, clip = 4) {
    f <- as.numeric(f)
    center <- stats::median(f, na.rm = TRUE)
    scale <- stats::mad(f, center = center, constant = 1, na.rm = TRUE)
    if (!is.finite(scale) || scale <= 0) {
        scale <- stats::sd(f, na.rm = TRUE)
    }
    if (!is.finite(scale) || scale <= 0) scale <- 1
    z <- (f - center) / scale
    pmax(-clip, pmin(clip, z))
}

calibrated.probability <- function(f, target.prevalence, slope,
                                   p.floor = 0.02, z.clip = 4) {
    z <- stable.z(f, clip = z.clip)
    target.prevalence <- as.numeric(target.prevalence)
    slope <- as.numeric(slope)
    p.floor <- as.numeric(p.floor)
    if (!is.finite(target.prevalence) || target.prevalence <= p.floor ||
        target.prevalence >= 1 - p.floor) {
        stop("'target.prevalence' must lie inside (p.floor, 1 - p.floor).",
             call. = FALSE)
    }
    mean.p <- function(alpha) {
        mean(p.floor + (1 - 2 * p.floor) * stats::plogis(alpha + slope * z))
    }
    alpha <- stats::uniroot(
        function(a) mean.p(a) - target.prevalence,
        interval = c(-50, 50)
    )$root
    p <- p.floor + (1 - 2 * p.floor) * stats::plogis(alpha + slope * z)
    list(
        p = as.numeric(p),
        alpha = alpha,
        z.center = stats::median(as.numeric(f), na.rm = TRUE),
        z.scale = {
            sc <- stats::mad(as.numeric(f), center = stats::median(as.numeric(f), na.rm = TRUE),
                             constant = 1, na.rm = TRUE)
            if (!is.finite(sc) || sc <= 0) sc <- stats::sd(as.numeric(f), na.rm = TRUE)
            if (!is.finite(sc) || sc <= 0) sc <- 1
            sc
        }
    )
}

validate.manifest <- function(tasks, expected.tasks) {
    required.cols <- c(
        "task_id", "pair_id", "dataset_id", "probability_profile",
        "repetition", "chart_dim_rule", "method_id", "outcome_family",
        "asset_path", "source_sha256", "response_seed", "fold_seed"
    )
    missing.cols <- setdiff(required.cols, names(tasks))
    if (length(missing.cols)) {
        stop("Task manifest is missing required columns: ",
             paste(missing.cols, collapse = ", "), call. = FALSE)
    }

    pair.split <- split(tasks, tasks$pair_id)
    arm.count <- vapply(pair.split, nrow, integer(1L))
    brier.count <- vapply(pair.split, function(x) {
        sum(x$method_id == "lps_bernoulli_brier")
    }, integer(1L))
    logistic.count <- vapply(pair.split, function(x) {
        sum(x$method_id == "lps_binomial_logistic")
    }, integer(1L))
    response.seed.count <- vapply(pair.split, function(x) {
        length(unique(x$response_seed))
    }, integer(1L))
    fold.seed.count <- vapply(pair.split, function(x) {
        length(unique(x$fold_seed))
    }, integer(1L))
    malformed.hashes <- is.na(tasks$source_sha256) |
        !grepl("^[0-9a-fA-F]{64}$", tasks$source_sha256)
    missing.assets <- is.na(tasks$asset_path) | !file.exists(tasks$asset_path)

    balance <- as.data.frame(xtabs(
        ~dataset_id + probability_profile + repetition + chart_dim_rule +
            method_id,
        tasks
    ), stringsAsFactors = FALSE)
    names(balance) <- c(
        "dataset_id", "probability_profile", "repetition",
        "chart_dim_rule", "method_id", "n"
    )

    summary <- data.frame(
        check = c(
            "planned_task_count",
            "planned_pair_count",
            "two_methods_per_pair",
            "one_bernoulli_brier_arm_per_pair",
            "one_binomial_logistic_arm_per_pair",
            "response_seed_matched_per_pair",
            "fold_seed_matched_per_pair",
            "asset_paths_present",
            "source_hashes_malformed",
            "balanced_dataset_profile_rep_chart_method_counts"
        ),
        observed = c(
            nrow(tasks),
            length(pair.split),
            sum(arm.count == 2L),
            sum(brier.count == 1L),
            sum(logistic.count == 1L),
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
            all(brier.count == 1L),
            all(logistic.count == 1L),
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
            bernoulli_brier_arms = brier.count,
            binomial_logistic_arms = logistic.count,
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
    "lps_binary_p7x_density_comparison_20260608_001"
n.workers <- as.integer(args$n_workers %||% "12")
task.timeout.sec <- as.integer(args$task_timeout_sec %||% "3600")
reps.per.profile <- as.integer(args$reps_per_profile %||% "5")
base.seed <- as.integer(args$base_seed %||% "20260608")

if (!is.finite(n.workers) || n.workers < 1L) {
    stop("'n_workers' must be a positive integer.", call. = FALSE)
}
if (!is.finite(task.timeout.sec) || task.timeout.sec < 1L) {
    stop("'task_timeout_sec' must be a positive integer.", call. = FALSE)
}
if (!is.finite(reps.per.profile) || reps.per.profile < 1L) {
    stop("'reps_per_profile' must be a positive integer.", call. = FALSE)
}
if (!is.finite(base.seed)) {
    stop("'base_seed' must be an integer.", call. = FALSE)
}

run.dir <- file.path(repo, "split_handoffs", run.id)
for (subdir in c("logs", "status", "results", "tables", "reports")) {
    dir.create(file.path(run.dir, subdir), recursive = TRUE,
               showWarnings = FALSE)
}

asset.manifest.path <- file.path(freeze.dir, "asset_manifest.csv")
asset.manifest <- utils::read.csv(asset.manifest.path, stringsAsFactors = FALSE)

profiles <- data.frame(
    probability_profile = c("balanced_smooth", "low_prevalence_smooth"),
    target_prevalence = c(0.50, 0.20),
    logit_slope = c(1.25, 1.25),
    probability_floor = c(0.02, 0.02),
    z_clip = c(4, 4),
    stringsAsFactors = FALSE
)

chart.rules <- c("auto", "local.auto")
methods <- data.frame(
    method_id = c("lps_bernoulli_brier", "lps_binomial_logistic"),
    outcome_family = c("bernoulli", "binomial"),
    selection_score = c("cv.brier.observed", "cv.logloss.observed"),
    stringsAsFactors = FALSE
)

surface.rows <- list()
ss <- 0L
for (ii in seq_len(nrow(asset.manifest))) {
    asset <- asset.manifest[ii, , drop = FALSE]
    obj <- readRDS(asset$asset.path[[1L]])
    f <- as.numeric(obj$f)
    if (length(f) != asset$n[[1L]]) {
        stop("Truth length mismatch for ", asset$dataset.id[[1L]],
             call. = FALSE)
    }
    for (pp in seq_len(nrow(profiles))) {
        profile <- profiles[pp, , drop = FALSE]
        prob <- calibrated.probability(
            f = f,
            target.prevalence = profile$target_prevalence[[1L]],
            slope = profile$logit_slope[[1L]],
            p.floor = profile$probability_floor[[1L]],
            z.clip = profile$z_clip[[1L]]
        )
        ss <- ss + 1L
        surface.rows[[ss]] <- data.frame(
            probability_surface_id = paste(asset$dataset.id[[1L]],
                                           profile$probability_profile[[1L]],
                                           sep = "__"),
            batch_id = asset$batch.id[[1L]],
            dataset_id = asset$dataset.id[[1L]],
            geometry_family = asset$geometry.family[[1L]],
            n = asset$n[[1L]],
            p = asset$p[[1L]],
            asset_path = asset$asset.path[[1L]],
            source_sha256 = asset$sha256[[1L]],
            probability_profile = profile$probability_profile[[1L]],
            target_prevalence = profile$target_prevalence[[1L]],
            realized_mean_probability = mean(prob$p),
            min_probability = min(prob$p),
            q05_probability = unname(stats::quantile(prob$p, 0.05)),
            median_probability = stats::median(prob$p),
            q95_probability = unname(stats::quantile(prob$p, 0.95)),
            max_probability = max(prob$p),
            logit_slope = profile$logit_slope[[1L]],
            logit_intercept = prob$alpha,
            probability_floor = profile$probability_floor[[1L]],
            z_clip = profile$z_clip[[1L]],
            f_center_median = prob$z.center,
            f_scale_mad_or_sd = prob$z.scale,
            transform_formula =
                "p=floor+(1-2*floor)*plogis(alpha+slope*clip((f-median(f))/scale,-z_clip,z_clip)); alpha chosen for mean(p)=target_prevalence",
            stringsAsFactors = FALSE
        )
    }
}
surface.manifest <- do.call(rbind, surface.rows)

task.list <- list()
tt <- 0L
for (ii in seq_len(nrow(asset.manifest))) {
    asset <- asset.manifest[ii, , drop = FALSE]
    for (pp in seq_len(nrow(profiles))) {
        profile <- profiles[pp, , drop = FALSE]
        probability.surface.id <- paste(asset$dataset.id[[1L]],
                                        profile$probability_profile[[1L]],
                                        sep = "__")
        for (rep.idx in seq_len(reps.per.profile)) {
            for (chart.rule in chart.rules) {
                pair.id <- make.pair.id(asset$dataset.id[[1L]],
                                        profile$probability_profile[[1L]],
                                        rep.idx, chart.rule)
                dataset.seed.component <- ii * 100000L
                profile.seed.component <- pp * 10000L
                repetition.seed.component <- rep.idx * 100L
                chart.seed.component <- if (identical(chart.rule, "local.auto")) {
                    10L
                } else {
                    0L
                }
                pair.seed.base <- base.seed + dataset.seed.component +
                    profile.seed.component + repetition.seed.component +
                    chart.seed.component
                fold.seed <- pair.seed.base + 1L
                response.seed <- pair.seed.base + 2L

                for (mm in seq_len(nrow(methods))) {
                    method <- methods[mm, , drop = FALSE]
                    tt <- tt + 1L
                    task.id <- sprintf(
                        "bin_%04d__%s__%s__r%02d__%s__%s",
                        tt,
                        sanitize.id(asset$dataset.id[[1L]]),
                        sanitize.id(profile$probability_profile[[1L]]),
                        rep.idx,
                        gsub("\\.", "_", chart.rule),
                        sanitize.id(method$method_id[[1L]])
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
                        probability_surface_id = probability.surface.id,
                        probability_profile =
                            profile$probability_profile[[1L]],
                        target_prevalence =
                            profile$target_prevalence[[1L]],
                        logit_slope = profile$logit_slope[[1L]],
                        probability_floor =
                            profile$probability_floor[[1L]],
                        z_clip = profile$z_clip[[1L]],
                        repetition = rep.idx,
                        pair_seed_base = pair.seed.base,
                        fold_seed = fold.seed,
                        response_seed = response.seed,
                        method_id = method$method_id[[1L]],
                        outcome_family = method$outcome_family[[1L]],
                        selection_score = method$selection_score[[1L]],
                        chart_dim_rule = chart.rule,
                        coordinate_method = "local.pca",
                        backend = "R",
                        support_grid = "15:35",
                        degree_grid = "1:2",
                        kernel_grid = "tricube",
                        design_basis = "orthogonal.polynomial.drop",
                        design_drop_tol = "1e-8",
                        ridge_multiplier_grid = "0;1e-10;1e-8",
                        ridge_condition_max = "1e12",
                        unstable_action = "mean",
                        cv_folds = 5L,
                        evaluation_metrics =
                            "truth_rmse_probability;truth_brier;truth_logloss;observed_brier;observed_logloss;calibration;logistic_telemetry",
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
}

tasks <- do.call(rbind, task.list)
expected.tasks <- nrow(asset.manifest) * nrow(profiles) * reps.per.profile *
    length(chart.rules) * nrow(methods)
qa <- validate.manifest(tasks, expected.tasks)

utils::write.csv(surface.manifest,
                 file.path(run.dir, "probability_surface_manifest.csv"),
                 row.names = FALSE, quote = TRUE)
utils::write.csv(tasks, file.path(run.dir, "task_manifest.csv"),
                 row.names = FALSE, quote = TRUE)
utils::write.csv(qa$summary, file.path(run.dir, "manifest_qa_summary.csv"),
                 row.names = FALSE, quote = TRUE)
utils::write.csv(qa$pair_details, file.path(run.dir, "manifest_pair_qa.csv"),
                 row.names = FALSE, quote = TRUE)
utils::write.csv(qa$balance, file.path(run.dir, "manifest_balance_qa.csv"),
                 row.names = FALSE, quote = TRUE)

run.config <- data.frame(
    run_id = run.id,
    repo = repo,
    freeze_dir = freeze.dir,
    asset_manifest_path = asset.manifest.path,
    run_dir = run.dir,
    n_workers = n.workers,
    task_timeout_sec = task.timeout.sec,
    task_count = nrow(tasks),
    paired_comparisons = length(unique(tasks$pair_id)),
    frozen_geometries = nrow(asset.manifest),
    probability_profiles = paste(profiles$probability_profile, collapse = ";"),
    reps_per_profile = reps.per.profile,
    binary_repetitions_per_geometry =
        reps.per.profile * nrow(profiles),
    base_seed = base.seed,
    purpose =
        "P7X-derived binary-outcome LPS comparison: Bernoulli/Brier versus binomial/logistic",
    cpu_policy = sprintf("local-only overnight; suggested workers=%d",
                         n.workers),
    support_grid = "15:35",
    degree_grid = "1:2",
    kernel_grid = "tricube",
    chart_dim_rules = paste(chart.rules, collapse = ";"),
    methods = paste(methods$method_id, collapse = ";"),
    created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    stringsAsFactors = FALSE
)
utils::write.csv(run.config, file.path(run.dir, "run_config.csv"),
                 row.names = FALSE, quote = TRUE)

writeLines(c(
    "LPS binary P7X-density manifest pre-launch QA",
    paste0("run_id: ", run.id),
    paste0("run_dir: ", run.dir),
    paste0("planned_tasks: ", nrow(tasks)),
    paste0("planned_pairs: ", length(unique(tasks$pair_id))),
    paste0("frozen_geometries: ", nrow(asset.manifest)),
    paste0("probability_profiles: ", nrow(profiles)),
    paste0("reps_per_profile: ", reps.per.profile),
    paste0("binary_repetitions_per_geometry: ",
           reps.per.profile * nrow(profiles)),
    paste0("seed_matched_pairs: ",
           sum(qa$pair_details$response_seed_values == 1L &
               qa$pair_details$fold_seed_values == 1L)),
    paste0("mismatched_pairs: ",
           sum(qa$pair_details$response_seed_values != 1L |
               qa$pair_details$fold_seed_values != 1L)),
    paste0("qa_passed: ", qa$pass)
), file.path(run.dir, "PRELAUNCH_SPEC_SUMMARY.txt"))

if (!qa$pass) {
    stop("Manifest pre-launch QA failed. See ",
         file.path(run.dir, "manifest_qa_summary.csv"), call. = FALSE)
}

message("Wrote binary manifest bundle: ", run.dir)
message("Tasks: ", nrow(tasks))
message("Pairs: ", length(unique(tasks$pair_id)))
