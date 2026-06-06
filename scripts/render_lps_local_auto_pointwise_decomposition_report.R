#!/usr/bin/env Rscript

repo.dir <- normalizePath("/Users/pgajer/current_projects/geosmooth", mustWork = TRUE)
freeze.dir <- file.path(
  repo.dir,
  "split_handoffs",
  "lps_local_auto_nonmanifold_first_batch_2026-06-05"
)
run.dir <- file.path(freeze.dir, "runs", "lps_local_auto_fb_20260605_001")
report.dir <- file.path(
  repo.dir,
  "split_handoffs",
  "lps_local_auto_pointwise_decomposition_2026-06-05"
)
fig.dir <- file.path(report.dir, "figures")
tab.dir <- file.path(report.dir, "tables")
dir.create(fig.dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tab.dir, recursive = TRUE, showWarnings = FALSE)

need <- c("ggplot2", "scales")
missing <- need[!vapply(need, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop("Missing required packages: ", paste(missing, collapse = ", "), call. = FALSE)
}

asset <- readRDS(file.path(freeze.dir, "assets", "LA-D1-RAW-N500.rds"))
auto <- readRDS(file.path(run.dir, "results", "FB01__LA_D1_RAW_N500__chart_auto.rds"))
local.auto <- readRDS(file.path(run.dir, "results", "FB01__LA_D1_RAW_N500__chart_local_auto.rds"))

dataset.id <- asset$dataset.id
n <- length(asset$f)
e.auto <- as.numeric(auto$predictions - asset$f)
e.local <- as.numeric(local.auto$predictions - asset$f)
r.auto <- sqrt(mean(e.auto^2))
r.local <- sqrt(mean(e.local^2))
delta.rmse <- r.local - r.auto
delta.mse <- r.local^2 - r.auto^2
denom <- n * (r.local + r.auto)
component <- if (denom > 0) {
  (e.local^2 - e.auto^2) / denom
} else {
  rep(0, n)
}
mse.component <- (e.local^2 - e.auto^2) / n

global.dim <- as.integer(auto$summary$resolved_chart_dim[[1L]])
local.dim <- as.integer(local.auto$chart_dim_by_eval)
dim.dev <- local.dim - global.dim
region <- as.character(asset$region.label)
if (length(region) != n) region <- rep(NA_character_, n)
region[is.na(region) | !nzchar(region)] <- "unlabeled"

pc <- stats::prcomp(as.matrix(asset$X), center = TRUE, scale. = TRUE)
pc.coords <- pc$x[, seq_len(min(2L, ncol(pc$x))), drop = FALSE]
if (ncol(pc.coords) < 2L) {
  pc.coords <- cbind(pc.coords, 0)
}
colnames(pc.coords) <- c("PC1", "PC2")

df <- data.frame(
  point = seq_len(n),
  truth = as.numeric(asset$f),
  y = as.numeric(asset$y),
  fit_auto = as.numeric(auto$predictions),
  fit_local_auto = as.numeric(local.auto$predictions),
  error_auto = e.auto,
  error_local_auto = e.local,
  abs_error_auto = abs(e.auto),
  abs_error_local_auto = abs(e.local),
  squared_error_auto = e.auto^2,
  squared_error_local_auto = e.local^2,
  rmse_component = component,
  mse_component = mse.component,
  local_dim = local.dim,
  auto_dim = global.dim,
  dim_deviation = dim.dev,
  region = region,
  PC1 = pc.coords[, 1],
  PC2 = pc.coords[, 2],
  stringsAsFactors = FALSE
)
df$helps_local_auto <- df$rmse_component < 0
df$component_abs_rank <- rank(-abs(df$rmse_component), ties.method = "first")
df$component_signed_rank <- rank(-df$rmse_component, ties.method = "first")

utils::write.csv(df, file.path(tab.dir, "fb01_pointwise_decomposition.csv"),
                 row.names = FALSE)

dim.summary <- aggregate(
  rmse_component ~ local_dim + dim_deviation,
  data = df,
  FUN = sum
)
names(dim.summary)[names(dim.summary) == "rmse_component"] <- "sum_rmse_component"
dim.count <- aggregate(point ~ local_dim + dim_deviation, data = df, FUN = length)
names(dim.count)[names(dim.count) == "point"] <- "n_points"
dim.summary <- merge(dim.summary, dim.count, by = c("local_dim", "dim_deviation"))
dim.summary <- dim.summary[order(dim.summary$local_dim), ]
utils::write.csv(dim.summary, file.path(tab.dir, "fb01_grouped_by_dimension.csv"),
                 row.names = FALSE)

region.summary <- aggregate(rmse_component ~ region, data = df, FUN = sum)
names(region.summary)[names(region.summary) == "rmse_component"] <- "sum_rmse_component"
region.count <- aggregate(point ~ region, data = df, FUN = length)
names(region.count)[names(region.count) == "point"] <- "n_points"
region.summary <- merge(region.summary, region.count, by = "region")
region.summary <- region.summary[order(region.summary$sum_rmse_component), ]
utils::write.csv(region.summary, file.path(tab.dir, "fb01_grouped_by_region.csv"),
                 row.names = FALSE)

fmt <- function(x, digits = 4) formatC(x, digits = digits, format = "fg", flag = "#")
fmt.int <- function(x) formatC(x, format = "d")

tex.summary <- c(
  sprintf("\\newcommand{\\fbDatasetId}{%s}", dataset.id),
  sprintf("\\newcommand{\\fbN}{%s}", fmt.int(n)),
  sprintf("\\newcommand{\\fbAutoDim}{%s}", fmt.int(global.dim)),
  sprintf("\\newcommand{\\fbAutoTruthRmse}{%s}", fmt(r.auto, 5)),
  sprintf("\\newcommand{\\fbLocalTruthRmse}{%s}", fmt(r.local, 5)),
  sprintf("\\newcommand{\\fbDeltaTruthRmse}{%s}", fmt(delta.rmse, 5)),
  sprintf("\\newcommand{\\fbDeltaTruthMse}{%s}", fmt(delta.mse, 5)),
  sprintf("\\newcommand{\\fbComponentSum}{%s}", fmt(sum(component), 5)),
  sprintf("\\newcommand{\\fbDimOneCount}{%s}", fmt.int(sum(local.dim == 1L))),
  sprintf("\\newcommand{\\fbDimTwoCount}{%s}", fmt.int(sum(local.dim == 2L))),
  sprintf("\\newcommand{\\fbDimThreeCount}{%s}", fmt.int(sum(local.dim == 3L))),
  sprintf("\\newcommand{\\fbAutoSupport}{%s}", fmt.int(auto$summary$selected_support_size[[1L]])),
  sprintf("\\newcommand{\\fbLocalSupport}{%s}", fmt.int(local.auto$summary$selected_support_size[[1L]])),
  sprintf("\\newcommand{\\fbAutoKernel}{%s}", auto$summary$selected_kernel[[1L]]),
  sprintf("\\newcommand{\\fbLocalKernel}{%s}", local.auto$summary$selected_kernel[[1L]]),
  sprintf("\\newcommand{\\fbTopTenAbsPct}{%s}", fmt(100 * sum(df$rmse_component[df$component_abs_rank <= 10]) / delta.rmse, 4)),
  sprintf("\\newcommand{\\fbTopTwentyAbsPct}{%s}", fmt(100 * sum(df$rmse_component[df$component_abs_rank <= 20]) / delta.rmse, 4))
)
writeLines(tex.summary, file.path(report.dir, "fb01_summary_macros.tex"))

utils::write.csv(data.frame(
  measure = c("Truth RMSE auto", "Truth RMSE local.auto",
              "Truth RMSE delta", "sum pointwise components",
              "Truth MSE delta"),
  value = c(r.auto, r.local, delta.rmse, sum(component), delta.mse)
), file.path(tab.dir, "fb01_scalar_checks.csv"), row.names = FALSE)

theme_report <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(color = "#4b5563"),
      panel.grid.minor = ggplot2::element_blank()
    )
}

