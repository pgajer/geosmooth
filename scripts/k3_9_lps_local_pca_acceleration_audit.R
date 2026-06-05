#!/usr/bin/env Rscript

if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("Package 'pkgload' is required.", call. = FALSE)
}
if (!requireNamespace("linf", quietly = TRUE)) {
    stop("Package 'linf' is required.", call. = FALSE)
}

pkgload::load_all(".", quiet = TRUE)
linf.root <- path.expand("~/current_projects/linf")
if (dir.exists(linf.root) && file.exists(file.path(linf.root, "DESCRIPTION"))) {
    pkgload::load_all(linf.root, quiet = TRUE)
}

out.root <- file.path(
    getwd(),
    "split_handoffs",
    "k3_9_lps_local_pca_acceleration_audit_2026-06-04"
)
fig.dir <- file.path(out.root, "k3_9_lps_local_pca_acceleration_audit_files")
dir.create(out.root, recursive = TRUE, showWarnings = FALSE)
dir.create(fig.dir, recursive = TRUE, showWarnings = FALSE)

support.grid <- c(15L, 25L, 35L)
degree.grid <- c(1L, 2L)
kernel.grid <- c("gaussian", "tricube")
sample.sizes <- c(250L, 500L)
cv.folds <- 3L
seed.base <- 20260604L

`%||%` <- function(x, y) if (is.null(x)) y else x

load_linf_asset <- function(name) {
    local.path <- file.path(linf.root, "data", paste0(name, ".rda"))
    if (file.exists(local.path)) {
        env <- new.env(parent = emptyenv())
        load(local.path, envir = env)
        return(get(name, envir = env))
    }
    env <- new.env(parent = emptyenv())
    data(list = name, package = "linf", envir = env)
    get(name, envir = env)
}

normalize_rows <- function(X) {
    X <- as.matrix(X)
    rs <- rowSums(X)
    keep <- is.finite(rs) & rs > 0
    X <- X[keep, , drop = FALSE]
    sweep(X, 1L, rowSums(X), "/")
}

safe_scale <- function(X) {
    X <- as.matrix(X)
    s <- apply(X, 2L, stats::sd)
    keep <- is.finite(s) & s > 0
    if (!any(keep)) return(X)
    scale(X[, keep, drop = FALSE])
}

path_taxa <- function(labels, sep = "__") {
    unique(unlist(strsplit(labels, sep, fixed = TRUE), use.names = FALSE))
}

make_depth_dataset <- function(depth, top.k) {
    valencia.source <- path.expand("~/current_projects/valencia/tx.13k.rds")
    if (!file.exists(valencia.source)) {
        stop("VALENCIA source matrix not found: ", valencia.source,
             call. = FALSE)
    }
    tx <- readRDS(valencia.source)
    asset.name <- if (depth == 2L) {
        "valencia13k_dcst_depth2_merged"
    } else {
        "valencia13k_dcst_depth3_merged"
    }
    asset <- load_linf_asset(asset.name)
    summary <- asset$summaries[[paste0("depth", depth)]]
    taxa <- path_taxa(head(summary$dcst_label, top.k))
    taxa <- taxa[taxa %in% colnames(tx)]
    X <- normalize_rows(tx[, taxa, drop = FALSE])
    labels <- asset$assignments[[paste0("dcst_depth", depth)]]
    list(
        X = X,
        strata = labels[seq_len(nrow(X))],
        feature.count = ncol(X),
        source = paste0("top ", top.k, " depth-", depth, " merged DCST labels")
    )
}

make_datasets <- function() {
    rel4.asset <- load_linf_asset("valencia_linf_hypercube_1k")
    X4 <- rel4.asset$rel4
    list(
        rel4 = list(
            X = X4,
            strata = rel4.asset$meta$dominant_component,
            feature.count = ncol(X4),
            source = "bundled Li/Lc/Gv/Bv 4D composition"
        ),
        hypercube_Li = list(
            X = linf::linf.hypercube.embedding(X4, reference = "Li"),
            strata = rel4.asset$meta$dominant_component,
            feature.count = ncol(X4) - 1L,
            source = "hypercube embedding of rel4 with Li reference"
        ),
        depth3_top = make_depth_dataset(depth = 3L, top.k = 10L)
    )
}

