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
  "ps_lps_first_batch_refined_experiment_2026-06-05"
)
result.dir <- file.path(out.dir, "results")
table.dir <- file.path(out.dir, "tables")
fig.dir <- file.path(out.dir, "figures")
dir.create(result.dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table.dir, recursive = TRUE, showWarnings = FALSE)
dir.create(fig.dir, recursive = TRUE, showWarnings = FALSE)

need <- c("ggplot2", "htmltools", "pkgload")
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

lambda.grid <- as.numeric(strsplit(
  Sys.getenv("PS_LPS_LAMBDA_GRID", "0,0.1,1"),
  ","
)[[1L]])
lambda.ridge <- as.numeric(Sys.getenv("PS_LPS_LAMBDA_RIDGE", "1e-8"))
sync.neighbor.size <- as.integer(Sys.getenv("PS_LPS_SYNC_NEIGHBOR_SIZE", "3"))

asset.manifest <- read.csv.safe(file.path(freeze.dir, "asset_manifest.csv"))
asset.manifest <- asset.manifest[order(asset.manifest[["batch.id"]]), ]
ordinary <- read.csv.safe(file.path(run.dir, "tables", "combined_results.csv"))

variant.rule <- function(variant) {
  if (grepl("local_auto$", variant)) "local.auto" else "auto"
}
variant.method <- function(variant) {
  switch(
    variant,
    ridge_auto = "ridge-LPS auto",
    ridge_local_auto = "ridge-LPS local.auto",
    ps_auto = "PS-LPS auto",
    ps_local_auto = "PS-LPS local.auto",
    stop("unknown variant: ", variant, call. = FALSE)
  )
}
variant.lambda.grid <- function(variant) {
  if (grepl("^ridge_", variant)) 0 else lambda.grid
}

load.source.lps <- function(batch.id, dataset.id, rule) {
  file.rule <- gsub("\\.", "_", rule)
  readRDS(file.path(
    run.dir,
    "results",
    sprintf("%s__%s__chart_%s.rds", batch.id, safe.id(dataset.id), file.rule)
  ))
}

compute.ordinary.diagnostics <- function(asset.row, rule) {
  batch.id <- asset.row[["batch.id"]]
  dataset.id <- asset.row[["dataset.id"]]
  asset <- readRDS(asset.row[["asset.path"]])
  lps.result <- load.source.lps(batch.id, dataset.id, rule)
  chart.dim <- if (identical(rule, "auto")) {
    lps.result$selected$chart.dim[[1L]]
  } else {
    lps.result$chart_dim_by_eval
  }
  frames <- .ps.lps.prepare.frames(
    X = asset$X,
    y = asset$y,
    support.size = lps.result$selected$support.size[[1L]],
    degree = lps.result$selected$degree[[1L]],
    kernel = lps.result$selected$kernel[[1L]],
    chart.dim.by.anchor = .ps.lps.prepare.chart.dim(
      chart.dim = chart.dim,
      n = nrow(asset$X),
      p = ncol(asset$X)
    )
  )
  sync.rows <- .ps.lps.prepare.sync.rows(
    frames = frames,
    sync.neighbor.size = sync.neighbor.size,
    overlap.weight = "normalized.product"
  )
  diag <- .ps.lps.solve(
    frames = frames,
    y = asset$y,
    response.weights = rep(1, length(asset$y)),
    lambda.sync = 0,
    lambda.ridge = 0,
    sync.rows = sync.rows,
    coefficients.only = TRUE
  )
  data.frame(
    batch_id = batch.id,
    dataset_id = dataset.id,
    chart_dim_rule = rule,
    total_local_gcv_ps = diag$total.local.gcv.ps,
    sync_energy = diag$sync.energy,
    mean_sync_squared_disagreement = diag$mean.sync.squared.disagreement,
    ridge_median = diag$ridge.median,
    ridge_max = diag$ridge.max,
    stringsAsFactors = FALSE
  )
}

