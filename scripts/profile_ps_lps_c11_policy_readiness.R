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
  "c11_policy_readiness_2026-06-05"
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
rmse <- function(a, b) sqrt(mean((a - b)^2))
time.block <- function(expr) {
  gc()
  start <- proc.time()
  value <- force(expr)
  elapsed <- unname((proc.time() - start)[["elapsed"]])
  list(value = value, elapsed = elapsed)
}

base.lambda.grid <- c(0, 1e-4, 3e-4, 1e-3, 3e-3, 1e-2, 3e-2,
                      0.1, 0.3, 1, 3, 10, 30, 100, 300)
positive.base <- base.lambda.grid[base.lambda.grid > 0]
reference.lambda.grid <- sort(unique(c(
  min(positive.base) / 9,
  min(positive.base) / 3,
  base.lambda.grid,
  max(positive.base) * 3,
  max(positive.base) * 9
)))

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
  list(
    batch_id = batch.id,
    dataset_id = asset.row[["dataset.id"]],
    geometry_family = asset.row[["geometry.family"]],
    chart_dim_rule = rule,
    asset = asset,
    lps.result = lps.result,
    chart.dim = chart.dim
  )
}

variant.spec <- list(
  exact_reference = list(
    label = "Exact expanded reference",
    search = "grid",
    grid = reference.lambda.grid,
    practical.reference = TRUE,
    control = list()
  ),
  guarded_default = list(
    label = "Guarded default",
    search = "guarded",
    grid = base.lambda.grid,
    practical.reference = FALSE,
    control = list()
  ),
  guarded_strict_edge = list(
    label = "Guarded stricter edge",
    search = "guarded",
    grid = base.lambda.grid,
    practical.reference = FALSE,
    control = list(boundary.guard.rel.tol = 0.002)
  ),
  guarded_one_expansion = list(
    label = "Guarded one expansion",
    search = "guarded",
    grid = base.lambda.grid,
    practical.reference = FALSE,
    control = list(max.boundary.expansions = 1L)
  )
)

fit.one <- function(prepared, spec) {
  asset <- prepared$asset
  lps <- prepared$lps.result
  args <- list(
    X = asset$X,
    y = asset$y,
    foldid = asset$foldid,
    support.size = lps$selected$support.size[[1L]],
    degree = lps$selected$degree[[1L]],
    kernel = lps$selected$kernel[[1L]],
    chart.dim = prepared$chart.dim,
    lambda.sync.grid = spec$grid,
    lambda.sync.search = spec$search,
    lambda.sync.search.control = spec$control,
    lambda.ridge = 1e-8,
    sync.neighbor.size = 3L
  )
  timed <- time.block(do.call(fit.ps.lps, args))
  fit <- timed$value
  if (isTRUE(spec$practical.reference)) {
    selected <- .ps.lps.select.lambda.table(fit$cv.table, rel.tol = 0.002)
    if (!isTRUE(all.equal(selected$lambda.sync[[1L]],
                          fit$selected$lambda.sync[[1L]]))) {
      args$lambda.sync.grid <- selected$lambda.sync[[1L]]
      args$lambda.sync.search <- "grid"
      args$lambda.sync.search.control <- list()
      refit <- do.call(fit.ps.lps, args)
      refit$cv.table <- fit$cv.table
      refit$selected <- selected
      refit$lambda.sync.search.telemetry <-
        .ps.lps.grid.search.telemetry(spec$grid)
      fit <- refit
    } else {
      fit$selected <- selected
    }
  }
  list(fit = fit, elapsed = timed$elapsed)
}

case.grid <- expand.grid(
  batch_id = asset.manifest[["batch.id"]],
  chart_dim_rule = c("auto", "local.auto"),
  stringsAsFactors = FALSE
)
case.grid <- case.grid[order(case.grid$batch_id, case.grid$chart_dim_rule), ,
                       drop = FALSE]

metrics.path <- file.path(table.dir, "ps_lps_c11_policy_metrics.csv")
pointwise.path <- file.path(table.dir, "ps_lps_c11_pointwise_delta.csv")
failures.path <- file.path(table.dir, "ps_lps_c11_failures.csv")
reuse.existing <- identical(Sys.getenv("C11_REUSE_EXISTING"), "1") &&
  file.exists(metrics.path) && file.exists(pointwise.path) &&
  file.exists(failures.path)