stratified_sample <- function(n, labels, seed) {
    set.seed(seed)
    labels <- as.character(labels)
    tab <- table(labels)
    raw <- as.numeric(tab) / sum(tab) * n
    alloc <- floor(raw)
    short <- n - sum(alloc)
    if (short > 0L) {
        ord <- order(raw - alloc, decreasing = TRUE)
        alloc[ord[seq_len(short)]] <- alloc[ord[seq_len(short)]] + 1L
    }
    names(alloc) <- names(tab)
    out <- integer(0)
    for (ll in names(alloc)) {
        idx <- which(labels == ll)
        out <- c(out, sample(idx, min(alloc[[ll]], length(idx))))
    }
    sort(out)
}

choose_centers <- function(X) {
    Z <- safe_scale(X)
    pc <- stats::prcomp(Z, center = FALSE, scale. = FALSE)
    score <- pc$x[, seq_len(min(2L, ncol(pc$x))), drop = FALSE]
    if (ncol(score) == 1L) score <- cbind(score, rep(0, nrow(score)))
    targets <- rbind(
        c(stats::quantile(score[, 1L], 0.20), stats::quantile(score[, 2L], 0.50)),
        c(stats::quantile(score[, 1L], 0.75), stats::quantile(score[, 2L], 0.30)),
        c(stats::quantile(score[, 1L], 0.55), stats::quantile(score[, 2L], 0.80))
    )
    vapply(seq_len(nrow(targets)), function(i) {
        which.min(rowSums((score - matrix(targets[i, ], nrow(score), 2L,
                                          byrow = TRUE))^2))
    }, integer(1))
}

truth_function <- function(X) {
    Z <- safe_scale(X)
    centers <- choose_centers(X)
    C <- Z[centers, , drop = FALSE]
    dmat <- as.matrix(stats::dist(Z))
    sigma.base <- stats::median(dmat[upper.tri(dmat)], na.rm = TRUE)
    if (!is.finite(sigma.base) || sigma.base <= 0) sigma.base <- 1
    sigmas <- sigma.base * c(0.28, 0.38, 0.48)
    amps <- c(1.2, 0.85, 0.55)
    f <- rep(0, nrow(Z))
    for (j in seq_along(amps)) {
        d2 <- rowSums((Z - matrix(C[j, ], nrow(Z), ncol(Z),
                                  byrow = TRUE))^2)
        f <- f + amps[[j]] * exp(-d2 / (2 * sigmas[[j]]^2))
    }
    as.numeric(scale(f, center = TRUE, scale = FALSE))
}

materialize_case <- function(dataset.name, dataset, n, seed) {
    idx <- if (!is.null(dataset$strata) && length(dataset$strata) == nrow(dataset$X)) {
        stratified_sample(n, dataset$strata, seed)
    } else {
        set.seed(seed)
        sort(sample(seq_len(nrow(dataset$X)), n))
    }
    X <- dataset$X[idx, , drop = FALSE]
    f <- truth_function(X)
    noise.sd <- 0.10 * stats::sd(f)
    set.seed(seed + 10000L)
    y <- f + stats::rnorm(length(f), sd = noise.sd)
    set.seed(seed + 20000L)
    foldid <- sample(rep(seq_len(cv.folds), length.out = n))
    list(
        dataset = dataset.name,
        n = n,
        X = X,
        y = y,
        truth = f,
        foldid = foldid,
        feature.count = dataset$feature.count,
        source = dataset$source
    )
}

rmse <- function(x) sqrt(mean(x^2, na.rm = TRUE))

