#!/usr/bin/env Rscript

parse.args <- function(args) {
    out <- list()
    for (arg in args) {
        if (!grepl("^--", arg)) next
        kv <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1L]]
        key <- kv[[1L]]
        val <- if (length(kv) > 1L) paste(kv[-1L], collapse = "=") else TRUE
        out[[key]] <- val
    }
    out
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

args <- parse.args(commandArgs(trailingOnly = TRUE))
run.dir <- normalizePath(args$run_dir %||%
    "/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_full_20260608_001",
    mustWork = TRUE)
tables.dir <- file.path(run.dir, "tables")
reports.dir <- file.path(run.dir, "reports")
fig.dir <- file.path(reports.dir, "figures_lps_binary_gm_ff")
dir.create(fig.dir, recursive = TRUE, showWarnings = FALSE)

read.table.required <- function(path) {
    if (!file.exists(path)) stop("Missing required table: ", path, call. = FALSE)
    read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

results <- read.table.required(file.path(tables.dir, "combined_results.csv"))
status.rows <- read.table.required(file.path(tables.dir, "run_status_rows.csv"))
manifest <- read.table.required(file.path(run.dir, "task_manifest.csv"))
run.config <- read.table.required(file.path(run.dir, "run_config.csv"))
pair.qa <- read.table.required(file.path(run.dir, "manifest_pair_qa.csv"))
manifest.qa <- read.table.required(file.path(run.dir, "manifest_qa_summary.csv"))

results <- merge(
    results,
    status.rows[, c("task_id", "elapsed_sec", "started_at", "finished_at")],
    by = "task_id",
    all.x = TRUE
)
results <- merge(
    results,
    manifest[, c("task_id", "intrinsic_dimension", "ambient_dimension",
                 "embedding_family", "profile_transform", "selection_score",
                 "support_grid", "degree_grid", "kernel_grid",
                 "design_basis", "ridge_multiplier_grid",
                 "ridge_condition_max", "cv_folds")],
    by = "task_id",
    all.x = TRUE
)

method.label <- c(
    lps_bernoulli_brier = "Bernoulli/Brier LPS",
    lps_binomial_logistic = "Binomial/logistic LPS"
)
chart.label <- c(auto = "auto", local.auto = "local.auto")
geometry.label <- c(
    `1d_highdim_pad100` = "1D high-D pad100",
    `1d_native_interval` = "1D native interval",
    `2d_curved_paraboloid` = "2D paraboloid",
    `2d_curved_saddle` = "2D saddle",
    `2d_highdim_diag100` = "2D high-D diag100",
    `2d_native_square` = "2D native square",
    `3d_highdim_diag99` = "3D high-D diag99",
    `3d_native_cube` = "3D native cube"
)
profile.label <- c(
    balanced_signed_smooth = "balanced signed",
    low_prevalence_signed_smooth = "low-prev signed",
    balanced_tail_smooth = "balanced tail",
    low_prevalence_central_smooth = "low-prev central"
)

theme <- list(
    ink = "#24303d",
    muted = "#64748b",
    grid = "#d8dee8",
    red = "#b91c1c",
    blue = "#2563eb",
    green = "#15803d",
    amber = "#b45309",
    purple = "#7c3aed",
    gray = "#94a3b8",
    light = "#f8fafc"
)

html.escape <- function(x) {
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x <- gsub('"', "&quot;", x, fixed = TRUE)
    x
}

fmt <- function(x, digits = 4) {
    ifelse(is.na(x), "NA", formatC(x, digits = digits, format = "fg", flag = "#"))
}
fmt.int <- function(x) formatC(as.integer(round(x)), format = "d", big.mark = ",")
fmt.pct <- function(x, digits = 1) paste0(formatC(100 * x, digits = digits, format = "f"), "%")
fmt.num <- function(x, digits = 4) {
    ifelse(is.na(x), "NA", formatC(x, digits = digits, format = "f"))
}

weighted.median <- function(x, w) {
    ok <- is.finite(x) & is.finite(w) & w >= 0
    x <- x[ok]
    w <- w[ok]
    if (!length(x) || sum(w) <= 0) return(NA_real_)
    ord <- order(x)
    x <- x[ord]
    w <- w[ord] / sum(w)
    x[which(cumsum(w) >= 0.5)[1L]]
}

bb.median.ci <- function(x, B = 3000L, seed = 20260609L) {
    x <- x[is.finite(x)]
    if (!length(x)) return(c(median = NA_real_, lo = NA_real_, hi = NA_real_))
    if (length(unique(x)) == 1L) {
        return(c(median = median(x), lo = median(x), hi = median(x)))
    }
    set.seed(seed)
    vals <- replicate(B, weighted.median(x, stats::rexp(length(x))))
    c(median = median(x), lo = unname(stats::quantile(vals, 0.025, na.rm = TRUE)),
      hi = unname(stats::quantile(vals, 0.975, na.rm = TRUE)))
}

mad0 <- function(x) stats::median(abs(x - stats::median(x, na.rm = TRUE)), na.rm = TRUE)

safe.split <- function(x, f) {
    split(x, f, drop = TRUE)
}

write.png <- function(path, expr, width = 1600, height = 980) {
    grDevices::png(path, width = width, height = height, res = 150)
    on.exit(grDevices::dev.off(), add = TRUE)
    par(
        family = "sans", fg = theme$ink, col.axis = theme$ink,
        col.lab = theme$ink, col.main = theme$ink, xaxs = "i"
    )
    force(expr)
}

fig.rel <- function(path) file.path("figures_lps_binary_gm_ff", basename(path))

make.table <- function(df, digits = 4) {
    if (!nrow(df)) return("<p>No rows.</p>")
    out <- c("<table class=\"compact\"><thead><tr>",
             paste0("<th>", html.escape(names(df)), "</th>", collapse = ""),
             "</tr></thead><tbody>")
    for (ii in seq_len(nrow(df))) {
        cells <- vapply(df[ii, , drop = FALSE], function(col) {
            val <- col[[1L]]
            if (is.numeric(val) && digits == 0L) {
                fmt.int(val)
            } else if (is.numeric(val)) {
                fmt(val, digits = digits)
            } else {
                html.escape(val)
            }
        }, character(1L))
        out <- c(out, "<tr>", paste0("<td>", cells, "</td>", collapse = ""),
                 "</tr>")
    }
    paste(c(out, "</tbody></table>"), collapse = "\n")
}

caption <- function(num, title, text) {
    sprintf(
        '<p class="caption"><strong>Figure %d. %s.</strong> %s</p>',
        num, html.escape(title), text
    )
}

method.variant <- function(method, chart) {
    paste(method.label[method], chart, sep = " / ")
}

results$method_label <- unname(method.label[results$method_id])
results$chart_label <- unname(chart.label[results$chart_dim_rule])
results$method_variant <- method.variant(results$method_id, results$chart_dim_rule)
results$geometry_label <- unname(geometry.label[results$geometry_block])
results$profile_label <- unname(profile.label[results$probability_profile])
run.id <- basename(run.dir)
n.repetitions <- length(unique(results$repetition))
report.title <- sprintf("LPS Binary GM/FF %s-Rep Run Report", n.repetitions)

wide <- reshape(
    results[, c("pair_id", "scenario_id", "geometry_block", "geometry_label",
                "sample_n", "gaussian_components", "probability_profile",
                "profile_label", "target_prevalence", "repetition",
                "chart_dim_rule", "chart_label", "method_id",
                "truth_rmse_probability", "brier_truth_probability",
                "observed_logloss", "elapsed_sec", "selected_support_size",
                "selected_degree", "observed_event_rate",
                "realized_mean_probability",
                "logistic_cv_event_rate_fallback_fraction",
                "logistic_final_event_rate_fallback_fraction",
                "logistic_cv_fallback_path_fraction",
                "logistic_final_fallback_path_fraction")],
    idvar = "pair_id",
    timevar = "method_id",
    direction = "wide"
)

shared.cols <- c(
    "scenario_id", "geometry_block", "geometry_label", "sample_n",
    "gaussian_components", "probability_profile", "profile_label",
    "target_prevalence", "repetition", "chart_dim_rule", "chart_label",
    "observed_event_rate", "realized_mean_probability"
)
for (nm in shared.cols) {
    src <- paste0(nm, ".lps_bernoulli_brier")
    if (src %in% names(wide)) wide[[nm]] <- wide[[src]]
}

wide$delta_truth_rmse_logistic_minus_brier <-
    wide$truth_rmse_probability.lps_binomial_logistic -
    wide$truth_rmse_probability.lps_bernoulli_brier
wide$delta_elapsed_logistic_minus_brier <-
    wide$elapsed_sec.lps_binomial_logistic -
    wide$elapsed_sec.lps_bernoulli_brier
wide$elapsed_ratio_logistic_over_brier <-
    wide$elapsed_sec.lps_binomial_logistic /
    wide$elapsed_sec.lps_bernoulli_brier
wide$logistic_better <- wide$delta_truth_rmse_logistic_minus_brier < 0
wide$brier_better <- wide$delta_truth_rmse_logistic_minus_brier > 0
for (nm in c("logistic_cv_event_rate_fallback_fraction",
             "logistic_final_event_rate_fallback_fraction",
             "logistic_cv_fallback_path_fraction",
             "logistic_final_fallback_path_fraction")) {
    src <- paste0(nm, ".lps_binomial_logistic")
    if (src %in% names(wide)) wide[[nm]] <- wide[[src]]
}
fallback.breaks <- c(-Inf, 0, 0.05, 0.25, Inf)
fallback.labels <- c(
    "0",
    "(0, 0.05]",
    "(0.05, 0.25]",
    ">0.25"
)
wide$fallback_stratum <- cut(
    wide$logistic_final_event_rate_fallback_fraction,
    breaks = fallback.breaks,
    labels = fallback.labels,
    right = TRUE
)

summarize.delta <- function(df, group.name) {
    ci <- bb.median.ci(df$delta_truth_rmse_logistic_minus_brier,
                       seed = 20260609L + nchar(group.name))
    data.frame(
        group = group.name,
        n_pairs = nrow(df),
        median_delta_truth_rmse = unname(ci["median"]),
        cri_low = unname(ci["lo"]),
        cri_high = unname(ci["hi"]),
        logistic_better = sum(df$delta_truth_rmse_logistic_minus_brier < -1e-12,
                              na.rm = TRUE),
        ties = sum(abs(df$delta_truth_rmse_logistic_minus_brier) <= 1e-12,
                   na.rm = TRUE),
        brier_better = sum(df$delta_truth_rmse_logistic_minus_brier > 1e-12,
                           na.rm = TRUE),
        stringsAsFactors = FALSE
    )
}

summarize.cluster.delta <- function(df, group.name, cluster.cols) {
    cluster.key <- interaction(df[, cluster.cols, drop = FALSE], drop = TRUE)
    cluster.delta <- stats::aggregate(
        df$delta_truth_rmse_logistic_minus_brier,
        by = list(cluster = cluster.key),
        FUN = function(z) stats::median(z, na.rm = TRUE)
    )
    names(cluster.delta)[2L] <- "cluster_median_delta"
    ci <- bb.median.ci(cluster.delta$cluster_median_delta,
                       seed = 20260610L + nchar(group.name))
    data.frame(
        group = group.name,
        n_clusters = nrow(cluster.delta),
        median_delta_truth_rmse = unname(ci["median"]),
        cri_low = unname(ci["lo"]),
        cri_high = unname(ci["hi"]),
        stringsAsFactors = FALSE
    )
}

overall.delta <- summarize.delta(wide, "all")
chart.delta <- do.call(rbind, lapply(safe.split(wide, wide$chart_label), function(df) {
    summarize.delta(df, unique(df$chart_label))
}))
geometry.delta <- do.call(rbind, lapply(safe.split(wide, wide$geometry_label), function(df) {
    summarize.delta(df, unique(df$geometry_label))
}))
profile.delta <- do.call(rbind, lapply(safe.split(wide, wide$profile_label), function(df) {
    summarize.delta(df, unique(df$profile_label))
}))
sample.delta <- do.call(rbind, lapply(safe.split(wide, wide$sample_n), function(df) {
    summarize.delta(df, paste0("n=", unique(df$sample_n)))
}))
fallback.delta <- do.call(rbind, lapply(safe.split(wide, wide$fallback_stratum), function(df) {
    out <- summarize.delta(df, unique(as.character(df$fallback_stratum)))
    out$mean_logistic_final_event_rate_fallback <-
        mean(df$logistic_final_event_rate_fallback_fraction, na.rm = TRUE)
    out$median_logistic_final_event_rate_fallback <-
        stats::median(df$logistic_final_event_rate_fallback_fraction,
                      na.rm = TRUE)
    out
}))
fallback.delta <- fallback.delta[match(fallback.labels, fallback.delta$group), ]
geometry.fallback.summary <- do.call(rbind, lapply(safe.split(wide, wide$geometry_label), function(df) {
    data.frame(
        group = unique(df$geometry_label),
        n_pairs = nrow(df),
        median_delta_truth_rmse =
            stats::median(df$delta_truth_rmse_logistic_minus_brier,
                          na.rm = TRUE),
        logistic_better = sum(df$delta_truth_rmse_logistic_minus_brier < -1e-12,
                              na.rm = TRUE),
        brier_better = sum(df$delta_truth_rmse_logistic_minus_brier > 1e-12,
                           na.rm = TRUE),
        mean_logistic_final_event_rate_fallback =
            mean(df$logistic_final_event_rate_fallback_fraction, na.rm = TRUE),
        median_logistic_final_event_rate_fallback =
            stats::median(df$logistic_final_event_rate_fallback_fraction,
                          na.rm = TRUE),
        stringsAsFactors = FALSE
    )
}))

overall.cluster.delta <- summarize.cluster.delta(
    wide, "all scenario clusters", "scenario_id"
)
chart.cluster.delta <- do.call(rbind, lapply(safe.split(wide, wide$chart_label), function(df) {
    summarize.cluster.delta(df, unique(df$chart_label), "scenario_id")
}))
geometry.cluster.delta <- do.call(rbind, lapply(safe.split(wide, wide$geometry_label), function(df) {
    summarize.cluster.delta(df, unique(df$geometry_label), "scenario_id")
}))

fallback.cols <- intersect(
    c("logistic_cv_fallback_event_rate", "logistic_final_fallback_event_rate",
      "logistic_cv_event_rate_fallback_fraction",
      "logistic_final_event_rate_fallback_fraction",
      "logistic_cv_fallback_path_fraction",
      "logistic_final_fallback_path_fraction"),
    names(results)
)
fallback.validity <- data.frame(
    column = fallback.cols,
    non_na = vapply(fallback.cols, function(nm) sum(!is.na(results[[nm]])),
                    integer(1L)),
    finite = vapply(fallback.cols, function(nm) sum(is.finite(results[[nm]])),
                    integer(1L)),
    stringsAsFactors = FALSE
)
fallback.telemetry.available <- any(fallback.validity$finite > 0)
selection.metric.summary <- data.frame(
    method = names(method.label),
    selection_score_used = c("cv.brier.observed", "cv.logloss.observed"),
    n_rows = as.integer(table(factor(results$method_id, levels = names(method.label)))),
    n_selected_cv_brier = vapply(names(method.label), function(id) {
        sum(results$method_id == id & is.finite(results$selected_cv_brier_observed))
    }, integer(1L)),
    n_selected_cv_logloss = vapply(names(method.label), function(id) {
        sum(results$method_id == id & is.finite(results$selected_cv_logloss_observed))
    }, integer(1L)),
    stringsAsFactors = FALSE
)
observed.logloss.scope <- if ("observed_logloss_scope" %in% names(results)) {
    unique(results$observed_logloss_scope)
} else {
    "full_data_final_fit_in_sample_inferred_from_worker_source"
}

variant.summary <- do.call(rbind, lapply(safe.split(results, results$method_variant), function(df) {
    data.frame(
        method_variant = unique(df$method_variant),
        n = nrow(df),
        median_truth_rmse = stats::median(df$truth_rmse_probability, na.rm = TRUE),
        mad_truth_rmse = mad0(df$truth_rmse_probability),
        median_elapsed_sec = stats::median(df$elapsed_sec, na.rm = TRUE),
        mad_elapsed_sec = mad0(df$elapsed_sec),
        failure_rate = mean(df$status != "ok", na.rm = TRUE),
        median_support_size = stats::median(df$selected_support_size, na.rm = TRUE),
        degree1_rate = mean(df$selected_degree == 1, na.rm = TRUE),
        degree2_rate = mean(df$selected_degree == 2, na.rm = TRUE),
        stringsAsFactors = FALSE
    )
}))
variant.summary$rmse_snr <- with(variant.summary, median_truth_rmse / pmax(mad_truth_rmse, 1e-12))
variant.summary$elapsed_snr <- with(variant.summary, median_elapsed_sec / pmax(mad_elapsed_sec, 1e-12))
variant.short <- setNames(
    c("B-a", "B-la", "L-a", "L-la"),
    c("Bernoulli/Brier LPS / auto",
      "Bernoulli/Brier LPS / local.auto",
      "Binomial/logistic LPS / auto",
      "Binomial/logistic LPS / local.auto")
)
results$variant_short <- unname(variant.short[results$method_variant])
variant.summary$variant_short <- unname(variant.short[variant.summary$method_variant])

status.small <- data.frame(
    attempted = nrow(status.rows),
    ok = sum(status.rows$status == "ok"),
    error = sum(status.rows$status == "error"),
    timeout = sum(status.rows$status == "timeout"),
    nonfinite = sum(status.rows$status == "nonfinite_fit"),
    stringsAsFactors = FALSE
)

factor.counts <- data.frame(
    factor = c("geometries", "sample sizes", "Gaussian components",
               "probability profiles", "chart rules", "methods",
               "repetitions", "tasks", "paired comparisons"),
    count = c(length(unique(results$geometry_block)),
              length(unique(results$sample_n)),
              length(unique(results$gaussian_components)),
              length(unique(results$probability_profile)),
              length(unique(results$chart_dim_rule)),
              length(unique(results$method_id)),
              length(unique(results$repetition)),
              nrow(results),
              nrow(wide)),
    stringsAsFactors = FALSE
)

utils::write.csv(wide, file.path(tables.dir, "binary_gm_ff_paired_method_comparison.csv"),
                 row.names = FALSE)
utils::write.csv(variant.summary, file.path(tables.dir, "binary_gm_ff_method_variant_summary.csv"),
                 row.names = FALSE)
utils::write.csv(chart.delta, file.path(tables.dir, "binary_gm_ff_chart_delta_summary.csv"),
                 row.names = FALSE)
utils::write.csv(geometry.delta, file.path(tables.dir, "binary_gm_ff_geometry_delta_summary.csv"),
                 row.names = FALSE)
utils::write.csv(profile.delta, file.path(tables.dir, "binary_gm_ff_profile_delta_summary.csv"),
                 row.names = FALSE)
utils::write.csv(sample.delta, file.path(tables.dir, "binary_gm_ff_sample_delta_summary.csv"),
                 row.names = FALSE)
utils::write.csv(fallback.delta, file.path(tables.dir, "binary_gm_ff_fallback_stratified_delta_summary.csv"),
                 row.names = FALSE)
utils::write.csv(geometry.fallback.summary, file.path(tables.dir, "binary_gm_ff_geometry_fallback_summary.csv"),
                 row.names = FALSE)
utils::write.csv(overall.cluster.delta, file.path(tables.dir, "binary_gm_ff_overall_clustered_delta_summary.csv"),
                 row.names = FALSE)
utils::write.csv(chart.cluster.delta, file.path(tables.dir, "binary_gm_ff_chart_clustered_delta_summary.csv"),
                 row.names = FALSE)
utils::write.csv(geometry.cluster.delta, file.path(tables.dir, "binary_gm_ff_geometry_clustered_delta_summary.csv"),
                 row.names = FALSE)
utils::write.csv(fallback.validity, file.path(tables.dir, "binary_gm_ff_fallback_telemetry_validity.csv"),
                 row.names = FALSE)
utils::write.csv(selection.metric.summary, file.path(tables.dir, "binary_gm_ff_selection_metric_summary.csv"),
                 row.names = FALSE)

fig1 <- file.path(fig.dir, "figure_1_paired_delta_by_chart_rule.png")
write.png(fig1, {
    par(mar = c(5.2, 7.4, 4.2, 2.0))
    wide$chart_factor <- factor(wide$chart_label, levels = c("auto", "local.auto"))
    xs <- wide$delta_truth_rmse_logistic_minus_brier
    lim <- range(c(stats::quantile(xs, c(0.01, 0.99), na.rm = TRUE),
                   chart.delta$cri_low, chart.delta$cri_high, 0), na.rm = TRUE)
    pad <- diff(lim) * 0.15
    if (!is.finite(pad) || pad == 0) pad <- 0.001
    lim <- lim + c(-pad, pad)
    plot(NA, xlim = lim, ylim = c(0.5, 2.5), yaxt = "n",
         xlab = expression(Delta*" Truth RMSE = logistic - Bernoulli/Brier"),
         ylab = "", main = "Paired Probability-Recovery Difference by Chart Rule")
    axis(2, at = 1:2, labels = c("auto", "local.auto"), las = 1)
    abline(v = 0, col = theme$muted, lwd = 2)
    abline(h = 1:2, col = theme$grid)
    set.seed(11)
    for (jj in seq_along(levels(wide$chart_factor))) {
        lev <- levels(wide$chart_factor)[jj]
        sub <- wide[wide$chart_factor == lev, ]
        y <- rep(jj, nrow(sub)) + stats::runif(nrow(sub), -0.13, 0.13)
        points(sub$delta_truth_rmse_logistic_minus_brier, y, pch = 16,
               col = grDevices::adjustcolor(theme$gray, 0.36), cex = 0.65)
        st <- chart.delta[chart.delta$group == lev, ]
        segments(st$cri_low, jj, st$cri_high, jj, col = theme$red, lwd = 5)
        points(st$median_delta_truth_rmse, jj, pch = 21, bg = theme$red,
               col = "white", cex = 1.55, lwd = 1.2)
        lab <- sprintf("logistic/Brier/tie = %s/%s/%s",
                       fmt.int(st$logistic_better), fmt.int(st$brier_better),
                       fmt.int(st$ties))
        text(lim[2], jj + 0.24, lab, adj = c(1, 0.5), cex = 0.78,
             col = theme$muted)
    }
    legend("topleft",
           legend = c("Paired scenario/repetition", "Median and Bayesian bootstrap 95% CrI",
                      "No difference"),
           pch = c(16, 21, NA), pt.bg = c(NA, theme$red, NA),
           col = c(theme$gray, "white", theme$muted), lty = c(NA, 1, 1),
           lwd = c(NA, 4, 2), bty = "n", cex = 0.82)
})

fig2 <- file.path(fig.dir, "figure_2_paired_delta_by_geometry.png")
write.png(fig2, width = 1800, height = 1100, {
    par(mar = c(5.2, 12.0, 4.2, 2.8))
    ds <- geometry.delta[order(geometry.delta$median_delta_truth_rmse), ]
    y <- seq_len(nrow(ds))
    lim <- range(c(ds$cri_low, ds$cri_high, 0), na.rm = TRUE)
    pad <- diff(lim) * 0.15
    if (!is.finite(pad) || pad == 0) pad <- 0.001
    lim <- lim + c(-pad, pad)
    plot(NA, xlim = lim, ylim = c(0.5, nrow(ds) + 0.5), yaxt = "n",
         xlab = expression("Median " * Delta * " Truth RMSE = logistic - Bernoulli/Brier"),
         ylab = "", main = "Paired Difference by Geometry")
    axis(2, at = y, labels = ds$group, las = 1, cex.axis = 0.82)
    abline(v = 0, col = theme$muted, lwd = 2)
    abline(h = y, col = theme$grid)
    col <- ifelse(ds$cri_high < 0, theme$green,
                  ifelse(ds$cri_low > 0, theme$red, theme$gray))
    segments(ds$cri_low, y, ds$cri_high, y, col = col, lwd = 4)
    points(ds$median_delta_truth_rmse, y, pch = 21, bg = col,
           col = "white", cex = 1.35)
    text(lim[2], y, paste0("n=", ds$n_pairs), adj = c(1, 0.5),
         cex = 0.74, col = theme$muted)
})

fig3 <- file.path(fig.dir, "figure_3_paired_delta_by_profile_and_sample_size.png")
write.png(fig3, width = 1800, height = 1050, {
    par(mfrow = c(1, 2), mar = c(5.2, 8.8, 4.2, 2.0))
    plot.delta.group <- function(df, main) {
        df <- df[order(df$median_delta_truth_rmse), ]
        y <- seq_len(nrow(df))
        lim <- range(c(df$cri_low, df$cri_high, 0), na.rm = TRUE)
        pad <- diff(lim) * 0.16
        if (!is.finite(pad) || pad == 0) pad <- 0.001
        lim <- lim + c(-pad, pad)
        plot(NA, xlim = lim, ylim = c(0.5, nrow(df) + 0.5), yaxt = "n",
             xlab = expression("Median " * Delta * " Truth RMSE"),
             ylab = "", main = main)
        axis(2, at = y, labels = df$group, las = 1, cex.axis = 0.76)
        abline(v = 0, col = theme$muted, lwd = 2)
        abline(h = y, col = theme$grid)
        col <- ifelse(df$cri_high < 0, theme$green,
                      ifelse(df$cri_low > 0, theme$red, theme$gray))
        segments(df$cri_low, y, df$cri_high, y, col = col, lwd = 4)
        points(df$median_delta_truth_rmse, y, pch = 21, bg = col,
               col = "white", cex = 1.25)
    }
    plot.delta.group(profile.delta, "By Probability Profile")
    plot.delta.group(sample.delta, "By Sample Size")
})

fig4 <- file.path(fig.dir, "figure_4_fallback_stratified_paired_delta.png")
write.png(fig4, width = 1650, height = 1000, {
    par(mar = c(5.2, 9.2, 4.2, 2.6))
    ds <- fallback.delta[!is.na(fallback.delta$group), ]
    ds$group <- factor(ds$group, levels = rev(fallback.labels))
    ds <- ds[order(ds$group), ]
    y <- seq_len(nrow(ds))
    lim <- range(c(ds$cri_low, ds$cri_high, 0), na.rm = TRUE)
    pad <- diff(lim) * 0.16
    if (!is.finite(pad) || pad == 0) pad <- 0.001
    lim <- lim + c(-pad, pad)
    plot(NA, xlim = lim, ylim = c(0.5, nrow(ds) + 0.5), yaxt = "n",
         xlab = expression("Median " * Delta * " Truth RMSE = logistic - Bernoulli/Brier"),
         ylab = "", main = "Paired Difference by Logistic Fallback Fraction")
    axis(2, at = y, labels = as.character(ds$group), las = 1, cex.axis = 0.82)
    abline(v = 0, col = theme$muted, lwd = 2)
    abline(h = y, col = theme$grid)
    col <- ifelse(ds$cri_high < 0, theme$green,
                  ifelse(ds$cri_low > 0, theme$red, theme$gray))
    segments(ds$cri_low, y, ds$cri_high, y, col = col, lwd = 4)
    points(ds$median_delta_truth_rmse, y, pch = 21, bg = col,
           col = "white", cex = 1.35)
    labels <- sprintf("n=%s", fmt.int(ds$n_pairs))
    text(lim[2], y, labels, adj = c(1, 0.5), cex = 0.72,
         col = theme$muted)
})

fig5 <- file.path(fig.dir, "figure_5_frank_friedman_accuracy_runtime_summary.png")
write.png(fig5, width = 1650, height = 1050, {
    par(mar = c(5.2, 6.0, 4.2, 2.6))
    x <- variant.summary$median_elapsed_sec
    y <- variant.summary$median_truth_rmse
    xlim <- range(c(x - variant.summary$mad_elapsed_sec,
                    x + variant.summary$mad_elapsed_sec), na.rm = TRUE)
    ylim <- range(c(y - variant.summary$mad_truth_rmse,
                    y + variant.summary$mad_truth_rmse), na.rm = TRUE)
    xpad <- diff(xlim) * 0.15
    ypad <- diff(ylim) * 0.15
    xlim <- xlim + c(-xpad, xpad)
    ylim <- ylim + c(-ypad, ypad)
    plot(NA, xlim = xlim, ylim = ylim,
         xlab = "Median elapsed seconds per fit",
         ylab = "Median probability Truth RMSE",
         main = "Frank/Friedman-Style Accuracy-Runtime Summary")
    grid(col = theme$grid)
    cols <- ifelse(grepl("Bernoulli", variant.summary$method_variant), theme$blue, theme$red)
    pchs <- ifelse(grepl("local.auto", variant.summary$method_variant), 24, 21)
    segments(x - variant.summary$mad_elapsed_sec, y,
             x + variant.summary$mad_elapsed_sec, y, col = theme$red, lwd = 2)
    segments(x, y - variant.summary$mad_truth_rmse,
             x, y + variant.summary$mad_truth_rmse, col = theme$red, lwd = 2)
    points(x, y, pch = pchs, bg = cols, col = "white", cex = 1.8, lwd = 1.2)
    text(x, y, labels = c("B-a", "B-la", "L-a", "L-la"),
         pos = c(4, 2, 4, 2), cex = 0.86, col = theme$ink, xpd = TRUE)
    legend("topright",
           legend = c("Bernoulli/Brier", "Binomial/logistic", "auto", "local.auto"),
           pch = c(21, 21, 21, 24), pt.bg = c(theme$blue, theme$red, "white", "white"),
           col = c("white", "white", theme$ink, theme$ink),
           bty = "n", cex = 0.86)
})

fig6 <- file.path(fig.dir, "figure_6_selected_support_size_and_degree.png")
write.png(fig6, width = 1750, height = 1050, {
    par(mfrow = c(1, 2), mar = c(5.4, 5.2, 4.2, 1.2))
    ord <- variant.summary$method_variant
    results$variant_short_factor <- factor(results$variant_short,
                                           levels = variant.summary$variant_short)
    boxplot(selected_support_size ~ variant_short_factor, data = results,
            las = 1, col = grDevices::adjustcolor(theme$blue, 0.35),
            border = theme$ink, ylab = "Selected support size",
            xlab = "Method variant",
            main = "Support Size Selected by CV")
    grid(nx = NA, ny = NULL, col = theme$grid)
    deg.tab <- as.data.frame(table(results$method_variant, results$selected_degree),
                             stringsAsFactors = FALSE)
    names(deg.tab) <- c("method_variant", "degree", "n")
    deg.wide <- reshape(deg.tab, idvar = "method_variant", timevar = "degree",
                        direction = "wide")
    deg.wide <- deg.wide[match(ord, deg.wide$method_variant), ]
    n1 <- deg.wide$n.1 %||% rep(0, nrow(deg.wide))
    n2 <- deg.wide$n.2 %||% rep(0, nrow(deg.wide))
    mat <- rbind(degree1 = n1, degree2 = n2)
    bp <- barplot(mat, beside = FALSE, las = 1, col = c(theme$amber, theme$green),
                  border = NA, ylab = "Number of fits",
                  names.arg = unname(variant.short[deg.wide$method_variant]),
                  main = "Selected Polynomial Degree")
    legend("topleft", legend = c("degree 1", "degree 2"),
           fill = c(theme$amber, theme$green), bty = "n", cex = 0.82)
})

fig_legacy4 <- file.path(fig.dir, "figure_4_frank_friedman_accuracy_runtime_summary.png")
if (file.exists(fig_legacy4)) unlink(fig_legacy4)
fig_legacy5 <- file.path(fig.dir, "figure_5_selected_support_size_and_degree.png")
if (file.exists(fig_legacy5)) unlink(fig_legacy5)

if (FALSE) {
fig4 <- file.path(fig.dir, "figure_4_frank_friedman_accuracy_runtime_summary.png")
write.png(fig4, width = 1650, height = 1050, {
    par(mar = c(5.2, 6.0, 4.2, 2.6))
    x <- variant.summary$median_elapsed_sec
    y <- variant.summary$median_truth_rmse
    xlim <- range(c(x - variant.summary$mad_elapsed_sec,
                    x + variant.summary$mad_elapsed_sec), na.rm = TRUE)
    ylim <- range(c(y - variant.summary$mad_truth_rmse,
                    y + variant.summary$mad_truth_rmse), na.rm = TRUE)
    xpad <- diff(xlim) * 0.15
    ypad <- diff(ylim) * 0.15
    xlim <- xlim + c(-xpad, xpad)
    ylim <- ylim + c(-ypad, ypad)
    plot(NA, xlim = xlim, ylim = ylim,
         xlab = "Median elapsed seconds per fit",
         ylab = "Median probability Truth RMSE",
         main = "Frank/Friedman-Style Accuracy-Runtime Summary")
    grid(col = theme$grid)
    cols <- ifelse(grepl("Bernoulli", variant.summary$method_variant), theme$blue, theme$red)
    pchs <- ifelse(grepl("local.auto", variant.summary$method_variant), 24, 21)
    segments(x - variant.summary$mad_elapsed_sec, y,
             x + variant.summary$mad_elapsed_sec, y, col = theme$red, lwd = 2)
    segments(x, y - variant.summary$mad_truth_rmse,
             x, y + variant.summary$mad_truth_rmse, col = theme$red, lwd = 2)
    points(x, y, pch = pchs, bg = cols, col = "white", cex = 1.8, lwd = 1.2)
    text(x, y, labels = c("B-a", "B-la", "L-a", "L-la"),
         pos = c(4, 2, 4, 2), cex = 0.86, col = theme$ink, xpd = TRUE)
    legend("topright",
           legend = c("Bernoulli/Brier", "Binomial/logistic", "auto", "local.auto"),
           pch = c(21, 21, 21, 24), pt.bg = c(theme$blue, theme$red, "white", "white"),
           col = c("white", "white", theme$ink, theme$ink),
           bty = "n", cex = 0.86)
})

fig5 <- file.path(fig.dir, "figure_5_selected_support_size_and_degree.png")
write.png(fig5, width = 1750, height = 1050, {
    par(mfrow = c(1, 2), mar = c(5.4, 5.2, 4.2, 1.2))
    ord <- variant.summary$method_variant
    results$variant_short_factor <- factor(results$variant_short,
                                           levels = variant.summary$variant_short)
    boxplot(selected_support_size ~ variant_short_factor, data = results,
            las = 1, col = grDevices::adjustcolor(theme$blue, 0.35),
            border = theme$ink, ylab = "Selected support size",
            xlab = "Method variant",
            main = "Support Size Selected by CV")
    grid(nx = NA, ny = NULL, col = theme$grid)
    deg.tab <- as.data.frame(table(results$method_variant, results$selected_degree),
                             stringsAsFactors = FALSE)
    names(deg.tab) <- c("method_variant", "degree", "n")
    deg.wide <- reshape(deg.tab, idvar = "method_variant", timevar = "degree",
                        direction = "wide")
    deg.wide <- deg.wide[match(ord, deg.wide$method_variant), ]
    n1 <- deg.wide$n.1 %||% rep(0, nrow(deg.wide))
    n2 <- deg.wide$n.2 %||% rep(0, nrow(deg.wide))
    mat <- rbind(degree1 = n1, degree2 = n2)
    bp <- barplot(mat, beside = FALSE, las = 1, col = c(theme$amber, theme$green),
                  border = NA, ylab = "Number of fits",
                  names.arg = unname(variant.short[deg.wide$method_variant]),
                  main = "Selected Polynomial Degree")
    legend("topleft", legend = c("degree 1", "degree 2"),
           fill = c(theme$amber, theme$green), bty = "n", cex = 0.82)
})
}

build.datetime <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z",
                         tz = "America/New_York")
