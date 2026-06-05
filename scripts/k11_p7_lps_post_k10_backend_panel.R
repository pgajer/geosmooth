#!/usr/bin/env Rscript

## K11: post-K10 P7/LPS backend panel validation.
##
## This script compares the current local-PCA LPS R-reference path
## (`backend = "auto"`, currently resolving to `backend.used = "R"`) with the
## explicit native local-PCA path (`backend = "cpp.local.pca"`) after the K10
## row-Gram chart backend optimization.  It intentionally does not promote the
## native backend to `backend = "auto"`.

if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("Package 'pkgload' is required.", call. = FALSE)
}

project.dir <- "/Users/pgajer/current_projects/geosmooth"
pkgload::load_all(project.dir, quiet = TRUE)

`%||%` <- function(a, b) {
    if (is.null(a) || length(a) == 0L || all(is.na(a))) b else a
}

timestamp <- function() {
    format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z", tz = "America/New_York")
}

html.escape <- function(x) {
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x
}

fmt <- function(x, digits = 4) {
    ifelse(is.na(x), "", format(signif(x, digits), scientific = FALSE))
}

html.table <- function(df, cols = names(df), digits = 4) {
    out <- df[, cols, drop = FALSE]
    for (nm in names(out)) {
        if (is.numeric(out[[nm]])) out[[nm]] <- fmt(out[[nm]], digits)
    }
    header <- paste0("<th>", html.escape(names(out)), "</th>", collapse = "")
    rows <- apply(out, 1L, function(row) {
        paste0("<tr>", paste0("<td>", html.escape(row), "</td>", collapse = ""),
               "</tr>")
    })
    paste0("<table><thead><tr>", header, "</tr></thead><tbody>",
           paste(rows, collapse = "\n"), "</tbody></table>")
}

rmse <- function(x, y) {
    sqrt(mean((as.numeric(x) - as.numeric(y))^2, na.rm = TRUE))
}

root <- paste(
    "/Users/pgajer/current_projects/trend_filtering/development/slpl_tf",
    "experiments/p7_prospective_synthetic_suite",
    sep = "/"
)
out.dir <- file.path(
    project.dir,
    "split_handoffs",
    "k11_p7_lps_post_k10_backend_panel_2026-06-04"
)
table.dir <- file.path(out.dir, "tables")
fig.dir <- file.path(out.dir, "report_files")
dir.create(table.dir, recursive = TRUE, showWarnings = FALSE)
dir.create(fig.dir, recursive = TRUE, showWarnings = FALSE)

source(file.path(root, "scripts", "p7_truth_materialization_helpers.R"))
source(file.path(root, "scripts", "p7_baseline_fitters.R"))

orchestrator.expr <- parse(
    file = file.path(root, "scripts", "run_p7e_prospective_orchestrator.R")
)
eval(orchestrator.expr[-length(orchestrator.expr)], envir = .GlobalEnv)

cfg <- p7e.parse.args(character())
cfg$root <- root
cfg$mode <- "full"
cfg$run.id <- "k11_lps_post_k10_backend_panel_20260604"
cfg$workers <- 1L
cfg$heavy.workers <- 1L
cfg$seed <- 20260602L
cfg$noise.sd <- 0.10
cfg$cv.folds <- 5L
cfg$maxsteps <- 1200L

registries <- p7e.read.registries(root)
all.rows <- p7e.dataset.index(registries, "full")

panel.spec <- data.frame(
    truth.id = c(
        "p7d_hd1_latent_two_gaussian_v1",
        "p7d_hd2_latent_three_gaussian_v1",
        "p7d_hd3_latent_four_gaussian_v1",
        "p7d_16s_graph_gaussian_farthest3_v1",
        "p7d_16s_graph_gaussian_farthest3_v1"
    ),
    sample.policy = c(
        "full_dataset",
        "full_dataset",
        "full_dataset",
        "deterministic_16s_subset_n250",
        "deterministic_16s_subset_n500"
    ),
    sample.n = c(NA_integer_, NA_integer_, NA_integer_, 250L, 500L),
    stringsAsFactors = FALSE
)

