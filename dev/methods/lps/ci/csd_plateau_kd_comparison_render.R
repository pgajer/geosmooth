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
    file.arg <- "--file="
    script.args <- args[startsWith(args, file.arg)]
    script <- if (length(script.args)) {
        sub(file.arg, "", script.args[[1L]])
    } else {
        getwd()
    }
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
run.root <- cli$`run-dir` %||% file.path(
    repo.dir,
    "dev/methods/lps/runs",
    paste0("csd_plateau_kd_comparison_", date.tag)
)
report.root <- cli$`report-dir` %||% file.path(
    repo.dir,
    "dev/methods/lps/reports",
    paste0("csd_plateau_kd_comparison_", date.tag)
)
fig.dir <- file.path(report.root, "figures")
tab.dir <- file.path(report.root, "tables")
dir.create(fig.dir, recursive = TRUE, showWarnings = FALSE)
dir.create(tab.dir, recursive = TRUE, showWarnings = FALSE)

res.path <- file.path(run.root, "csd_plateau_kd_comparison_results.rds")
if (!file.exists(res.path)) {
    stop("Missing result bundle: ", res.path, call. = FALSE)
}
res <- readRDS(res.path)
scores <- res$scores
predictions <- res$predictions
datasets <- res$datasets

utils::write.csv(scores, file.path(tab.dir, "csd_plateau_kd_scores.csv"),
                 row.names = FALSE)
utils::write.csv(datasets, file.path(tab.dir, "csd_plateau_kd_datasets.csv"),
                 row.names = FALSE)

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

table.html <- function(df, digits = 4L, max.rows = 40L) {
    if (!nrow(df)) return("<p>No rows.</p>")
    if (nrow(df) > max.rows) df <- utils::head(df, max.rows)
    out <- df
    for (nm in names(out)) {
        if (is.numeric(out[[nm]])) out[[nm]] <- fmt(out[[nm]], digits)
    }
    header <- paste0("<tr>",
                     paste0("<th>", html.escape(names(out)), "</th>",
                            collapse = ""),
                     "</tr>")
    body <- apply(out, 1L, function(row) {
        paste0("<tr>",
               paste0("<td>", html.escape(row), "</td>", collapse = ""),
               "</tr>")
    })
    paste0("<table>", header, paste(body, collapse = "\n"), "</table>")
}

write.svg <- function(path, width = 8, height = 5, expr) {
    grDevices::svg(path, width = width, height = height, onefile = TRUE)
    old.par <- par(no.readonly = TRUE)
    on.exit({
        par(old.par)
        grDevices::dev.off()
    }, add = TRUE)
    force(expr)
}

safe.id <- function(x) gsub("[^A-Za-z0-9_]+", "_", x)
fig.rel <- function(path) file.path("figures", basename(path))
tab.rel <- function(name) file.path("tables", name)

method.labels <- c(
    auto = "auto",
    local_auto = "local.auto",
    full_kd = "full_kd",
    plateau_kd = "plateau_kd"
)
method.colors <- c(
    auto = "#0072B2",
    local_auto = "#009E73",
    full_kd = "#CC79A7",
    plateau_kd = "#D55E00"
)

caption.counter <- 0L
caption <- function(text) {
    caption.counter <<- caption.counter + 1L
    paste0("Figure ", caption.counter, ". ", text)
}

finite.range <- function(...) {
    x <- unlist(list(...), use.names = FALSE)
    range(x[is.finite(x)], finite = TRUE)
}

make.summary.plot <- function() {
    path <- file.path(fig.dir, "figure_1_truth_rmse_by_dataset.svg")
    ok <- scores[scores$status == "ok", , drop = FALSE]
    ok$label <- paste(ok$dataset.id, method.labels[ok$method.id], sep = " / ")
    ok <- ok[order(ok$dataset.id, ok$truth.rmse), , drop = FALSE]
    yy <- seq_len(nrow(ok))
    write.svg(path, width = 10.5, height = max(6, 0.28 * nrow(ok) + 1.5), {
        par(mar = c(5, 13, 3, 1))
        plot(ok$truth.rmse, yy, pch = 16,
             col = method.colors[ok$method.id],
             yaxt = "n", xlab = "Truth RMSE",
             ylab = "", main = "Truth RMSE for every fit",
             xlim = c(0, max(ok$truth.rmse, na.rm = TRUE) * 1.08))
        segments(0, yy, ok$truth.rmse, yy, col = "#D4DADD")
        points(ok$truth.rmse, yy, pch = 16,
               col = method.colors[ok$method.id])
        axis(2, at = yy, labels = ok$label, las = 2, cex.axis = 0.72)
        legend("bottomright", bty = "n", legend = method.labels,
               pch = 16, col = method.colors)
        grid(col = "#E8ECEE")
    })
    path
}

