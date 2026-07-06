#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
arg.value <- function(prefix, default = NULL) {
    hit <- grep(paste0("^", prefix, "="), args, value = TRUE)
    if (!length(hit)) {
        return(default)
    }
    sub(paste0("^", prefix, "="), "", hit[[length(hit)]])
}

script.file <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script.file <- if (length(script.file)) {
    sub("^--file=", "", script.file[[1L]])
} else {
    NA_character_
}
root <- if (!is.na(script.file) && nzchar(script.file)) {
    script.file <- normalizePath(script.file, winslash = "/", mustWork = TRUE)
    normalizePath(file.path(dirname(script.file), ".."),
                  winslash = "/", mustWork = TRUE)
} else {
    normalizePath(".", winslash = "/", mustWork = TRUE)
}
out.dir <- arg.value(
    "--out-dir",
    file.path(root, "dev", "shared", "experiments",
              "od_cv5_all_method_smoke_2026-07-06")
)
out.dir <- normalizePath(out.dir, winslash = "/", mustWork = FALSE)
tables.dir <- file.path(out.dir, "tables")
dir.create(tables.dir, recursive = TRUE, showWarnings = FALSE)

if (!exists("fit.subject.od", mode = "function")) {
    if (!requireNamespace("pkgload", quietly = TRUE)) {
        stop("pkgload is required to run this source-tree smoke benchmark.",
             call. = FALSE)
    }
    pkgload::load_all(root, quiet = TRUE)
}

build.timestamp <- format(
    as.POSIXct(Sys.time(), tz = "America/New_York"),
    "%Y-%m-%d %H:%M:%S %Z"
)

git.commit <- tryCatch(
    system2("git", c("rev-parse", "--short", "HEAD"),
            stdout = TRUE, stderr = FALSE),
    error = function(e) NA_character_
)
git.commit <- if (length(git.commit)) git.commit[[1L]] else NA_character_

make.path.graph <- function(lengths) {
    n <- length(lengths) + 1L
    adj <- vector("list", n)
    wt <- vector("list", n)
    for (i in seq_along(lengths)) {
        j <- i + 1L
        ell <- as.double(lengths[[i]])
        adj[[i]] <- c(adj[[i]], j)
        wt[[i]] <- c(wt[[i]], ell)
        adj[[j]] <- c(adj[[j]], i)
        wt[[j]] <- c(wt[[j]], ell)
    }
    list(
        adj.list = lapply(adj, as.integer),
        weight.list = lapply(wt, as.double)
    )
}

fixture <- local({
    n <- 28L
    t <- seq(-1, 1, length.out = n)
    X <- cbind(t, t^2)
    graph <- make.path.graph(rep(c(1, 1.5, 0.8), length.out = n - 1L))
    subject.index <- c(3L, 4L, 5L, 8L, 8L, 11L, 14L, 17L, 20L, 22L,
                       24L, 26L)
    visit.foldid <- rep(1:4, length.out = length(subject.index))
    list(
        id = "od_cv5_curved_path_fixture",
        n = n,
        X = X,
        graph = graph,
        subject.index = subject.index,
        visit.foldid = visit.foldid
    )
})

common.chart <- list(
    coordinate.method = "local.pca",
    chart.dim.grid = c("1", "auto"),
    auto.chart.support.metric = "both",
    auto.chart.selection.metric = "operator"
)