component.lims <- max(abs(df$rmse_component), na.rm = TRUE)
component.cols <- ggplot2::scale_color_gradient2(
  low = "#2C7BB6", mid = "#f7f7f7", high = "#D7191C",
  midpoint = 0,
  limits = c(-component.lims, component.lims),
  labels = scales::label_number(accuracy = 0.0001),
  name = "point contribution"
)

p1 <- ggplot2::ggplot(df, ggplot2::aes(
  x = factor(dim_deviation),
  y = rmse_component,
  color = rmse_component
)) +
  ggplot2::geom_hline(yintercept = 0, linewidth = 0.35, linetype = "dashed") +
  ggplot2::geom_jitter(width = 0.16, height = 0, alpha = 0.82, size = 1.8) +
  component.cols +
  ggplot2::labs(
    title = "Pointwise RMSE-delta contribution by local dimension deviation",
    subtitle = "Negative values help local.auto; positive values hurt local.auto.",
    x = "local.auto chart dimension minus global auto dimension",
    y = "pointwise component of Truth-RMSE delta"
  ) +
  theme_report()
ggplot2::ggsave(file.path(fig.dir, "fb01_contribution_by_dimension.png"),
                p1, width = 7.2, height = 4.6, dpi = 220)

max.err <- max(abs(c(df$error_auto, df$error_local_auto)), na.rm = TRUE)
p2 <- ggplot2::ggplot(df, ggplot2::aes(
  x = error_auto,
  y = error_local_auto,
  color = dim_deviation
)) +
  ggplot2::geom_abline(slope = 1, intercept = 0, color = "#444444",
                       linetype = "solid", linewidth = 0.4) +
  ggplot2::geom_abline(slope = -1, intercept = 0, color = "#777777",
                       linetype = "dashed", linewidth = 0.4) +
  ggplot2::geom_point(alpha = 0.78, size = 1.8) +
  ggplot2::coord_equal(xlim = c(-max.err, max.err), ylim = c(-max.err, max.err)) +
  ggplot2::scale_color_gradient2(
    low = "#2C7BB6", mid = "#f7f7f7", high = "#D7191C",
    midpoint = 0, breaks = sort(unique(df$dim_deviation)),
    name = "dimension deviation"
  ) +
  ggplot2::labs(
    title = "Truth-error scatter: local.auto versus auto",
    subtitle = "Inside the dashed wedge |local.auto error| < |auto error|, local.auto has smaller pointwise truth error.",
    x = "auto truth error",
    y = "local.auto truth error"
  ) +
  theme_report()
