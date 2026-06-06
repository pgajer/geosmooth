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
  "ps_lps_profile_2026-06-05"
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
solve.timing.rows <- function(timings, batch.id, dataset.id, rule, scope) {
  data.frame(
    batch_id = batch.id,
    dataset_id = dataset.id,
    chart_dim_rule = rule,
    scope = scope,
    phase = names(timings),
    elapsed_sec = as.numeric(unlist(timings, use.names = FALSE)),
    stringsAsFactors = FALSE
  )
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

prepare.profile.case <- function(batch.id, rule) {
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
    rule = rule,
    asset = asset,
    lps.result = lps.result,
    chart.dim.by.anchor = chart.dim.by.anchor
  )
}

profile.case <- function(batch.id, rule, lambda.sync = 10,
                         lambda.ridge = 1e-8, sync.neighbor.size = 3) {
  prepared <- prepare.profile.case(batch.id, rule)
  asset <- prepared$asset
  lps.result <- prepared$lps.result
  frames.t <- time.block(.ps.lps.prepare.frames(
    X = asset$X,
    y = asset$y,
    support.size = lps.result$selected$support.size[[1L]],
    degree = lps.result$selected$degree[[1L]],
    kernel = lps.result$selected$kernel[[1L]],
    chart.dim.by.anchor = prepared$chart.dim.by.anchor
  ))
  frames <- frames.t$value
  sync.t <- time.block(.ps.lps.prepare.sync.rows(
    frames = frames,
    sync.neighbor.size = sync.neighbor.size,
    overlap.weight = "normalized.product"
  ))
  sync.rows <- sync.t$value
  first.fold <- sort(unique(asset$foldid))[[1L]]
  one.fold.weights <- as.numeric(asset$foldid != first.fold)
  one.fold.t <- time.block(.ps.lps.solve(
    frames = frames,
    y = asset$y,
    response.weights = one.fold.weights,
    lambda.sync = lambda.sync,
    lambda.ridge = lambda.ridge,
    sync.rows = sync.rows
  ))
  cv.t <- time.block({
    pred <- rep(NA_real_, length(asset$y))
    fold.detail <- list()
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
      pred[asset$foldid == fold] <- fit.fold$fitted.values[asset$foldid == fold]
      fold.detail[[as.character(fold)]] <- solve.timing.rows(
        timings = fit.fold$solve.phase.timings,
        batch.id = prepared$batch_id,
        dataset.id = prepared$dataset_id,
        rule = rule,
        scope = paste0("cv_fold_", fold)
      )
    }
    list(pred = pred, fold.detail = do.call(rbind, fold.detail))
  })
  full.t <- time.block(.ps.lps.solve(
    frames = frames,
    y = asset$y,
    response.weights = rep(1, length(asset$y)),
    lambda.sync = lambda.sync,
    lambda.ridge = lambda.ridge,
    sync.rows = sync.rows
  ))
  full.fit <- full.t$value
  n.sync.rows <- sum(vapply(sync.rows, function(sr) length(sr$omega), integer(1L)))
  one.fold.detail <- solve.timing.rows(
    timings = one.fold.t$value$solve.phase.timings,
    batch.id = prepared$batch_id,
    dataset.id = prepared$dataset_id,
    rule = rule,
    scope = "one_fold"
  )
  cv.fold.detail <- cv.t$value$fold.detail
  cv.aggregate <- aggregate(elapsed_sec ~ phase, cv.fold.detail, sum)
  cv.aggregate$batch_id <- prepared$batch_id
  cv.aggregate$dataset_id <- prepared$dataset_id
  cv.aggregate$chart_dim_rule <- rule
  cv.aggregate$scope <- "cv_all_folds"
  cv.aggregate <- cv.aggregate[, names(one.fold.detail)]
  full.detail <- solve.timing.rows(
    timings = full.fit$solve.phase.timings,
    batch.id = prepared$batch_id,
    dataset.id = prepared$dataset_id,
    rule = rule,
    scope = "full"
  )
  detail <- rbind(one.fold.detail, cv.fold.detail, cv.aggregate, full.detail)
  summary <- data.frame(
    batch_id = prepared$batch_id,
    dataset_id = prepared$dataset_id,
    chart_dim_rule = rule,
    n = nrow(asset$X),
    p = ncol(asset$X),
    support_size = lps.result$selected$support.size[[1L]],
    degree = lps.result$selected$degree[[1L]],
    kernel = lps.result$selected$kernel[[1L]],
    chart_dim_median = stats::median(prepared$chart.dim.by.anchor),
    chart_dim_max = max(prepared$chart.dim.by.anchor),
    lambda_sync = lambda.sync,
    lambda_ridge = lambda.ridge,
    phase_prepare_frames_sec = frames.t$elapsed,
    phase_prepare_sync_rows_sec = sync.t$elapsed,
    phase_one_fold_solve_sec = one.fold.t$elapsed,
    phase_cv_all_folds_sec = cv.t$elapsed,
    phase_full_solve_sec = full.t$elapsed,
    phase_total_candidate_sec = frames.t$elapsed + sync.t$elapsed +
      cv.t$elapsed + full.t$elapsed,
    n_system_rows = full.fit$n.system.rows,
    n_coefficients = attr(frames, "ncoef"),
    n_sync_pairs = length(sync.rows),
    n_sync_rows = n.sync.rows,
    ridge_max = full.fit$ridge.max,
    stringsAsFactors = FALSE
  )
  list(summary = summary, solve.detail = detail)
}

