#!/usr/bin/env Rscript

repo.dir <- normalizePath("/Users/pgajer/current_projects/geosmooth",
                          mustWork = TRUE)
freeze.dir <- file.path(
  repo.dir,
  "split_handoffs",
  "lps_local_auto_nonmanifold_first_batch_2026-06-05"
)
run.dir <- file.path(
  freeze.dir,
  "runs",
  "lps_local_auto_fb_20260605_001"
)
out.dir <- file.path(
  repo.dir,
  "split_handoffs",
  "ps_lps_s1_lambda_ridge_sensitivity_2026-06-05"
)
result.dir <- file.path(out.dir, "results")
table.dir <- file.path(out.dir, "tables")
fig.dir <- file.path(out.dir, "figures")
dir.create(result.dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table.dir, recursive = TRUE, showWarnings = FALSE)
dir.create(fig.dir, recursive = TRUE, showWarnings = FALSE)

need <- c("ggplot2", "htmltools", "parallel", "pkgload")
missing <- need[!vapply(need, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Missing required packages: ", paste(missing, collapse = ", "),
       call. = FALSE)
}
pkgload::load_all(repo.dir, quiet = TRUE)

safe.id <- function(x) gsub("[^A-Za-z0-9_]+", "_", x)
rmse <- function(x, y) sqrt(mean((as.numeric(x) - as.numeric(y))^2))
read.csv.safe <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}
write.csv.safe <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
}
fmt <- function(x, digits = 5) {
  ifelse(is.finite(x), formatC(x, digits = digits, format = "fg"), "")
}
lambda.label <- function(x) {
  ifelse(
    x == 0,
    "0",
    formatC(x, digits = 8, format = "fg", flag = "#")
  )
}

lambda.sync.grid <- as.numeric(strsplit(
  Sys.getenv("PS_LPS_S1_LAMBDA_SYNC_GRID", "0,0.01,0.03,0.1,0.3,1,3,10"),
  ","
)[[1L]])
lambda.ridge.grid <- as.numeric(strsplit(
  Sys.getenv("PS_LPS_S1_LAMBDA_RIDGE_GRID", "0,1e-10,1e-8,1e-6"),
  ","
)[[1L]])
sync.neighbor.size <- as.integer(Sys.getenv("PS_LPS_SYNC_NEIGHBOR_SIZE", "3"))
s1.workers <- max(1L, as.integer(Sys.getenv("PS_LPS_S1_WORKERS", "1")))

asset.manifest <- read.csv.safe(file.path(freeze.dir, "asset_manifest.csv"))
asset.manifest <- asset.manifest[order(asset.manifest[["batch.id"]]), ]

load.source.lps <- function(batch.id, dataset.id, rule) {
  file.rule <- gsub("\\.", "_", rule)
  readRDS(file.path(
    run.dir,
    "results",
    sprintf("%s__%s__chart_%s.rds", batch.id, safe.id(dataset.id), file.rule)
  ))
}

