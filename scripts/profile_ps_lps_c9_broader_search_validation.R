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
  "c9_broader_search_validation_2026-06-05"
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

make.evaluator <- function(prepared, lambda.ridge = 1e-8,
                           sync.neighbor.size = 3L) {
  asset <- prepared$asset
  lps <- prepared$lps.result
  setup.t <- time.block({
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
    system.cache <- .ps.lps.prepare.system.cache(frames, sync.rows)
    foldid <- asset$foldid
    folds <- sort(unique(foldid))
    fold.caches <- vector("list", length(folds))
    names(fold.caches) <- as.character(folds)
    for (fold in folds) {
      fold.caches[[as.character(fold)]] <- .ps.lps.prepare.component.cache(
        cache = system.cache,
        y = asset$y,
        response.weights = as.numeric(foldid != fold)
      )
    }
    full.cache <- .ps.lps.prepare.component.cache(
      cache = system.cache,
      y = asset$y,
      response.weights = rep(1, length(asset$y))
    )
    list(
      frames = frames,
      sync.rows = sync.rows,
      fold.caches = fold.caches,
      full.cache = full.cache,
      folds = folds
    )
  })
  state <- setup.t$value
  eval.env <- new.env(parent = emptyenv())
  eval.env$rows <- list()

  eval.one <- function(lambda.sync) {
    key <- sprintf("%.17g", lambda.sync)
    if (!is.null(eval.env$rows[[key]])) return(eval.env$rows[[key]])
    row.t <- time.block({
      pred <- rep(NA_real_, length(asset$y))
      for (fold in state$folds) {
        idx <- asset$foldid == fold
        fit.fold <- if (lambda.sync > 0) {
          .ps.lps.solve.component.cached(
            component.cache = state$fold.caches[[as.character(fold)]],
            lambda.sync = lambda.sync,
            lambda.ridge = lambda.ridge
          )
        } else {
          .ps.lps.solve(
            frames = state$frames,
            y = asset$y,
            response.weights = as.numeric(asset$foldid != fold),
            lambda.sync = lambda.sync,
            lambda.ridge = lambda.ridge,
            sync.rows = state$sync.rows
          )
        }
        pred[idx] <- fit.fold$fitted.values[idx]
      }
      fit.diag <- if (lambda.sync > 0) {
        .ps.lps.solve.component.cached(
          component.cache = state$full.cache,
          lambda.sync = lambda.sync,
          lambda.ridge = lambda.ridge,
          coefficients.only = TRUE
        )
      } else {
        .ps.lps.solve(
          frames = state$frames,
          y = asset$y,
          response.weights = rep(1, length(asset$y)),
          lambda.sync = lambda.sync,
          lambda.ridge = lambda.ridge,
          sync.rows = state$sync.rows,
          coefficients.only = TRUE
        )
      }
      list(
        cv.rmse.observed = .klp.rmse(pred, asset$y),
        total.local.gcv.ps = fit.diag$total.local.gcv.ps,
        sync.energy = fit.diag$sync.energy,
        mean.sync.squared.disagreement =
          fit.diag$mean.sync.squared.disagreement
      )
    })
    row <- data.frame(
      lambda.sync = lambda.sync,
      cv.rmse.observed = row.t$value$cv.rmse.observed,
      total.local.gcv.ps = row.t$value$total.local.gcv.ps,
      sync.energy = row.t$value$sync.energy,
      mean.sync.squared.disagreement =
        row.t$value$mean.sync.squared.disagreement,
      eval.elapsed.sec = row.t$elapsed,
      stringsAsFactors = FALSE
    )
    eval.env$rows[[key]] <- row
    row
  }
  list(
    setup.elapsed.sec = setup.t$elapsed,
    evaluate = function(lambda.grid) {
      lambda.grid <- sort(unique(as.numeric(lambda.grid)))
      do.call(rbind, lapply(lambda.grid, eval.one))
    },
    evaluated = function() {
      if (!length(eval.env$rows)) {
        return(data.frame())
      }
      out <- do.call(rbind, eval.env$rows)
      out[order(out$lambda.sync), , drop = FALSE]
    }
  )
}