cases <- data.frame(
  batch_id = c("FB01", "FB09", "FB14", "FB14"),
  chart_dim_rule = c("auto", "auto", "auto", "local.auto"),
  lambda_sync = c(10, 10, 10, 10),
  lambda_ridge = c(1e-8, 1e-8, 1e-8, 1e-8),
  stringsAsFactors = FALSE
)

profile.results <- lapply(seq_len(nrow(cases)), function(ii) {
  message(sprintf(
    "Profiling timing case %s %s",
    cases$batch_id[[ii]], cases$chart_dim_rule[[ii]]
  ))
  profile.case(
    batch.id = cases$batch_id[[ii]],
    rule = cases$chart_dim_rule[[ii]],
    lambda.sync = cases$lambda_sync[[ii]],
    lambda.ridge = cases$lambda_ridge[[ii]]
  )
})
timings <- do.call(rbind, lapply(profile.results, `[[`, "summary"))
solve.detail <- do.call(rbind, lapply(profile.results, `[[`, "solve.detail"))
write.csv.safe(timings, file.path(table.dir, "ps_lps_profile_phase_timings.csv"))
write.csv.safe(solve.detail,
               file.path(table.dir, "ps_lps_profile_solve_phase_timings.csv"))

profile.target <- list(batch_id = "FB14", chart_dim_rule = "local.auto",
                       lambda_sync = 10, lambda_ridge = 1e-8)
profile.file <- file.path(out.dir, "ps_lps_fb14_local_auto_Rprof.out")
message("Running Rprof target FB14 local.auto.")
Rprof(profile.file, interval = 0.01)
invisible(profile.case(
  batch.id = profile.target$batch_id,
  rule = profile.target$chart_dim_rule,
  lambda.sync = profile.target$lambda_sync,
  lambda.ridge = profile.target$lambda_ridge
))
Rprof(NULL)
prof <- utils::summaryRprof(profile.file)
by.total <- as.data.frame(prof$by.total)
by.total$function_name <- row.names(by.total)
by.total <- by.total[, c("function_name", setdiff(names(by.total), "function_name"))]
write.csv.safe(head(by.total, 80),
               file.path(table.dir, "ps_lps_profile_Rprof_by_total_top80.csv"))

phase.long <- data.frame(
  batch_id = rep(timings$batch_id, each = 5L),
  chart_dim_rule = rep(timings$chart_dim_rule, each = 5L),
  phase = rep(c("prepare frames", "prepare sync rows", "one fold solve",
                "CV all folds", "full solve"), times = nrow(timings)),
  elapsed_sec = c(rbind(
    timings$phase_prepare_frames_sec,
    timings$phase_prepare_sync_rows_sec,
    timings$phase_one_fold_solve_sec,
    timings$phase_cv_all_folds_sec,
    timings$phase_full_solve_sec
  )),
  stringsAsFactors = FALSE
)
phase.long$case <- paste(phase.long$batch_id, phase.long$chart_dim_rule)
solve.detail$case <- paste(solve.detail$batch_id, solve.detail$chart_dim_rule)
solve.detail.plot <- solve.detail[
  solve.detail$scope %in% c("one_fold", "cv_all_folds", "full") &
    is.finite(solve.detail$elapsed_sec) &
    !is.na(solve.detail$elapsed_sec),
  ,
  drop = FALSE
]
solve.detail.plot$phase <- factor(
  solve.detail.plot$phase,
  levels = c(
    "phase_count_sec",
    "phase_fill_triplets_sec",
    "phase_sparse_matrix_sec",
    "phase_assembly_sec",
    "phase_crossprod_sec",
    "phase_rhs_crossprod_sec",
    "phase_ridge_normal_sec",
    "phase_solve_sec",
    "phase_fallback_solve_sec",
    "phase_diagnostics_sec",
    "phase_fitted_sec"
  )
)

theme.report <- ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    legend.position = "bottom",
    plot.title.position = "plot"
  )