run.grid.one <- function(asset.row, rule, lambda.ridge) {
  batch.id <- asset.row[["batch.id"]]
  dataset.id <- asset.row[["dataset.id"]]
  ridge.id <- gsub("[^A-Za-z0-9]+", "_", format(lambda.ridge, scientific = TRUE))
  result.path <- file.path(
    result.dir,
    sprintf("%s__%s__%s__ridge_%s.rds",
            batch.id, safe.id(dataset.id), gsub("\\.", "_", rule), ridge.id)
  )
  if (file.exists(result.path) && !identical(Sys.getenv("PS_LPS_FORCE"), "1")) {
    return(readRDS(result.path))
  }

  asset <- readRDS(asset.row[["asset.path"]])
  lps.result <- load.source.lps(batch.id, dataset.id, rule)
  chart.dim <- if (identical(rule, "auto")) {
    lps.result$selected$chart.dim[[1L]]
  } else if (!is.null(lps.result$chart_dim_by_eval)) {
    lps.result$chart_dim_by_eval
  } else {
    lps.result$chart.dim.by.eval
  }
  chart.dim.by.anchor <- .ps.lps.prepare.chart.dim(
    chart.dim = chart.dim,
    n = nrow(asset$X),
    p = ncol(asset$X)
  )
  frames <- .ps.lps.prepare.frames(
    X = asset$X,
    y = asset$y,
    support.size = lps.result$selected$support.size[[1L]],
    degree = lps.result$selected$degree[[1L]],
    kernel = lps.result$selected$kernel[[1L]],
    chart.dim.by.anchor = chart.dim.by.anchor
  )
  sync.rows <- .ps.lps.prepare.sync.rows(
    frames = frames,
    sync.neighbor.size = sync.neighbor.size,
    overlap.weight = "normalized.product"
  )

  rows <- vector("list", length(lambda.sync.grid))
  t0 <- proc.time()
  for (ll in seq_along(lambda.sync.grid)) {
    lambda.sync <- lambda.sync.grid[[ll]]
    pred <- rep(NA_real_, length(asset$y))
    status <- "ok"
    error <- NA_character_
    fold.elapsed <- NA_real_
    fit.full <- NULL
    t.lambda <- proc.time()
    try.result <- tryCatch({
      for (fold in sort(unique(asset$foldid))) {
        response.weights <- as.numeric(asset$foldid != fold)
        fit.fold <- .ps.lps.solve(
          frames = frames,
          y = asset$y,
          response.weights = response.weights,
          lambda.sync = lambda.sync,
          lambda.ridge = lambda.ridge,
          sync.rows = sync.rows
        )
        pred[asset$foldid == fold] <- fit.fold$fitted.values[
          asset$foldid == fold
        ]
      }
      fit.full <- .ps.lps.solve(
        frames = frames,
        y = asset$y,
        response.weights = rep(1, length(asset$y)),
        lambda.sync = lambda.sync,
        lambda.ridge = lambda.ridge,
        sync.rows = sync.rows
      )
      TRUE
    }, error = function(e) {
      status <<- "error"
      error <<- conditionMessage(e)
      FALSE
    })
    fold.elapsed <- unname((proc.time() - t.lambda)[["elapsed"]])
    if (identical(status, "error") || !isTRUE(try.result)) {
      rows[[ll]] <- data.frame(
        batch_id = batch.id,
        dataset_id = dataset.id,
        chart_dim_rule = rule,
        lambda_ridge = lambda.ridge,
        lambda_sync = lambda.sync,
        status = status,
        error = error,
        support_size = lps.result$selected$support.size[[1L]],
        degree = lps.result$selected$degree[[1L]],
        kernel = lps.result$selected$kernel[[1L]],
        chart_dim_summary = if (length(unique(chart.dim.by.anchor)) == 1L) {
          unique(chart.dim.by.anchor)
        } else {
          stats::median(chart.dim.by.anchor)
        },
        cv_rmse_observed = NA_real_,
        observed_rmse = NA_real_,
        truth_rmse = NA_real_,
        total_local_gcv = NA_real_,
        sync_energy = NA_real_,
        mean_sync_squared_disagreement = NA_real_,
        ridge_median = NA_real_,
        ridge_max = NA_real_,
        elapsed_sec = fold.elapsed,
        stringsAsFactors = FALSE
      )
      next
    }
    rows[[ll]] <- data.frame(
      batch_id = batch.id,
      dataset_id = dataset.id,
      chart_dim_rule = rule,
      lambda_ridge = lambda.ridge,
      lambda_sync = lambda.sync,
      status = status,
      error = NA_character_,
      support_size = lps.result$selected$support.size[[1L]],
      degree = lps.result$selected$degree[[1L]],
      kernel = lps.result$selected$kernel[[1L]],
      chart_dim_summary = if (length(unique(chart.dim.by.anchor)) == 1L) {
        unique(chart.dim.by.anchor)
      } else {
        stats::median(chart.dim.by.anchor)
      },
      cv_rmse_observed = rmse(pred, asset$y),
      observed_rmse = rmse(fit.full$fitted.values, asset$y),
      truth_rmse = rmse(fit.full$fitted.values, asset$f),
      total_local_gcv = fit.full$total.local.gcv.ps,
      sync_energy = fit.full$sync.energy,
      mean_sync_squared_disagreement = fit.full$mean.sync.squared.disagreement,
      ridge_median = fit.full$ridge.median,
      ridge_max = fit.full$ridge.max,
      elapsed_sec = fold.elapsed,
      stringsAsFactors = FALSE
    )
  }
  candidate.table <- do.call(rbind, rows)
  ok <- candidate.table$status == "ok" & is.finite(candidate.table$cv_rmse_observed)
  selected <- if (any(ok)) {
    candidate.table[ok, ][order(candidate.table$cv_rmse_observed[ok],
                                candidate.table$lambda_sync[ok]), ][1L, ,
                                                                    drop = FALSE]
  } else {
    candidate.table[1L, , drop = FALSE]
  }
  out <- list(
    status = if (any(ok)) "ok" else "error",
    batch_id = batch.id,
    dataset_id = dataset.id,
    chart_dim_rule = rule,
    lambda_ridge = lambda.ridge,
    selected = selected,
    candidate_table = candidate.table,
    elapsed_sec = unname((proc.time() - t0)[["elapsed"]])
  )
  saveRDS(out, result.path)
  out
}