if (reuse.existing) {
  message("C11 reusing existing metric/pointwise/failure CSV tables")
  metrics <- read.csv.safe(metrics.path)
  pointwise <- read.csv.safe(pointwise.path)
  failures <- read.csv.safe(failures.path)
} else {
metric.rows <- list()
point.rows <- list()
failure.rows <- list()
mm <- 0L
pp <- 0L
ff <- 0L
for (ii in seq_len(nrow(case.grid))) {
  prepared <- prepare.case(case.grid$batch_id[[ii]],
                           case.grid$chart_dim_rule[[ii]])
  message(sprintf("C11 case %s %s", prepared$batch_id,
                  prepared$chart_dim_rule))
  fits <- list()
  for (variant.id in names(variant.spec)) {
    spec <- variant.spec[[variant.id]]
    message(sprintf("  fitting %s", variant.id))
    result <- tryCatch(
      fit.one(prepared, spec),
      error = function(e) e
    )
    if (inherits(result, "error")) {
      ff <- ff + 1L
      failure.rows[[ff]] <- data.frame(
        batch_id = prepared$batch_id,
        dataset_id = prepared$dataset_id,
        chart_dim_rule = prepared$chart_dim_rule,
        variant_id = variant.id,
        error = conditionMessage(result),
        stringsAsFactors = FALSE
      )
      next
    }
    fits[[variant.id]] <- result
  }
  if (!length(fits) || is.null(fits$exact_reference)) next
  ref <- fits$exact_reference$fit
  f.truth <- prepared$asset$f
  y <- prepared$asset$y
  ref.truth.rmse <- rmse(ref$fitted.values, f.truth)
  ref.observed.rmse <- rmse(ref$fitted.values, y)
  ref.fit <- ref$fitted.values
  for (variant.id in names(fits)) {
    fit <- fits[[variant.id]]$fit
    selected <- fit$selected
    truth.rmse <- rmse(fit$fitted.values, f.truth)
    observed.rmse <- rmse(fit$fitted.values, y)
    fit.delta <- fit$fitted.values - ref.fit
    telemetry <- fit$lambda.sync.search.telemetry
    boundary.expansions <- if (is.null(telemetry)) {
      NA_integer_
    } else {
      sum(grepl("^boundary_expand_", telemetry$stage))
    }
    mm <- mm + 1L
    metric.rows[[mm]] <- data.frame(
      batch_id = prepared$batch_id,
      dataset_id = prepared$dataset_id,
      geometry_family = prepared$geometry_family,
      chart_dim_rule = prepared$chart_dim_rule,
      variant_id = variant.id,
      variant_label = variant.spec[[variant.id]]$label,
      support.size = prepared$lps.result$selected$support.size[[1L]],
      degree = prepared$lps.result$selected$degree[[1L]],
      kernel = prepared$lps.result$selected$kernel[[1L]],
      selected_lambda_sync = selected$lambda.sync[[1L]],
      selected_cv_rmse = selected$cv.rmse.observed[[1L]],
      truth_rmse = truth.rmse,
      observed_rmse = observed.rmse,
      total_local_gcv_ps = fit$total.local.gcv.ps,
      sync_energy = fit$sync.energy,
      mean_sync_squared_disagreement =
        fit$mean.sync.squared.disagreement,
      candidate_count = nrow(fit$cv.table),
      boundary_expansion_count = boundary.expansions,
      elapsed_sec = fits[[variant.id]]$elapsed,
      truth_rmse_delta_vs_exact = truth.rmse - ref.truth.rmse,
      observed_rmse_delta_vs_exact = observed.rmse - ref.observed.rmse,
      fit_rmse_delta_vs_exact = rmse(fit$fitted.values, ref.fit),
      fit_max_abs_delta_vs_exact = max(abs(fit.delta)),
      stringsAsFactors = FALSE
    )
    if (!identical(variant.id, "exact_reference")) {
      e.variant <- fit$fitted.values - f.truth
      e.ref <- ref.fit - f.truth
      denom <- length(f.truth) * (truth.rmse + ref.truth.rmse)
      contrib <- ((e.variant)^2 - (e.ref)^2) / denom
      pp <- pp + 1L
      point.rows[[pp]] <- data.frame(
        batch_id = prepared$batch_id,
        dataset_id = prepared$dataset_id,
        chart_dim_rule = prepared$chart_dim_rule,
        variant_id = variant.id,
        point_index = seq_along(f.truth),
        exact_error = e.ref,
        variant_error = e.variant,
        contribution_to_truth_rmse_delta = contrib,
        stringsAsFactors = FALSE
      )
    }
  }
}

metrics <- if (length(metric.rows)) do.call(rbind, metric.rows) else data.frame()
pointwise <- if (length(point.rows)) do.call(rbind, point.rows) else data.frame()
failures <- if (length(failure.rows)) {
  do.call(rbind, failure.rows)
} else {
  data.frame(batch_id = character(), dataset_id = character(),
             chart_dim_rule = character(), variant_id = character(),
             error = character())
}

write.csv.safe(metrics, metrics.path)
write.csv.safe(pointwise, pointwise.path)
write.csv.safe(failures, failures.path)
}