subset.bundle <- function(bundle, sample.policy, sample.n) {
    if (identical(sample.policy, "full_dataset")) {
        bundle$analysis.sample.policy <- sample.policy
        bundle$analysis.sample.n <- length(bundle$y)
        return(bundle)
    }
    set.seed(20260604L + as.integer(sample.n))
    keep <- sort(sample(seq_along(bundle$y), as.integer(sample.n)))
    bundle$X <- bundle$X[keep, , drop = FALSE]
    bundle$y <- bundle$y[keep]
    bundle$f.truth <- bundle$f.truth[keep]
    bundle$foldid <- rep(seq_len(cfg$cv.folds), length.out = length(keep))
    bundle$analysis.sample.policy <- sample.policy
    bundle$analysis.sample.n <- length(keep)
    bundle
}

lps.materialize.dataset <- function(row) {
    geom.row <- registries$geometry[
        registries$geometry$geometry_id == row$geometry_id[[1L]], ,
        drop = FALSE
    ]
    truth.row <- registries$truth[
        registries$truth$truth_id == row$truth_id[[1L]], , drop = FALSE
    ]
    materialized <- p7.materialize.geometry(geom.row[1L, , drop = FALSE])
    f <- p7.evaluate.truth(materialized, truth.row[1L, , drop = FALSE],
                           geom.row[1L, , drop = FALSE])
    seed <- cfg$seed + match(row$truth_id[[1L]],
                             registries$truth$truth_id) * 1009L
    set.seed(seed)
    y <- as.numeric(f) + stats::rnorm(length(f), sd = cfg$noise.sd)
    foldid <- p7e.foldid(length(y), cfg$cv.folds, seed + 17L)
    list(
        dataset.id = row$dataset_id[[1L]],
        geometry.id = row$geometry_id[[1L]],
        truth.id = row$truth_id[[1L]],
        geometry.family = row$geometry_family[[1L]],
        X = materialized$X,
        y = y,
        f.truth = as.numeric(f),
        noise.sd = cfg$noise.sd,
        noise.id = "gaussian_sd010_r01",
        random.seed = seed,
        foldid = foldid
    )
}

run.fit <- function(method.bundle, support.grid, backend) {
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
    fit$k11.runtime.seconds <- proc.time()[["elapsed"]] - start
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
        analysis.sample.policy = bundle$analysis.sample.policy,
        analysis.sample.n = bundle$analysis.sample.n,
        n = length(bundle$y),
        ambient.dimension = ncol(bundle$X),
        support.grid = paste(support.grid, collapse = ","),
        candidate.count = nrow(fit$cv.table),
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
        observed.rmse = rmse(fit$fitted.values, bundle$y),
        truth.rmse = rmse(fit$fitted.values, bundle$f.truth),
        runtime.seconds = fit$k11.runtime.seconds,
        stringsAsFactors = FALSE
    )
}