run.one <- function(asset.row, variant) {
  batch.id <- asset.row[["batch.id"]]
  dataset.id <- asset.row[["dataset.id"]]
  result.path <- file.path(
    result.dir,
    sprintf("%s__%s__%s.rds", batch.id, safe.id(dataset.id), variant)
  )
  if (file.exists(result.path) && !identical(Sys.getenv("PS_LPS_FORCE"), "1")) {
    return(readRDS(result.path))
  }

  asset <- readRDS(asset.row[["asset.path"]])
  source.rule <- variant.rule(variant)
  lps.result <- load.source.lps(batch.id, dataset.id, source.rule)
  chart.dim <- if (identical(source.rule, "auto")) {
    lps.result$selected$chart.dim[[1L]]
  } else {
    lps.result$chart_dim_by_eval
  }

  t0 <- proc.time()
  fit <- tryCatch(
    fit.ps.lps(
      X = asset$X,
      y = asset$y,
      foldid = asset$foldid,
      support.size = lps.result$selected$support.size[[1L]],
      degree = lps.result$selected$degree[[1L]],
      kernel = lps.result$selected$kernel[[1L]],
      chart.dim = chart.dim,
      lambda.sync.grid = variant.lambda.grid(variant),
      lambda.ridge = lambda.ridge,
      sync.neighbor.size = sync.neighbor.size
    ),
    error = function(e) e
  )
  elapsed <- unname((proc.time() - t0)[["elapsed"]])
  if (inherits(fit, "error")) {
    out <- list(
      status = "error",
      error = conditionMessage(fit),
      batch_id = batch.id,
      dataset_id = dataset.id,
      variant = variant,
      method = variant.method(variant),
      source_chart_dim_rule = source.rule,
      elapsed_sec = elapsed
    )
    saveRDS(out, result.path)
    return(out)
  }

  out <- list(
    status = "ok",
    batch_id = batch.id,
    dataset_id = dataset.id,
    variant = variant,
    method = variant.method(variant),
    source_chart_dim_rule = source.rule,
    elapsed_sec = elapsed,
    selected = fit$selected,
    cv.table = fit$cv.table,
    fitted.values = fit$fitted.values,
    total.local.gcv.ps = fit$total.local.gcv.ps,
    mean.local.gcv.ps = fit$mean.local.gcv.ps,
    local.gcv.ps = fit$local.gcv.ps,
    local.df.ratio = fit$local.df.ratio,
    sync.energy = fit$sync.energy,
    mean.sync.squared.disagreement = fit$mean.sync.squared.disagreement,
    support.size = fit$support.size,
    degree = fit$degree,
    kernel = fit$kernel,
    chart.dim.summary = if (length(unique(fit$chart.dim.by.anchor)) == 1L) {
      unique(fit$chart.dim.by.anchor)
    } else {
      stats::median(fit$chart.dim.by.anchor)
    },
    chart.dim.by.anchor = fit$chart.dim.by.anchor,
    ridge.min = fit$ridge.min,
    ridge.median = fit$ridge.median,
    ridge.max = fit$ridge.max,
    truth_rmse = rmse(fit$fitted.values, asset$f),
    observed_rmse = rmse(fit$fitted.values, asset$y)
  )
  saveRDS(out, result.path)
  out
}

variants <- c("ridge_auto", "ridge_local_auto", "ps_auto", "ps_local_auto")
all.results <- list()
for (aa in seq_len(nrow(asset.manifest))) {
  for (variant in variants) {
    message(sprintf(
      "[%s] running %s on %s",
      asset.manifest[["batch.id"]][[aa]],
      variant,
      asset.manifest[["dataset.id"]][[aa]]
    ))
    key <- paste(asset.manifest[["batch.id"]][[aa]], variant, sep = "__")
    all.results[[key]] <- run.one(asset.manifest[aa, ], variant)
  }
}

