#!/usr/bin/env Rscript

parse_args <- function(args) {
  out <- list()
  for (arg in args) {
    if (!grepl("^--", arg)) next
    kv <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1L]]
    key <- kv[[1L]]
    val <- if (length(kv) > 1L) paste(kv[-1L], collapse = "=") else TRUE
    out[[key]] <- val
  }
  out
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

args <- parse_args(commandArgs(trailingOnly = TRUE))
run.dir <- normalizePath(args$run_dir %||%
  "/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_20260607_001",
  mustWork = TRUE)
source.run.dir <- args$source_run_dir %||% NA_character_
repair.run.dir <- args$repair_run_dir %||% NA_character_
tables.dir <- file.path(run.dir, "tables")
reports.dir <- file.path(run.dir, "reports")
fig.dir <- file.path(reports.dir, "figures_s3r_expanded_results")
dir.create(fig.dir, recursive = TRUE, showWarnings = FALSE)

read_table <- function(name) {
  path <- file.path(tables.dir, name)
  if (!file.exists(path)) {
    stop("Missing required table: ", path)
  }
  read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

pairs <- read_table("full_vs_screened_pairs.csv")
chart.summary <- read_table("paired_summary_by_chart_rule.csv")
dataset.summary <- read_table("paired_summary_by_dataset.csv")
rep.summary <- read_table("paired_summary_by_repetition_subset.csv")
task.status <- read_table("task_status.csv")
task.by.design <- read_table("task_status_by_design.csv")
task.summary <- read_table("task_summary.csv")
inclusion <- read_table("candidate_inclusion_diagnostics.csv")

report.name <- args$report_name %||% "ps_lps_s3r_expanded_results_report.html"
report.path <- file.path(reports.dir, report.name)

theme <- list(
  ink = "#26313d",
  muted = "#64748b",
  grid = "#d8dee8",
  red = "#b91c1c",
  blue = "#2563eb",
  green = "#15803d",
  gray = "#94a3b8",
  amber = "#b45309"
)

html_escape <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

fmt <- function(x, digits = 4) {
  ifelse(is.na(x), "NA", formatC(x, digits = digits, format = "fg", flag = "#"))
}

fmt_int <- function(x) {
  formatC(as.integer(x), format = "d", big.mark = ",")
}

weighted_median <- function(x, w) {
  ok <- is.finite(x) & is.finite(w) & w >= 0
  x <- x[ok]
  w <- w[ok]
  if (!length(x) || sum(w) <= 0) return(NA_real_)
  ord <- order(x)
  x <- x[ord]
  w <- w[ord] / sum(w)
  x[which(cumsum(w) >= 0.5)[1]]
}

bb_median_ci <- function(x, B = 3000, seed = 20260608L) {
  x <- x[is.finite(x)]
  if (!length(x)) return(c(median = NA_real_, lo = NA_real_, hi = NA_real_))
  if (length(unique(x)) == 1L) {
    return(c(median = median(x), lo = median(x), hi = median(x)))
  }
  set.seed(seed)
  vals <- replicate(B, {
    w <- rexp(length(x))
    weighted_median(x, w)
  })
  c(median = median(x), lo = unname(quantile(vals, 0.025, na.rm = TRUE)),
    hi = unname(quantile(vals, 0.975, na.rm = TRUE)))
}

fig_rel <- function(path) {
  file.path("figures_s3r_expanded_results", basename(path))
}

write_png <- function(path, expr, width = 1600, height = 950) {
  png(path, width = width, height = height, res = 150)
  on.exit(dev.off(), add = TRUE)
  par(family = "sans", fg = theme$ink, col.axis = theme$ink, col.lab = theme$ink,
      col.main = theme$ink, mar = c(5.1, 8.5, 4.2, 2.2), xaxs = "i")
  force(expr)
}

panel_caption <- function(num, title, text) {
  sprintf(
    '<p class="caption"><strong>Figure %d. %s.</strong> %s</p>',
    num, html_escape(title), text
  )
}

make_small_table <- function(df, digits = 4) {
  if (!nrow(df)) return("<p>No rows.</p>")
  out <- c("<table class=\"compact\"><thead><tr>",
           paste0("<th>", html_escape(names(df)), "</th>", collapse = ""),
           "</tr></thead><tbody>")
  for (i in seq_len(nrow(df))) {
    row <- vapply(df[i, , drop = FALSE], function(col) {
      value <- col[[1]]
      if (is.numeric(value)) fmt(value, digits = digits) else html_escape(value)
    }, character(1))
    out <- c(out, "<tr>", paste0("<td>", row, "</td>", collapse = ""), "</tr>")
  }
  paste(c(out, "</tbody></table>"), collapse = "\n")
}

complete <- subset(pairs, pair_complete)
complete$chart_dim_rule <- factor(complete$chart_dim_rule, levels = c("auto", "local.auto"))
complete$candidate_ratio <- complete$screened_candidates_evaluated / complete$full_candidates_evaluated

planned.pairs <- nrow(pairs)
complete.pairs <- nrow(complete)
screened.errors <- subset(task.status, search_policy == "screened" & status == "error")
full.errors <- subset(task.status, search_policy == "full" & status != "ok")

chart.stats <- do.call(rbind, lapply(split(complete, complete$chart_dim_rule), function(df) {
  med.delta <- bb_median_ci(df$delta_truth_rmse)
  med.runtime <- bb_median_ci(df$elapsed_ratio_screened_full)
  med.cand <- bb_median_ci(df$candidate_ratio)
  data.frame(
    chart_dim_rule = as.character(df$chart_dim_rule[1]),
    complete_pairs = nrow(df),
    median_delta_truth_rmse = med.delta["median"],
    delta_cri_low = med.delta["lo"],
    delta_cri_high = med.delta["hi"],
    median_runtime_ratio = med.runtime["median"],
    runtime_cri_low = med.runtime["lo"],
    runtime_cri_high = med.runtime["hi"],
    median_candidate_ratio = med.cand["median"],
    candidate_cri_low = med.cand["lo"],
    candidate_cri_high = med.cand["hi"],
    screened_better = sum(df$delta_truth_rmse < -1e-12, na.rm = TRUE),
    ties = sum(abs(df$delta_truth_rmse) <= 1e-12, na.rm = TRUE),
    full_better = sum(df$delta_truth_rmse > 1e-12, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))

fig1 <- file.path(fig.dir, "figure_1_truth_rmse_delta_by_chart_rule.png")
write_png(fig1, {
  xs <- complete$delta_truth_rmse
  lim <- quantile(xs, c(0.01, 0.99), na.rm = TRUE)
  lim <- range(c(lim, 0, chart.stats$delta_cri_low, chart.stats$delta_cri_high), na.rm = TRUE)
  pad <- diff(lim) * 0.12
  if (!is.finite(pad) || pad == 0) pad <- 0.001
  lim <- lim + c(-pad, pad)
  plot(NA, xlim = lim, ylim = c(0.5, 2.5), yaxt = "n",
       xlab = expression(Delta*" Truth RMSE = screened - full"),
       ylab = "", main = "Screened PS-LPS Accuracy Relative to Full Search")
  axis(2, at = 1:2, labels = c("auto", "local.auto"), las = 1)
  abline(v = 0, col = theme$muted, lwd = 2)
  abline(h = 1:2, col = theme$grid)
  set.seed(1)
  for (j in seq_along(levels(complete$chart_dim_rule))) {
    lev <- levels(complete$chart_dim_rule)[j]
    xj <- complete$delta_truth_rmse[complete$chart_dim_rule == lev]
    yj <- rep(j, length(xj)) + runif(length(xj), -0.12, 0.12)
    points(xj, yj, pch = 16, col = adjustcolor(theme$gray, 0.42), cex = 0.8)
    st <- chart.stats[chart.stats$chart_dim_rule == lev, ]
    segments(st$delta_cri_low, j, st$delta_cri_high, j, col = theme$red, lwd = 5)
    points(st$median_delta_truth_rmse, j, pch = 21, bg = theme$red, col = "white", cex = 1.5, lwd = 1.2)
    label <- sprintf("n=%s, screened better/tie/full better = %s/%s/%s",
                     fmt_int(st$complete_pairs), fmt_int(st$screened_better),
                     fmt_int(st$ties), fmt_int(st$full_better))
    text(lim[2], j + 0.23, label, adj = c(1, 0.5), cex = 0.78, col = theme$muted)
  }
  legend("topleft", legend = c("Complete pair", "Median and Bayesian bootstrap 95% CrI", "No difference"),
         pch = c(16, 21, NA), pt.bg = c(NA, theme$red, NA), col = c(theme$gray, "white", theme$muted),
         lty = c(NA, 1, 1), lwd = c(NA, 4, 2), bty = "n", cex = 0.84)
})

fig2 <- file.path(fig.dir, "figure_2_dataset_truth_rmse_delta_summary.png")
write_png(fig2, width = 1950, height = 1120, {
  par(mar = c(5.1, 12.5, 4.2, 3.8))
  ds <- dataset.summary[order(dataset.summary$mean_delta_truth_rmse), ]
  y <- seq_len(nrow(ds))
  lim <- range(c(ds$ci95_lo, ds$ci95_hi, 0), na.rm = TRUE)
  pad <- diff(lim) * 0.15
  if (!is.finite(pad) || pad == 0) pad <- 0.001
  lim <- lim + c(-pad, pad)
  plot(NA, xlim = lim, ylim = c(0.5, nrow(ds) + 0.5), yaxt = "n",
       xlab = expression("Mean " * Delta * " Truth RMSE = screened - full"),
       ylab = "", main = "Dataset-Level Accuracy Shift")
  axis(2, at = y, labels = ds$dataset_id, las = 1, cex.axis = 0.68)
  abline(v = 0, col = theme$muted, lwd = 2)
  abline(h = y, col = theme$grid)
  sig <- ds$ci95_lo > 0 | ds$ci95_hi < 0
  segments(ds$ci95_lo, y, ds$ci95_hi, y, col = ifelse(sig, theme$red, theme$gray), lwd = 3)
  points(ds$mean_delta_truth_rmse, y, pch = 21, bg = ifelse(sig, theme$red, theme$blue),
         col = "white", cex = 1.25)
  text(lim[2], y, paste0("n=", ds$complete_pairs, "/", ds$planned_pairs),
       adj = c(1, 0.5), cex = 0.62, col = theme$muted)
})

fig3 <- file.path(fig.dir, "figure_3_runtime_ratio_by_chart_rule.png")
write_png(fig3, {
  xs <- complete$elapsed_ratio_screened_full
  lim <- quantile(xs, c(0.01, 0.99), na.rm = TRUE)
  lim <- range(c(lim, chart.stats$runtime_cri_low, chart.stats$runtime_cri_high, 1), na.rm = TRUE)
  lim[1] <- max(0, lim[1] - diff(lim) * 0.08)
  lim[2] <- lim[2] + diff(lim) * 0.12
  plot(NA, xlim = lim, ylim = c(0.5, 2.5), yaxt = "n",
       xlab = "Runtime ratio = screened elapsed / full elapsed",
       ylab = "", main = "Runtime Saved by Screening")
  axis(2, at = 1:2, labels = c("auto", "local.auto"), las = 1)
  abline(v = 1, col = theme$muted, lwd = 2)
  abline(h = 1:2, col = theme$grid)
  set.seed(2)
  for (j in seq_along(levels(complete$chart_dim_rule))) {
    lev <- levels(complete$chart_dim_rule)[j]
    xj <- complete$elapsed_ratio_screened_full[complete$chart_dim_rule == lev]
    yj <- rep(j, length(xj)) + runif(length(xj), -0.12, 0.12)
    points(xj, yj, pch = 16, col = adjustcolor(theme$gray, 0.42), cex = 0.8)
    st <- chart.stats[chart.stats$chart_dim_rule == lev, ]
    segments(st$runtime_cri_low, j, st$runtime_cri_high, j, col = theme$red, lwd = 5)
    points(st$median_runtime_ratio, j, pch = 21, bg = theme$red, col = "white", cex = 1.5, lwd = 1.2)
    text(lim[2], j + 0.23, sprintf("median ratio %s", fmt(st$median_runtime_ratio, 3)),
         adj = c(1, 0.5), cex = 0.78, col = theme$muted)
  }
  legend("topright", legend = c("Full-search runtime", "Median and Bayesian bootstrap 95% CrI"),
         lty = c(1, 1), lwd = c(2, 4), col = c(theme$muted, theme$red), bty = "n", cex = 0.84)
})

fig4 <- file.path(fig.dir, "figure_4_candidate_ratio_by_chart_rule.png")
write_png(fig4, {
  xs <- complete$candidate_ratio
  lim <- range(c(0, quantile(xs, c(0.01, 0.99), na.rm = TRUE), chart.stats$candidate_cri_low,
                 chart.stats$candidate_cri_high, 1), na.rm = TRUE)
  lim[2] <- min(1.05, lim[2] + 0.08)
  plot(NA, xlim = lim, ylim = c(0.5, 2.5), yaxt = "n",
       xlab = "Candidate ratio = screened candidates / full candidates",
       ylab = "", main = "Candidate-Count Reduction")
  axis(2, at = 1:2, labels = c("auto", "local.auto"), las = 1)
  abline(v = 1, col = theme$muted, lwd = 2)
  abline(h = 1:2, col = theme$grid)
  set.seed(3)
  for (j in seq_along(levels(complete$chart_dim_rule))) {
    lev <- levels(complete$chart_dim_rule)[j]
    xj <- complete$candidate_ratio[complete$chart_dim_rule == lev]
    yj <- rep(j, length(xj)) + runif(length(xj), -0.12, 0.12)
    points(xj, yj, pch = 16, col = adjustcolor(theme$gray, 0.42), cex = 0.8)
    st <- chart.stats[chart.stats$chart_dim_rule == lev, ]
    segments(st$candidate_cri_low, j, st$candidate_cri_high, j, col = theme$red, lwd = 5)
    points(st$median_candidate_ratio, j, pch = 21, bg = theme$red, col = "white", cex = 1.5, lwd = 1.2)
    text(lim[2], j + 0.23, sprintf("median ratio %s", fmt(st$median_candidate_ratio, 3)),
         adj = c(1, 0.5), cex = 0.78, col = theme$muted)
  }
})

fig5 <- file.path(fig.dir, "figure_5_candidate_inclusion_diagnostics.png")
write_png(fig5, width = 1950, height = 1050, {
  par(mar = c(5.1, 12.5, 4.2, 2.2))
  inc <- inclusion
  diagnostics <- unique(inc$diagnostic)
  labels <- c(
    "full support in screened supports" = "Full support in screened grid",
    "full candidate key in screened candidates" = "Full candidate key in screened grid",
    "selected support match" = "Selected support matches",
    "selected lambda match" = "Selected lambda matches"
  )
  yy <- seq_along(diagnostics)
  plot(NA, xlim = c(0, 1.05), ylim = c(0.5, length(diagnostics) + 0.5), yaxt = "n",
       xlab = "Rate among complete full/screened pairs",
       ylab = "", main = "Screening Inclusion and Match Diagnostics")
  axis(2, at = yy, labels = labels[diagnostics], las = 1, cex.axis = 0.78)
  abline(v = seq(0, 1, by = 0.25), col = theme$grid)
  cols <- c(auto = theme$blue, local.auto = theme$green)
  for (rule in c("auto", "local.auto")) {
    off <- ifelse(rule == "auto", -0.08, 0.08)
    x <- vapply(diagnostics, function(d) {
      val <- inc$rate[inc$chart_dim_rule == rule & inc$diagnostic == d]
      if (length(val)) val[[1]] else NA_real_
    }, numeric(1))
    points(x, yy + off, pch = 21, bg = cols[[rule]], col = "white", cex = 1.45)
    text(pmin(1.03, x + 0.035), yy + off, fmt(x, 3), cex = 0.7, col = theme$muted, adj = 0)
  }
  legend("bottomright", legend = c("auto", "local.auto"), pt.bg = cols, pch = 21,
         col = "white", bty = "n")
})

fig6 <- file.path(fig.dir, "figure_6_screened_error_accounting_by_dataset.png")
write_png(fig6, width = 1950, height = 1120, {
  par(mar = c(5.1, 12.5, 4.2, 4.8))
  screened <- subset(task.status, search_policy == "screened")
  all.ds <- sort(unique(screened$dataset_id))
  err <- tapply(screened$status == "error", screened$dataset_id, sum)
  ok <- tapply(screened$status == "ok", screened$dataset_id, sum)
  err <- setNames(as.integer(err[all.ds]), all.ds)
  ok <- setNames(as.integer(ok[all.ds]), all.ds)
  err[is.na(err)] <- 0L
  ok[is.na(ok)] <- 0L
  ord <- order(err, decreasing = FALSE)
  all.ds <- all.ds[ord]
  err <- err[ord]
  ok <- ok[ord]
  y <- seq_along(all.ds)
  max.err <- max(err, na.rm = TRUE)
  lim <- c(0, max(7, max.err + 7))
  main.title <- if (max.err == 0) {
    "No Screened Failures Remain"
  } else {
    "Screened Failures Were Not Spread Uniformly"
  }
  plot(NA, xlim = lim, ylim = c(0.5, length(all.ds) + 0.5), yaxt = "n",
       xlab = "Screened-policy error count",
       ylab = "", main = main.title)
  axis(2, at = y, labels = all.ds, las = 1, cex.axis = 0.68)
  abline(v = pretty(lim), col = theme$grid)
  segments(0, y, err, y, col = theme$grid, lwd = 4)
  points(err, y, pch = 21, bg = ifelse(err > 0, theme$red, theme$green), col = "white", cex = 1.4)
  text(pmin(lim[2], err + 0.7), y, paste0("errors=", err, ", ok=", ok),
       adj = 0, cex = 0.62, col = theme$muted)
})

task_status_compact <- as.data.frame.matrix(table(task.status$search_policy, task.status$status))
task_status_compact$search_policy <- rownames(task_status_compact)
task_status_compact <- task_status_compact[, c("search_policy", setdiff(names(task_status_compact), "search_policy")), drop = FALSE]

pair_status_compact <- data.frame(
  pair_status = names(table(pairs$pair_status)),
  count = as.integer(table(pairs$pair_status)),
  stringsAsFactors = FALSE
)

chart.table <- chart.stats[, c("chart_dim_rule", "complete_pairs", "median_delta_truth_rmse",
                               "delta_cri_low", "delta_cri_high",
                               "median_runtime_ratio", "median_candidate_ratio",
                               "screened_better", "ties", "full_better")]

rep.table <- rep.summary[, c("subset", "complete_pairs",
                             "mean_delta_truth_rmse", "ci95_lo", "ci95_hi",
                             "median_delta_truth_rmse", "median_elapsed_ratio_screened_full",
                             "median_candidates_screened", "median_candidates_full")]

all.table.links <- c(
  "full_vs_screened_pairs.csv",
  "paired_summary_by_chart_rule.csv",
  "paired_summary_by_dataset.csv",
  "paired_summary_by_geometry_family.csv",
  "paired_summary_by_repetition_subset.csv",
  "candidate_inclusion_diagnostics.csv",
  "task_status.csv",
  "task_status_by_design.csv",
  "task_summary.csv",
  "local_candidate_details.csv"
)
table_links_html <- paste(
  sprintf('<li><a href="../tables/%s">%s</a></li>', html_escape(all.table.links), html_escape(all.table.links)),
  collapse = "\n"
)

mtime <- max(file.info(file.path(tables.dir, list.files(tables.dir)))$mtime, na.rm = TRUE)
build.time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z", tz = "America/New_York")
tables.time <- format(mtime, "%Y-%m-%d %H:%M:%S %Z", tz = "America/New_York")

screened.error.by.dataset <- aggregate(status ~ dataset_id, subset(task.status, search_policy == "screened"),
                                       function(x) sum(x == "error"))
names(screened.error.by.dataset)[2] <- "screened_error_count"
screened.error.by.dataset <- screened.error.by.dataset[screened.error.by.dataset$screened_error_count > 0, ]
screened.error.by.dataset <- screened.error.by.dataset[order(-screened.error.by.dataset$screened_error_count), ]

style <- '
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #26313d; margin: 0; background: #f8fafc; }
main { max-width: 1180px; margin: 0 auto; padding: 36px 28px 70px; background: #ffffff; }
h1 { font-size: 34px; line-height: 1.12; margin: 0 0 10px; }
h2 { font-size: 23px; margin: 34px 0 12px; border-top: 1px solid #e2e8f0; padding-top: 22px; }
h3 { font-size: 18px; margin: 24px 0 10px; }
p, li { font-size: 15.5px; line-height: 1.55; }
.meta { color: #64748b; font-size: 13.5px; margin-bottom: 22px; }
.callout { border-left: 5px solid #2563eb; background: #eff6ff; padding: 12px 16px; margin: 18px 0; }
.warning { border-left-color: #b91c1c; background: #fef2f2; }
.small { color: #64748b; font-size: 13.5px; }
.figure { margin: 28px 0 18px; }
.figure img { width: 100%; max-width: 1120px; border: 1px solid #e2e8f0; }
.caption { color: #475569; font-size: 13.5px; margin-top: 7px; }
table.compact { border-collapse: collapse; width: 100%; margin: 12px 0 18px; font-size: 13.5px; }
table.compact th { text-align: left; background: #e2e8f0; padding: 7px 8px; }
table.compact td { border-bottom: 1px solid #e2e8f0; padding: 6px 8px; vertical-align: top; }
code { background: #f1f5f9; padding: 1px 4px; border-radius: 4px; }
.math { overflow-x: auto; padding: 4px 0; }
'

source.repair.html <- ""
if (!is.na(source.run.dir) || !is.na(repair.run.dir)) {
  source.repair.html <- paste0(
    '<p class="callout"><strong>Repair provenance.</strong> ',
    if (!is.na(source.run.dir)) {
      paste0('Source run: <code>', html_escape(source.run.dir), '</code>. ')
    } else {
      ""
    },
    if (!is.na(repair.run.dir)) {
      paste0('Screened repair run: <code>', html_escape(repair.run.dir), '</code>. ')
    } else {
      ""
    },
    'The original run directory is not overwritten; this report is rendered from a separate merged bundle.</p>'
  )
}

if (nrow(screened.errors) == 0L && nrow(full.errors) == 0L) {
  answer.first <- sprintf(
    '<p><strong>Answer first.</strong> After the screened-task repair, all %s full-search rows and all %s screened rows completed successfully, giving %s complete seed-matched pairs. The screened PS-LPS support-search policy preserves the full-search Truth RMSE almost exactly in median terms while evaluating far fewer support candidates and running in roughly forty percent of the full-search time.</p>',
    fmt_int(sum(task.status$search_policy == "full")),
    fmt_int(sum(task.status$search_policy == "screened")),
    fmt_int(complete.pairs)
  )
  accounting.text <- '<p>Interpretation starts with accounting because failed tasks change the denominator of any paired claim. In this repaired bundle, both the full and screened policies completed all planned rows, so the paired accuracy figures below use the full planned denominator.</p>'
  fig6.caption <- 'The repaired bundle has zero screened-policy errors. The plot shows error counts by dataset and successful screened-task counts in the text labels.'
  failure.figure.text <- '<p>Figure 6 confirms the repaired accounting: no screened-policy errors remain in this merged report bundle.</p>'
  reliability.item <- '<li><strong>Reliability:</strong> the repaired screened path completed all planned rows in this run. Together with the median-preserving accuracy result and consistent runtime reduction, this supports using screened PS-LPS as the routine experimental support-search policy for similar broad sweeps.</li>'
  recommended.next <- '<p>Use screened PS-LPS as the routine experimental support-search policy for similar broad synthetic and real-geometry sweeps. Keep full support-grid PS-LPS as the validation/reference mode for spot checks, new geometry families, publication-critical sensitivity checks, and cases where screening telemetry shows unusual candidate inclusion, fallback, or runtime behavior.</p>'
} else {
  answer.first <- sprintf(
    '<p><strong>Answer first.</strong> On the complete paired rows, the screened PS-LPS support-search policy preserved the full-search Truth RMSE almost exactly in median terms while evaluating far fewer support candidates and running in roughly forty percent of the full-search time. The result is encouraging but not yet a closure result: screened errors total %s and full non-ok rows total %s, so accuracy claims are conditional on the %s complete full/screened pairs.</p>',
    fmt_int(nrow(screened.errors)), fmt_int(nrow(full.errors)), fmt_int(complete.pairs)
  )
  accounting.text <- '<p>Interpretation starts with accounting because failed tasks change the denominator of any paired claim. The paired accuracy figures below use complete pairs only.</p>'
  fig6.caption <- 'Only screened-policy rows failed. The plot shows how those errors are distributed across datasets, with successful screened tasks shown in the text labels.'
  failure.figure.text <- '<p>Figure 6 shows how remaining failures are distributed across datasets. This is useful engineering signal: before the screened policy is treated as routine, the failing screened paths should be patched or made to return classified nonfinite/error states that preserve planned/ok/error accounting without losing paired interpretation.</p>'
  reliability.item <- '<li><strong>Reliability:</strong> the main blocker is screened-path robustness. Remaining screened failures should be addressed before treating screened PS-LPS as a default routine policy.</li>'
  recommended.next <- '<p>Patch any remaining screened-policy failure paths, then rerun a screened-only repair pass for the failed tasks. After that, regenerate this report with all planned pairs represented either as complete, classified nonfinite, or classified error rows.</p>'
}

if (all(dataset.summary$complete_pairs == dataset.summary$planned_pairs)) {
  fig2.text <- '<p>Figure 2 shows that the aggregate result is not driven by one universal direction. Several datasets slightly favor screening, several slightly favor full search, and most intervals remain close to zero. In this repaired report every dataset contributes complete paired rows.</p>'
} else {
  missing.ds <- dataset.summary$dataset_id[dataset.summary$complete_pairs == 0]
  if (length(missing.ds)) {
    fig2.text <- paste0(
      '<p>Figure 2 shows that the aggregate result is not driven by one universal direction. Several datasets slightly favor screening, several slightly favor full search, and most intervals remain close to zero. Datasets with no complete paired rows are absent from this figure; here that set is ',
      paste(sprintf('<code>%s</code>', html_escape(missing.ds)), collapse = ", "),
      '.</p>'
    )
  } else {
    fig2.text <- '<p>Figure 2 shows that the aggregate result is not driven by one universal direction. Several datasets slightly favor screening, several slightly favor full search, and most intervals remain close to zero. Labels at right show where partial pairing remains.</p>'
  }
}

html <- c(
  '<!doctype html>',
  '<html lang="en">',
  '<head>',
  '<meta charset="utf-8">',
  '<meta name="viewport" content="width=device-width, initial-scale=1">',
  '<title>PS-LPS S3R Expanded Seed-Matched Results</title>',
  '<script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js" async></script>',
  '<style>', style, '</style>',
  '</head>',
  '<body><main>',
  '<h1>PS-LPS S3R Expanded Seed-Matched Results</h1>',
  sprintf('<p class="meta">Generated %s from cached S3R-expanded tables last modified %s.<br>Run bundle: <code>%s</code></p>',
          html_escape(build.time), html_escape(tables.time), html_escape(run.dir)),
  source.repair.html,
  '<div class="callout">',
  answer.first,
  '</div>',
  '<h2>Main Questions</h2>',
  '<p>This S3R-expanded run asks whether the screened PS-LPS support-search policy can replace the full support-grid policy for routine runs without materially changing fitted accuracy. The paired comparison is deliberately seed-matched: for each dataset, repetition, and chart-dimension rule, the screened policy is compared to the corresponding full policy on the same synthetic response.</p>',
  '<p>The report focuses on four questions:</p>',
  '<ul>',
  '<li>Does screening preserve synthetic Truth RMSE relative to full support-grid search?</li>',
  '<li>How much runtime and candidate-count reduction does screening deliver?</li>',
  '<li>Are the screened failures contained, and do they affect the interpretation?</li>',
  '<li>Does the conclusion differ between <code>chart.dim = "auto"</code> and <code>chart.dim = "local.auto"</code>?</li>',
  '</ul>',
  '<h2>Methods and Quantities</h2>',
  '<p>The model is prediction-synchronized local polynomial smoothing (PS-LPS). Each local chart fits a polynomial prediction rule, and the synchronized objective couples overlapping chart predictions with a synchronization penalty. The full policy searches the full support-size grid; the screened policy first uses a cheaper support-screening step and then optimizes PS-LPS over the retained support candidates.</p>',
  '<p>The paired unit is</p>',
  '<div class="math">\\[ (\\text{dataset},\\ \\text{repetition},\\ \\text{chart-dimension rule}). \\]</div>',
  '<p>The synthetic target is Truth RMSE, computed against the known simulation truth:</p>',
  '<div class="math">\\[ R_m = \\operatorname{TruthRMSE}(m)=\\left\\{\\frac{1}{n}\\sum_{i=1}^n\\bigl(\\hat f_i^m-f_i\\bigr)^2\\right\\}^{1/2}. \\]</div>',
  '<p>The primary paired accuracy contrast is</p>',
  '<div class="math">\\[ \\Delta R = R_{\\rm screened}-R_{\\rm full}. \\]</div>',
  '<p>Negative values favor the screened policy; positive values favor the full policy. Runtime and candidate-count reductions are summarized by</p>',
  '<div class="math">\\[ \\rho_T=\\frac{T_{\\rm screened}}{T_{\\rm full}},\\qquad \\rho_C=\\frac{C_{\\rm screened}}{C_{\\rm full}}. \\]</div>',
  '<p>Values below one mean that screening used less time or fewer candidates. Red intervals in paired figures are Bayesian bootstrap 95% credible intervals for the paired median, using exponential bootstrap weights on the complete paired rows. Dataset-level intervals use the cached summary intervals produced with the run tables.</p>',
  '<h2>Fit-Status Accounting</h2>',
  accounting.text,
  make_small_table(task_status_compact),
  make_small_table(pair_status_compact),
  sprintf('<p>The run planned %s full/screened pairs and produced %s complete pairs. Screened errors total %s; full non-ok rows total %s.</p>',
          fmt_int(planned.pairs), fmt_int(complete.pairs), fmt_int(nrow(screened.errors)), fmt_int(nrow(full.errors))),
  if (nrow(screened.error.by.dataset)) {
    paste0('<p class="warning callout"><strong>Screened failure concentration.</strong> The datasets with screened errors were: ',
           paste(sprintf('<code>%s</code> (%d)', html_escape(screened.error.by.dataset$dataset_id),
                         screened.error.by.dataset$screened_error_count), collapse = ", "),
           '. These rows are excluded from complete-pair accuracy summaries, so any deployment recommendation still needs the screened failure modes patched or explicitly handled.</p>')
  } else {
    '<p class="callout"><strong>No screened errors were recorded.</strong></p>'
  },
  '<h2>Accuracy Results</h2>',
  '<div class="figure">',
  sprintf('<img src="%s" alt="Paired Truth RMSE deltas by chart rule">', html_escape(fig_rel(fig1))),
  panel_caption(1, "Paired Truth RMSE deltas by chart rule",
                'Each gray point is a complete seed-matched pair. Red points and intervals summarize the paired median and Bayesian bootstrap 95% credible interval. The vertical line at zero marks no accuracy difference.'),
  '</div>',
  '<p>Figure 1 is the core accuracy check. The medians are exactly or nearly zero because many screened fits select the same practical solution as the full search. The <code>auto</code> rule shows a small positive mean shift in the cached summaries, but the median comparison indicates that the typical complete pair is unchanged. The <code>local.auto</code> rule is even closer to zero on average among complete pairs.</p>',
  '<div class="figure">',
  sprintf('<img src="%s" alt="Dataset-level screened minus full Truth RMSE deltas">', html_escape(fig_rel(fig2))),
  panel_caption(2, "Dataset-level accuracy shifts",
                'Points show dataset-level mean screened-minus-full Truth RMSE; horizontal intervals are cached 95% intervals from the run summaries. Labels at right show complete over planned paired rows.'),
  '</div>',
  fig2.text,
  '<h2>Runtime and Candidate Work</h2>',
  '<div class="figure">',
  sprintf('<img src="%s" alt="Runtime ratios by chart rule">', html_escape(fig_rel(fig3))),
  panel_caption(3, "Runtime ratio by chart rule",
                'The runtime ratio is screened elapsed time divided by full elapsed time. Values below one indicate that screening was faster.'),
  '</div>',
  '<p>Figure 3 shows the practical speed gain: among complete pairs, screened runs usually took less than half the full-search time. This speedup is achieved by reducing the support candidates before the expensive PS-LPS synchronization solve, not by changing the final objective once a candidate is evaluated.</p>',
  '<div class="figure">',
  sprintf('<img src="%s" alt="Candidate ratios by chart rule">', html_escape(fig_rel(fig4))),
  panel_caption(4, "Candidate-count ratio by chart rule",
                'The candidate ratio is the number of screened support candidates divided by the number of full-search support candidates for the same paired task.'),
  '</div>',
  '<p>Figure 4 explains the runtime result. The screened policy commonly evaluates only a small fraction of the full support grid. Runtime does not shrink in exactly the same proportion because fixed overheads, chart construction, cache setup, and synchronization solves are not all proportional to the number of support candidates.</p>',
  '<div class="figure">',
  sprintf('<img src="%s" alt="Candidate inclusion and lambda-match diagnostics">', html_escape(fig_rel(fig5))),
  panel_caption(5, "Candidate inclusion and lambda-match diagnostics",
                'Rates are computed among complete full/screened pairs. Candidate-key inclusion is nearly the same as support inclusion because degree and kernel were fixed in this run.'),
  '</div>',
  '<p>Figure 5 is the main diagnostic for how screening succeeds. Screening does not always retain the exact full-search support candidate, yet it often selects the same or nearby synchronization penalty. This is why candidate-count savings can coexist with small Truth-RMSE deltas.</p>',
  '<h2>Failure Pattern</h2>',
  '<div class="figure">',
  sprintf('<img src="%s" alt="Screened error counts by dataset">', html_escape(fig_rel(fig6))),
  panel_caption(6, "Screened error accounting by dataset",
                fig6.caption),
  '</div>',
  failure.figure.text,
  '<h2>Summary Tables</h2>',
  '<p>The compact table below gives the key complete-pair summaries by chart-dimension rule. Longer tables are linked in the reproducibility section.</p>',
  make_small_table(chart.table),
  '<p>The repetition-subset summary checks whether the first 10 repetitions and all available repetitions tell the same story.</p>',
  make_small_table(rep.table),
  '<h2>What We Learned</h2>',
  '<ul>',
  '<li><strong>Accuracy:</strong> conditional on complete pairs, screened PS-LPS is usually indistinguishable from full support-grid PS-LPS in median Truth RMSE.</li>',
  '<li><strong>Speed:</strong> screening delivers a large practical speedup by evaluating fewer support candidates, with median runtime ratios around forty percent of full search.</li>',
  '<li><strong>Candidate behavior:</strong> exact support inclusion is not required for good performance; nearby or equivalent candidates often preserve the selected fit.</li>',
  reliability.item,
  '</ul>',
  '<h2>Recommended Next Step</h2>',
  recommended.next,
  '<h2>Reproducibility</h2>',
  '<p>This report was rendered from cached run tables and did not refit models. Source tables:</p>',
  '<ul>',
  table_links_html,
  '</ul>',
  sprintf('<p class="small">Renderer: <code>%s</code></p>',
          html_escape("/Users/pgajer/current_projects/geosmooth/scripts/render_ps_lps_s3r_expanded_results_report.R")),
  '</main></body></html>'
)

writeLines(html, report.path)
message("Wrote ", report.path)
