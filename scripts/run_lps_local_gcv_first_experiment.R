#!/usr/bin/env Rscript

repo.dir <- normalizePath("/Users/pgajer/current_projects/geosmooth", mustWork = TRUE)
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
pointwise.dir <- file.path(
  run.dir,
  "reports",
  "lps_local_auto_geometry_report",
  "pointwise_contributions"
)
out.dir <- file.path(
  repo.dir,
  "split_handoffs",
  "lps_local_gcv_first_experiment_2026-06-05"
)
table.dir <- file.path(out.dir, "tables")
fig.dir <- file.path(out.dir, "figures")
dir.create(table.dir, recursive = TRUE, showWarnings = FALSE)
dir.create(fig.dir, recursive = TRUE, showWarnings = FALSE)

need <- c("ggplot2", "htmltools", "pkgload")
missing <- need[!vapply(need, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Missing required packages: ", paste(missing, collapse = ", "), call. = FALSE)
}

pkgload::load_all(repo.dir, quiet = TRUE)

`%||%` <- function(x, y) if (is.null(x)) y else x

safe.id <- function(x) gsub("[^A-Za-z0-9_]+", "_", x)

rmse <- function(x, y) sqrt(mean((as.numeric(x) - as.numeric(y))^2))

read.csv.safe <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

write.csv.safe <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
}

design.ncol <- getFromNamespace(".klp.design.ncol", "geosmooth")
design.matrix <- getFromNamespace(".local.polynomial.design.matrix", "geosmooth")
local.order <- getFromNamespace(".klp.local.order", "geosmooth")
kernel.weights <- getFromNamespace(".klp.kernel.weights", "geosmooth")
local.coordinates <- getFromNamespace(".klp.local.coordinates", "geosmooth")

build.local.frame.cache <- function(X, support.grid, max.chart.dim = 6L) {
  X <- as.matrix(X)
  support.grid <- sort(unique(as.integer(support.grid)))
  max.support <- max(support.grid)
  max.chart.dim <- max(1L, min(as.integer(max.chart.dim), ncol(X)))
  orders <- lapply(seq_len(nrow(X)), function(ii) {
    local.order(
      X.train = X,
      center = X[ii, , drop = TRUE],
      support.size = max.support
    )
  })
  frames <- vector("list", length(support.grid))
  names(frames) <- as.character(support.grid)
  for (support.size in support.grid) {
    frames[[as.character(support.size)]] <- lapply(seq_len(nrow(X)), function(ii) {
      idx <- orders[[ii]]$index[seq_len(support.size)]
      dist <- orders[[ii]]$distances[seq_len(support.size)]
      coords <- tryCatch(
        local.coordinates(
          X.support = X[idx, , drop = FALSE],
          center = X[ii, , drop = TRUE],
          coordinate.method = "local.pca",
          chart.dim = max.chart.dim,
          local.chart.method = "pca",
          weights = NULL,
          return.chart = FALSE
        ),
        error = function(e) NULL
      )
      list(index = idx, distances = dist, coordinates = coords)
    })
  }
  frames
}