ggplot2::ggsave(file.path(fig.dir, "fb01_error_error_scatter.png"),
                p2, width = 6.6, height = 5.8, dpi = 220)

p3 <- ggplot2::ggplot(df, ggplot2::aes(
  x = PC1, y = PC2, color = rmse_component
)) +
  ggplot2::geom_point(alpha = 0.86, size = 1.9) +
  component.cols +
  ggplot2::labs(
    title = "Geometry view colored by pointwise contribution",
    subtitle = "Two-dimensional PCA projection of the four-component composition.",
    x = "PC1 of observed coordinates",
    y = "PC2 of observed coordinates"
  ) +
  theme_report()
ggplot2::ggsave(file.path(fig.dir, "fb01_geometry_contribution_pca.png"),
                p3, width = 7.1, height = 5.2, dpi = 220)

df.cum <- df[order(-abs(df$rmse_component)), ]
df.cum$cumulative_component <- cumsum(df.cum$rmse_component)
df.cum$rank_by_abs_component <- seq_len(nrow(df.cum))
p4 <- ggplot2::ggplot(df.cum, ggplot2::aes(
  x = rank_by_abs_component,
  y = cumulative_component
)) +
  ggplot2::geom_hline(yintercept = delta.rmse, color = "#D7191C",
                      linewidth = 0.5, linetype = "dashed") +
  ggplot2::geom_line(color = "#2C7BB6", linewidth = 0.7) +
  ggplot2::labs(
    title = "Cumulative contribution sorted by absolute point impact",
    subtitle = "A steep early curve means a few points dominate the dataset-level delta.",
    x = "points included, sorted by decreasing absolute contribution",
    y = "cumulative Truth-RMSE delta contribution"
  ) +
  theme_report()
ggplot2::ggsave(file.path(fig.dir, "fb01_cumulative_contribution.png"),
                p4, width = 7.2, height = 4.6, dpi = 220)

dim.summary$dimension_label <- paste0(
  "local dim ", dim.summary$local_dim,
  " (dev ", ifelse(dim.summary$dim_deviation >= 0, "+", ""),
  dim.summary$dim_deviation, ")"
)
p5 <- ggplot2::ggplot(dim.summary, ggplot2::aes(
  x = reorder(dimension_label, sum_rmse_component),
  y = sum_rmse_component,
  color = sum_rmse_component
)) +
  ggplot2::geom_hline(yintercept = 0, linewidth = 0.35, linetype = "dashed") +
  ggplot2::geom_segment(ggplot2::aes(xend = dimension_label, y = 0,
                                     yend = sum_rmse_component),
                        color = "#9aa3ad", linewidth = 0.5) +
  ggplot2::geom_point(size = 3.4) +
  ggplot2::geom_text(ggplot2::aes(label = paste0("n=", n_points)),
                     hjust = -0.15, size = 3) +
  component.cols +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = "Grouped contribution by selected local dimension",
    subtitle = "Group sums add to the dataset-level Truth-RMSE delta.",
    x = NULL,
    y = "sum of pointwise components"
  ) +
  theme_report()
ggplot2::ggsave(file.path(fig.dir, "fb01_grouped_contribution_by_dimension.png"),
                p5, width = 7.2, height = 4.5, dpi = 220)

cat("Report assets written to:", report.dir, "\n")
