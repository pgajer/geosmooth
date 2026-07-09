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
        "csd8_candidate_cv_surface_audit_20260708"
    ),
    mustWork = TRUE
)
report.root <- cli$`report-dir` %||% file.path(
    repo.dir, "dev/methods/lps/reports",
    paste0("csd9_robust_cv_selection_policy_audit_", date.tag)
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

bayes.boot.median <- function(x, n.draw = 6000L, seed = 20260709L) {
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

joined <- read.csv.required(file.path(input.root, "tables",
                                      "csd8_joined_cv_truth_surface.csv"))
metadata <- read.csv.required(file.path(input.root, "tables",
                                        "csd8_result_metadata.csv"))
joined <- joined[is.finite(joined$cv.scaled) & is.finite(joined$truth.scaled), ,
                 drop = FALSE]
joined$task.id <- paste(joined$dataset.id, joined$repetition, joined$outer.fold,
                        sep = "::")
joined$on.boundary <- joined$support.size %in% c(15L, 35L) |
    joined$chart.dim %in% c(1L, 8L)
joined$mid.k.distance <- abs(joined$support.size - 25L)

order.pick <- function(dd, ord.expr) {
    dd[do.call(order, ord.expr(dd)), ][1L, , drop = FALSE]
}

pick.policy <- function(dd, policy) {
    dd <- dd[is.finite(dd$cv.scaled) & is.finite(dd$truth.scaled), ,
             drop = FALSE]
    if (policy == "cv_min") {
        return(order.pick(dd, function(x) list(x$cv.scaled,
                                               x$mid.k.distance,
                                               x$chart.dim)))
    }
    if (policy == "eps01_low_d_mid_k") {
        cand <- dd[dd$cv.scaled <= 1.01, , drop = FALSE]
        if (any(!cand$on.boundary)) cand <- cand[!cand$on.boundary, ]
        return(order.pick(cand, function(x) list(x$chart.dim,
                                                 x$mid.k.distance,
                                                 x$cv.scaled)))
    }
    if (policy == "eps03_low_d_mid_k") {
        cand <- dd[dd$cv.scaled <= 1.03, , drop = FALSE]
        if (any(!cand$on.boundary)) cand <- cand[!cand$on.boundary, ]
        return(order.pick(cand, function(x) list(x$chart.dim,
                                                 x$mid.k.distance,
                                                 x$cv.scaled)))
    }
    if (policy == "eps05_low_d_mid_k") {
        cand <- dd[dd$cv.scaled <= 1.05, , drop = FALSE]
        if (any(!cand$on.boundary)) cand <- cand[!cand$on.boundary, ]
        return(order.pick(cand, function(x) list(x$chart.dim,
                                                 x$mid.k.distance,
                                                 x$cv.scaled)))
    }
    if (policy == "eps03_large_k_low_d") {
        cand <- dd[dd$cv.scaled <= 1.03, , drop = FALSE]
        if (any(!cand$on.boundary)) cand <- cand[!cand$on.boundary, ]
        return(order.pick(cand, function(x) list(-x$support.size,
                                                 x$chart.dim,
                                                 x$cv.scaled)))
    }
    if (policy == "penalty_boundary_mid_k") {
        dd$policy.score <- dd$cv.scaled +
            0.030 * as.numeric(dd$on.boundary) +
            0.002 * dd$mid.k.distance
        return(order.pick(dd, function(x) list(x$policy.score,
                                               x$cv.scaled,
                                               x$chart.dim)))
    }
    if (policy == "penalty_low_d") {
        dd$policy.score <- dd$cv.scaled +
            0.030 * as.numeric(dd$on.boundary) +
            0.006 * dd$chart.dim
        return(order.pick(dd, function(x) list(x$policy.score,
                                               x$cv.scaled,
                                               x$mid.k.distance)))
    }
    stop("unknown policy: ", policy, call. = FALSE)
}

policy.info <- data.frame(
    policy = c("cv_min", "eps01_low_d_mid_k", "eps03_low_d_mid_k",
               "eps05_low_d_mid_k", "eps03_large_k_low_d",
               "penalty_boundary_mid_k", "penalty_low_d"),
    short.label = c("CV min", "1% low-d", "3% low-d", "5% low-d",
                    "3% large-k", "boundary penalty", "low-d penalty"),
    description = c(
        "Exact inner-CV minimum; current full-grid selector.",
        "Within 1% of CV minimum, prefer non-boundary, then smaller d, then k closest to 25.",
        "Within 3% of CV minimum, prefer non-boundary, then smaller d, then k closest to 25.",
        "Within 5% of CV minimum, prefer non-boundary, then smaller d, then k closest to 25.",
        "Within 3% of CV minimum, prefer non-boundary, then larger support size, then smaller d.",
        "Minimize CV ratio plus a small boundary and mid-k penalty.",
        "Minimize CV ratio plus a small boundary and chart-dimension penalty."
    ),
    stringsAsFactors = FALSE
)

task.split <- split(joined, joined$task.id)
policy.rows <- list()
idx <- 1L
for (task in names(task.split)) {
    dd <- task.split[[task]]
    for (policy in policy.info$policy) {
        sel <- pick.policy(dd, policy)
        policy.rows[[idx]] <- data.frame(
            task.id = task,
            dataset.id = sel$dataset.id[[1L]],
            dataset.family = sel$dataset.family[[1L]],
            repetition = sel$repetition[[1L]],
            outer.fold = sel$outer.fold[[1L]],
            policy = policy,
            support.size = sel$support.size[[1L]],
            chart.dim = sel$chart.dim[[1L]],
            cv.scaled = sel$cv.scaled[[1L]],
            truth.scaled = sel$truth.scaled[[1L]],
            cv.rank = sel$cv.rank[[1L]],
            truth.rank = sel$truth.rank[[1L]],
            on.boundary = sel$on.boundary[[1L]],
            stringsAsFactors = FALSE
        )
        idx <- idx + 1L
    }
}
selection <- do.call(rbind, policy.rows)
selection <- merge(selection, policy.info[, c("policy", "short.label")],
                   by = "policy", all.x = TRUE)
ref <- selection[selection$policy == "cv_min",
                 c("task.id", "truth.scaled")]
names(ref)[2L] <- "cv_min.truth.scaled"
selection <- merge(selection, ref, by = "task.id", all.x = TRUE)
selection$delta.vs.cv.min <- selection$truth.scaled -
    selection$cv_min.truth.scaled
selection$improved.vs.cv.min <- selection$delta.vs.cv.min < 0
utils::write.csv(selection,
                 file.path(tab.dir, "csd9_policy_replay_selections.csv"),
                 row.names = FALSE)

summarize.policy <- function(dd) {
    data.frame(
        n.tasks = nrow(dd),
        median.truth.ratio = stats::median(dd$truth.scaled),
        median.delta.vs.cv.min = stats::median(dd$delta.vs.cv.min),
        n.better.vs.cv.min = sum(dd$delta.vs.cv.min < 0),
        n.worse.vs.cv.min = sum(dd$delta.vs.cv.min > 0),
        n.ratio.gt.1.15 = sum(dd$truth.scaled > 1.15),
        n.ratio.gt.1.50 = sum(dd$truth.scaled > 1.50),
        n.ratio.gt.2.00 = sum(dd$truth.scaled > 2.00),
        boundary.rate = mean(dd$on.boundary),
        median.cv.ratio = stats::median(dd$cv.scaled),
        median.k = stats::median(dd$support.size),
        median.d = stats::median(dd$chart.dim)
    )
}
summary <- do.call(rbind, lapply(split(selection, selection$policy),
                                 summarize.policy))
summary$policy <- rownames(summary)
rownames(summary) <- NULL
summary <- merge(summary, policy.info, by = "policy", all.x = TRUE)
summary <- summary[order(summary$median.truth.ratio,
                         summary$n.ratio.gt.1.50,
                         summary$boundary.rate), ]
utils::write.csv(summary, file.path(tab.dir, "csd9_policy_summary.csv"),
                 row.names = FALSE)

bb.rows <- list()
idx <- 1L
for (policy in setdiff(policy.info$policy, "cv_min")) {
    dd <- selection[selection$policy == policy, ]
    bb <- bayes.boot.median(dd$delta.vs.cv.min,
                            seed = 20260709L + idx)
    bb.rows[[idx]] <- data.frame(
        policy = policy,
        median.delta = bb[["median"]],
        lo = bb[["lo"]],
        hi = bb[["hi"]],
        n.better = sum(dd$delta.vs.cv.min < 0),
        n.total = nrow(dd),
        stringsAsFactors = FALSE
    )
    idx <- idx + 1L
}
bb.summary <- do.call(rbind, bb.rows)
bb.summary <- merge(bb.summary, policy.info[, c("policy", "short.label")],
                    by = "policy", all.x = TRUE)
utils::write.csv(bb.summary,
                 file.path(tab.dir, "csd9_policy_delta_bayes_bootstrap.csv"),
                 row.names = FALSE)

family.summary <- aggregate(
    truth.scaled ~ policy + short.label + dataset.family,
    data = selection,
    FUN = stats::median
)
names(family.summary)[names(family.summary) == "truth.scaled"] <-
    "median.truth.ratio"
utils::write.csv(family.summary,
                 file.path(tab.dir, "csd9_policy_family_summary.csv"),
                 row.names = FALSE)

make.delta.plot <- function() {
    path <- file.path(fig.dir, "figure_1_policy_delta_vs_cv_min.svg")
    order.policy <- summary$policy[summary$policy != "cv_min"]
    dd <- selection[selection$policy %in% order.policy, ]
    dd$x <- match(dd$policy, order.policy)
    bb <- bb.summary[match(order.policy, bb.summary$policy), ]
    write.svg(path, width = 10.5, height = 6.2, {
        old <- par(mar = c(8, 5, 3, 1))
        on.exit(par(old), add = TRUE)
        plot(jitter(dd$x, amount = 0.08), dd$delta.vs.cv.min,
             pch = 16, col = "#B8B8B8", xaxt = "n",
             xlab = "", ylab = "Truth RMSE ratio delta versus CV minimum",
             main = "Figure 1. Paired policy deltas versus exact CV minimum")
        abline(h = 0, lty = 2, col = "#666666")
        segments(seq_along(order.policy), bb$lo, seq_along(order.policy),
                 bb$hi, col = "#B22222", lwd = 2)
        points(seq_along(order.policy), bb$median.delta,
               pch = 16, col = "#B22222", cex = 1.2)
        axis(1, at = seq_along(order.policy),
             labels = policy.info$short.label[match(order.policy,
                                                    policy.info$policy)],
             las = 2)
        text(seq_along(order.policy), par("usr")[4],
             labels = paste0(bb$n.better, "/", bb$n.total, " better"),
             pos = 3, cex = 0.72, xpd = NA)
        grid(col = "#E6E6E6")
    })
    path
}

make.summary.plot <- function() {
    path <- file.path(fig.dir, "figure_2_policy_ratio_and_miss_counts.svg")
    ss <- summary
    ss$x <- seq_len(nrow(ss))
    write.svg(path, width = 10.5, height = 6.2, {
        old <- par(mar = c(8, 5, 3, 5))
        on.exit(par(old), add = TRUE)
        plot(ss$x, ss$median.truth.ratio, pch = 16, col = "#0072B2",
             ylim = c(0.95, max(ss$median.truth.ratio) * 1.08),
             xaxt = "n", xlab = "",
             ylab = "Median selected Truth RMSE ratio",
             main = "Figure 2. Policy accuracy and severe-miss count")
        axis(1, at = ss$x, labels = ss$short.label, las = 2)
        abline(h = c(1.15, 1.5, 2), lty = 3, col = "#D0D7DB")
        par(new = TRUE)
        plot(ss$x, ss$n.ratio.gt.1.50, type = "b", pch = 17,
             col = "#D55E00", axes = FALSE, xlab = "", ylab = "",
             ylim = c(0, max(ss$n.ratio.gt.1.50) * 1.2))
        axis(4, col = "#D55E00", col.axis = "#D55E00")
        mtext("Tasks with ratio > 1.5", side = 4, line = 3,
              col = "#D55E00")
        legend("topleft", bty = "n",
               legend = c("median truth ratio", "count ratio > 1.5"),
               pch = c(16, 17), col = c("#0072B2", "#D55E00"))
        grid(col = "#E6E6E6")
    })
    path
}

make.family_plot <- function() {
    path <- file.path(fig.dir, "figure_3_family_policy_heatmap.svg")
    fam <- family.summary
    keep.policy <- summary$policy
    fam <- fam[fam$policy %in% keep.policy, ]
    fam$policy <- factor(fam$policy, levels = keep.policy)
    family.order <- unique(fam$dataset.family)
    z <- xtabs(median.truth.ratio ~ dataset.family + policy, fam)
    z <- z[family.order, keep.policy, drop = FALSE]
    cols <- grDevices::hcl.colors(40, "Viridis", rev = TRUE)
    z.range <- range(z, finite = TRUE)
    write.svg(path, width = 12.5, height = 6.8, {
        old <- par(no.readonly = TRUE)
        on.exit(par(old), add = TRUE)
        layout(matrix(c(1, 2), nrow = 1), widths = c(10, 1.1))
        par(mar = c(9, 15, 3, 1))
        image(seq_len(ncol(z)), seq_len(nrow(z)), t(z[nrow(z):1, ]),
              col = cols, xaxt = "n", yaxt = "n", xlab = "",
              ylab = "", main = "Figure 3. Median truth ratio by family and policy")
        axis(1, at = seq_len(ncol(z)),
             labels = policy.info$short.label[match(colnames(z),
                                                    policy.info$policy)],
             las = 2)
        axis(2, at = seq_len(nrow(z)),
             labels = rev(rownames(z)), las = 2)
        for (ii in seq_len(nrow(z))) {
            for (jj in seq_len(ncol(z))) {
                val <- z[nrow(z) - ii + 1L, jj]
                text(jj, ii, labels = fmt(val, 3), cex = 0.7)
            }
        }
        par(mar = c(9, 1, 3, 4))
        legend.values <- seq(z.range[1], z.range[2], length.out = length(cols))
        image(x = 1, y = legend.values, z = matrix(legend.values, nrow = 1),
              col = cols, xaxt = "n", xlab = "", ylab = "")
        axis(4, las = 1)
        mtext("Median truth ratio", side = 4, line = 2.5)
        box()
    })
    path
}

make_boundary_plot <- function() {
    path <- file.path(fig.dir, "figure_4_boundary_rate_vs_misses.svg")
    ss <- summary
    ss$plot.id <- seq_len(nrow(ss))
    grouped <- aggregate(
        plot.id ~ boundary.rate + n.ratio.gt.1.50,
        data = ss,
        FUN = function(x) paste(x, collapse = ",")
    )
    write.svg(path, width = 8.5, height = 5.8, {
        old <- par(mar = c(5, 5, 3, 1))
        on.exit(par(old), add = TRUE)
        y.lim <- range(ss$n.ratio.gt.1.50)
        y.lim <- y.lim + c(-0.2, 0.45)
        plot(ss$boundary.rate, ss$n.ratio.gt.1.50, type = "n",
             ylim = y.lim,
             xlab = "Boundary-selection rate",
             ylab = "Tasks with selected Truth RMSE ratio > 1.5",
             main = "Figure 4. Boundary use versus severe misses")
        points(ss$boundary.rate, ss$n.ratio.gt.1.50, pch = 16,
               col = "#0072B2", cex = 1.1)
        text(grouped$boundary.rate, grouped$n.ratio.gt.1.50,
             labels = grouped$plot.id, pos = 3, cex = 0.8)
        grid(col = "#E6E6E6")
        legend("topright", bty = "n", cex = 0.72,
               title = "Policy labels",
               legend = paste0(ss$plot.id, ". ", ss$short.label))
    })
    path
}

fig1 <- make.delta.plot()
fig2 <- make.summary.plot()
fig3 <- make.family_plot()
fig4 <- make_boundary_plot()

run.timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
source.path <- "~/current_projects/geosmooth/dev/methods/lps/ci/csd9_robust_cv_selection_policy_audit_render.R"
rel.input <- sub(normalizePath(path.expand("~")), "~", input.root, fixed = TRUE)
rel.report <- sub(normalizePath(path.expand("~")), "~", report.root, fixed = TRUE)
fig.rel <- function(path) file.path("figures", basename(path))
tab.rel <- function(path) file.path("tables", basename(path))

best.policy <- summary$policy[[1L]]
best.label <- summary$short.label[[1L]]
cv.row <- summary[summary$policy == "cv_min", ]
best.row <- summary[summary$policy == best.policy, ]
policy.display <- summary[, c("short.label", "median.truth.ratio",
                              "median.delta.vs.cv.min",
                              "n.better.vs.cv.min", "n.worse.vs.cv.min",
                              "n.ratio.gt.1.50", "n.ratio.gt.2.00",
                              "boundary.rate", "median.cv.ratio",
                              "median.k", "median.d")]
names(policy.display) <- c("policy", "median_ratio", "median_delta",
                           "n_better", "n_worse", "n_gt_1.5", "n_gt_2",
                           "boundary_rate", "median_cv_ratio",
                           "median_k", "median_d")

html <- paste0('<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>CSD9 Robust CV Selection Policy Audit</title>
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
<h1>CSD9 Robust CV Selection Policy Audit</h1>
<div class="meta">
Report build: ', html.escape(run.timestamp), '<br>
Source: <code>', html.escape(source.path), '</code><br>
Input CSD8 bundle: <code>', html.escape(rel.input), '</code><br>
Output bundle: <code>', html.escape(rel.report), '</code>
</div>

<section>
<h2>Purpose</h2>
<p>CSD8 showed that the exact inner-CV minimum can select a candidate whose
truth RMSE is much worse than the full-grid truth-facing oracle.  CSD9 asks
whether simple robust replay rules would reduce those misses on the saved CSD8
candidate surfaces, without refitting any models.</p>
<p>For each task \\\\(s\\\\), candidate \\\\((k,d)\\\\), and policy \\\\(p\\\\),
let the selected candidate be \\\\((\\hat k_{s,p},\\hat d_{s,p})\\\\).  The
reported error is the truth ratio</p>
\\\\[
  \\kappa_{s,p}
  =
  \\frac{R_s(\\hat k_{s,p},\\hat d_{s,p})}
       {\\min_{k,d}R_s(k,d)}.
\\\\]
<p>Lower is better and \\\\(\\kappa=1\\\\) is the truth-facing full-grid oracle.
The baseline policy is the exact CV minimum.  Every other policy is an offline
selector that uses only the saved CV surface and simple deterministic tie
preferences.</p>
<div class="warning">
<strong>Scope.</strong> CSD9 is a policy replay.  It is useful for screening
ideas, but it is not a prospective validation run.  A policy that looks good
here should be rerun in a fresh outer-CV or expanded benchmark before becoming
a default.
</div>
</section>

<section>
<h2>Policies Tested</h2>
<p>The table lists the deterministic replay rules.  The \\\\(\\epsilon\\\\)-tie
rules first restrict to candidates satisfying
\\\\(C_s(k,d)\\le 1+\\epsilon\\\\), where \\\\(C_s\\\\) is the candidate CV score
divided by the task-best CV score.  If non-boundary candidates exist inside the
tie set, boundary candidates are removed before applying the stated preference.</p>
', small.table.html(policy.info, digits = 4), '
</section>

<section>
<h2>Policy Summary</h2>
<p>The best offline policy in this CSD9 replay is <code>',
html.escape(best.label), '</code>, with median truth ratio ',
fmt(best.row$median.truth.ratio, 4), '.  The exact CV-minimum baseline has
median truth ratio ', fmt(cv.row$median.truth.ratio, 4), '.  The most important
columns are <code>median_ratio</code>, <code>n_gt_1.5</code>, and
<code>n_gt_2</code>.  The boundary rate records how often the policy selected
\\\\(k=15\\\\), \\\\(k=35\\\\), \\\\(d=1\\\\), or \\\\(d=8\\\\).</p>
', small.table.html(policy.display, digits = 4), '
</section>

<section>
<h2>Paired Delta Against Exact CV Minimum</h2>
<p>The paired delta is
\\\\[
  \\Delta_{s,p}=\\kappa_{s,p}-\\kappa_{s,\\mathrm{CVmin}}.
\\\\]
Negative values mean the robust policy improved over exact CV minimum on that
same task.  The red point and interval are a Bayesian-bootstrap median paired
delta and 95% credible interval.  Several intervals collapse to zero because
many replay policies choose the same candidate as the CV-minimum rule on many
tasks; this is a result of the replay, not a plotting failure.</p>
<div class="figure"><img src="', fig.rel(fig1), '" alt="Paired policy deltas versus CV minimum">
<p class="caption"><strong>Figure 1.</strong> Paired truth-ratio deltas versus
the exact CV-minimum selector.  Gray points are task-level paired deltas.  The
red point and vertical interval summarize the Bayesian-bootstrap median paired
delta.  A label such as <code>12/48 better</code> means the policy improved over
CV minimum on 12 of 48 tasks.</p></div>
</section>

<section>
<h2>Accuracy And Severe Misses</h2>
<p>A useful robust policy should reduce severe misses without merely improving
the median by sacrificing many easy tasks.  Figure 2 shows the median truth
ratio and the number of tasks with \\\\(\\kappa>1.5\\\\).</p>
<div class="figure"><img src="', fig.rel(fig2), '" alt="Policy accuracy and severe miss counts">
<p class="caption"><strong>Figure 2.</strong> Median selected truth ratio and
severe-miss count by policy.  Blue dots show the median \\\\(\\kappa\\\\); orange
triangles show the number of tasks with \\\\(\\kappa>1.5\\\\).  A promising rule
should move both quantities downward.</p></div>
</section>

<section>
<h2>Geometry-Family Stability</h2>
<p>A policy can look good globally while damaging a specific geometry family.
Figure 3 reports median \\\\(\\kappa\\\\) for every policy and family.</p>
<div class="figure"><img src="', fig.rel(fig3), '" alt="Family by policy heatmap">
<p class="caption"><strong>Figure 3.</strong> Median truth ratio by geometry
family and policy.  Each cell is the median \\\\(\\kappa\\\\).  Values close to
one are better.  This figure checks whether a robust policy helps only by
trading one geometry failure mode for another.</p></div>
</section>

<section>
<h2>Boundary Use</h2>
<p>CSD7 suggested that some large gaps involve boundary choices.  Figure 4 asks
whether policies that select boundaries less often also have fewer severe
misses.</p>
<div class="figure"><img src="', fig.rel(fig4), '" alt="Boundary selection rate versus severe misses">
<p class="caption"><strong>Figure 4.</strong> Boundary-selection rate versus
number of severe misses.  Boundary means \\\\(k\\\\) or \\\\(d\\\\) lies at the
edge of the CSD grid.  This is not proof that boundaries cause misses, but it
shows whether boundary avoidance is a plausible ingredient in the next
selector.</p></div>
</section>

<section>
<h2>What We Learned</h2>
<p>CSD9 is a screening step.  If none of the robust replay rules beats exact
CV-minimum selection, then the next work should focus on better scoring, such
as repeated CV with uncertainty, nested score stabilization, or geometry-aware
selection.  If one or more replay rules reduce severe misses without damaging
easy families, the next useful step is a prospective CSD10 rerun using that
policy inside <code>fit.lps()</code> rather than as an offline replay.</p>
<p>Here the strongest replay signal is modest.  The 1% low-d rule has the best
median ratio and one fewer severe miss than exact CV minimum, but most policies
often agree with CV minimum and the paired median deltas are mostly zero.  That
argues for a small prospective validation of the 1% low-d rule, not for an
immediate default change.</p>
<p>The most important caution is that a replay policy can overfit this saved
CSD8 bundle.  The result should guide engineering priorities, not settle the
default policy by itself.</p>
</section>

<section>
<h2>Reproducibility</h2>
<ul>
<li>Render command: <code>Rscript dev/methods/lps/ci/csd9_robust_cv_selection_policy_audit_render.R --input-dir=', html.escape(input.root), '</code></li>
<li>Policy selections: <a href="', tab.rel(file.path(tab.dir, "csd9_policy_replay_selections.csv")), '">csd9_policy_replay_selections.csv</a></li>
<li>Policy summary: <a href="', tab.rel(file.path(tab.dir, "csd9_policy_summary.csv")), '">csd9_policy_summary.csv</a></li>
<li>Bayesian-bootstrap paired deltas: <a href="', tab.rel(file.path(tab.dir, "csd9_policy_delta_bayes_bootstrap.csv")), '">csd9_policy_delta_bayes_bootstrap.csv</a></li>
<li>Family summary: <a href="', tab.rel(file.path(tab.dir, "csd9_policy_family_summary.csv")), '">csd9_policy_family_summary.csv</a></li>
</ul>
</section>

</main></body></html>')

out.path <- file.path(report.root, "csd9_robust_cv_selection_policy_audit_report.html")
writeLines(html, out.path)
message("Wrote ", out.path)
