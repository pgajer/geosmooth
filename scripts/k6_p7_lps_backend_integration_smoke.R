#!/usr/bin/env Rscript

repo <- "/Users/pgajer/current_projects/geosmooth"
p7.scripts <- paste(
    "/Users/pgajer/current_projects/trend_filtering/development/slpl_tf",
    "experiments/p7_prospective_synthetic_suite/scripts",
    sep = "/"
)

if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("pkgload is required for the K6 smoke test.", call. = FALSE)
}
pkgload::load_all(repo, quiet = TRUE)
source(file.path(p7.scripts, "p7_baseline_fitters.R"))

set.seed(20260604)
n <- 24L
theta <- seq(0, 2 * pi, length.out = n + 1L)[seq_len(n)]
X <- cbind(cos(theta), sin(theta))
y <- sin(theta) + 0.05 * rnorm(n)
foldid <- rep(seq_len(4L), length.out = n)

fit.r <- p7.fit.lps(
    X = X,
    y = y,
    foldid = foldid,
    support.grid = 8L,
    degree.grid = 1L,
    kernel.grid = "gaussian",
    coordinate.method = "local.pca",
    chart.dim = 1L,
    backend = "auto"
)
if (!identical(fit.r$backend.used, "R")) {
    stop("Expected local-PCA LPS auto backend to use R reference path.",
         call. = FALSE)
}

fit.cpp <- p7.fit.lps(
    X = X,
    y = y,
    foldid = foldid,
    support.grid = 8L,
    degree.grid = 1L,
    kernel.grid = "gaussian",
    coordinate.method = "local.pca",
    chart.dim = 1L,
    backend = "cpp.local.pca"
)
if (!identical(fit.cpp$backend.used, "cpp.local.pca")) {
    stop("Expected explicit local-PCA LPS backend to use cpp.local.pca.",
         call. = FALSE)
}

fit.coords <- p7.fit.lps(
    X = X,
    y = y,
    foldid = foldid,
    support.grid = 8L,
    degree.grid = 1L,
    kernel.grid = "gaussian",
    coordinate.method = "coordinates",
    backend = "auto"
)
if (!identical(fit.coords$backend.used, "cpp")) {
    stop("Expected ambient-coordinate LPS auto backend to use cpp.",
         call. = FALSE)
}

orchestrator <- file.path(p7.scripts, "run_p7e_prospective_orchestrator.R")
invisible(parse(file = orchestrator))

cat("K6 P7 LPS backend integration smoke passed.\n")
