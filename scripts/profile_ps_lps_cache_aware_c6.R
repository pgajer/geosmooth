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
  "c6_cache_aware_profile_2026-06-05"
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

direct.tuning.loop <- function(prepared, lambda.grid, lambda.ridge = 1e-8,
                               sync.neighbor.size = 3L) {
  asset <- prepared$asset
  lps <- prepared$lps.result
  frames <- .ps.lps.prepare.frames(
    X = asset$X,
    y = asset$y,
    support.size = lps$selected$support.size[[1L]],
    degree = lps$selected$degree[[1L]],
    kernel = lps$selected$kernel[[1L]],
    chart.dim.by.anchor = prepared$chart.dim.by.anchor
  )
  sync.rows <- .ps.lps.prepare.sync.rows(
    frames = frames,
    sync.neighbor.size = sync.neighbor.size,
    overlap.weight = "normalized.product"
  )
  cv.table <- data.frame(
    lambda.sync = lambda.grid,
    cv.rmse.observed = NA_real_,
    total.local.gcv.ps = NA_real_,
    sync.energy = NA_real_,
    stringsAsFactors = FALSE
  )
  folds <- sort(unique(asset$foldid))
  for (ll in seq_along(lambda.grid)) {
    lambda <- lambda.grid[[ll]]
    pred <- rep(NA_real_, length(asset$y))
    for (fold in folds) {
      fit.fold <- .ps.lps.solve(
        frames = frames,
        y = asset$y,
        response.weights = as.numeric(asset$foldid != fold),
        lambda.sync = lambda,
        lambda.ridge = lambda.ridge,
        sync.rows = sync.rows
      )
      pred[asset$foldid == fold] <- fit.fold$fitted.values[asset$foldid == fold]
    }
    cv.table$cv.rmse.observed[[ll]] <- .klp.rmse(pred, asset$y)
    fit.diag <- .ps.lps.solve(
      frames = frames,
      y = asset$y,
      response.weights = rep(1, length(asset$y)),
      lambda.sync = lambda,
      lambda.ridge = lambda.ridge,
      sync.rows = sync.rows,
      coefficients.only = TRUE
    )
    cv.table$total.local.gcv.ps[[ll]] <- fit.diag$total.local.gcv.ps
    cv.table$sync.energy[[ll]] <- fit.diag$sync.energy
  }
  best <- order(cv.table$cv.rmse.observed, cv.table$lambda.sync)[[1L]]
  final <- .ps.lps.solve(
    frames = frames,
    y = asset$y,
    response.weights = rep(1, length(asset$y)),
    lambda.sync = cv.table$lambda.sync[[best]],
    lambda.ridge = lambda.ridge,
    sync.rows = sync.rows
  )
  list(
    cv.table = cv.table,
    selected.lambda.sync = cv.table$lambda.sync[[best]],
    fitted.values = final$fitted.values,
    solve.timings = final$solve.phase.timings
  )
}

cache.aware.fit <- function(prepared, lambda.grid, lambda.ridge = 1e-8,
                            sync.neighbor.size = 3L) {
  asset <- prepared$asset
  lps <- prepared$lps.result
  fit.ps.lps(
    X = asset$X,
    y = asset$y,
    foldid = asset$foldid,
    support.size = lps$selected$support.size[[1L]],
    degree = lps$selected$degree[[1L]],
    kernel = lps$selected$kernel[[1L]],
    chart.dim = prepared$chart.dim.by.anchor,
    lambda.sync.grid = lambda.grid,
    lambda.ridge = lambda.ridge,
    sync.neighbor.size = sync.neighbor.size
  )
}

lambda.grids <- list(
  mixed_4 = c(0, 0.1, 1, 10),
  positive_7 = c(0.01, 0.03, 0.1, 0.3, 1, 3, 10)
)
cases <- data.frame(
  batch_id = c("FB01", "FB09", "FB14"),
  chart_dim_rule = c("auto", "auto", "local.auto"),
  stringsAsFactors = FALSE
)