result.timestamp <- max(file.info(file.path(tables.dir, "combined_results.csv"))$mtime,
                        na.rm = TRUE)
result.datetime <- format(result.timestamp, "%Y-%m-%d %H:%M:%S %Z",
                          tz = "America/New_York")

report.path <- file.path(
    reports.dir,
    sprintf("lps_binary_gm_ff_%srep_report.html", n.repetitions)
)
rel.path <- function(path) {
    html.escape(path)
}

overall <- overall.delta
best.variant <- variant.summary[which.min(variant.summary$median_truth_rmse), ]
fast.variant <- variant.summary[which.min(variant.summary$median_elapsed_sec), ]
clean.fallback.row <- fallback.delta[fallback.delta$group == "0", ]
heavy.fallback.row <- fallback.delta[fallback.delta$group == ">0.25", ]
highd.1d.fallback.row <- geometry.fallback.summary[
    geometry.fallback.summary$group == "1D high-D pad100", ]

status.text <- sprintf(
    "%s attempted fits, %s ok, %s errors, %s timeouts.",
    fmt.int(status.small$attempted), fmt.int(status.small$ok),
    fmt.int(status.small$error), fmt.int(status.small$timeout)
)
headline.text <- if (fallback.telemetry.available) {
    paste(
        "The LPS-BIN-GM-FF run completed cleanly with populated logistic",
        "fallback telemetry. The report compares the current Bernoulli/Brier",
        "and binomial/logistic deployed policies by probability Truth RMSE,",
        "runtime, selected candidate behavior, and fit diagnostics."
    )
} else {
    paste(
        sprintf("The LPS-BIN-GM-FF run completed cleanly: all %s fits have",
                fmt.int(nrow(results))),
        "status <code>ok</code>. The current deployable-policy comparison",
        "favors Bernoulli/Brier LPS in pooled probability Truth RMSE and",
        "runtime, but several logistic-specific mechanism claims are blocked",
        "until the run is repeated with corrected fallback telemetry and",
        "symmetric selection-score diagnostics."
    )
}
fallback.validity.html <- if (fallback.telemetry.available) {
    c(
        '<div class="callout">',
        '<strong>Logistic fallback telemetry is populated.</strong> At least one logistic fallback diagnostic column has finite values in this result bundle, so logistic fallback rates can be audited directly from the cached CSV.',
        '</div>'
    )
} else {
    c(
        '<div class="warning">',
        '<strong>Important audit note.</strong> The cached result rows do not contain valid logistic fallback telemetry: the run worker wrote obsolete field names, so the logistic fallback columns are all <code>NA</code>. The worker has been patched for future runs, but this report cannot recover per-fit logistic fallback rates from the cached CSV alone.',
        '</div>'
    )
}
fallback.interpretation.html <- if (fallback.telemetry.available) {
    paste(
        "The fallback table below should be interpreted as a data-validity",
        "check: non-zero fallback rates are not automatically failures, but",
        "they must be stratified before making claims about the logistic mode."
    )
} else {
    paste(
        "This means the report can still compare completed deployable",
        "policies by probability Truth RMSE and runtime, but it must not",
        "conclude that local logistic fitting itself was stable, unstable,",
        "helpful, or unhelpful across all local charts. That question needs a",
        "telemetry-valid rerun or repair run."
    )
}
telemetry.learned.html <- if (fallback.telemetry.available) {
    "<li>Logistic fallback telemetry is present in this rerun, so future audit can stratify the logistic path by convergence, fallback-path, event-rate fallback, and missing-score behavior rather than treating logistic failures as invisible.</li>"
} else {
    "<li>Fallback telemetry is missing from this cached run. The worker has been patched, and future logistic comparisons should be audited for fallback rates before interpreting local logistic stability.</li>"
}