palette.values <- function(z, zlim, n = 100L) {
    pal <- grDevices::hcl.colors(n, "Viridis")
    idx <- round((z - zlim[[1L]]) / diff(zlim) * (n - 1L)) + 1L
    idx[!is.finite(idx)] <- 1L
    pal[pmax(1L, pmin(n, idx))]
}

make.1d.plot <- function(dataset.id, method.id) {
    df <- predictions[
        predictions$dataset.id == dataset.id &
            predictions$method.id == method.id,
        ,
        drop = FALSE
    ]
    sc <- scores[scores$dataset.id == dataset.id &
                     scores$method.id == method.id, , drop = FALSE]
    df <- df[order(df$coord.1), , drop = FALSE]
    path <- file.path(fig.dir, paste0("fit_1d_", safe.id(dataset.id), "_",
                                      safe.id(method.id), ".svg"))
    write.svg(path, width = 8.5, height = 4.8, {
        par(mar = c(4.8, 5, 3, 1))
        yr <- finite.range(df$truth, df$estimate, df$observed)
        plot(df$coord.1, df$truth, type = "l", lwd = 2.2, col = "#111111",
             ylim = yr, xlab = "Latent 1D coordinate",
             ylab = "Truth and fitted value",
             main = paste(dataset.id, "/", method.labels[[method.id]]))
        points(df$coord.1, df$observed, pch = 16, cex = 0.45,
               col = grDevices::adjustcolor("#777777", 0.45))
        lines(df$coord.1, df$estimate, lwd = 2.2,
              col = method.colors[[method.id]])
        legend("topright", bty = "n",
               legend = c("truth", "observed noisy response",
                          method.labels[[method.id]]),
               lty = c(1, NA, 1), pch = c(NA, 16, NA),
               lwd = c(2.2, NA, 2.2),
               col = c("#111111", "#777777", method.colors[[method.id]]),
               cex = 0.82)
        txt <- paste0("RMSE=", fmt(sc$truth.rmse[[1L]], 4L),
                      "  k=", sc$selected.support.size[[1L]],
                      "  d=", sc$selected.chart.dim[[1L]])
        mtext(txt, side = 3, line = 0.2, cex = 0.78)
        grid(col = "#E8ECEE")
    })
    path
}

make.2d.plot <- function(dataset.id, method.id) {
    df <- predictions[
        predictions$dataset.id == dataset.id &
            predictions$method.id == method.id,
        ,
        drop = FALSE
    ]
    sc <- scores[scores$dataset.id == dataset.id &
                     scores$method.id == method.id, , drop = FALSE]
    path <- file.path(fig.dir, paste0("fit_2d_", safe.id(dataset.id), "_",
                                      safe.id(method.id), ".svg"))
    zlim <- finite.range(df$truth, df$estimate)
    rlim <- finite.range(df$residual.truth)
    write.svg(path, width = 10.5, height = 4.4, {
        par(mfrow = c(1, 3), mar = c(4.3, 4.3, 3, 1))
        plot(df$coord.1, df$coord.2, pch = 16, cex = 1.35,
             col = palette.values(df$truth, zlim),
             xlab = "Latent/display coordinate 1",
             ylab = "Latent/display coordinate 2",
             main = "Truth")
        grid(col = "#E8ECEE")
        plot(df$coord.1, df$coord.2, pch = 16, cex = 1.35,
             col = palette.values(df$estimate, zlim),
             xlab = "Latent/display coordinate 1",
             ylab = "Latent/display coordinate 2",
             main = paste("Estimate:", method.labels[[method.id]]))
        grid(col = "#E8ECEE")
        res.cols <- grDevices::colorRampPalette(
            c("#2166AC", "#F7F7F7", "#B2182B")
        )(101L)
        rmid <- max(abs(rlim))
        rlim2 <- c(-rmid, rmid)
        ridx <- round((df$residual.truth - rlim2[[1L]]) / diff(rlim2) * 100) + 1
        ridx <- pmax(1L, pmin(101L, ridx))
        plot(df$coord.1, df$coord.2, pch = 16, cex = 1.35,
             col = res.cols[ridx],
             xlab = "Latent/display coordinate 1",
             ylab = "Latent/display coordinate 2",
             main = "Estimate minus truth")
        mtext(paste0("RMSE=", fmt(sc$truth.rmse[[1L]], 4L),
                     "  k=", sc$selected.support.size[[1L]],
                     "  d=", sc$selected.chart.dim[[1L]]),
              side = 3, line = -1.1, cex = 0.72)
        grid(col = "#E8ECEE")
    })
    path
}