task.grid <- expand.grid(
  asset_index = seq_len(nrow(asset.manifest)),
  chart_dim_rule = c("auto", "local.auto"),
  lambda_ridge = lambda.ridge.grid,
  KEEP.OUT.ATTRS = FALSE,
  stringsAsFactors = FALSE
)
task.grid <- task.grid[order(task.grid$asset_index,
                             task.grid$chart_dim_rule,
                             task.grid$lambda_ridge), ]
task.keys <- sprintf(
  "%s__%s__%s",
  asset.manifest[["batch.id"]][task.grid$asset_index],
  task.grid$chart_dim_rule,
  format(task.grid$lambda_ridge, scientific = TRUE)
)

run.task <- function(ii) {
  aa <- task.grid$asset_index[[ii]]
  rule <- task.grid$chart_dim_rule[[ii]]
  lambda.ridge <- task.grid$lambda_ridge[[ii]]
  message(sprintf("[%s] %s ridge=%s",
                  asset.manifest[["batch.id"]][[aa]],
                  rule,
                  format(lambda.ridge, scientific = TRUE)))
  run.grid.one(asset.manifest[aa, ], rule, lambda.ridge)
}

message(sprintf("Running %d S1 blocks with %d worker(s).",
                nrow(task.grid), s1.workers))
if (s1.workers > 1L && .Platform$OS.type != "windows") {
  results <- parallel::mclapply(seq_len(nrow(task.grid)), run.task,
                                mc.cores = s1.workers,
                                mc.preschedule = FALSE)
} else {
  results <- lapply(seq_len(nrow(task.grid)), run.task)
}
names(results) <- task.keys

candidate.table <- do.call(rbind, lapply(results, `[[`, "candidate_table"))
candidate.table$requested_zero_ridge_fallback <-
  candidate.table$lambda_ridge == 0 &
  is.finite(candidate.table$ridge_max) &
  candidate.table$ridge_max > 0
write.csv.safe(candidate.table,
               file.path(table.dir, "ps_lps_s1_candidate_grid.csv"))

selected.table <- do.call(rbind, lapply(results, `[[`, "selected"))
selected.table$selected_by_cv <- TRUE
selected.table$requested_zero_ridge_fallback <-
  selected.table$lambda_ridge == 0 &
  is.finite(selected.table$ridge_max) &
  selected.table$ridge_max > 0
write.csv.safe(selected.table,
               file.path(table.dir, "ps_lps_s1_selected_by_cv.csv"))