method.specs <- list(
    graph_random_walk = list(
        method = "graph_random_walk",
        label = "Graph random walk",
        args = list(
            graph.control = list(
                walk.step.grid = c(0L, 1L, 2L),
                affinity.method.grid = c("exp_neg_length_over_median",
                                         "inverse_length"),
                affinity.scale.grid = c(NA_real_, 0.75),
                affinity.epsilon.grid = 1e-8,
                normalize.grid = TRUE
            )
        )
    ),
    chart_kernel = list(
        method = "chart_kernel",
        label = "Chart kernel",
        args = c(
            list(
                support.grid = c(9L, 11L),
                kernel.grid = "gaussian",
                bandwidth.multiplier.grid = c(1, 1.2)
            ),
            common.chart
        )
    ),
    local_likelihood_density = list(
        method = "local_likelihood_density",
        label = "Local likelihood density",
        args = c(
            list(
                support.grid = c(9L, 11L),
                degree.grid = 0:1,
                kernel.grid = "gaussian",
                bandwidth.multiplier.grid = 1,
                lambda.ridge.grid = c(1e-8)
            ),
            common.chart
        )
    ),
    local_likelihood_bernoulli = list(
        method = "local_likelihood_bernoulli",
        label = "Local likelihood Bernoulli",
        args = c(
            list(
                support.grid = c(9L, 11L),
                degree.grid = 0:1,
                kernel.grid = "gaussian",
                bandwidth.multiplier.grid = 1,
                lambda.ridge.grid = c(1e-8),
                optimizer = "newton"
            ),
            common.chart
        )
    ),
    lps_count = list(
        method = "lps_count",
        label = "LPS count",
        args = c(
            list(
                support.grid = c(9L, 11L),
                degree.grid = 0:1,
                kernel.grid = "gaussian",
                bandwidth.multiplier.grid = 1,
                backend = "R",
                design.basis = "orthogonal.polynomial.drop",
                ridge.multiplier.grid = 0,
                ridge.condition.max = Inf
            ),
            common.chart
        )
    ),
    lps_logistic_binary = list(
        method = "lps_logistic_binary",
        label = "LPS Bernoulli",
        args = c(
            list(
                support.grid = c(9L, 11L),
                degree.grid = 0:1,
                kernel.grid = "gaussian",
                bandwidth.multiplier.grid = 1,
                backend = "R",
                design.basis = "orthogonal.polynomial.drop",
                ridge.multiplier.grid = 0,
                ridge.condition.max = Inf
            ),
            common.chart
        )
    ),
    ps_lps_count = list(
        method = "ps_lps_count",
        label = "PS-LPS count",
        args = list(
            support.grid = c(9L, 11L),
            degree.grid = 1L,
            kernel.grid = "gaussian",
            chart.dim.grid = c("1", "auto"),
            auto.chart.support.metric = "both",
            auto.chart.selection.metric = "operator",
            lambda.sync.grid = c(0, 0.1),
            lambda.ridge = 1e-8,
            design.basis = "orthogonal.polynomial.drop",
            ridge.multiplier.grid = c(0, 1e-10),
            ridge.condition.max = 1e10,
            sync.neighbor.size = 3L
        )
    )
)

fit.one <- function(spec) {
    start <- proc.time()
    fit <- tryCatch(
        do.call(
            fit.subject.od,
            c(
                list(
                    X = fixture$X,
                    subject.index = fixture$subject.index,
                    method = spec$method,
                    graph = fixture$graph,
                    od.cv = "visit",
                    visit.foldid = fixture$visit.foldid,
                    od.control = list(smoothness.adj.list =
                                          fixture$graph$adj.list),
                    return.details = TRUE
                ),
                spec$args
            )
        ),
        error = function(e) e
    )
    elapsed <- unname((proc.time() - start)[["elapsed"]])
    if (inherits(fit, "error")) {
        return(list(
            summary = data.frame(
                method = spec$method,
                label = spec$label,
                status = "error",
                elapsed.sec = elapsed,
                n.candidates = NA_integer_,
                n.failed.candidates = NA_integer_,
                selected.candidate.id = NA_integer_,
                visit.cv.neg.log.rho = NA_real_,
                visit.cv.mean.heldout.rho = NA_real_,
                mass = NA_real_,
                max.rho = NA_real_,
                n.local.maxima = NA_integer_,
                selected.summary = NA_character_,
                error.message = conditionMessage(fit),
                stringsAsFactors = FALSE
            ),
            cv.table = data.frame()
        ))
    }
    cv.table <- fit$visit.cv.table
    selection <- fit$diagnostics$od.visit.cv.selection
    selected.summary <- paste(
        names(selection)[names(selection) %in%
                             c("walk.step", "affinity.method",
                               "affinity.scale", "support.size", "degree",
                               "kernel", "bandwidth.multiplier",
                               "lambda.sync", "lambda.ridge", "chart.dim")],
        unlist(selection[names(selection) %in%
                             c("walk.step", "affinity.method",
                               "affinity.scale", "support.size", "degree",
                               "kernel", "bandwidth.multiplier",
                               "lambda.sync", "lambda.ridge", "chart.dim")]),
        sep = "=",
        collapse = "; "
    )
    cv.table$method <- spec$method
    cv.table$label <- spec$label
    list(
        summary = data.frame(
            method = spec$method,
            label = spec$label,
            status = fit$status,
            elapsed.sec = elapsed,
            n.candidates = nrow(cv.table),
            n.failed.candidates = sum(cv.table$visit.cv.status != "ok"),
            selected.candidate.id = selection$candidate.id,
            visit.cv.neg.log.rho = selection$visit.cv.neg.log.rho,
            visit.cv.mean.heldout.rho = selection$visit.cv.mean.heldout.rho,
            mass = fit$accounting$mass,
            max.rho = max(fit$rho),
            n.local.maxima = fit$smoothness$n.local.maxima,
            selected.summary = selected.summary,
            error.message = NA_character_,
            stringsAsFactors = FALSE
        ),
        cv.table = cv.table
    )
}