variant.order <- names(variant.spec)
metrics$variant_id <- factor(metrics$variant_id, levels = variant.order)
metrics$case_id <- paste(metrics$batch_id, metrics$chart_dim_rule)
case.order <- metrics[metrics$variant_id == "exact_reference", , drop = FALSE]
case.order <- case.order[order(case.order$truth_rmse), "case_id"]
metrics$case_id <- factor(metrics$case_id, levels = case.order)

non.ref <- metrics[metrics$variant_id != "exact_reference", , drop = FALSE]
summary.flat <- do.call(rbind, lapply(
  split(non.ref, droplevels(non.ref$variant_id)),
  function(dd) {
  data.frame(
    variant_id = as.character(dd$variant_id[[1L]]),
    variant_label = as.character(dd$variant_label[[1L]]),
    truth_rmse_delta_vs_exact.mean =
      mean(dd$truth_rmse_delta_vs_exact),
    truth_rmse_delta_vs_exact.median =
      median(dd$truth_rmse_delta_vs_exact),
    truth_rmse_delta_vs_exact.max =
      max(dd$truth_rmse_delta_vs_exact),
    truth_rmse_delta_vs_exact.max_abs =
      max(abs(dd$truth_rmse_delta_vs_exact)),
    observed_rmse_delta_vs_exact.mean =
      mean(dd$observed_rmse_delta_vs_exact),
    observed_rmse_delta_vs_exact.median =
      median(dd$observed_rmse_delta_vs_exact),
    observed_rmse_delta_vs_exact.max =
      max(dd$observed_rmse_delta_vs_exact),
    fit_rmse_delta_vs_exact.mean =
      mean(dd$fit_rmse_delta_vs_exact),
    fit_rmse_delta_vs_exact.median =
      median(dd$fit_rmse_delta_vs_exact),
    fit_rmse_delta_vs_exact.max =
      max(dd$fit_rmse_delta_vs_exact),
    fit_max_abs_delta_vs_exact.max =
      max(dd$fit_max_abs_delta_vs_exact),
    candidate_count.mean = mean(dd$candidate_count),
    candidate_count.median = median(dd$candidate_count),
    elapsed_sec.mean = mean(dd$elapsed_sec),
    elapsed_sec.median = median(dd$elapsed_sec),
    stringsAsFactors = FALSE
  )
}))
write.csv.safe(summary.flat,
               file.path(table.dir, "ps_lps_c11_policy_summary.csv"))

ref.metrics <- metrics[metrics$variant_id == "exact_reference", c(
  "batch_id", "dataset_id", "chart_dim_rule", "selected_lambda_sync",
  "truth_rmse", "observed_rmse", "selected_cv_rmse"
)]
names(ref.metrics)[4:7] <- paste0("exact_", names(ref.metrics)[4:7])
mismatch.table <- merge(
  ref.metrics,
  non.ref,
  by = c("batch_id", "dataset_id", "chart_dim_rule")
)
mismatch.table <- mismatch.table[
  mismatch.table$exact_selected_lambda_sync !=
    mismatch.table$selected_lambda_sync,
  c("batch_id", "dataset_id", "chart_dim_rule", "variant_id",
    "exact_selected_lambda_sync", "selected_lambda_sync",
    "exact_truth_rmse", "truth_rmse", "truth_rmse_delta_vs_exact",
    "exact_selected_cv_rmse", "selected_cv_rmse",
    "candidate_count", "boundary_expansion_count")
]
write.csv.safe(mismatch.table,
               file.path(table.dir, "ps_lps_c11_lambda_mismatches.csv"))

theme.report <- ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    legend.position = "bottom",
    plot.title.position = "plot"
  )

p.truth <- ggplot2::ggplot(
  non.ref,
  ggplot2::aes(x = case_id, y = truth_rmse_delta_vs_exact,
               color = variant_id)
) +
  ggplot2::geom_hline(yintercept = 0, color = "gray55",
                      linetype = "dashed") +
  ggplot2::geom_point(position = ggplot2::position_dodge(width = 0.55),
                      size = 2.4) +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = "C11 Truth RMSE delta versus exact expanded reference",
    subtitle = "Negative values mean the guarded variant has lower Truth RMSE than the exact reference.",
    x = NULL,
    y = "Truth RMSE delta",
    color = "Policy"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_c11_truth_rmse_delta.png"),
                p.truth, width = 11, height = 9, dpi = 180)

