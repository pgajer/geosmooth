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

suppressPackageStartupMessages(pkgload::load_all(repo.dir, quiet = TRUE))

cli <- parse.args(commandArgs(trailingOnly = TRUE))
experiment.degree <- as.integer(cli$degree %||% 1L)
if (length(experiment.degree) != 1L || !is.finite(experiment.degree) ||
    experiment.degree < 0L) {
    stop("'--degree' must be a nonnegative integer scalar.", call. = FALSE)
}
date.tag <- format(Sys.Date(), "%Y%m%d")
report.prefix <- cli$`report-prefix` %||% if (experiment.degree == 1L) {
    "csd8_candidate_cv_surface_audit"
} else {
    paste0("csd8_deg", experiment.degree, "_candidate_cv_surface_audit")
}
report.root <- cli$`report-dir` %||% file.path(
    repo.dir, "dev/methods/lps/reports",
    paste0(report.prefix, "_", date.tag)
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

    curve.high.X <- cbind(
        curve.X,
        sapply(1:16, function(jj) sin((jj + 1) * pi * t) / sqrt(jj + 1)),
        sapply(1:16, function(jj) cos((jj + 1) * pi * t) / sqrt(jj + 1))
    )
    curve.high.X <- scale(curve.high.X)
    curve.high.f <- exp(-18 * (t + 0.45)^2) -
        0.8 * exp(-20 * (t - 0.35)^2) + 0.25 * sin(3 * pi * t)

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

    surface.high.X <- cbind(
        surface.X,
        sin(2 * pi * u), sin(2 * pi * v), cos(2 * pi * u),
        cos(2 * pi * v), u^3, v^3, u^2 * v, u * v^2,
        sin(pi * u * v), cos(pi * u * v), u + v, u - v,
        (u + v)^2, (u - v)^2, sin(3 * u), cos(3 * v)
    )
    surface.high.X <- scale(surface.high.X)
    surface.high.f <- sin(pi * u) * cos(pi * v) +
        0.5 * exp(-6 * ((u + 0.2)^2 + (v - 0.35)^2))

    grid3 <- expand.grid(a = seq(-1, 1, length.out = 4L),
                         b = seq(-1, 1, length.out = 4L),
                         c = seq(-1, 1, length.out = 4L))
    a <- grid3$a
    b <- grid3$b
    cc <- grid3$c
    volume.X <- cbind(
        a, b, cc, a * b, a * cc, b * cc, a^2, b^2, cc^2,
        sin(pi * a), cos(pi * b), sin(pi * cc)
    )
    volume.f <- exp(-3 * ((a - 0.35)^2 + (b + 0.1)^2 + cc^2)) -
        0.65 * exp(-4 * ((a + 0.4)^2 + (b - 0.35)^2 +
                             (cc - 0.25)^2))

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

    n.block <- 72L
    z1 <- seq(-1, 1, length.out = n.block)
    z2 <- rep(seq(-1, 1, length.out = 12L), each = 6L)
    z3 <- rep(seq(-1, 1, length.out = 6L), times = 12L)
    block.X <- matrix(0, n.block, 40L)
    block.X[, 1:12] <- outer(z1, seq(0.5, 1.6, length.out = 12L),
                             function(x, w) sin(w * pi * x))
    block.X[, 13:24] <- outer(z2, seq(0.5, 1.6, length.out = 12L),
                              function(x, w) cos(w * pi * x))
    block.X[, 25:36] <- outer(z3, seq(0.5, 1.6, length.out = 12L),
                              function(x, w) sin(w * pi * x))
    block.X[, 37:40] <- cbind(z1 * z2, z1 * z3, z2 * z3, z1^2 - z2^2)
    block.X <- scale(block.X)
    block.f <- 0.8 * sin(pi * z1) + 0.5 * exp(-8 * (z2 - 0.25)^2) -
        0.35 * cos(pi * z3)

    list(
        list(id = "curve_1d_embedded_p8",
             family = "homogeneous 1D manifold",
             X = curve.X, f = curve.f),
        list(id = "curve_1d_highdim_p40",
             family = "high-dimensional embedded 1D",
             X = curve.high.X, f = curve.high.f),
        list(id = "surface_2d_embedded_p8",
             family = "homogeneous 2D manifold",
             X = surface.X, f = surface.f),
        list(id = "surface_2d_highdim_p24",
             family = "high-dimensional embedded 2D",
             X = surface.high.X, f = surface.high.f),
        list(id = "volume_3d_embedded_p12",
             family = "homogeneous 3D manifold",
             X = volume.X, f = volume.f),
        list(id = "surface_line_union_p8",
             family = "heterogeneous/non-manifold",
             X = nonmanifold.X, f = nonmanifold.f),
        list(id = "simplex_faces_p8",
             family = "OD-style simplex-boundary geometry",
             X = simplex.X, f = simplex.f),
        list(id = "rank_blocks_p40",
             family = "rank/block heterogeneity",
             X = block.X, f = block.f)
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

fit.full.grid.cv.surface <- function(X.train, y.train, inner.seed, dataset.id,
                                     dataset.family, rep.id, outer.fold) {
    t0 <- proc.time()
    out <- tryCatch({
        fit <- fit.lps(
            X = X.train,
            y = y.train,
            support.grid = 15:35,
            degree.grid = experiment.degree,
            kernel.grid = "gaussian",
            bandwidth.multiplier.grid = 1,
            coordinate.method = "local.pca",
            backend = "R",
            design.basis = "orthogonal.polynomial.drop",
            ridge.multiplier.grid = c(0, 1e-10),
            ridge.condition.max = Inf,
            cv.folds = 3L,
            cv.seed = inner.seed,
            chart.dim.grid = 1:8,
            selection.strategy = "grid"
        )
        elapsed <- unname((proc.time() - t0)[["elapsed"]])
        cv <- fit$cv.table
        selected <- fit$selected
        cv$dataset.id <- dataset.id
        cv$dataset.family <- dataset.family
        cv$repetition <- rep.id
        cv$outer.fold <- outer.fold
        cv$fit.status <- "ok"
        cv$fit.elapsed.sec <- elapsed
        cv$fit.error.message <- ""
        cv$selected.by.cv <- cv$candidate.id %in% selected$candidate.id
        cv$selected.support.size <- selected$support.size[[1L]] %||% NA_integer_
        cv$selected.chart.dim <- selected$chart.dim[[1L]] %||% NA_integer_
        cv$selected.cv.rmse <- selected$cv.rmse.observed[[1L]] %||% NA_real_
        cv
    }, error = function(e) {
        elapsed <- unname((proc.time() - t0)[["elapsed"]])
        data.frame(
            candidate.id = NA_integer_,
            support.size = NA_integer_,
            degree = NA_integer_,
            kernel = NA_character_,
            bandwidth.multiplier = NA_real_,
            chart.dim = NA_integer_,
            cv.rmse.observed = NA_real_,
            dataset.id = dataset.id,
            dataset.family = dataset.family,
            repetition = rep.id,
            outer.fold = outer.fold,
            fit.status = "error",
            fit.elapsed.sec = elapsed,
            fit.error.message = conditionMessage(e),
            selected.by.cv = FALSE,
            selected.support.size = NA_integer_,
            selected.chart.dim = NA_integer_,
            selected.cv.rmse = NA_real_,
            stringsAsFactors = FALSE
        )
    })
    out
}

run.cv.surface.evaluation <- function() {
    datasets <- make.datasets()
    cv.rows <- list()
    idx <- 1L
    for (ds in datasets) {
        for (rep.id in 1:2) {
            set.seed(7000L + rep.id)
            y <- ds$f + stats::rnorm(length(ds$f), sd = 0.05 * stats::sd(ds$f))
            ofold <- outer.foldid(nrow(ds$X), seed = 9000L + rep.id)
            for (fold in sort(unique(ofold))) {
                train <- which(ofold != fold)
                inner.seed <- 10000L + 100L * rep.id + fold
                cv <- fit.full.grid.cv.surface(
                    X.train = ds$X[train, , drop = FALSE],
                    y.train = y[train],
                    inner.seed = inner.seed,
                    dataset.id = ds$id,
                    dataset.family = ds$family,
                    rep.id = rep.id,
                    outer.fold = fold
                )
                cv.rows[[idx]] <- cv
                idx <- idx + 1L
            }
        }
    }
    do.call(rbind, cv.rows)
}

message("Running CSD8 candidate-level CV surface collection. ",
        "This reruns the CSD6 full-grid selector and persists fit$cv.table.")
cv.surface <- run.cv.surface.evaluation()
utils::write.csv(cv.surface,
                 file.path(tab.dir, "csd8_candidate_inner_cv_scores.csv"),
                 row.names = FALSE)

metadata <- data.frame(
    key = c(
        "result.generated.at", "source.path", "command", "working.directory",
        "outer.folds", "repetitions", "support.grid", "chart.dim.grid",
        "degree", "design.margin", "dataset.count", "candidate.cv.rows",
        "note"
    ),
    value = c(
        format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
        "~/current_projects/geosmooth/dev/methods/lps/ci/csd8_candidate_cv_surface_audit_run.R",
        paste("Rscript dev/methods/lps/ci/csd8_candidate_cv_surface_audit_run.R",
              paste0("--degree=", experiment.degree)),
        "~/current_projects/geosmooth",
        "3", "2", "15:35", "1:8", as.character(experiment.degree), "2",
        as.character(length(make.datasets())),
        as.character(nrow(cv.surface)),
        "CSD8 persists candidate-level inner-CV scores and joins them to the CSD6 truth-facing grid in the render step."
    ),
    stringsAsFactors = FALSE
)
utils::write.csv(metadata, file.path(tab.dir, "csd8_result_metadata.csv"),
                 row.names = FALSE)

message("Wrote CSD8 result artifacts under ", report.root)
message("Render the HTML report with: Rscript dev/methods/lps/ci/csd8_candidate_cv_surface_audit_render.R --report-dir=", report.root)