fit_mode <- function(case, mode) {
    args <- list(
        X = case$X,
        y = case$y,
        foldid = case$foldid,
        support.grid = support.grid,
        degree.grid = degree.grid,
        kernel.grid = kernel.grid,
        cv.folds = cv.folds
    )
    if (identical(mode, "ambient_cpp")) {
        args$coordinate.method <- "coordinates"
        args$backend <- "cpp"
    } else if (identical(mode, "local_pca_auto")) {
        args$coordinate.method <- "local.pca"
        args$chart.dim <- "auto"
        args$local.chart.method <- "pca"
        args$backend <- "R"
    } else {
        stop("Unknown mode: ", mode, call. = FALSE)
    }
    error <- NA_character_
    fit <- NULL
    elapsed <- system.time({
        fit <- tryCatch(
            do.call(fit.lps, args),
            error = function(e) {
                error <<- conditionMessage(e)
                NULL
            }
        )
    })[["elapsed"]]
    if (is.null(fit)) {
        return(data.frame(
            dataset = case$dataset,
            n = case$n,
            mode = mode,
            success = FALSE,
            runtime.sec = as.numeric(elapsed),
            truth.rmse = NA_real_,
            cv.rmse = NA_real_,
            support.size = NA_integer_,
            degree = NA_integer_,
            kernel = NA_character_,
            chart.dim = NA_integer_,
            error = error,
            stringsAsFactors = FALSE
        ))
    }
    data.frame(
        dataset = case$dataset,
        n = case$n,
        mode = mode,
        success = TRUE,
        runtime.sec = as.numeric(elapsed),
        truth.rmse = rmse(as.numeric(fit$fitted.values) - case$truth),
        cv.rmse = fit$selected$cv.rmse.observed[[1L]],
        support.size = fit$selected$support.size[[1L]],
        degree = fit$selected$degree[[1L]],
        kernel = as.character(fit$selected$kernel[[1L]]),
        chart.dim = fit$chart.dim %||% NA_integer_,
        error = NA_character_,
        stringsAsFactors = FALSE
    )
}

ns <- asNamespace("geosmooth")
klp.resolve.chart.dim <- get(".klp.resolve.chart.dim", envir = ns)
klp.local.order <- get(".klp.local.order", envir = ns)
klp.local.neighborhood.from.order <- get(".klp.local.neighborhood.from.order",
                                        envir = ns)
klp.kernel.weights <- get(".klp.kernel.weights", envir = ns)
klp.fit.intercept.lazy <- get(".klp.fit.intercept.lazy", envir = ns)
klp.rmse <- get(".klp.rmse", envir = ns)