select.row <- function(cv.table, tie.rel.tol = 0.002, tie.abs.tol = 1e-8) {
  min.cv <- min(cv.table$cv.rmse.observed)
  tol <- max(tie.abs.tol, tie.rel.tol * min.cv)
  ok <- cv.table$cv.rmse.observed <= min.cv + tol
  tied <- cv.table[ok, , drop = FALSE]
  tied[order(tied$lambda.sync), , drop = FALSE][1L, , drop = FALSE]
}

candidate.indices <- function(n, target) {
  unique(pmax(1L, pmin(n, as.integer(round(seq(1, n, length.out = target))))))
}

search.policy <- function(evaluator, lambda.grid, coarse.size = 5L,
                          refine.radius = 1L, include.zero = TRUE) {
  lambda.grid <- sort(unique(as.numeric(lambda.grid)))
  positive <- lambda.grid[lambda.grid > 0]
  zero.present <- any(lambda.grid == 0)
  eval.set <- numeric(0)
  stages <- list()
  if (include.zero && zero.present) {
    eval.set <- c(eval.set, 0)
  }
  if (length(positive)) {
    coarse.idx <- candidate.indices(length(positive),
                                    min(coarse.size, length(positive)))
    coarse.lam <- positive[coarse.idx]
    eval.set <- sort(unique(c(eval.set, coarse.lam)))
    coarse.table <- evaluator$evaluate(eval.set)
    coarse.best <- select.row(coarse.table)
    stages[[length(stages) + 1L]] <- data.frame(
      stage = "coarse",
      lambda.sync = eval.set,
      stringsAsFactors = FALSE
    )
    if (coarse.best$lambda.sync[[1L]] > 0) {
      best.idx <- which(positive == coarse.best$lambda.sync[[1L]])
      if (!length(best.idx)) {
        best.idx <- which.min(abs(log10(positive) -
                                   log10(coarse.best$lambda.sync[[1L]])))
      }
      if (best.idx == 1L) {
        refine.idx <- seq_len(min(length(positive), 1L + refine.radius + 1L))
        boundary.flag <- "left"
      } else if (best.idx == length(positive)) {
        refine.idx <- seq.int(max(1L, length(positive) - refine.radius - 1L),
                              length(positive))
        boundary.flag <- "right"
      } else {
        refine.idx <- seq.int(max(1L, best.idx - refine.radius),
                              min(length(positive), best.idx + refine.radius))
        boundary.flag <- "interior"
      }
      refine.lam <- positive[refine.idx]
      eval.set <- sort(unique(c(eval.set, refine.lam)))
      stages[[length(stages) + 1L]] <- data.frame(
        stage = paste0("refine_", boundary.flag),
        lambda.sync = refine.lam,
        stringsAsFactors = FALSE
      )
    }
  }
  final.table <- evaluator$evaluate(eval.set)
  selected <- select.row(final.table)
  list(
    evaluated = final.table[order(final.table$lambda.sync), , drop = FALSE],
    selected = selected,
    stages = if (length(stages)) do.call(rbind, stages) else data.frame(),
    candidate.count = length(unique(eval.set))
  )
}

cases <- data.frame(
  batch_id = c("FB01", "FB01", "FB06", "FB07", "FB09", "FB09",
               "FB10", "FB11", "FB12", "FB13", "FB14", "FB14"),
  chart_dim_rule = c("auto", "local.auto", "auto", "local.auto",
                     "auto", "local.auto", "local.auto", "local.auto",
                     "local.auto", "local.auto", "auto", "local.auto"),
  stringsAsFactors = FALSE
)

layout.id <- "wide_mixed_15"
lambda.grid <- c(0, 1e-4, 3e-4, 1e-3, 3e-3, 1e-2, 3e-2,
                 0.1, 0.3, 1, 3, 10, 30, 100, 300)