baseline.table <- candidate.table[
  candidate.table$lambda_sync == 0 &
    candidate.table$status == "ok",
  c("batch_id", "dataset_id", "chart_dim_rule", "lambda_ridge", "truth_rmse",
    "cv_rmse_observed", "total_local_gcv", "sync_energy",
    "mean_sync_squared_disagreement"),
  drop = FALSE
]
names(baseline.table) <- c("batch_id", "dataset_id", "chart_dim_rule",
                           "lambda_ridge", "baseline_truth_rmse",
                           "baseline_cv_rmse_observed",
                           "baseline_total_local_gcv",
                           "baseline_sync_energy",
                           "baseline_mean_sync_squared_disagreement")
selected.delta <- merge(
  selected.table,
  baseline.table,
  by = c("batch_id", "dataset_id", "chart_dim_rule", "lambda_ridge"),
  all.x = TRUE,
  sort = FALSE
)
selected.delta$truth_rmse_delta_vs_matched_baseline <-
  selected.delta$truth_rmse - selected.delta$baseline_truth_rmse
selected.delta$cv_rmse_delta_vs_matched_baseline <-
  selected.delta$cv_rmse_observed - selected.delta$baseline_cv_rmse_observed
write.csv.safe(selected.delta,
               file.path(table.dir, "ps_lps_s1_selected_delta_vs_baseline.csv"))

summary.table <- aggregate(
  truth_rmse_delta_vs_matched_baseline ~ chart_dim_rule + lambda_ridge,
  selected.delta,
  function(x) stats::median(x[is.finite(x)])
)
names(summary.table)[[3L]] <- "median_truth_rmse_delta"
summary.table$wins <- aggregate(
  truth_rmse_delta_vs_matched_baseline ~ chart_dim_rule + lambda_ridge,
  selected.delta,
  function(x) sum(is.finite(x) & x < 0)
)$truth_rmse_delta_vs_matched_baseline
summary.table$n <- aggregate(
  truth_rmse_delta_vs_matched_baseline ~ chart_dim_rule + lambda_ridge,
  selected.delta,
  function(x) sum(is.finite(x))
)$truth_rmse_delta_vs_matched_baseline
summary.table$selected_lambda_sync_median <- aggregate(
  lambda_sync ~ chart_dim_rule + lambda_ridge,
  selected.delta,
  function(x) stats::median(x[is.finite(x)])
)$lambda_sync
write.csv.safe(summary.table,
               file.path(table.dir, "ps_lps_s1_summary_by_rule_ridge.csv"))

fallback.summary <- aggregate(
  requested_zero_ridge_fallback ~ chart_dim_rule + lambda_ridge,
  candidate.table,
  function(x) sum(x %in% TRUE)
)
names(fallback.summary)[[3L]] <- "candidate_fallback_count"
fallback.summary$candidate_n <- aggregate(
  requested_zero_ridge_fallback ~ chart_dim_rule + lambda_ridge,
  candidate.table,
  length
)$requested_zero_ridge_fallback
fallback.summary$selected_fallback_count <- aggregate(
  requested_zero_ridge_fallback ~ chart_dim_rule + lambda_ridge,
  selected.table,
  function(x) sum(x %in% TRUE)
)$requested_zero_ridge_fallback
fallback.summary$selected_n <- aggregate(
  requested_zero_ridge_fallback ~ chart_dim_rule + lambda_ridge,
  selected.table,
  length
)$requested_zero_ridge_fallback
write.csv.safe(fallback.summary,
               file.path(table.dir, "ps_lps_s1_fallback_summary.csv"))

boundary.value <- max(lambda.sync.grid)
boundary.summary <- aggregate(
  lambda_sync ~ chart_dim_rule + lambda_ridge,
  selected.delta,
  function(x) sum(is.finite(x) & x == boundary.value)
)
names(boundary.summary)[[3L]] <- "boundary_selected_count"
boundary.summary$selected_n <- aggregate(
  lambda_sync ~ chart_dim_rule + lambda_ridge,
  selected.delta,
  function(x) sum(is.finite(x))
)$lambda_sync
boundary.summary$boundary_fraction <-
  boundary.summary$boundary_selected_count / boundary.summary$selected_n