weighted.lm.diagnostics <- function(design, y, weights, rank.tol = 1e-10) {
  design.ok <- rowSums(is.finite(design)) == ncol(design)
  ok <- is.finite(y) & is.finite(weights) & weights > 0 & design.ok
  m <- sum(ok)
  if (!m) {
    return(list(
      rss = NA_real_, rank = NA_integer_, df.ratio = NA_real_,
      condition = NA_real_, gcv = Inf, fallback = TRUE,
      fallback.reason = "no_positive_weighted_rows"
    ))
  }
  if (m < ncol(design)) {
    mu <- stats::weighted.mean(y[ok], weights[ok])
    rss <- sum(weights[ok] * (y[ok] - mu)^2)
    df <- 1L
    denom <- 1 - df / m
    return(list(
      rss = rss, rank = df, df.ratio = df / m,
      condition = NA_real_,
      gcv = if (denom > 0) (rss / m) / denom^2 else Inf,
      fallback = TRUE,
      fallback.reason = "underdetermined_local_design"
    ))
  }
  xw <- design[ok, , drop = FALSE] * sqrt(weights[ok])
  yw <- y[ok] * sqrt(weights[ok])
  s <- tryCatch(svd(xw, nu = 0, nv = 0)$d, error = function(e) numeric(0))
  if (!length(s) || !all(is.finite(s))) {
    mu <- stats::weighted.mean(y[ok], weights[ok])
    rss <- sum(weights[ok] * (y[ok] - mu)^2)
    df <- 1L
    denom <- 1 - df / m
    return(list(
      rss = rss, rank = df, df.ratio = df / m,
      condition = NA_real_,
      gcv = if (denom > 0) (rss / m) / denom^2 else Inf,
      fallback = TRUE,
      fallback.reason = "svd_failure"
    ))
  }
  threshold <- rank.tol * max(s)
  rank <- as.integer(sum(s > threshold))
  condition <- if (rank > 0L) max(s) / min(s[s > threshold]) else Inf
  fit <- tryCatch(
    stats::lm.wfit(design[ok, , drop = FALSE], y[ok], weights[ok]),
    error = function(e) NULL
  )
  if (is.null(fit) || !length(fit$coefficients)) {
    mu <- stats::weighted.mean(y[ok], weights[ok])
    rss <- sum(weights[ok] * (y[ok] - mu)^2)
    df <- 1L
    denom <- 1 - df / m
    return(list(
      rss = rss, rank = df, df.ratio = df / m,
      condition = condition,
      gcv = if (denom > 0) (rss / m) / denom^2 else Inf,
      fallback = TRUE,
      fallback.reason = "weighted_lm_failure"
    ))
  }
  coef <- fit$coefficients
  coef[!is.finite(coef)] <- 0
  pred <- as.numeric(design[ok, , drop = FALSE] %*% coef)
  rss <- sum(weights[ok] * (y[ok] - pred)^2)
  df <- as.integer(rank)
  denom <- 1 - df / m
  list(
    rss = rss,
    rank = df,
    df.ratio = df / m,
    condition = condition,
    gcv = if (denom > 0) (rss / m) / denom^2 else Inf,
    fallback = FALSE,
    fallback.reason = "none"
  )
}