p.fit <- ggplot2::ggplot(
  non.ref,
  ggplot2::aes(x = case_id, y = fit_rmse_delta_vs_exact,
               color = variant_id)
) +
  ggplot2::geom_point(position = ggplot2::position_dodge(width = 0.55),
                      size = 2.4) +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = "C11 fitted-value RMSE difference versus exact reference",
    subtitle = "This measures how much the fitted vector changes, independent of truth labels.",
    x = NULL,
    y = "RMSE between fitted vectors",
    color = "Policy"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_c11_fit_delta.png"),
                p.fit, width = 11, height = 9, dpi = 180)

p.lambda <- ggplot2::ggplot(
  metrics,
  ggplot2::aes(x = case_id, y = selected_lambda_sync,
               color = variant_id)
) +
  ggplot2::geom_point(position = ggplot2::position_dodge(width = 0.55),
                      size = 2.2) +
  ggplot2::scale_y_continuous(trans = "pseudo_log",
                              breaks = c(0, 1e-4, 1e-2, 1, 100, 2700)) +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = "C11 selected lambda.sync by policy",
    x = NULL,
    y = "Selected lambda.sync",
    color = "Policy"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_c11_selected_lambda.png"),
                p.lambda, width = 11, height = 9, dpi = 180)

p.count <- ggplot2::ggplot(
  metrics,
  ggplot2::aes(x = case_id, y = candidate_count, color = variant_id)
) +
  ggplot2::geom_point(position = ggplot2::position_dodge(width = 0.55),
                      size = 2.2) +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = "C11 candidate counts by policy",
    x = NULL,
    y = "Number of evaluated lambda.sync candidates",
    color = "Policy"
  ) +
  theme.report
ggplot2::ggsave(file.path(fig.dir, "ps_lps_c11_candidate_counts.png"),
                p.count, width = 11, height = 9, dpi = 180)

if (nrow(pointwise)) {
  point.groups <- split(
    pointwise,
    list(pointwise$batch_id, pointwise$dataset_id,
         pointwise$chart_dim_rule, pointwise$variant_id),
    drop = TRUE
  )
  point.flat <- do.call(rbind, lapply(point.groups, function(dd) {
    x <- dd$contribution_to_truth_rmse_delta
    data.frame(
      batch_id = dd$batch_id[[1L]],
      dataset_id = dd$dataset_id[[1L]],
      chart_dim_rule = dd$chart_dim_rule[[1L]],
      variant_id = dd$variant_id[[1L]],
      positive_mass = sum(pmax(x, 0)),
      negative_mass = sum(pmin(x, 0)),
      absolute_mass = sum(abs(x)),
      stringsAsFactors = FALSE
    )
  }))
  write.csv.safe(point.flat,
                 file.path(table.dir,
                           "ps_lps_c11_pointwise_delta_summary.csv"))
}

display.metrics <- transform(
  metrics,
  selected_lambda_sync = fmt(selected_lambda_sync),
  selected_cv_rmse = fmt(selected_cv_rmse),
  truth_rmse = fmt(truth_rmse),
  truth_rmse_delta_vs_exact = fmt(truth_rmse_delta_vs_exact),
  fit_rmse_delta_vs_exact = fmt(fit_rmse_delta_vs_exact),
  elapsed_sec = fmt(elapsed_sec)
)
display.metrics <- display.metrics[, c(
  "batch_id", "dataset_id", "chart_dim_rule", "variant_id",
  "selected_lambda_sync", "candidate_count", "boundary_expansion_count",
  "selected_cv_rmse", "truth_rmse", "truth_rmse_delta_vs_exact",
  "fit_rmse_delta_vs_exact", "elapsed_sec"
)]

