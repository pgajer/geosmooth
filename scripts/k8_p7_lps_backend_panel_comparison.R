#!/usr/bin/env Rscript

`%||%` <- function(a, b) {
    if (is.null(a) || length(a) == 0L || all(is.na(a))) b else a
}

timestamp <- function() {
    format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z", tz = "America/New_York")
}

root <- paste(
    "/Users/pgajer/current_projects/trend_filtering/development/slpl_tf",
    "experiments/p7_prospective_synthetic_suite",
    sep = "/"
)
out.dir <- file.path(
    "/Users/pgajer/current_projects/geosmooth/split_handoffs",
    "k8_p7_lps_backend_panel_comparison_2026-06-04"
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
cfg$mode <- "full"
cfg$run.id <- "k8_lps_backend_panel_comparison_20260604"
cfg$workers <- 1L
cfg$heavy.workers <- 1L
cfg$seed <- 20260602L
cfg$noise.sd <- 0.10
cfg$cv.folds <- 5L
cfg$maxsteps <- 1200L

registries <- p7e.read.registries(root)
all.rows <- p7e.dataset.index(registries, "full")

controlled.truth.ids <- c(
    "p7d_1d_two_gaussian_v1",
    "p7d_square_aniso_three_gaussian_v1",
    "p7d_paraboloid_latent_three_gaussian_v1",
    "p7d_saddle_latent_three_gaussian_v1",
    "p7d_3d_four_gaussian_v1",
    "p7d_hd1_latent_two_gaussian_v1",
    "p7d_hd2_latent_three_gaussian_v1",
    "p7d_hd3_latent_four_gaussian_v1"
)
real16s.truth.ids <- c("p7d_16s_graph_gaussian_farthest3_v1")

panel <- all.rows[all.rows$truth_id %in% controlled.truth.ids, , drop = FALSE]
panel$k8.panel <- "controlled_full_p7_grid"

real.rows <- all.rows[all.rows$truth_id %in% real16s.truth.ids, , drop = FALSE]
if (nrow(real.rows)) {
    real.rows$k8.panel <- "real16s_quick_smoke_reduced_grid"
    panel <- rbind(panel, real.rows)
}
panel <- panel[match(c(controlled.truth.ids, real16s.truth.ids),
                     panel$truth_id, nomatch = 0L), , drop = FALSE]

run.fit <- function(method.bundle, bundle, support.grid, backend) {
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
    fit$k8.runtime.seconds <- proc.time()[["elapsed"]] - start
    fit
}

summarize.fit <- function(fit, bundle, support.grid, run.label) {
    selected <- fit$selected[1L, , drop = FALSE]
    data.frame(
        run.label = run.label,
        dataset.id = bundle$dataset.id,
        geometry.id = bundle$geometry.id,
        truth.id = bundle$truth.id,
        geometry.family = bundle$geometry.family,
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
        runtime.seconds = fit$k8.runtime.seconds,
        stringsAsFactors = FALSE
    )
}

compare.dataset <- function(row) {
    cat("[", timestamp(), "] K8 dataset ", row$dataset_id[[1L]], "\n", sep = "")
    bundle <- p7e.materialize.dataset(row, cfg, registries)
    method.bundle <- p7e.method.bundle(bundle)
    support.grid <- p7e.support.grid(length(bundle$y), "baseline")
    grid.policy <- "p7_baseline_full_grid"
    if (identical(row$k8.panel[[1L]], "real16s_quick_smoke_reduced_grid")) {
        support.grid <- sort(unique(pmin(length(bundle$y), c(15L, 25L, 35L))))
        grid.policy <- "reduced_grid_for_real16s_smoke"
    }

    auto <- tryCatch(run.fit(method.bundle, bundle, support.grid, "auto"),
                     error = function(e) e)
    cpp <- tryCatch(run.fit(method.bundle, bundle, support.grid, "cpp.local.pca"),
                    error = function(e) e)

    if (inherits(auto, "error") || inherits(cpp, "error")) {
        return(list(
            summary = data.frame(
                dataset.id = bundle$dataset.id,
                geometry.id = bundle$geometry.id,
                truth.id = bundle$truth.id,
                geometry.family = bundle$geometry.family,
                k8.panel = row$k8.panel[[1L]],
                grid.policy = grid.policy,
                comparison.status = "failed",
                failure.auto = if (inherits(auto, "error")) {
                    conditionMessage(auto)
                } else {
                    ""
                },
                failure.cpp = if (inherits(cpp, "error")) {
                    conditionMessage(cpp)
                } else {
                    ""
                },
                stringsAsFactors = FALSE
            ),
            cv = data.frame(),
            delta = data.frame(),
            fits = list(auto = auto, cpp.local.pca = cpp)
        ))
    }

    summary <- rbind(
        summarize.fit(auto, bundle, support.grid, "auto"),
        summarize.fit(cpp, bundle, support.grid, "cpp.local.pca")
    )
    summary$k8.panel <- row$k8.panel[[1L]]
    summary$grid.policy <- grid.policy

    cv.auto <- auto$cv.table
    cv.cpp <- cpp$cv.table
    cv.auto$run.label <- "auto"
    cv.cpp$run.label <- "cpp.local.pca"
    cv <- rbind(cv.auto, cv.cpp)
    cv$dataset.id <- bundle$dataset.id

    cv.wide <- merge(
        auto$cv.table,
        cpp$cv.table,
        by = c("support.size", "degree", "kernel"),
        suffixes = c(".auto", ".cpp"),
        all = TRUE
    )
    cv.wide$dataset.id <- bundle$dataset.id
    cv.delta <- cv.wide$cv.rmse.observed.cpp - cv.wide$cv.rmse.observed.auto

    selected.same <- identical(
        as.list(summary[summary$run.label == "auto",
                        c("selected.support.size", "selected.degree",
                          "selected.kernel")]),
        as.list(summary[summary$run.label == "cpp.local.pca",
                        c("selected.support.size", "selected.degree",
                          "selected.kernel")])
    )
    fitted.delta <- cpp$fitted.values - auto$fitted.values
    truth.delta <- summary$truth.rmse[summary$run.label == "cpp.local.pca"] -
        summary$truth.rmse[summary$run.label == "auto"]
    runtime.speedup <- summary$runtime.seconds[summary$run.label == "auto"] /
        summary$runtime.seconds[summary$run.label == "cpp.local.pca"]
    max.cv.delta <- max(abs(cv.delta), na.rm = TRUE)
    max.fitted.delta <- max(abs(fitted.delta), na.rm = TRUE)
    class <- if (!selected.same) {
        "selected_candidate_drift"
    } else if (max.cv.delta > 1e-8 || max.fitted.delta > 1e-8 ||
               abs(truth.delta) > 1e-8) {
        "numeric_drift_selected_stable"
    } else {
        "safe_machine_precision"
    }

    delta <- data.frame(
        dataset.id = bundle$dataset.id,
        geometry.id = bundle$geometry.id,
        truth.id = bundle$truth.id,
        geometry.family = bundle$geometry.family,
        k8.panel = row$k8.panel[[1L]],
        grid.policy = grid.policy,
        n = length(bundle$y),
        ambient.dimension = ncol(bundle$X),
        candidate.count = nrow(auto$cv.table),
        selected.same = selected.same,
        max.abs.cv.rmse.delta = max.cv.delta,
        mean.abs.cv.rmse.delta = mean(abs(cv.delta), na.rm = TRUE),
        max.abs.fitted.delta = max.fitted.delta,
        rmse.fitted.delta = p7.rmse(cpp$fitted.values, auto$fitted.values),
        truth.rmse.delta.cpp.minus.auto = truth.delta,
        runtime.auto.seconds =
            summary$runtime.seconds[summary$run.label == "auto"],
        runtime.cpp.seconds =
            summary$runtime.seconds[summary$run.label == "cpp.local.pca"],
        runtime.speedup.auto.over.cpp = runtime.speedup,
        comparison.status = class,
        stringsAsFactors = FALSE
    )

    list(
        summary = summary,
        cv = cv,
        delta = delta,
        fits = list(auto = auto, cpp.local.pca = cpp)
    )
}

results <- lapply(seq_len(nrow(panel)), function(i) {
    compare.dataset(panel[i, , drop = FALSE])
})

summary <- do.call(rbind, lapply(results, `[[`, "summary"))
cv <- do.call(rbind, lapply(results, `[[`, "cv"))
delta <- do.call(rbind, lapply(results, `[[`, "delta"))

utils::write.csv(panel, file.path(out.dir, "tables", "k8_dataset_panel.csv"),
                 row.names = FALSE)
utils::write.csv(summary, file.path(out.dir, "tables", "k8_lps_backend_summary_long.csv"),
                 row.names = FALSE)
utils::write.csv(cv, file.path(out.dir, "tables", "k8_lps_backend_cv_tables_long.csv"),
                 row.names = FALSE)
utils::write.csv(delta, file.path(out.dir, "tables", "k8_lps_backend_delta_summary.csv"),
                 row.names = FALSE)
saveRDS(results, file.path(out.dir, "k8_lps_backend_results.rds"))

safe.html <- function(x) {
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x
}

fmt <- function(x, digits = 4) {
    ifelse(is.na(x), "", format(signif(x, digits), scientific = FALSE))
}

table.html <- function(x, cols = names(x), max.rows = Inf) {
    y <- x[, cols, drop = FALSE]
    if (nrow(y) > max.rows) y <- y[seq_len(max.rows), , drop = FALSE]
    rows <- apply(y, 1L, function(r) {
        paste0("<tr>", paste0("<td>", safe.html(r), "</td>", collapse = ""),
               "</tr>")
    })
    paste0(
        "<table><thead><tr>",
        paste0("<th>", safe.html(cols), "</th>", collapse = ""),
        "</tr></thead><tbody>",
        paste(rows, collapse = "\n"),
        "</tbody></table>"
    )
}

delta.display <- delta
for (nm in names(delta.display)) {
    if (is.numeric(delta.display[[nm]])) delta.display[[nm]] <- fmt(delta.display[[nm]])
}
summary.display <- summary
for (nm in names(summary.display)) {
    if (is.numeric(summary.display[[nm]])) summary.display[[nm]] <- fmt(summary.display[[nm]])
}

html.path <- file.path(out.dir, "k8_p7_lps_backend_panel_comparison.html")
status.counts <- as.data.frame(table(delta$comparison.status),
                               stringsAsFactors = FALSE)
names(status.counts) <- c("comparison.status", "dataset.count")
speedup.median <- stats::median(delta$runtime.speedup.auto.over.cpp,
                                na.rm = TRUE)
max.cv <- max(delta$max.abs.cv.rmse.delta, na.rm = TRUE)
max.fit <- max(delta$max.abs.fitted.delta, na.rm = TRUE)
max.truth <- max(abs(delta$truth.rmse.delta.cpp.minus.auto), na.rm = TRUE)
html <- paste0(
    "<!doctype html><html><head><meta charset='utf-8'>",
    "<title>K8 P7 LPS Backend Panel Comparison</title>",
    "<style>",
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;",
    "line-height:1.45;margin:32px;color:#1f2933;max-width:1180px}",
    "h1,h2{line-height:1.15} table{border-collapse:collapse;width:100%;",
    "font-size:13px;margin:14px 0 24px} th,td{border:1px solid #d8dee9;",
    "padding:6px 8px;text-align:left;vertical-align:top} th{background:#edf2f7}",
    ".ok{color:#156b3a;font-weight:700}.warn{color:#9a5700;font-weight:700}",
    ".note{background:#f7fafc;border-left:4px solid #94a3b8;padding:10px 14px}",
    "</style></head><body>",
    "<h1>K8 P7 LPS Backend Panel Comparison</h1>",
    "<p>Generated: ", safe.html(timestamp()), "</p>",
    "<div class='note'><p><strong>Question.</strong> Does explicit ",
    "<code>backend = &quot;cpp.local.pca&quot;</code> reproduce the current ",
    "local-PCA LPS R-reference path across a diverse P7 panel, while improving ",
    "runtime?</p></div>",
    "<h2>Answer</h2>",
    "<p class='", if (all(delta$comparison.status == "safe_machine_precision")) {
        "ok"
    } else {
        "warn"
    }, "'>",
    if (all(delta$comparison.status == "safe_machine_precision")) {
        "All K8 comparisons matched to machine precision."
    } else {
        "At least one K8 comparison showed drift or failure."
    },
    "</p>",
    "<p>Median R/native runtime ratio: <strong>", fmt(speedup.median),
    "x</strong>. Max absolute CV-RMSE delta: <strong>", fmt(max.cv, 5),
    "</strong>. Max absolute fitted-value delta: <strong>", fmt(max.fit, 5),
    "</strong>. Max absolute Truth-RMSE delta: <strong>", fmt(max.truth, 5),
    "</strong>.</p>",
    "<h2>Status Counts</h2>",
    table.html(status.counts),
    "<h2>Dataset Delta Summary</h2>",
    table.html(delta.display, cols = c(
        "dataset.id", "geometry.family", "k8.panel", "grid.policy",
        "candidate.count", "selected.same", "max.abs.cv.rmse.delta",
        "max.abs.fitted.delta", "truth.rmse.delta.cpp.minus.auto",
        "runtime.speedup.auto.over.cpp", "comparison.status"
    )),
    "<h2>Selected Fits</h2>",
    table.html(summary.display, cols = c(
        "dataset.id", "run.label", "backend.used", "selected.support.size",
        "selected.degree", "selected.kernel", "selected.cv.rmse.observed",
        "truth.rmse", "runtime.seconds", "grid.policy"
    )),
    "<h2>Interpretation</h2>",
    "<p>The controlled and high-dimensional rows use the full P7 baseline ",
    "support grid. The real-16S row is included as a quick smoke using a reduced ",
    "support grid, because the R-reference local-PCA path is much heavier at ",
    "n=2000 and p=178.</p>",
    "<p>This report supports using <code>cpp.local.pca</code> as an explicit ",
    "experimental backend when <code>backend.used</code> is recorded. Promotion ",
    "to <code>backend = &quot;auto&quot;</code> should still wait for a dedicated ",
    "diagnostic suite that includes the K5.1 exact-plane case.</p>",
    "</body></html>"
)
writeLines(html, html.path)

cat("K8 P7 LPS backend panel comparison complete.\n")
cat("Output directory:", out.dir, "\n")
print(delta[, c("dataset.id", "comparison.status",
                "max.abs.cv.rmse.delta", "max.abs.fitted.delta",
                "truth.rmse.delta.cpp.minus.auto",
                "runtime.speedup.auto.over.cpp")])
