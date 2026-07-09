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
        paste0("csd8_candidate_cv_surface_audit_", date.tag)
    ),
    mustWork = TRUE
)
input.csd6 <- normalizePath(
    cli$`csd6-dir` %||% file.path(
        repo.dir, "dev/methods/lps/reports",
        "csd6_expanded_relative_regret_20260708"
    ),
    mustWork = TRUE
)
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

write.svg <- function(path, width = 8, height = 5, expr) {
    grDevices::svg(path, width = width, height = height, onefile = TRUE)
    on.exit(grDevices::dev.off(), add = TRUE)
    force(expr)
}

read.csv.required <- function(path) {
    if (!file.exists(path)) stop("Missing required table: ", path, call. = FALSE)
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

cv <- read.csv.required(file.path(tab.dir, "csd8_candidate_inner_cv_scores.csv"))
truth <- read.csv.required(file.path(input.csd6, "tables",
                                     "csd6_full_grid_candidate_scores.csv"))
csd6.scores <- read.csv.required(file.path(input.csd6, "tables",
                                           "csd6_strategy_outer_scores.csv"))
metadata <- read.csv.required(file.path(tab.dir, "csd8_result_metadata.csv"))

cv$task.id <- paste(cv$dataset.id, cv$repetition, cv$outer.fold, sep = "::")
truth$task.id <- paste(truth$dataset.id, truth$repetition, truth$outer.fold,
                       sep = "::")
truth <- truth[truth$status == "ok" & is.finite(truth$outer.rmse), ,
               drop = FALSE]

joined <- merge(
    cv,
    truth[, c("task.id", "support.size", "chart.dim", "outer.rmse")],
    by = c("task.id", "support.size", "chart.dim"),
    all.x = TRUE
)
joined <- joined[joined$fit.status == "ok" &
                     is.finite(joined$cv.rmse.observed) &
                     is.finite(joined$outer.rmse), , drop = FALSE]
joined$cv.rank <- ave(joined$cv.rmse.observed, joined$task.id,
                      FUN = function(x) rank(x, ties.method = "min"))
joined$truth.rank <- ave(joined$outer.rmse, joined$task.id,
                         FUN = function(x) rank(x, ties.method = "min"))
joined$cv.scaled <- ave(joined$cv.rmse.observed, joined$task.id,
                        FUN = function(x) x / min(x, na.rm = TRUE))
joined$truth.scaled <- ave(joined$outer.rmse, joined$task.id,
                           FUN = function(x) x / min(x, na.rm = TRUE))
joined$rank.diff <- joined$cv.rank - joined$truth.rank
utils::write.csv(joined,
                 file.path(tab.dir, "csd8_joined_cv_truth_surface.csv"),
                 row.names = FALSE)

by.task <- split(joined, joined$task.id)
task.metrics <- do.call(rbind, lapply(by.task, function(dd) {
    cv.winner <- dd[which.min(dd$cv.rmse.observed), ]
    truth.winner <- dd[which.min(dd$outer.rmse), ]
    data.frame(
        task.id = dd$task.id[[1L]],
        dataset.id = dd$dataset.id[[1L]],
        dataset.family = dd$dataset.family[[1L]],
        repetition = dd$repetition[[1L]],
        outer.fold = dd$outer.fold[[1L]],
        n.candidates = nrow(dd),
        cv.winner.k = cv.winner$support.size[[1L]],
        cv.winner.d = cv.winner$chart.dim[[1L]],
        truth.winner.k = truth.winner$support.size[[1L]],
        truth.winner.d = truth.winner$chart.dim[[1L]],
        cv.winner.truth.ratio = cv.winner$truth.scaled[[1L]],
        truth.winner.cv.ratio = truth.winner$cv.scaled[[1L]],
        truth.winner.cv.rank = truth.winner$cv.rank[[1L]],
        cv.truth.rank.spearman = suppressWarnings(stats::cor(
            dd$cv.rmse.observed, dd$outer.rmse, method = "spearman"
        )),
        cv.truth.rank.kendall = suppressWarnings(stats::cor(
            dd$cv.rmse.observed, dd$outer.rmse, method = "kendall"
        )),
        near.cv.01 = sum(dd$cv.scaled <= 1.01),
        near.cv.05 = sum(dd$cv.scaled <= 1.05),
        near.truth.15 = sum(dd$truth.scaled <= 1.15),
        stringsAsFactors = FALSE
    )
}))
task.metrics <- task.metrics[order(-task.metrics$cv.winner.truth.ratio), ]
utils::write.csv(task.metrics,
                 file.path(tab.dir, "csd8_task_cv_truth_alignment.csv"),
                 row.names = FALSE)

family.metrics <- aggregate(
    cbind(cv.winner.truth.ratio, truth.winner.cv.rank,
          cv.truth.rank.spearman, near.cv.05, near.truth.15) ~ dataset.family,
    data = task.metrics,
    FUN = function(x) stats::median(x[is.finite(x)])
)
family.metrics <- family.metrics[order(-family.metrics$cv.winner.truth.ratio), ]
utils::write.csv(family.metrics,
                 file.path(tab.dir, "csd8_family_cv_truth_alignment.csv"),
                 row.names = FALSE)

large.miss <- task.metrics[task.metrics$cv.winner.truth.ratio > 1.5, ]
top.tasks <- head(task.metrics$task.id, 6L)

make.scatter.plot <- function() {
    path <- file.path(fig.dir, "figure_1_cv_truth_alignment_scatter.svg")
    cols <- c("#0072B2AA", "#D55E00AA")
    write.svg(path, width = 8.6, height = 5.6, {
        old <- par(mar = c(5, 5, 3, 1))
        on.exit(par(old), add = TRUE)
        x <- joined$cv.scaled
        y <- joined$truth.scaled
        plot(x, y, log = "xy", pch = 16, cex = 0.55, col = cols[1],
             xlab = "Inner-CV RMSE / task minimum inner-CV RMSE",
             ylab = "Truth RMSE / task oracle Truth RMSE",
             main = "Figure 1. Candidate-level CV versus truth surfaces")
        abline(h = c(1.15, 1.5, 2), v = c(1.01, 1.05, 1.15),
               lty = 3, col = "#D0D7DB")
        grid(col = "#E6E6E6")
    })
    path
}

make.task_ratio_plot <- function() {
    path <- file.path(fig.dir, "figure_2_cv_winner_truth_ratio.svg")
    dd <- task.metrics
    write.svg(path, width = 12.5, height = 6.2, {
        old <- par(mar = c(5, 17, 3, 1))
        on.exit(par(old), add = TRUE)
        fam <- unique(dd$dataset.family)
        y <- seq_along(fam)
        plot(NA, NA, xlim = c(0.95, max(dd$cv.winner.truth.ratio) * 1.08),
             ylim = c(0.5, length(fam) + 0.5), log = "x", yaxt = "n",
             xlab = "Truth RMSE ratio of the inner-CV winner",
             ylab = "", main = "Figure 2. CV winner quality by geometry family")
        axis(2, at = y, labels = fam, las = 2)
        abline(v = c(1.15, 1.5, 2), lty = 3, col = "#D0D7DB")
        abline(v = 1, lty = 2, col = "#666666")
        for (ii in seq_along(fam)) {
            tmp <- dd[dd$dataset.family == fam[ii], ]
            points(tmp$cv.winner.truth.ratio,
                   rep(ii, nrow(tmp)) + seq(-0.22, 0.22, length.out = nrow(tmp)),
                   pch = 16, col = "#0072B2", cex = 0.9)
        }
        grid(col = "#E6E6E6")
    })
    path
}

make_rank_plot <- function() {
    path <- file.path(fig.dir, "figure_3_truth_winner_cv_rank.svg")
    dd <- task.metrics
    write.svg(path, width = 8.6, height = 5.6, {
        old <- par(mar = c(5, 5, 3, 1))
        on.exit(par(old), add = TRUE)
        plot(dd$truth.winner.cv.rank, dd$cv.winner.truth.ratio,
             log = "y", pch = 16, col = "#444444",
             xlab = "CV rank of the truth-oracle candidate",
             ylab = "Truth RMSE ratio of the CV winner",
             main = "Figure 3. Does CV rank the truth winner well?")
        abline(h = c(1.15, 1.5, 2), lty = 3, col = "#D0D7DB")
        grid(col = "#E6E6E6")
    })
    path
}

make_surface_panel <- function() {
    path <- file.path(fig.dir, "figure_4_cv_truth_surface_pairs.svg")
    task.ids <- top.tasks
    cols <- grDevices::hcl.colors(40, "Viridis", rev = TRUE)
    write.svg(path, width = 12, height = 8.6, {
        old <- par(mfrow = c(length(task.ids), 2), mar = c(3, 3, 2.4, 1))
        on.exit(par(old), add = TRUE)
        for (task in task.ids) {
            dd <- joined[joined$task.id == task, ]
            z.cv <- xtabs(cv.scaled ~ chart.dim + support.size, dd)
            z.truth <- xtabs(truth.scaled ~ chart.dim + support.size, dd)
            cv.win <- dd[which.min(dd$cv.rmse.observed), ]
            tr.win <- dd[which.min(dd$outer.rmse), ]
            title.base <- paste0(dd$dataset.id[[1L]], " r", dd$repetition[[1L]],
                                 " f", dd$outer.fold[[1L]])
            image(as.numeric(colnames(z.cv)), as.numeric(rownames(z.cv)),
                  t(z.cv), col = cols, xlab = "k", ylab = "d",
                  main = paste0(title.base, ": CV surface"))
            points(cv.win$support.size, cv.win$chart.dim, pch = 16,
                   col = "#E69F00", cex = 1.2)
            points(tr.win$support.size, tr.win$chart.dim, pch = 4,
                   col = "#E41A1C", cex = 1.4, lwd = 2)
            image(as.numeric(colnames(z.truth)), as.numeric(rownames(z.truth)),
                  t(z.truth), col = cols, xlab = "k", ylab = "d",
                  main = paste0(title.base, ": Truth surface"))
            points(cv.win$support.size, cv.win$chart.dim, pch = 16,
                   col = "#E69F00", cex = 1.2)
            points(tr.win$support.size, tr.win$chart.dim, pch = 4,
                   col = "#E41A1C", cex = 1.4, lwd = 2)
        }
    })
    path
}

fig1 <- make.scatter.plot()
fig2 <- make.task_ratio_plot()
fig3 <- make_rank_plot()
fig4 <- make_surface_panel()

build.time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
source.path <- "~/current_projects/geosmooth/dev/methods/lps/ci/csd8_candidate_cv_surface_audit_render.R"
rel.report <- sub(normalizePath(path.expand("~")), "~", report.root, fixed = TRUE)
rel.csd6 <- sub(normalizePath(path.expand("~")), "~", input.csd6, fixed = TRUE)
fig.rel <- function(path) file.path("figures", basename(path))
tab.rel <- function(path) file.path("tables", basename(path))
summary.display <- data.frame(
    metric = c("outer tasks", "candidate rows", "large CV-winner misses",
               "median CV-winner truth ratio", "median CV rank of truth winner"),
    value = c(length(unique(joined$task.id)), nrow(joined), nrow(large.miss),
              fmt(stats::median(task.metrics$cv.winner.truth.ratio), 4),
              fmt(stats::median(task.metrics$truth.winner.cv.rank), 4))
)
top.display <- head(task.metrics[, c("dataset.id", "dataset.family",
                                     "repetition", "outer.fold",
                                     "cv.winner.k", "cv.winner.d",
                                     "truth.winner.k", "truth.winner.d",
                                     "cv.winner.truth.ratio",
                                     "truth.winner.cv.rank",
                                     "cv.truth.rank.spearman",
                                     "near.cv.05", "near.truth.15")], 12L)

html <- paste0('<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>CSD8 Candidate-Level CV Surface Audit</title>
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
<h1>CSD8 Candidate-Level CV Surface Audit</h1>
<div class="meta">
Report build: ', html.escape(build.time), '<br>
Source: <code>', html.escape(source.path), '</code><br>
CSD8 bundle: <code>', html.escape(rel.report), '</code><br>
CSD6 truth-reference bundle: <code>', html.escape(rel.csd6), '</code>
</div>

<section>
<h2>Purpose</h2>
<p>CSD7 showed that some large gaps are not sparse-grid misses: even the full
numeric \\\\((k,d)\\\\) selector can choose a candidate far from the
truth-facing oracle.  CSD8 adds the missing evidence by saving candidate-level
inner-CV scores and joining them to the CSD6 truth-facing grid.</p>
<p>For each task \\\\(s\\\\) and candidate \\\\((k,d)\\\\), this report compares
the inner-CV score \\\\(\\widehat R^{\\mathrm{CV}}_s(k,d)\\\\) with the
truth-facing score \\\\(R_s(k,d)\\\\).  We use two task-normalized ratios:</p>
\\\\[
  C_s(k,d)=\\frac{\\widehat R^{\\mathrm{CV}}_s(k,d)}
                 {\\min_{k,d}\\widehat R^{\\mathrm{CV}}_s(k,d)},
  \\qquad
  T_s(k,d)=\\frac{R_s(k,d)}{\\min_{k,d}R_s(k,d)}.
\\\\]
<p>If CV is a good selector, candidates with small \\\\(C_s(k,d)\\\\) should also
have small \\\\(T_s(k,d)\\\\).  In particular, the CV winner should have
\\\\(T_s\\\\) close to one, and the truth winner should have a good CV rank.</p>
', small.table.html(summary.display, digits = 4), '
</section>

<section>
<h2>Candidate-Level Alignment</h2>
<p>Every point in the next figure is one candidate from one outer task.  The
x-axis is the candidate CV score relative to the task-best CV score; the y-axis
is the candidate Truth RMSE relative to the task-best Truth RMSE.</p>
<div class="figure"><img src="', fig.rel(fig1), '" alt="Candidate-level CV truth alignment">
<p class="caption"><strong>Figure 1.</strong> Candidate-level CV versus truth
alignment.  Points near the lower-left corner are good under both criteria.
Points near the left but high on the y-axis are dangerous: CV views them as
near-optimal, but truth RMSE is much worse than the oracle.  Both axes are
log-scaled because the disagreement can span orders of magnitude.</p></div>
</section>

<section>
<h2>CV Winner Quality</h2>
<p>The next figure asks a direct selector question: if we choose the candidate
with the smallest inner-CV RMSE, how far is its truth RMSE from the
truth-facing oracle?</p>
<div class="figure"><img src="', fig.rel(fig2), '" alt="CV winner quality by family">
<p class="caption"><strong>Figure 2.</strong> Truth RMSE ratio of the inner-CV
winner by geometry family.  Values near one mean CV selected a candidate close
to the truth-facing oracle.  Values above \\(1.5\\) or \\(2\\) are the cases where
CV itself is the main suspect, because the full numeric grid contained a much
better truth-facing candidate.</p></div>
</section>

<section>
<h2>Does CV Recognize The Truth Winner?</h2>
<p>For each task, the truth winner is the candidate with the smallest
\\\\(R_s(k,d)\\\\).  CSD8 records its rank under the inner-CV score.  A small
rank means CV saw the truth winner as competitive; a large rank means the
truth winner looked bad under CV.</p>
<div class="figure"><img src="', fig.rel(fig3), '" alt="CV rank of truth winner">
<p class="caption"><strong>Figure 3.</strong> CV rank of the truth-oracle
candidate versus the truth ratio of the CV winner.  The most concerning tasks
are in the upper-right: CV selects a poor truth candidate and also ranks the
truth winner poorly.</p></div>
</section>

<section>
<h2>Surface Pairs</h2>
<p>The paired heatmaps show why candidate-level persistence matters.  In each
row, the left panel is the task-normalized CV surface \\(C_s(k,d)\\), and the
right panel is the task-normalized truth surface \\(T_s(k,d)\\).  The orange dot
marks the CV winner; the red cross marks the truth winner.</p>
<div class="figure"><img src="', fig.rel(fig4), '" alt="CV and truth surface pairs">
<p class="caption"><strong>Figure 4.</strong> Representative CV/truth surface
pairs for the largest CSD8 CV-winner misses.  A good selector would place the
orange dot close to the dark region of the truth panel.  Separated orange and
red marks indicate that the CV surface and truth surface disagree about the
best \\\\((k,d)\\\\) region.</p></div>
</section>

<section>
<h2>Largest Task-Level Misses</h2>
<p>The table lists tasks where the CV winner has the largest truth RMSE ratio.
The columns <code>near.cv.05</code> and <code>near.truth.15</code> count how many
candidates are within 5% of the best CV score and within 15% of the truth
oracle, respectively.</p>
', small.table.html(top.display, digits = 4), '
</section>

<section>
<h2>What We Learned</h2>
<p>CSD8 directly tests the hypothesis raised by CSD7.  If the large regret were
only a sparse-grid problem, the full-grid CV winner would usually be close to
the truth-facing oracle.  The saved candidate-level surfaces show whether this
is true task by task.  Large CV-winner truth ratios, high CV ranks for the truth
winner, or low rank correlations all point toward a selection-score mismatch:
the inner-CV surface is not reliably identifying the truth-good region.</p>
<p>The practical next step should be based on these diagnostics.  If most large
misses have many near-tied CV candidates, repeated CV or one-standard-error
selection is natural.  If misses concentrate near boundaries, a boundary-aware
or staged rule is natural.  If CV and truth surfaces are systematically
misaligned in particular geometry families, then the selector needs a
geometry-stratified policy rather than a single global rule.</p>
</section>

<section>
<h2>Reproducibility</h2>
<ul>
<li>CSD8 run command: <code>Rscript dev/methods/lps/ci/csd8_candidate_cv_surface_audit_run.R</code></li>
<li>CSD8 render command: <code>Rscript dev/methods/lps/ci/csd8_candidate_cv_surface_audit_render.R --report-dir=', html.escape(report.root), '</code></li>
<li>Candidate inner-CV scores: <a href="', tab.rel(file.path(tab.dir, "csd8_candidate_inner_cv_scores.csv")), '">csd8_candidate_inner_cv_scores.csv</a></li>
<li>Joined CV/truth surface: <a href="', tab.rel(file.path(tab.dir, "csd8_joined_cv_truth_surface.csv")), '">csd8_joined_cv_truth_surface.csv</a></li>
<li>Task alignment summary: <a href="', tab.rel(file.path(tab.dir, "csd8_task_cv_truth_alignment.csv")), '">csd8_task_cv_truth_alignment.csv</a></li>
<li>Family alignment summary: <a href="', tab.rel(file.path(tab.dir, "csd8_family_cv_truth_alignment.csv")), '">csd8_family_cv_truth_alignment.csv</a></li>
</ul>
</section>

</main></body></html>')

out.path <- file.path(report.root, "csd8_candidate_cv_surface_audit_report.html")
writeLines(html, out.path)
message("Wrote ", out.path)
