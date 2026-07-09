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
date.tag <- format(Sys.Date(), "%Y%m%d")
run.root <- cli$`run-dir` %||% file.path(
    repo.dir,
    "dev/methods/lps/runs",
    paste0("csd_plateau_kd_comparison_", date.tag)
)
dir.create(run.root, recursive = TRUE, showWarnings = FALSE)

rmse <- function(x, y) sqrt(mean((as.numeric(x) - as.numeric(y))^2))
mae <- function(x, y) mean(abs(as.numeric(x) - as.numeric(y)))
cor.safe <- function(x, y) {
    ok <- is.finite(x) & is.finite(y)
    if (sum(ok) < 3L || stats::sd(x[ok]) == 0 || stats::sd(y[ok]) == 0) {
        return(NA_real_)
    }
    as.numeric(stats::cor(x[ok], y[ok]))
}

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
    nonmanifold.f <- c(sin(pi * uu) + 0.25 * vv, 0.8 * sin(1.5 * pi * s))
    nonmanifold.coord <- rbind(cbind(u = uu, v = vv),
                               cbind(u = s, v = 0.15 * s))

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
             display = "1d", coord = data.frame(t = t),
             X = curve.X, f = curve.f),
        list(id = "curve_1d_highdim_p40",
             family = "high-dimensional embedded 1D",
             display = "1d", coord = data.frame(t = t),
             X = curve.high.X, f = curve.high.f),
        list(id = "surface_2d_embedded_p8",
             family = "homogeneous 2D manifold",
             display = "2d", coord = data.frame(u = u, v = v),
             X = surface.X, f = surface.f),
        list(id = "surface_2d_highdim_p24",
             family = "high-dimensional embedded 2D",
             display = "2d", coord = data.frame(u = u, v = v),
             X = surface.high.X, f = surface.high.f),
        list(id = "volume_3d_embedded_p12",
             family = "homogeneous 3D manifold",
             display = "table", coord = data.frame(a = a, b = b, c = cc),
             X = volume.X, f = volume.f),
        list(id = "surface_line_union_p8",
             family = "heterogeneous/non-manifold",
             display = "2d", coord = as.data.frame(nonmanifold.coord),
             X = nonmanifold.X, f = nonmanifold.f),
        list(id = "simplex_faces_p8",
             family = "OD-style simplex-boundary geometry",
             display = "table", coord = data.frame(face = face),
             X = simplex.X, f = simplex.f),
        list(id = "rank_blocks_p40",
             family = "rank/block heterogeneity",
             display = "table", coord = data.frame(z1 = z1, z2 = z2, z3 = z3),
             X = block.X, f = block.f)
    )
}

extract.chart.dim.summary <- function(fit) {
    tel <- fit$diagnostics$chart.dim
    if (is.null(tel) || is.null(tel$summary)) {
        return(list(min = NA_integer_, median = fit$chart.dim %||% NA_integer_,
                    max = NA_integer_, n.unique = NA_integer_))
    }
    list(
        min = tel$summary$min %||% NA_integer_,
        median = tel$summary$median %||% NA_real_,
        max = tel$summary$max %||% NA_integer_,
        n.unique = tel$summary$n.unique %||% NA_integer_
    )
}

fit.one <- function(ds, y, method.id) {
    common <- list(
        X = ds$X,
        y = y,
        support.grid = 15:35,
        degree.grid = 2L,
        kernel.grid = "gaussian",
        bandwidth.multiplier.grid = 1,
        coordinate.method = "local.pca",
        backend = "R",
        design.basis = "orthogonal.polynomial.drop",
        ridge.multiplier.grid = c(0, 1e-10),
        ridge.condition.max = Inf,
        cv.folds = 3L,
        cv.seed = 1701L
    )
    args <- switch(
        method.id,
        auto = c(common, list(chart.dim = "auto")),
        local_auto = c(common, list(chart.dim = "local.auto")),
        full_kd = c(common, list(chart.dim.grid = 1:8,
                                 selection.strategy = "grid")),
        plateau_kd = c(common, list(chart.dim.grid = 1:8,
                                    selection.strategy = "plateau_kd")),
        stop("Unknown method: ", method.id, call. = FALSE)
    )
    t0 <- proc.time()
    fit <- do.call(fit.lps, args)
    elapsed <- unname((proc.time() - t0)[["elapsed"]])
    pred <- as.numeric(fit$fitted.values)
    selected <- fit$selected
    dim.summary <- extract.chart.dim.summary(fit)
    list(
        fit = fit,
        predictions = pred,
        summary = data.frame(
            dataset.id = ds$id,
            dataset.family = ds$family,
            display = ds$display,
            method.id = method.id,
            status = "ok",
            truth.rmse = rmse(pred, ds$f),
            truth.mae = mae(pred, ds$f),
            truth.correlation = cor.safe(pred, ds$f),
            observed.rmse = rmse(pred, y),
            selected.support.size =
                selected$support.size[[1L]] %||% NA_integer_,
            selected.chart.dim =
                as.character(selected$chart.dim[[1L]] %||%
                                 fit$chart.dim[[1L]] %||% NA_character_),
            chart.dim.anchor.min = dim.summary$min,
            chart.dim.anchor.median = dim.summary$median,
            chart.dim.anchor.max = dim.summary$max,
            chart.dim.anchor.n.unique = dim.summary$n.unique,
            selected.cv.rmse =
                selected$cv.rmse.observed[[1L]] %||% NA_real_,
            elapsed.sec = elapsed,
            evaluated.candidates = nrow(fit$cv.table),
            planned.candidates =
                fit$diagnostics$coupled.kd.selection$planned.candidates %||%
                    nrow(fit$cv.table),
            error.message = "",
            stringsAsFactors = FALSE
        )
    )
}

