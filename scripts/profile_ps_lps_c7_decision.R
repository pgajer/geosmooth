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
  "ps_lps_cache_backend_2026-06-05",
  "c7_solve_search_decision_2026-06-05"
)
table.dir <- file.path(out.dir, "tables")
fig.dir <- file.path(out.dir, "figures")
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
read.csv.safe <- function(path) {
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}
write.csv.safe <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
}
fmt <- function(x, digits = 5) {
  ifelse(is.finite(x), formatC(x, digits = digits, format = "fg"), "")
}
time.block <- function(expr) {
  gc()
  start <- proc.time()
  value <- force(expr)
  elapsed <- unname((proc.time() - start)[["elapsed"]])
  list(value = value, elapsed = elapsed)
}
summarize.repeats <- function(df, group.cols) {
  split.df <- split(df, df[group.cols], drop = TRUE)
  out <- lapply(split.df, function(dd) {
    data.frame(
      dd[1L, group.cols, drop = FALSE],
      n_reps = nrow(dd),
      elapsed_median_sec = stats::median(dd$elapsed_sec),
      elapsed_iqr_sec = stats::IQR(dd$elapsed_sec),
      elapsed_min_sec = min(dd$elapsed_sec),
      elapsed_max_sec = max(dd$elapsed_sec),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
}

asset.manifest <- read.csv.safe(file.path(freeze.dir, "asset_manifest.csv"))
load.source.lps <- function(batch.id, dataset.id, rule) {
  file.rule <- gsub("\\.", "_", rule)
  readRDS(file.path(
    run.dir,
    "results",
    sprintf("%s__%s__chart_%s.rds", batch.id, safe.id(dataset.id), file.rule)
  ))
}
prepare.case <- function(batch.id, rule) {
  asset.row <- asset.manifest[asset.manifest[["batch.id"]] == batch.id, ,
                              drop = FALSE]
  if (nrow(asset.row) != 1L) stop("Unknown or nonunique batch id: ", batch.id)
  asset <- readRDS(asset.row[["asset.path"]])
  lps.result <- load.source.lps(batch.id, asset.row[["dataset.id"]], rule)
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
  list(
    batch_id = batch.id,
    dataset_id = asset.row[["dataset.id"]],
    chart_dim_rule = rule,
    asset = asset,
    lps.result = lps.result,
    chart.dim.by.anchor = chart.dim.by.anchor
  )
}

profile.case <- prepare.case("FB14", "local.auto")
asset <- profile.case$asset
lps <- profile.case$lps.result
lambda.ridge <- 1e-8
sync.neighbor.size <- 3L
base.lambda <- c(0.01, 0.03, 0.1, 0.3, 1, 3, 10, 30, 100, 300, 1000)

message("Preparing shared frames and component cache.")
frames.t <- time.block(.ps.lps.prepare.frames(
  X = asset$X,
  y = asset$y,
  support.size = lps$selected$support.size[[1L]],
  degree = lps$selected$degree[[1L]],
  kernel = lps$selected$kernel[[1L]],
  chart.dim.by.anchor = profile.case$chart.dim.by.anchor
))
frames <- frames.t$value
sync.t <- time.block(.ps.lps.prepare.sync.rows(
  frames = frames,
  sync.neighbor.size = sync.neighbor.size,
  overlap.weight = "normalized.product"
))
sync.rows <- sync.t$value
system.cache <- .ps.lps.prepare.system.cache(frames, sync.rows)
full.component.t <- time.block(.ps.lps.prepare.component.cache(
  cache = system.cache,
  y = asset$y,
  response.weights = rep(1, length(asset$y))
))
full.component.cache <- full.component.t$value

foldid <- asset$foldid
folds <- sort(unique(foldid))
fold.component.t <- time.block({
  out <- vector("list", length(folds))
  names(out) <- as.character(folds)
  for (fold in folds) {
    out[[as.character(fold)]] <- .ps.lps.prepare.component.cache(
      cache = system.cache,
      y = asset$y,
      response.weights = as.numeric(foldid != fold)
    )
  }
  out
})
fold.component.caches <- fold.component.t$value

bench.solve.grid <- function(component.cache, lambda.grid,
                             coefficients.only = FALSE) {
  out <- vector("list", length(lambda.grid))
  for (ii in seq_along(lambda.grid)) {
    lambda <- lambda.grid[[ii]]
    combine.t <- time.block(.ps.lps.component.normal.cache(
      component.cache = component.cache,
      lambda.sync = lambda
    ))
    solve.t <- time.block(.ps.lps.solve.normal.cached(
      normal.cache = combine.t$value,
      lambda.ridge = lambda.ridge,
      coefficients.only = coefficients.only
    ))
    timings <- solve.t$value$solve.phase.timings
    out[[ii]] <- data.frame(
      lambda_sync = lambda,
      combine_elapsed_sec = combine.t$elapsed,
      solve_elapsed_sec = solve.t$elapsed,
      reported_component_combine_sec = timings$phase_component_combine_sec,
      reported_ridge_normal_sec = timings$phase_ridge_normal_sec,
      reported_solve_sec = timings$phase_solve_sec,
      reported_diagnostics_sec = timings$phase_diagnostics_sec,
      reported_fitted_sec = timings$phase_fitted_sec,
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, out)
}

micro.rows <- list()
rr <- 0L
micro.grid.sizes <- c(1L, 3L, 7L, 11L)
n.reps.micro <- 5L
for (grid.size in micro.grid.sizes) {
  lambda.grid <- head(base.lambda, grid.size)
  for (rep.id in seq_len(n.reps.micro)) {
    message(sprintf("Micro timing grid=%d rep=%d", grid.size, rep.id))
    grid.t <- time.block(bench.solve.grid(
      full.component.cache,
      lambda.grid,
      coefficients.only = TRUE
    ))
    rr <- rr + 1L
    micro.rows[[rr]] <- data.frame(
      grid_size = grid.size,
      rep_id = rep.id,
      elapsed_sec = grid.t$elapsed,
      per_lambda_sec = grid.t$elapsed / grid.size,
      stringsAsFactors = FALSE
    )
  }
}
micro.raw <- do.call(rbind, micro.rows)
micro.summary <- summarize.repeats(micro.raw, "grid_size")
micro.summary$per_lambda_median_sec <- micro.summary$elapsed_median_sec /
  micro.summary$grid_size

layer.rows <- list()
ll <- 0L
for (rep.id in seq_len(5L)) {
  message(sprintf("Layer timing rep=%d", rep.id))
  layer <- bench.solve.grid(
    full.component.cache,
    head(base.lambda, 7L),
    coefficients.only = TRUE
  )
  layer$rep_id <- rep.id
  ll <- ll + 1L
  layer.rows[[ll]] <- layer
}
layer.raw <- do.call(rbind, layer.rows)
layer.summary <- aggregate(
  cbind(combine_elapsed_sec, solve_elapsed_sec,
        reported_ridge_normal_sec, reported_solve_sec,
        reported_diagnostics_sec) ~ lambda_sync,
  data = layer.raw,
  FUN = stats::median
)

end.rows <- list()
ee <- 0L
end.grid.sizes <- c(1L, 3L, 7L)
n.reps.end <- 3L
for (grid.size in end.grid.sizes) {
  lambda.grid <- head(base.lambda, grid.size)
  for (rep.id in seq_len(n.reps.end)) {
    message(sprintf("End-to-end timing grid=%d rep=%d", grid.size, rep.id))
    fit.t <- time.block(fit.ps.lps(
      X = asset$X,
      y = asset$y,
      foldid = asset$foldid,
      support.size = lps$selected$support.size[[1L]],
      degree = lps$selected$degree[[1L]],
      kernel = lps$selected$kernel[[1L]],
      chart.dim = profile.case$chart.dim.by.anchor,
      lambda.sync.grid = lambda.grid,
      lambda.ridge = lambda.ridge,
      sync.neighbor.size = sync.neighbor.size
    ))
    ee <- ee + 1L
    end.rows[[ee]] <- data.frame(
      grid_size = grid.size,
      rep_id = rep.id,
      elapsed_sec = fit.t$elapsed,
      per_lambda_sec = fit.t$elapsed / grid.size,
      selected_lambda_sync = fit.t$value$selected$lambda.sync[[1L]],
      cache_backend = fit.t$value$cache.backend,
      stringsAsFactors = FALSE
    )
  }
}
end.raw <- do.call(rbind, end.rows)
end.summary <- summarize.repeats(end.raw, "grid_size")
end.summary$per_lambda_median_sec <- end.summary$elapsed_median_sec /
  end.summary$grid_size

setup.summary <- data.frame(
  phase = c("prepare_frames", "prepare_sync_rows",
            "prepare_full_component_cache", "prepare_fold_component_caches"),
  elapsed_sec = c(frames.t$elapsed, sync.t$elapsed,
                  full.component.t$elapsed, fold.component.t$elapsed),
  stringsAsFactors = FALSE
)

write.csv.safe(setup.summary, file.path(table.dir, "ps_lps_c7_setup_timing.csv"))
write.csv.safe(micro.raw, file.path(table.dir, "ps_lps_c7_micro_raw.csv"))
write.csv.safe(micro.summary, file.path(table.dir, "ps_lps_c7_micro_summary.csv"))
write.csv.safe(layer.raw, file.path(table.dir, "ps_lps_c7_layer_raw.csv"))
write.csv.safe(layer.summary, file.path(table.dir, "ps_lps_c7_layer_summary.csv"))
write.csv.safe(end.raw, file.path(table.dir, "ps_lps_c7_end_to_end_raw.csv"))
write.csv.safe(end.summary,
               file.path(table.dir, "ps_lps_c7_end_to_end_summary.csv"))

theme.report <- ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    legend.position = "bottom",
    plot.title.position = "plot"
  )

p.end <- ggplot2::ggplot(
  end.raw,
  ggplot2::aes(x = factor(grid_size), y = elapsed_sec)
) +
  ggplot2::geom_boxplot(fill = "#a6bddb", width = 0.55,
                        outlier.shape = NA) +
  ggplot2::geom_point(position = ggplot2::position_jitter(width = 0.08),
                      size = 2, alpha = 0.75) +
  ggplot2::labs(
    title = "C7 cache-aware end-to-end timing by lambda grid size",
    subtitle = "Three repeats per grid size on FB14 local.auto.",
    x = "Number of positive lambda.sync candidates",
    y = "Elapsed seconds"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_c7_end_to_end_grid_size.png"),
                p.end, width = 9, height = 6, dpi = 180)

p.micro <- ggplot2::ggplot(
  micro.raw,
  ggplot2::aes(x = factor(grid_size), y = per_lambda_sec)
) +
  ggplot2::geom_boxplot(fill = "#b2df8a", width = 0.55,
                        outlier.shape = NA) +
  ggplot2::geom_point(position = ggplot2::position_jitter(width = 0.08),
                      size = 2, alpha = 0.75) +
  ggplot2::labs(
    title = "C7 isolated cached solve marginal cost",
    subtitle = "Five repeats per grid size; full-data component cache reused.",
    x = "Number of positive lambda.sync candidates",
    y = "Elapsed seconds per lambda"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_c7_micro_per_lambda.png"),
                p.micro, width = 9, height = 6, dpi = 180)

layer.long <- reshape(
  layer.summary,
  varying = c("combine_elapsed_sec", "solve_elapsed_sec",
              "reported_ridge_normal_sec", "reported_solve_sec",
              "reported_diagnostics_sec"),
  v.names = "elapsed_sec",
  timevar = "phase",
  times = c("combine wall", "solve wall", "ridge normal",
            "Matrix solve", "diagnostics"),
  direction = "long"
)
row.names(layer.long) <- NULL
p.layer <- ggplot2::ggplot(
  layer.long,
  ggplot2::aes(x = factor(lambda_sync), y = elapsed_sec, fill = phase)
) +
  ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.75),
                    width = 0.65) +
  ggplot2::labs(
    title = "C7 median layer timings by lambda.sync",
    subtitle = "Medians over five isolated full-data cached solves.",
    x = "lambda.sync",
    y = "Elapsed seconds",
    fill = "Layer"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_c7_layer_timing.png"),
                p.layer, width = 10, height = 6, dpi = 180)

top.setup <- transform(setup.summary, elapsed_sec = fmt(elapsed_sec))
micro.display <- transform(micro.summary,
                           elapsed_median_sec = fmt(elapsed_median_sec),
                           elapsed_iqr_sec = fmt(elapsed_iqr_sec),
                           per_lambda_median_sec = fmt(per_lambda_median_sec))
end.display <- transform(end.summary,
                         elapsed_median_sec = fmt(elapsed_median_sec),
                         elapsed_iqr_sec = fmt(elapsed_iqr_sec),
                         per_lambda_median_sec = fmt(per_lambda_median_sec))
layer.display <- transform(layer.summary,
                           combine_elapsed_sec = fmt(combine_elapsed_sec),
                           solve_elapsed_sec = fmt(solve_elapsed_sec),
                           reported_ridge_normal_sec = fmt(reported_ridge_normal_sec),
                           reported_solve_sec = fmt(reported_solve_sec),
                           reported_diagnostics_sec = fmt(reported_diagnostics_sec))

median.end.slope <- coef(stats::lm(elapsed_median_sec ~ grid_size,
                                   data = end.summary))[["grid_size"]]
median.micro.slope <- coef(stats::lm(elapsed_median_sec ~ grid_size,
                                     data = micro.summary))[["grid_size"]]
decision <- if (median.end.slope > 1.0) {
  "candidate search can save seconds per skipped lambda on this stress case"
} else {
  "candidate search still saves time, but solver-path work may be comparably important"
}

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
.data-table { border-collapse: collapse; font-size: 0.86rem; margin: 12px 0 24px; }
.data-table th, .data-table td { border: 1px solid #ddd; padding: 5px 7px; text-align: right; }
.data-table th:first-child, .data-table td:first-child { text-align: left; }
code { background: #f3f4f6; padding: 1px 4px; border-radius: 3px; }
"

report <- htmltools::tagList(
  htmltools::tags$html(
    htmltools::tags$head(
      htmltools::tags$title("PS-LPS C7 Solve/Search Decision Profile"),
      htmltools::tags$style(css)
    ),
    htmltools::tags$body(
      htmltools::tags$h1("PS-LPS C7 Solve/Search Decision Profile"),
      htmltools::tags$p(
        class = "note",
        "C7 uses repeated timings on the FB14 local.auto stress case to ",
        "separate end-to-end lambda-grid cost from isolated cached solve cost. ",
        "The goal is to decide whether the next phase should prioritize ",
        "low-level sparse-solve optimization or smarter lambda-search policy."
      ),
      htmltools::tags$h2("Setup Timings"),
      table.html(top.setup),
      htmltools::tags$h2("End-to-End Lambda Grid Cost"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures",
                                            "ps_lps_c7_end_to_end_grid_size.png")),
        htmltools::tags$p(
          class = "caption",
          "Full cache-aware fit.ps.lps() timing.  Each point is one complete ",
          "CV/diagnostic/final-fit run."
        )
      ),
      table.html(end.display),
      htmltools::tags$h2("Isolated Cached Solve Cost"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures",
                                            "ps_lps_c7_micro_per_lambda.png")),
        htmltools::tags$p(
          class = "caption",
          "Full-data component cache reused across lambda values.  This isolates ",
          "normal-matrix combination plus ridge solve/diagnostics."
        )
      ),
      table.html(micro.display),
      htmltools::tags$h2("Solve Layer Timing"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures",
                                            "ps_lps_c7_layer_timing.png")),
        htmltools::tags$p(
          class = "caption",
          "Median timings over five isolated cached solves.  The split helps ",
          "separate normal-matrix combination, ridge-normal formation, Matrix ",
          "solve, and diagnostics."
        )
      ),
      table.html(layer.display),
      htmltools::tags$h2("Decision"),
      htmltools::tags$p(
        class = "note",
        sprintf(
          paste0(
            "A simple linear fit to median end-to-end timings estimates about ",
            "%.3f seconds per additional lambda.sync candidate.  The isolated ",
            "full-data cached solve estimate is about %.3f seconds per lambda. ",
            "This means %s.  The recommended next engineering phase is to ",
            "prototype a practical lambda-search policy before attempting ",
            "invasive sparse-solver changes."
          ),
          median.end.slope, median.micro.slope, decision
        )
      ),
      htmltools::tags$h2("Output Tables"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_c7_setup_timing.csv"),
          "Setup timing"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_c7_micro_summary.csv"),
          "Isolated cached solve summary"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_c7_layer_summary.csv"),
          "Layer timing summary"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_c7_end_to_end_summary.csv"),
          "End-to-end summary"
        ))
      )
    )
  )
)

report.path <- file.path(out.dir, "ps_lps_c7_solve_search_decision_report.html")
htmltools::save_html(report, report.path)
message("Wrote ", report.path)