table.html <- function(df, max.rows = 120L) {
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
.note { max-width: 1060px; }
.figure { margin: 24px 0 30px; }
.figure img { max-width: 100%; border: 1px solid #ddd; }
.caption { font-size: 0.94rem; color: #53606c; max-width: 1060px; }
.data-table { border-collapse: collapse; font-size: 0.82rem; margin: 12px 0 24px; }
.data-table th, .data-table td { border: 1px solid #ddd; padding: 5px 7px; text-align: right; }
.data-table th:first-child, .data-table td:first-child { text-align: left; }
code { background: #f3f4f6; padding: 1px 4px; border-radius: 3px; }
"

max.abs.truth.delta <- if (nrow(non.ref)) {
  max(abs(non.ref$truth_rmse_delta_vs_exact))
} else {
  NA_real_
}
max.fit.delta <- if (nrow(non.ref)) {
  max(non.ref$fit_rmse_delta_vs_exact)
} else {
  NA_real_
}
best.guard.default <- summary.flat[
  summary.flat$variant_id == "guarded_default", , drop = FALSE
]
failure.text <- if (nrow(failures)) {
  sprintf("%d failures were recorded; see the failures table.", nrow(failures))
} else {
  "No fit failures were recorded."
}

report <- htmltools::tagList(
  htmltools::tags$html(
    htmltools::tags$head(
      htmltools::tags$title("PS-LPS C11 Policy Readiness"),
      htmltools::tags$style(css)
    ),
    htmltools::tags$body(
      htmltools::tags$h1("PS-LPS C11 Policy Readiness"),
      htmltools::tags$p(
        class = "note",
        "C11 compares exact expanded-grid PS-LPS with guarded lambda.sync ",
        "search policies on all frozen first-batch examples under both ",
        "auto and local.auto chart-dimension rules.  The reference policy ",
        "uses the expanded C10 grid and the same practical 0.2% tie rule. ",
        "The main readiness criterion is whether guarded policies preserve ",
        "the selected fit, Truth RMSE, and pointwise truth-error behavior, ",
        "not merely whether they save candidate evaluations."
      ),
      htmltools::tags$h2("Summary"),
      htmltools::tags$p(
        class = "note",
        sprintf(
          paste0(
            "%s Maximum absolute Truth RMSE delta versus the exact reference ",
            "was %s, and maximum fitted-vector RMSE difference was %s."
          ),
          failure.text,
          fmt(max.abs.truth.delta),
          fmt(max.fit.delta)
        )
      ),
      htmltools::tags$h2("Truth RMSE Delta"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures",
                                            "ps_lps_c11_truth_rmse_delta.png")),
        htmltools::tags$p(
          class = "caption",
          "Truth RMSE delta is variant Truth RMSE minus exact-reference ",
          "Truth RMSE.  Values near zero indicate practical equivalence to ",
          "the expanded exact-grid reference."
        )
      ),
      htmltools::tags$h2("Fitted-Value Difference"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures",
                                            "ps_lps_c11_fit_delta.png"))
      ),
      htmltools::tags$h2("Selected Lambda and Candidate Counts"),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures",
                                            "ps_lps_c11_selected_lambda.png"))
      ),
      htmltools::tags$div(
        class = "figure",
        htmltools::tags$img(src = file.path("figures",
                                            "ps_lps_c11_candidate_counts.png"))
      ),
      htmltools::tags$h2("Metric Preview"),
      table.html(display.metrics, max.rows = 80L),
      htmltools::tags$h2("Selected-Lambda Mismatches"),
      htmltools::tags$p(
        class = "note",
        "This table lists cases where a guarded policy selected a different ",
        "lambda.sync than the exact expanded reference.  Negative Truth RMSE ",
        "delta means the guarded policy had lower synthetic truth error."
      ),
      table.html(transform(
        mismatch.table,
        exact_selected_lambda_sync = fmt(exact_selected_lambda_sync),
        selected_lambda_sync = fmt(selected_lambda_sync),
        exact_truth_rmse = fmt(exact_truth_rmse),
        truth_rmse = fmt(truth_rmse),
        truth_rmse_delta_vs_exact = fmt(truth_rmse_delta_vs_exact),
        exact_selected_cv_rmse = fmt(exact_selected_cv_rmse),
        selected_cv_rmse = fmt(selected_cv_rmse)
      ), max.rows = 80L),
      htmltools::tags$h2("Output Tables"),
      htmltools::tags$ul(
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_c11_policy_metrics.csv"),
          "Policy metrics"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_c11_policy_summary.csv"),
          "Policy summary"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_c11_lambda_mismatches.csv"),
          "Selected-lambda mismatches"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_c11_pointwise_delta.csv"),
          "Pointwise delta table"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables",
                           "ps_lps_c11_pointwise_delta_summary.csv"),
          "Pointwise delta summary"
        )),
        htmltools::tags$li(htmltools::tags$a(
          href = file.path("tables", "ps_lps_c11_failures.csv"),
          "Failures"
        ))
      )
    )
  )
)

report.path <- file.path(out.dir, "ps_lps_c11_policy_readiness_report.html")
htmltools::save_html(report, report.path)
message("Wrote ", report.path)