local.gcv.by.anchor <- function(X, y, support.size, kernel, degree,
                                chart.dim = NULL, chart.dim.by.anchor = NULL,
                                rank.tol = 1e-10,
                                frame.cache = NULL) {
  X <- as.matrix(X)
  y <- as.numeric(y)
  n <- nrow(X)
  out <- vector("list", n)
  for (ii in seq_len(n)) {
    d.anchor <- if (is.null(chart.dim.by.anchor)) {
      as.integer(chart.dim)
    } else {
      as.integer(chart.dim.by.anchor[[ii]])
    }
    d.anchor <- max(1L, min(d.anchor, ncol(X)))
    frame <- NULL
    if (!is.null(frame.cache) &&
        !is.null(frame.cache[[as.character(support.size)]])) {
      frame <- frame.cache[[as.character(support.size)]][[ii]]
    }
    if (is.null(frame)) {
      ord <- local.order(
        X.train = X,
        center = X[ii, , drop = TRUE],
        support.size = support.size
      )
      idx <- ord$index
      dist <- ord$distances
      coords <- NULL
    } else {
      idx <- frame$index
      dist <- frame$distances
      coords <- frame$coordinates
    }
    w <- kernel.weights(dist, kernel)
    if (!any(w > 0)) w[] <- 1
    if (is.null(coords) || ncol(coords) < d.anchor) {
      coords <- tryCatch(
        local.coordinates(
          X.support = X[idx, , drop = FALSE],
          center = X[ii, , drop = TRUE],
          coordinate.method = "local.pca",
          chart.dim = d.anchor,
          local.chart.method = "pca",
          weights = w,
          return.chart = FALSE
        ),
        error = function(e) NULL
      )
    }
    if (is.null(coords)) {
      mu <- stats::weighted.mean(y[idx], w, na.rm = TRUE)
      rss <- sum(w * (y[idx] - mu)^2)
      m <- sum(is.finite(y[idx]) & is.finite(w) & w > 0)
      df <- 1L
      denom <- 1 - df / max(m, 1L)
      out[[ii]] <- data.frame(
        point = ii, support.size = support.size, degree = degree,
        kernel = kernel, chart.dim = d.anchor,
        local.gcv = if (m > 1L && denom > 0) (rss / m) / denom^2 else Inf,
        local.rss = rss, local.rank = df,
        df.ratio = if (m > 0L) df / m else NA_real_,
        local.condition = NA_real_, fallback = TRUE,
        fallback.reason = "local_coordinate_failure",
        stringsAsFactors = FALSE
      )
      next
    }
    design <- design.matrix(coords[, seq_len(d.anchor), drop = FALSE], degree)
    diag <- weighted.lm.diagnostics(design, y[idx], w, rank.tol = rank.tol)
    out[[ii]] <- data.frame(
      point = ii, support.size = support.size, degree = degree,
      kernel = kernel, chart.dim = d.anchor,
      local.gcv = diag$gcv,
      local.rss = diag$rss,
      local.rank = diag$rank,
      df.ratio = diag$df.ratio,
      local.condition = diag$condition,
      fallback = diag$fallback,
      fallback.reason = diag$fallback.reason,
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, out)
}

score.candidate <- function(asset, candidate, frame.cache = NULL) {
  local <- local.gcv.by.anchor(
    X = asset$X,
    y = asset$y,
    support.size = candidate$support.size,
    kernel = candidate$kernel,
    degree = candidate$degree,
    chart.dim = candidate$chart.dim,
    frame.cache = frame.cache
  )
  finite <- is.finite(local$local.gcv)
  data.frame(
    support.size = candidate$support.size,
    degree = candidate$degree,
    kernel = candidate$kernel,
    chart.dim = candidate$chart.dim,
    design.ncol = design.ncol(candidate$degree, candidate$chart.dim),
    sum.local.gcv = sum(local$local.gcv[finite]),
    mean.local.gcv = mean(local$local.gcv[finite]),
    median.local.gcv = stats::median(local$local.gcv[finite]),
    finite.local.gcv.fraction = mean(finite),
    fallback.rate = mean(local$fallback),
    mean.df.ratio = mean(local$df.ratio, na.rm = TRUE),
    max.df.ratio = max(local$df.ratio, na.rm = TRUE),
    median.condition = stats::median(local$local.condition, na.rm = TRUE),
    max.condition = max(local$local.condition, na.rm = TRUE),
    status = if (mean(finite) == 0) {
      "no_finite_local_gcv"
    } else if (mean(local$fallback) > 0.05) {
      "high_fallback_rate"
    } else {
      "eligible"
    },
    stringsAsFactors = FALSE
  )
}

candidate.grid.for.asset <- function(asset, support.grid = 15:35,
                                     degree.grid = 2L,
                                     kernel.grid = c("gaussian", "tricube"),
                                     max.chart.dim = 6L) {
  p <- ncol(asset$X)
  d.grid <- seq_len(min(p, max.chart.dim))
  cand <- expand.grid(
    support.size = support.grid,
    degree = degree.grid,
    kernel = kernel.grid,
    chart.dim = d.grid,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  cand$design.ncol <- mapply(design.ncol, cand$degree, cand$chart.dim)
  cand$nominally.feasible <- cand$design.ncol < cand$support.size
  cand[cand$nominally.feasible, c("support.size", "degree", "kernel", "chart.dim")]
}

fit.selected.gcv.candidate <- function(asset, selected) {
  fit <- tryCatch(
    fit.lps(
      X = asset$X,
      y = asset$y,
      foldid = asset$foldid,
      support.grid = selected$support.size,
      degree.grid = selected$degree,
      kernel.grid = selected$kernel,
      coordinate.method = "local.pca",
      chart.dim = selected$chart.dim,
      local.chart.method = "pca",
      backend = "R"
    ),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    return(data.frame(
      selected_support_size = selected$support.size,
      selected_degree = selected$degree,
      selected_kernel = selected$kernel,
      selected_chart_dim = selected$chart.dim,
      selected_cv_rmse_observed = NA_real_,
      observed_rmse = NA_real_,
      truth_rmse = NA_real_,
      fit_status = paste("fit_error:", conditionMessage(fit)),
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    selected_support_size = selected$support.size,
    selected_degree = selected$degree,
    selected_kernel = selected$kernel,
    selected_chart_dim = selected$chart.dim,
    selected_cv_rmse_observed = fit$selected$cv.rmse.observed[[1L]],
    observed_rmse = rmse(fit$fitted.values, asset$y),
    truth_rmse = rmse(fit$fitted.values, asset$f),
    fit_status = "ok",
    stringsAsFactors = FALSE
  )
}

pointwise.diagnostics.for.local.auto <- function(asset, local.result,
                                                 component.path,
                                                 frame.cache = NULL) {
  component <- read.csv.safe(component.path)
  selected <- local.result$selected
  local <- local.gcv.by.anchor(
    X = asset$X,
    y = asset$y,
    support.size = selected$support.size[[1L]],
    kernel = selected$kernel[[1L]],
    degree = selected$degree[[1L]],
    chart.dim.by.anchor = local.result$chart_dim_by_eval,
    frame.cache = frame.cache
  )
  out <- merge(component, local, by = "point", all.x = TRUE, sort = FALSE)
  out
}

safe.cor <- function(x, y) {
  ok <- is.finite(x) & is.finite(y)
  if (sum(ok) < 3L) return(NA_real_)
  suppressWarnings(stats::cor(x[ok], y[ok], method = "spearman"))
}

summarize.pointwise.diagnostics <- function(pointwise, batch.id, dataset.id) {
  red <- pointwise$rmse_component > 0
  data.frame(
    batch_id = batch.id,
    dataset_id = dataset.id,
    n_points = nrow(pointwise),
    red_fraction = mean(red, na.rm = TRUE),
    cor_component_local_gcv = safe.cor(pointwise$rmse_component, pointwise$local.gcv),
    cor_abs_component_local_gcv = safe.cor(abs(pointwise$rmse_component), pointwise$local.gcv),
    cor_component_df_ratio = safe.cor(pointwise$rmse_component, pointwise$df.ratio),
    cor_abs_component_df_ratio = safe.cor(abs(pointwise$rmse_component), pointwise$df.ratio),
    mean_local_gcv_red = mean(pointwise$local.gcv[red], na.rm = TRUE),
    mean_local_gcv_blue = mean(pointwise$local.gcv[!red], na.rm = TRUE),
    mean_df_ratio_red = mean(pointwise$df.ratio[red], na.rm = TRUE),
    mean_df_ratio_blue = mean(pointwise$df.ratio[!red], na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}

rows <- read.csv.safe(file.path(run.dir, "tables", "combined_results.csv"))
asset.manifest <- read.csv.safe(file.path(freeze.dir, "asset_manifest.csv"))
asset.manifest <- asset.manifest[order(asset.manifest[["batch.id"]]), ]

candidate.scores.path <- file.path(table.dir, "candidate_local_gcv_scores.csv")
gcv.selected.path <- file.path(table.dir, "gcv_selected_candidates.csv")
method.comparison.path <- file.path(table.dir, "method_comparison.csv")
pointwise.all.path <- file.path(table.dir, "pointwise_gcv_component_diagnostics.csv")
pointwise.summary.path <- file.path(table.dir, "pointwise_gcv_component_summary.csv")
cached.tables <- c(
  candidate.scores.path,
  gcv.selected.path,
  method.comparison.path,
  pointwise.all.path,
  pointwise.summary.path
)

if (all(file.exists(cached.tables)) &&
    !identical(Sys.getenv("LPS_GCV_FORCE"), "1")) {
  message("Reusing existing local-GCV tables. Set LPS_GCV_FORCE=1 to recompute.")
  candidate.scores <- read.csv.safe(candidate.scores.path)
  gcv.selected <- read.csv.safe(gcv.selected.path)
  method.comparison <- read.csv.safe(method.comparison.path)
  pointwise.all <- read.csv.safe(pointwise.all.path)
  pointwise.summary <- read.csv.safe(pointwise.summary.path)
} else {
  all.candidate.scores <- list()
  all.gcv.selected <- list()
  all.method.rows <- list()
  all.pointwise <- list()
  all.pointwise.summary <- list()

  for (aa in seq_len(nrow(asset.manifest))) {
  batch.id <- asset.manifest[["batch.id"]][[aa]]
  dataset.id <- asset.manifest[["dataset.id"]][[aa]]
  message(sprintf("[%s] scoring local-GCV candidates for %s", batch.id, dataset.id))
  asset <- readRDS(asset.manifest[["asset.path"]][[aa]])
  cand <- candidate.grid.for.asset(asset)
  frame.cache <- build.local.frame.cache(
    X = asset$X,
    support.grid = sort(unique(cand$support.size)),
    max.chart.dim = max(cand$chart.dim)
  )
  scores <- do.call(rbind, lapply(seq_len(nrow(cand)), function(ii) {
    score.candidate(asset, cand[ii, , drop = FALSE], frame.cache = frame.cache)
  }))
  scores$batch_id <- batch.id
  scores$dataset_id <- dataset.id
  scores <- scores[, c("batch_id", "dataset_id", setdiff(names(scores), c("batch_id", "dataset_id")))]
  all.candidate.scores[[batch.id]] <- scores

  eligible <- scores[
    scores$status == "eligible" &
      is.finite(scores$sum.local.gcv) &
      is.finite(scores$mean.local.gcv),
    ,
    drop = FALSE
  ]
  if (!nrow(eligible)) {
    eligible <- scores[is.finite(scores$sum.local.gcv), , drop = FALSE]
  }
  selected <- eligible[order(
    eligible$sum.local.gcv,
    eligible$support.size,
    eligible$kernel,
    eligible$chart.dim
  ), , drop = FALSE][1L, ]
  selected.fit <- fit.selected.gcv.candidate(asset, selected)
  selected.row <- cbind(
    data.frame(
      batch_id = batch.id,
      dataset_id = dataset.id,
      selection_rule = "sum_local_gcv",
      stringsAsFactors = FALSE
    ),
    selected[, c("support.size", "degree", "kernel", "chart.dim",
                 "sum.local.gcv", "mean.local.gcv", "fallback.rate",
                 "mean.df.ratio", "max.df.ratio", "status")],
    selected.fit
  )
  all.gcv.selected[[batch.id]] <- selected.row

  current <- rows[rows$batch_id == batch.id, , drop = FALSE]
  method.rows <- rbind(
    data.frame(
      batch_id = batch.id,
      dataset_id = dataset.id,
      method = "CV auto",
      selected_support_size = current$selected_support_size[current$chart_dim_rule == "auto"],
      selected_degree = current$selected_degree[current$chart_dim_rule == "auto"],
      selected_kernel = current$selected_kernel[current$chart_dim_rule == "auto"],
      selected_chart_dim = current$resolved_chart_dim[current$chart_dim_rule == "auto"],
      selected_cv_rmse_observed = current$selected_cv_rmse_observed[current$chart_dim_rule == "auto"],
      observed_rmse = current$observed_rmse[current$chart_dim_rule == "auto"],
      truth_rmse = current$truth_rmse[current$chart_dim_rule == "auto"],
      stringsAsFactors = FALSE
    ),
    data.frame(
      batch_id = batch.id,
      dataset_id = dataset.id,
      method = "CV local.auto",
      selected_support_size = current$selected_support_size[current$chart_dim_rule == "local.auto"],
      selected_degree = current$selected_degree[current$chart_dim_rule == "local.auto"],
      selected_kernel = current$selected_kernel[current$chart_dim_rule == "local.auto"],
      selected_chart_dim = current$resolved_chart_dim[current$chart_dim_rule == "local.auto"],
      selected_cv_rmse_observed = current$selected_cv_rmse_observed[current$chart_dim_rule == "local.auto"],
      observed_rmse = current$observed_rmse[current$chart_dim_rule == "local.auto"],
      truth_rmse = current$truth_rmse[current$chart_dim_rule == "local.auto"],
      stringsAsFactors = FALSE
    ),
    data.frame(
      batch_id = batch.id,
      dataset_id = dataset.id,
      method = "GCV sum",
      selected_support_size = selected.fit$selected_support_size,
      selected_degree = selected.fit$selected_degree,
      selected_kernel = selected.fit$selected_kernel,
      selected_chart_dim = selected.fit$selected_chart_dim,
      selected_cv_rmse_observed = selected.fit$selected_cv_rmse_observed,
      observed_rmse = selected.fit$observed_rmse,
      truth_rmse = selected.fit$truth_rmse,
      stringsAsFactors = FALSE
    )
  )
  all.method.rows[[batch.id]] <- method.rows

  local.path <- file.path(
    run.dir,
    "results",
    sprintf("%s__%s__chart_local_auto.rds", batch.id, safe.id(dataset.id))
  )
  component.path <- file.path(
    pointwise.dir,
    sprintf("%s__%s__pointwise_rmse_components.csv", batch.id, safe.id(dataset.id))
  )
  if (file.exists(local.path) && file.exists(component.path)) {
    local.result <- readRDS(local.path)
    pointwise <- pointwise.diagnostics.for.local.auto(
      asset = asset,
      local.result = local.result,
      component.path = component.path,
      frame.cache = frame.cache
    )
    pointwise$batch_id <- batch.id
    pointwise$dataset_id <- dataset.id
    pointwise <- pointwise[, c("batch_id", "dataset_id",
                               setdiff(names(pointwise), c("batch_id", "dataset_id")))]
    all.pointwise[[batch.id]] <- pointwise
    all.pointwise.summary[[batch.id]] <- summarize.pointwise.diagnostics(
      pointwise,
      batch.id,
      dataset.id
    )
  }
  }

  candidate.scores <- do.call(rbind, all.candidate.scores)
  gcv.selected <- do.call(rbind, all.gcv.selected)
  method.comparison <- do.call(rbind, all.method.rows)
  pointwise.all <- do.call(rbind, all.pointwise)
  pointwise.summary <- do.call(rbind, all.pointwise.summary)
}

method.comparison$method <- factor(
  method.comparison$method,
  levels = c("CV auto", "CV local.auto", "GCV sum")
)
method.comparison$dataset_label <- paste(method.comparison$batch_id,
                                         method.comparison$dataset_id)
method.comparison$best_truth_rmse <- ave(
  method.comparison$truth_rmse,
  method.comparison$batch_id,
  FUN = min
)
method.comparison$truth_rmse_delta_from_best <-
  method.comparison$truth_rmse - method.comparison$best_truth_rmse

write.csv.safe(candidate.scores, candidate.scores.path)
write.csv.safe(gcv.selected, gcv.selected.path)
write.csv.safe(method.comparison, method.comparison.path)
write.csv.safe(pointwise.all, pointwise.all.path)
write.csv.safe(pointwise.summary, pointwise.summary.path)

theme.report <- ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    plot.title.position = "plot",
    legend.position = "bottom"
  )

p.methods <- ggplot2::ggplot(
  method.comparison,
  ggplot2::aes(x = method, y = truth_rmse, group = dataset_label)
) +
  ggplot2::geom_line(color = "grey70", linewidth = 0.35) +
  ggplot2::geom_point(ggplot2::aes(color = method), size = 2.2) +
  ggplot2::facet_wrap(~ batch_id, scales = "free_y", ncol = 4) +
  ggplot2::labs(
    title = "Truth RMSE for CV-selected auto, CV-selected local.auto, and summed-local-GCV selection",
    x = NULL,
    y = "Truth RMSE"
  ) +
  theme.report +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 35, hjust = 1))
ggplot2::ggsave(file.path(fig.dir, "truth_rmse_method_comparison.png"),
                p.methods, width = 12, height = 8, dpi = 180)

p.delta <- ggplot2::ggplot(
  method.comparison,
  ggplot2::aes(x = truth_rmse_delta_from_best, y = dataset_label,
               color = method)
) +
  ggplot2::geom_vline(xintercept = 0, color = "grey55") +
  ggplot2::geom_point(size = 2.1, position = ggplot2::position_dodge(width = 0.5)) +
  ggplot2::labs(
    title = "Truth RMSE regret relative to the best of the three compared selectors",
    x = "Truth RMSE minus per-dataset best",
    y = NULL
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "truth_rmse_regret_by_dataset.png"),
                p.delta, width = 10, height = 7, dpi = 180)

pointwise.plot <- pointwise.all
pointwise.plot$log10_local_gcv <- log10(pmax(pointwise.plot$local.gcv, 1e-12))
p.pointwise <- ggplot2::ggplot(
  pointwise.plot,
  ggplot2::aes(x = log10_local_gcv, y = rmse_component, color = df.ratio)
) +
  ggplot2::geom_hline(yintercept = 0, color = "grey60") +
  ggplot2::geom_point(alpha = 0.45, size = 0.65) +
  ggplot2::scale_color_viridis_c(option = "C", end = 0.9) +
  ggplot2::facet_wrap(~ batch_id, scales = "free", ncol = 4) +
  ggplot2::labs(
    title = "Pointwise local.auto loss/win component versus local GCV",
    subtitle = "Positive c_i means local.auto contributes more Truth-RMSE than auto at that point.",
    x = expression(log[10]("local GCV")),
    y = expression(c[i]),
    color = "df / k"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "pointwise_component_vs_local_gcv.png"),
                p.pointwise, width = 12, height = 8, dpi = 180)

cors.long <- rbind(
  data.frame(batch_id = pointwise.summary$batch_id,
             dataset_id = pointwise.summary$dataset_id,
             diagnostic = "cor(c_i, local GCV)",
             value = pointwise.summary$cor_component_local_gcv),
  data.frame(batch_id = pointwise.summary$batch_id,
             dataset_id = pointwise.summary$dataset_id,
             diagnostic = "cor(|c_i|, local GCV)",
             value = pointwise.summary$cor_abs_component_local_gcv),
  data.frame(batch_id = pointwise.summary$batch_id,
             dataset_id = pointwise.summary$dataset_id,
             diagnostic = "cor(c_i, df/k)",
             value = pointwise.summary$cor_component_df_ratio),
  data.frame(batch_id = pointwise.summary$batch_id,
             dataset_id = pointwise.summary$dataset_id,
             diagnostic = "cor(|c_i|, df/k)",
             value = pointwise.summary$cor_abs_component_df_ratio)
)
p.cor <- ggplot2::ggplot(
  cors.long,
  ggplot2::aes(x = value, y = paste(batch_id, dataset_id), color = diagnostic)
) +
  ggplot2::geom_vline(xintercept = 0, color = "grey55") +
  ggplot2::geom_point(size = 2, position = ggplot2::position_dodge(width = 0.55)) +
  ggplot2::labs(
    title = "Spearman associations between red/blue components and local diagnostics",
    x = "Spearman correlation",
    y = NULL,
    color = NULL
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "component_diagnostic_correlations.png"),
                p.cor, width = 11, height = 7, dpi = 180)