compare.bundle <- function(bundle) {
    cat("[", timestamp(), "] K11 dataset ", bundle$dataset.id, " / ",
        bundle$analysis.sample.policy, "\n", sep = "")
    method.bundle <- list(
        X = bundle$X,
        y = bundle$y,
        foldid = bundle$foldid
    )
    support.grid <- p7e.support.grid(length(bundle$y), "baseline")

    auto <- tryCatch(run.fit(method.bundle, support.grid, "auto"),
                     error = function(e) e)
    cpp <- tryCatch(run.fit(method.bundle, support.grid, "cpp.local.pca"),
                    error = function(e) e)

    if (inherits(auto, "error") || inherits(cpp, "error")) {
        return(list(
            summary = data.frame(
                dataset.id = bundle$dataset.id,
                geometry.id = bundle$geometry.id,
                truth.id = bundle$truth.id,
                geometry.family = bundle$geometry.family,
                analysis.sample.policy = bundle$analysis.sample.policy,
                analysis.sample.n = bundle$analysis.sample.n,
                n = length(bundle$y),
                ambient.dimension = ncol(bundle$X),
                comparison.status = "failed",
                failure.auto = if (inherits(auto, "error")) {
                    conditionMessage(auto)
                } else "",
                failure.cpp = if (inherits(cpp, "error")) {
                    conditionMessage(cpp)
                } else "",
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

    cv.auto <- auto$cv.table
    cv.cpp <- cpp$cv.table
    cv.auto$run.label <- "auto"
    cv.cpp$run.label <- "cpp.local.pca"
    cv <- rbind(cv.auto, cv.cpp)
    cv$dataset.id <- bundle$dataset.id
    cv$analysis.sample.policy <- bundle$analysis.sample.policy

    cv.wide <- merge(
        auto$cv.table,
        cpp$cv.table,
        by = c("support.size", "degree", "kernel"),
        suffixes = c(".auto", ".cpp"),
        all = TRUE
    )
    cv.delta <- cv.wide$cv.rmse.observed.cpp -
        cv.wide$cv.rmse.observed.auto

    selected.fields <- c(
        "chart.dim",
        "selected.support.size",
        "selected.degree",
        "selected.kernel"
    )
    selected.same <- identical(
        as.list(summary[summary$run.label == "auto",
                        selected.fields]),
        as.list(summary[summary$run.label == "cpp.local.pca",
                        selected.fields])
    )
    fitted.delta <- cpp$fitted.values - auto$fitted.values
    truth.delta <- summary$truth.rmse[summary$run.label == "cpp.local.pca"] -
        summary$truth.rmse[summary$run.label == "auto"]
    runtime.speedup <- summary$runtime.seconds[summary$run.label == "auto"] /
        summary$runtime.seconds[summary$run.label == "cpp.local.pca"]
    max.cv.delta <- max(abs(cv.delta), na.rm = TRUE)
    max.fitted.delta <- max(abs(fitted.delta), na.rm = TRUE)

    status <- if (!selected.same) {
        "selected_candidate_drift"
    } else if (max.cv.delta <= 1e-8 && max.fitted.delta <= 1e-8 &&
               abs(truth.delta) <= 1e-8) {
        "safe_machine_precision"
    } else if (max.cv.delta <= 1e-5 && max.fitted.delta <= 1e-8 &&
               abs(truth.delta) <= 1e-8) {
        "cv_numeric_drift_selected_stable"
    } else {
        "material_drift"
    }

    delta <- data.frame(
        dataset.id = bundle$dataset.id,
        geometry.id = bundle$geometry.id,
        truth.id = bundle$truth.id,
        geometry.family = bundle$geometry.family,
        analysis.sample.policy = bundle$analysis.sample.policy,
        analysis.sample.n = bundle$analysis.sample.n,
        n = length(bundle$y),
        ambient.dimension = ncol(bundle$X),
        support.grid = paste(support.grid, collapse = ","),
        candidate.count = nrow(auto$cv.table),
        selected.same = selected.same,
        selected.chart.dim.same =
            summary$chart.dim[summary$run.label == "auto"] ==
            summary$chart.dim[summary$run.label == "cpp.local.pca"],
        max.abs.cv.rmse.delta = max.cv.delta,
        mean.abs.cv.rmse.delta = mean(abs(cv.delta), na.rm = TRUE),
        max.abs.fitted.delta = max.fitted.delta,
        rmse.fitted.delta = rmse(cpp$fitted.values, auto$fitted.values),
        truth.rmse.delta.cpp.minus.auto = truth.delta,
        runtime.auto.seconds =
            summary$runtime.seconds[summary$run.label == "auto"],
        runtime.cpp.seconds =
            summary$runtime.seconds[summary$run.label == "cpp.local.pca"],
        runtime.speedup.auto.over.cpp = runtime.speedup,
        comparison.status = status,
        stringsAsFactors = FALSE
    )

    list(
        summary = summary,
        cv = cv,
        delta = delta,
        fits = list(auto = auto, cpp.local.pca = cpp)
    )
}

materialize.spec <- function(spec.row) {
    row <- all.rows[all.rows$truth_id == spec.row$truth.id[[1L]], ,
                    drop = FALSE][1L, , drop = FALSE]
    bundle <- lps.materialize.dataset(row)
    subset.bundle(bundle, spec.row$sample.policy[[1L]], spec.row$sample.n[[1L]])
}

results <- lapply(seq_len(nrow(panel.spec)), function(i) {
    bundle <- materialize.spec(panel.spec[i, , drop = FALSE])
    compare.bundle(bundle)
})

summary <- do.call(rbind, lapply(results, `[[`, "summary"))
cv <- do.call(rbind, lapply(results, `[[`, "cv"))
delta <- do.call(rbind, lapply(results, `[[`, "delta"))

utils::write.csv(panel.spec, file.path(table.dir, "k11_dataset_panel_spec.csv"),
                 row.names = FALSE)
utils::write.csv(summary, file.path(table.dir, "k11_lps_backend_summary_long.csv"),
                 row.names = FALSE)
utils::write.csv(cv, file.path(table.dir, "k11_lps_backend_cv_tables_long.csv"),
                 row.names = FALSE)
utils::write.csv(delta, file.path(table.dir, "k11_lps_backend_delta_summary.csv"),
                 row.names = FALSE)
saveRDS(results, file.path(out.dir, "k11_lps_backend_results.rds"))

plot.runtime <- function() {
    path <- file.path(fig.dir, "k11_runtime_speedup_panel.png")
    grDevices::png(path, width = 1150, height = 720, res = 130)
    on.exit(grDevices::dev.off(), add = TRUE)
    op <- par(mar = c(10, 5, 3, 1))
    on.exit(par(op), add = TRUE)
    labs <- paste0(delta$truth.id, "\n", delta$analysis.sample.policy)
    y <- delta$runtime.speedup.auto.over.cpp
    plot(seq_along(y), y, pch = 19, cex = 1.3, xaxt = "n",
         xlab = "", ylab = "Runtime ratio: R-reference / native",
         main = "K11 Post-K10 Local-PCA LPS Runtime (Descriptive)")
    abline(h = 1, col = "#9ca3af", lty = 2)
    axis(1, at = seq_along(y), labels = labs, las = 2, cex.axis = 0.72)
    grid(nx = NA, ny = NULL)
    file.path("report_files", basename(path))
}

plot.drift <- function() {
    path <- file.path(fig.dir, "k11_backend_drift_panel.png")
    grDevices::png(path, width = 1150, height = 720, res = 130)
    on.exit(grDevices::dev.off(), add = TRUE)
    op <- par(mar = c(10, 5, 3, 1))
    on.exit(par(op), add = TRUE)
    labs <- paste0(delta$truth.id, "\n", delta$analysis.sample.policy)
    y <- pmax(delta$max.abs.cv.rmse.delta, .Machine$double.eps)
    plot(seq_along(y), y, pch = 19, cex = 1.3, xaxt = "n", log = "y",
         xlab = "", ylab = "Max absolute CV-RMSE table delta",
         main = "K11 R vs Native CV Table Drift")
    abline(h = c(1e-8, 1e-5), col = c("#9ca3af", "#ef4444"),
           lty = c(2, 3))
    axis(1, at = seq_along(y), labels = labs, las = 2, cex.axis = 0.72)
    grid(nx = NA, ny = NULL)
    file.path("report_files", basename(path))
}

runtime.fig <- plot.runtime()
drift.fig <- plot.drift()

status.counts <- as.data.frame(table(delta$comparison.status),
                               stringsAsFactors = FALSE)
names(status.counts) <- c("comparison.status", "dataset.count")
all.selected.same <- all(delta$selected.same)
max.fit.delta <- max(delta$max.abs.fitted.delta, na.rm = TRUE)
max.truth.delta <- max(abs(delta$truth.rmse.delta.cpp.minus.auto), na.rm = TRUE)
max.cv.delta <- max(delta$max.abs.cv.rmse.delta, na.rm = TRUE)
median.speedup <- stats::median(delta$runtime.speedup.auto.over.cpp,
                                na.rm = TRUE)

answer <- if (all.selected.same && max.fit.delta <= 1e-8 &&
              max.truth.delta <= 1e-8 && max.cv.delta <= 1e-5) {
    paste(
        "K11 supports using `cpp.local.pca` as an explicit opt-in backend on",
        "the focused high-dimensional and 16S-style panel because the",
        "effective selected models, fitted values, and Truth-RMSE values match",
        "the R reference. It does not support promoting the native backend to",
        "`backend = \"auto\"`; runtime is descriptive only and remains",
        "size- and geometry-dependent."
    )
} else {
    paste(
        "K11 does not yet support routine use of `cpp.local.pca` beyond",
        "explicit diagnostics, because at least one comparison showed selected",
        "model, fitted-value, truth-RMSE, or CV-table drift beyond the",
        "predeclared tolerance. The selected model includes chart dimension,",
        "support size, polynomial degree, and kernel."
    )
}

html.path <- file.path(out.dir, "k11_p7_lps_post_k10_backend_panel.html")
html <- paste0(
    "<!doctype html><html><head><meta charset='utf-8'>",
    "<title>K11 P7 LPS Post-K10 Backend Panel</title>",
    "<style>",
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;",
    "line-height:1.45;margin:36px;max-width:1180px;color:#1f2933}",
    "h1,h2{line-height:1.15;color:#111827}",
    "table{border-collapse:collapse;width:100%;font-size:13px;margin:12px 0 24px}",
    "th,td{border:1px solid #d1d5db;padding:6px 8px;text-align:left;vertical-align:top}",
    "th{background:#f3f4f6} img{max-width:100%;border:1px solid #e5e7eb}",
    ".note{background:#f9fafb;border-left:4px solid #4b5563;padding:10px 14px;margin:16px 0}",
    ".ok{color:#166534;font-weight:700}.warn{color:#9a3412;font-weight:700}",
    "code{background:#f3f4f6;padding:1px 4px;border-radius:3px}",
    "</style></head><body>",
    "<h1>K11 P7 LPS Post-K10 Backend Panel</h1>",
    "<p>Generated ", html.escape(timestamp()), ".</p>",
    "<div class='note'><strong>Question.</strong> After K10, does explicit ",
    "<code>backend = &quot;cpp.local.pca&quot;</code> reproduce the R-reference ",
    "local-PCA LPS path on focused high-dimensional and 16S-style rows?</div>",
    "<h2>Answer</h2>",
    "<p class='", if (all.selected.same && max.fit.delta <= 1e-8 &&
        max.truth.delta <= 1e-8 && max.cv.delta <= 1e-5) "ok" else "warn",
    "'>", html.escape(answer), "</p>",
    "<p>Descriptive median runtime ratio R/native: <strong>",
    fmt(median.speedup),
    "x</strong>. This runtime number is not treated as durable speed evidence. ",
    "Max absolute CV-RMSE delta: <strong>",
    fmt(max.cv.delta, 5), "</strong>. Max fitted-value delta: <strong>",
    fmt(max.fit.delta, 5), "</strong>. Max Truth-RMSE delta: <strong>",
    fmt(max.truth.delta, 5), "</strong>.</p>",
    "<h2>Runtime</h2>",
    "<p><img src='", runtime.fig, "' alt='K11 runtime speedup panel'></p>",
    "<h2>CV Table Drift</h2>",
    "<p><img src='", drift.fig, "' alt='K11 CV drift panel'></p>",
    "<h2>Status Counts</h2>",
    html.table(status.counts),
    "<h2>Dataset Delta Summary</h2>",
    html.table(delta, cols = c(
        "truth.id", "geometry.family", "analysis.sample.policy", "n",
        "ambient.dimension", "candidate.count", "selected.same",
        "selected.chart.dim.same",
        "max.abs.cv.rmse.delta", "max.abs.fitted.delta",
        "truth.rmse.delta.cpp.minus.auto",
        "runtime.speedup.auto.over.cpp", "comparison.status"
    )),
    "<h2>Selected Fits</h2>",
    html.table(summary, cols = c(
        "truth.id", "analysis.sample.policy", "run.label", "backend.used",
        "chart.dim", "selected.support.size", "selected.degree",
        "selected.kernel",
        "selected.cv.rmse.observed", "truth.rmse", "runtime.seconds"
    )),
    "<h2>Interpretation</h2>",
    "<p>The native backend remains explicit opt-in. K11 tests fit/CV parity ",
    "and speed after K10 on the hard high-dimensional controlled rows and two ",
    "deterministic 16S-style subsets. The 16S rows use full current P7 LPS ",
    "support grid <code>15:35</code>, not the earlier reduced smoke grid.</p>",
    "<p>All rows use <code>chart.dim = &quot;auto&quot;</code>. This is intentional ",
    "and should remain the real-data contract: for real geometries such as 16S ",
    "relative-abundance data, the local dimension is unknown and must be ",
    "estimated from the observed covariates rather than supplied from latent ",
    "coordinates or truth-side information.</p>",
    "<p>Even when parity is stable, backend promotion should wait for a ",
    "separate default-policy decision. Runtime in this report is descriptive ",
    "only because elapsed times can differ across reruns and depend on geometry, ",
    "n, ambient dimension, selected chart dimension, and support grid.</p>",
    "<h2>Files</h2><ul>",
    "<li><code>tables/k11_dataset_panel_spec.csv</code></li>",
    "<li><code>tables/k11_lps_backend_summary_long.csv</code></li>",
    "<li><code>tables/k11_lps_backend_delta_summary.csv</code></li>",
    "<li><code>tables/k11_lps_backend_cv_tables_long.csv</code></li>",
    "<li><code>k11_lps_backend_results.rds</code></li>",
    "</ul></body></html>"
)
writeLines(html, html.path)

handoff.path <- file.path(
    project.dir,
    "split_handoffs",
    "k11_p7_lps_post_k10_backend_panel_handoff_2026-06-04.md"
)
handoff <- c(
    "# K11 Handoff: P7 LPS Post-K10 Backend Panel",
    "",
    paste("Generated:", timestamp()),
    "",
    "## Scope",
    "",
    "K11 validates the explicit opt-in local-PCA LPS native backend after K10.",
    "It compares:",
    "",
    "- `backend = \"auto\"`, which currently resolves local-PCA LPS to the R",
    "  reference path; and",
    "- `backend = \"cpp.local.pca\"`, the explicit native local-PCA backend.",
    "",
    "K11 does not change `backend = \"auto\"` and does not promote the native",
    "backend into package defaults.",
    "",
    "## Panel",
    "",
    "The panel contains three controlled high-dimensional P7 rows and two",
    "deterministic 16S-style subsets.  All rows use the current full P7 LPS",
    "support grid `15:35`, degree grid `{1, 2}`, kernel grid",
    "`{gaussian, tricube}`, `chart.dim = \"auto\"`,",
    "`auto.chart.support.metric = \"both\"`, and",
    "`auto.chart.selection.metric = \"operator\"`.",
    "",
    "`chart.dim = \"auto\"` is part of the deployable real-data contract.  In",
    "real geometries, including 16S relative-abundance data, the local",
    "dimension is unknown and must be estimated from observed covariates, not",
    "from latent coordinates or truth-side information.",
    "",
    paste0("HTML report: `", html.path, "`"),
    paste0("Output directory: `", out.dir, "`"),
    "",
    "## Results",
    "",
    paste("- All effective selected models matched:", all.selected.same),
    paste("- Selected chart dimensions matched:",
          all(delta$selected.chart.dim.same)),
    paste("- Maximum absolute CV-RMSE table delta:", signif(max.cv.delta, 6)),
    paste("- Maximum absolute fitted-value delta:", signif(max.fit.delta, 6)),
    paste("- Maximum absolute Truth-RMSE delta:", signif(max.truth.delta, 6)),
    paste("- Descriptive median runtime ratio R/native:",
          signif(median.speedup, 6)),
    "",
    "Status counts:",
    "",
    paste(
        "-",
        status.counts$comparison.status,
        status.counts$dataset.count,
        collapse = "\n"
    ),
    "",
    "## Recommendation",
    "",
    answer,
    "",
    "Treat runtime in this K11 panel as descriptive only.  K11 is a parity and",
    "explicit-opt-in validation, not a durable benchmark for a speed claim.",
    "",
    "Do not promote `cpp.local.pca` to `backend = \"auto\"` yet.  K11 supports",
    "recorded, explicit opt-in use on focused P7-style panels, but the next",
    "default-policy decision should be based on a broader size/dimension policy",
    "or a backend chooser that records its decision.",
    "",
    "## Validation",
    "",
    "Run:",
    "",
    "```sh",
    "Rscript scripts/k11_p7_lps_post_k10_backend_panel.R",
    "Rscript -e 'pkgload::load_all(\"/Users/pgajer/current_projects/geosmooth\", quiet=TRUE); testthat::test_file(\"/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R\", reporter=\"summary\")'",
    "Rscript -e 'pkgload::load_all(\"/Users/pgajer/current_projects/geosmooth\", quiet=TRUE); testthat::test_file(\"/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge1-r-smoothers.R\", reporter=\"summary\")'",
    "git diff --check",
    "```"
)
writeLines(handoff, handoff.path)

cat("K11 P7 LPS post-K10 backend panel complete.\n")
cat("Output directory: ", out.dir, "\n", sep = "")
print(delta[, c("truth.id", "analysis.sample.policy", "comparison.status",
                "max.abs.cv.rmse.delta", "max.abs.fitted.delta",
                "truth.rmse.delta.cpp.minus.auto",
                "runtime.speedup.auto.over.cpp")])