bind.fill <- function(rows) {
    rows <- rows[lengths(rows) > 0L]
    if (!length(rows)) {
        return(data.frame())
    }
    all.names <- unique(unlist(lapply(rows, names), use.names = FALSE))
    rows <- lapply(rows, function(x) {
        missing <- setdiff(all.names, names(x))
        for (nm in missing) {
            x[[nm]] <- NA
        }
        x[, all.names, drop = FALSE]
    })
    do.call(rbind, rows)
}

results <- lapply(method.specs, fit.one)
summary.table <- bind.fill(lapply(results, `[[`, "summary"))
cv.tables <- bind.fill(lapply(results, `[[`, "cv.table"))
summary.table <- summary.table[order(summary.table$visit.cv.neg.log.rho,
                                     summary.table$method,
                                     na.last = TRUE), ]
rownames(summary.table) <- NULL

summary.path <- file.path(tables.dir, "od_cv5_method_summary.csv")
candidate.path <- file.path(tables.dir, "od_cv5_candidate_table.csv")
write.csv(summary.table, summary.path, row.names = FALSE)
write.csv(cv.tables, candidate.path, row.names = FALSE)

html.escape <- function(x) {
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x <- gsub('"', "&quot;", x, fixed = TRUE)
    x
}

fmt <- function(x, digits = 4) {
    ifelse(is.na(x), "NA", format(signif(x, digits), scientific = FALSE))
}

table.html <- function(df, columns) {
    df <- df[, columns, drop = FALSE]
    header <- paste(sprintf("<th>%s</th>", html.escape(names(df))),
                    collapse = "")
    body <- apply(df, 1L, function(row) {
        paste0("<tr>",
               paste(sprintf("<td>%s</td>", html.escape(row)), collapse = ""),
               "</tr>")
    })
    paste0("<table><thead><tr>", header, "</tr></thead><tbody>",
           paste(body, collapse = "\n"), "</tbody></table>")
}