fmt <- function(x, digits = 4) {
  ifelse(is.finite(x), formatC(x, digits = digits, format = "fg"), "")
}

table.html <- function(df, max.rows = 50L) {
  df <- head(df, max.rows)
  htmltools::tags$table(
    class = "data-table",
    htmltools::tags$thead(
      htmltools::tags$tr(lapply(names(df), htmltools::tags$th))
    ),
    htmltools::tags$tbody(
      lapply(seq_len(nrow(df)), function(ii) {
        htmltools::tags$tr(lapply(df[ii, , drop = FALSE], function(x) {
          htmltools::tags$td(as.character(x[[1L]]))
        }))
      })
    )
  )
}

best.rows <- method.comparison[order(method.comparison$batch_id,
                                     method.comparison$truth_rmse), ]
best.rows <- best.rows[!duplicated(best.rows$batch_id), ]
gcv.rank.rows <- merge(
  method.comparison[method.comparison$method == "GCV sum",
                    c("batch_id", "dataset_id", "truth_rmse",
                      "truth_rmse_delta_from_best")],
  best.rows[, c("batch_id", "method")],
  by = "batch_id",
  suffixes = c("_gcv", "_best")
)

summary.text <- sprintf(
  paste0(
    "Across %d datasets, summed local GCV was the best of the three compared ",
    "selectors in %d datasets. Its median Truth-RMSE regret relative to the ",
    "best of {CV auto, CV local.auto, GCV sum} was %s."
  ),
  length(unique(method.comparison$batch_id)),
  sum(best.rows$method == "GCV sum"),
  fmt(stats::median(gcv.rank.rows$truth_rmse_delta_from_best, na.rm = TRUE), 5)
)