refined.summary <- do.call(rbind, lapply(all.results, function(x) {
  if (!identical(x$status, "ok")) {
    return(data.frame(
      batch_id = x$batch_id,
      dataset_id = x$dataset_id,
      method = x$method,
      status = x$status,
      selected_lambda_sync = NA_real_,
      lambda_ridge = lambda.ridge,
      selected_support_size = NA_integer_,
      selected_degree = NA_integer_,
      selected_kernel = NA_character_,
      selected_chart_dim = NA_real_,
      selected_cv_rmse_observed = NA_real_,
      observed_rmse = NA_real_,
      truth_rmse = NA_real_,
      total_local_gcv_ps = NA_real_,
      sync_energy = NA_real_,
      mean_sync_squared_disagreement = NA_real_,
      ridge_median = NA_real_,
      ridge_max = NA_real_,
      elapsed_sec = x$elapsed_sec,
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    batch_id = x$batch_id,
    dataset_id = x$dataset_id,
    method = x$method,
    status = x$status,
    selected_lambda_sync = x$selected$lambda.sync[[1L]],
    lambda_ridge = x$selected$lambda.ridge[[1L]],
    selected_support_size = x$support.size,
    selected_degree = x$degree,
    selected_kernel = x$kernel,
    selected_chart_dim = x$chart.dim.summary,
    selected_cv_rmse_observed = x$selected$cv.rmse.observed[[1L]],
    observed_rmse = x$observed_rmse,
    truth_rmse = x$truth_rmse,
    total_local_gcv_ps = x$total.local.gcv.ps,
    sync_energy = x$sync.energy,
    mean_sync_squared_disagreement = x$mean.sync.squared.disagreement,
    ridge_median = x$ridge.median,
    ridge_max = x$ridge.max,
    elapsed_sec = x$elapsed_sec,
    stringsAsFactors = FALSE
  )
}))

ordinary.diag <- do.call(rbind, lapply(seq_len(nrow(asset.manifest)), function(aa) {
  rbind(
    compute.ordinary.diagnostics(asset.manifest[aa, ], "auto"),
    compute.ordinary.diagnostics(asset.manifest[aa, ], "local.auto")
  )
}))
ordinary <- merge(
  ordinary,
  ordinary.diag,
  by = c("batch_id", "dataset_id", "chart_dim_rule"),
  all.x = TRUE,
  sort = FALSE
)

ordinary.summary <- rbind(
  data.frame(
    batch_id = ordinary$batch_id[ordinary$chart_dim_rule == "auto"],
    dataset_id = ordinary$dataset_id[ordinary$chart_dim_rule == "auto"],
    method = "LPS auto",
    status = "ok",
    selected_lambda_sync = NA_real_,
    lambda_ridge = 0,
    selected_support_size = ordinary$selected_support_size[
      ordinary$chart_dim_rule == "auto"
    ],
    selected_degree = ordinary$selected_degree[
      ordinary$chart_dim_rule == "auto"
    ],
    selected_kernel = ordinary$selected_kernel[
      ordinary$chart_dim_rule == "auto"
    ],
    selected_chart_dim = ordinary$resolved_chart_dim[
      ordinary$chart_dim_rule == "auto"
    ],
    selected_cv_rmse_observed = ordinary$selected_cv_rmse_observed[
      ordinary$chart_dim_rule == "auto"
    ],
    observed_rmse = ordinary$observed_rmse[ordinary$chart_dim_rule == "auto"],
    truth_rmse = ordinary$truth_rmse[ordinary$chart_dim_rule == "auto"],
    total_local_gcv_ps = ordinary$total_local_gcv_ps[
      ordinary$chart_dim_rule == "auto"
    ],
    sync_energy = ordinary$sync_energy[ordinary$chart_dim_rule == "auto"],
    mean_sync_squared_disagreement =
      ordinary$mean_sync_squared_disagreement[ordinary$chart_dim_rule == "auto"],
    ridge_median = ordinary$ridge_median[ordinary$chart_dim_rule == "auto"],
    ridge_max = ordinary$ridge_max[ordinary$chart_dim_rule == "auto"],
    elapsed_sec = ordinary$elapsed_sec[ordinary$chart_dim_rule == "auto"],
    stringsAsFactors = FALSE
  ),
  data.frame(
    batch_id = ordinary$batch_id[ordinary$chart_dim_rule == "local.auto"],
    dataset_id = ordinary$dataset_id[ordinary$chart_dim_rule == "local.auto"],
    method = "LPS local.auto",
    status = "ok",
    selected_lambda_sync = NA_real_,
    lambda_ridge = 0,
    selected_support_size = ordinary$selected_support_size[
      ordinary$chart_dim_rule == "local.auto"
    ],
    selected_degree = ordinary$selected_degree[
      ordinary$chart_dim_rule == "local.auto"
    ],
    selected_kernel = ordinary$selected_kernel[
      ordinary$chart_dim_rule == "local.auto"
    ],
    selected_chart_dim = ordinary$resolved_chart_dim[
      ordinary$chart_dim_rule == "local.auto"
    ],
    selected_cv_rmse_observed = ordinary$selected_cv_rmse_observed[
      ordinary$chart_dim_rule == "local.auto"
    ],
    observed_rmse = ordinary$observed_rmse[
      ordinary$chart_dim_rule == "local.auto"
    ],
    truth_rmse = ordinary$truth_rmse[ordinary$chart_dim_rule == "local.auto"],
    total_local_gcv_ps = ordinary$total_local_gcv_ps[
      ordinary$chart_dim_rule == "local.auto"
    ],
    sync_energy = ordinary$sync_energy[ordinary$chart_dim_rule == "local.auto"],
    mean_sync_squared_disagreement =
      ordinary$mean_sync_squared_disagreement[
        ordinary$chart_dim_rule == "local.auto"
      ],
    ridge_median = ordinary$ridge_median[
      ordinary$chart_dim_rule == "local.auto"
    ],
    ridge_max = ordinary$ridge_max[ordinary$chart_dim_rule == "local.auto"],
    elapsed_sec = ordinary$elapsed_sec[
      ordinary$chart_dim_rule == "local.auto"
    ],
    stringsAsFactors = FALSE
  )
)

comparison <- rbind(ordinary.summary, refined.summary)
method.levels <- c(
  "LPS auto", "ridge-LPS auto", "PS-LPS auto",
  "LPS local.auto", "ridge-LPS local.auto", "PS-LPS local.auto"
)
comparison$method <- factor(comparison$method, levels = method.levels)
comparison$dataset_label <- paste(comparison$batch_id, comparison$dataset_id)
comparison$best_truth_rmse <- ave(comparison$truth_rmse,
                                  comparison$batch_id, FUN = min)
comparison$truth_rmse_delta_from_best <-
  comparison$truth_rmse - comparison$best_truth_rmse
write.csv.safe(comparison,
               file.path(table.dir, "ps_lps_refined_method_comparison.csv"))
write.csv.safe(refined.summary,
               file.path(table.dir, "ps_lps_refined_summary.csv"))

lambda.rows <- do.call(rbind, lapply(all.results, function(x) {
  if (!identical(x$status, "ok")) return(NULL)
  tab <- x$cv.table
  tab$batch_id <- x$batch_id
  tab$dataset_id <- x$dataset_id
  tab$method <- x$method
  tab[, c("batch_id", "dataset_id", "method",
          setdiff(names(tab), c("batch_id", "dataset_id", "method")))]
}))
write.csv.safe(lambda.rows,
               file.path(table.dir, "ps_lps_refined_lambda_cv_gcv_table.csv"))

pointwise <- list()
for (aa in seq_len(nrow(asset.manifest))) {
  batch.id <- asset.manifest[["batch.id"]][[aa]]
  dataset.id <- asset.manifest[["dataset.id"]][[aa]]
  asset <- readRDS(asset.manifest[["asset.path"]][[aa]])
  auto <- load.source.lps(batch.id, dataset.id, "auto")
  e.auto <- as.numeric(auto$predictions - asset$f)
  r.auto <- sqrt(mean(e.auto^2))
  for (variant in variants) {
    key <- paste(batch.id, variant, sep = "__")
    res <- all.results[[key]]
    if (!identical(res$status, "ok")) next
    e.method <- as.numeric(res$fitted.values - asset$f)
    r.method <- sqrt(mean(e.method^2))
    denom <- length(e.method) * (r.method + r.auto)
    comp <- if (is.finite(denom) && denom > 0) {
      (e.method^2 - e.auto^2) / denom
    } else {
      rep(0, length(e.method))
    }
    pointwise[[paste(key, "pointwise", sep = "__")]] <- data.frame(
      batch_id = batch.id,
      dataset_id = dataset.id,
      method = res$method,
      point = seq_along(comp),
      error_lps_auto = e.auto,
      error_method = e.method,
      rmse_component_vs_lps_auto = comp,
      local_gcv_ps = res$local.gcv.ps,
      local_df_ratio = res$local.df.ratio,
      stringsAsFactors = FALSE
    )
  }
}
pointwise <- do.call(rbind, pointwise)
write.csv.safe(pointwise,
               file.path(table.dir, "ps_lps_refined_pointwise_components.csv"))

make.delta.table <- function(comparison) {
  source.rows <- comparison[
    comparison$method %in% c("LPS auto", "LPS local.auto",
                             "ridge-LPS auto", "ridge-LPS local.auto"),
    c("batch_id", "method", "truth_rmse"),
    drop = FALSE
  ]
  names(source.rows) <- c("batch_id", "source_method", "source_truth_rmse")

  refined <- comparison[comparison$method %in% c(
    "ridge-LPS auto", "ridge-LPS local.auto", "PS-LPS auto", "PS-LPS local.auto"
  ), , drop = FALSE]
  refined$source_method <- ifelse(grepl("local\\.auto", refined$method),
                                  "LPS local.auto", "LPS auto")
  out <- merge(refined, source.rows,
               by = c("batch_id", "source_method"),
               all.x = TRUE, sort = FALSE)
  out$delta_type <- "versus ordinary LPS"
  out$truth_rmse_delta <- out$truth_rmse - out$source_truth_rmse

  ps <- comparison[comparison$method %in% c("PS-LPS auto", "PS-LPS local.auto"),
                   , drop = FALSE]
  ps$source_method <- ifelse(grepl("local\\.auto", ps$method),
                             "ridge-LPS local.auto", "ridge-LPS auto")
  ps <- merge(ps, source.rows,
              by = c("batch_id", "source_method"),
              all.x = TRUE, sort = FALSE)
  ps$delta_type <- "versus ridge-LPS"
  ps$truth_rmse_delta <- ps$truth_rmse - ps$source_truth_rmse
  rbind(out, ps)
}
delta.table <- make.delta.table(comparison)
write.csv.safe(delta.table,
               file.path(table.dir, "ps_lps_refined_delta_table.csv"))
matched.win.summary <- aggregate(
  truth_rmse_delta ~ method,
  delta.table[delta.table$delta_type == "versus ridge-LPS", , drop = FALSE],
  function(x) sum(is.finite(x) & x < 0)
)
names(matched.win.summary)[[2L]] <- "wins_vs_matched_ridge_lps"
matched.win.summary$n_datasets <- aggregate(
  truth_rmse_delta ~ method,
  delta.table[delta.table$delta_type == "versus ridge-LPS", , drop = FALSE],
  function(x) sum(is.finite(x))
)$truth_rmse_delta
write.csv.safe(matched.win.summary,
               file.path(table.dir, "ps_lps_refined_matched_ridge_win_counts.csv"))

theme.report <- ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    legend.position = "bottom",
    plot.title.position = "plot"
  )

p.truth <- ggplot2::ggplot(
  comparison,
  ggplot2::aes(x = method, y = truth_rmse, group = dataset_label)
) +
  ggplot2::geom_line(color = "grey72", linewidth = 0.35) +
  ggplot2::geom_point(ggplot2::aes(color = method), size = 2.1) +
  ggplot2::facet_wrap(~ batch_id, scales = "free_y", ncol = 4) +
  ggplot2::labs(
    title = "Truth RMSE: ordinary LPS, ridge-LPS, and PS-LPS",
    x = NULL,
    y = "Truth RMSE"
  ) +
  theme.report +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 38, hjust = 1))
