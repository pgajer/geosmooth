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


metadata <- data.frame(
    key = c(
        "result.generated.at", "source.path", "command", "working.directory",
        "outer.folds", "repetitions", "support.grid", "chart.dim.grid",
        "degree", "design.margin", "strategy.rows", "full.grid.rows"
    ),
    value = c(
        format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
        "~/current_projects/geosmooth/dev/methods/lps/ci/csd5_coupled_kd_evaluation_run.R",
        "Rscript dev/methods/lps/ci/csd5_coupled_kd_evaluation_run.R",
        "~/current_projects/geosmooth",
        "3", "2", "15:35", "1:8", "1", "2",
        as.character(nrow(scores)), as.character(nrow(refs))
    ),
    stringsAsFactors = FALSE
)
utils::write.csv(metadata, file.path(tab.dir, "csd5_result_metadata.csv"),
                 row.names = FALSE)

message("Wrote CSD5 result artifacts under ", report.root)
message("Render the HTML report with: Rscript dev/methods/lps/ci/csd5_coupled_kd_evaluation_render.R --report-dir=", report.root)