score.svg <- function(df) {
    ok <- is.finite(df$visit.cv.neg.log.rho)
    width <- 920
    row.h <- 38
    left <- 260
    right <- 50
    top <- 35
    bottom <- 50
    height <- top + bottom + row.h * nrow(df)
    scores <- df$visit.cv.neg.log.rho
    max.score <- max(scores[ok], na.rm = TRUE)
    min.score <- min(scores[ok], na.rm = TRUE)
    if (!is.finite(max.score) || max.score <= min.score) {
        max.score <- min.score + 1
    }
    x.of <- function(x) {
        left + (x - min.score) / (max.score - min.score) *
            (width - left - right)
    }
    rows <- character(nrow(df))
    for (i in seq_len(nrow(df))) {
        y <- top + (i - 0.5) * row.h
        label <- html.escape(df$label[[i]])
        if (is.finite(df$visit.cv.neg.log.rho[[i]])) {
            x <- x.of(df$visit.cv.neg.log.rho[[i]])
            rows[[i]] <- paste0(
                sprintf('<text x="12" y="%.1f" class="svg-label">%s</text>',
                        y + 5, label),
                sprintf('<line x1="%d" y1="%.1f" x2="%.1f" y2="%.1f" class="stem"/>',
                        left, y, x, y),
                sprintf('<circle cx="%.1f" cy="%.1f" r="5.2" class="dot"/>',
                        x, y),
                sprintf('<text x="%.1f" y="%.1f" class="score">%s</text>',
                        x + 8, y + 5,
                        html.escape(fmt(df$visit.cv.neg.log.rho[[i]], 5)))
            )
        } else {
            rows[[i]] <- paste0(
                sprintf('<text x="12" y="%.1f" class="svg-label">%s</text>',
                        y + 5, label),
                sprintf('<text x="%d" y="%.1f" class="failed">failed</text>',
                        left, y + 5)
            )
        }
    }
    axis.y <- height - bottom + 8
    ticks <- pretty(c(min.score, max.score), n = 4)
    ticks <- ticks[ticks >= min.score & ticks <= max.score]
    tick.svg <- paste(vapply(ticks, function(tk) {
        x <- x.of(tk)
        paste0(
            sprintf('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" class="tick"/>',
                    x, axis.y - 8, x, axis.y - 2),
            sprintf('<text x="%.1f" y="%d" class="tick-label">%s</text>',
                    x, axis.y + 15, html.escape(fmt(tk, 4)))
        )
    }, character(1L)), collapse = "")
    paste0(
        sprintf('<svg viewBox="0 0 %d %d" role="img" aria-label="OD-CV5 selected visit-CV scores">',
                width, height),
        '<style>.svg-label{font:14px sans-serif;fill:#1f2933}.score{font:12px sans-serif;fill:#1f2933}.failed{font:13px sans-serif;fill:#9a3412}.stem{stroke:#b8c2cc;stroke-width:2}.dot{fill:#0f766e;stroke:white;stroke-width:1.4}.axis,.tick{stroke:#64748b;stroke-width:1}.tick-label{font:11px sans-serif;fill:#475569;text-anchor:middle}</style>',
        sprintf('<line x1="%d" y1="%d" x2="%d" y2="%d" class="axis"/>',
                left, axis.y - 8, width - right, axis.y - 8),
        tick.svg,
        paste(rows, collapse = ""),
        '</svg>'
    )
}

visible.table <- summary.table
visible.table$elapsed.sec <- fmt(visible.table$elapsed.sec, 4)
visible.table$visit.cv.neg.log.rho <- fmt(visible.table$visit.cv.neg.log.rho, 5)
visible.table$visit.cv.mean.heldout.rho <-
    fmt(visible.table$visit.cv.mean.heldout.rho, 4)
visible.table$mass <- fmt(visible.table$mass, 4)
visible.table$max.rho <- fmt(visible.table$max.rho, 4)

ok.count <- sum(summary.table$status == "ok", na.rm = TRUE)
attempt.count <- nrow(summary.table)
best.label <- summary.table$label[which.min(summary.table$visit.cv.neg.log.rho)]
report.path <- file.path(out.dir, "od_cv5_all_method_smoke_report.html")