rows <- list()
curves <- list()
stages <- list()
rr <- 0L
cc <- 0L
ss <- 0L
for (ii in seq_len(nrow(cases))) {
  prepared <- prepare.case(cases$batch_id[[ii]], cases$chart_dim_rule[[ii]])
  message(sprintf(
    "C9 evaluating %s %s %s",
    prepared$batch_id, prepared$chart_dim_rule, layout.id
  ))

  full.evaluator <- make.evaluator(prepared)
  full.t <- time.block(full.evaluator$evaluate(lambda.grid))
  full.table <- full.t$value
  full.selected <- select.row(full.table)
  full.best.raw <- full.table[order(full.table$cv.rmse.observed,
                                    full.table$lambda.sync), ,
                              drop = FALSE][1L, , drop = FALSE]
  full.position <- if (full.best.raw$lambda.sync[[1L]] == 0) {
    "zero"
  } else if (full.best.raw$lambda.sync[[1L]] ==
             min(lambda.grid[lambda.grid > 0])) {
    "left_boundary"
  } else if (full.best.raw$lambda.sync[[1L]] == max(lambda.grid)) {
    "right_boundary"
  } else {
    "interior"
  }

  search.evaluator <- make.evaluator(prepared)
  search.t <- time.block(search.policy(search.evaluator, lambda.grid))
  search <- search.t$value
  search.selected <- search$selected
  regret <- search.selected$cv.rmse.observed[[1L]] -
    full.selected$cv.rmse.observed[[1L]]
  rel.regret <- regret / full.selected$cv.rmse.observed[[1L]]
  selected.agree <- isTRUE(all.equal(search.selected$lambda.sync[[1L]],
                                     full.selected$lambda.sync[[1L]]))

  rr <- rr + 1L
  rows[[rr]] <- data.frame(
    batch_id = prepared$batch_id,
    dataset_id = prepared$dataset_id,
    chart_dim_rule = prepared$chart_dim_rule,
    layout_id = layout.id,
    full_grid = paste(lambda.grid, collapse = ", "),
    full_candidate_count = length(lambda.grid),
    search_candidate_count = search$candidate.count,
    candidate_reduction = length(lambda.grid) - search$candidate.count,
    candidate_reduction_pct =
      100 * (length(lambda.grid) - search$candidate.count) / length(lambda.grid),
    full_setup_elapsed_sec = full.evaluator$setup.elapsed.sec,
    full_eval_elapsed_sec = full.t$elapsed,
    search_setup_elapsed_sec = search.evaluator$setup.elapsed.sec,
    search_eval_elapsed_sec = search.t$elapsed,
    full_total_elapsed_sec = full.evaluator$setup.elapsed.sec + full.t$elapsed,
    search_total_elapsed_sec =
      search.evaluator$setup.elapsed.sec + search.t$elapsed,
    elapsed_speedup =
      (full.evaluator$setup.elapsed.sec + full.t$elapsed) /
      (search.evaluator$setup.elapsed.sec + search.t$elapsed),
    full_raw_best_lambda = full.best.raw$lambda.sync[[1L]],
    full_selected_lambda = full.selected$lambda.sync[[1L]],
    search_selected_lambda = search.selected$lambda.sync[[1L]],
    full_best_position = full.position,
    selected_agree = selected.agree,
    cv_rmse_regret = regret,
    cv_rmse_relative_regret = rel.regret,
    stringsAsFactors = FALSE
  )

  full.table$path <- "full_grid"
  full.table$evaluated_by_search <- full.table$lambda.sync %in%
    search$evaluated$lambda.sync
  full.table$batch_id <- prepared$batch_id
  full.table$dataset_id <- prepared$dataset_id
  full.table$chart_dim_rule <- prepared$chart_dim_rule
  full.table$layout_id <- layout.id
  full.table$full_selected_lambda <- full.selected$lambda.sync[[1L]]
  full.table$search_selected_lambda <- search.selected$lambda.sync[[1L]]
  cc <- cc + 1L
  curves[[cc]] <- full.table

  if (nrow(search$stages)) {
    search$stages$batch_id <- prepared$batch_id
    search$stages$dataset_id <- prepared$dataset_id
    search$stages$chart_dim_rule <- prepared$chart_dim_rule
    search$stages$layout_id <- layout.id
    ss <- ss + 1L
    stages[[ss]] <- search$stages
  }
}