rows <- list()
cv.rows <- list()
timing.rows <- list()
rr <- 0L
cc <- 0L
tt <- 0L
for (ii in seq_len(nrow(cases))) {
  prepared <- prepare.case(cases$batch_id[[ii]], cases$chart_dim_rule[[ii]])
  for (grid.name in names(lambda.grids)) {
    lambda.grid <- lambda.grids[[grid.name]]
    message(sprintf(
      "Profiling %s %s %s",
      prepared$batch_id, prepared$chart_dim_rule, grid.name
    ))
    direct.t <- time.block(direct.tuning.loop(prepared, lambda.grid))
    cached.t <- time.block(cache.aware.fit(prepared, lambda.grid))
    direct <- direct.t$value
    cached <- cached.t$value
    max.cv.delta <- max(abs(
      direct$cv.table$cv.rmse.observed - cached$cv.table$cv.rmse.observed
    ))
    max.fitted.delta <- max(abs(direct$fitted.values - cached$fitted.values))
    rr <- rr + 1L
    rows[[rr]] <- data.frame(
      batch_id = prepared$batch_id,
      dataset_id = prepared$dataset_id,
      chart_dim_rule = prepared$chart_dim_rule,
      grid_name = grid.name,
      n_lambda = length(lambda.grid),
      lambda_grid = paste(lambda.grid, collapse = ", "),
      n = nrow(prepared$asset$X),
      p = ncol(prepared$asset$X),
      support_size = prepared$lps.result$selected$support.size[[1L]],
      degree = prepared$lps.result$selected$degree[[1L]],
      kernel = prepared$lps.result$selected$kernel[[1L]],
      chart_dim_median = stats::median(prepared$chart.dim.by.anchor),
      chart_dim_max = max(prepared$chart.dim.by.anchor),
      direct_elapsed_sec = direct.t$elapsed,
      cache_elapsed_sec = cached.t$elapsed,
      speedup = direct.t$elapsed / cached.t$elapsed,
      selected_lambda_direct = direct$selected.lambda.sync,
      selected_lambda_cache = cached$selected$lambda.sync[[1L]],
      max_cv_rmse_delta = max.cv.delta,
      max_fitted_delta = max.fitted.delta,
      cache_backend = cached$cache.backend,
      stringsAsFactors = FALSE
    )
    cv.direct <- direct$cv.table
    cv.cache <- cached$cv.table
    for (ll in seq_along(lambda.grid)) {
      cc <- cc + 1L
      cv.rows[[cc]] <- data.frame(
        batch_id = prepared$batch_id,
        dataset_id = prepared$dataset_id,
        chart_dim_rule = prepared$chart_dim_rule,
        grid_name = grid.name,
        lambda_sync = lambda.grid[[ll]],
        direct_cv_rmse = cv.direct$cv.rmse.observed[[ll]],
        cache_cv_rmse = cv.cache$cv.rmse.observed[[ll]],
        cv_rmse_delta = cv.cache$cv.rmse.observed[[ll]] -
          cv.direct$cv.rmse.observed[[ll]],
        direct_total_gcv = cv.direct$total.local.gcv.ps[[ll]],
        cache_total_gcv = cv.cache$total.local.gcv.ps[[ll]],
        stringsAsFactors = FALSE
      )
    }
    timing <- cached$solve.phase.timings
    for (phase in names(timing)) {
      tt <- tt + 1L
      timing.rows[[tt]] <- data.frame(
        batch_id = prepared$batch_id,
        dataset_id = prepared$dataset_id,
        chart_dim_rule = prepared$chart_dim_rule,
        grid_name = grid.name,
        phase = phase,
        elapsed_sec = as.numeric(timing[[phase]]),
        stringsAsFactors = FALSE
      )
    }
  }
}

summary.table <- do.call(rbind, rows)
cv.table <- do.call(rbind, cv.rows)
solve.timing.table <- do.call(rbind, timing.rows)
write.csv.safe(summary.table, file.path(table.dir, "ps_lps_c6_timing_summary.csv"))
write.csv.safe(cv.table, file.path(table.dir, "ps_lps_c6_cv_parity.csv"))
write.csv.safe(solve.timing.table,
               file.path(table.dir, "ps_lps_c6_cache_final_solve_timings.csv"))

profile.target <- prepare.case("FB14", "local.auto")
profile.file <- file.path(out.dir, "ps_lps_c6_fit_ps_lps_Rprof.out")
message("Running Rprof target FB14 local.auto positive_7.")
Rprof(profile.file, interval = 0.01)
invisible(cache.aware.fit(profile.target, lambda.grids$positive_7))
Rprof(NULL)
prof <- utils::summaryRprof(profile.file)
by.total <- as.data.frame(prof$by.total)
by.total$function_name <- row.names(by.total)
by.total <- by.total[, c("function_name", setdiff(names(by.total),
                                                  "function_name"))]
write.csv.safe(head(by.total, 100),
               file.path(table.dir, "ps_lps_c6_Rprof_by_total_top100.csv"))

theme.report <- ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    legend.position = "bottom",
    plot.title.position = "plot"
  )

summary.table$case <- paste(summary.table$batch_id,
                            summary.table$chart_dim_rule,
                            summary.table$grid_name)
summary.long <- rbind(
  data.frame(summary.table[, c("case", "batch_id", "chart_dim_rule",
                               "grid_name")],
             path = "direct loop",
             elapsed_sec = summary.table$direct_elapsed_sec),
  data.frame(summary.table[, c("case", "batch_id", "chart_dim_rule",
                               "grid_name")],
             path = "cache-aware fit.ps.lps",
             elapsed_sec = summary.table$cache_elapsed_sec)
)

p.elapsed <- ggplot2::ggplot(
  summary.long,
  ggplot2::aes(x = case, y = elapsed_sec, fill = path)
) +
  ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.75),
                    width = 0.68) +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = "PS-LPS C6 end-to-end timing comparison",
    subtitle = "Direct loop reconstructs the pre-cache CV/diagnostic/final path; cache-aware path is exported fit.ps.lps().",
    x = NULL,
    y = "Elapsed seconds",
    fill = "Path"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_c6_elapsed_comparison.png"),
                p.elapsed, width = 11, height = 7, dpi = 180)

