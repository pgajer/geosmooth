#!/usr/bin/env Rscript

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

root <- paste(
    "/Users/pgajer/current_projects/trend_filtering/development/slpl_tf",
    "experiments/p7_prospective_synthetic_suite",
    sep = "/"
)
out.dir <- file.path(
    project.dir,
    "split_handoffs",
    "k9_lps_local_pca_native_phase_profile_2026-06-04"
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
cfg$run.id <- "k9_lps_phase_profile_20260604"
cfg$workers <- 1L
cfg$heavy.workers <- 1L
cfg$seed <- 20260602L
cfg$noise.sd <- 0.10
cfg$cv.folds <- 5L
cfg$maxsteps <- 1200L

registries <- p7e.read.registries(root)
all.rows <- p7e.dataset.index(registries, "full")
profile.truth.ids <- c(
    "p7d_1d_two_gaussian_v1",
    "p7d_hd1_latent_two_gaussian_v1",
    "p7d_hd3_latent_four_gaussian_v1",
    "p7d_16s_graph_gaussian_farthest3_v1"
)
panel <- all.rows[all.rows$truth_id %in% profile.truth.ids, , drop = FALSE]
panel <- panel[match(profile.truth.ids, panel$truth_id, nomatch = 0L), ,
               drop = FALSE]

ns <- asNamespace("geosmooth")
klp.resolve.chart.dim <- get(".klp.resolve.chart.dim", envir = ns)
profile.native <- get("rcpp_kernel_local_polynomial_cv_local_pca_profile",
                      envir = ns)
cv.native <- get("rcpp_kernel_local_polynomial_cv_local_pca", envir = ns)

make.candidates <- function(X, support.grid) {
    cand <- expand.grid(
        support.size = support.grid,
        degree = c(1L, 2L),
        kernel = c("gaussian", "tricube"),
        KEEP.OUT.ATTRS = FALSE,
        stringsAsFactors = FALSE
    )
    cand$chart.dim <- NA_integer_
    combos <- unique(cand[, c("support.size", "degree"), drop = FALSE])
    dim.rows <- vector("list", nrow(combos))
    dim.lookup <- list()
    dim.elapsed <- system.time({
        for (ii in seq_len(nrow(combos))) {
            info <- klp.resolve.chart.dim(
                X = X,
                support.size = combos$support.size[[ii]],
                degree = combos$degree[[ii]],
                coordinate.method = "local.pca",
                chart.dim = "auto",
                auto.chart.support.metric = "both",
                auto.chart.selection.metric = "operator"
            )
            key <- paste(combos$support.size[[ii]],
                         combos$degree[[ii]], sep = "_")
            dim.lookup[[key]] <- info$chart.dim
            dim.rows[[ii]] <- data.frame(
                support.size = combos$support.size[[ii]],
                degree = combos$degree[[ii]],
                chart.dim = info$chart.dim,
                stringsAsFactors = FALSE
            )
        }
    })[["elapsed"]]
    for (rr in seq_len(nrow(cand))) {
        key <- paste(cand$support.size[[rr]], cand$degree[[rr]], sep = "_")
        cand$chart.dim[[rr]] <- dim.lookup[[key]]
    }
    list(
        candidates = cand,
        chart.dim.table = do.call(rbind, dim.rows),
        chart.dim.elapsed = dim.elapsed
    )
}

fit.lps.timed <- function(method.bundle, support.grid, backend) {
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
    fit$elapsed.seconds <- proc.time()[["elapsed"]] - start
    fit
}

rmse <- function(x, y) sqrt(mean((as.numeric(x) - as.numeric(y))^2))

profile.one <- function(row) {
    cat("[", timestamp(), "] K9 dataset ", row$dataset_id[[1L]], "\n", sep = "")
    bundle <- p7e.materialize.dataset(row, cfg, registries)
    method.bundle <- p7e.method.bundle(bundle)
    profile.sample.policy <- "full_dataset"
    profile.sample.n <- length(bundle$y)
    if (identical(row$truth_id[[1L]],
                  "p7d_16s_graph_gaussian_farthest3_v1")) {
        set.seed(20260604L)
        keep <- sort(sample(seq_along(bundle$y), 500L))
        bundle$X <- bundle$X[keep, , drop = FALSE]
        bundle$y <- bundle$y[keep]
        bundle$f.truth <- bundle$f.truth[keep]
        method.bundle$X <- method.bundle$X[keep, , drop = FALSE]
        method.bundle$y <- method.bundle$y[keep]
        method.bundle$foldid <- rep(seq_len(cfg$cv.folds),
                                    length.out = length(keep))
        profile.sample.policy <- "deterministic_16s_subset_n500"
        profile.sample.n <- length(keep)
    }
    support.grid <- p7e.support.grid(length(bundle$y), "baseline")
    grid.policy <- "p7_baseline_full_grid"
    if (identical(row$truth_id[[1L]],
                  "p7d_16s_graph_gaussian_farthest3_v1")) {
        support.grid <- sort(unique(pmin(length(bundle$y), c(15L, 25L, 35L))))
        grid.policy <- "reduced_grid_for_real16s_profile"
    }

    cand.info <- make.candidates(method.bundle$X, support.grid)
    cand <- cand.info$candidates

    prof.elapsed <- system.time({
        prof <- profile.native(
            X = method.bundle$X,
            y = method.bundle$y,
            foldid = method.bundle$foldid,
            support_size = cand$support.size,
            degree = cand$degree,
            kernel = cand$kernel,
            chart_dim = cand$chart.dim
        )
    })[["elapsed"]]

    native.elapsed <- system.time({
        native.cv <- cv.native(
            X = method.bundle$X,
            y = method.bundle$y,
            foldid = method.bundle$foldid,
            support_size = cand$support.size,
            degree = cand$degree,
            kernel = cand$kernel,
            chart_dim = cand$chart.dim
        )
    })[["elapsed"]]

    fit.r <- fit.lps.timed(method.bundle, support.grid, "auto")
    fit.cpp <- fit.lps.timed(method.bundle, support.grid, "cpp.local.pca")

    prof.timing <- data.frame(prof$timing, stringsAsFactors = FALSE)
    prof.timing$dataset.id <- bundle$dataset.id
    prof.timing$truth.id <- bundle$truth.id
    prof.timing$geometry.family <- bundle$geometry.family
    prof.timing$n <- length(bundle$y)
    prof.timing$ambient.dimension <- ncol(bundle$X)
    prof.timing$profile.sample.policy <- profile.sample.policy
    prof.timing$profile.sample.n <- profile.sample.n
    prof.timing$candidate.count <- nrow(cand)

    counts <- data.frame(
        dataset.id = bundle$dataset.id,
        truth.id = bundle$truth.id,
        geometry.family = bundle$geometry.family,
        n = length(bundle$y),
        ambient.dimension = ncol(bundle$X),
        profile.sample.policy = profile.sample.policy,
        profile.sample.n = profile.sample.n,
        candidate.count = nrow(cand),
        folds = as.integer(prof$counts$folds),
        trees = as.integer(prof$counts$trees),
        targets = as.integer(prof$counts$targets),
        ann.searches = as.integer(prof$counts$ann.searches),
        tie.recoveries = as.integer(prof$counts$tie.recoveries),
        candidate.evals = as.integer(prof$counts$candidate.evals),
        chart.builds = as.integer(prof$counts$chart.builds),
        chart.cache.hits = as.integer(prof$counts$chart.cache.hits),
        local.solves = as.integer(prof$counts$local.solves),
        stringsAsFactors = FALSE
    )

    cv.delta <- max(abs(as.numeric(prof$rmse) - as.numeric(native.cv)),
                    na.rm = TRUE)
    selected.same <- identical(
        as.list(fit.r$selected[1L, c("support.size", "degree", "kernel")]),
        as.list(fit.cpp$selected[1L, c("support.size", "degree", "kernel")])
    )
    summary <- data.frame(
        dataset.id = bundle$dataset.id,
        truth.id = bundle$truth.id,
        geometry.family = bundle$geometry.family,
        grid.policy = grid.policy,
        n = length(bundle$y),
        ambient.dimension = ncol(bundle$X),
        profile.sample.policy = profile.sample.policy,
        profile.sample.n = profile.sample.n,
        support.grid = paste(support.grid, collapse = ","),
        candidate.count = nrow(cand),
        chart.dim.elapsed.seconds = cand.info$chart.dim.elapsed,
        r.fit.elapsed.seconds = fit.r$elapsed.seconds,
        cpp.fit.elapsed.seconds = fit.cpp$elapsed.seconds,
        cpp.profile.external.seconds = prof.elapsed,
        cpp.profile.internal.seconds = as.numeric(prof$total.seconds),
        cpp.cv.unprofiled.seconds = native.elapsed,
        cpp.profile.wrapper.overhead.seconds =
            prof.elapsed - as.numeric(prof$total.seconds),
        profile.rmse.matches.unprofiled.max.abs.delta = cv.delta,
        selected.same = selected.same,
        r.truth.rmse = rmse(fit.r$fitted.values, bundle$f.truth),
        cpp.truth.rmse = rmse(fit.cpp$fitted.values, bundle$f.truth),
        max.abs.fitted.delta =
            max(abs(fit.cpp$fitted.values - fit.r$fitted.values), na.rm = TRUE),
        runtime.speedup.r.over.cpp =
            fit.r$elapsed.seconds / fit.cpp$elapsed.seconds,
        stringsAsFactors = FALSE
    )
    list(
        summary = summary,
        timing = prof.timing,
        counts = counts,
        chart.dim = transform(
            cand.info$chart.dim.table,
            dataset.id = bundle$dataset.id,
            truth.id = bundle$truth.id,
            stringsAsFactors = FALSE
        )
    )
}

results <- lapply(seq_len(nrow(panel)), function(i) {
    profile.one(panel[i, , drop = FALSE])
})
summary <- do.call(rbind, lapply(results, `[[`, "summary"))
timing <- do.call(rbind, lapply(results, `[[`, "timing"))
counts <- do.call(rbind, lapply(results, `[[`, "counts"))
chart.dim <- do.call(rbind, lapply(results, `[[`, "chart.dim"))

utils::write.csv(summary, file.path(table.dir, "k9_profile_summary.csv"),
                 row.names = FALSE)
utils::write.csv(timing, file.path(table.dir, "k9_native_phase_timing.csv"),
                 row.names = FALSE)
utils::write.csv(counts, file.path(table.dir, "k9_native_operation_counts.csv"),
                 row.names = FALSE)
utils::write.csv(chart.dim, file.path(table.dir, "k9_chart_dimension_table.csv"),
                 row.names = FALSE)
saveRDS(results, file.path(out.dir, "k9_lps_phase_profile_results.rds"))

html.escape <- function(x) {
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x
}

html.table <- function(df, digits = 4) {
    df2 <- df
    for (jj in seq_along(df2)) {
        if (is.numeric(df2[[jj]])) df2[[jj]] <- signif(df2[[jj]], digits)
    }
    header <- paste0("<th>", html.escape(names(df2)), "</th>", collapse = "")
    rows <- apply(df2, 1L, function(row) {
        paste0("<tr>", paste0("<td>", html.escape(row), "</td>",
                              collapse = ""), "</tr>")
    })
    paste0("<table><thead><tr>", header, "</tr></thead><tbody>",
           paste(rows, collapse = "\n"), "</tbody></table>")
}

png.plot <- function(filename, width = 1050, height = 650, code) {
    path <- file.path(fig.dir, filename)
    grDevices::png(path, width = width, height = height, res = 120)
    on.exit(grDevices::dev.off(), add = TRUE)
    force(code)
    file.path("report_files", filename)
}

runtime.fig <- png.plot("k9_runtime_summary.png", code = {
    op <- par(mar = c(9, 5, 3, 1))
    on.exit(par(op), add = TRUE)
    mids <- barplot(
        t(as.matrix(summary[, c("r.fit.elapsed.seconds",
                                "cpp.fit.elapsed.seconds")])),
        beside = TRUE,
        names.arg = summary$truth.id,
        las = 2,
        col = c("#737373", "#2f6fbd"),
        ylab = "Elapsed seconds",
        main = "End-to-End LPS Runtime"
    )
    grid(nx = NA, ny = NULL)
    legend("topright", bty = "n", fill = c("#737373", "#2f6fbd"),
           legend = c("R reference", "native local-PCA"))
})

phase.fig <- png.plot("k9_native_phase_shares.png", code = {
    phase.wide <- reshape(
        timing[, c("dataset.id", "phase", "share.of.total")],
        idvar = "dataset.id",
        timevar = "phase",
        direction = "wide"
    )
    rownames(phase.wide) <- phase.wide$dataset.id
    phase.mat <- as.matrix(phase.wide[, setdiff(names(phase.wide),
                                                "dataset.id"),
                                      drop = FALSE])
    colnames(phase.mat) <- sub("^share.of.total\\.", "", colnames(phase.mat))
    op <- par(mar = c(9, 5, 3, 8), xpd = TRUE)
    on.exit(par(op), add = TRUE)
    cols <- c("#2f6fbd", "#77a8d9", "#b24745", "#e07a5f", "#7f7f7f",
              "#c2a83e", "#4f9d69", "#8ab17d", "#6d597a", "#b8b8b8")
    barplot(t(phase.mat), beside = FALSE, las = 2, col = cols,
            ylab = "Share of native profiled time",
            main = "Native Local-PCA CV Phase Shares")
    legend("right", inset = c(-0.22, 0), bty = "n", fill = cols,
           legend = colnames(phase.mat), cex = 0.8)
})

top.phase <- do.call(rbind, lapply(split(timing, timing$dataset.id),
                                   function(df) {
    df <- df[order(df$seconds, decreasing = TRUE), , drop = FALSE]
    df[1:min(3L, nrow(df)), c("dataset.id", "phase", "seconds",
                              "share.of.total")]
}))
top.phase$share.percent <- 100 * top.phase$share.of.total

recommendation <- paste(
    "K9 shows that chart_build is the dominant native phase on the hard",
    "high-dimensional and 16S profiling rows. ANN search and deterministic",
    "tie recovery are measurable but not the primary bottleneck. The next",
    "optimization should therefore target local PCA chart construction:",
    "avoid redundant SVD work across support sizes and chart dimensions where",
    "possible, consider prefix/nested-support reuse, and only then optimize",
    "the local polynomial solve path. Do not promote cpp.local.pca to",
    "backend = 'auto' until this chart-construction bottleneck is addressed",
    "or a size/dimension-dependent backend chooser is justified."
)

phase.summary <- do.call(rbind, lapply(split(timing, timing$dataset.id),
                                       function(df) {
    top <- df[order(df$seconds, decreasing = TRUE), , drop = FALSE][1L, ]
    chart <- df[df$phase == "chart_build", , drop = FALSE][1L, ]
    data.frame(
        dataset.id = df$dataset.id[[1L]],
        truth.id = df$truth.id[[1L]],
        geometry.family = df$geometry.family[[1L]],
        profile.sample.policy = df$profile.sample.policy[[1L]],
        profile.sample.n = df$profile.sample.n[[1L]],
        top.phase = top$phase[[1L]],
        top.share.percent = 100 * top$share.of.total[[1L]],
        chart.build.share.percent = 100 * chart$share.of.total[[1L]],
        stringsAsFactors = FALSE
    )
}))
phase.summary <- phase.summary[match(summary$dataset.id,
                                     phase.summary$dataset.id), ,
                               drop = FALSE]
phase.lines <- vapply(seq_len(nrow(phase.summary)), function(ii) {
    row <- phase.summary[ii, , drop = FALSE]
    paste0(
        "- `", row$truth.id, "`: top phase `", row$top.phase, "` (",
        sprintf("%.2f", row$top.share.percent),
        "%); `chart_build` share ",
        sprintf("%.2f", row$chart.build.share.percent),
        "%; sample policy `", row$profile.sample.policy, "` with n = ",
        row$profile.sample.n, "."
    )
}, character(1L))

html <- paste0(
    "<!doctype html><html><head><meta charset='utf-8'>",
    "<title>K9 LPS Native Phase Profile</title>",
    "<style>",
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;line-height:1.45;margin:40px;max-width:1180px;color:#1f2933}",
    "h1,h2{color:#111827} table{border-collapse:collapse;width:100%;font-size:13px;margin:12px 0 24px}",
    "th,td{border:1px solid #d1d5db;padding:6px 8px;text-align:left;vertical-align:top}",
    "th{background:#f3f4f6} img{max-width:100%;border:1px solid #e5e7eb}",
    ".note{background:#f9fafb;border-left:4px solid #4b5563;padding:10px 14px;margin:16px 0}",
    "code{background:#f3f4f6;padding:1px 4px;border-radius:3px}",
    "</style></head><body>",
    "<h1>K9 LPS Native Phase Profile</h1>",
    "<p>Generated ", html.escape(timestamp()), ".</p>",
    "<div class='note'><strong>Scope.</strong> This report profiles the ",
    "explicit <code>backend = &quot;cpp.local.pca&quot;</code> path for local-PCA ",
    "LPS on four P7 rows. It does not change package defaults.</div>",
    "<h2>Runtime Summary</h2>",
    "<p><img src='", runtime.fig, "' alt='runtime summary'></p>",
    html.table(summary[, c("truth.id", "geometry.family", "n",
                          "ambient.dimension", "candidate.count",
                          "r.fit.elapsed.seconds",
                          "cpp.fit.elapsed.seconds",
                          "runtime.speedup.r.over.cpp",
                          "cpp.profile.internal.seconds",
                          "cpp.cv.unprofiled.seconds",
                          "profile.rmse.matches.unprofiled.max.abs.delta")]),
    "<h2>Native CV Phase Shares</h2>",
    "<p><img src='", phase.fig, "' alt='native phase shares'></p>",
    html.table(top.phase[, c("dataset.id", "phase", "seconds",
                            "share.percent")]),
    "<h2>Operation Counts</h2>",
    html.table(counts),
    "<h2>Recommendation</h2>",
    "<p>", html.escape(recommendation), "</p>",
    "<h2>Files</h2><ul>",
    "<li><code>tables/k9_profile_summary.csv</code></li>",
    "<li><code>tables/k9_native_phase_timing.csv</code></li>",
    "<li><code>tables/k9_native_operation_counts.csv</code></li>",
    "<li><code>tables/k9_chart_dimension_table.csv</code></li>",
    "<li><code>k9_lps_phase_profile_results.rds</code></li>",
    "</ul></body></html>"
)
writeLines(html, file.path(out.dir, "k9_lps_local_pca_native_phase_profile.html"))

handoff <- c(
    "# K9 Handoff: LPS Local-PCA Native Phase Profile",
    "",
    "## Scope",
    "",
    "K9 profiles the explicit `backend = \"cpp.local.pca\"` path for",
    "`fit.lps(coordinate.method = \"local.pca\")`.  It does not change",
    "package defaults.",
    "",
    "## Script and Outputs",
    "",
    paste0("Script: `", file.path(project.dir,
                                  "scripts/k9_lps_local_pca_native_phase_profile.R"),
           "`"),
    "",
    paste0("Output directory: `", out.dir, "`"),
    "",
    paste0("HTML report: `", file.path(out.dir,
                                       "k9_lps_local_pca_native_phase_profile.html"),
           "`"),
    "",
    "## Key Result",
    "",
    "The native profiler decomposes CV time into fold partitioning, ANN tree",
    "construction, ANN search, deterministic tie recovery, neighbor extraction,",
    "kernel weights, local PCA chart construction, local polynomial solves,",
    "accumulation, and RMSE assembly.",
    "",
    "The profile validates that the profiled native RMSE values match the",
    "unprofiled native CV backend to the tolerance recorded in",
    "`tables/k9_profile_summary.csv`.",
    "",
    "The phase table supports the chart-construction conclusion only with the",
    "intended qualification.  `chart_build` dominates the hard",
    "high-dimensional and deterministic 16S profiling rows, while the ordinary",
    "controlled 1D row is dominated by `local_solve`:",
    "",
    phase.lines,
    "",
    "The full 16S row was intentionally not profiled after an initial attempt",
    "ran too long.  The final K9 report uses a deterministic 16S subset of",
    "500 rows, labeled `deterministic_16s_subset_n500`, so that row is a",
    "profiling stress case rather than a P7 performance result.",
    "",
    "## Recommendation",
    "",
    recommendation,
    "",
    "Do not promote `cpp.local.pca` to `backend = \"auto\"` yet.  The next",
    "optimization should target local PCA chart construction on the hard rows,",
    "not the whole LPS pipeline blindly.  K9 is also not a broad speedup result:",
    "native end-to-end elapsed time was slower than the R path on three of the",
    "four profiled rows.",
    "",
    "## Validation",
    "",
    "Run:",
    "",
    "```sh",
    "Rscript scripts/k9_lps_local_pca_native_phase_profile.R",
    "git diff --check",
    "```"
)
writeLines(
    handoff,
    file.path(
        project.dir,
        "split_handoffs",
        "k9_lps_local_pca_native_phase_profile_handoff_2026-06-04.md"
    )
)

cat("K9 LPS native phase profile complete.\n")
cat("Output directory: ", out.dir, "\n", sep = "")