summary.table <- do.call(rbind, rows)
curve.table <- do.call(rbind, curves)
stage.table <- if (length(stages)) do.call(rbind, stages) else data.frame()
write.csv.safe(summary.table, file.path(table.dir, "ps_lps_c9_search_summary.csv"))
write.csv.safe(curve.table, file.path(table.dir, "ps_lps_c9_full_grid_curves.csv"))
write.csv.safe(stage.table, file.path(table.dir, "ps_lps_c9_search_stages.csv"))

theme.report <- ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    legend.position = "bottom",
    plot.title.position = "plot"
  )
curve.table$case_layout <- paste(
  curve.table$batch_id,
  curve.table$chart_dim_rule,
  curve.table$layout_id
)
curve.table$lambda_label <- ifelse(curve.table$lambda.sync == 0,
                                   "0",
                                   formatC(curve.table$lambda.sync,
                                           format = "fg", digits = 4))

p.curve <- ggplot2::ggplot(
  curve.table,
  ggplot2::aes(x = factor(lambda_label, levels = unique(lambda_label)),
               y = cv.rmse.observed, group = 1)
) +
  ggplot2::geom_line(color = "gray45") +
  ggplot2::geom_point(ggplot2::aes(color = evaluated_by_search), size = 2.5) +
  ggplot2::geom_point(
    data = curve.table[curve.table$lambda.sync ==
                         curve.table$full_selected_lambda, , drop = FALSE],
    shape = 21,
    size = 4,
    stroke = 1.1,
    fill = NA,
    color = "#1b9e77"
  ) +
  ggplot2::geom_point(
    data = curve.table[curve.table$lambda.sync ==
                         curve.table$search_selected_lambda, , drop = FALSE],
    shape = 4,
    size = 4,
    stroke = 1.1,
    color = "#d95f02"
  ) +
  ggplot2::facet_wrap(~ case_layout, scales = "free_y") +
  ggplot2::labs(
    title = "C9 full-grid CV curves and searched candidates",
    subtitle = "Green circle = full-grid selected lambda; orange cross = search-selected lambda.",
    x = "lambda.sync candidate",
    y = "CV RMSE",
    color = "Evaluated by search"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_c9_cv_curves.png"),
                p.curve, width = 14, height = 9, dpi = 180)

summary.table$case_layout <- paste(
  summary.table$batch_id,
  summary.table$chart_dim_rule,
  summary.table$layout_id
)
p.count <- ggplot2::ggplot(
  summary.table,
  ggplot2::aes(x = case_layout)
) +
  ggplot2::geom_col(
    ggplot2::aes(y = full_candidate_count),
    fill = "gray82",
    width = 0.65
  ) +
  ggplot2::geom_point(
    ggplot2::aes(y = search_candidate_count),
    color = "#2b8cbe",
    size = 3.2
  ) +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = "C9 candidate count reduction",
    subtitle = "Gray bars show full-grid candidate count; blue points show searched candidate count.",
    x = NULL,
    y = "Number of lambda.sync candidates"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_c9_candidate_counts.png"),
                p.count, width = 11, height = 7, dpi = 180)