css <- "
body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f4f7f6; color: #1f2933; }
main { max-width: 1160px; margin: 0 auto; padding: 32px 28px 48px; }
section { background: white; border: 1px solid #d9e2df; border-radius: 8px; padding: 22px 24px; margin: 18px 0; box-shadow: 0 1px 2px rgba(15,23,42,0.04); }
h1 { font-size: 34px; margin: 0 0 10px; }
h2 { font-size: 23px; margin: 0 0 12px; }
p { line-height: 1.55; }
.meta { color: #52615d; font-size: 14px; }
.note { background: #eef8f5; border-left: 4px solid #0f766e; padding: 10px 13px; }
figure { margin: 20px 0 8px; }
figcaption { font-size: 14px; color: #475569; margin-top: 8px; line-height: 1.45; }
table { border-collapse: collapse; width: 100%; font-size: 13px; }
th, td { border-bottom: 1px solid #e5ebe8; padding: 8px 7px; text-align: left; vertical-align: top; }
th { background: #f0f5f3; color: #25312f; }
code { background: #eef2f1; padding: 1px 4px; border-radius: 4px; }
a { color: #0f766e; }
"

html <- paste0(
    '<!doctype html><html><head><meta charset="utf-8">',
    '<title>OD-CV5 All-Method Smoke Benchmark</title>',
    '<script src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>',
    '<style>', css, '</style></head><body><main>',
    '<h1>OD-CV5 All-Method Smoke Benchmark</h1>',
    '<p class="meta">Build timestamp: ', html.escape(build.timestamp),
    ' | Git commit: ', html.escape(git.commit), '</p>',
    '<section><h2>Purpose</h2>',
    '<p>OD-CV5 asks whether every currently implemented subject occupation-density method can run through the same held-out visit cross-validation interface on one deterministic smoke fixture. The purpose is contract validation, not a claim about which method is scientifically best.</p>',
    '<p>For a candidate \\(\\theta\\), the selected score is</p>',
    '<p>\\[\\mathrm{VisitCV}(\\theta)=-\\frac{1}{n_s}\\sum_{r=1}^{n_s}\\log\\{\\max(\\widehat\\rho^{(-F(r))}_{\\theta}(x_r),\\epsilon)\\}.\\]</p>',
    '<p>Here \\(x_r\\) is the row visited by the subject at visit \\(r\\), \\(F(r)\\) is its fold, and \\(\\widehat\\rho^{(-F(r))}_{\\theta}\\) is the density fit after removing that fold.</p>',
    '<p class="note">Smoke result: ', ok.count, ' of ', attempt.count,
    ' methods returned status <code>ok</code>. The smallest selected held-out negative log mass was produced by <code>',
    html.escape(best.label), '</code> on this fixture.</p></section>',
    '<section><h2>Methods Included</h2>',
    '<p>The smoke set includes the current OD visit-CV coverage: graph random walk, chart-kernel density, local-likelihood density, local-likelihood Bernoulli, LPS count, LPS Bernoulli, and PS-LPS count. All methods use the same support matrix, subject visits, graph, and visit folds.</p>',
    table.html(visible.table, c("label", "status", "n.candidates",
                                "n.failed.candidates", "elapsed.sec")),
    '</section>',
    '<section><h2>Selected Visit-CV Scores</h2>',
    '<p>Lower values are better because the plotted quantity is negative log held-out occupation mass. The figure shows one selected score per method after that method internally chooses its best candidate from its small OD-CV5 candidate grid.</p>',
    '<figure>', score.svg(summary.table),
    '<figcaption>Figure 1. Selected held-out visit-CV score for each OD method in the OD-CV5 smoke benchmark. Each dot is the selected candidate for one method; lower negative log held-out mass means the fitted density assigned more mass to held-out subject visits. This is a deterministic contract smoke figure, not a replicated method-comparison study.</figcaption>',
    '</figure></section>',
    '<section><h2>Selected Candidate Table</h2>',
    '<p>The table records the selected candidate, candidate-grid size, score, final mass accounting, local-maxima smoothness diagnostic, and selected parameter summary. Full candidate-level telemetry is linked in the appendix.</p>',
    table.html(visible.table, c("label", "selected.candidate.id",
                                "visit.cv.neg.log.rho",
                                "visit.cv.mean.heldout.rho",
                                "mass", "max.rho", "n.local.maxima",
                                "selected.summary")),
    '</section>',
    '<section><h2>What We Learned</h2>',
    '<p>The uniform OD visit-CV path now covers all currently implemented OD-CV method families. The important engineering result is that the same output fields, score definition, candidate table, fold vector, and selected-candidate metadata are available across graph, chart, LPS, PS-LPS, and local-likelihood methods.</p>',
    '<p>The remaining boundary is deliberate: metric graph low-pass is still available as a source smoother that can be normalized into a density, but it is not yet a first-class <code>fit.subject.od(method = ...)</code> branch with an OD visit-CV candidate contract.</p>',
    '</section>',
    '<section><h2>Appendix: Reproducibility</h2>',
    '<p>Result directory: <code>', html.escape(out.dir), '</code></p>',
    '<ul>',
    '<li><a href="tables/od_cv5_method_summary.csv">Method summary CSV</a></li>',
    '<li><a href="tables/od_cv5_candidate_table.csv">Candidate table CSV</a></li>',
    '</ul>',
    '<p>Regeneration command:</p>',
    '<pre><code>Rscript scripts/run_od_cv5_all_method_smoke.R</code></pre>',
    '</section>',
    '</main></body></html>'
)

writeLines(html, report.path)
cat("OD-CV5 report:", report.path, "\n")
cat("OD-CV5 summary:", summary.path, "\n")
cat("OD-CV5 candidates:", candidate.path, "\n")