p.phase <- ggplot2::ggplot(
  phase.long,
  ggplot2::aes(x = phase, y = elapsed_sec, fill = phase)
) +
  ggplot2::geom_col(show.legend = FALSE) +
  ggplot2::coord_flip() +
  ggplot2::facet_wrap(~ case, scales = "free_x") +
  ggplot2::labs(
    title = "PS-LPS representative phase timings",
    subtitle = "All cases use lambda.sync = 10 and lambda.ridge = 1e-8.",
    x = NULL,
    y = "Elapsed seconds"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_profile_phase_timings.png"),
                p.phase, width = 12, height = 7, dpi = 180)

p.solve.detail <- ggplot2::ggplot(
  solve.detail.plot,
  ggplot2::aes(x = phase, y = elapsed_sec, fill = scope)
) +
  ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.75),
                    width = 0.65) +
  ggplot2::coord_flip() +
  ggplot2::facet_wrap(~ case, scales = "free_x") +
  ggplot2::labs(
    title = "PS-LPS internal solve phase timings",
    subtitle = "Exact timings reported from .ps.lps.solve(); CV all folds is the sum across folds.",
    x = NULL,
    y = "Elapsed seconds",
    fill = "Solve scope"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_profile_solve_phase_timings.png"),
                p.solve.detail, width = 13, height = 8, dpi = 180)

top.profile <- head(by.total, 20)
top.profile$function_name <- factor(top.profile$function_name,
                                    levels = rev(top.profile$function_name))
p.rprof <- ggplot2::ggplot(
  top.profile,
  ggplot2::aes(x = function_name, y = total.time)
) +
  ggplot2::geom_col(fill = "#2b8cbe") +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = "Rprof top functions by total time",
    subtitle = "Target: FB14 local.auto, lambda.sync = 10, lambda.ridge = 1e-8.",
    x = NULL,
    y = "Total sampled time"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_profile_rprof_top_total.png"),
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
.data-table { border-collapse: collapse; font-size: 0.88rem; margin: 12px 0 24px; }
.data-table th, .data-table td { border: 1px solid #ddd; padding: 5px 7px; text-align: right; }
.data-table th:first-child, .data-table td:first-child { text-align: left; }
code { background: #f3f4f6; padding: 1px 4px; border-radius: 3px; }
"

report <- htmltools::tagList(
  htmltools::tags$html(
    htmltools::tags$head(
      htmltools::tags$title("PS-LPS Representative Profile"),
      htmltools::tags$style(css)
    ),
    htmltools::tags$body(
      htmltools::tags$h1("PS-LPS Representative Profile"),
      htmltools::tags$p(
        class = "note",
        "This profile uses a small set of frozen first-batch PS-LPS cases to ",
        "separate setup time, synchronization-row construction, CV fold solves, ",
        "and full-data solves. It is intended to guide optimization before an ",
        "extended S2 synchronization search."
      ),
      htmltools::tags$h2("Phase Timings"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures",
                                            "ps_lps_profile_phase_timings.png")),
        htmltools::tags$p(
          class = "caption",
          "Representative elapsed times by phase. CV all folds is the cost ",
          "paid for each candidate during tuning."
        )
      ),
      table.html(transform(
        timings,
        phase_prepare_frames_sec = fmt(phase_prepare_frames_sec),
        phase_prepare_sync_rows_sec = fmt(phase_prepare_sync_rows_sec),
        phase_one_fold_solve_sec = fmt(phase_one_fold_solve_sec),
        phase_cv_all_folds_sec = fmt(phase_cv_all_folds_sec),
        phase_full_solve_sec = fmt(phase_full_solve_sec),
        phase_total_candidate_sec = fmt(phase_total_candidate_sec)
      )),
      htmltools::tags$h2("Internal Solve Phase Timings"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures",
                                            "ps_lps_profile_solve_phase_timings.png")),
        htmltools::tags$p(
          class = "caption",
          "Breakdown from inside .ps.lps.solve(): row counting, triplet fill, ",
          "sparse matrix construction, A'A crossproduct, A'y crossproduct, ",
          "ridge-normal formation, sparse solve, fallback solve, diagnostics, ",
          "and fitted-value extraction."
        )
      ),
      table.html(transform(
        solve.detail.plot,
        elapsed_sec = fmt(elapsed_sec)
      )),
      htmltools::tags$h2("Rprof Hot Spots"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures",
                                            "ps_lps_profile_rprof_top_total.png")),
        htmltools::tags$p(
          class = "caption",
          "Top sampled functions by total time for the heaviest representative ",
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
          href = file.path("tables", "ps_lps_profile_phase_timings.csv"),
          "Phase timing table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_profile_solve_phase_timings.csv"),
          "Internal solve phase timing table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_profile_Rprof_by_total_top80.csv"),
          "Rprof by-total top 80 table"
        ))
      )
    )
  )
)

report.path <- file.path(out.dir, "ps_lps_representative_profile_report.html")
htmltools::save_html(report, report.path)
message("Wrote ", report.path)
