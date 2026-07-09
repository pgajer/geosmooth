#!/usr/bin/env Rscript

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

parse.args <- function(args) {
    out <- list()
    for (arg in args) {
        if (!startsWith(arg, "--")) next
        kv <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1L]]
        out[[kv[[1L]]]] <- if (length(kv) > 1L) {
            paste(kv[-1L], collapse = "=")
        } else {
            TRUE
        }
    }
    out
}

find.repo.dir <- function() {
    args <- commandArgs(trailingOnly = FALSE)
    script.args <- args[startsWith(args, "--file=")]
    script <- if (length(script.args)) sub("^--file=", "", script.args[[1L]]) else getwd()
    here <- normalizePath(dirname(script), mustWork = TRUE)
    for (ii in 1:8) {
        if (file.exists(file.path(here, "DESCRIPTION"))) return(here)
        parent <- dirname(here)
        if (identical(parent, here)) break
        here <- parent
    }
    normalizePath("/Users/pgajer/current_projects/geosmooth", mustWork = TRUE)
}

repo.dir <- find.repo.dir()
setwd(repo.dir)

cli <- parse.args(commandArgs(trailingOnly = TRUE))
date.tag <- format(Sys.Date(), "%Y%m%d")
input.root <- normalizePath(
    cli$`input-dir` %||% file.path(
        repo.dir, "dev/methods/lps/reports",
        "csd6_expanded_relative_regret_20260708"
    ),
    mustWork = TRUE
)
report.root <- cli$`report-dir` %||% file.path(
    repo.dir, "dev/methods/lps/reports",
    paste0("csd7_task_failure_diagnostics_", date.tag)
)
dir.create(report.root, recursive = TRUE, showWarnings = FALSE)
fig.dir <- file.path(report.root, "figures")
tab.dir <- file.path(report.root, "tables")
dir.create(fig.dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tab.dir, recursive = TRUE, showWarnings = FALSE)

html.escape <- function(x) {
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    gsub(">", "&gt;", x, fixed = TRUE)
}

fmt <- function(x, digits = 4L) {
    ifelse(is.na(x), "NA",
           ifelse(is.finite(x), formatC(x, format = "fg", digits = digits),
                  as.character(x)))
}

fmt.pct <- function(x, digits = 1L) {
    ifelse(is.na(x), "NA",
           ifelse(is.finite(x), paste0(formatC(x, format = "f", digits = digits), "%"),
                  as.character(x)))
}

write.svg <- function(path, width = 8, height = 5, expr) {
    grDevices::svg(path, width = width, height = height, onefile = TRUE)
    on.exit(grDevices::dev.off(), add = TRUE)
    force(expr)
}

small.table.html <- function(df, digits = 4L) {
    if (!nrow(df)) return("<p>No rows.</p>")
    out <- df
    for (nm in names(out)) {
        if (is.numeric(out[[nm]])) out[[nm]] <- fmt(out[[nm]], digits)
    }
    header <- paste0("<tr>",
                     paste0("<th>", html.escape(names(out)), "</th>", collapse = ""),
                     "</tr>")
    rows <- apply(out, 1L, function(row) {
        paste0("<tr>", paste0("<td>", html.escape(row), "</td>", collapse = ""),
               "</tr>")
    })
    paste0("<table>", header, paste(rows, collapse = "\n"), "</table>")
}