boundary.summary$boundary_value <- boundary.value
write.csv.safe(boundary.summary,
               file.path(table.dir, "ps_lps_s1_boundary_selection_summary.csv"))

theme.report <- ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    legend.position = "bottom",
    plot.title.position = "plot"
  )

candidate.table$lambda_sync_label <- factor(
  lambda.label(candidate.table$lambda_sync),
  levels = unique(lambda.label(lambda.sync.grid))
)
candidate.table$lambda_ridge_label <- factor(
  lambda.label(candidate.table$lambda_ridge),
  levels = unique(lambda.label(lambda.ridge.grid))
)
selected.delta$lambda_ridge_label <- factor(
  lambda.label(selected.delta$lambda_ridge),
  levels = unique(lambda.label(lambda.ridge.grid))
)
selected.delta$lambda_sync_label <- factor(
  lambda.label(selected.delta$lambda_sync),
  levels = unique(lambda.label(lambda.sync.grid))
)
summary.table$lambda_ridge_label <- factor(
  lambda.label(summary.table$lambda_ridge),
  levels = unique(lambda.label(lambda.ridge.grid))
)

p.selected <- ggplot2::ggplot(
  selected.delta,
  ggplot2::aes(x = lambda_ridge_label, y = lambda_sync_label,
               color = truth_rmse_delta_vs_matched_baseline)
) +
  ggplot2::geom_hline(yintercept = which(levels(selected.delta$lambda_sync_label) == "0"),
                      color = "grey80") +
  ggplot2::geom_point(size = 2.5, alpha = 0.9) +
  ggplot2::scale_color_gradient2(
    low = "#2b8cbe",
    mid = "white",
    high = "#d7301f",
    midpoint = 0
  ) +
  ggplot2::facet_wrap(~ chart_dim_rule, nrow = 1) +
  ggplot2::labs(
    title = "S1 selected synchronization and ridge scales",
    subtitle = "Color is selected Truth RMSE minus matched lambda.sync = 0 baseline; blue is better.",
    x = "lambda.ridge",
    y = "lambda.sync",
    color = "Truth RMSE delta"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_s1_selected_lambda_ridge.png"),
                p.selected, width = 10, height = 5.5, dpi = 180)

p.delta <- ggplot2::ggplot(
  selected.delta,
  ggplot2::aes(x = lambda_ridge_label,
               y = truth_rmse_delta_vs_matched_baseline,
               color = chart_dim_rule)
) +
  ggplot2::geom_hline(yintercept = 0, color = "grey55") +
  ggplot2::geom_point(size = 2, alpha = 0.85,
                      position = ggplot2::position_jitter(width = 0.08,
                                                          height = 0)) +
  ggplot2::stat_summary(fun = median, geom = "line",
                        ggplot2::aes(group = chart_dim_rule),
                        linewidth = 0.9) +
  ggplot2::labs(
    title = "S1 selected Truth-RMSE deltas versus matched baseline",
    subtitle = "Each point is one dataset; lines are medians by chart rule.",
    x = "lambda.ridge",
    y = "Selected Truth RMSE minus matched baseline Truth RMSE",
    color = "Chart rule"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_s1_delta_vs_ridge.png"),
                p.delta, width = 10, height = 6, dpi = 180)