p.regret <- ggplot2::ggplot(
  summary.table,
  ggplot2::aes(x = case_layout, y = cv_rmse_regret)
) +
  ggplot2::geom_hline(yintercept = 0, color = "gray60",
                      linetype = "dashed") +
  ggplot2::geom_point(size = 3.2, color = "#756bb1") +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = "C9 CV RMSE regret relative to full grid",
    subtitle = "Regret is search-selected CV RMSE minus full-grid selected CV RMSE.",
    x = NULL,
    y = "CV RMSE regret"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_c9_cv_regret.png"),
                p.regret, width = 11, height = 7, dpi = 180)

display.summary <- transform(
  summary.table,
  candidate_reduction_pct = fmt(candidate_reduction_pct),
  full_total_elapsed_sec = fmt(full_total_elapsed_sec),
  search_total_elapsed_sec = fmt(search_total_elapsed_sec),
  elapsed_speedup = fmt(elapsed_speedup),
  cv_rmse_regret = fmt(cv_rmse_regret),
  cv_rmse_relative_regret = fmt(cv_rmse_relative_regret)
)
display.summary <- display.summary[, c(
  "batch_id", "dataset_id", "chart_dim_rule", "layout_id",
  "full_candidate_count", "search_candidate_count",
  "candidate_reduction_pct", "full_best_position",
  "full_selected_lambda", "search_selected_lambda", "selected_agree",
  "cv_rmse_regret", "cv_rmse_relative_regret",
  "full_total_elapsed_sec", "search_total_elapsed_sec", "elapsed_speedup"
)]

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

max.regret <- max(summary.table$cv_rmse_regret)
min.reduction <- min(summary.table$candidate_reduction_pct)
all.agree <- all(summary.table$selected_agree)
report <- htmltools::tagList(
  htmltools::tags$html(
    htmltools::tags$head(
      htmltools::tags$title("PS-LPS C9 Broader Lambda Search Validation"),
      htmltools::tags$style(css)
    ),
    htmltools::tags$body(
      htmltools::tags$h1("PS-LPS C9 Broader Lambda Search Validation"),
      htmltools::tags$p(
        class = "note",
        "C9 evaluates the guarded coarse-to-refine lambda.sync search policy ",
        "from C8 across a broader frozen first-batch suite.  The deployable ",
        "correctness guard is CV RMSE regret: the search-selected CV RMSE ",
        "minus the full-grid selected CV RMSE.  A practical tie rule selects ",
        "the smallest lambda.sync whose CV RMSE is within 0.2% of the grid ",
        "minimum."
      ),
      htmltools::tags$h2("Summary"),
      htmltools::tags$p(
        class = "note",
        sprintf(
          paste0(
            "Across the C9 validation cases, selected-lambda agreement was %s, ",
            "maximum CV RMSE regret was %s, and candidate reduction was at ",
            "least %s%%.  These broader validation results are still offline ",
            "and script-local; they do not yet establish a package default."
          ),
          if (all.agree) "complete" else "not complete",
          fmt(max.regret),
          fmt(min.reduction)
        )
      ),
      table.html(display.summary),
      htmltools::tags$h2("Full-Grid Curves"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures",
                                            "ps_lps_c9_cv_curves.png")),
        htmltools::tags$p(
          class = "caption",
          "Each panel shows the full-grid CV curve.  Search-evaluated ",
          "candidates are highlighted.  The green circle marks the full-grid ",
          "tie-rule selection and the orange cross marks the search selection."
        )
      ),
      htmltools::tags$h2("Candidate Count and Regret"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures",
                                            "ps_lps_c9_candidate_counts.png"))
      ),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures",
                                            "ps_lps_c9_cv_regret.png"))
      ),
      htmltools::tags$h2("Output Tables"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_c9_search_summary.csv"),
          "Search summary"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_c9_full_grid_curves.csv"),
          "Full-grid CV curves"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_c9_search_stages.csv"),
          "Search stages"
        ))
      )
    )
  )
)

report.path <- file.path(out.dir, "ps_lps_c9_broader_search_validation_report.html")
htmltools::save_html(report, report.path)
message("Wrote ", report.path)