ggplot2::ggsave(file.path(fig.dir, "ps_lps_refined_truth_rmse_comparison.png"),
                p.truth, width = 13, height = 8, dpi = 180)

p.delta <- ggplot2::ggplot(
  delta.table,
  ggplot2::aes(x = method, y = truth_rmse_delta, color = method)
) +
  ggplot2::geom_hline(yintercept = 0, color = "grey55") +
  ggplot2::geom_linerange(
    ggplot2::aes(ymin = 0, ymax = truth_rmse_delta),
    color = "grey75",
    linewidth = 0.4
  ) +
  ggplot2::geom_point(size = 2.2, alpha = 0.9) +
  ggplot2::facet_grid(delta_type ~ batch_id, scales = "free_y") +
  ggplot2::labs(
    title = "Truth-RMSE deltas separate ridge effect from synchronization effect",
    subtitle = "Negative values mean the row method improves over the stated reference.",
    x = NULL,
    y = "Truth RMSE delta"
  ) +
  theme.report +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 38, hjust = 1))
ggplot2::ggsave(file.path(fig.dir, "ps_lps_refined_delta_decomposition.png"),
                p.delta, width = 13, height = 7, dpi = 180)

selected.refined <- comparison[grepl("^(ridge|PS)-LPS",
                                     as.character(comparison$method)),
                               , drop = FALSE]
