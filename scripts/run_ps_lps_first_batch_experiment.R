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
out.dir <- file.path(
  repo.dir,
  "split_handoffs",
  "ps_lps_first_batch_experiment_2026-06-05"
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
  stop("Missing required packages: ", paste(missing, collapse = ", "), call. = FALSE)
}

pkgload::load_all(repo.dir, quiet = TRUE)

safe.id <- function(x) gsub("[^A-Za-z0-9_]+", "_", x)
rmse <- function(x, y) sqrt(mean((as.numeric(x) - as.numeric(y))^2))
read.csv.safe <- function(path) utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
write.csv.safe <- function(x, path) utils::write.csv(x, path, row.names = FALSE, na = "")
fmt <- function(x, digits = 5) ifelse(is.finite(x), formatC(x, digits = digits, format = "fg"), "")

lambda.grid <- as.numeric(strsplit(Sys.getenv("PS_LPS_LAMBDA_GRID", "0,0.1,1"), ",")[[1L]])
sync.neighbor.size <- as.integer(Sys.getenv("PS_LPS_SYNC_NEIGHBOR_SIZE", "3"))

asset.manifest <- read.csv.safe(file.path(freeze.dir, "asset_manifest.csv"))
asset.manifest <- asset.manifest[order(asset.manifest[["batch.id"]]), ]
ordinary <- read.csv.safe(file.path(run.dir, "tables", "combined_results.csv"))

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
  source.rule <- if (identical(variant, "ps_auto")) "auto" else "local.auto"
  source.file.rule <- gsub("\\.", "_", source.rule)
  lps.path <- file.path(
    run.dir,
    "results",
    sprintf("%s__%s__chart_%s.rds", batch.id, safe.id(dataset.id), source.file.rule)
  )
  lps.result <- readRDS(lps.path)
  chart.dim <- if (identical(variant, "ps_auto")) {
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
      lambda.sync.grid = lambda.grid,
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
    mean.sync.disagreement = fit$mean.sync.disagreement,
    support.size = fit$support.size,
    degree = fit$degree,
    kernel = fit$kernel,
    chart.dim.summary = if (length(unique(fit$chart.dim.by.anchor)) == 1L) {
      unique(fit$chart.dim.by.anchor)
    } else {
      stats::median(fit$chart.dim.by.anchor)
    },
    chart.dim.by.anchor = fit$chart.dim.by.anchor,
    truth_rmse = rmse(fit$fitted.values, asset$f),
    observed_rmse = rmse(fit$fitted.values, asset$y)
  )
  saveRDS(out, result.path)
  out
}

