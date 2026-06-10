#!/usr/bin/env Rscript

parse.args <- function(args) {
    out <- list()
    for (arg in args) {
        if (!grepl("^--", arg)) next
        kv <- strsplit(sub("^--", "", arg), "=", fixed = TRUE)[[1L]]
        out[[kv[[1L]]]] <- if (length(kv) > 1L) {
            paste(kv[-1L], collapse = "=")
        } else {
            TRUE
        }
    }
    out
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L) y else x

args <- parse.args(commandArgs(trailingOnly = TRUE))
repo <- normalizePath(args$repo %||%
    file.path(Sys.getenv("HOME"), "current_projects", "geosmooth"),
    mustWork = TRUE)
run.id <- args$run_id %||%
    paste0("lps_binary_gm_ff_runtime_smoke_", format(Sys.time(), "%Y%m%d_%H%M%S"))
run.dir <- file.path(repo, "split_handoffs", run.id)
dir.create(file.path(run.dir, "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(run.dir, "logs"), recursive = TRUE, showWarnings = FALSE)

suppressPackageStartupMessages({
    if (!requireNamespace("pkgload", quietly = TRUE)) {
        stop("Package 'pkgload' is required for this smoke script.", call. = FALSE)
    }
})
pkgload::load_all(repo, quiet = TRUE)

timestamp <- function() {
    format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z", tz = "America/New_York")
}

stable.z <- function(f, clip = 4) {
    center <- stats::median(f, na.rm = TRUE)
    scale <- stats::mad(f, center = center, constant = 1, na.rm = TRUE)
    if (!is.finite(scale) || scale <= 0) scale <- stats::sd(f, na.rm = TRUE)
    if (!is.finite(scale) || scale <= 0) scale <- 1
    pmax(-clip, pmin(clip, (f - center) / scale))
}

probability.profile <- function(f, transform = "signed",
                                target.prevalence = 0.5,
                                slope = 1.25,
                                p.floor = 0.02,
                                z.clip = 4) {
    z <- stable.z(f, clip = z.clip)
    h <- switch(
        transform,
        signed = z,
        tail = abs(z),
        central = -abs(z),
        stop("Unknown transform.", call. = FALSE)
    )
    h <- h - stats::median(h, na.rm = TRUE)
    mean.p <- function(alpha) {
        mean(p.floor + (1 - 2 * p.floor) * stats::plogis(alpha + slope * h))
    }
    alpha <- stats::uniroot(
        function(a) mean.p(a) - target.prevalence,
        interval = c(-50, 50)
    )$root
    p <- p.floor + (1 - 2 * p.floor) * stats::plogis(alpha + slope * h)
    as.numeric(p)
}

lhs <- function(n, d, seed) {
    set.seed(seed)
    out <- matrix(NA_real_, n, d)
    for (j in seq_len(d)) {
        out[, j] <- (sample.int(n) - stats::runif(n)) / n
    }
    out
}

make.geometry <- function(block, n, seed) {
    if (identical(block, "1d_native_interval")) {
        set.seed(seed)
        u <- sort(stats::runif(n))
        return(list(X = matrix(u, ncol = 1L), latent = matrix(u, ncol = 1L)))
    }
    if (identical(block, "2d_native_square")) {
        uv <- lhs(n, 2L, seed)
        return(list(X = uv, latent = uv))
    }
    if (identical(block, "2d_highdim_diag100")) {
        uv <- lhs(n, 2L, seed)
        set.seed(seed + 1000L)
        X <- cbind(matrix(rep(uv[, 1L], 50L), ncol = 50L),
                   matrix(rep(uv[, 2L], 50L), ncol = 50L))
        X <- X + matrix(stats::rnorm(n * 100L, sd = 0.01), n, 100L)
        X <- scale(X)
        return(list(X = X, latent = uv))
    }
    if (identical(block, "3d_native_cube")) {
        uvw <- lhs(n, 3L, seed)
        return(list(X = uvw, latent = uvw))
    }
    if (identical(block, "3d_highdim_diag99")) {
        uvw <- lhs(n, 3L, seed)
        set.seed(seed + 2000L)
        X <- cbind(matrix(rep(uvw[, 1L], 33L), ncol = 33L),
                   matrix(rep(uvw[, 2L], 33L), ncol = 33L),
                   matrix(rep(uvw[, 3L], 33L), ncol = 33L))
        X <- X + matrix(stats::rnorm(n * 99L, sd = 0.01), n, 99L)
        X <- scale(X)
        return(list(X = X, latent = uvw))
    }
    stop("Unknown geometry block: ", block, call. = FALSE)
}

gaussian.truth <- function(latent, k) {
    d <- ncol(latent)
    centers <- switch(
        paste0(d, "d_", k),
        "1d_2" = matrix(c(0.30, 0.76), ncol = 1L),
        "1d_3" = matrix(c(0.25, 0.55, 0.82), ncol = 1L),
        "1d_4" = matrix(c(0.18, 0.42, 0.68, 0.88), ncol = 1L),
        "2d_2" = matrix(c(0.30, 0.34, 0.68, 0.70), ncol = 2L, byrow = TRUE),
        "2d_3" = matrix(c(0.20, 0.32, 0.58, 0.72, 0.82, 0.24), ncol = 2L, byrow = TRUE),
        "2d_4" = matrix(c(0.18, 0.22, 0.38, 0.78, 0.70, 0.32, 0.84, 0.76), ncol = 2L, byrow = TRUE),
        "3d_2" = matrix(c(0.25, 0.30, 0.35, 0.72, 0.68, 0.62), ncol = 3L, byrow = TRUE),
        "3d_3" = matrix(c(0.20, 0.25, 0.35, 0.62, 0.70, 0.28, 0.78, 0.30, 0.72), ncol = 3L, byrow = TRUE),
        "3d_4" = matrix(c(0.20, 0.25, 0.35, 0.60, 0.72, 0.30, 0.78, 0.30, 0.72, 0.44, 0.50, 0.84), ncol = 3L, byrow = TRUE),
        stop("Unsupported dimension/components combination.", call. = FALSE)
    )
    amps <- switch(as.character(k),
                   "2" = c(1.00, 0.70),
                   "3" = c(1.00, 0.75, 0.55),
                   "4" = c(1.00, 0.78, 0.60, 0.45))
    bw <- switch(as.character(d),
                 "1" = rep(0.075, k),
                 "2" = rep(0.13, k),
                 "3" = rep(0.16, k))
    f <- numeric(nrow(latent))
    for (j in seq_len(k)) {
        dif <- sweep(latent, 2L, centers[j, ], "-")
        f <- f + amps[[j]] * exp(-rowSums(dif^2) / (2 * bw[[j]]^2))
    }
    as.numeric(scale(f))
}

make.folds <- function(n, k = 5L, seed = 1L) {
    set.seed(seed)
    sample(rep(seq_len(k), length.out = n))
}

truth.rmse <- function(pred, p) sqrt(mean((as.numeric(pred) - p)^2))
brier <- function(pred, p) mean((as.numeric(pred) - p)^2)
logloss <- function(pred, y, eps = 1e-12) {
    pred <- pmin(1 - eps, pmax(eps, as.numeric(pred)))
    -mean(y * log(pred) + (1 - y) * log(1 - pred))
}

geometry.blocks <- strsplit(args$geometry_blocks %||%
    "1d_native_interval,2d_native_square,2d_highdim_diag100,3d_highdim_diag99",
    ",", fixed = TRUE)[[1L]]
sample.sizes <- as.integer(strsplit(args$sample_sizes %||% "250,500,1000",
                                    ",", fixed = TRUE)[[1L]])
k.values <- as.integer(strsplit(args$gaussian_components %||% "3",
                                ",", fixed = TRUE)[[1L]])
profiles <- data.frame(
    profile = c("balanced_signed_smooth"),
    transform = c("signed"),
    prevalence = c(0.50),
    stringsAsFactors = FALSE
)
if (isTRUE(as.logical(args$include_all_profiles %||% FALSE))) {
    profiles <- data.frame(
        profile = c("balanced_signed_smooth",
                    "low_prevalence_signed_smooth",
                    "balanced_tail_smooth",
                    "low_prevalence_central_smooth"),
        transform = c("signed", "signed", "tail", "central"),
        prevalence = c(0.50, 0.20, 0.50, 0.20),
        stringsAsFactors = FALSE
    )
}
chart.rules <- c("auto", "local.auto")
methods <- data.frame(
    method.id = c("lps_bernoulli_brier", "lps_binomial_logistic"),
    outcome.family = c("bernoulli", "binomial"),
    selection.score = c("cv.brier.observed", "cv.logloss.observed"),
    stringsAsFactors = FALSE
)

rows <- list()
task.id <- 0L
for (block in geometry.blocks) {
    for (n in sample.sizes) {
        for (kk in k.values) {
            for (pp in seq_len(nrow(profiles))) {
                for (chart in chart.rules) {
                    for (mm in seq_len(nrow(methods))) {
                        task.id <- task.id + 1L
                        rows[[task.id]] <- data.frame(
                            task.id = sprintf("smoke_%03d", task.id),
                            geometry.block = block,
                            sample.n = n,
                            gaussian.components = kk,
                            probability.profile = profiles$profile[[pp]],
                            profile.transform = profiles$transform[[pp]],
                            target.prevalence = profiles$prevalence[[pp]],
                            chart.dim.rule = chart,
                            method.id = methods$method.id[[mm]],
                            outcome.family = methods$outcome.family[[mm]],
                            selection.score = methods$selection.score[[mm]],
                            seed = 20260608L + task.id,
                            stringsAsFactors = FALSE
                        )
                    }
                }
            }
        }
    }
}
tasks <- do.call(rbind, rows)
utils::write.csv(tasks, file.path(run.dir, "task_manifest.csv"), row.names = FALSE)

run.task <- function(row) {
    start <- proc.time()[["elapsed"]]
    status <- "ok"
    message <- ""
    selected <- list()
    metrics <- list()
    tryCatch({
        geom <- make.geometry(row$geometry.block, row$sample.n, row$seed)
        f <- gaussian.truth(geom$latent, row$gaussian.components)
        p <- probability.profile(
            f,
            transform = row$profile.transform,
            target.prevalence = row$target.prevalence
        )
        set.seed(row$seed + 50000L)
        y <- stats::rbinom(length(p), size = 1L, prob = p)
        foldid <- make.folds(length(p), seed = row$seed + 70000L)
        fit <- fit.lps(
            geom$X,
            y,
            foldid = foldid,
            support.grid = 15:35,
            degree.grid = 1:2,
            kernel.grid = "tricube",
            cv.folds = 5L,
            cv.seed = row$seed + 90000L,
            coordinate.method = "local.pca",
            chart.dim = row$chart.dim.rule,
            auto.chart.support.metric = "both",
            auto.chart.selection.metric = "operator",
            backend = "R",
            design.basis = "orthogonal.polynomial.drop",
            design.drop.tol = 1e-8,
            ridge.multiplier.grid = c(0, 1e-10, 1e-8),
            ridge.condition.max = 1e12,
            unstable.action = "mean",
            outcome.family = row$outcome.family
        )
        pred <- pmin(1, pmax(0, as.numeric(fit$fitted.values)))
        selected <- fit$selected
        metrics <- list(
            truth.rmse = truth.rmse(pred, p),
            brier.truth = brier(pred, p),
            observed.logloss = logloss(pred, y),
            selected.support.size = selected$support.size[[1L]] %||% NA,
            selected.degree = selected$degree[[1L]] %||% NA,
            selected.kernel = selected$kernel[[1L]] %||% NA,
            selected.score = selected[[row$selection.score]][[1L]] %||% NA_real_,
            logistic.cv.fallbacks = fit$logistic.diagnostics$cv$fallback.event.rate %||% NA_integer_,
            logistic.final.fallbacks = fit$logistic.diagnostics$final$fallback.event.rate %||% NA_integer_
        )
    }, error = function(e) {
        status <<- "error"
        message <<- conditionMessage(e)
    })
    elapsed <- proc.time()[["elapsed"]] - start
    data.frame(
        row,
        status = status,
        error.message = message,
        elapsed.sec = elapsed,
        truth.rmse = metrics$truth.rmse %||% NA_real_,
        brier.truth = metrics$brier.truth %||% NA_real_,
        observed.logloss = metrics$observed.logloss %||% NA_real_,
        selected.support.size = metrics$selected.support.size %||% NA,
        selected.degree = metrics$selected.degree %||% NA,
        selected.kernel = metrics$selected.kernel %||% NA,
        selected.score = metrics$selected.score %||% NA_real_,
        logistic.cv.fallbacks = metrics$logistic.cv.fallbacks %||% NA,
        logistic.final.fallbacks = metrics$logistic.final.fallbacks %||% NA,
        stringsAsFactors = FALSE
    )
}

cat("Run directory:", run.dir, "\n")
cat("Planned smoke tasks:", nrow(tasks), "\n")
results <- vector("list", nrow(tasks))
for (ii in seq_len(nrow(tasks))) {
    cat(sprintf("[%s] %d/%d %s n=%d %s %s\n",
                timestamp(), ii, nrow(tasks), tasks$geometry.block[[ii]],
                tasks$sample.n[[ii]], tasks$chart.dim.rule[[ii]],
                tasks$method.id[[ii]]))
    results[[ii]] <- run.task(tasks[ii, , drop = FALSE])
    utils::write.csv(do.call(rbind, results[seq_len(ii)]),
                     file.path(run.dir, "tables", "runtime_smoke_results_partial.csv"),
                     row.names = FALSE)
}
res <- do.call(rbind, results)
utils::write.csv(res, file.path(run.dir, "tables", "runtime_smoke_results.csv"),
                 row.names = FALSE)

ok <- res[res$status == "ok" & is.finite(res$elapsed.sec), , drop = FALSE]
summary.by <- function(cols) {
    if (!nrow(ok)) return(data.frame())
    aggregate(
        list(
            n.ok = ok$elapsed.sec,
            elapsed.median.sec = ok$elapsed.sec,
            elapsed.mean.sec = ok$elapsed.sec,
            elapsed.p90.sec = ok$elapsed.sec
        ),
        by = ok[, cols, drop = FALSE],
        FUN = function(x) c(length = length(x),
                            median = stats::median(x),
                            mean = mean(x),
                            p90 = as.numeric(stats::quantile(x, 0.9)))
    )
}

summ <- aggregate(
    elapsed.sec ~ sample.n + method.id + chart.dim.rule,
    ok,
    function(x) c(n = length(x), median = median(x), mean = mean(x),
                  p90 = as.numeric(stats::quantile(x, 0.9)))
)
flatten.aggregate <- function(x) {
    out <- data.frame(x[, seq_len(ncol(x) - 1L), drop = FALSE])
    mat <- as.data.frame(x[[ncol(x)]])
    colnames(mat) <- paste0(names(x)[[ncol(x)]], ".", colnames(mat))
    cbind(out, mat)
}
summ.flat <- flatten.aggregate(summ)
utils::write.csv(summ.flat, file.path(run.dir, "tables",
                                      "runtime_by_sample_method_chart.csv"),
                 row.names = FALSE)

overall.median <- stats::median(ok$elapsed.sec)
overall.mean <- mean(ok$elapsed.sec)
full.scenarios <- 288L
full.tasks <- full.scenarios * 10L * 2L * 2L
estimate <- data.frame(
    planned.full.scenario.cells = full.scenarios,
    planned.full.tasks = full.tasks,
    smoke.tasks = nrow(res),
    smoke.ok.tasks = nrow(ok),
    smoke.error.tasks = sum(res$status != "ok"),
    overall.median.sec.per.task = overall.median,
    overall.mean.sec.per.task = overall.mean,
    serial.hours.median = full.tasks * overall.median / 3600,
    serial.hours.mean = full.tasks * overall.mean / 3600,
    parallel.hours.12w.median = full.tasks * overall.median / 3600 / 12,
    parallel.hours.12w.mean = full.tasks * overall.mean / 3600 / 12
)
utils::write.csv(estimate, file.path(run.dir, "tables",
                                     "full_tier_runtime_estimate.csv"),
                 row.names = FALSE)

readme <- c(
    "# LPS-BIN-GM-FF Runtime Smoke",
    "",
    paste0("Generated: ", timestamp()),
    "",
    paste0("Run directory: `", run.dir, "`"),
    "",
    "This smoke uses the planned heavy LPS binary candidate grid:",
    "",
    "- `support.grid = 15:35`",
    "- `degree.grid = 1:2`",
    "- `kernel.grid = \"tricube\"`",
    "- `design.basis = \"orthogonal.polynomial.drop\"`",
    "- `ridge.multiplier.grid = c(0, 1e-10, 1e-8)`",
    "- `chart.dim = \"auto\"` and `\"local.auto\"`",
    "- `outcome.family = \"bernoulli\"` and `\"binomial\"`",
    "",
    "The smoke is intended for runtime extrapolation to the full proposed",
    "`LPS-BIN-GM-FF` tier, not for performance claims.",
    "",
    "Key outputs:",
    "",
    "- `task_manifest.csv`",
    "- `tables/runtime_smoke_results.csv`",
    "- `tables/runtime_by_sample_method_chart.csv`",
    "- `tables/full_tier_runtime_estimate.csv`"
)
writeLines(readme, file.path(run.dir, "README.md"))

cat("\nRuntime estimate:\n")
print(estimate)
cat("\nWrote:", run.dir, "\n")