run.comparison <- function() {
    datasets <- make.datasets()
    method.ids <- c("auto", "local_auto", "full_kd", "plateau_kd")
    summary.rows <- list()
    pred.rows <- list()
    dataset.rows <- list()
    fits <- list()
    rr <- 0L
    pp <- 0L
    dd <- 0L
    for (ds in datasets) {
        set.seed(88000L + match(ds$id, vapply(datasets, `[[`, "", "id")))
        noise.sd <- 0.05 * stats::sd(ds$f)
        y <- ds$f + stats::rnorm(length(ds$f), sd = noise.sd)
        dd <- dd + 1L
        dataset.rows[[dd]] <- data.frame(
            dataset.id = ds$id,
            dataset.family = ds$family,
            display = ds$display,
            n = nrow(ds$X),
            ambient.dim = ncol(ds$X),
            truth.sd = stats::sd(ds$f),
            noise.sd = noise.sd,
            stringsAsFactors = FALSE
        )
        base <- data.frame(
            dataset.id = ds$id,
            row.index = seq_len(nrow(ds$X)),
            truth = ds$f,
            observed = y,
            display = ds$display,
            stringsAsFactors = FALSE
        )
        coord <- as.data.frame(ds$coord)
        base$coord.1 <- if (ncol(coord) >= 1L) coord[[1L]] else NA_real_
        base$coord.2 <- if (ncol(coord) >= 2L) coord[[2L]] else NA_real_
        base$coord.3 <- if (ncol(coord) >= 3L) coord[[3L]] else NA_real_
        for (method.id in method.ids) {
            message("Fitting ", ds$id, " / ", method.id)
            result <- tryCatch(
                fit.one(ds, y, method.id),
                error = function(e) {
                    list(
                        fit = NULL,
                        predictions = rep(NA_real_, length(ds$f)),
                        summary = data.frame(
                            dataset.id = ds$id,
                            dataset.family = ds$family,
                            display = ds$display,
                            method.id = method.id,
                            status = "error",
                            truth.rmse = NA_real_,
                            truth.mae = NA_real_,
                            truth.correlation = NA_real_,
                            observed.rmse = NA_real_,
                            selected.support.size = NA_integer_,
                            selected.chart.dim = NA_character_,
                            chart.dim.anchor.min = NA_integer_,
                            chart.dim.anchor.median = NA_real_,
                            chart.dim.anchor.max = NA_integer_,
                            chart.dim.anchor.n.unique = NA_integer_,
                            selected.cv.rmse = NA_real_,
                            elapsed.sec = NA_real_,
                            evaluated.candidates = NA_integer_,
                            planned.candidates = NA_integer_,
                            error.message = conditionMessage(e),
                            stringsAsFactors = FALSE
                        )
                    )
                }
            )
            rr <- rr + 1L
            summary.rows[[rr]] <- result$summary
            pp <- pp + 1L
            pred <- base
            pred$method.id <- method.id
            pred$estimate <- result$predictions
            pred$residual.truth <- pred$estimate - pred$truth
            pred.rows[[pp]] <- pred
            fits[[paste(ds$id, method.id, sep = "::")]] <- result$fit
        }
    }
    list(
        run.generated.at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
        datasets = do.call(rbind, dataset.rows),
        scores = do.call(rbind, summary.rows),
        predictions = do.call(rbind, pred.rows),
        fits = fits,
        methods = method.ids
    )
}

res <- run.comparison()
saveRDS(res, file.path(run.root, "csd_plateau_kd_comparison_results.rds"))
utils::write.csv(res$datasets,
                 file.path(run.root, "csd_plateau_kd_datasets.csv"),
                 row.names = FALSE)
utils::write.csv(res$scores,
                 file.path(run.root, "csd_plateau_kd_scores.csv"),
                 row.names = FALSE)
utils::write.csv(res$predictions,
                 file.path(run.root, "csd_plateau_kd_predictions.csv"),
                 row.names = FALSE)

cat("Wrote CSD plateau-kd comparison results to:\n", run.root, "\n")