all.results <- list()
for (aa in seq_len(nrow(asset.manifest))) {
  for (variant in c("ps_auto", "ps_local_auto")) {
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

ps.summary <- do.call(rbind, lapply(all.results, function(x) {
  if (!identical(x$status, "ok")) {
    return(data.frame(
      batch_id = x$batch_id,
      dataset_id = x$dataset_id,
      method = ifelse(x$variant == "ps_auto", "PS-LPS auto", "PS-LPS local.auto"),
      status = x$status,
      selected_lambda_sync = NA_real_,
      selected_support_size = NA_integer_,
      selected_degree = NA_integer_,
      selected_kernel = NA_character_,
      selected_chart_dim = NA_real_,
      selected_cv_rmse_observed = NA_real_,
      observed_rmse = NA_real_,
      truth_rmse = NA_real_,
      total_local_gcv_ps = NA_real_,
      sync_energy = NA_real_,
      mean_sync_disagreement = NA_real_,
      elapsed_sec = x$elapsed_sec,
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    batch_id = x$batch_id,
    dataset_id = x$dataset_id,
    method = ifelse(x$variant == "ps_auto", "PS-LPS auto", "PS-LPS local.auto"),
    status = x$status,
    selected_lambda_sync = x$selected$lambda.sync[[1L]],
    selected_support_size = x$support.size,
    selected_degree = x$degree,
    selected_kernel = x$kernel,
    selected_chart_dim = x$chart.dim.summary,
    selected_cv_rmse_observed = x$selected$cv.rmse.observed[[1L]],
    observed_rmse = x$observed_rmse,
    truth_rmse = x$truth_rmse,
    total_local_gcv_ps = x$total.local.gcv.ps,
    sync_energy = x$sync.energy,
    mean_sync_disagreement = x$mean.sync.disagreement,
    elapsed_sec = x$elapsed_sec,
    stringsAsFactors = FALSE
  )
}))

ordinary.summary <- rbind(
  data.frame(
    batch_id = ordinary$batch_id[ordinary$chart_dim_rule == "auto"],
    dataset_id = ordinary$dataset_id[ordinary$chart_dim_rule == "auto"],
    method = "LPS auto",
    status = "ok",
    selected_lambda_sync = NA_real_,
    selected_support_size = ordinary$selected_support_size[ordinary$chart_dim_rule == "auto"],
    selected_degree = ordinary$selected_degree[ordinary$chart_dim_rule == "auto"],
    selected_kernel = ordinary$selected_kernel[ordinary$chart_dim_rule == "auto"],
    selected_chart_dim = ordinary$resolved_chart_dim[ordinary$chart_dim_rule == "auto"],
    selected_cv_rmse_observed = ordinary$selected_cv_rmse_observed[ordinary$chart_dim_rule == "auto"],
    observed_rmse = ordinary$observed_rmse[ordinary$chart_dim_rule == "auto"],
    truth_rmse = ordinary$truth_rmse[ordinary$chart_dim_rule == "auto"],
    total_local_gcv_ps = NA_real_,
    sync_energy = NA_real_,
    mean_sync_disagreement = NA_real_,
    elapsed_sec = ordinary$elapsed_sec[ordinary$chart_dim_rule == "auto"],
    stringsAsFactors = FALSE
  ),
  data.frame(
    batch_id = ordinary$batch_id[ordinary$chart_dim_rule == "local.auto"],
    dataset_id = ordinary$dataset_id[ordinary$chart_dim_rule == "local.auto"],
    method = "LPS local.auto",
    status = "ok",
    selected_lambda_sync = NA_real_,
    selected_support_size = ordinary$selected_support_size[ordinary$chart_dim_rule == "local.auto"],
    selected_degree = ordinary$selected_degree[ordinary$chart_dim_rule == "local.auto"],
    selected_kernel = ordinary$selected_kernel[ordinary$chart_dim_rule == "local.auto"],
    selected_chart_dim = ordinary$resolved_chart_dim[ordinary$chart_dim_rule == "local.auto"],
    selected_cv_rmse_observed = ordinary$selected_cv_rmse_observed[ordinary$chart_dim_rule == "local.auto"],
    observed_rmse = ordinary$observed_rmse[ordinary$chart_dim_rule == "local.auto"],
    truth_rmse = ordinary$truth_rmse[ordinary$chart_dim_rule == "local.auto"],
    total_local_gcv_ps = NA_real_,
    sync_energy = NA_real_,
    mean_sync_disagreement = NA_real_,
    elapsed_sec = ordinary$elapsed_sec[ordinary$chart_dim_rule == "local.auto"],
    stringsAsFactors = FALSE
  )
)

comparison <- rbind(ordinary.summary, ps.summary)
comparison$method <- factor(
  comparison$method,
  levels = c("LPS auto", "LPS local.auto", "PS-LPS auto", "PS-LPS local.auto")
)
comparison$dataset_label <- paste(comparison$batch_id, comparison$dataset_id)
comparison$best_truth_rmse <- ave(comparison$truth_rmse, comparison$batch_id, FUN = min)
comparison$truth_rmse_delta_from_best <- comparison$truth_rmse - comparison$best_truth_rmse
write.csv.safe(comparison, file.path(table.dir, "ps_lps_first_batch_method_comparison.csv"))
write.csv.safe(ps.summary, file.path(table.dir, "ps_lps_first_batch_summary.csv"))

lambda.rows <- do.call(rbind, lapply(all.results, function(x) {
  if (!identical(x$status, "ok")) return(NULL)
  tab <- x$cv.table
  tab$batch_id <- x$batch_id
  tab$dataset_id <- x$dataset_id
  tab$method <- ifelse(x$variant == "ps_auto", "PS-LPS auto", "PS-LPS local.auto")
  tab[, c("batch_id", "dataset_id", "method", setdiff(names(tab), c("batch_id", "dataset_id", "method")))]
}))
write.csv.safe(lambda.rows, file.path(table.dir, "ps_lps_lambda_cv_gcv_table.csv"))

pointwise <- list()
for (aa in seq_len(nrow(asset.manifest))) {
  batch.id <- asset.manifest[["batch.id"]][[aa]]
  dataset.id <- asset.manifest[["dataset.id"]][[aa]]
  asset <- readRDS(asset.manifest[["asset.path"]][[aa]])
  auto <- readRDS(file.path(
    run.dir,
    "results",
    sprintf("%s__%s__chart_auto.rds", batch.id, safe.id(dataset.id))
  ))
  e.auto <- as.numeric(auto$predictions - asset$f)
  r.auto <- sqrt(mean(e.auto^2))
  for (variant in c("ps_auto", "ps_local_auto")) {
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
      method = ifelse(variant == "ps_auto", "PS-LPS auto", "PS-LPS local.auto"),
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
write.csv.safe(pointwise, file.path(table.dir, "ps_lps_pointwise_components.csv"))

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
    title = "Truth RMSE: ordinary LPS versus PS-LPS variants",
    x = NULL,
    y = "Truth RMSE"
  ) +
  theme.report +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 35, hjust = 1))
ggplot2::ggsave(file.path(fig.dir, "truth_rmse_lps_vs_ps_lps.png"),
                p.truth, width = 12, height = 8, dpi = 180)

ps.selected <- comparison[grepl("^PS-LPS", as.character(comparison$method)), ,
                          drop = FALSE]
ps.selected$lambda_label <- paste0("lambda = ", ps.selected$selected_lambda_sync)
p.gcv.truth <- ggplot2::ggplot(
  ps.selected,
  ggplot2::aes(x = total_local_gcv_ps, y = truth_rmse, color = method,
               shape = lambda_label)
) +
  ggplot2::geom_point(size = 2.5, alpha = 0.9) +
  ggplot2::geom_text(
    ggplot2::aes(label = batch_id),
    nudge_y = 0.002,
    size = 2.8,
    show.legend = FALSE
  ) +
  ggplot2::scale_x_log10() +
  ggplot2::labs(
    title = "Selected PS-LPS total local GCV versus Truth RMSE",
    subtitle = "Each point is one selected PS-LPS fit on one first-batch dataset.",
    x = "Total synchronized local GCV (log scale)",
    y = "Truth RMSE",
    color = NULL,
    shape = NULL
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_selected_total_gcv_vs_truth_rmse.png"),
                p.gcv.truth, width = 9, height = 6, dpi = 180)

source.rows <- comparison[comparison$method %in% c("LPS auto", "LPS local.auto"),
                          c("batch_id", "method", "truth_rmse"),
                          drop = FALSE]
names(source.rows) <- c("batch_id", "source_method", "source_truth_rmse")
ps.delta <- ps.selected
ps.delta$source_method <- ifelse(
  ps.delta$method == "PS-LPS auto",
  "LPS auto",
  "LPS local.auto"
)
ps.delta <- merge(ps.delta, source.rows,
                  by = c("batch_id", "source_method"),
                  all.x = TRUE, sort = FALSE)
ps.delta$truth_rmse_delta_vs_source <-
  ps.delta$truth_rmse - ps.delta$source_truth_rmse
p.sync.delta <- ggplot2::ggplot(
  ps.delta,
  ggplot2::aes(x = sync_energy, y = truth_rmse_delta_vs_source,
               color = method, shape = lambda_label)
) +
  ggplot2::geom_hline(yintercept = 0, color = "grey55") +
  ggplot2::geom_point(size = 2.5, alpha = 0.9) +
  ggplot2::geom_text(
    ggplot2::aes(label = batch_id),
    nudge_y = -0.0015,
    size = 2.8,
    show.legend = FALSE
  ) +
  ggplot2::labs(
    title = "Truth-RMSE change versus synchronization energy",
    subtitle = "Negative values mean PS-LPS improved over the corresponding ordinary LPS source fit.",
    x = "Synchronization energy",
    y = "Truth RMSE minus source ordinary LPS Truth RMSE",
    color = NULL,
    shape = NULL
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_sync_energy_vs_truth_rmse_delta.png"),
                p.sync.delta, width = 9, height = 6, dpi = 180)

p.lambda <- ggplot2::ggplot(
  lambda.rows,
  ggplot2::aes(x = total.local.gcv.ps, y = cv.rmse.observed, color = factor(lambda.sync))
) +
  ggplot2::geom_point(size = 1.8, alpha = 0.85) +
  ggplot2::facet_wrap(~ method, scales = "free", ncol = 2) +
  ggplot2::labs(
    title = "PS-LPS total local GCV versus CV RMSE across lambda candidates",
    x = "Total synchronized local GCV",
    y = "CV RMSE",
    color = expression(lambda[sync])
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_total_gcv_vs_cv_rmse.png"),
                p.lambda, width = 10, height = 6, dpi = 180)

pointwise$component_sign <- ifelse(pointwise$rmse_component_vs_lps_auto > 0,
                                   "PS-LPS worse than LPS auto",
                                   "PS-LPS better than LPS auto")
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
    title = "Pointwise Truth-RMSE components for PS-LPS versus LPS auto",
    x = "PS-LPS local GCV (log scale)",
    y = expression(c[i]),
    color = "df/k"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_pointwise_components.png"),
                p.point, width = 13, height = 7, dpi = 180)

best <- comparison[order(comparison$batch_id, comparison$truth_rmse), ]
best <- best[!duplicated(best$batch_id), ]
best.count <- table(best$method)

table.html <- function(df, max.rows = 50L) {
  df <- head(df, max.rows)
  htmltools::tags$table(
    class = "data-table",
    htmltools::tags$thead(htmltools::tags$tr(lapply(names(df), htmltools::tags$th))),
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
.note { max-width: 980px; }
.figure { margin: 24px 0 30px; }
.figure img { max-width: 100%; border: 1px solid #ddd; }
.caption { font-size: 0.94rem; color: #53606c; max-width: 980px; }
.data-table { border-collapse: collapse; font-size: 0.88rem; margin: 12px 0 24px; }
.data-table th, .data-table td { border: 1px solid #ddd; padding: 5px 7px; text-align: right; }
.data-table th:first-child, .data-table td:first-child, .data-table th:nth-child(2), .data-table td:nth-child(2), .data-table th:nth-child(3), .data-table td:nth-child(3) { text-align: left; }
code { background: #f3f4f6; padding: 1px 4px; border-radius: 3px; }
"

summary.text <- paste(
  sprintf("Lambda grid: {%s}.", paste(lambda.grid, collapse = ", ")),
  sprintf("Sync neighbor size: %d.", sync.neighbor.size),
  sprintf("Best-method counts: %s.",
          paste(names(best.count), as.integer(best.count), sep = "=", collapse = "; "))
)

report <- htmltools::tagList(
  htmltools::tags$html(
    htmltools::tags$head(
      htmltools::tags$title("PS-LPS First-Batch Experiment"),
      htmltools::tags$style(css),
      htmltools::tags$script(
        src = "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js",
        async = NA
      )
    ),
    htmltools::tags$body(
      htmltools::tags$h1("PS-LPS First-Batch Experiment"),
      htmltools::tags$p(
        class = "note",
        "This report compares ordinary LPS ",
        htmltools::tags$code("auto"),
        " and ",
        htmltools::tags$code("local.auto"),
        " against prediction-synchronized LPS (PS-LPS) variants that reuse the ",
        "same selected support, kernel, degree, and chart-dimension policy, ",
        "then tune only ",
        htmltools::HTML("\\(\\lambda_{\\mathrm{sync}}\\)"),
        " by CV."
      ),
      htmltools::tags$p(class = "note", summary.text),
      htmltools::tags$h2("Truth RMSE"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures", "truth_rmse_lps_vs_ps_lps.png")),
        htmltools::tags$p(
          class = "caption",
          "Lower Truth RMSE is better. Gray lines connect methods within a dataset."
        )
      ),
      htmltools::tags$h2("Total Local GCV and CV RMSE"),
      htmltools::tags$p(
        class = "note",
        "The plotted total local GCV is computed after synchronization, using ",
        "the synchronized chart coefficients. It is therefore not the same ",
        "quantity as total local GCV for independent LPS charts."
      ),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures", "ps_lps_total_gcv_vs_cv_rmse.png")),
        htmltools::tags$p(
          class = "caption",
          "Each point is one PS-LPS lambda candidate on one dataset and one chart-dimension variant."
        )
      ),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures", "ps_lps_selected_total_gcv_vs_truth_rmse.png")),
        htmltools::tags$p(
          class = "caption",
          "This synthetic-truth diagnostic asks whether the synchronized total ",
          "local GCV of the selected PS-LPS fit is aligned with the final Truth ",
          "RMSE. It should not be read as a deployable selection rule because ",
          "Truth RMSE is unavailable on real data."
        )
      ),
      htmltools::tags$h2("Synchronization Energy and Improvement"),
      htmltools::tags$p(
        class = "note",
        "As an additional diagnostic, the next figure compares synchronization ",
        "energy with the Truth-RMSE change relative to the corresponding ",
        "ordinary LPS source fit. This helps check whether the empirical gains ",
        "are plausibly connected to prediction synchronization."
      ),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures", "ps_lps_sync_energy_vs_truth_rmse_delta.png")),
        htmltools::tags$p(
          class = "caption",
          "Negative y-values mean PS-LPS improved over the ordinary LPS fit ",
          "from which it inherited support size, kernel, degree, and chart ",
          "dimension policy."
        )
      ),
      htmltools::tags$h2("Pointwise Components"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures", "ps_lps_pointwise_components.png")),
        htmltools::tags$p(
          class = "caption",
          "Positive c_i means the PS-LPS variant contributes more Truth-RMSE ",
          "than ordinary LPS auto at that point. Colors show local degrees-of-freedom ratio."
        )
      ),
      htmltools::tags$h2("PS-LPS Summary"),
      table.html(transform(
        ps.summary[, c("batch_id", "dataset_id", "method", "selected_lambda_sync",
                       "selected_support_size", "selected_kernel", "selected_chart_dim",
                       "selected_cv_rmse_observed", "truth_rmse",
                       "total_local_gcv_ps", "sync_energy", "elapsed_sec")],
        selected_cv_rmse_observed = fmt(selected_cv_rmse_observed),
        truth_rmse = fmt(truth_rmse),
        total_local_gcv_ps = fmt(total_local_gcv_ps),
        sync_energy = fmt(sync_energy),
        elapsed_sec = fmt(elapsed_sec, 4)
      )),
      htmltools::tags$h2("Tables"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_first_batch_method_comparison.csv"),
          "Method comparison table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_first_batch_summary.csv"),
          "PS-LPS summary table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_lambda_cv_gcv_table.csv"),
          "Lambda CV/GCV table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_pointwise_components.csv"),
          "Pointwise component table"
        ))
      )
    )
  )
)

htmltools::save_html(report, file.path(out.dir, "ps_lps_first_batch_experiment_report.html"))
message("Wrote ", file.path(out.dir, "ps_lps_first_batch_experiment_report.html"))