selected.refined$lambda_label <- paste0(
  "lambda.sync = ", selected.refined$selected_lambda_sync
)
p.gcv.truth <- ggplot2::ggplot(
  selected.refined,
  ggplot2::aes(x = total_local_gcv_ps, y = truth_rmse, color = method,
               shape = lambda_label)
) +
  ggplot2::geom_point(size = 2.4, alpha = 0.9) +
  ggplot2::geom_text(
    ggplot2::aes(label = batch_id),
    nudge_y = 0.002,
    size = 2.7,
    show.legend = FALSE
  ) +
  ggplot2::scale_x_log10() +
  ggplot2::labs(
    title = "Selected total local GCV versus Truth RMSE",
    subtitle = "Ridge-LPS uses lambda.sync = 0; PS-LPS tunes lambda.sync by CV.",
    x = "Total local GCV after solving selected chart system (log scale)",
    y = "Truth RMSE",
    color = NULL,
    shape = NULL
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_refined_total_gcv_vs_truth_rmse.png"),
                p.gcv.truth, width = 9.5, height = 6, dpi = 180)

gcv.lm.data <- comparison[
  is.finite(comparison$total_local_gcv_ps) &
    is.finite(comparison$truth_rmse),
  ,
  drop = FALSE
]
gcv.lm.stats <- do.call(rbind, lapply(split(gcv.lm.data, gcv.lm.data$method),
                                      function(df) {
  fit <- stats::lm(truth_rmse ~ total_local_gcv_ps, data = df)
  coef <- stats::coef(fit)
  sm <- summary(fit)
  data.frame(
    method = as.character(df$method[[1L]]),
    n = nrow(df),
    intercept = unname(coef[[1L]]),
    slope = unname(coef[[2L]]),
    r_squared = unname(sm$r.squared),
    p_value_slope = unname(sm$coefficients[2L, 4L]),
    stringsAsFactors = FALSE
  )
}))
gcv.lm.stats$label <- sprintf(
  "y = %.3g + %.3g x\nR^2 = %.2f\np = %.3g",
  gcv.lm.stats$intercept,
  gcv.lm.stats$slope,
  gcv.lm.stats$r_squared,
  gcv.lm.stats$p_value_slope
)
write.csv.safe(gcv.lm.stats,
               file.path(table.dir, "ps_lps_refined_gcv_truth_lm_table.csv"))