profile_local_pca_cv <- function(case) {
    X <- case$X
    y <- case$y
    foldid <- case$foldid
    max.profile.targets <- 120L
    cand <- expand.grid(
        support.size = support.grid,
        degree = degree.grid,
        kernel = kernel.grid,
        KEEP.OUT.ATTRS = FALSE,
        stringsAsFactors = FALSE
    )
    cand$chart.dim <- NA_integer_
    timings <- c(
        chart_dim_resolution = 0,
        neighbor_ordering = 0,
        local_chart = 0,
        kernel_weighting = 0,
        weighted_fit = 0,
        cv_rmse = 0
    )
    counts <- c(
        chart_dim_resolutions = 0,
        neighbor_orderings = 0,
        local_charts = 0,
        kernel_weight_vectors = 0,
        weighted_fits = 0
    )

    combos <- unique(cand[, c("support.size", "degree"), drop = FALSE])
    dim.lookup <- list()
    timings[["chart_dim_resolution"]] <- system.time({
        for (ii in seq_len(nrow(combos))) {
            info <- klp.resolve.chart.dim(
                X = X,
                support.size = combos$support.size[[ii]],
                degree = combos$degree[[ii]],
                coordinate.method = "local.pca",
                chart.dim = "auto",
                auto.chart.support.metric = "coordinates",
                auto.chart.selection.metric = "coordinates"
            )
            counts[["chart_dim_resolutions"]] <-
                counts[["chart_dim_resolutions"]] + 1
            key <- paste(combos$support.size[[ii]], combos$degree[[ii]],
                         sep = "_")
            dim.lookup[[key]] <- info$chart.dim
        }
    })[["elapsed"]]
    for (rr in seq_len(nrow(cand))) {
        key <- paste(cand$support.size[[rr]], cand$degree[[rr]], sep = "_")
        cand$chart.dim[[rr]] <- dim.lookup[[key]]
    }
    support.sizes <- sort(unique(cand$support.size))
    max.support.size <- max(support.sizes)

    entries <- list()
    for (fold in sort(unique(foldid))) {
        test <- which(foldid == fold)
        train <- which(foldid != fold)
        X.train <- X[train, , drop = FALSE]
        y.train <- y[train]
        fold.max.support <- min(max.support.size, length(train))
        for (target in test) {
            entries[[length(entries) + 1L]] <- list(
                target = target,
                center = X[target, , drop = TRUE],
                X.train = X.train,
                y.train = y.train,
                fold.max.support = fold.max.support
            )
        }
    }
    if (length(entries) > max.profile.targets) {
        entries <- entries[seq_len(max.profile.targets)]
    }

    ordered.entries <- vector("list", length(entries))
    timings[["neighbor_ordering"]] <- system.time({
        for (ii in seq_along(entries)) {
            entry <- entries[[ii]]
            ordered.entries[[ii]] <- klp.local.order(
                X.train = entry$X.train,
                center = entry$center,
                support.size = entry$fold.max.support
            )
        }
    })[["elapsed"]]
    counts[["neighbor_orderings"]] <- length(entries)

    local.entries <- list()
    timings[["local_chart"]] <- system.time({
        for (ii in seq_along(entries)) {
            entry <- entries[[ii]]
            ordered <- ordered.entries[[ii]]
            for (support.size in support.sizes) {
                support.rows <- which(cand$support.size == support.size)
                max.chart.dim <- max(cand$chart.dim[support.rows],
                                     na.rm = TRUE)
                local <- klp.local.neighborhood.from.order(
                    X.train = entry$X.train,
                    y.train = entry$y.train,
                    center = entry$center,
                    ordered = ordered,
                    support.size = support.size,
                    coordinate.method = "local.pca",
                    chart.dim = max.chart.dim,
                    local.chart.method = "pca"
                )
                local.entries[[length(local.entries) + 1L]] <- list(
                    ordered = ordered,
                    local = local,
                    support.size = support.size,
                    support.rows = support.rows
                )
            }
        }
    })[["elapsed"]]
    counts[["local_charts"]] <- length(local.entries)

    kernel.entries <- vector("list", length(local.entries))
    timings[["kernel_weighting"]] <- system.time({
        for (ii in seq_along(local.entries)) {
            entry <- local.entries[[ii]]
            effective.support <- min(as.integer(entry$support.size),
                                     length(entry$ordered$distances))
            kernel.names <- unique(cand$kernel[entry$support.rows])
            kernel.weights <- lapply(
                kernel.names,
                function(kernel) klp.kernel.weights(
                    entry$ordered$distances[seq_len(effective.support)],
                    kernel
                )
            )
            names(kernel.weights) <- kernel.names
            kernel.entries[[ii]] <- kernel.weights
            counts[["kernel_weight_vectors"]] <-
                counts[["kernel_weight_vectors"]] + length(kernel.names)
        }
    })[["elapsed"]]

    timings[["weighted_fit"]] <- system.time({
        last.fit <- NA_real_
        for (ii in seq_along(local.entries)) {
            entry <- local.entries[[ii]]
            kernel.weights <- kernel.entries[[ii]]
            design.cache <- new.env(parent = emptyenv())
            for (rr in entry$support.rows) {
                w <- kernel.weights[[cand$kernel[[rr]]]]
                last.fit <- klp.fit.intercept.lazy(
                    z = entry$local$z,
                    y = entry$local$y,
                    weights = w,
                    degree = cand$degree[[rr]],
                    chart.dim = cand$chart.dim[[rr]],
                    design.cache = design.cache
                )
                counts[["weighted_fits"]] <- counts[["weighted_fits"]] + 1
            }
        }
        invisible(last.fit)
    })[["elapsed"]]

    total <- sum(timings)

    timing.df <- data.frame(
        dataset = case$dataset,
        n = case$n,
        phase = names(timings),
        seconds = as.numeric(timings),
        share.of.total = as.numeric(timings) / as.numeric(total),
        stringsAsFactors = FALSE
    )
    count.df <- data.frame(
        dataset = case$dataset,
        n = case$n,
        counter = names(counts),
        count = as.integer(counts),
        stringsAsFactors = FALSE
    )
    list(
        total.sec = as.numeric(total),
        timing = timing.df,
        counts = count.df,
        cv.table = cand,
        profile.targets = length(entries)
    )
}

png_plot <- function(filename, width = 980, height = 640, code) {
    path <- file.path(fig.dir, filename)
    grDevices::png(path, width = width, height = height, res = 120)
    on.exit(grDevices::dev.off(), add = TRUE)
    force(code)
    file.path("k3_9_lps_local_pca_acceleration_audit_files", filename)
}

