#!/usr/bin/env Rscript

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

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

suppressPackageStartupMessages(pkgload::load_all(repo.dir, quiet = TRUE))

date.tag <- format(Sys.Date(), "%Y%m%d")
report.root <- file.path(
    repo.dir,
    "dev/methods/lps/reports",
    paste0("csd5_coupled_kd_evaluation_", date.tag)
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

table.html <- function(df, digits = 4L, max.rows = 30L) {
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
    on.exit(grDevices::dev.off(), add = TRUE)
    force(expr)
}

rmse <- function(x, y) sqrt(mean((as.numeric(x) - as.numeric(y))^2))

safe.id <- function(x) gsub("[^A-Za-z0-9_]+", "_", x)

make.datasets <- function() {
    n.curve <- 63L
    t <- seq(-1, 1, length.out = n.curve)
    curve.X <- cbind(
        t, t^2, t^3, sin(2 * t), cos(2 * t),
        sin(3 * t), cos(3 * t), 0.25 * sin(5 * t)
    )
    curve.f <- sin(pi * t) + 0.35 * cos(2 * pi * t)

    grid <- expand.grid(u = seq(-1, 1, length.out = 8L),
                        v = seq(-1, 1, length.out = 8L))
    u <- grid$u
    v <- grid$v
    surface.X <- cbind(
        u, v, u^2 + v^2, u * v, sin(pi * u), cos(pi * v),
        sin(pi * (u + v)), cos(pi * (u - v))
    )
    surface.f <- exp(-4 * ((u - 0.35)^2 + (v + 0.1)^2)) -
        0.7 * exp(-5 * ((u + 0.45)^2 + (v - 0.35)^2))

    n.line <- 24L
    n.patch <- 48L
    uu <- seq(-1, 1, length.out = n.patch)
    vv <- sin(seq(0, 2 * pi, length.out = n.patch))
    patch.X <- cbind(
        uu, vv, uu^2 - 0.5 * vv^2, uu * vv, sin(2 * uu),
        cos(2 * vv), uu^3, vv^3
    )
    s <- seq(-1, 1, length.out = n.line)
    line.X <- cbind(s, 0.15 * s, 0.2 * s, 0.1 * s, sin(s),
                    cos(s), 0.3 * s, -0.2 * s)
    nonmanifold.X <- rbind(patch.X, line.X)
    nonmanifold.f <- c(
        sin(pi * uu) + 0.25 * vv,
        0.8 * sin(1.5 * pi * s)
    )

    set.seed(20260708L)
    n.simplex <- 72L
    face <- rep(1:3, length.out = n.simplex)
    simplex.X <- matrix(0, n.simplex, 8L)
    for (ii in seq_len(n.simplex)) {
        active <- switch(as.character(face[[ii]]),
                         `1` = c(1L, 2L),
                         `2` = c(1L, 3L, 4L),
                         `3` = c(2L, 5L, 6L, 7L))
        vals <- stats::rgamma(length(active), shape = 1.5, rate = 1)
        simplex.X[ii, active] <- vals / sum(vals)
    }
    simplex.f <- 1.2 * simplex.X[, 1] - 0.8 * simplex.X[, 2] +
        0.6 * simplex.X[, 5] + 0.25 * sin(4 * simplex.X[, 3])

    list(
        list(id = "curve_1d_embedded_p8",
             family = "homogeneous 1D manifold",
             X = curve.X, f = curve.f),
        list(id = "surface_2d_embedded_p8",
             family = "homogeneous 2D manifold",
             X = surface.X, f = surface.f),
        list(id = "surface_line_union_p8",
             family = "heterogeneous/non-manifold",
             X = nonmanifold.X, f = nonmanifold.f),
        list(id = "simplex_faces_p8",
             family = "OD-style simplex-boundary geometry",
             X = simplex.X, f = simplex.f)
    )
}

outer.foldid <- function(n, nfold = 3L, seed = 1L) {
    set.seed(seed)
    sample(rep(seq_len(nfold), length.out = n))
}

inner.foldid <- function(n, nfold = 3L, seed = 1L) {
    set.seed(seed)
    sample(rep(seq_len(nfold), length.out = n))
}

feasible.full.grid <- function(support.grid = 15:35,
                               chart.dim.grid = 1:8,
                               degree = 1L,
                               design.margin = 2L) {
    grid <- expand.grid(
        support.size = support.grid,
        chart.dim = chart.dim.grid,
        KEEP.OUT.ATTRS = FALSE
    )
    grid$design.ncol <- choose(grid$chart.dim + degree, degree)
    grid$design.margin <- design.margin
    grid$feasible <- grid$design.ncol + design.margin <= grid$support.size
    grid
}

fit.strategy <- function(X.train, y.train, X.test, y.test, strategy,
                         inner.seed) {
    common <- list(
        X = X.train,
        y = y.train,
        support.grid = 15:35,
        degree.grid = 1L,
        kernel.grid = "gaussian",
        bandwidth.multiplier.grid = 1,
        coordinate.method = "local.pca",
        backend = "R",
        design.basis = "orthogonal.polynomial.drop",
        ridge.multiplier.grid = c(0, 1e-10),
        ridge.condition.max = Inf,
        cv.folds = 3L,
        cv.seed = inner.seed
    )
    args <- switch(
        strategy,
        auto = c(common, list(chart.dim = "auto")),
        local_auto = c(common, list(chart.dim = "local.auto")),
        sparse_kd = c(common, list(chart.dim.grid = 1:8,
                                   selection.strategy = "sparse_kd")),
        full_kd = c(common, list(chart.dim.grid = 1:8,
                                 selection.strategy = "grid")),
        stop("unknown strategy: ", strategy, call. = FALSE)
    )
    t0 <- proc.time()
    fit <- do.call(fit.lps, args)
    elapsed <- unname((proc.time() - t0)[["elapsed"]])
    pred <- predict(fit, newdata = X.test)
    selected <- fit$selected
    evaluated.candidates <- nrow(fit$cv.table)
    numeric.grid.arm <- strategy %in% c("sparse_kd", "full_kd")
    unique.pca.builds <- if (numeric.grid.arm) {
        fit$diagnostics$coupled.kd.selection$reuse.groups %||%
            length(unique(fit$cv.table$support.size))
    } else {
        evaluated.candidates
    }
    data.frame(
        strategy = strategy,
        status = "ok",
        outer.rmse = rmse(pred, y.test),
        selected.support.size = selected$support.size[[1L]] %||% NA_integer_,
        selected.chart.dim = as.character(selected$chart.dim[[1L]] %||%
                                              fit$chart.dim[[1L]] %||%
                                              NA_character_),
        inner.cv.rmse = selected$cv.rmse.observed[[1L]] %||% NA_real_,
        elapsed.sec = elapsed,
        evaluated.candidates = evaluated.candidates,
        planned.candidates = fit$diagnostics$coupled.kd.selection$planned.candidates %||%
            evaluated.candidates,
        unique.pca.builds = unique.pca.builds,
        numeric.grid.arm = numeric.grid.arm,
        stringsAsFactors = FALSE
    )
}

score.full.candidates <- function(X.train, y.train, X.test, y.test,
                                  inner.seed, dataset.id, rep.id,
                                  outer.fold) {
    grid <- feasible.full.grid()
    grid <- grid[grid$feasible, , drop = FALSE]
    rows <- vector("list", nrow(grid))
    for (ii in seq_len(nrow(grid))) {
        cand <- grid[ii, , drop = FALSE]
        t0 <- proc.time()
        fit <- fit.lps(
            X = X.train,
            y = y.train,
            support.grid = cand$support.size,
            degree.grid = 1L,
            kernel.grid = "gaussian",
            bandwidth.multiplier.grid = 1,
            coordinate.method = "local.pca",
            chart.dim = cand$chart.dim,
            backend = "R",
            design.basis = "orthogonal.polynomial.drop",
            ridge.multiplier.grid = c(0, 1e-10),
            ridge.condition.max = Inf,
            cv.folds = 3L,
            cv.seed = inner.seed
        )
        elapsed <- unname((proc.time() - t0)[["elapsed"]])
        pred <- predict(fit, newdata = X.test)
        rows[[ii]] <- data.frame(
            dataset.id = dataset.id,
            repetition = rep.id,
            outer.fold = outer.fold,
            support.size = cand$support.size,
            chart.dim = cand$chart.dim,
            outer.rmse = rmse(pred, y.test),
            elapsed.sec = elapsed,
            stringsAsFactors = FALSE
        )
    }
    do.call(rbind, rows)
}

run.evaluation <- function() {
    datasets <- make.datasets()
    strategies <- c("auto", "local_auto", "sparse_kd", "full_kd")
    score.rows <- list()
    ref.rows <- list()
    idx <- 1L
    ridx <- 1L
    for (ds in datasets) {
        for (rep.id in 1:2) {
            set.seed(7000L + rep.id)
            y <- ds$f + stats::rnorm(length(ds$f), sd = 0.05 * stats::sd(ds$f))
            ofold <- outer.foldid(nrow(ds$X), seed = 9000L + rep.id)
            for (fold in sort(unique(ofold))) {
                train <- which(ofold != fold)
                test <- which(ofold == fold)
                inner.seed <- 10000L + 100L * rep.id + fold
                for (strategy in strategies) {
                    row <- tryCatch(
                        fit.strategy(
                            X.train = ds$X[train, , drop = FALSE],
                            y.train = y[train],
                            X.test = ds$X[test, , drop = FALSE],
                            y.test = ds$f[test],
                            strategy = strategy,
                            inner.seed = inner.seed
                        ),
                        error = function(e) {
                            data.frame(
                                strategy = strategy,
                                status = "error",
                                outer.rmse = NA_real_,
                                selected.support.size = NA_integer_,
                                selected.chart.dim = NA_character_,
                                inner.cv.rmse = NA_real_,
                                elapsed.sec = NA_real_,
                                evaluated.candidates = NA_integer_,
                                planned.candidates = NA_integer_,
                                unique.pca.builds = NA_integer_,
                                numeric.grid.arm = strategy %in%
                                    c("sparse_kd", "full_kd"),
                                error.message = conditionMessage(e),
                                stringsAsFactors = FALSE
                            )
                        }
                    )
                    row$dataset.id <- ds$id
                    row$dataset.family <- ds$family
                    row$repetition <- rep.id
                    row$outer.fold <- fold
                    score.rows[[idx]] <- row
                    idx <- idx + 1L
                }
                ref <- score.full.candidates(
                    X.train = ds$X[train, , drop = FALSE],
                    y.train = y[train],
                    X.test = ds$X[test, , drop = FALSE],
                    y.test = ds$f[test],
                    inner.seed = inner.seed,
                    dataset.id = ds$id,
                    rep.id = rep.id,
                    outer.fold = fold
                )
                ref.rows[[ridx]] <- ref
                ridx <- ridx + 1L
            }
        }
    }
    list(
        scores = do.call(rbind, score.rows),
        references = do.call(rbind, ref.rows)
    )
}

message("Running CSD5 focused evaluation. This takes about two minutes.")
res <- run.evaluation()
scores <- res$scores
refs <- res$references

key <- c("dataset.id", "repetition", "outer.fold")
ref.best <- refs[ave(refs$outer.rmse, refs[key], FUN = function(x) {
    x == min(x, na.rm = TRUE)
}) == 1, , drop = FALSE]
ref.best <- ref.best[!duplicated(ref.best[key]), , drop = FALSE]
names(ref.best)[names(ref.best) == "outer.rmse"] <- "reference.outer.rmse"
names(ref.best)[names(ref.best) == "support.size"] <- "reference.support.size"
names(ref.best)[names(ref.best) == "chart.dim"] <- "reference.chart.dim"
scores <- merge(scores, ref.best[, c(key, "reference.outer.rmse",
                                     "reference.support.size",
                                     "reference.chart.dim")],
                by = key, all.x = TRUE)
scores$outer.regret <- scores$outer.rmse - scores$reference.outer.rmse
scores$support.distance.to.reference <-
    abs(scores$selected.support.size - scores$reference.support.size)
scores$chart.dim.distance.to.reference <-
    abs(suppressWarnings(as.integer(scores$selected.chart.dim)) -
            scores$reference.chart.dim)

summary <- aggregate(
    cbind(outer.rmse, outer.regret, elapsed.sec, evaluated.candidates,
          unique.pca.builds) ~ strategy,
    data = scores[scores$status == "ok", ],
    FUN = stats::median
)
summary$n.ok <- as.integer(table(scores$strategy)[summary$strategy])
summary$failure.rate <- aggregate(status ~ strategy, data = scores,
                                  FUN = function(x) mean(x != "ok"))$status[
                                      match(summary$strategy,
                                            aggregate(status ~ strategy,
                                                      data = scores,
                                                      FUN = length)$strategy)
                                  ]

family.summary <- aggregate(
    outer.regret ~ strategy + dataset.family,
    data = scores[scores$status == "ok", ],
    FUN = stats::median
)

utils::write.csv(scores, file.path(tab.dir, "csd5_strategy_outer_scores.csv"),
                 row.names = FALSE)
utils::write.csv(refs, file.path(tab.dir, "csd5_full_grid_candidate_scores.csv"),
                 row.names = FALSE)
utils::write.csv(summary, file.path(tab.dir, "csd5_strategy_summary.csv"),
                 row.names = FALSE)
utils::write.csv(family.summary,
                 file.path(tab.dir, "csd5_family_strategy_summary.csv"),
                 row.names = FALSE)

make.regret.runtime.plot <- function() {
    path <- file.path(fig.dir, "figure_1_regret_runtime.svg")
    ok <- scores[scores$status == "ok", , drop = FALSE]
    plot.df <- aggregate(
        cbind(outer.regret, elapsed.sec) ~ strategy,
        data = ok,
        FUN = stats::median
    )
    mad.regret <- aggregate(outer.regret ~ strategy, data = ok,
                            FUN = stats::mad)
    mad.time <- aggregate(elapsed.sec ~ strategy, data = ok,
                          FUN = stats::mad)
    plot.df$mad.regret <- mad.regret$outer.regret[
        match(plot.df$strategy, mad.regret$strategy)
    ]
    plot.df$mad.time <- mad.time$elapsed.sec[
        match(plot.df$strategy, mad.time$strategy)
    ]
    cols <- c(auto = "#4C78A8", local_auto = "#59A14F",
              sparse_kd = "#F28E2B", full_kd = "#E15759")
    write.svg(path, width = 8.4, height = 5.5, {
        old <- par(mar = c(5, 5, 3, 1))
        on.exit(par(old), add = TRUE)
        plot(plot.df$elapsed.sec, plot.df$outer.regret,
             pch = 16, cex = 1.2, col = cols[plot.df$strategy],
             xlab = "Median elapsed seconds per outer fit",
             ylab = "Median regret vs full-grid outer reference",
             main = "Figure 1. Runtime versus full-grid outer regret")
        arrows(plot.df$elapsed.sec - plot.df$mad.time, plot.df$outer.regret,
               plot.df$elapsed.sec + plot.df$mad.time, plot.df$outer.regret,
               code = 3, angle = 90, length = 0.04,
               col = grDevices::adjustcolor("#B22222", 0.75))
        arrows(plot.df$elapsed.sec, plot.df$outer.regret - plot.df$mad.regret,
               plot.df$elapsed.sec, plot.df$outer.regret + plot.df$mad.regret,
               code = 3, angle = 90, length = 0.04,
               col = grDevices::adjustcolor("#B22222", 0.75))
        text(plot.df$elapsed.sec, plot.df$outer.regret,
             labels = plot.df$strategy, pos = 3, cex = 0.85)
        grid(col = "#E6E6E6")
    })
    path
}

make.selected.kd.plot <- function() {
    path <- file.path(fig.dir, "figure_2_selected_kd.svg")
    ok <- scores[scores$status == "ok" &
                     scores$strategy %in% c("sparse_kd", "full_kd"), ,
                 drop = FALSE]
    cols <- c(sparse_kd = "#F28E2B", full_kd = "#E15759")
    write.svg(path, width = 9, height = 5.8, {
        old <- par(mar = c(5, 5, 3, 8))
        on.exit(par(old), add = TRUE)
        plot(ok$selected.support.size,
             suppressWarnings(as.integer(ok$selected.chart.dim)),
             pch = 16, cex = 0.9, col = cols[ok$strategy],
             xlim = c(14, 36), ylim = c(0.5, 8.5),
             xlab = "Selected support size k",
             ylab = "Selected chart dimension d",
             main = "Figure 2. Selected numeric (k,d) over outer tasks")
        legend("right", inset = -0.28, xpd = TRUE, bty = "n",
               legend = names(cols), pch = 16, col = cols)
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
        old <- par(mar = c(5, 5, 3, 6))
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
        legend("right", inset = -0.2, xpd = TRUE, bty = "n",
               legend = "full-grid winner", pch = 4, col = "#D7191C")
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
    mat <- rbind(reuse$unique.pca.builds, reuse$avoided.pca.builds)
    colnames(mat) <- reuse$strategy
    write.svg(path, width = 8.5, height = 5.4, {
        old <- par(mar = c(6, 5, 3, 1))
        on.exit(par(old), add = TRUE)
        barplot(mat, beside = FALSE, col = c("#4C78A8", "#D9E5F2"),
                border = NA, las = 2,
                ylab = "Median count",
                main = "Figure 4. Candidate evaluation and PCA-reuse accounting")
        legend("topright",
               legend = c("unique PCA builds", "candidate builds avoided"),
               fill = c("#4C78A8", "#D9E5F2"), bty = "n")
    })
    path
}

fig1 <- make.regret.runtime.plot()
fig2 <- make.selected.kd.plot()
fig3 <- make.surface.plot()
fig4 <- make.reuse.plot()

rel <- function(path) {
    gsub("\\\\", "/", utils::URLencode(basename(dirname(path)), reserved = TRUE))
}
fig.rel <- function(path) file.path("figures", basename(path))
tab.rel <- function(name) file.path("tables", name)

build.time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
source.path <- "~/current_projects/geosmooth/dev/methods/lps/ci/csd5_coupled_kd_evaluation_report.R"

html <- paste0(
'<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>CSD5 Coupled Support-Size and Chart-Dimension Evaluation</title>
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
</style>
</head>
<body>
<main>
<section>
<h1>CSD5 Coupled Support-Size and Chart-Dimension Evaluation</h1>
<p class="meta">Built ', html.escape(build.time), ' from <code>',
html.escape(source.path), '</code>.</p>
<p>This focused CSD5 report asks whether the sparse coupled selector over
support size <code>k</code> and chart dimension <code>d</code> behaves like a
full Cartesian reference while reducing candidate count and PCA work.  The
report is deliberately truth-facing: every strategy is selected using only
inner folds on the outer-training set, then scored on an outer fold that no
selector saw.  The full-grid reference is the best candidate on that same outer
truth target, not the candidate with the lowest inner CV score.</p>
<div class="callout"><strong>Scope.</strong> This first report validates the
LPS implementation path where full Cartesian references are feasible.  PS-LPS
uses the same sparse candidate machinery after CSD4, but its full-grid
synchronized solve reference is intentionally left for a larger runtime study.</div>
</section>

<section>
<h2>Design</h2>
<p>The full Cartesian reference universe is
<code>k in 15:35</code> and <code>d in 1:8</code>, filtered by
<code>q(d,g)+design.margin <= k</code>.  Here the report uses degree
<code>g=1</code>, so <code>q(d,1)=d+1</code>, and all planned candidates are
feasible.  The strategy arms are:</p>
<table>
<tr><th>Label</th><th>Meaning</th></tr>
<tr><td><code>auto</code></td><td>Global automatic chart dimension with support selected over <code>15:35</code>.</td></tr>
<tr><td><code>local_auto</code></td><td>Anchor-specific automatic chart dimension with support selected over <code>15:35</code>.</td></tr>
<tr><td><code>sparse_kd</code></td><td>Sparse coupled numeric <code>(k,d)</code> skeleton drawn from the same candidate universe.</td></tr>
<tr><td><code>full_kd</code></td><td>Full Cartesian numeric <code>(k,d)</code> selector using inner CV.</td></tr>
</table>
<p>The benchmark cells include homogeneous 1D and 2D embedded manifolds, a
heterogeneous surface--line union, and a simplex-boundary geometry intended to
probe OD-style data structure.</p>
</section>

<section>
<h2>Main Questions Status</h2>
<p><strong>Near-best recovery.</strong> The sparse selector is evaluated by
outer-fold regret against the full Cartesian truth-facing reference.  This is
the central quantity in Figure 1 and the summary table below.</p>
<p><strong>Runtime and candidate count.</strong> Figure 4 shows that the sparse
selector evaluates fewer candidates and reuses PCA coordinates across chart
dimensions within support groups.</p>
<p><strong>Homogeneous versus heterogeneous behavior.</strong> The family-level
summary separates homogeneous manifold cells from heterogeneous and
simplex-boundary cells.  This is a smoke-sized evaluation, so these rows are
diagnostic rather than final evidence for defaults.</p>
</section>

<section>
<h2>Summary Tables</h2>',
table.html(summary[order(summary$outer.regret), ], digits = 4),
'<p>Full tables are available as
<a href="', tab.rel("csd5_strategy_outer_scores.csv"), '">strategy outer scores</a>,
<a href="', tab.rel("csd5_full_grid_candidate_scores.csv"), '">full-grid candidate scores</a>,
<a href="', tab.rel("csd5_strategy_summary.csv"), '">strategy summary</a>, and
<a href="', tab.rel("csd5_family_strategy_summary.csv"), '">family summary</a>.</p>
</section>

<section>
<h2>Figures</h2>
<div class="figure"><img src="', fig.rel(fig1), '" alt="Runtime versus regret">
<p class="caption"><strong>Figure 1.</strong> Runtime versus full-grid outer
regret.  Points show strategy medians across matched outer tasks.  Red bars show
median absolute deviations, so a strategy is attractive when it sits low and to
the left.</p></div>
<div class="figure"><img src="', fig.rel(fig2), '" alt="Selected k d">
<p class="caption"><strong>Figure 2.</strong> Selected numeric
<code>(k,d)</code> values for sparse and full numeric selectors.  This reveals
whether the sparse skeleton systematically pushes toward smaller supports or
lower dimensions.</p></div>
<div class="figure"><img src="', fig.rel(fig3), '" alt="Full-grid score surface">
<p class="caption"><strong>Figure 3.</strong> A representative full-grid outer
score surface.  The red cross marks the outer truth-facing full-grid winner.
This is the surface the sparse selector is trying to approximate with fewer
candidate evaluations.</p></div>
<div class="figure"><img src="', fig.rel(fig4), '" alt="Reuse accounting">
<p class="caption"><strong>Figure 4.</strong> Candidate and PCA-reuse
accounting.  For numeric chart-dimension grids, the implementation builds the
maximum-dimension PCA coordinates once per reusable support/kernel group and
slices them for lower dimensions.  The <code>auto</code> and
<code>local_auto</code> arms are not numeric dimension-grid arms, so their bars
show evaluated candidates with no avoided-build segment.</p></div>
</section>

<section>
<h2>Family-Level Summary</h2>',
table.html(family.summary[order(family.summary$dataset.family,
                                family.summary$strategy), ], digits = 4),
'<p>The simplex-boundary row is included because CSD selection will eventually
matter for OD-style examples.  The present report only uses continuous
truth-facing LPS fits, so OD density recovery and subject-level visit-law
scoring still require a dedicated OD evaluation.</p>
</section>

<section>
<h2>Interpretation</h2>
<p>The useful reading of this report is comparative rather than absolute.  If
<code>sparse_kd</code> has small regret relative to the full-grid outer
reference while evaluating far fewer candidates, then the sparse skeleton is
doing its intended job.  If the selected <code>(k,d)</code> values differ from
<code>full_kd</code> but the outer regret remains small, that is not a failure:
it means the outer score surface is flat enough that several local chart
configurations are practically equivalent.</p>
<p>No package defaults are changed by this phase.  The report is evidence for
auditing CSD selection behavior and deciding which larger PS-LPS or OD-style
benchmarks should be run next.</p>
</section>
</main>
</body>
</html>')

report.path <- file.path(report.root, "csd5_coupled_kd_evaluation_report.html")
writeLines(html, report.path)
message("Wrote ", report.path)