fig1 <- make.summary.plot()

all.fit.figures <- list()
for (dataset.id in datasets$dataset.id[datasets$display %in% c("1d", "2d")]) {
    display <- datasets$display[datasets$dataset.id == dataset.id][[1L]]
    for (method.id in res$methods) {
        path <- if (identical(display, "1d")) {
            make.1d.plot(dataset.id, method.id)
        } else {
            make.2d.plot(dataset.id, method.id)
        }
        all.fit.figures[[length(all.fit.figures) + 1L]] <- list(
            dataset.id = dataset.id,
            method.id = method.id,
            display = display,
            path = path
        )
    }
}

score.summary <- scores[, c(
    "dataset.id", "method.id", "status", "truth.rmse", "truth.mae",
    "truth.correlation", "observed.rmse", "selected.support.size",
    "selected.chart.dim", "chart.dim.anchor.min", "chart.dim.anchor.median",
    "chart.dim.anchor.max", "selected.cv.rmse", "elapsed.sec",
    "evaluated.candidates"
)]

highdim.table <- score.summary[
    scores$display == "table",
    ,
    drop = FALSE
]

best.by.dataset <- do.call(rbind, lapply(split(scores, scores$dataset.id),
                                         function(df) {
    ok <- df[df$status == "ok" & is.finite(df$truth.rmse), , drop = FALSE]
    if (!nrow(ok)) return(NULL)
    best <- ok[which.min(ok$truth.rmse), , drop = FALSE]
    data.frame(
        dataset.id = best$dataset.id,
        best.method = best$method.id,
        best.truth.rmse = best$truth.rmse,
        stringsAsFactors = FALSE
    )
}))

fit.status <- as.data.frame.matrix(table(scores$method.id, scores$status))
fit.status$method.id <- rownames(fit.status)
rownames(fit.status) <- NULL
if (!"ok" %in% names(fit.status)) fit.status$ok <- 0L
if (!"error" %in% names(fit.status)) fit.status$error <- 0L
fit.status$attempted <- rowSums(fit.status[
    setdiff(names(fit.status), "method.id")
])
fit.status <- fit.status[, c("method.id", "attempted", "ok", "error"),
                         drop = FALSE]

build.time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
result.time <- res$run.generated.at %||% "unknown"
run.bundle <- sub(paste0("^", repo.dir, "/"), "~/current_projects/geosmooth/",
                  run.root)
report.bundle <- sub(paste0("^", repo.dir, "/"), "~/current_projects/geosmooth/",
                     report.root)
render.source <- "~/current_projects/geosmooth/dev/methods/lps/ci/csd_plateau_kd_comparison_render.R"
run.source <- "~/current_projects/geosmooth/dev/methods/lps/ci/csd_plateau_kd_comparison_run.R"

fig.html <- function(path, cap) {
    paste0(
        '<div class="figure"><img src="', html.escape(fig.rel(path)),
        '" alt="', html.escape(cap), '"><p class="caption">',
        html.escape(cap), '</p></div>'
    )
}

fig1.cap <- caption(
    "Truth RMSE for every method on every dataset. Each row is one full-data synthetic fit; lower values are better. The 1D and 2D rows are expanded in the All Fits gallery below, while higher-dimensional rows are summarized in tables."
)