p.gcv.lm <- ggplot2::ggplot(
  gcv.lm.data,
  ggplot2::aes(x = total_local_gcv_ps, y = truth_rmse)
) +
  ggplot2::geom_point(ggplot2::aes(color = batch_id), size = 2.1, alpha = 0.9) +
  ggplot2::geom_smooth(method = "lm", se = TRUE, color = "grey20",
                       fill = "grey75", linewidth = 0.8) +
  ggplot2::geom_text(
    data = gcv.lm.stats,
    ggplot2::aes(x = -Inf, y = Inf, label = label),
    inherit.aes = FALSE,
    hjust = -0.05,
    vjust = 1.12,
    size = 3.0,
    lineheight = 0.95
  ) +
  ggplot2::facet_wrap(~ method, scales = "free_x", ncol = 3) +
  ggplot2::labs(
    title = "Total local GCV versus Truth RMSE by method",
    subtitle = "Each panel fits Truth RMSE = alpha + beta * total local GCV across the 14 first-batch datasets.",
    x = "Total local GCV",
    y = "Truth RMSE",
    color = "Dataset"
  ) +
  theme.report +
  ggplot2::theme(legend.position = "none")
ggplot2::ggsave(file.path(fig.dir, "ps_lps_refined_gcv_truth_lm_by_method.png"),
                p.gcv.lm, width = 12, height = 8.5, dpi = 180)

p.lambda <- ggplot2::ggplot(
  lambda.rows,
  ggplot2::aes(x = total.local.gcv.ps, y = cv.rmse.observed,
               color = factor(lambda.sync))
) +
  ggplot2::geom_point(size = 1.8, alpha = 0.85) +
  ggplot2::facet_wrap(~ method, scales = "free", ncol = 2) +
  ggplot2::labs(
    title = "Total local GCV versus CV RMSE across refined candidates",
    x = "Total local GCV",
    y = "CV RMSE",
    color = expression(lambda[sync])
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_refined_total_gcv_vs_cv_rmse.png"),
                p.lambda, width = 10, height = 6, dpi = 180)

p.sync <- ggplot2::ggplot(
  selected.refined,
  ggplot2::aes(x = mean_sync_squared_disagreement, y = truth_rmse,
               color = method, shape = lambda_label)
) +
  ggplot2::geom_point(size = 2.4, alpha = 0.9) +
  ggplot2::geom_text(
    ggplot2::aes(label = batch_id),
    nudge_y = 0.002,
    size = 2.7,
    show.legend = FALSE
  ) +
  ggplot2::labs(
    title = "Selected mean squared overlap disagreement versus Truth RMSE",
    x = "Mean squared prediction disagreement on overlaps",
    y = "Truth RMSE",
    color = NULL,
    shape = NULL
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_refined_sync_disagreement_vs_truth_rmse.png"),
                p.sync, width = 9.5, height = 6, dpi = 180)