html_escape <- function(x) {
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x
}

html_table <- function(df, digits = 4) {
    df2 <- df
    for (jj in seq_along(df2)) {
        if (is.numeric(df2[[jj]])) df2[[jj]] <- signif(df2[[jj]], digits)
    }
    header <- paste0("<th>", html_escape(names(df2)), "</th>", collapse = "")
    rows <- apply(df2, 1L, function(row) {
        paste0("<tr>", paste0("<td>", html_escape(row), "</td>",
                              collapse = ""), "</tr>")
    })
    paste0("<table><thead><tr>", header, "</tr></thead><tbody>",
           paste(rows, collapse = "\n"), "</tbody></table>")
}

datasets <- make_datasets()
cases <- list()
ii <- 1L
for (dataset.name in names(datasets)) {
    for (n in sample.sizes) {
        cases[[ii]] <- materialize_case(
            dataset.name = dataset.name,
            dataset = datasets[[dataset.name]],
            n = n,
            seed = seed.base + ii * 97L
        )
        ii <- ii + 1L
    }
}

fit.rows <- list()
jj <- 1L
for (case in cases) {
    for (mode in c("ambient_cpp", "local_pca_auto")) {
        message("K3.9 end-to-end: ", case$dataset, " n=", case$n,
                " mode=", mode)
        fit.rows[[jj]] <- fit_mode(case, mode)
        jj <- jj + 1L
    }
}
fit.results <- do.call(rbind, fit.rows)

profile.case <- cases[[which(vapply(cases, function(x) {
    identical(x$dataset, "depth3_top") && identical(as.integer(x$n), 250L)
}, logical(1L)))[[1L]]]]
message("K3.9 instrumented local-PCA replay: ", profile.case$dataset,
        " n=", profile.case$n)
profile <- profile_local_pca_cv(profile.case)

csv.fit <- file.path(out.root, "k3_9_end_to_end_fit_results.csv")
csv.timing <- file.path(out.root, "k3_9_local_pca_cv_timing_breakdown.csv")
csv.counts <- file.path(out.root, "k3_9_local_pca_cv_operation_counts.csv")
rds.path <- file.path(out.root, "k3_9_lps_local_pca_acceleration_bundle.rds")
html.path <- file.path(out.root, "k3_9_lps_local_pca_acceleration_audit.html")

utils::write.csv(fit.results, csv.fit, row.names = FALSE)
utils::write.csv(profile$timing, csv.timing, row.names = FALSE)
utils::write.csv(profile$counts, csv.counts, row.names = FALSE)
saveRDS(
    list(
        fit.results = fit.results,
        profile = profile,
        support.grid = support.grid,
        degree.grid = degree.grid,
        kernel.grid = kernel.grid,
        sample.sizes = sample.sizes,
        cv.folds = cv.folds
    ),
    rds.path
)

runtime.plot <- png_plot("end_to_end_runtime.png", code = {
    ok <- fit.results[fit.results$success, , drop = FALSE]
    labels <- paste(ok$dataset, ok$n, sep = "\n")
    xpos <- seq_len(nrow(ok))
    cols <- ifelse(ok$mode == "ambient_cpp", "#2f6fbd", "#b24745")
    op <- par(mar = c(8, 5, 3, 1))
    on.exit(par(op), add = TRUE)
    plot(xpos, ok$runtime.sec, pch = 19, col = cols, xaxt = "n",
         xlab = "", ylab = "Runtime (seconds)",
         main = "K3.9 End-to-End LPS Runtime")
    axis(1, at = xpos, labels = labels, las = 2, cex.axis = 0.7)
    grid()
    legend("topleft", bty = "n", pch = 19,
           col = c("#2f6fbd", "#b24745"),
           legend = c("ambient C++", "local-PCA auto R"))
})