read.csv.required <- function(path) {
    if (!file.exists(path)) stop("Missing required table: ", path, call. = FALSE)
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

in.tables <- file.path(input.root, "tables")
scores <- read.csv.required(file.path(in.tables, "csd6_strategy_outer_scores.csv"))
refs <- read.csv.required(file.path(in.tables, "csd6_full_grid_candidate_scores.csv"))
metadata <- read.csv.required(file.path(in.tables, "csd6_result_metadata.csv"))
meta.value <- function(key, default = "not recorded") {
    hit <- metadata$value[metadata$key == key]
    if (length(hit)) hit[[1L]] else default
}

scores$task.id <- paste(scores$dataset.id, scores$repetition, scores$outer.fold,
                        sep = "::")
refs$task.id <- paste(refs$dataset.id, refs$repetition, refs$outer.fold,
                      sep = "::")
scores$selected.chart.dim.int <- suppressWarnings(as.integer(scores$selected.chart.dim))
scores$selected.support.size.int <- suppressWarnings(as.integer(scores$selected.support.size))

refs.ok <- refs[refs$status == "ok" & is.finite(refs$outer.rmse), , drop = FALSE]
refs.ok$relative.to.oracle <- ave(refs.ok$outer.rmse, refs.ok$task.id,
                                  FUN = function(x) x / min(x, na.rm = TRUE))
refs.ok$rank.truth <- ave(refs.ok$outer.rmse, refs.ok$task.id,
                          FUN = function(x) rank(x, ties.method = "min"))

oracle <- refs.ok[ave(refs.ok$outer.rmse, refs.ok$task.id,
                      FUN = function(x) x == min(x, na.rm = TRUE)) == 1, ,
                  drop = FALSE]
oracle <- oracle[!duplicated(oracle$task.id),
                 c("task.id", "outer.rmse", "support.size", "chart.dim"),
                 drop = FALSE]
names(oracle) <- c("task.id", "oracle.rmse", "oracle.k", "oracle.d")

near.counts <- aggregate(cbind(near.105 = relative.to.oracle <= 1.05,
                               near.115 = relative.to.oracle <= 1.15,
                               near.125 = relative.to.oracle <= 1.25,
                               near.150 = relative.to.oracle <= 1.50) ~ task.id,
                         data = refs.ok, FUN = sum)
candidate.counts <- aggregate(outer.rmse ~ task.id, data = refs.ok, FUN = length)
names(candidate.counts)[names(candidate.counts) == "outer.rmse"] <- "candidate.count"
near.counts <- merge(near.counts, candidate.counts, by = "task.id", all.x = TRUE)

selected.keys <- scores[, c("task.id", "strategy", "dataset.id", "dataset.family",
                            "repetition", "outer.fold", "status", "outer.rmse",
                            "outer.regret", "outer.relative.regret.percent",
                            "outer.rmse.ratio", "inner.cv.rmse",
                            "selected.support.size.int",
                            "selected.chart.dim.int", "reference.support.size",
                            "reference.chart.dim", "support.distance.to.reference",
                            "chart.dim.distance.to.reference",
                            "evaluated.candidates", "unique.pca.builds",
                            "elapsed.sec")]
selected.keys$merge.k <- selected.keys$selected.support.size.int
selected.keys$merge.d <- selected.keys$selected.chart.dim.int
refs.match <- refs.ok[, c("task.id", "support.size", "chart.dim", "outer.rmse",
                          "rank.truth", "relative.to.oracle")]
names(refs.match) <- c("task.id", "merge.k", "merge.d",
                       "matched.truth.rmse", "selected.truth.rank",
                       "selected.truth.ratio.from.grid")
diagnostics <- merge(selected.keys, refs.match,
                     by = c("task.id", "merge.k", "merge.d"), all.x = TRUE)
diagnostics <- merge(diagnostics, oracle, by = "task.id", all.x = TRUE)
diagnostics <- merge(diagnostics, near.counts, by = "task.id", all.x = TRUE)
diagnostics$selected.replay.present <- is.finite(diagnostics$matched.truth.rmse)
support.range <- range(refs.ok$support.size, na.rm = TRUE)
chart.dim.range <- range(refs.ok$chart.dim, na.rm = TRUE)
diagnostics$selected.on.k.boundary <- diagnostics$selected.support.size.int %in%
    support.range
diagnostics$selected.on.d.boundary <- diagnostics$selected.chart.dim.int %in%
    chart.dim.range
diagnostics$selected.near.115 <- diagnostics$outer.rmse.ratio <= 1.15
diagnostics$selected.near.125 <- diagnostics$outer.rmse.ratio <= 1.25
diagnostics$selected.poor.150 <- diagnostics$outer.rmse.ratio > 1.50
diagnostics$selected.very.poor.200 <- diagnostics$outer.rmse.ratio > 2.00

task.wide <- reshape(scores[, c("task.id", "strategy", "outer.rmse.ratio",
                                "outer.relative.regret.percent")],
                     idvar = "task.id", timevar = "strategy", direction = "wide")
names(task.wide) <- sub("outer.rmse.ratio\\.", "ratio.", names(task.wide))
names(task.wide) <- sub("outer.relative.regret.percent\\.", "relpct.",
                        names(task.wide))
diagnostics <- merge(diagnostics, task.wide, by = "task.id", all.x = TRUE)

diagnostics$failure.class <- "moderate_or_geometry_specific"
diagnostics$failure.class[diagnostics$outer.rmse.ratio <= 1.15] <- "near_oracle"
diagnostics$failure.class[diagnostics$outer.rmse.ratio > 1.15 &
                              diagnostics$outer.rmse.ratio <= 1.25] <- "acceptable_gap"
diagnostics$failure.class[diagnostics$outer.rmse.ratio > 1.25 &
                              diagnostics$outer.rmse.ratio <= 1.50] <- "watch_gap"
diagnostics$failure.class[diagnostics$outer.rmse.ratio > 1.50] <- "large_selection_gap"
diagnostics$failure.class[!diagnostics$selected.replay.present] <- "outside_reference_grid"
diagnostics$failure.class[diagnostics$strategy == "sparse_kd" &
                              diagnostics$outer.rmse.ratio > 1.50 &
                              is.finite(diagnostics$ratio.full_kd) &
                              diagnostics$ratio.full_kd <= 1.15] <- "sparse_grid_miss"
diagnostics$failure.class[diagnostics$strategy == "full_kd" &
                              diagnostics$outer.rmse.ratio > 1.50] <- "full_grid_selection_miss"
boundary.large.idx <- diagnostics$outer.rmse.ratio > 1.50 &
    (diagnostics$selected.on.k.boundary | diagnostics$selected.on.d.boundary)
boundary.large.idx[is.na(boundary.large.idx)] <- FALSE
replace.idx <- boundary.large.idx &
    !(diagnostics$failure.class %in% c("sparse_grid_miss",
                                       "full_grid_selection_miss"))
diagnostics$failure.class[replace.idx] <- "boundary_large_gap"

diagnostics <- diagnostics[order(-diagnostics$outer.rmse.ratio,
                                 diagnostics$strategy), ]
utils::write.csv(diagnostics,
                 file.path(tab.dir, "csd7_row_level_failure_diagnostics.csv"),
                 row.names = FALSE)

class.summary <- as.data.frame.matrix(table(diagnostics$strategy,
                                            diagnostics$failure.class))
class.summary$strategy <- rownames(class.summary)
rownames(class.summary) <- NULL
class.summary <- class.summary[, c("strategy",
                                   setdiff(names(class.summary), "strategy"))]
utils::write.csv(class.summary,
                 file.path(tab.dir, "csd7_failure_class_summary.csv"),
                 row.names = FALSE)

family.summary <- aggregate(cbind(outer.rmse.ratio,
                                  outer.relative.regret.percent,
                                  support.distance.to.reference,
                                  chart.dim.distance.to.reference) ~
                                strategy + dataset.family,
                            data = diagnostics[diagnostics$status == "ok", ],
                            FUN = function(x) stats::median(x[is.finite(x)]))
names(family.summary) <- c("strategy", "dataset.family", "median.rmse.ratio",
                           "median.relative.regret.percent",
                           "median.k.distance", "median.d.distance")
utils::write.csv(family.summary,
                 file.path(tab.dir, "csd7_family_failure_summary.csv"),
                 row.names = FALSE)

task.summary <- aggregate(cbind(outer.rmse.ratio,
                                outer.relative.regret.percent) ~
                              task.id + dataset.id + dataset.family,
                          data = diagnostics[diagnostics$status == "ok", ],
                          FUN = max)
names(task.summary)[names(task.summary) == "outer.rmse.ratio"] <- "max.rmse.ratio"
names(task.summary)[names(task.summary) == "outer.relative.regret.percent"] <-
    "max.relative.regret.percent"
task.summary <- merge(task.summary, near.counts, by = "task.id", all.x = TRUE)
task.summary <- task.summary[order(-task.summary$max.rmse.ratio), ]
utils::write.csv(task.summary,
                 file.path(tab.dir, "csd7_task_level_summary.csv"),
                 row.names = FALSE)

top.rows <- diagnostics[diagnostics$status == "ok" &
                            diagnostics$outer.rmse.ratio > 1.50,
                        c("dataset.id", "dataset.family", "repetition",
                          "outer.fold", "strategy", "outer.rmse",
                          "oracle.rmse", "outer.rmse.ratio",
                          "outer.relative.regret.percent",
                          "selected.support.size.int",
                          "selected.chart.dim.int", "oracle.k", "oracle.d",
                          "near.115", "near.125", "failure.class")]
top.rows <- head(top.rows[order(-top.rows$outer.rmse.ratio), ], 16L)
names(top.rows) <- c("dataset", "family", "rep", "fold", "strategy",
                     "R_m", "R_star", "R_ratio", "Delta_rel_pct",
                     "k_sel", "d_sel", "k_star", "d_star",
                     "near_1.15_count", "near_1.25_count", "class")
utils::write.csv(top.rows,
                 file.path(tab.dir, "csd7_top_large_gap_rows.csv"),
                 row.names = FALSE)

meta <- data.frame(
    key = c("report.generated.at", "source.path", "command",
            "working.directory", "input.result.dir", "input.result.timestamp",
            "input.strategy.rows", "input.full.grid.rows",
            "diagnostic.note"),
    value = c(format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
              "~/current_projects/geosmooth/dev/methods/lps/ci/csd7_task_failure_diagnostics_render.R",
              paste("Rscript dev/methods/lps/ci/csd7_task_failure_diagnostics_render.R",
                    "--input-dir=", input.root, sep = ""),
              "~/current_projects/geosmooth",
              sub(normalizePath(path.expand("~")), "~", input.root, fixed = TRUE),
              metadata$value[metadata$key == "result.generated.at"] %||% "not recorded",
              as.character(nrow(scores)),
              as.character(nrow(refs)),
              "CSD7 is a post-processing diagnostic over CSD6 artifacts; it does not rerun fits and does not have full saved inner-CV surfaces."),
    stringsAsFactors = FALSE
)
utils::write.csv(meta, file.path(tab.dir, "csd7_result_metadata.csv"),
                 row.names = FALSE)

make.class.plot <- function() {
    path <- file.path(fig.dir, "figure_1_failure_class_counts.svg")
    cls <- as.data.frame(table(diagnostics$strategy, diagnostics$failure.class),
                         stringsAsFactors = FALSE)
    names(cls) <- c("strategy", "class", "count")
    cls <- cls[cls$count > 0, ]
    cls$strategy <- factor(cls$strategy,
                           levels = c("auto", "local_auto", "sparse_kd",
                                      "full_kd"))
    cls$class <- factor(cls$class,
                        levels = c("near_oracle", "acceptable_gap",
                                   "watch_gap", "large_selection_gap",
                                   "boundary_large_gap", "sparse_grid_miss",
                                   "full_grid_selection_miss",
                                   "outside_reference_grid"))
    cols <- c(near_oracle = "#4DAF4A", acceptable_gap = "#A6D854",
              watch_gap = "#FFD92F", large_selection_gap = "#FC8D62",
              boundary_large_gap = "#E78AC3",
              sparse_grid_miss = "#8DA0CB",
              full_grid_selection_miss = "#E41A1C",
              outside_reference_grid = "#666666")
    write.svg(path, width = 11, height = 8.2, {
        old <- par(mar = c(12, 5, 3, 1), xpd = NA)
        on.exit(par(old), add = TRUE)
        yy <- seq_along(levels(cls$strategy))
        plot(NA, NA, xlim = c(0, max(tapply(cls$count, cls$strategy, sum)) * 1.18),
             ylim = c(0.5, length(yy) + 0.5), yaxt = "n",
             xlab = "Number of outer-task rows", ylab = "",
             main = "Figure 1. Failure-class accounting by selector")
        axis(2, at = yy, labels = levels(cls$strategy), las = 1)
        for (ii in yy) {
            st <- levels(cls$strategy)[ii]
            tmp <- cls[cls$strategy == st, ]
            left <- 0
            for (jj in seq_len(nrow(tmp))) {
                rect(left, ii - 0.28, left + tmp$count[jj], ii + 0.28,
                     col = cols[as.character(tmp$class[jj])], border = "white")
                left <- left + tmp$count[jj]
            }
            text(left + 0.6, ii, labels = left, cex = 0.75, adj = 0)
        }
        legend("bottom", inset = c(0, -0.30), bty = "n", cex = 0.72,
               ncol = 2,
               fill = cols[names(cols)], legend = names(cols))
        grid(col = "#E6E6E6")
    })
    path
}

make.distance.plot <- function() {
    path <- file.path(fig.dir, "figure_2_selected_distance_vs_ratio.svg")
    ok <- diagnostics[diagnostics$status == "ok" &
                          is.finite(diagnostics$outer.rmse.ratio), ]
    ok$kd.distance <- abs(ok$support.distance.to.reference) +
        abs(ok$chart.dim.distance.to.reference)
    cols <- c(auto = "#0072B2", local_auto = "#009E73",
              sparse_kd = "#E69F00", full_kd = "#CC79A7")
    pchs <- c(auto = 16, local_auto = 17, sparse_kd = 15, full_kd = 18)
    write.svg(path, width = 8.8, height = 5.6, {
        old <- par(mar = c(5, 5, 3, 1))
        on.exit(par(old), add = TRUE)
        plot(ok$kd.distance, ok$outer.rmse.ratio, type = "n",
             log = "y", xlab = "|k selected - k*| + |d selected - d*|",
             ylab = "RMSE ratio Rm / R*",
             main = "Figure 2. Selection distance versus RMSE ratio")
        abline(h = c(1.05, 1.15, 1.25, 1.5, 2), lty = 3, col = "#D0D7DB")
        abline(h = 1, lty = 2, col = "#666666")
        for (st in names(cols)) {
            tmp <- ok[ok$strategy == st, ]
            points(tmp$kd.distance, tmp$outer.rmse.ratio,
                   pch = pchs[[st]], col = cols[[st]], cex = 0.9)
        }
        legend("topleft", bty = "n",
               legend = c("auto", "local.auto", "sparse kd", "full kd"),
               pch = pchs[names(cols)], col = cols[names(cols)], cex = 0.85)
        grid(col = "#E6E6E6")
    })
    path
}

make.family.plot <- function() {
    path <- file.path(fig.dir, "figure_3_family_failure_summary.svg")
    fam <- family.summary
    fam <- fam[is.finite(fam$median.rmse.ratio), ]
    family.order <- unique(fam$dataset.family)
    offsets <- c(auto = -0.24, local_auto = -0.08,
                 sparse_kd = 0.08, full_kd = 0.24)
    cols <- c(auto = "#0072B2", local_auto = "#009E73",
              sparse_kd = "#E69F00", full_kd = "#CC79A7")
    pchs <- c(auto = 16, local_auto = 17, sparse_kd = 15, full_kd = 18)
    write.svg(path, width = 12.5, height = 6.2, {
        old <- par(mar = c(5, 16, 3, 1))
        on.exit(par(old), add = TRUE)
        y.base <- seq_along(family.order)
        plot(NA, NA, xlim = c(0.95, max(fam$median.rmse.ratio) * 1.08),
             ylim = c(0.5, length(family.order) + 0.5), log = "x",
             yaxt = "n", xlab = "Median RMSE ratio Rm / R*",
             ylab = "", main = "Figure 3. Family-level median RMSE ratio")
        abline(v = c(1.05, 1.15, 1.25, 1.5, 2), lty = 3, col = "#D0D7DB")
        abline(v = 1, lty = 2, col = "#666666")
        axis(2, at = y.base, labels = family.order, las = 2)
        for (st in names(cols)) {
            tmp <- fam[fam$strategy == st, ]
            yy <- match(tmp$dataset.family, family.order) + offsets[[st]]
            points(tmp$median.rmse.ratio, yy, pch = pchs[[st]],
                   col = cols[[st]], cex = 0.95)
        }
        legend("bottomright", bty = "n",
               legend = c("auto", "local.auto", "sparse kd", "full kd"),
               pch = pchs[names(cols)], col = cols[names(cols)], cex = 0.85)
        grid(col = "#E6E6E6")
    })
    path
}

make.near.tie.plot <- function() {
    path <- file.path(fig.dir, "figure_4_near_oracle_candidate_counts.svg")
    ts <- task.summary
    write.svg(path, width = 8.8, height = 5.5, {
        old <- par(mar = c(5, 5, 3, 1))
        on.exit(par(old), add = TRUE)
        plot(ts$near.115, ts$max.rmse.ratio, pch = 16, col = "#555555",
             log = "y", xlab = "Number of full-grid candidates within 15% of oracle",
             ylab = "Worst selector RMSE ratio in task",
             main = "Figure 4. Near-oracle multiplicity versus worst task gap")
        abline(h = c(1.15, 1.5, 2), lty = 3, col = "#D0D7DB")
        grid(col = "#E6E6E6")
    })
    path
}

make.surface.plot <- function() {
    path <- file.path(fig.dir, "figure_5_large_gap_truth_surfaces.svg")
    worst.tasks <- unique(top.rows$dataset)[seq_len(min(6L, length(unique(top.rows$dataset))))]
    if (!length(worst.tasks)) worst.tasks <- unique(scores$dataset.id)[1L]
    worst.keys <- unique(diagnostics[diagnostics$outer.rmse.ratio > 2,
                                     c("task.id", "dataset.id", "repetition",
                                       "outer.fold")])
    worst.keys <- head(worst.keys[order(match(worst.keys$dataset.id,
                                             unique(top.rows$dataset))), ], 6L)
    if (!nrow(worst.keys)) {
        worst.keys <- head(unique(diagnostics[, c("task.id", "dataset.id",
                                                  "repetition", "outer.fold")]),
                           6L)
    }
    cols <- grDevices::hcl.colors(40, "Viridis", rev = TRUE)
    write.svg(path, width = 12, height = 8.2, {
        old <- par(mfrow = c(2, 3), mar = c(4, 4, 3, 1))
        on.exit(par(old), add = TRUE)
        for (ii in seq_len(nrow(worst.keys))) {
            key <- worst.keys$task.id[ii]
            rr <- refs.ok[refs.ok$task.id == key, ]
            z <- xtabs(outer.rmse ~ chart.dim + support.size, rr)
            image(as.numeric(colnames(z)), as.numeric(rownames(z)), t(z),
                  col = cols, xlab = "k", ylab = "d",
                  main = paste0(worst.keys$dataset.id[ii], "\nrep ",
                                worst.keys$repetition[ii], ", fold ",
                                worst.keys$outer.fold[ii]))
            contour(as.numeric(colnames(z)), as.numeric(rownames(z)), t(z),
                    add = TRUE, drawlabels = FALSE, col = "#FFFFFF99")
            oo <- oracle[oracle$task.id == key, ]
            points(oo$oracle.k, oo$oracle.d, pch = 4, col = "#E41A1C",
                   cex = 1.4, lwd = 2)
            for (st in c("sparse_kd", "full_kd")) {
                ss <- diagnostics[diagnostics$task.id == key &
                                      diagnostics$strategy == st, ]
                if (nrow(ss)) {
                    points(ss$selected.support.size.int,
                           ss$selected.chart.dim.int,
                           pch = if (st == "sparse_kd") 15 else 16,
                           col = if (st == "sparse_kd") "#E69F00" else "#CC79A7",
                           cex = 1.1)
                }
            }
            legend("topright", bty = "n", cex = 0.7,
                   legend = c("oracle", "sparse kd", "full kd"),
                   pch = c(4, 15, 16),
                   col = c("#E41A1C", "#E69F00", "#CC79A7"))
        }
    })
    path
}

fig1 <- make.class.plot()
fig2 <- make.distance.plot()
fig3 <- make.family.plot()
fig4 <- make.near.tie.plot()
fig5 <- make.surface.plot()

run.timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
source.path <- "~/current_projects/geosmooth/dev/methods/lps/ci/csd7_task_failure_diagnostics_render.R"
rel.input <- sub(normalizePath(path.expand("~")), "~", input.root, fixed = TRUE)
rel.report <- sub(normalizePath(path.expand("~")), "~", report.root, fixed = TRUE)
fig.rel <- function(path) file.path("figures", basename(path))
tab.rel <- function(path) file.path("tables", basename(path))
degree.value <- meta.value("degree", "1")
report.title <- if (identical(as.character(degree.value), "2")) {
    "CSD-deg2 CSD7 Task-Level Failure Diagnostics"
} else {
    "CSD7 Task-Level Failure Diagnostics"
}
support.display <- paste0("\\{", paste(support.range, collapse = ",\\ldots,"), "\\}")
dim.display <- paste0("\\{", paste(chart.dim.range, collapse = ",\\ldots,"), "\\}")

class.html <- small.table.html(class.summary, digits = 0L)
family.display <- family.summary[order(family.summary$dataset.family,
                                       family.summary$strategy), ]
family.html <- small.table.html(head(family.display, 32L), digits = 3L)
top.html <- small.table.html(top.rows, digits = 3L)

html <- paste0('<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>', html.escape(report.title), '</title>
<script>
window.MathJax = {tex: {inlineMath: [["\\\\(","\\\\)"],["$","$"]],
displayMath: [["\\\\[","\\\\]"],["$$","$$"]]}};
</script>
<script defer src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js"></script>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
       margin: 0; padding: 0; color: #1f2a2e; background: #f6f7f5; }
main { max-width: 1180px; margin: 0 auto; padding: 28px; }
section { background: #fff; border: 1px solid #d8dfdc; border-radius: 8px;
          padding: 24px; margin: 18px 0; }
h1 { font-size: 34px; margin-bottom: 8px; }
h2 { margin-top: 0; }
.meta { color: #5d6b66; font-size: 14px; line-height: 1.5; }
.callout { border-left: 4px solid #0f766e; padding: 10px 14px;
           background: #eef7f5; margin: 14px 0; }
.warning { border-left: 4px solid #b45309; padding: 10px 14px;
           background: #fff7ed; margin: 14px 0; }
.figure { margin: 20px 0; }
.figure img { width: 100%; height: auto; border: 1px solid #d8dfdc;
              border-radius: 4px; background: #fff; }
.caption { color: #43504b; font-size: 15px; line-height: 1.45; }
table { border-collapse: collapse; width: 100%; margin: 12px 0; font-size: 14px; }
th, td { border: 1px solid #d8dfdc; padding: 7px 9px; vertical-align: top; }
th { background: #edf2f0; text-align: left; }
code { background: #eef2f0; padding: 1px 4px; border-radius: 3px; }
a { color: #0f766e; }
</style>
</head>
<body><main>
<h1>', html.escape(report.title), '</h1>
<div class="meta">
Report build: ', html.escape(run.timestamp), '<br>
Source: <code>', html.escape(source.path), '</code><br>
Input CSD6 bundle: <code>', html.escape(rel.input), '</code><br>
Output bundle: <code>', html.escape(rel.report), '</code>
</div>

<section>
<h2>Purpose</h2>
<p>CSD6 showed that coupled support-size and chart-dimension selection can be
fast, but the selected fits can still be far from the truth-facing full-grid
oracle.  CSD7 asks a narrower diagnostic question: <em>when a selector has high
regret, what kind of miss is it?</em></p>
<p>For each outer task \\(s\\), let \\(R_{s,m}\\) be the Truth RMSE of method
\\(m\\), and let</p>
\\[
  R_s^\\star = \\min_{k\\in ', support.display, ',\\ d\\in ', dim.display, '}
  R_s(k,d)
\\]
<p>be the best Truth RMSE over the full numeric reference grid.  CSD7 reports
the ratio</p>
\\[
  \\kappa_{s,m}=\\frac{R_{s,m}}{R_s^\\star}
\\]
<p>and the relative regret \\(100(\\kappa_{s,m}-1)\\).  Values near \\(1\\) mean the
selected fit is close to the full-grid oracle.  Large values mean the selected
fit is much worse than a candidate that was available in the reference grid.</p>
<div class="warning">
<strong>Important limitation.</strong> CSD7 is a post-processing diagnostic over
the CSD6 artifacts.  CSD6 saved the full truth-facing grid \\(R_s(k,d)\\), but it
did not save the full inner-CV score surface for every candidate.  Therefore
CSD7 can identify outside-reference-grid selections, boundary misses, sparse-grid
misses, and full-grid selection misses against the truth reference.  It cannot
yet prove the detailed shape of the CV surface without a new run that persists
full inner-CV candidate scores.
</div>
</section>

<section>
<h2>Failure Classes</h2>
<p>Each method-task row is assigned one descriptive class.  The thresholds are
diagnostic, not a statistical test: near-oracle means
\\(\\kappa\\le1.15\\), acceptable means \\(1.15&lt;\\kappa\\le1.25\\), watch means
\\(1.25&lt;\\kappa\\le1.5\\), and large gap means \\(\\kappa&gt;1.5\\).  A
<code>sparse_grid_miss</code> means <code>sparse_kd</code> is poor while
<code>full_kd</code> is near-oracle on the same task.  A
<code>full_grid_selection_miss</code> means even the full numeric grid selector
is poor relative to the truth-facing oracle, which points toward selection/CV
instability rather than only sparse-grid coverage.  The
<code>outside_reference_grid</code> class means the selected coordinates could
not be replayed inside the CSD6 numeric reference grid, often because an
automatic dimension rule chose a chart dimension above the reference cap
\\(d=8\\).</p>
', class.html, '
<div class="figure"><img src="', fig.rel(fig1), '" alt="Failure class counts">
<p class="caption"><strong>Figure 1.</strong> Failure-class accounting by
selector.  Each horizontal stack contains the 48 outer-task rows for one
selector.  Green classes are close to the truth-facing full-grid oracle; orange
and red classes mark larger gaps.  The class names are descriptive labels used
to triage where additional selector work should focus.</p></div>
<p>The most important distinction is between sparse-only misses and full-grid
selection misses.  If sparse misses dominate, the sparse grid should be refined.
If full-grid misses dominate, changing the sparse grid alone will not solve the
problem because the larger candidate set is also selecting poorly.</p>
</section>

<section>
<h2>Distance From The Truth-Facing Oracle</h2>
<p>The full-grid oracle has coordinates \\((k_s^\\star,d_s^\\star)\\).  For a
selected method with coordinates \\((\\hat k_{s,m},\\hat d_{s,m})\\), CSD7 plots
the simple coordinate distance</p>
\\[
  D_{s,m}=|\\hat k_{s,m}-k_s^\\star|+|\\hat d_{s,m}-d_s^\\star|.
\\]
<p>This is not a geometry-aware distance between fits; it is only a quick
diagnostic for whether poor fits tend to select far-away candidate coordinates.
If \\(D_{s,m}\\) is small and \\(\\kappa_{s,m}\\) is still large, then the truth
surface is locally steep or unstable near the oracle.  If \\(D_{s,m}\\) is large,
then the selector is moving to a very different part of the grid.</p>
<div class="figure"><img src="', fig.rel(fig2), '" alt="Selection distance versus RMSE ratio">
<p class="caption"><strong>Figure 2.</strong> Selected-coordinate distance
versus RMSE ratio.  The vertical axis is logarithmic because a few tasks have
very large ratios.  Horizontal guide lines mark \\(\\kappa=1.05,1.15,1.25,1.5\\),
and \\(2\\).  Points high above the \\(2\\) line are severe misses; points far to
the right also selected a \\((k,d)\\) pair far from the truth-facing oracle.</p></div>
</section>

<section>
<h2>Geometry Families</h2>
<p>The CSD6 bundle deliberately mixes homogeneous manifolds, high-dimensional
embeddings, non-manifold unions, simplex-boundary geometry, and rank-block
heterogeneity.  Family-level summaries ask whether high regret is concentrated
in only one kind of geometry.</p>
', family.html, '
<div class="figure"><img src="', fig.rel(fig3), '" alt="Family-level median RMSE ratio">
<p class="caption"><strong>Figure 3.</strong> Median RMSE ratio by geometry
family and selector.  Each point is the family-level median \\(\\kappa=R_m/R^\\star\\).
The dashed vertical line is the oracle value \\(\\kappa=1\\); dotted guide lines
mark \\(1.05\\), \\(1.15\\), \\(1.25\\), \\(1.5\\), and \\(2\\).  Families with points
far to the right are the cases driving the largest practical concern.</p></div>
</section>

<section>
<h2>Near-Oracle Multiplicity</h2>
<p>A task may be easy to select if many full-grid candidates are close to the
truth-facing oracle.  CSD7 counts how many candidates satisfy
\\(R_s(k,d)\\le1.15R_s^\\star\\).  A small count means the good region of the
truth surface is narrow; a large count means there are many almost-equivalent
choices.</p>
<div class="figure"><img src="', fig.rel(fig4), '" alt="Near-oracle candidate counts">
<p class="caption"><strong>Figure 4.</strong> Number of near-oracle full-grid
candidates versus the worst selector ratio in the same task.  If severe misses
occur when the near-oracle count is small, then the selection problem is
sharply localized.  If severe misses occur even when the count is large, then
the issue is less about a narrow optimum and more about selection bias or
score mismatch.</p></div>
</section>

<section>
<h2>Large-Gap Truth Surfaces</h2>
<p>The next figure shows representative large-gap tasks.  The heatmap is the
truth-facing full-grid surface \\(R_s(k,d)\\); darker colors are lower Truth RMSE.
The red cross is the full-grid oracle, the orange square is the
<code>sparse_kd</code> selected candidate, and the pink dot is the
<code>full_kd</code> selected candidate.</p>
<div class="figure"><img src="', fig.rel(fig5), '" alt="Large-gap truth surfaces">
<p class="caption"><strong>Figure 5.</strong> Representative large-gap
truth-facing score surfaces.  These panels separate two different problems:
whether the sparse grid even looks in the right region, and whether the full
numeric grid selector chooses a candidate near the truth-facing oracle.  The
figure does not show inner-CV surfaces; it shows only the saved CSD6 truth
reference surface.</p></div>
<p>The table below lists the largest individual gaps.  It is intentionally
short; the full row-level diagnostics are linked in the reproducibility
section.</p>
', top.html, '
</section>

<section>
<h2>What We Learned</h2>
<p>CSD7 changes the next-step question.  The problem is not only sparse-grid
coverage.  Some high-regret rows are sparse-grid misses, but full-grid selection
misses also occur.  That means a larger sparse grid alone is unlikely to close
the gap.  The next useful CSD step should persist candidate-level inner-CV
scores and compare them directly with the truth-facing grid.  That would let us
distinguish a genuinely noisy CV surface from a deterministic rule that is
systematically biased toward the wrong part of the grid.</p>
<p>Until that candidate-level CV surface exists, the safest interpretation is
that coupled \\((k,d)\\) selection is promising but not ready to be treated as a
settled default.  It needs a CV-surface audit and probably a robust selection
rule, such as near-tie handling, one-standard-error-style biasing, repeated CV,
or a staged rule that avoids boundary and narrow-optimum failures.</p>
</section>

<section>
<h2>Reproducibility</h2>
<p>CSD7 was generated from cached CSD6 artifacts and did not rerun any model
fits.</p>
<ul>
<li>Render command: <code>Rscript dev/methods/lps/ci/csd7_task_failure_diagnostics_render.R --input-dir=', html.escape(input.root), '</code></li>
<li>Input strategy scores: <a href="../csd6_expanded_relative_regret_20260708/tables/csd6_strategy_outer_scores.csv">CSD6 strategy outer scores</a></li>
<li>Input full-grid candidate scores: <a href="../csd6_expanded_relative_regret_20260708/tables/csd6_full_grid_candidate_scores.csv">CSD6 full-grid candidate scores</a></li>
<li>Row-level diagnostics: <a href="', tab.rel(file.path(tab.dir, "csd7_row_level_failure_diagnostics.csv")), '">csd7_row_level_failure_diagnostics.csv</a></li>
<li>Failure-class summary: <a href="', tab.rel(file.path(tab.dir, "csd7_failure_class_summary.csv")), '">csd7_failure_class_summary.csv</a></li>
<li>Family summary: <a href="', tab.rel(file.path(tab.dir, "csd7_family_failure_summary.csv")), '">csd7_family_failure_summary.csv</a></li>
<li>Task summary: <a href="', tab.rel(file.path(tab.dir, "csd7_task_level_summary.csv")), '">csd7_task_level_summary.csv</a></li>
<li>Metadata: <a href="', tab.rel(file.path(tab.dir, "csd7_result_metadata.csv")), '">csd7_result_metadata.csv</a></li>
</ul>
</section>

</main></body></html>')

out.path <- file.path(report.root, "csd7_task_failure_diagnostics_report.html")
writeLines(html, out.path)
message("Wrote ", out.path)