p.point <- ggplot2::ggplot(
  pointwise,
  ggplot2::aes(x = local_gcv_ps, y = rmse_component_vs_lps_auto,
               color = local_df_ratio)
) +
  ggplot2::geom_hline(yintercept = 0, color = "grey60") +
  ggplot2::geom_point(alpha = 0.42, size = 0.65) +
  ggplot2::scale_x_log10() +
  ggplot2::scale_color_viridis_c(option = "C") +
  ggplot2::facet_grid(method ~ batch_id, scales = "free") +
  ggplot2::labs(
    title = "Pointwise Truth-RMSE components versus LPS auto",
    x = "Local GCV of refined fit (log scale)",
    y = expression(c[i]),
    color = "df/k"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_refined_pointwise_components.png"),
                p.point, width = 13, height = 9, dpi = 180)

best <- comparison[order(comparison$batch_id, comparison$truth_rmse), ]
best <- best[!duplicated(best$batch_id), ]
best.count <- table(best$method)

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
.note { max-width: 1020px; }
.figure { margin: 24px 0 30px; }
.figure img { max-width: 100%; border: 1px solid #ddd; }
.caption { font-size: 0.94rem; color: #53606c; max-width: 1020px; }
.data-table { border-collapse: collapse; font-size: 0.88rem; margin: 12px 0 24px; }
.data-table th, .data-table td { border: 1px solid #ddd; padding: 5px 7px; text-align: right; }
.data-table th:first-child, .data-table td:first-child, .data-table th:nth-child(2), .data-table td:nth-child(2), .data-table th:nth-child(3), .data-table td:nth-child(3) { text-align: left; }
code { background: #f3f4f6; padding: 1px 4px; border-radius: 3px; }
"

summary.text <- paste(
  sprintf("PS-LPS lambda grid: {%s}.", paste(lambda.grid, collapse = ", ")),
  sprintf("Ridge scale lambda.ridge: %s.", format(lambda.ridge, scientific = TRUE)),
  sprintf("Sync neighbor size: %d.", sync.neighbor.size),
  sprintf("Best-method counts: %s.",
          paste(names(best.count), as.integer(best.count),
                sep = "=", collapse = "; "))
)
matched.win.text <- sprintf(
  "Matched ridge-LPS comparison: %s.",
  paste(
    matched.win.summary$method,
    paste0(matched.win.summary$wins_vs_matched_ridge_lps,
           "/", matched.win.summary$n_datasets, " wins"),
    sep = "=",
    collapse = "; "
  )
)

report <- htmltools::tagList(
  htmltools::tags$html(
    htmltools::tags$head(
      htmltools::tags$title("Refined PS-LPS First-Batch Experiment"),
      htmltools::tags$style(css),
      htmltools::tags$script(
        src = "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js",
        async = NA
      )
    ),
    htmltools::tags$body(
      htmltools::tags$h1("Refined PS-LPS First-Batch Experiment"),
      htmltools::tags$p(
        class = "note",
        "This audit-response report separates three quantities that were ",
        "confounded in the first PS-LPS report: ordinary LPS, independent ",
        "ridge-stabilized LPS with ",
        htmltools::HTML("\\(\\lambda_{\\mathrm{sync}}=0\\)"),
        ", and prediction-synchronized LPS with CV-selected ",
        htmltools::HTML("\\(\\lambda_{\\mathrm{sync}}\\)"),
        ". All refined fits reuse the support size, kernel, degree, and chart ",
        "dimension policy selected by the corresponding ordinary LPS run."
      ),
      htmltools::tags$p(
        class = "note",
        "With ",
        htmltools::HTML("\\(\\lambda_{\\mathrm{ridge}}=0\\)"),
        " and ",
        htmltools::HTML("\\(\\lambda_{\\mathrm{sync}}=0\\)"),
        ", PS-LPS is now tested to reproduce ordinary independent LPS full-data ",
        "fitted values. The production comparison here uses an explicit small ",
        "ridge and therefore compares PS-LPS to the matched ridge-LPS baseline, ",
        "not only to ordinary LPS."
      ),
      htmltools::tags$p(class = "note", summary.text),
      htmltools::tags$p(
        class = "note",
        matched.win.text,
        " This is the intended cautious reading: median improvement and ",
        "dataset-wise wins over matched ridge-LPS, not a claim of universal ",
        "dominance on every dataset or a broad validation result."
      ),
      htmltools::tags$h2("Truth RMSE"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(
          src = file.path("figures", "ps_lps_refined_truth_rmse_comparison.png")
        ),
        htmltools::tags$p(
          class = "caption",
          "Lower Truth RMSE is better. Gray lines connect methods within a dataset."
        )
      ),
      htmltools::tags$h2("Ridge and Synchronization Decomposition"),
      htmltools::tags$p(
        class = "note",
        "The next figure is the main correction to the original experiment. ",
        "The upper comparison asks whether ridge-stabilized and synchronized ",
        "fits improve over ordinary LPS. The lower comparison asks whether ",
        "positive synchronization improves over the matched ridge-LPS baseline."
      ),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(
          src = file.path("figures", "ps_lps_refined_delta_decomposition.png")
        ),
        htmltools::tags$p(
          class = "caption",
          "Negative values mean the row method has lower Truth RMSE than the ",
          "reference named in the facet row."
        )
      ),
      htmltools::tags$h2("GCV and Synchronization Diagnostics"),
      htmltools::tags$p(
        class = "note",
        "Total local GCV is computed after solving the selected chart system. ",
        "For PS-LPS this uses synchronized chart coefficients, so it is not the ",
        "same diagnostic as ordinary independent LPS local GCV."
      ),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(
          src = file.path("figures", "ps_lps_refined_total_gcv_vs_cv_rmse.png")
        ),
        htmltools::tags$p(
          class = "caption",
          "Each point is one ridge-LPS or PS-LPS lambda candidate."
        )
      ),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(
          src = file.path("figures", "ps_lps_refined_total_gcv_vs_truth_rmse.png")
        ),
        htmltools::tags$p(
          class = "caption",
          "Synthetic-truth diagnostic for selected refined fits."
        )
      ),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(
          src = file.path("figures", "ps_lps_refined_gcv_truth_lm_by_method.png")
        ),
        htmltools::tags$p(
          class = "caption",
          "Each panel is one method. The fitted line is the linear model ",
          htmltools::HTML("\\(\\mathrm{TruthRMSE}=\\alpha+\\beta\\,\\mathrm{TotalLocalGCV}\\)"),
          " across the 14 first-batch datasets."
        )
      ),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(
          src = file.path("figures", "ps_lps_refined_sync_disagreement_vs_truth_rmse.png")
        ),
        htmltools::tags$p(
          class = "caption",
          "Mean squared disagreement is reported even for ",
          htmltools::HTML("\\(\\lambda_{\\mathrm{sync}}=0\\)"),
          ", where it is diagnostic rather than penalized."
        )
      ),
      htmltools::tags$h2("Pointwise Components"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(
          src = file.path("figures", "ps_lps_refined_pointwise_components.png")
        ),
        htmltools::tags$p(
          class = "caption",
          "Positive ",
          htmltools::HTML("\\(c_i\\)"),
          " means the refined fit contributes more Truth-RMSE than LPS auto at ",
          "that point. Colors show local degrees-of-freedom ratio."
        )
      ),
      htmltools::tags$h2("Selected Refined Fits"),
      table.html(transform(
        refined.summary[, c("batch_id", "dataset_id", "method",
                            "selected_lambda_sync", "lambda_ridge",
                            "selected_support_size", "selected_kernel",
                            "selected_chart_dim", "selected_cv_rmse_observed",
                            "truth_rmse", "total_local_gcv_ps",
                            "sync_energy", "mean_sync_squared_disagreement",
                            "ridge_median", "elapsed_sec")],
        selected_cv_rmse_observed = fmt(selected_cv_rmse_observed),
        truth_rmse = fmt(truth_rmse),
        total_local_gcv_ps = fmt(total_local_gcv_ps),
        sync_energy = fmt(sync_energy),
        mean_sync_squared_disagreement = fmt(mean_sync_squared_disagreement),
        ridge_median = fmt(ridge_median),
        elapsed_sec = fmt(elapsed_sec, 4)
      )),
      htmltools::tags$h2("Tables"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_refined_method_comparison.csv"),
          "Method comparison table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_refined_summary.csv"),
          "Refined fit summary table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_refined_delta_table.csv"),
          "Ridge/synchronization delta table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_refined_matched_ridge_win_counts.csv"),
          "Matched ridge-LPS win-count table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_refined_lambda_cv_gcv_table.csv"),
          "Lambda CV/GCV table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_refined_gcv_truth_lm_table.csv"),
          "GCV versus Truth RMSE linear-model table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_refined_pointwise_components.csv"),
          "Pointwise component table"
        ))
      )
    )
  )
)

report.path <- file.path(out.dir, "ps_lps_first_batch_refined_experiment_report.html")
htmltools::save_html(report, report.path)
message("Wrote ", report.path)
