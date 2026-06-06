#!/usr/bin/env Rscript

options(rgl.useNULL = TRUE)

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
report.dir <- file.path(run.dir, "reports", "lps_local_auto_geometry_report")
fig.dir <- file.path(report.dir, "figures")
pointwise.dir <- file.path(report.dir, "pointwise_contributions")
dir.create(fig.dir, recursive = TRUE, showWarnings = FALSE)
dir.create(pointwise.dir, recursive = TRUE, showWarnings = FALSE)

need <- c("ggplot2", "htmltools", "htmlwidgets", "rgl", "dgraphs", "igraph")
missing <- need[!vapply(need, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Missing required packages: ", paste(missing, collapse = ", "), call. = FALSE)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

read.csv.safe <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

scale.coords <- function(x) {
  x <- as.matrix(x)
  x <- x[, colSums(is.finite(x)) == nrow(x), drop = FALSE]
  if (!ncol(x)) x <- matrix(0, nrow = nrow(x), ncol = 1L)
  x <- scale(x, center = TRUE, scale = TRUE)
  x[!is.finite(x)] <- 0
  if (ncol(x) < 3L) {
    x <- cbind(x, matrix(0, nrow = nrow(x), ncol = 3L - ncol(x)))
  }
  x[, seq_len(3L), drop = FALSE]
}

safe.file.id <- function(x) gsub("[^A-Za-z0-9_]+", "_", x)

json.escape <- function(x) {
  x <- gsub("\\\\", "\\\\\\\\", as.character(x))
  x <- gsub("\"", "\\\"", x)
  x
}

weighted.median <- function(x, w) {
  ord <- order(x)
  x <- x[ord]
  w <- w[ord] / sum(w[ord])
  x[which(cumsum(w) >= 0.5)[1L]]
}

bayes.boot.median <- function(x, n.draw = 20000L, seed = 20260605L) {
  set.seed(seed)
  n <- length(x)
  draws <- replicate(n.draw, {
    w <- stats::rexp(n)
    weighted.median(x, w)
  })
  c(
    median = stats::median(draws),
    lo = unname(stats::quantile(draws, 0.025)),
    hi = unname(stats::quantile(draws, 0.975))
  )
}

pad.labels <- function(x, n) {
  if (length(x) == n) return(x)
  rep(NA_character_, n)
}

dimension.palette <- function(values) {
  vals <- sort(unique(as.integer(values[is.finite(values)])))
  cols <- grDevices::hcl.colors(max(length(vals), 3L), "Dark 3")
  stats::setNames(cols[seq_along(vals)], vals)
}

make.rgl.widget <- function(coords, dim.values, title, subtitle,
                            width = 760, height = 520) {
  pal <- dimension.palette(dim.values)
  point.cols <- unname(pal[as.character(as.integer(dim.values))])
  point.cols[is.na(point.cols)] <- "#999999"
  rgl::open3d(useNULL = TRUE)
  on.exit(rgl::close3d(), add = TRUE)
  rgl::bg3d(color = "white")
  rgl::par3d(windowRect = c(0, 0, width, height + 40))
  rgl::plot3d(
    coords[, 1], coords[, 2], coords[, 3],
    type = "n",
    xlab = "axis 1", ylab = "axis 2", zlab = "axis 3",
    main = title
  )
  rgl::points3d(coords[, 1], coords[, 2], coords[, 3],
                col = point.cols, size = 6)
  rgl::axes3d(edges = "bbox", col = "#777777")
  rgl::title3d(main = title, sub = subtitle)
  rgl::rglwidget(width = width, height = height)
}

contribution.palette <- function(values, n = 101L) {
  lim <- max(abs(values[is.finite(values)]), na.rm = TRUE)
  if (!is.finite(lim) || lim <= 0) lim <- 1
  breaks <- seq(-lim, lim, length.out = n + 1L)
  cols <- grDevices::colorRampPalette(c("#2C7BB6", "#F7F7F7", "#D7191C"))(n)
  idx <- findInterval(values, breaks, all.inside = TRUE)
  list(colors = cols[idx], limit = lim)
}

make.contribution.rgl.widget <- function(coords, contribution.values, title,
                                         subtitle, width = 540,
                                         height = 430) {
  pal <- contribution.palette(contribution.values)
  point.cols <- pal$colors
  point.cols[is.na(point.cols)] <- "#999999"
  rgl::open3d(useNULL = TRUE)
  on.exit(rgl::close3d(), add = TRUE)
  rgl::bg3d(color = "white")
  rgl::par3d(windowRect = c(0, 0, width, height + 40))
  rgl::plot3d(
    coords[, 1], coords[, 2], coords[, 3],
    type = "n",
    xlab = "axis 1", ylab = "axis 2", zlab = "axis 3",
    main = title
  )
  rgl::points3d(coords[, 1], coords[, 2], coords[, 3],
                col = point.cols, size = 6)
  rgl::axes3d(edges = "bbox", col = "#777777")
  rgl::title3d(main = title, sub = subtitle)
  rgl::rglwidget(width = width, height = height)
}

pointwise.rmse.components <- function(asset, auto.result, local.result) {
  e.auto <- as.numeric(auto.result$predictions - asset$f)
  e.local <- as.numeric(local.result$predictions - asset$f)
  r.auto <- sqrt(mean(e.auto^2))
  r.local <- sqrt(mean(e.local^2))
  n <- length(asset$f)
  denom <- n * (r.local + r.auto)
  if (!is.finite(denom) || denom <= 0) {
    component <- rep(0, n)
  } else {
    component <- (e.local^2 - e.auto^2) / denom
  }
  data.frame(
    point = seq_len(n),
    error_auto = e.auto,
    error_local_auto = e.local,
    rmse_component = component,
    truth_rmse_auto = r.auto,
    truth_rmse_local_auto = r.local,
    truth_rmse_delta = r.local - r.auto,
    stringsAsFactors = FALSE
  )
}

direct.embedding <- function(asset) {
  list(
    coords = scale.coords(asset$X),
    method = sprintf("direct ambient coordinates, p = %d", ncol(asset$X)),
    graph = NULL
  )
}

graph.embedding <- function(asset, support.size) {
  X <- as.matrix(asset$X)
  graph <- dgraphs::create.rknn.graph(
    X,
    type = "adaptive.radius",
    k.scale = support.size,
    connect.components = TRUE,
    graph.detail = "full"
  )
  weights <- pmax(graph$edge_weight, 1e-8)
  ig <- igraph::graph_from_edgelist(graph$edge_matrix, directed = FALSE)
  igraph::E(ig)$weight <- weights
  d <- igraph::distances(ig, weights = igraph::E(ig)$weight)
  d[!is.finite(d)] <- max(d[is.finite(d)], 0) * 1.05
  cm <- stats::cmdscale(stats::as.dist(d), k = 3L, eig = FALSE, add = TRUE)
  coords <- if (is.list(cm)) cm$points else cm
  method <- sprintf(
    "adaptive-radius graph layout, k.scale = %d; classical MDS initialization",
    support.size
  )
  if (requireNamespace("grip", quietly = TRUE)) {
    kk.coords <- tryCatch({
      igraph::layout_with_kk(
        ig,
        coords = coords,
        dim = 3L,
        maxiter = 150L,
        weights = weights
      )
    }, error = function(e) NULL)
    if (!is.null(kk.coords)) {
      coords <- kk.coords
      method <- paste0(method, " + weighted KK polish")
    } else {
      method <- paste0(method, "; KK polish failed, MDS used")
    }
  }
  list(coords = scale.coords(coords), method = method, graph = graph)
}

truth.result.plot <- function(rows, dataset.id, out.path) {
  plot.df <- rows[rows$metric %in% c("truth_rmse", "observed_rmse",
                                     "selected_cv_rmse_observed"), ]
  plot.df$metric <- factor(
    plot.df$metric,
    levels = c("truth_rmse", "observed_rmse", "selected_cv_rmse_observed"),
    labels = c("Truth RMSE", "Observed RMSE", "CV RMSE")
  )
  p <- ggplot2::ggplot(plot.df, ggplot2::aes(x = chart_dim_rule, y = value,
                                             color = chart_dim_rule)) +
    ggplot2::geom_point(size = 3) +
    ggplot2::geom_line(ggplot2::aes(group = metric), color = "#b0b0b0",
                       linewidth = 0.5) +
    ggplot2::facet_wrap(~ metric, scales = "free_y", nrow = 1) +
    ggplot2::scale_color_manual(values = c(auto = "#4C78A8",
                                           `local.auto` = "#D65F5F")) +
    ggplot2::labs(
      title = paste0(dataset.id, ": selected LPS fit metrics"),
      x = "chart.dim rule",
      y = "value"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(legend.position = "none")
  ggplot2::ggsave(out.path, p, width = 8.2, height = 3.2, dpi = 160)
}

dim.hist.plot <- function(dim.values, dataset.id, out.path) {
  df <- data.frame(dim = as.integer(dim.values))
  p <- ggplot2::ggplot(df, ggplot2::aes(x = factor(dim))) +
    ggplot2::geom_bar(fill = "#6B8EAE", width = 0.7) +
    ggplot2::labs(
      title = paste0(dataset.id, ": local.auto chart-dimension distribution"),
      x = "local chart dimension",
      y = "number of anchors"
    ) +
    ggplot2::theme_minimal(base_size = 12)
  ggplot2::ggsave(out.path, p, width = 6.6, height = 3.2, dpi = 160)
}

paired.summary.plot <- function(wide, out.path) {
  deltas <- wide$truth_rmse_local_auto - wide$truth_rmse_auto
  bb <- bayes.boot.median(deltas)
  df <- data.frame(
    comparison = "local.auto - auto",
    delta = deltas,
    dataset_id = wide$dataset_id
  )
  n.better <- sum(deltas < 0)
  n.worse <- sum(deltas > 0)
  n.tie <- sum(abs(deltas) <= 1e-12)
  p <- ggplot2::ggplot(df, ggplot2::aes(x = delta, y = comparison)) +
    ggplot2::geom_vline(xintercept = 0, color = "#555555",
                        linetype = "dashed") +
    ggplot2::geom_point(color = "#707070", alpha = 0.8,
                        position = ggplot2::position_jitter(height = 0.05,
                                                            width = 0),
                        size = 2.5) +
    ggplot2::geom_pointrange(
      data = data.frame(comparison = "local.auto - auto",
                        median = bb[["median"]], lo = bb[["lo"]],
                        hi = bb[["hi"]]),
      ggplot2::aes(x = median, xmin = lo, xmax = hi, y = comparison),
      inherit.aes = FALSE,
      color = "#C23B22",
      linewidth = 0.8,
      size = 1.2
    ) +
    ggplot2::labs(
      title = "Pairwise Truth-RMSE Comparison",
      subtitle = sprintf("local.auto better / worse / tied: %d / %d / %d across %d paired datasets",
                         n.better, n.worse, n.tie, length(deltas)),
      x = "paired Truth-RMSE delta",
      y = NULL,
      caption = sprintf("Red: Bayesian-bootstrap median paired delta, 95%% CrI [%.4g, %.4g]. Positive is worse for local.auto.",
                        bb[["lo"]], bb[["hi"]])
    ) +
    ggplot2::theme_minimal(base_size = 12)
  ggplot2::ggsave(out.path, p, width = 8.5, height = 3.8, dpi = 170)
  bb
}

combined <- read.csv.safe(file.path(run.dir, "tables", "combined_results.csv"))
asset.manifest <- read.csv.safe(file.path(freeze.dir, "asset_manifest.csv"))
combined.long <- utils::stack(
  combined[c("truth_rmse", "observed_rmse", "selected_cv_rmse_observed")]
)
combined.metrics <- cbind(
  combined[rep(seq_len(nrow(combined)), 3L),
           c("dataset_id", "chart_dim_rule", "selected_support_size",
             "selected_kernel", "selected_degree")],
  data.frame(metric = combined.long$ind, value = combined.long$values)
)

wide <- reshape(
  combined[, c("dataset_id", "chart_dim_rule", "truth_rmse", "observed_rmse",
               "selected_cv_rmse_observed", "selected_support_size",
               "selected_kernel", "elapsed_sec")],
  idvar = "dataset_id",
  timevar = "chart_dim_rule",
  direction = "wide"
)
names(wide) <- gsub(".", "_", names(wide), fixed = TRUE)

summary.fig <- file.path(fig.dir, "pairwise_truth_rmse_delta.png")
bb <- paired.summary.plot(wide, summary.fig)

dataset.blocks <- list()
embedding.records <- list()

for (i in seq_len(nrow(asset.manifest))) {
  asset.row <- asset.manifest[i, ]
  dataset.id <- asset.row$dataset.id
  batch.id <- asset.row$batch.id
  asset <- readRDS(asset.row$asset.path)
  local.result.path <- file.path(
    run.dir, "results",
    paste0(batch.id, "__", safe.file.id(dataset.id), "__chart_local_auto.rds")
  )
  auto.result.path <- file.path(
    run.dir, "results",
    paste0(batch.id, "__", safe.file.id(dataset.id), "__chart_auto.rds")
  )
  local.result <- readRDS(local.result.path)
  auto.result <- readRDS(auto.result.path)
  pointwise <- pointwise.rmse.components(asset, auto.result, local.result)
  pointwise$dataset_id <- dataset.id
  pointwise$batch_id <- batch.id
  pointwise$local_dim <- NA_integer_
  dim.values <- local.result$chart_dim_by_eval
  if (length(dim.values) != nrow(asset$X)) {
    dim.values <- rep(local.result$summary$resolved_chart_dim[[1L]], nrow(asset$X))
  }
  pointwise$local_dim <- as.integer(dim.values)
  pointwise$auto_dim <- as.integer(auto.result$summary$resolved_chart_dim[[1L]])
  pointwise$dim_deviation <- pointwise$local_dim - pointwise$auto_dim
  utils::write.csv(
    pointwise,
    file.path(pointwise.dir, paste0(batch.id, "__", safe.file.id(dataset.id),
                                    "__pointwise_rmse_components.csv")),
    row.names = FALSE
  )
  result.rows <- combined_metrics <- combined.metrics[
    combined.metrics$dataset_id == dataset.id, ,
    drop = FALSE
  ]
  selected.support <- local.result$summary$selected_support_size[[1L]]
  emb <- tryCatch({
    if (ncol(asset$X) <= 3L) direct.embedding(asset)
    else graph.embedding(asset, selected.support)
  }, error = function(e) {
    list(coords = scale.coords(stats::prcomp(asset$X, center = TRUE,
                                             scale. = TRUE)$x[, 1:3, drop = FALSE]),
         method = paste0("PCA fallback after embedding error: ",
                         conditionMessage(e)),
         graph = NULL)
  })
  embedding.records[[length(embedding.records) + 1L]] <- data.frame(
    dataset_id = dataset.id,
    p = ncol(asset$X),
    embedding_method = emb$method,
    graph_edges = if (is.null(emb$graph)) NA_integer_ else emb$graph$n_edges,
    graph_components_before = if (is.null(emb$graph)) NA_integer_ else emb$graph$n_components_before,
    graph_components_after = if (is.null(emb$graph)) NA_integer_ else emb$graph$n_components_after,
    stringsAsFactors = FALSE
  )
  title <- paste(dataset.id, "-", asset$geometry.family)
  subtitle <- emb$method
  widget <- make.rgl.widget(
    emb$coords, dim.values,
    paste(dataset.id, "- local dimension"),
    subtitle,
    width = 540,
    height = 430
  )
  contribution.widget <- make.contribution.rgl.widget(
    emb$coords,
    pointwise$rmse_component,
    paste(dataset.id, "- Truth-RMSE contribution"),
    "blue: local.auto wins; red: auto wins",
    width = 540,
    height = 430
  )
  result.fig <- file.path(fig.dir, paste0(safe.file.id(dataset.id),
                                          "_metrics.png"))
  dim.fig <- file.path(fig.dir, paste0(safe.file.id(dataset.id),
                                       "_local_dim_hist.png"))
  truth.result.plot(result.rows, dataset.id, result.fig)
  dim.hist.plot(dim.values, dataset.id, dim.fig)
  pal <- dimension.palette(dim.values)
  legend.items <- lapply(names(pal), function(dim) {
    htmltools::tags$span(
      class = "legend-item",
      htmltools::tags$span(style = sprintf("background:%s", pal[[dim]]),
                           class = "swatch"),
      paste("dim", dim)
    )
  })
  dataset.blocks[[length(dataset.blocks) + 1L]] <- htmltools::tags$section(
    class = "dataset-section",
    htmltools::tags$h2(sprintf("%s. %s", batch.id, dataset.id)),
    htmltools::tags$p(class = "meta",
      sprintf("%s; n = %d, p = %d. Points are colored by local.auto chart dimension.",
              asset$geometry.family, nrow(asset$X), ncol(asset$X))
    ),
    htmltools::tags$p(class = "meta", sprintf("Embedding: %s.", emb$method)),
    htmltools::tags$div(
      class = "widget-grid",
      htmltools::tags$figure(
        htmltools::tags$figcaption(
          "Same geometry colored by the local dimension selected by the local.auto model."
        ),
        htmltools::tags$div(class = "legend", legend.items),
        widget
      ),
      htmltools::tags$figure(
        htmltools::tags$figcaption(
          htmltools::HTML(
            "Same geometry colored by the exact pointwise contribution \\(c_i\\) to the Truth-RMSE delta. Blue means the point helps local.auto; red means it hurts local.auto."
          )
        ),
        htmltools::tags$div(
          class = "contribution-legend",
          htmltools::tags$span(class = "legend-item",
                               htmltools::tags$span(class = "swatch contribution-blue"),
                               "local.auto wins"),
          htmltools::tags$span(class = "legend-item",
                               htmltools::tags$span(class = "swatch contribution-white"),
                               "near zero"),
          htmltools::tags$span(class = "legend-item",
                               htmltools::tags$span(class = "swatch contribution-red"),
                               "auto wins")
        ),
        contribution.widget
      )
    ),
    htmltools::tags$div(
      class = "fig-grid",
      htmltools::tags$figure(
        htmltools::tags$img(src = file.path("figures", basename(result.fig))),
        htmltools::tags$figcaption(
          "Selected fit metrics for global auto and local.auto chart-dimension rules."
        )
      ),
      htmltools::tags$figure(
        htmltools::tags$img(src = file.path("figures", basename(dim.fig))),
        htmltools::tags$figcaption(
          "Distribution of per-anchor dimensions used by the local.auto fit."
        )
      )
    )
  )
}

embedding.table <- do.call(rbind, embedding.records)
utils::write.csv(embedding.table,
                 file.path(report.dir, "embedding_manifest.csv"),
                 row.names = FALSE)
utils::write.csv(wide, file.path(report.dir, "paired_truth_rmse_wide.csv"),
                 row.names = FALSE)

css <- "
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
       color: #202833; margin: 0; background: #f7f8fa; }
main { max-width: 1180px; margin: 0 auto; padding: 32px 28px 56px; background: white; }
h1 { font-size: 34px; margin: 0 0 10px; }
h2 { margin-top: 42px; border-top: 1px solid #e2e5e9; padding-top: 28px; }
h3 { margin-top: 28px; }
p { line-height: 1.5; }
.lede { font-size: 18px; color: #3b4652; }
.meta { color: #566170; margin: 6px 0; }
.note { background: #f1f5f9; border-left: 4px solid #6B8EAE; padding: 12px 14px; }
.decoder { background: #fafbfc; border: 1px solid #dfe5ec; padding: 12px 14px; margin: 16px 0 20px; }
.decoder ul { margin: 8px 0 0 20px; padding: 0; }
.decoder li { margin: 4px 0; }
.dataset-section { margin-top: 22px; }
.legend { margin: 10px 0 12px; display: flex; gap: 10px; flex-wrap: wrap; }
.legend-item { font-size: 13px; color: #3b4652; }
.swatch { display: inline-block; width: 12px; height: 12px; border-radius: 2px; margin-right: 5px; vertical-align: -1px; border: 1px solid #777; }
.contribution-blue { background: #2C7BB6; }
.contribution-white { background: #F7F7F7; }
.contribution-red { background: #D7191C; }
.contribution-legend { margin: 10px 0 12px; display: flex; gap: 10px; flex-wrap: wrap; }
.widget-grid { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 18px; align-items: start; margin: 16px 0 18px; }
.widget-grid figure { margin: 0; min-width: 0; }
.widget-grid .rglWebGL { max-width: 100%; }
.fig-grid { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 0.85fr); gap: 18px; align-items: start; }
figure { margin: 18px 0; }
figure img { width: 100%; max-width: 100%; border: 1px solid #dde2e8; background: white; }
figcaption { font-size: 13px; color: #566170; margin-top: 7px; }
table { border-collapse: collapse; width: 100%; font-size: 13px; }
th, td { border-bottom: 1px solid #e2e5e9; text-align: left; padding: 6px 8px; }
th { background: #f3f5f7; }
code { background: #eef1f4; padding: 1px 4px; border-radius: 3px; }
@media (max-width: 1050px) { .widget-grid { grid-template-columns: 1fr; } }
@media (max-width: 850px) { .fig-grid { grid-template-columns: 1fr; } main { padding: 22px 16px; } }
"

summary.table <- combined[, c("dataset_id", "chart_dim_rule", "truth_rmse",
                              "observed_rmse", "selected_cv_rmse_observed",
                              "selected_support_size", "selected_kernel",
                              "resolved_chart_dim",
                              "chart_dim_by_eval_median",
                              "elapsed_sec")]
summary.table$truth_rmse <- signif(summary.table$truth_rmse, 4)
summary.table$observed_rmse <- signif(summary.table$observed_rmse, 4)
summary.table$selected_cv_rmse_observed <- signif(summary.table$selected_cv_rmse_observed, 4)

page <- htmltools::tagList(
  htmltools::tags$head(
    htmltools::tags$title("LPS local.auto Geometry and Performance Report"),
    htmltools::tags$meta(charset = "utf-8"),
    htmltools::tags$script(
      src = "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js",
      async = NA
    ),
    htmltools::tags$style(css)
  ),
  htmltools::tags$main(
    htmltools::tags$h1("LPS local.auto Geometry and Performance Report"),
    htmltools::tags$p(
      class = "lede",
      "This report visualizes each frozen non-manifold dataset and compares ",
      htmltools::tags$code('chart.dim = "auto"'),
      " with ",
      htmltools::tags$code('chart.dim = "local.auto"'),
      " for the completed first-batch LPS run."
    ),
    htmltools::tags$p(
      "The chart dimension controls how many local PCA coordinates are used by the local polynomial smoother near each evaluation point. ",
      "With ",
      htmltools::tags$code('chart.dim = "auto"'),
      ", the package estimates one global chart dimension from the observed covariate matrix and then uses that same dimension for every local fit in the dataset. ",
      "This is natural when the data are expected to lie near a single manifold of roughly constant intrinsic dimension."
    ),
    htmltools::tags$p(
      "With ",
      htmltools::tags$code('chart.dim = "local.auto"'),
      ", the package estimates the chart dimension separately at each anchor or evaluation point, using only the local neighborhood of observed covariates available to that local fit. ",
      "This is meant for non-manifold or mixed-dimensional state spaces, where one region may look one-dimensional, another may look two-dimensional, and another may have a higher effective local dimension. ",
      "The report colors each dataset visualization by these per-anchor local dimensions."
    ),
    htmltools::tags$section(
      class = "decoder",
      htmltools::tags$h2("Dataset Label Decoder"),
      htmltools::tags$p(
        "Each dataset heading has the form ",
        htmltools::tags$code("FB##. FAMILY-DETAILS-N###"),
        ". The batch prefix is an audit identifier, and the dataset ID describes the frozen geometry."
      ),
      htmltools::tags$ul(
        htmltools::tags$li(
          htmltools::tags$code("FB##"),
          " means first-batch registry item number ",
          htmltools::tags$code("##"),
          ". For example, ",
          htmltools::tags$code("FB01"),
          " is the first frozen asset in this batch."
        ),
        htmltools::tags$li(
          htmltools::tags$code("LA"),
          " means a local-auto evaluation asset for the LPS ",
          htmltools::tags$code('chart.dim = "auto"'),
          " versus ",
          htmltools::tags$code('chart.dim = "local.auto"'),
          " comparison."
        ),
        htmltools::tags$li(
          htmltools::tags$code("D1"),
          ", ",
          htmltools::tags$code("D2"),
          ", and ",
          htmltools::tags$code("D3"),
          " mean VALENCIA depth-1, depth-2, and depth-3 merged dCST component systems."
        ),
        htmltools::tags$li(
          htmltools::tags$code("RAW"),
          " means the relative-abundance component matrix itself, row-normalized to sum to one."
        ),
        htmltools::tags$li(
          htmltools::tags$code("HC"),
          " means an extended homogeneous or hypercube embedding. A suffix such as ",
          htmltools::tags$code("Li"),
          ", ",
          htmltools::tags$code("Lc"),
          ", ",
          htmltools::tags$code("Gv"),
          ", or ",
          htmltools::tags$code("Bv"),
          " gives the reference component; ",
          htmltools::tags$code("TOP1"),
          " means the most prevalent component was used as the reference."
        ),
        htmltools::tags$li(
          htmltools::tags$code("13K-SUB"),
          " means a stratified subsample from the VALENCIA 13k phylotype relative-abundance matrix."
        ),
        htmltools::tags$li(
          htmltools::tags$code("SYN"),
          " means a synthetic mixed-dimensional geometry, such as a surface plus a line, intersecting planes, simplex faces, or high-dimensional rank blocks."
        ),
        htmltools::tags$li(
          htmltools::tags$code("N###"),
          " gives the sample size. For example, ",
          htmltools::tags$code("N500"),
          " means 500 samples."
        )
      ),
      htmltools::tags$p(
        "Example: ",
        htmltools::tags$code("FB01. LA-D1-RAW-N500"),
        " is first-batch item 01: a local-auto comparison asset built from the VALENCIA depth-1 dCST raw relative-abundance coordinates with 500 samples."
      )
    ),
    htmltools::tags$p(
      "The summary comparison follows the Codex HTML report convention for paired method comparisons. ",
      "For a synthetic dataset, the observed response is the true signal plus noise:"
    ),
    htmltools::tags$p(
      htmltools::HTML(
        "\\[
          y_i = f_i + \\varepsilon_i,
          \\qquad i = 1,\\ldots,n.
        \\]"
      )
    ),
    htmltools::tags$p(
      "For fitted values, the synthetic target is Truth RMSE:"
    ),
    htmltools::tags$p(
      htmltools::HTML(
        "\\[
          \\operatorname{TruthRMSE}(\\widehat f)
          =
          \\left\\{
            \\frac{1}{n}
            \\sum_{i=1}^{n}
            \\left(\\widehat f_i - f_i\\right)^2
          \\right\\}^{1/2}.
        \\]"
      )
    ),
    htmltools::tags$p(
      "Truth RMSE is the quantity we would minimize if the true function were known. ",
      "It is available here only because these are synthetic or synthetic-truth examples; it is the oracle diagnostic used to judge whether a deployable selection rule chose a good fit."
    ),
    htmltools::tags$p(
      "The report also includes Observed RMSE:"
    ),
    htmltools::tags$p(
      htmltools::HTML(
        "\\[
          \\operatorname{ObservedRMSE}(\\widehat f)
          =
          \\left\\{
            \\frac{1}{n}
            \\sum_{i=1}^{n}
            \\left(\\widehat f_i - y_i\\right)^2
          \\right\\}^{1/2}.
        \\]"
      )
    ),
    htmltools::tags$p(
      "Observed RMSE measures how closely the selected full-data fit follows the noisy observations. ",
      "It is not the synthetic target, because following ",
      "the noisy observations too closely can mean interpolation or overfitting. ",
      "It is used here as an interpretability and overfit diagnostic alongside Truth RMSE."
    ),
    htmltools::tags$p(
      "The selection score reported as CV RMSE is the fold-weighted validation RMSE:"
    ),
    htmltools::tags$p(
      htmltools::HTML(
        "\\[
          \\operatorname{CVRMSE}(\\theta)
          =
          \\left\\{
            \\frac{1}{n}
            \\sum_{k=1}^{K}
            \\sum_{i \\in V_k}
            \\left(
              \\widehat f^{(-k)}_{\\theta,i} - y_i
            \\right)^2
          \\right\\}^{1/2},
        \\]"
      )
    ),
    htmltools::tags$p(
      "The notation in this formula means that each validation fold is indexed by k, and the fitted value with superscript minus k is predicted from a model trained without that fold. ",
      "CV RMSE is the deployable quantity: it aims to estimate Truth RMSE when the true signal is unknown, as it would be in real applications."
    ),
    htmltools::tags$p(
      "The paired comparison plotted below uses the dataset-level Truth-RMSE delta"
    ),
    htmltools::tags$p(
      htmltools::HTML(
        "\\[
          \\Delta_j
          =
          \\operatorname{TruthRMSE}_{j}(\\mathrm{local.auto})
          -
          \\operatorname{TruthRMSE}_{j}(\\mathrm{auto}).
        \\]"
      )
    ),
    htmltools::tags$p(
      "Positive values mean that ",
      htmltools::tags$code('chart.dim = "local.auto"'),
      " is worse than ",
      htmltools::tags$code('chart.dim = "auto"'),
      " on the corresponding dataset. The red point and interval summarize the Bayesian-bootstrap median paired delta and its 95% credible interval."
    ),
    htmltools::tags$p(
      "For the per-dataset geometry views, the report also computes the exact pointwise contribution"
    ),
    htmltools::tags$p(
      htmltools::HTML(
        "\\[
          c_i
          =
          \\frac{
            (\\widehat f_i^{\\,local.auto}-f_i)^2
            -
            (\\widehat f_i^{\\,auto}-f_i)^2
          }{
            n\\{\\operatorname{TruthRMSE}(local.auto)
            + \\operatorname{TruthRMSE}(auto)\\}
          }.
        \\]"
      )
    ),
    htmltools::tags$p(
      "These components sum exactly to the dataset-level Truth-RMSE delta. ",
      "A blue point has negative contribution and helps ",
      htmltools::tags$code('chart.dim = "local.auto"'),
      "; a red point has positive contribution and helps ",
      htmltools::tags$code('chart.dim = "auto"'),
      "."
    ),
    htmltools::tags$h2("Summary Pairwise Comparison"),
    htmltools::tags$figure(
      htmltools::tags$img(src = file.path("figures", basename(summary.fig))),
      htmltools::tags$figcaption(
        sprintf(
          "Bayesian-bootstrap median paired delta = %.4g, 95%% CrI [%.4g, %.4g], over %d matched datasets.",
          bb[["median"]], bb[["lo"]], bb[["hi"]], nrow(wide)
        )
      )
    ),
    htmltools::tags$h2("Dataset Visualizations"),
    htmltools::tags$p(
      "For ambient dimension p <= 3, the widget shows the dataset in native ambient coordinates, centered and scaled. ",
      "For p > 3, the widget shows vertices of an adaptive-radius kNN graph with edges hidden; the layout uses classical MDS followed by weighted KK polish when possible. ",
      "Every widget colors points by the per-anchor local dimension selected by the local.auto model."
    ),
    dataset.blocks,
    htmltools::tags$h2("Compact Result Table"),
    htmltools::tags$p(
      "The table is included only as a compact audit aid; the figures above are the primary human-readable views."
    ),
    htmltools::HTML(knitr::kable(summary.table, format = "html", row.names = FALSE))
  )
)

out.file <- file.path(report.dir, "lps_local_auto_geometry_report.html")
htmltools::save_html(page, file = out.file, libdir = "lib")
cat("HTML report:", out.file, "\n")
cat("Embedding manifest:", file.path(report.dir, "embedding_manifest.csv"), "\n")
cat("Paired table:", file.path(report.dir, "paired_truth_rmse_wide.csv"), "\n")