ratio.table <- do.call(rbind, lapply(split(
    fit.results[fit.results$success, , drop = FALSE],
    paste(fit.results$dataset, fit.results$n, sep = "__")
), function(block) {
    if (!all(c("ambient_cpp", "local_pca_auto") %in% block$mode)) return(NULL)
    ambient <- block[block$mode == "ambient_cpp", , drop = FALSE]
    pca <- block[block$mode == "local_pca_auto", , drop = FALSE]
    data.frame(
        dataset = ambient$dataset[[1L]],
        n = ambient$n[[1L]],
        ambient.runtime.sec = ambient$runtime.sec[[1L]],
        local.pca.runtime.sec = pca$runtime.sec[[1L]],
        runtime.ratio = pca$runtime.sec[[1L]] / ambient$runtime.sec[[1L]],
        ambient.truth.rmse = ambient$truth.rmse[[1L]],
        local.pca.truth.rmse = pca$truth.rmse[[1L]],
        truth.rmse.delta = pca$truth.rmse[[1L]] - ambient$truth.rmse[[1L]],
        stringsAsFactors = FALSE
    )
}))

breakdown.plot <- png_plot("local_pca_cv_timing_breakdown.png", code = {
    df <- profile$timing
    op <- par(mar = c(8, 5, 3, 1))
    on.exit(par(op), add = TRUE)
    ord <- order(df$seconds, decreasing = TRUE)
    barplot(df$seconds[ord], names.arg = df$phase[ord], las = 2,
            col = "#5277a8", ylab = "Seconds",
            main = "Instrumented Local-PCA CV Timing Breakdown")
    grid(nx = NA, ny = NULL)
})

phase.summary <- profile$timing[order(profile$timing$seconds, decreasing = TRUE), ]
phase.summary$share.percent <- 100 * phase.summary$share.of.total

recommendation <- if (phase.summary$phase[[1L]] %in%
                      c("neighbor_ordering", "local_chart", "weighted_fit")) {
    paste(
        "Implement a native local-PCA LPS backend. The C++ backend should reuse",
        "ANN fold trees, call compute_local_pca_chart() for local charts, and",
        "reuse the existing C++ weighted local-polynomial normal-equation",
        "solver. This is higher leverage than R-level micro-optimizing because",
        "the measured work occurs inside per-target/per-support loops."
    )
} else {
    paste(
        "Prioritize cache/precomputation around", phase.summary$phase[[1L]],
        "before a full native backend."
    )
}

html <- paste0(
    "<!doctype html><html><head><meta charset='utf-8'>",
    "<title>K3.9 Local-PCA LPS Acceleration Audit</title>",
    "<style>",
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;line-height:1.45;margin:40px;max-width:1180px;color:#1f2933}",
    "h1,h2{color:#111827} table{border-collapse:collapse;width:100%;font-size:13px;margin:12px 0 24px}",
    "th,td{border:1px solid #d1d5db;padding:6px 8px;text-align:left;vertical-align:top}",
    "th{background:#f3f4f6} img{max-width:100%;border:1px solid #e5e7eb}",
    ".note{background:#f9fafb;border-left:4px solid #4b5563;padding:10px 14px;margin:16px 0}",
    "code{background:#f3f4f6;padding:1px 4px;border-radius:3px}",
    "</style></head><body>",
    "<h1>K3.9 Local-PCA LPS Acceleration Audit</h1>",
    "<p>This report audits why <code>fit.lps(coordinate.method = 'local.pca', ",
    "chart.dim = 'auto')</code> is slower than ambient-coordinate C++ LPS on ",
    "bounded VALENCIA-derived examples. It does not change package behavior.</p>",
    "<div class='note'><strong>Candidate grid:</strong> support sizes ",
    paste(support.grid, collapse = ", "), "; degrees ",
    paste(degree.grid, collapse = ", "), "; kernels ",
    paste(kernel.grid, collapse = ", "), "; CV folds ", cv.folds, ".</div>",
    "<h2>End-to-End Runtime</h2><p><img src='", runtime.plot,
    "' alt='end-to-end runtime'></p>",
    "<h2>Runtime Ratios and Truth RMSE</h2>",
    html_table(ratio.table),
    "<h2>Instrumented Local-PCA CV Replay</h2>",
    "<p>The replay uses <code>depth3_top</code> at <code>n = 250</code>, with ",
    "<code>", profile$profile.targets, "</code> held-out target locations. ",
    "It follows the R local-PCA CV loop and records elapsed time for chart ",
    "dimension resolution, neighbor ordering, local chart construction, kernel ",
    "weighting, weighted fitting, and final CV RMSE aggregation.</p>",
    "<p><img src='", breakdown.plot,
    "' alt='local-PCA timing breakdown'></p>",
    html_table(phase.summary[, c("phase", "seconds", "share.percent")]),
    "<h2>Operation Counts</h2>",
    html_table(profile$counts),
    "<h2>Recommendation</h2><div class='note'>",
    html_escape(recommendation),
    "</div>",
    "<h2>Files</h2><ul>",
    "<li><code>", basename(csv.fit), "</code></li>",
    "<li><code>", basename(csv.timing), "</code></li>",
    "<li><code>", basename(csv.counts), "</code></li>",
    "<li><code>", basename(rds.path), "</code></li>",
    "</ul></body></html>"
)