p.speedup <- ggplot2::ggplot(
  summary.table,
  ggplot2::aes(x = case, y = speedup)
) +
  ggplot2::geom_hline(yintercept = 1, color = "gray60",
                      linetype = "dashed") +
  ggplot2::geom_point(size = 3.2, color = "#2b8cbe") +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = "Cache-aware speedup over direct loop",
    subtitle = "Values above 1 mean cache-aware fit.ps.lps() was faster.",
    x = NULL,
    y = "Speedup = direct elapsed / cache-aware elapsed"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_c6_speedup.png"),
                p.speedup, width = 10, height = 6, dpi = 180)

top.profile <- head(by.total, 20)
top.profile$function_name <- factor(top.profile$function_name,
                                    levels = rev(top.profile$function_name))
p.rprof <- ggplot2::ggplot(
  top.profile,
  ggplot2::aes(x = function_name, y = total.time)
) +
  ggplot2::geom_col(fill = "#5254a3") +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = "C6 cache-aware fit.ps.lps() Rprof hot spots",
    subtitle = "Target: FB14 local.auto with seven positive lambda.sync values.",
    x = NULL,
    y = "Total sampled time"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_c6_rprof_top_total.png"),
                p.rprof, width = 10, height = 7, dpi = 180)

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

summary.display <- transform(
  summary.table,
  direct_elapsed_sec = fmt(direct_elapsed_sec),
  cache_elapsed_sec = fmt(cache_elapsed_sec),
  speedup = fmt(speedup),
  max_cv_rmse_delta = fmt(max_cv_rmse_delta),
  max_fitted_delta = fmt(max_fitted_delta)
)
summary.display <- summary.display[, c(
  "batch_id", "dataset_id", "chart_dim_rule", "grid_name",
  "n_lambda", "n", "p", "support_size", "chart_dim_median",
  "chart_dim_max", "direct_elapsed_sec", "cache_elapsed_sec",
  "speedup", "selected_lambda_direct", "selected_lambda_cache",
  "max_cv_rmse_delta", "max_fitted_delta", "cache_backend"
)]

report <- htmltools::tagList(
  htmltools::tags$html(
    htmltools::tags$head(
      htmltools::tags$title("PS-LPS C6 Cache-Aware Profile"),
      htmltools::tags$style(css)
    ),
    htmltools::tags$body(
      htmltools::tags$h1("PS-LPS C6 Cache-Aware Profile"),
      htmltools::tags$p(
        class = "note",
        "C6 validates the cache-aware exported fitter path after C5. ",
        "The direct loop reconstructs the pre-cache tuning pattern using ",
        "`.ps.lps.solve()` for each fold, diagnostic solve, and final fit. ",
        "The cache-aware path calls `fit.ps.lps()`, which now reuses component ",
        "caches across positive synchronization candidates."
      ),
      htmltools::tags$h2("End-to-End Timing"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures",
                                            "ps_lps_c6_elapsed_comparison.png")),
        htmltools::tags$p(
          class = "caption",
          "Elapsed timing for direct and cache-aware paths.  These timings ",
          "include chart/frame preparation, synchronization-row construction, ",
          "CV folds, full-data diagnostics, and final fitting."
        )
      ),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures",
                                            "ps_lps_c6_speedup.png")),
        htmltools::tags$p(
          class = "caption",
          "Speedup above 1 indicates a faster cache-aware exported fitter. ",
          "The expected benefit is larger for larger positive lambda grids."
        )
      ),
      table.html(summary.display),
      htmltools::tags$h2("Parity Checks"),
      htmltools::tags$p(
        class = "note",
        "The cache-aware and direct paths should agree up to numerical error. ",
        "The summary table reports maximum CV RMSE and final fitted-value ",
        "differences for each profiled case."
      ),
      htmltools::tags$h2("Rprof Hot Spots"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures",
                                            "ps_lps_c6_rprof_top_total.png")),
        htmltools::tags$p(
          class = "caption",
          "Sampled total time for cache-aware fit.ps.lps() on the heaviest ",
          "profile target."
        )
      ),
      table.html(transform(
        head(by.total, 20),
        total.time = fmt(total.time),
        total.pct = fmt(total.pct),
        self.time = fmt(self.time),
        self.pct = fmt(self.pct)
      )),
      htmltools::tags$h2("Output Tables"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_c6_timing_summary.csv"),
          "Timing summary"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_c6_cv_parity.csv"),
          "CV parity table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_c6_cache_final_solve_timings.csv"),
          "Cache final solve timing table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_c6_Rprof_by_total_top100.csv"),
          "Rprof by-total top 100"
        ))
      )
    )
  )
)

report.path <- file.path(out.dir, "ps_lps_c6_cache_aware_profile_report.html")
htmltools::save_html(report, report.path)
message("Wrote ", report.path)