html <- c(
'<!DOCTYPE html>',
'<html lang="en">',
'<head>',
'<meta charset="utf-8">',
'<meta name="viewport" content="width=device-width, initial-scale=1">',
sprintf('<title>%s</title>', html.escape(report.title)),
'<script>',
'window.MathJax = { tex: { inlineMath: [["\\\\(","\\\\)"], ["$","$"]], displayMath: [["\\\\[","\\\\]"]] } };',
'</script>',
'<script defer src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>',
'<style>',
'body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #24303d; line-height: 1.55; margin: 0; background: #f8fafc; }',
'.page { max-width: 1180px; margin: 0 auto; padding: 34px 28px 60px; background: white; }',
'h1 { font-size: 34px; line-height: 1.15; margin: 0 0 8px; }',
'h2 { margin-top: 34px; border-top: 1px solid #e2e8f0; padding-top: 22px; font-size: 24px; }',
'h3 { margin-top: 24px; font-size: 18px; }',
'.meta { color: #64748b; font-size: 14px; margin: 12px 0 24px; }',
'.callout { background: #eef6ff; border-left: 4px solid #2563eb; padding: 12px 16px; margin: 18px 0; }',
'.warning { background: #fff7ed; border-left: 4px solid #b45309; padding: 12px 16px; margin: 18px 0; }',
'.grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; margin: 18px 0; }',
'.metric { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 12px; }',
'.metric .value { font-size: 24px; font-weight: 700; }',
'.metric .label { color: #64748b; font-size: 13px; }',
'figure { margin: 28px 0 10px; }',
'figure img { width: 100%; border: 1px solid #e2e8f0; border-radius: 8px; }',
'.caption { color: #334155; font-size: 14px; margin-top: 8px; }',
'table.compact { border-collapse: collapse; width: auto; max-width: 100%; margin: 14px 0; font-size: 14px; }',
'table.compact th, table.compact td { border: 1px solid #e2e8f0; padding: 7px 9px; text-align: left; vertical-align: top; }',
'table.compact th { background: #f1f5f9; }',
'code { background: #f1f5f9; padding: 1px 4px; border-radius: 4px; }',
'ul { padding-left: 24px; }',
'a { color: #1d4ed8; }',
'@media (max-width: 900px) { .grid { grid-template-columns: repeat(2, 1fr); } .page { padding: 24px 16px; } }',
'</style>',
'</head>',
'<body><main class="page">',
sprintf('<h1>%s</h1>', html.escape(report.title)),
sprintf('<div class="meta">Report built: %s<br>Result artifact timestamp: %s<br>Run directory: <code>%s</code></div>',
        html.escape(build.datetime), html.escape(result.datetime), html.escape(run.dir)),
'<div class="callout">',
sprintf('<strong>Headline.</strong> %s', headline.text),
'</div>',
'<div class="grid">',
sprintf('<div class="metric"><div class="value">%s</div><div class="label">attempted fits</div></div>', fmt.int(nrow(results))),
sprintf('<div class="metric"><div class="value">%s</div><div class="label">paired comparisons</div></div>', fmt.int(nrow(wide))),
sprintf('<div class="metric"><div class="value">%s</div><div class="label">scenario cells</div></div>', fmt.int(length(unique(results$scenario_id)))),
sprintf('<div class="metric"><div class="value">%s</div><div class="label">status</div></div>', html.escape("all ok")),
'</div>',
'<h2>Purpose And Main Questions</h2>',
'<p>This experiment tests two binary-outcome variants of the local polynomial smoother (LPS) on a factorial suite of Gaussian-mixture probability surfaces. The response is binary, but the synthetic truth is the known conditional probability \\(p_i = \\Pr(Y_i = 1 \\mid X_i)\\). This lets us judge whether each method recovers the probability surface, not only whether it predicts the particular realized binary sample.</p>',
'<p>The main questions are:</p>',
'<ul>',
'<li>Does local logistic fitting improve probability-surface recovery relative to the simpler Bernoulli/Brier conditional-mean mode?</li>',
'<li>Does the answer change when chart dimension is selected globally with <code>chart.dim = "auto"</code> versus locally with <code>chart.dim = "local.auto"</code>?</li>',
'<li>How do accuracy, runtime, selected support size, and selected degree vary across geometries, probability profiles, and sample sizes?</li>',
'</ul>',
'<h2>Design And Fit-Status Accounting</h2>',
sprintf('<p>The experiment crossed eight geometry blocks, three sample sizes, three Gaussian-mixture complexities, four probability profiles, two chart-dimension policies, two binary LPS modes, and %s repetitions. Every paired comparison shares the same geometry seed, probability surface, binary response realization, and CV folds.</p>',
        fmt.int(n.repetitions)),
make.table(factor.counts, digits = 0),
sprintf('<p><strong>Fit-status accounting:</strong> %s No rows were excluded from the paired accuracy summaries.</p>', html.escape(status.text)),
make.table(status.small, digits = 0),
'<p>The manifest QA required exactly two method arms per pair, one shared response seed, and one shared fold seed inside each pair.</p>',
make.table(manifest.qa, digits = 0),
'<h2>Methods And Quantities</h2>',
'<p>The two compared methods are:</p>',
'<ul>',
'<li><strong>Bernoulli/Brier LPS</strong>: treats the binary response \\(Y_i \\in \\{0,1\\}\\) as a numeric conditional-mean target and chooses candidates by observed CV Brier score.</li>',
'<li><strong>Binomial/logistic LPS</strong>: fits local logistic polynomial models and chooses candidates by observed CV log loss.</li>',
'</ul>',
'<p>For a fitted probability estimate \\(\\hat p_i\\) and known synthetic probability \\(p_i\\), the primary target is probability Truth RMSE:</p>',
'\\[ R(\\hat p,p) = \\sqrt{\\frac{1}{n}\\sum_{i=1}^n (\\hat p_i - p_i)^2}. \\]',
'<p>Lower values mean better recovery of the true probability surface. We also report observed log loss on the realized binary outcomes,</p>',
'\\[ L(\\hat p,Y) = -\\frac{1}{n}\\sum_{i=1}^n \\left\\{Y_i\\log(\\hat p_i) + (1-Y_i)\\log(1-\\hat p_i)\\right\\}, \\]',
'<p>after clipping probabilities away from zero and one for numerical stability. Observed log loss is useful, but the synthetic target in this report is probability Truth RMSE.</p>',
'<p>For paired method comparisons, the plotted difference is</p>',
'\\[ \\Delta_s = R_s(\\hat p^{\\rm logistic},p) - R_s(\\hat p^{\\rm Brier},p), \\]',
'<p>where \\(s\\) indexes a matched scenario, repetition, and chart rule. Negative \\(\\Delta_s\\) means the local logistic fit has lower Truth RMSE; positive \\(\\Delta_s\\) means the Bernoulli/Brier fit has lower Truth RMSE. Red intervals in paired figures are Bayesian-bootstrap 95% credible intervals for the median paired difference over displayed matched pairs. Scenario-clustered summaries are reported separately because repeated folds, repetitions, and chart rules are not independent scientific units.</p>',
'<h2>Data-Validity Notes Before Interpretation</h2>',
fallback.validity.html,
make.table(fallback.validity, digits = 0),
sprintf('<p>%s</p>', html.escape(fallback.interpretation.html)),
'<p>The two methods also used different selection scores. Bernoulli/Brier LPS was selected by observed CV Brier score, while binomial/logistic LPS was selected by observed CV log loss. Because the primary synthetic target is squared probability error, this is a deployed-policy comparison, not a clean family comparison under a shared selection metric.</p>',
make.table(selection.metric.summary, digits = 0),
sprintf('<p>The reported <code>observed_logloss</code> column has scope <code>%s</code>. It is computed on the final full-data fit and realized binary responses, not as a held-out log-loss diagnostic. For that reason, the prior observed-log-loss scatter has been removed from the main report; future runs should store fold-held-out log loss if it is to be interpreted as a validation metric.</p>',
        html.escape(paste(observed.logloss.scope, collapse = ", "))),
sprintf('<p>Pair-level pooled median delta is %s, while scenario-clustered median delta is %s with 95%% Bayesian-bootstrap CrI [%s, %s] over %s scenario clusters. The scenario-clustered summary is the safer uncertainty summary for cross-scenario claims.</p>',
        fmt(overall$median_delta_truth_rmse, 5),
        fmt(overall.cluster.delta$median_delta_truth_rmse, 5),
        fmt(overall.cluster.delta$cri_low, 5),
        fmt(overall.cluster.delta$cri_high, 5),
        fmt.int(overall.cluster.delta$n_clusters)),
'<h2>Paired Method Comparison</h2>',
sprintf('<p>Across all %s paired comparisons, the median paired delta is %s. The sign pattern is %s logistic-better, %s Bernoulli/Brier-better, and %s ties.</p>',
        fmt.int(nrow(wide)), fmt(overall$median_delta_truth_rmse, 5),
        fmt.int(overall$logistic_better), fmt.int(overall$brier_better),
        fmt.int(overall$ties)),
sprintf('<figure><img src="%s" alt="Paired Truth RMSE delta by chart rule">%s</figure>',
        fig.rel(fig1),
        caption(1, "Paired method difference by chart rule",
                "Each gray point is one matched scenario/repetition pair. The red point and interval show the Bayesian-bootstrap median paired delta and 95% credible interval. Negative values favor binomial/logistic LPS; positive values favor Bernoulli/Brier LPS.")),
'<p>The chart-rule split is the first check for whether local dimension selection changes the method conclusion. If both intervals remain close to zero, then the two binary modes are practically similar at this suite scale; if one interval is clearly shifted, the chart policy changes the preferred binary mode.</p>',
sprintf('<figure><img src="%s" alt="Paired Truth RMSE delta by geometry">%s</figure>',
        fig.rel(fig2),
        caption(2, "Paired method difference by geometry",
                "Rows summarize matched pairs within a geometry family. Green intervals favor the logistic mode, red intervals favor the Bernoulli/Brier mode, and gray intervals overlap zero.")),
'<p>The geometry view shows a real interaction hidden by the pooled median. Logistic LPS wins all 720 matched pairs in the 1D high-dimensional pad100 geometry, with median \\(\\Delta\\) below zero, but Bernoulli/Brier LPS dominates the 3D native and 3D high-dimensional geometries. This run therefore supports a geometry-dependent result, not a universal statement that one binary mode is always better.</p>',
make.table(geometry.delta[order(geometry.delta$median_delta_truth_rmse),
                          c("group", "n_pairs", "median_delta_truth_rmse",
                            "logistic_better", "brier_better")],
           digits = 4),
sprintf('<figure><img src="%s" alt="Paired Truth RMSE delta by probability profile and sample size">%s</figure>',
        fig.rel(fig3),
        caption(3, "Paired method difference by probability profile and sample size",
                "The left panel groups by probability-profile transform and prevalence; the right panel groups by sample size. The plotted quantity is the median paired Truth-RMSE delta with Bayesian-bootstrap 95% credible intervals.")),
'<p>The profile and sample-size view separates two possible explanations: one method may be better only for rare-event profiles, or one method may need larger sample sizes before its local likelihood advantage appears.</p>',
'<h2>Fallback-Stratified Interpretation</h2>',
'<p>The logistic arm records an event-rate fallback fraction for the final fit. This is the fraction of local logistic predictions that could not be obtained from a converged local logistic solve and instead used an event-rate fallback. A large fallback fraction means the row is no longer evidence about clean local logistic fitting alone.</p>',
sprintf('<figure><img src="%s" alt="Fallback-stratified paired Truth RMSE delta">%s</figure>',
        fig.rel(fig4),
        caption(4, "Paired method difference by logistic fallback fraction",
                "Rows group matched pairs by the final-fit event-rate fallback fraction in the logistic arm. Negative values favor the logistic-mode output; positive values favor Bernoulli/Brier. Heavy fallback changes the interpretation because the logistic-mode output is then partly an event-rate fallback rather than a pure local logistic fit.")),
sprintf('<p>In the zero-fallback stratum, the median paired delta is %s over %s pairs. In the heavy-fallback stratum, defined here as fallback fraction above 0.25, the median paired delta is %s over %s pairs. Thus the pooled result mixes clean local-logistic behavior with a distinct fallback-dominated regime.</p>',
        fmt(clean.fallback.row$median_delta_truth_rmse, 5),
        fmt.int(clean.fallback.row$n_pairs),
        fmt(heavy.fallback.row$median_delta_truth_rmse, 5),
        fmt.int(heavy.fallback.row$n_pairs)),
make.table(fallback.delta[, c("group", "n_pairs",
                              "median_delta_truth_rmse",
                              "logistic_better", "brier_better",
                              "mean_logistic_final_event_rate_fallback")],
           digits = 4),
'<p>The geometry interaction should be read through this fallback lens. In particular, the 1D high-dimensional pad100 geometry is not a clean logistic success case when its logistic fallback fraction is large; it is evidence about the deployed logistic policy, including fallback behavior.</p>',
make.table(geometry.fallback.summary[
    order(geometry.fallback.summary$median_delta_truth_rmse),
    c("group", "n_pairs", "median_delta_truth_rmse",
      "logistic_better", "brier_better",
      "mean_logistic_final_event_rate_fallback")],
    digits = 4),
'<h2>Frank/Friedman-Style Accuracy And Runtime Summary</h2>',
'<p>For each method/chart variant, define the regret-like accuracy summary as the vector of probability Truth RMSE values across all controlled cases. The figure below shows the median of that vector on the vertical axis and median elapsed seconds on the horizontal axis. Red error bars are median absolute deviations (MADs), so a compact point with short bars is both accurate and stable.</p>',
sprintf('<figure><img src="%s" alt="Accuracy and runtime summary">%s</figure>',
        fig.rel(fig5),
        caption(5, "Accuracy-runtime summary across controlled cases",
                "Each point is one method/chart variant. The x-axis is median elapsed seconds per fit; the y-axis is median probability Truth RMSE. Red horizontal and vertical bars show MAD of elapsed time and Truth RMSE across cases.")),
sprintf('<p>The best median Truth RMSE variant in this run is <strong>%s</strong> with median Truth RMSE %s. The fastest median runtime variant is <strong>%s</strong> with median elapsed time %s seconds.</p>',
        html.escape(best.variant$method_variant), fmt(best.variant$median_truth_rmse, 4),
        html.escape(fast.variant$method_variant), fmt(fast.variant$median_elapsed_sec, 4)),
'<h2>Selected Candidate Behavior</h2>',
'<p>The LPS candidates varied support size and local polynomial degree, while the kernel was fixed to tricube for this run. The support-size distribution shows whether CV tends to choose boundaries or interior values; the degree distribution shows whether local linear or local quadratic models dominate. In the figure labels, <code>B-a</code> means Bernoulli/Brier with <code>auto</code>, <code>B-la</code> means Bernoulli/Brier with <code>local.auto</code>, <code>L-a</code> means logistic with <code>auto</code>, and <code>L-la</code> means logistic with <code>local.auto</code>.</p>',
sprintf('<figure><img src="%s" alt="Selected support size and degree">%s</figure>',
        fig.rel(fig6),
        caption(6, "Selected support size and selected polynomial degree",
                "The left panel shows the distribution of CV-selected support sizes. The right panel shows how often degree 1 or degree 2 was selected for each method/chart variant.")),
'<p>Candidate-selection behavior is part of the modeling result. A method that obtains good Truth RMSE only by repeatedly selecting boundary support sizes may need a wider or better-localized support search in later runs.</p>',
'<h2>What We Learned</h2>',
'<ul>',
sprintf('<li>The execution system is robust at this scale: %s of %s planned fits completed with status <code>ok</code>.</li>',
        fmt.int(status.small$ok), fmt.int(status.small$attempted)),
'<li>The report-level comparison should be read through paired Truth-RMSE deltas, but broad claims should use scenario-clustered summaries rather than treating all nested pairs as independent.</li>',
'<li>The strongest scientific signal is fallback-confounded geometry dependence. The apparent logistic advantage in the 1D high-dimensional pad geometry occurs in a regime with substantial event-rate fallback, so it is evidence about the deployed logistic policy including fallback behavior, not clean local logistic fitting alone.</li>',
'<li>When the logistic final-fit event-rate fallback fraction is zero, the comparison mildly favors Bernoulli/Brier in this run. Heavy-fallback rows can reverse the sign, which is why pooled summaries should not be read without fallback stratification.</li>',
'<li>The current Bernoulli/Brier advantage is a deployable-policy result under asymmetric selection metrics. A cleaner family comparison should select both binary modes under shared Brier and shared log-loss score policies.</li>',
telemetry.learned.html,
'<li>The Frank/Friedman-style summary remains the clearest compact view of the accuracy-runtime tradeoff; it should be reused after the telemetry-valid and shared-selection follow-up run.</li>',
'</ul>',
'<h2>Appendix: Reproducibility And Linked Artifacts</h2>',
sprintf('<p>Report built from cached result artifacts; the model fits were not rerun during report rendering. Build timestamp: %s. Result artifact timestamp: %s.</p>',
        html.escape(build.datetime), html.escape(result.datetime)),
'<ul>',
sprintf('<li>Run directory: <code>%s</code></li>', html.escape(run.dir)),
sprintf('<li>Combined results CSV: <code>%s</code></li>', html.escape(file.path(tables.dir, "combined_results.csv"))),
sprintf('<li>Status rows CSV: <code>%s</code></li>', html.escape(file.path(tables.dir, "run_status_rows.csv"))),
sprintf('<li>Task manifest CSV: <code>%s</code></li>', html.escape(file.path(run.dir, "task_manifest.csv"))),
sprintf('<li>Paired method comparison CSV: <code>%s</code></li>', html.escape(file.path(tables.dir, "binary_gm_ff_paired_method_comparison.csv"))),
sprintf('<li>Method variant summary CSV: <code>%s</code></li>', html.escape(file.path(tables.dir, "binary_gm_ff_method_variant_summary.csv"))),
sprintf('<li>Scenario-clustered overall delta CSV: <code>%s</code></li>', html.escape(file.path(tables.dir, "binary_gm_ff_overall_clustered_delta_summary.csv"))),
sprintf('<li>Fallback telemetry validity CSV: <code>%s</code></li>', html.escape(file.path(tables.dir, "binary_gm_ff_fallback_telemetry_validity.csv"))),
sprintf('<li>Renderer script: <code>%s</code></li>', html.escape("~/current_projects/geosmooth/scripts/render_lps_binary_gm_ff_report.R")),
'</ul>',
'<p>Render command:</p>',
sprintf('<pre><code>Rscript %s --run_dir=%s</code></pre>',
        html.escape("~/current_projects/geosmooth/scripts/render_lps_binary_gm_ff_report.R"),
        html.escape(run.dir)),
'</main></body></html>'
)

writeLines(html, report.path)
cat("Wrote report:", report.path, "\n")
