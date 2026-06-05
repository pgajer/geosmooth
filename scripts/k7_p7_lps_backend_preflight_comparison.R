#!/usr/bin/env Rscript

`%||%` <- function(a, b) {
    if (is.null(a) || length(a) == 0L || all(is.na(a))) b else a
}

root <- paste(
    "/Users/pgajer/current_projects/trend_filtering/development/slpl_tf",
    "experiments/p7_prospective_synthetic_suite",
    sep = "/"
)
out.dir <- file.path(
    "/Users/pgajer/current_projects/geosmooth/split_handoffs",
    "k7_p7_lps_backend_preflight_comparison_2026-06-04"
)
dir.create(file.path(out.dir, "tables"), recursive = TRUE, showWarnings = FALSE)

source(file.path(root, "scripts", "p7_truth_materialization_helpers.R"))
source(file.path(root, "scripts", "p7_baseline_fitters.R"))

orchestrator.expr <- parse(
    file = file.path(root, "scripts", "run_p7e_prospective_orchestrator.R")
)
eval(orchestrator.expr[-length(orchestrator.expr)], envir = .GlobalEnv)

cfg <- p7e.parse.args(character())
cfg$root <- root
cfg$mode <- "preflight"
cfg$run.id <- "k7_lps_backend_preflight_comparison_20260604"
cfg$workers <- 1L
cfg$heavy.workers <- 1L
cfg$seed <- 20260602L
cfg$noise.sd <- 0.10
cfg$cv.folds <- 5L
cfg$maxsteps <- 1200L

registries <- p7e.read.registries(root)
row <- p7e.dataset.index(registries, "preflight")[1L, , drop = FALSE]
bundle <- p7e.materialize.dataset(row, cfg, registries)
method.bundle <- p7e.method.bundle(bundle)
support.grid <- p7e.support.grid(length(bundle$y), "baseline")

run.one <- function(backend) {
    start <- proc.time()[["elapsed"]]
    fit <- p7.fit.lps(
        X = method.bundle$X,
        y = method.bundle$y,
        foldid = method.bundle$foldid,
        support.grid = support.grid,
        degree.grid = c(1L, 2L),
        kernel.grid = c("gaussian", "tricube"),
        cv.folds = cfg$cv.folds,
        coordinate.method = "local.pca",
        chart.dim = "auto",
        backend = backend,
        auto.chart.support.metric = "both",
        auto.chart.selection.metric = "operator"
    )
    elapsed <- proc.time()[["elapsed"]] - start
    fit$k7.runtime.seconds <- elapsed
    fit
}

fits <- list(
    auto = run.one("auto"),
    cpp.local.pca = run.one("cpp.local.pca")
)

summary.rows <- lapply(names(fits), function(id) {
    fit <- fits[[id]]
    selected <- fit$selected[1L, , drop = FALSE]
    data.frame(
        run.label = id,
        dataset.id = bundle$dataset.id,
        geometry.id = bundle$geometry.id,
        truth.id = bundle$truth.id,
        n = length(bundle$y),
        ambient.dimension = ncol(bundle$X),
        support.grid = paste(support.grid, collapse = ","),
        coordinate.method = fit$coordinate.method %||% NA_character_,
        requested.chart.dim = fit$requested.chart.dim %||% NA_character_,
        chart.dim = fit$chart.dim %||% NA_integer_,
        local.chart.method = fit$local.chart.method %||% NA_character_,
        local.chart.method.effective =
            fit$local.chart.method.effective %||% NA_character_,
        backend.requested = fit$backend %||% NA_character_,
        backend.used = fit$backend.used %||% NA_character_,
        selected.support.size = selected$support.size %||% NA_integer_,
        selected.degree = selected$degree %||% NA_integer_,
        selected.kernel = selected$kernel %||% NA_character_,
        selected.cv.rmse.observed =
            selected$cv.rmse.observed %||% NA_real_,
        observed.rmse = p7.rmse(fit$fitted.values, bundle$y),
        truth.rmse = p7.rmse(fit$fitted.values, bundle$f.truth),
        runtime.seconds = fit$k7.runtime.seconds,
        selected.parameters =
            p7e.baseline.selected.parameters("lps_local_pca_cv", fit),
        stringsAsFactors = FALSE
    )
})
summary <- do.call(rbind, summary.rows)
rownames(summary) <- NULL

cv.tables <- lapply(names(fits), function(id) {
    tab <- fits[[id]]$cv.table
    tab$run.label <- id
    tab
})
cv.all <- do.call(rbind, cv.tables)
rownames(cv.all) <- NULL

cv.wide <- merge(
    fits$auto$cv.table,
    fits$cpp.local.pca$cv.table,
    by = c("support.size", "degree", "kernel"),
    suffixes = c(".auto", ".cpp"),
    all = TRUE
)
for (nm in c("cv.rmse.observed", "cv.se.observed")) {
    a <- paste0(nm, ".auto")
    b <- paste0(nm, ".cpp")
    if (all(c(a, b) %in% names(cv.wide))) {
        cv.wide[[paste0(nm, ".delta.cpp.minus.auto")]] <-
            cv.wide[[b]] - cv.wide[[a]]
    }
}

fitted.delta <- data.frame(
    dataset.id = bundle$dataset.id,
    max.abs.fitted.delta =
        max(abs(fits$cpp.local.pca$fitted.values - fits$auto$fitted.values)),
    rmse.fitted.delta =
        p7.rmse(fits$cpp.local.pca$fitted.values, fits$auto$fitted.values),
    stringsAsFactors = FALSE
)

utils::write.csv(summary, file.path(out.dir, "tables", "k7_lps_backend_summary.csv"),
                 row.names = FALSE)
utils::write.csv(cv.all, file.path(out.dir, "tables", "k7_lps_backend_cv_tables_long.csv"),
                 row.names = FALSE)
utils::write.csv(cv.wide, file.path(out.dir, "tables", "k7_lps_backend_cv_table_comparison.csv"),
                 row.names = FALSE)
utils::write.csv(fitted.delta, file.path(out.dir, "tables", "k7_lps_backend_fitted_delta.csv"),
                 row.names = FALSE)
saveRDS(fits, file.path(out.dir, "k7_lps_backend_fits.rds"))
saveRDS(bundle, file.path(out.dir, "k7_preflight_dataset_bundle.rds"))

cat("K7 P7 LPS backend preflight comparison complete.\n")
cat("Output directory:", out.dir, "\n")
print(summary[, c("run.label", "backend.used", "selected.support.size",
                  "selected.degree", "selected.kernel",
                  "selected.cv.rmse.observed", "truth.rmse",
                  "runtime.seconds")])
print(fitted.delta)