candidate.ok <- candidate.table[
  candidate.table$status == "ok" & is.finite(candidate.table$truth_rmse),
  ,
  drop = FALSE
]
p.surface <- ggplot2::ggplot(
  candidate.ok,
  ggplot2::aes(x = lambda_sync_label, y = truth_rmse, color = lambda_ridge_label)
) +
  ggplot2::geom_line(ggplot2::aes(group = interaction(batch_id, lambda_ridge_label)),
                     alpha = 0.35, linewidth = 0.35) +
  ggplot2::stat_summary(fun = median, geom = "line",
                        ggplot2::aes(group = lambda_ridge_label),
                        linewidth = 1.1) +
  ggplot2::facet_wrap(~ chart_dim_rule, scales = "free_y", nrow = 1) +
  ggplot2::labs(
    title = "S1 candidate Truth RMSE across synchronization grid",
    subtitle = "Thin lines are datasets; thick lines are medians at each ridge scale.",
    x = "lambda.sync",
    y = "Truth RMSE",
    color = "lambda.ridge"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_s1_candidate_truth_rmse_profiles.png"),
                p.surface, width = 12, height = 5.5, dpi = 180)

p.summary <- ggplot2::ggplot(
  summary.table,
  ggplot2::aes(x = lambda_ridge_label, y = median_truth_rmse_delta,
               fill = chart_dim_rule)
) +
  ggplot2::geom_hline(yintercept = 0, color = "grey55") +
  ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.75),
                    width = 0.65) +
  ggplot2::geom_text(
    ggplot2::aes(label = paste0(wins, "/", n)),
    position = ggplot2::position_dodge(width = 0.75),
    vjust = ifelse(summary.table$median_truth_rmse_delta < 0, 1.35, -0.35),
    size = 3.2
  ) +
  ggplot2::labs(
    title = "S1 median selected Truth-RMSE delta by ridge scale",
    subtitle = "Labels show dataset-wise wins over the matched lambda.sync = 0 baseline.",
    x = "lambda.ridge",
    y = "Median selected Truth RMSE delta",
    fill = "Chart rule"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_s1_summary_by_ridge.png"),
                p.summary, width = 10, height = 6, dpi = 180)

table.html <- function(df, max.rows = 80L) {
  df <- head(df, max.rows)
  htmltools::tags$table(
    class = "data-table",
    htmltools::tags$thead(
      htmltools::tags$tr(lapply(names(df), htmltools::tags$th))
    ),
    htmltools::tags$tbody(lapply(seq_len(nrow(df)), function(ii) {
      htmltools::tags$tr(lapply(df[ii, , drop = FALSE], function(x) {
        htmltools::tags$td(as.character(x[[1L]]))
      }))
    }))
  )
}