cor.summary <- aggregate(value ~ diagnostic, cors.long, function(x) {
  stats::median(x, na.rm = TRUE)
})
names(cor.summary)[names(cor.summary) == "value"] <- "median_spearman"

css <- "
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 32px; color: #1f2933; line-height: 1.45; }
h1, h2 { line-height: 1.15; }
.note { max-width: 980px; }
.figure { margin: 24px 0 30px; }
.figure img { max-width: 100%; border: 1px solid #ddd; }
.caption { font-size: 0.94rem; color: #53606c; max-width: 980px; }
.data-table { border-collapse: collapse; font-size: 0.88rem; margin: 12px 0 24px; }
.data-table th, .data-table td { border: 1px solid #ddd; padding: 5px 7px; text-align: right; }
.data-table th:first-child, .data-table td:first-child,
.data-table th:nth-child(2), .data-table td:nth-child(2),
.data-table th:nth-child(3), .data-table td:nth-child(3) { text-align: left; }
code { background: #f3f4f6; padding: 1px 4px; border-radius: 3px; }
.math { font-family: Georgia, serif; font-size: 1.08rem; margin: 14px 0; }
"

report <- htmltools::tagList(
  htmltools::tags$html(
    htmltools::tags$head(
      htmltools::tags$title("LPS Local GCV First Experiment"),
      htmltools::tags$style(css),
      htmltools::tags$script(
        src = "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js",
        async = NA
      )
    ),
    htmltools::tags$body(
      htmltools::tags$h1("LPS Local GCV First Experiment"),
      htmltools::tags$p(
        class = "note",
        "This report implements the first local-GCV experiment on the frozen ",
        "first-batch non-manifold LPS datasets. For every dataset and every ",
        "candidate combination of support size k, kernel, degree, and fixed ",
        "global chart dimension d, it computes the summed local generalized ",
        "cross-validation score."
      ),
      htmltools::tags$div(
        class = "math",
        htmltools::HTML(
          "\\[ \\operatorname{GCV}_{i}(\\theta)=
          \\frac{\\operatorname{RSS}_{i}(\\theta)/k}
          {(1-\\operatorname{df}_{i}(\\theta)/k)^2},
          \\qquad
          \\operatorname{GCV}_{\\Sigma}(\\theta)=
          \\sum_{i=1}^{n}\\operatorname{GCV}_{i}(\\theta). \\]"
        )
      ),
      htmltools::tags$p(
        class = "note",
        "Here ",
        htmltools::tags$code("\\theta=(k,kernel,degree,d)"),
        ", RSS is the weighted residual sum of squares for the local weighted ",
        "polynomial fit at anchor i, and df is the local weighted-design rank. ",
        "The candidate selected by the smallest summed local GCV is compared ",
        "with the existing CV-selected ",
        htmltools::tags$code("chart.dim = \"auto\""),
        " and ",
        htmltools::tags$code("chart.dim = \"local.auto\""),
        " fits."
      ),
      htmltools::tags$p(class = "note", summary.text),
      htmltools::tags$h2("Truth RMSE Comparison"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures", "truth_rmse_method_comparison.png")),
        htmltools::tags$p(
          class = "caption",
          "Truth RMSE for the three selectors. Gray lines connect methods ",
          "within the same dataset; lower is better. The GCV selector uses no ",
          "CV folds for selection, but its selected candidate is then refit ",
          "through the standard LPS path to report Truth RMSE, Observed RMSE, ",
          "and the usual CV RMSE diagnostic."
        )
      ),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures", "truth_rmse_regret_by_dataset.png")),
        htmltools::tags$p(
          class = "caption",
          "Truth-RMSE regret relative to the best of the three compared ",
          "selectors on each dataset."
        )
      ),
      htmltools::tags$h2("Does Local GCV Explain Red c_i Regions?"),
      htmltools::tags$p(
        class = "note",
        "The pointwise component ",
        htmltools::HTML("\\(c_i=((e_i^{la})^2-(e_i^a)^2)/(n(R_{la}+R_a))\\)"),
        " is positive where local.auto contributes more Truth-RMSE than auto. ",
        "The scatter plot below overlays these components against the local ",
        "GCV score of the CV-selected local.auto fit, colored by the local ",
        "degrees-of-freedom ratio df/k."
      ),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures", "pointwise_component_vs_local_gcv.png")),
        htmltools::tags$p(
          class = "caption",
          "If red regions were simply high-local-risk or high-complexity ",
          "regions, positive c_i values would tend to occur at high local GCV ",
          "or high df/k."
        )
      ),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures", "component_diagnostic_correlations.png")),
        htmltools::tags$p(
          class = "caption",
          "Spearman correlations summarize whether the pointwise local.auto ",
          "loss/win components are monotone-associated with local GCV or with ",
          "the local degrees-of-freedom ratio."
        )
      ),
      htmltools::tags$h2("Median Diagnostic Correlations"),
      table.html(transform(cor.summary,
                           median_spearman = fmt(median_spearman, 4))),
      htmltools::tags$h2("GCV-Selected Candidates"),
      table.html(transform(
        gcv.selected[, c("batch_id", "dataset_id", "support.size", "kernel",
                         "degree", "chart.dim", "sum.local.gcv",
                         "fallback.rate", "mean.df.ratio", "truth_rmse")],
        sum.local.gcv = fmt(sum.local.gcv, 5),
        fallback.rate = fmt(fallback.rate, 4),
        mean.df.ratio = fmt(mean.df.ratio, 4),
        truth_rmse = fmt(truth_rmse, 5)
      )),
      htmltools::tags$h2("Output Assets"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "candidate_local_gcv_scores.csv"),
          "Candidate local-GCV score table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "gcv_selected_candidates.csv"),
          "GCV-selected candidate table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "method_comparison.csv"),
          "Selector comparison table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "pointwise_gcv_component_diagnostics.csv"),
          "Pointwise c_i versus local-GCV diagnostics"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "pointwise_gcv_component_summary.csv"),
          "Pointwise diagnostic correlation summary"
        ))
      )
    )
  )
)

htmltools::save_html(report, file.path(out.dir, "lps_local_gcv_first_experiment_report.html"))
message("Wrote ", file.path(out.dir, "lps_local_gcv_first_experiment_report.html"))
