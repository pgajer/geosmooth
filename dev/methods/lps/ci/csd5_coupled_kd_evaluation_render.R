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
report.root <- normalizePath(
    cli$`report-dir` %||% file.path(
        repo.dir, "dev/methods/lps/reports",
        paste0("csd5_coupled_kd_evaluation_", date.tag)
    ),
    mustWork = TRUE
)
fig.dir <- file.path(report.root, "figures")
tab.dir <- file.path(report.root, "tables")
dir.create(fig.dir, recursive = TRUE, showWarnings = FALSE)

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
                     paste0("<th>", html.escape(names(out)), "</th>",
                            collapse = ""),
                     "</tr>")
    rows <- apply(out, 1L, function(row) {
        paste0("<tr>",
               paste0("<td>", html.escape(row), "</td>", collapse = ""),
               "</tr>")
    })
    paste0("<table>", header, paste(rows, collapse = "\n"), "</table>")
}

read.csv.required <- function(name) {
    path <- file.path(tab.dir, name)
    if (!file.exists(path)) stop("Missing required CSD5 table: ", path,
                                 call. = FALSE)
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

bayes.boot.median <- function(x, n.draw = 6000L, seed = 20260708L) {
    x <- as.numeric(x)
    x <- x[is.finite(x)]
    if (!length(x)) return(c(median = NA_real_, lo = NA_real_, hi = NA_real_))
    set.seed(seed)
    draws <- replicate(n.draw, {
        w <- stats::rexp(length(x))
        ord <- order(x)
        xs <- x[ord]
        ws <- w[ord] / sum(w)
        xs[which(cumsum(ws) >= 0.5)[[1L]]]
    })
    c(median = stats::median(draws),
      lo = unname(stats::quantile(draws, 0.025)),
      hi = unname(stats::quantile(draws, 0.975)))
}

scores <- read.csv.required("csd5_strategy_outer_scores.csv")
refs <- read.csv.required("csd5_full_grid_candidate_scores.csv")
summary <- read.csv.required("csd5_strategy_summary.csv")
family.summary <- read.csv.required("csd5_family_strategy_summary.csv")
metadata <- if (file.exists(file.path(tab.dir, "csd5_result_metadata.csv"))) {
    read.csv.required("csd5_result_metadata.csv")
} else {
    data.frame(
        key = c("result.generated.at", "source.path", "command",
                "working.directory"),
        value = c(format(file.info(file.path(tab.dir,
                                             "csd5_strategy_outer_scores.csv"))$mtime,
                         "%Y-%m-%d %H:%M:%S %Z"),
                  "not recorded", "not recorded",
                  "~/current_projects/geosmooth"),
        stringsAsFactors = FALSE
    )
}
if (!file.exists(file.path(tab.dir, "csd5_result_metadata.csv"))) {
    utils::write.csv(metadata, file.path(tab.dir, "csd5_result_metadata.csv"),
                     row.names = FALSE)
}
meta.value <- function(key, default = "not recorded") {
    hit <- metadata$value[metadata$key == key]
    if (length(hit)) hit[[1L]] else default
}

status.table <- as.data.frame.matrix(table(scores$strategy, scores$status))
status.table$strategy <- rownames(status.table)
rownames(status.table) <- NULL
for (nm in c("ok", "error", "timeout", "nonfinite_fit")) {
    if (!nm %in% names(status.table)) status.table[[nm]] <- 0L
}
status.table$attempted <- rowSums(status.table[setdiff(names(status.table),
                                                       "strategy")])
status.table$failed <- status.table$attempted - status.table$ok
status.table <- status.table[, c("strategy", "attempted", "ok", "failed")]

relative.regret.eps <- 1e-12
scores$outer.relative.regret <- scores$outer.regret /
    pmax(scores$reference.outer.rmse, relative.regret.eps)
scores$outer.relative.regret.percent <- 100 * scores$outer.relative.regret

if (!"outer.relative.regret.percent" %in% names(summary)) {
    rel.summary <- aggregate(outer.relative.regret.percent ~ strategy,
                             data = scores[scores$status == "ok", ,
                                           drop = FALSE],
                             FUN = stats::median)
    summary <- merge(summary, rel.summary, by = "strategy", all.x = TRUE)
}

summary.display <- summary
summary.name.map <- c(
    strategy = "strategy",
    outer.rmse = "R_med",
    outer.regret = "Delta_med",
    outer.relative.regret.percent = "Delta_rel_pct_med",
    elapsed.sec = "T_med",
    evaluated.candidates = "cand_med",
    unique.pca.builds = "pca_med",
    n.ok = "n_ok",
    failure.rate = "fail_rate"
)
names(summary.display) <- unname(summary.name.map[names(summary.display)])
summary.display <- summary.display[order(summary.display$Delta_med), ]

make.regret.runtime.plot <- function() {
    path <- file.path(fig.dir, "figure_1_regret_runtime.svg")
    ok <- scores[scores$status == "ok", , drop = FALSE]
    plot.df <- aggregate(cbind(outer.relative.regret.percent, elapsed.sec) ~
                             strategy,
                         data = ok, FUN = stats::median)
    mad.regret <- aggregate(outer.relative.regret.percent ~ strategy,
                            data = ok,
                            FUN = stats::mad)
    mad.time <- aggregate(elapsed.sec ~ strategy, data = ok, FUN = stats::mad)
    plot.df$mad.regret <- mad.regret$outer.relative.regret.percent[
        match(plot.df$strategy, mad.regret$strategy)
    ]
    plot.df$mad.time <- mad.time$elapsed.sec[
        match(plot.df$strategy, mad.time$strategy)
    ]
    point.cols <- c(auto = "#0072B2", local_auto = "#009E73",
                    sparse_kd = "#E69F00", full_kd = "#CC79A7")
    point.pch <- c(auto = 16, local_auto = 17, sparse_kd = 15, full_kd = 18)
    label.map <- c(auto = "auto", local_auto = "local.auto",
                   sparse_kd = "sparse kd", full_kd = "full kd")
    write.svg(path, width = 8.6, height = 5.6, {
        old <- par(mar = c(5, 5, 3, 1))
        on.exit(par(old), add = TRUE)
        x.bounds <- range(c(plot.df$elapsed.sec - plot.df$mad.time,
                            plot.df$elapsed.sec + plot.df$mad.time),
                          finite = TRUE)
        y.lower <- pmax(0, plot.df$outer.relative.regret.percent -
                            plot.df$mad.regret)
        y.upper <- plot.df$outer.relative.regret.percent + plot.df$mad.regret
        y.bounds <- range(c(y.lower, y.upper),
                          finite = TRUE)
        x.pad <- diff(x.bounds) * 0.08
        y.pad <- diff(y.bounds) * 0.10
        plot(plot.df$elapsed.sec, plot.df$outer.relative.regret.percent,
             pch = point.pch[plot.df$strategy], cex = 1.25,
             col = point.cols[plot.df$strategy],
             xlim = x.bounds + c(-x.pad, x.pad),
             ylim = y.bounds + c(-y.pad, y.pad),
             xlab = "Median elapsed seconds per outer fit",
             ylab = "Median relative regret versus reference (%)",
             main = "Figure 1. Runtime versus relative outer regret")
        arrows(plot.df$elapsed.sec - plot.df$mad.time,
               plot.df$outer.relative.regret.percent,
               plot.df$elapsed.sec + plot.df$mad.time,
               plot.df$outer.relative.regret.percent,
               code = 3, angle = 90, length = 0.04,
               col = grDevices::adjustcolor("#B22222", 0.75))
        arrows(plot.df$elapsed.sec, y.lower,
               plot.df$elapsed.sec, y.upper,
               code = 3, angle = 90, length = 0.04,
               col = grDevices::adjustcolor("#B22222", 0.75))
        text(plot.df$elapsed.sec,
             plot.df$outer.relative.regret.percent,
             labels = label.map[plot.df$strategy],
             pos = c(auto = 3, local_auto = 3, sparse_kd = 4, full_kd = 4)[
                 plot.df$strategy
             ],
             cex = 0.78, col = point.cols[plot.df$strategy])
        grid(col = "#E6E6E6")
    })
    path
}

make.selected.kd.plot <- function() {
    path <- file.path(fig.dir, "figure_2_selected_kd.svg")
    ok <- scores[scores$status == "ok" &
                     scores$strategy %in% c("sparse_kd", "full_kd"), ,
                 drop = FALSE]
    cols <- c(sparse_kd = "#E69F00", full_kd = "#0072B2")
    pchs <- c(sparse_kd = 17, full_kd = 16)
    write.svg(path, width = 9, height = 5.8, {
        old <- par(mar = c(5, 5, 3, 1))
        on.exit(par(old), add = TRUE)
        plot(ok$selected.support.size,
             suppressWarnings(as.integer(ok$selected.chart.dim)),
             pch = pchs[ok$strategy], cex = 0.95, col = cols[ok$strategy],
             xlim = c(14, 36), ylim = c(0.5, 8.5),
             xlab = "Selected support size k",
             ylab = "Selected chart dimension d",
             main = "Figure 2. Selected numeric (k,d) over outer tasks")
        legend("bottomright", bty = "n",
               legend = c("sparse kd", "full kd"),
               pch = pchs[names(cols)], col = cols)
        grid(col = "#E6E6E6")
    })
    path
}

make.surface.plot <- function() {
    path <- file.path(fig.dir, "figure_3_example_full_grid_surface.svg")
    first.key <- refs[refs$dataset.id == "curve_1d_embedded_p8" &
                          refs$repetition == 1L &
                          refs$outer.fold == 1L, , drop = FALSE]
    z <- xtabs(outer.rmse ~ chart.dim + support.size, first.key)
    write.svg(path, width = 9, height = 5.8, {
        old <- par(mar = c(5, 5, 3, 1))
        on.exit(par(old), add = TRUE)
        image(as.numeric(colnames(z)), as.numeric(rownames(z)), t(z),
              col = grDevices::hcl.colors(40, "Viridis", rev = TRUE),
              xlab = "support size k", ylab = "chart dimension d",
              main = "Figure 3. Example full-grid outer score surface")
        contour(as.numeric(colnames(z)), as.numeric(rownames(z)), t(z),
                add = TRUE, drawlabels = FALSE, col = "#FFFFFF99")
        best <- first.key[which.min(first.key$outer.rmse), ]
        points(best$support.size, best$chart.dim, pch = 4, cex = 1.5,
               lwd = 2, col = "#D7191C")
    })
    path
}

make.reuse.plot <- function() {
    path <- file.path(fig.dir, "figure_4_reuse_accounting.svg")
    ok <- scores[scores$status == "ok", , drop = FALSE]
    reuse <- aggregate(cbind(evaluated.candidates, unique.pca.builds) ~
                           strategy,
                       data = ok, FUN = stats::median)
    reuse$avoided.pca.builds <- ifelse(
        reuse$strategy %in% c("sparse_kd", "full_kd"),
        pmax(0, reuse$evaluated.candidates - reuse$unique.pca.builds),
        0
    )
    yy <- seq_len(nrow(reuse))
    cols <- c(auto = "#0072B2", local_auto = "#009E73",
              sparse_kd = "#E69F00", full_kd = "#CC79A7")
    write.svg(path, width = 8.6, height = 5.3, {
        old <- par(mar = c(5, 9, 3, 1))
        on.exit(par(old), add = TRUE)
        plot(reuse$evaluated.candidates, yy, pch = 16, yaxt = "n",
             xlab = "Median count per outer fit", ylab = "",
             xlim = c(0, max(reuse$evaluated.candidates) * 1.12),
             main = "Figure 4. Candidate count and PCA-reuse accounting",
             col = cols[reuse$strategy])
        segments(reuse$unique.pca.builds, yy, reuse$evaluated.candidates, yy,
                 col = "#B8BDC7", lwd = 3)
        points(reuse$unique.pca.builds, yy, pch = 21, bg = "white",
               col = cols[reuse$strategy])
        axis(2, at = yy, labels = reuse$strategy, las = 2)
        legend("bottomright", bty = "n",
               legend = c("evaluated candidates", "unique PCA builds",
                          "avoided PCA-build span"),
               pch = c(16, 21, NA), pt.bg = c(NA, "white", NA),
               lty = c(NA, NA, 1), lwd = c(NA, NA, 3),
               col = c("#555555", "#555555", "#B8BDC7"))
        grid(col = "#E6E6E6")
    })
    path
}

make.paired.regret.plot <- function() {
    path <- file.path(fig.dir, "figure_5_paired_regret_intervals.svg")
    ok <- scores[scores$status == "ok", , drop = FALSE]
    strategies <- c("auto", "local_auto", "sparse_kd", "full_kd")
    scale.y <- function(x) log10(1 + pmax(0, x))
    y.ticks.raw <- c(0, 10, 25, 50, 100, 250, 500, 1000, 3000)
    stats <- do.call(rbind, lapply(seq_along(strategies), function(ii) {
        x <- ok$outer.relative.regret.percent[ok$strategy == strategies[[ii]]]
        bb <- bayes.boot.median(x, seed = 20260708L + ii)
        data.frame(strategy = strategies[[ii]], x = ii,
                   median = bb[["median"]], lo = bb[["lo"]],
                   hi = bb[["hi"]],
                   n = length(x),
                   n.equal = sum(abs(x) <= 1e-8, na.rm = TRUE),
                   n.worse = sum(x > 1e-8, na.rm = TRUE),
                   stringsAsFactors = FALSE)
    }))
    write.svg(path, width = 9.2, height = 5.6, {
        old <- par(mar = c(6, 5, 3, 1))
        on.exit(par(old), add = TRUE)
        y.values <- scale.y(c(0, ok$outer.relative.regret.percent,
                              stats$lo, stats$hi))
        plot(seq_along(strategies), rep(0, length(strategies)), type = "n",
             xaxt = "n", xlab = "",
             yaxt = "n",
             ylab = "Relative outer regret versus reference (%)",
             xlim = c(0.45, length(strategies) + 0.55),
             ylim = range(y.values, finite = TRUE),
             main = "Figure 5. Paired relative-regret distribution")
        shown.ticks <- y.ticks.raw[
            scale.y(y.ticks.raw) >= par("usr")[3] &
                scale.y(y.ticks.raw) <= par("usr")[4]
        ]
        axis(2, at = scale.y(shown.ticks), labels = shown.ticks, las = 2)
        abline(h = 0, lty = 2, col = "#666666")
        for (ii in seq_along(strategies)) {
            vals <- ok$outer.relative.regret.percent[
                ok$strategy == strategies[[ii]]
            ]
            set.seed(100 + ii)
            jitter <- stats::runif(length(vals), -0.08, 0.08)
            points(rep(ii, length(vals)) + jitter, scale.y(vals),
                   pch = 16, cex = 0.55,
                   col = grDevices::adjustcolor("#666666", 0.45))
        }
        arrows(stats$x, scale.y(stats$lo), stats$x, scale.y(stats$hi), code = 3,
               angle = 90, length = 0.05, col = "#B22222", lwd = 2)
        points(stats$x, scale.y(stats$median), pch = 16, cex = 1.3,
               col = "#B22222")
        axis(1, at = seq_along(strategies), labels = strategies, las = 2)
        text(stats$x, scale.y(stats$hi),
             labels = paste0(stats$n.equal, " equal / ", stats$n.worse,
                             " worse"),
             pos = 3, cex = 0.62)
        grid(col = "#E6E6E6")
    })
    path
}

fig1 <- make.regret.runtime.plot()
fig2 <- make.selected.kd.plot()
fig3 <- make.surface.plot()
fig4 <- make.reuse.plot()
fig5 <- make.paired.regret.plot()

fig.rel <- function(path) file.path("figures", basename(path))
tab.rel <- function(name) file.path("tables", name)

build.time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
result.time <- meta.value("result.generated.at")
result.bundle <- sub(paste0("^", repo.dir, "/"), "~/current_projects/geosmooth/",
                     report.root)
render.source <- "~/current_projects/geosmooth/dev/methods/lps/ci/csd5_coupled_kd_evaluation_render.R"

html <- paste0(
'<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>CSD5 Coupled Support-Size and Chart-Dimension Evaluation</title>
<script>
window.MathJax = { tex: { inlineMath: [["\\\\(","\\\\)"], ["$","$"]], displayMath: [["\\\\[","\\\\]"], ["$$","$$"]] } };
</script>
<script defer src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js"></script>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 0; background: #f5f7f8; color: #1f2a2e; }
main { max-width: 1180px; margin: 0 auto; padding: 28px; }
section { background: white; border: 1px solid #d9e0e3; border-radius: 10px; padding: 22px; margin: 0 0 20px; }
h1 { font-size: 34px; margin: 0 0 8px; }
h2 { font-size: 23px; margin-top: 0; }
p { line-height: 1.55; }
table { border-collapse: collapse; width: 100%; font-size: 13px; }
th, td { border-bottom: 1px solid #e5eaed; padding: 7px 8px; text-align: left; }
th { background: #eef3f5; }
.meta { color: #5a686d; font-size: 14px; }
.figure { margin: 18px 0; }
.figure img { width: 100%; max-width: 980px; display: block; border: 1px solid #dde5e8; border-radius: 8px; background: #fff; }
.caption { font-size: 14px; color: #344247; margin-top: 8px; }
.callout { border-left: 4px solid #1f766d; padding: 10px 14px; background: #eef8f6; }
code { background: #eef2f4; padding: 1px 4px; border-radius: 4px; }
a { color: #126d73; }
.dict { font-size: 14px; color: #3a494e; }
</style>
</head>
<body>
<main>
<section>
<h1>CSD5 Coupled Support-Size and Chart-Dimension Evaluation</h1>
<p class="meta">Report build: ', html.escape(build.time),
'. Result generation: ', html.escape(result.time),
'. Bundle: <code>', html.escape(result.bundle), '</code>. Render source:
<code>', html.escape(render.source), '</code>.</p>
<p>This focused CSD5 report asks whether a sparse coupled selector over support
size \\(k\\) and chart dimension \\(d\\) can approximate a full Cartesian
reference while reducing candidate count and repeated local-PCA work.  The
report is truth-facing: each strategy is selected using only inner folds on
the outer-training set, then scored on an outer fold that no selector saw.</p>
<p>For an outer task \\(s\\), the reported error for method \\(m\\) is</p>
\\[
R_{s,m}=\\left\\{\\frac{1}{|I_s^{\\mathrm{out}}|}
\\sum_{i\\in I_s^{\\mathrm{out}}}(\\hat f_{s,m}(x_i)-f_i)^2\\right\\}^{1/2},
\\]
<p>where \\(I_s^{\\mathrm{out}}\\) is the held-out outer fold, \\(f_i\\) is the
known synthetic truth, and \\(\\hat f_{s,m}\\) is the fit selected by method
\\(m\\).  The full-grid outer reference is</p>
\\[
R_s^{\\star}=\\min_{(k,d)\\in\\mathcal G_{\\mathrm{full}}} R_{s,(k,d)},
\\qquad
\\Delta_{s,m}=R_{s,m}-R_s^{\\star}.
\\]
<p>Thus positive regret \\(\\Delta_{s,m}\\) means the selected strategy was worse
than the full-grid truth-facing reference on that same outer fold.  Because an
absolute RMSE loss is difficult to interpret without the scale of the task, the
main figures also report percent relative regret</p>
\\[
\\Delta^{\\mathrm{rel}}_{s,m}
=
100\\,
\\frac{R_{s,m}-R_s^{\\star}}{R_s^{\\star}+\\epsilon},
\\qquad \\epsilon=10^{-12}.
\\]
<p>A value of \\(5\\) means that the selected strategy had 5% larger outer RMSE
than the full-grid reference on the same task.  A value of \\(100\\) means twice
the reference RMSE.  The tiny \\(\\epsilon\\) only protects against division by
zero and has no visible effect in this result bundle.</p>
<div class="callout"><strong>Scope.</strong> This first report validates the
LPS implementation path where full Cartesian references are feasible.  PS-LPS
uses the same sparse candidate machinery after CSD4, but its synchronized
full-grid solve reference is intentionally left for a larger runtime study.</div>
</section>

<section>
<h2>Design And Fit Accounting</h2>
<p>The full Cartesian reference universe is
\\(\\mathcal G_{\\mathrm{full}}=\\{15,16,\\ldots,35\\}\\times\\{1,2,\\ldots,8\\}\\),
filtered by \\(q(d,g)+m\\le k\\).  Here \\(g=1\\), \\(q(d,1)=d+1\\), and the design
margin is \\(m=2\\), so every planned candidate is feasible.  The comparison
uses four synthetic geometry families, two repetitions, three matched outer
folds, and identical inner-fold rules for all selectors.</p>
<p class="dict"><strong>Status columns.</strong> <code>attempted</code> is the
number of outer tasks planned for a strategy; <code>ok</code> is the number
that returned a finite selected fit and outer score; <code>failed</code>
combines errors, timeouts, and non-finite fits.  No rows were excluded from the
summary.</p>',
small.table.html(status.table),
'<p>The strategy arms are <code>auto</code> (one global automatic chart
dimension), <code>local_auto</code> (anchor-specific automatic dimensions),
<code>sparse_kd</code> (sparse numeric \\((k,d)\\) skeleton), and
<code>full_kd</code> (full numeric Cartesian selector using inner CV).</p>
</section>

<section>
<h2>Strategy Summary</h2>
<p>This table summarizes successful outer tasks.  \\(R_{\\mathrm{med}}\\) is the
median outer RMSE \\(R_{s,m}\\), \\(\\Delta_{\\mathrm{med}}\\) is the median regret
\\(\\Delta_{s,m}\\), \\(\\Delta^{\\mathrm{rel}}_{\\mathrm{pct,med}}\\) is the median
percent relative regret, \\(T_{\\mathrm{med}}\\) is median end-to-end serial wall
time per outer fit in seconds, <code>cand</code> is the median evaluated candidate
count, and <code>pca</code> is the median number of unique reusable local-PCA
support groups.  Values are medians across 24 matched outer tasks per
strategy.  The absolute and relative regret columns should be read together:
the first gives the raw RMSE loss, and the second says how large that loss is
relative to the task reference error.</p>',
small.table.html(summary.display, digits = 4L),
'<p>Full linked artifacts:
<a href="', tab.rel("csd5_strategy_outer_scores.csv"), '">outer scores</a>,
<a href="', tab.rel("csd5_full_grid_candidate_scores.csv"), '">full-grid candidate scores</a>,
<a href="', tab.rel("csd5_strategy_summary.csv"), '">strategy summary</a>,
<a href="', tab.rel("csd5_family_strategy_summary.csv"), '">family summary</a>,
and <a href="', tab.rel("csd5_result_metadata.csv"), '">metadata</a>.</p>
</section>

<section>
<h2>Runtime And Relative Regret</h2>
<p>This diagnostic asks whether sparse coupled selection reduces time without
moving far from the full-grid outer reference.  The vertical axis is percent
relative regret, so a value of 10 means a 10% larger outer RMSE than the
reference.  The red intervals are median absolute deviations, shown as
descriptive spread rather than inferential confidence intervals.</p>
<div class="figure"><img src="', fig.rel(fig1), '" alt="Runtime versus regret">
<p class="caption"><strong>Figure 1.</strong> Runtime versus percent relative
outer regret.  Each labeled point is a strategy median across matched outer
tasks.  Lower is better on the vertical axis, and farther left is faster.  Red
intervals show median absolute deviations across tasks for runtime and percent
relative regret; lower vertical interval ends are capped at zero because
relative regret is nonnegative.</p></div>
<p>The sparse selector evaluates a much smaller candidate set and is visibly
faster than the full numeric grid in this focused LPS lane.  The median regret
gap between sparse and full numeric selection remains interpretable on the
percent scale: the sparse rule pays a modest relative-error cost for a large
runtime and PCA-build reduction.</p>
</section>

<section>
<h2>Selected Numeric Candidates</h2>
<p>This section asks whether the sparse selector chooses systematically
different support sizes or chart dimensions from the full numeric selector.</p>
<div class="figure"><img src="', fig.rel(fig2), '" alt="Selected support and chart dimension">
<p class="caption"><strong>Figure 2.</strong> Selected numeric \\((k,d)\\) values
for sparse and full numeric selectors over all matched outer tasks.  Horizontal
position is selected support size \\(k\\); vertical position is selected chart
dimension \\(d\\).</p></div>
<p>The plot should be read as a selection-behavior diagnostic, not as a score
plot.  Different selected \\((k,d)\\) values are acceptable when the outer score
surface is flat; they become concerning only when paired regret in Figure 5 is
large.</p>
</section>

<section>
<h2>Reference Surface</h2>
<p>This example shows the full-grid outer target for one held-out task.  It is
included to make the phrase "full-grid reference" concrete: every feasible
numeric pair is scored on the same held-out truth target.</p>
<div class="figure"><img src="', fig.rel(fig3), '" alt="Example full-grid score surface">
<p class="caption"><strong>Figure 3.</strong> Example full-grid outer score
surface for the embedded 1D curve, repetition 1, outer fold 1.  Colors encode
outer truth RMSE; the red cross marks the best feasible \\((k,d)\\) candidate for
that outer task.</p></div>
<p>The score surface is not optimized inner CV.  It is an audit reference
computed after selection, using the known synthetic truth on the outer fold.</p>
</section>

<section>
<h2>PCA-Reuse Accounting</h2>
<p>This diagnostic asks how much local-PCA work is avoided by reuse.  For
numeric grid arms, lower-dimensional chart candidates reuse the
maximum-dimension PCA coordinates within each support/kernel group.</p>
<div class="figure"><img src="', fig.rel(fig4), '" alt="PCA reuse accounting">
<p class="caption"><strong>Figure 4.</strong> Candidate count and PCA-reuse
accounting.  Filled points are median evaluated candidates; open points are
median unique PCA builds.  The connecting segment is the candidate-build span
covered by reuse.  The <code>auto</code> and <code>local_auto</code> arms are
not numeric dimension-grid arms, so they have no avoided-build segment.</p></div>
<p>The sparse numeric selector uses three reusable PCA support groups in this
evaluation, compared with 21 groups for the full numeric grid.  This is the
mechanism behind the runtime reduction seen in Figure 1.</p>
</section>

<section>
<h2>Paired Outer-Regret Comparison</h2>
<p>This paired diagnostic compares every method to the same full-grid outer
oracle on each matched task.  Points are task-level percent relative regrets
\\(\\Delta^{\\mathrm{rel}}_{s,m}\\).  Red points and intervals are
Bayesian-bootstrap medians and 95% credible intervals for the median paired
relative regret.  The label above each method gives the number of tasks tied
with the oracle and the number worse than the oracle, using tolerance
\\(10^{-8}\\) on the absolute regret scale.</p>
<div class="figure"><img src="', fig.rel(fig5), '" alt="Paired regret with Bayesian bootstrap intervals">
<p class="caption"><strong>Figure 5.</strong> Paired percent relative-regret
distribution relative to the full-grid truth-facing reference.  The dashed line
is zero regret; lower values are better, and zero is the best possible value
under this reference definition.  The vertical axis uses a \\(\\log_{10}(1+x)\\)
display transform but labels ticks in ordinary percent units, because the
relative regrets span orders of magnitude.  Percent relative regret makes
large-looking absolute RMSE losses easier to judge against the error scale of
the matched task.</p></div>
<p>The paired view is the main method-comparison evidence.  It shows whether a
strategy has occasional severe misses even when its median summary looks
acceptable.</p>
</section>

<section>
<h2>Family-Level Check</h2>
<p>The linked family summary separates homogeneous manifolds, the heterogeneous
surface--line union, and the simplex-boundary geometry.  This smoke-sized
evaluation suggests that sparse coupled selection is especially competitive on
the heterogeneous and simplex-boundary cells in this run, but this is not yet a
claim about OD density recovery.  OD subject-visit laws require a separate
evaluation with density-facing targets.</p>
</section>

<section>
<h2>What We Learned</h2>
<p>The sparse numeric \\((k,d)\\) selector behaves as intended in this focused
LPS evaluation: it uses far fewer candidate evaluations and reusable PCA
groups than the full numeric grid, while retaining small paired regret on the
outer truth target.  The full numeric selector remains the strongest
truth-facing reference in median regret, but it is slower and evaluates the
entire Cartesian grid.</p>
<p>The evidence is not a default-change decision.  It is a validation that the
CSD sparse-grid machinery is worth carrying into larger PS-LPS and OD-style
experiments, where the full Cartesian grid is often too expensive to run
exhaustively.</p>
</section>

<section>
<h2>Reproducibility</h2>
<p>Working directory: <code>~/current_projects/geosmooth</code>.</p>
<p>Generate result artifacts:</p>
<pre><code>Rscript dev/methods/lps/ci/csd5_coupled_kd_evaluation_run.R</code></pre>
<p>Render this report from existing artifacts:</p>
<pre><code>Rscript dev/methods/lps/ci/csd5_coupled_kd_evaluation_render.R --report-dir=', html.escape(result.bundle), '</code></pre>
<p>The result bundle contains all CSV tables and SVG figures used by this HTML
file.  The main package development gate after report regeneration was
<code>make test</code>.</p>
</section>
</main>
</body>
</html>')

report.path <- file.path(report.root, "csd5_coupled_kd_evaluation_report.html")
writeLines(html, report.path)
message("Wrote ", report.path)