css <- "
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 32px; color: #1f2933; line-height: 1.45; }
h1, h2 { line-height: 1.15; }
.note { max-width: 1040px; }
.figure { margin: 24px 0 30px; }
.figure img { max-width: 100%; border: 1px solid #ddd; }
.caption { font-size: 0.94rem; color: #53606c; max-width: 1040px; }
.data-table { border-collapse: collapse; font-size: 0.88rem; margin: 12px 0 24px; }
.data-table th, .data-table td { border: 1px solid #ddd; padding: 5px 7px; text-align: right; }
.data-table th:first-child, .data-table td:first-child, .data-table th:nth-child(2), .data-table td:nth-child(2) { text-align: left; }
code { background: #f3f4f6; padding: 1px 4px; border-radius: 3px; }
"

report <- htmltools::tagList(
  htmltools::tags$html(
    htmltools::tags$head(
      htmltools::tags$title("PS-LPS-S1 Lambda/Ridge Sensitivity"),
      htmltools::tags$style(css),
      htmltools::tags$script(
        src = "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js",
        async = NA
      )
    ),
    htmltools::tags$body(
      htmltools::tags$h1("PS-LPS-S1 Lambda/Ridge Sensitivity"),
      htmltools::tags$p(
        class = "note",
        "This report uses the frozen first-batch LPS-selected support, kernel, ",
        "degree, and chart rules, then varies only ",
        htmltools::HTML("\\(\\lambda_{\\mathrm{sync}}\\)"),
        " and ",
        htmltools::HTML("\\(\\lambda_{\\mathrm{ridge}}\\)"),
        ". Every selected PS-LPS fit is compared to the matched ",
        htmltools::HTML("\\(\\lambda_{\\mathrm{sync}}=0\\)"),
        " baseline at the same ridge scale."
      ),
      htmltools::tags$p(
        class = "note",
        sprintf("lambda.sync grid: {%s}.", paste(lambda.sync.grid, collapse = ", ")),
        " ",
        sprintf("lambda.ridge grid: {%s}.", paste(lambda.ridge.grid, collapse = ", ")),
        " ",
        sprintf("sync.neighbor.size = %d.", sync.neighbor.size)
      ),
      htmltools::tags$h2("Selected Scales"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(
          src = file.path("figures", "ps_lps_s1_selected_lambda_ridge.png")
        ),
        htmltools::tags$p(
          class = "caption",
          "Each point is a dataset/ridge/chart-rule selected candidate. ",
          "Blue means selected PS-LPS improves over the matched zero-sync baseline."
        )
      ),
      htmltools::tags$h2("Matched-Baseline Deltas"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures", "ps_lps_s1_delta_vs_ridge.png")),
        htmltools::tags$p(
          class = "caption",
          "Negative values are improvements over the matched baseline."
        )
      ),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures", "ps_lps_s1_summary_by_ridge.png")),
        htmltools::tags$p(
          class = "caption",
          "Bars show median selected Truth-RMSE delta; labels show wins over ",
          "the matched zero-sync baseline."
        )
      ),
      htmltools::tags$h2("Candidate Profiles"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(
          src = file.path("figures", "ps_lps_s1_candidate_truth_rmse_profiles.png")
        ),
        htmltools::tags$p(
          class = "caption",
          "Candidate-level Truth RMSE over the synchronization grid."
        )
      ),
      htmltools::tags$h2("Summary Table"),
      table.html(transform(
        summary.table[, c("chart_dim_rule", "lambda_ridge",
                          "median_truth_rmse_delta", "wins", "n",
                          "selected_lambda_sync_median")],
        median_truth_rmse_delta = fmt(median_truth_rmse_delta),
        selected_lambda_sync_median = fmt(selected_lambda_sync_median)
      )),
      htmltools::tags$h2("Boundary and Fallback Summaries"),
      htmltools::tags$p(
        class = "note",
        "The boundary table counts selected candidates whose ",
        htmltools::HTML("\\(\\lambda_{\\mathrm{sync}}\\)"),
        " is the largest value in the tested grid. The fallback table counts ",
        "requested zero-ridge rows where the numerical solver used a positive ",
        "fallback ridge; positive requested ridge rows are not counted as ",
        "fallbacks."
      ),
      htmltools::tags$h3("Boundary Selection Summary"),
      table.html(transform(
        boundary.summary[, c("chart_dim_rule", "lambda_ridge",
                             "boundary_value", "boundary_selected_count",
                             "selected_n", "boundary_fraction")],
        boundary_fraction = fmt(boundary_fraction)
      )),
      htmltools::tags$h3("Requested Zero-Ridge Fallback Summary"),
      table.html(fallback.summary[, c("chart_dim_rule", "lambda_ridge",
                                      "candidate_fallback_count",
                                      "candidate_n",
                                      "selected_fallback_count",
                                      "selected_n")]),
      htmltools::tags$h2("Tables"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_s1_candidate_grid.csv"),
          "Candidate grid table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_s1_selected_by_cv.csv"),
          "Selected-by-CV table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_s1_selected_delta_vs_baseline.csv"),
          "Selected delta versus matched baseline table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_s1_summary_by_rule_ridge.csv"),
          "Summary by chart rule and ridge scale"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_s1_boundary_selection_summary.csv"),
          "Boundary selection summary table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_s1_fallback_summary.csv"),
          "Requested zero-ridge fallback summary table"
        ))
      )
    )
  )
)

report.path <- file.path(out.dir, "ps_lps_s1_lambda_ridge_sensitivity_report.html")
htmltools::save_html(report, report.path)
message("Wrote ", report.path)