writeLines(html, html.path)

handoff.path <- file.path(
    getwd(),
    "split_handoffs",
    "k3_9_lps_local_pca_acceleration_audit_handoff_2026-06-04.md"
)
writeLines(c(
    "# K3.9 Handoff: Local-PCA LPS Acceleration Audit",
    "",
    "Date: 2026-06-04",
    "",
    "## Outputs",
    "",
    paste0("- HTML report: `", html.path, "`"),
    paste0("- End-to-end fit CSV: `", csv.fit, "`"),
    paste0("- Timing breakdown CSV: `", csv.timing, "`"),
    paste0("- Operation counts CSV: `", csv.counts, "`"),
    paste0("- RDS bundle: `", rds.path, "`"),
    "",
    "## Summary",
    "",
    paste0("- Median local-PCA / ambient runtime ratio: `",
           signif(stats::median(ratio.table$runtime.ratio, na.rm = TRUE), 4),
           "`."),
    paste0("- End-to-end fits succeeded for `", sum(fit.results$success),
           "` of `", nrow(fit.results), "` method/dataset/sample-size runs."),
    paste0("- Instrumented replay case: `", profile.case$dataset, "` at n = `",
           profile.case$n, "`, using `", profile$profile.targets,
           "` held-out target locations."),
    paste0("- Instrumented local-PCA replay total seconds: `",
           signif(profile$total.sec, 4), "`."),
    paste0("- Largest timed phase: `", phase.summary$phase[[1L]], "` (`",
           signif(phase.summary$seconds[[1L]], 4), " sec, ",
           signif(phase.summary$share.percent[[1L]], 4), "% of total)."),
    paste0("- Chart-dimension resolution share: `",
           signif(phase.summary$share.percent[
               match("chart_dim_resolution", phase.summary$phase)
           ], 4), "%`; weighted-fit share: `",
           signif(phase.summary$share.percent[
               match("weighted_fit", phase.summary$phase)
           ], 4), "%`."),
    "",
    "## Recommendation",
    "",
    recommendation,
    "",
    "## Precise Next Step",
    "",
    "Proceed to **K4: native local-PCA LPS backend prototype**.",
    "",
    "K4 should implement a narrow C++ backend for",
    "`fit.lps(coordinate.method = 'local.pca', local.chart.method = 'pca')`.",
    "It should not include second-order charts, MALPS, LPL-TF, or SLPL-TF.",
    "The backend should:",
    "",
    "1. Reuse ANN trees per CV fold for nearest-neighbor searches.",
    "2. Reuse `geosmooth::compute_local_pca_chart()` for local chart coordinates.",
    "3. Reuse the C++ weighted local-polynomial normal-equation code already",
    "   used by ambient LPS.",
    "4. Match the existing R local-PCA path numerically on fixed small tests.",
    "5. Keep `backend = 'auto'` unchanged until parity and speed are audited.",
    "",
    "Validation gates for K4:",
    "",
    "- targeted numerical parity tests against the current R local-PCA path;",
    "- K3.9 benchmark rerun showing speedup;",
    "- `make test`;",
    "- `git diff --check`."
), handoff.path)

cat("Wrote HTML report:", html.path, "\n")
cat("Wrote handoff:", handoff.path, "\n")
cat("End-to-end median runtime ratio:",
    stats::median(ratio.table$runtime.ratio, na.rm = TRUE), "\n")
cat("Largest local-PCA phase:", phase.summary$phase[[1L]],
    phase.summary$seconds[[1L]], "seconds\n")
cat("Recommendation:", recommendation, "\n")