gallery.html <- paste(vapply(all.fit.figures, function(info) {
    sc <- scores[scores$dataset.id == info$dataset.id &
                     scores$method.id == info$method.id, , drop = FALSE]
    cap <- caption(paste0(
        info$dataset.id, " fitted by ", method.labels[[info$method.id]],
        ". The figure shows the known synthetic truth and the fitted LPS ",
        "estimate. The goodness-of-fit statistics for this panel are ",
        "Truth RMSE = ", fmt(sc$truth.rmse[[1L]], 4L),
        ", Truth MAE = ", fmt(sc$truth.mae[[1L]], 4L),
        ", selected support size k = ", sc$selected.support.size[[1L]],
        ", and selected chart dimension d = ", sc$selected.chart.dim[[1L]],
        "."
    ))
    fig.html(info$path, cap)
}, character(1L)), collapse = "\n")

html <- paste0(
'<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>CSD Plateau-kd Geometry Selector Comparison</title>
<script>
window.MathJax = { tex: { inlineMath: [["\\\\(","\\\\)"], ["$","$"]], displayMath: [["\\\\[","\\\\]"], ["$$","$$"]] } };
</script>
<script defer src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js"></script>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 0; background: #f5f7f8; color: #1f2a2e; }
main { max-width: 1280px; margin: 0 auto; padding: 28px; }
section { background: white; border: 1px solid #d9e0e3; border-radius: 10px; padding: 22px; margin: 0 0 20px; }
h1 { font-size: 34px; margin: 0 0 8px; }
h2 { font-size: 23px; margin-top: 0; }
h3 { font-size: 18px; margin-bottom: 6px; }
p { line-height: 1.55; }
table { border-collapse: collapse; width: 100%; font-size: 13px; }
th, td { border-bottom: 1px solid #e5eaed; padding: 7px 8px; text-align: left; vertical-align: top; }
th { background: #eef3f5; }
.meta { color: #5a686d; font-size: 14px; }
.figure { margin: 18px 0 26px; }
.figure img { width: 100%; max-width: 1120px; display: block; border: 1px solid #dde5e8; border-radius: 8px; background: #fff; }
.caption { font-size: 14px; color: #344247; margin-top: 8px; }
.callout { border-left: 4px solid #1f766d; padding: 10px 14px; background: #eef8f6; }
code { background: #eef2f4; padding: 1px 4px; border-radius: 4px; }
a { color: #126d73; }
.grid2 { display: grid; grid-template-columns: repeat(auto-fit, minmax(420px, 1fr)); gap: 18px; }
</style>
</head>
<body>
<main>
<section>
<h1>CSD Plateau-kd Geometry Selector Comparison</h1>
<p class="meta">Report build: ', html.escape(build.time),
'. Result generation: ', html.escape(result.time),
'. Run bundle: <code>', html.escape(run.bundle),
'</code>. Report bundle: <code>', html.escape(report.bundle),
'</code>. Run source: <code>', html.escape(run.source),
'</code>. Render source: <code>', html.escape(render.source), '</code>.</p>
<p>This report compares four LPS chart-selection policies on the same synthetic
design family used in the recent coupled support-size and chart-dimension
experiments. The new method is <code>plateau_kd</code>, a geometry-only rule
that chooses one support size and one chart dimension from the local PCA
dimension plateau before looking at the response.</p>
<p>The main goodness-of-fit score is the truth RMSE</p>
\\[
R_m = \\left\\{\\frac{1}{n}\\sum_{i=1}^n
\\bigl(\\widehat f_m(x_i)-f_i\\bigr)^2\\right\\}^{1/2},
\\]
<p>where \\(f_i\\) is the known synthetic truth and \\(\\widehat f_m(x_i)\\) is
the fitted value from method \\(m\\). Lower values are better. The figures use
the known synthetic truth field. Some of these CSD examples are signed
regression truths rather than probability densities, so the phrase “truth
density” should be read here as “known truth signal” for those examples.</p>
<div class="callout"><strong>Included dimensions.</strong> The comparison
explicitly includes the 1D synthetic curve examples and the 2D surface examples.
The 1D and 2D examples are shown in full in the All Fits section. Higher
dimensional and non-directly-plottable examples are summarized by tables.</div>
</section>

<section>
<h2>Methods Compared</h2>
<p>All methods use degree-2 local polynomial fits, Gaussian kernels, support
grid \\(k\\in\\{15,16,\\ldots,35\\}\\), and local PCA coordinates. The numeric
\\((k,d)\\) methods use the dimension universe \\(d\\in\\{1,\\ldots,8\\}\\),
with infeasible polynomial designs removed internally.</p>
<p><code>auto</code> estimates one global chart dimension from observed
geometry and then selects support size by the ordinary LPS CV grid.
<code>local.auto</code> estimates an anchor-specific dimension field but still
selects support size by ordinary CV. <code>full_kd</code> evaluates the full
numeric Cartesian grid by inner CV and selects one global \\((k,d)\\).
<code>plateau_kd</code> computes local PCA total-variance dimensions over the
support grid, finds the initial stable dimension plateau, aggregates those
plateau endpoints across representative anchors, and evaluates the resulting
single geometry-selected \\((k,d)\\) candidate.</p>
</section>

<section>
<h2>Run Accounting</h2>
<p>The table lists all datasets used in the run. Each method was attempted once
per dataset on one fixed noisy response realization, and each fit was scored
against the known truth on the same design points. The fit-status table makes
the attempted, successful, and failed counts explicit before any score
interpretation.</p>',
table.html(datasets, digits = 4L, max.rows = 20L),
'<h3>Fit status by method</h3>',
table.html(fit.status, digits = 4L, max.rows = 20L),
'<h3>Best method by dataset</h3>',
table.html(best.by.dataset, digits = 4L, max.rows = 20L),
'</section>

<section>
<h2>Truth RMSE Overview</h2>
<p>This lollipop-style plot avoids color-only interpretation by labeling each
row with both dataset and method. It is a compact overview; the 1D and 2D
fits are shown in detail in the next section.</p>',
fig.html(fig1, fig1.cap),
'<p><strong>Interpretation.</strong> This figure should be read as a descriptive
first comparison, not a final selector verdict. In particular, <code>full_kd</code>
uses response CV over many candidates, while <code>plateau_kd</code> chooses
its pair from geometry only. Large gaps between them identify examples where
response-facing scale choice still matters.</p>
</section>

<section>
<h2>All Fits: Every 1D and 2D Example</h2>
<p>Each panel below is one model-truth comparison for one 1D or 2D dataset. In
1D, the black line is the known truth, gray points are the noisy observations,
and the colored line is the fitted estimate. In 2D, the first panel shows the
truth, the second panel shows the estimate on the same color scale, and the
third panel shows estimate minus truth.</p>',
gallery.html,
'</section>

<section>
<h2>Higher-Dimensional Summary</h2>
<p>The remaining examples are not shown as direct surfaces because their
geometry is three-dimensional, simplex-boundary, or high-dimensional block
structure. The table retains the same goodness-of-fit and selected-parameter
columns used for the plotted examples.</p>',
table.html(highdim.table, digits = 4L, max.rows = 80L),
'</section>

<section>
<h2>What We Learned</h2>
<p>The new <code>plateau_kd</code> rule is now implemented as a true
geometry-only coupled selector. It is much cheaper than <code>full_kd</code>
because it evaluates one selected candidate rather than the full Cartesian
grid, but this report should be used to decide whether that economy loses too
much truth-facing accuracy on particular geometries.</p>
<p>The most important diagnostic is the per-dataset pattern. If
<code>plateau_kd</code> is close to <code>full_kd</code> on the 1D and 2D
examples, that supports the idea that stable local dimension plateaus capture
useful scale information. If it is far away on a specific geometry, the fitted
curves and residual panels identify where a response-CV-selected support size
is still needed.</p>
</section>

<section>
<h2>Reproducibility</h2>
<p>The fit-generation and report-rendering steps are separated. Rerun the fits
with:</p>
<pre>Rscript ', html.escape(run.source), '</pre>
<p>Then regenerate this HTML report from the cached bundle with:</p>
<pre>Rscript ', html.escape(render.source), '</pre>
<p>Primary linked tables:
<a href="', html.escape(tab.rel("csd_plateau_kd_scores.csv")),
'">fit scores CSV</a> and
<a href="', html.escape(tab.rel("csd_plateau_kd_datasets.csv")),
'">dataset manifest CSV</a>.</p>
</section>
</main>
</body>
</html>')

out.path <- file.path(report.root, "csd_plateau_kd_comparison_report.html")
writeLines(html, out.path)
cat("Wrote report to:\n", out.path, "\n")
