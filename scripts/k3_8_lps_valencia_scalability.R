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
    "k3_8_lps_valencia_scalability_2026-06-04"
)
fig.dir <- file.path(out.root, "k3_8_lps_valencia_scalability_report_files")
dir.create(out.root, recursive = TRUE, showWarnings = FALSE)
dir.create(fig.dir, recursive = TRUE, showWarnings = FALSE)

set.seed(20260604L)

support.grid <- c(15L, 25L, 35L)
degree.grid <- c(1L, 2L)
kernel.grid <- c("gaussian", "tricube")
sample.sizes <- c(250L, 500L)
cv.folds <- 3L

valencia.source <- path.expand("~/current_projects/valencia/tx.13k.rds")

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

plain_sample <- function(n.total, n, seed) {
    set.seed(seed)
    sort(sample(seq_len(n.total), n))
}

path_taxa <- function(labels, sep = "__") {
    unique(unlist(strsplit(labels, sep, fixed = TRUE), use.names = FALSE))
}

make_depth_dataset <- function(depth, top.k) {
    if (!file.exists(valencia.source)) {
        stop("VALENCIA source matrix not found: ", valencia.source, call. = FALSE)
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
        hypercube_Gv = list(
            X = linf::linf.hypercube.embedding(X4, reference = "Gv"),
            strata = rel4.asset$meta$dominant_component,
            feature.count = ncol(X4) - 1L,
            source = "hypercube embedding of rel4 with Gv reference"
        ),
        depth2_top = make_depth_dataset(depth = 2L, top.k = 8L),
        depth3_top = make_depth_dataset(depth = 3L, top.k = 10L)
    )
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
        which.min(rowSums((score - matrix(targets[i, ], nrow(score), 2L, byrow = TRUE))^2))
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
        d2 <- rowSums((Z - matrix(C[j, ], nrow(Z), ncol(Z), byrow = TRUE))^2)
        f <- f + amps[[j]] * exp(-d2 / (2 * sigmas[[j]]^2))
    }
    as.numeric(scale(f, center = TRUE, scale = FALSE))
}

rmse <- function(x) sqrt(mean(x^2, na.rm = TRUE))

fit_one <- function(dataset.name, dataset, n, mode, seed) {
    Xfull <- dataset$X
    if (nrow(Xfull) < n) {
        stop("Dataset ", dataset.name, " has fewer rows than requested n = ", n)
    }
    idx <- if (!is.null(dataset$strata) && length(dataset$strata) == nrow(Xfull)) {
        stratified_sample(n, dataset$strata, seed)
    } else {
        plain_sample(nrow(Xfull), n, seed)
    }
    X <- Xfull[idx, , drop = FALSE]
    f <- truth_function(X)
    noise.sd <- 0.10 * stats::sd(f)
    set.seed(seed + 10000L)
    y <- f + stats::rnorm(length(f), sd = noise.sd)
    foldid <- sample(rep(seq_len(cv.folds), length.out = n))

    args <- list(
        X = X,
        y = y,
        foldid = foldid,
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
            dataset = dataset.name,
            n = n,
            mode = mode,
            feature.count = dataset$feature.count,
            source = dataset$source,
            success = FALSE,
            runtime.sec = as.numeric(elapsed),
            truth.rmse = NA_real_,
            observed.rmse = NA_real_,
            cv.rmse = NA_real_,
            support.size = NA_integer_,
            degree = NA_integer_,
            kernel = NA_character_,
            chart.dim = NA_integer_,
            error = error,
            stringsAsFactors = FALSE
        ))
    }

    pred <- as.numeric(fit$fitted.values)
    selected <- fit$selected
    data.frame(
        dataset = dataset.name,
        n = n,
        mode = mode,
        feature.count = dataset$feature.count,
        source = dataset$source,
        success = TRUE,
        runtime.sec = as.numeric(elapsed),
        truth.rmse = rmse(pred - f),
        observed.rmse = rmse(pred - y),
        cv.rmse = selected$cv.rmse.observed[[1L]],
        support.size = selected$support.size[[1L]],
        degree = selected$degree[[1L]],
        kernel = as.character(selected$kernel[[1L]]),
        chart.dim = fit$chart.dim %||% NA_integer_,
        error = NA_character_,
        stringsAsFactors = FALSE
    )
}

`%||%` <- function(x, y) if (is.null(x)) y else x

datasets <- make_datasets()
modes <- c("ambient_cpp", "local_pca_auto")

rows <- list()
ii <- 1L
for (dataset.name in names(datasets)) {
    for (n in sample.sizes) {
        for (mode in modes) {
            message("Running ", dataset.name, " n=", n, " mode=", mode)
            rows[[ii]] <- fit_one(
                dataset.name = dataset.name,
                dataset = datasets[[dataset.name]],
                n = n,
                mode = mode,
                seed = 20260604L + ii * 97L
            )
            ii <- ii + 1L
        }
    }
}

results <- do.call(rbind, rows)
csv.path <- file.path(out.root, "k3_8_lps_valencia_scalability_results.csv")
rds.path <- file.path(out.root, "k3_8_lps_valencia_scalability_bundle.rds")
html.path <- file.path(out.root, "k3_8_lps_valencia_scalability_report.html")

utils::write.csv(results, csv.path, row.names = FALSE)
saveRDS(
    list(
        results = results,
        support.grid = support.grid,
        degree.grid = degree.grid,
        kernel.grid = kernel.grid,
        sample.sizes = sample.sizes,
        cv.folds = cv.folds,
        dataset.sources = vapply(datasets, `[[`, character(1), "source")
    ),
    rds.path
)

png_plot <- function(filename, width = 960, height = 620, code) {
    path <- file.path(fig.dir, filename)
    grDevices::png(path, width = width, height = height, res = 120)
    on.exit(grDevices::dev.off(), add = TRUE)
    force(code)
    file.path("k3_8_lps_valencia_scalability_report_files", filename)
}

plot_runtime <- png_plot("runtime_by_dataset.png", code = {
    ok <- results[results$success, , drop = FALSE]
    op <- par(mar = c(9, 5, 3, 1))
    on.exit(par(op), add = TRUE)
    labels <- paste(ok$dataset, ok$n, ok$mode, sep = "\n")
    cols <- ifelse(ok$mode == "ambient_cpp", "#2f6fbd", "#b24745")
    plot(seq_len(nrow(ok)), ok$runtime.sec, pch = 19, col = cols,
         xaxt = "n", xlab = "", ylab = "Runtime (seconds)",
         main = "LPS Runtime by Dataset, n, and Mode")
    axis(1, at = seq_len(nrow(ok)), labels = labels, las = 2, cex.axis = 0.58)
    grid()
    legend("topleft", legend = c("ambient_cpp", "local_pca_auto"),
           col = c("#2f6fbd", "#b24745"), pch = 19, bty = "n")
})

plot_truth <- png_plot("truth_rmse_by_dataset.png", code = {
    ok <- results[results$success, , drop = FALSE]
    op <- par(mar = c(9, 5, 3, 1))
    on.exit(par(op), add = TRUE)
    labels <- paste(ok$dataset, ok$n, ok$mode, sep = "\n")
    cols <- ifelse(ok$mode == "ambient_cpp", "#2f6fbd", "#b24745")
    plot(seq_len(nrow(ok)), ok$truth.rmse, pch = 19, col = cols,
         xaxt = "n", xlab = "", ylab = "Truth RMSE",
         main = "Truth RMSE by Dataset, n, and Mode")
    axis(1, at = seq_len(nrow(ok)), labels = labels, las = 2, cex.axis = 0.58)
    grid()
    legend("topleft", legend = c("ambient_cpp", "local_pca_auto"),
           col = c("#2f6fbd", "#b24745"), pch = 19, bty = "n")
})

wide_delta <- function(metric) {
    ok <- results[results$success, , drop = FALSE]
    key <- paste(ok$dataset, ok$n, sep = "__")
    split.rows <- split(seq_len(nrow(ok)), key)
    out <- lapply(split.rows, function(ii) {
        block <- ok[ii, , drop = FALSE]
        if (!all(c("ambient_cpp", "local_pca_auto") %in% block$mode)) return(NULL)
        ambient <- block[block$mode == "ambient_cpp", , drop = FALSE]
        pca <- block[block$mode == "local_pca_auto", , drop = FALSE]
        data.frame(
            dataset = ambient$dataset[[1L]],
            n = ambient$n[[1L]],
            delta = pca[[metric]][[1L]] - ambient[[metric]][[1L]],
            ambient = ambient[[metric]][[1L]],
            local.pca = pca[[metric]][[1L]],
            stringsAsFactors = FALSE
        )
    })
    do.call(rbind, out)
}

truth.delta <- wide_delta("truth.rmse")
runtime.delta <- wide_delta("runtime.sec")

plot_delta <- png_plot("local_pca_minus_ambient_delta.png", code = {
    op <- par(mar = c(8, 5, 3, 1))
    on.exit(par(op), add = TRUE)
    labels <- paste(truth.delta$dataset, truth.delta$n, sep = "\n")
    cols <- ifelse(truth.delta$delta <= 0, "#2a8c55", "#b24745")
    plot(seq_len(nrow(truth.delta)), truth.delta$delta, pch = 19, col = cols,
         xaxt = "n", xlab = "", ylab = "Truth RMSE delta",
         main = "Local-PCA LPS minus Ambient LPS Truth RMSE")
    abline(h = 0, lty = 2, col = "gray40")
    axis(1, at = seq_len(nrow(truth.delta)), labels = labels, las = 2,
         cex.axis = 0.7)
    grid()
})

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
        paste0("<tr>", paste0("<td>", html_escape(row), "</td>", collapse = ""), "</tr>")
    })
    paste0("<table><thead><tr>", header, "</tr></thead><tbody>",
           paste(rows, collapse = "\n"), "</tbody></table>")
}

summary.table <- results[order(results$dataset, results$n, results$mode),
                         c("dataset", "n", "mode", "feature.count", "success",
                           "runtime.sec", "truth.rmse", "observed.rmse",
                           "cv.rmse", "support.size", "degree", "kernel",
                           "chart.dim", "error")]

delta.table <- merge(
    truth.delta,
    runtime.delta[, c("dataset", "n", "delta")],
    by = c("dataset", "n"),
    suffixes = c(".truth.rmse", ".runtime.sec")
)

html <- paste0(
    "<!doctype html><html><head><meta charset='utf-8'>",
    "<title>K3.8 LPS VALENCIA Scalability</title>",
    "<style>",
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;line-height:1.45;margin:40px;max-width:1180px;color:#1f2933}",
    "h1,h2{color:#111827} table{border-collapse:collapse;width:100%;font-size:13px;margin:12px 0 24px}",
    "th,td{border:1px solid #d1d5db;padding:6px 8px;text-align:left;vertical-align:top}",
    "th{background:#f3f4f6} img{max-width:100%;border:1px solid #e5e7eb}",
    ".note{background:#f9fafb;border-left:4px solid #4b5563;padding:10px 14px;margin:16px 0}",
    "code{background:#f3f4f6;padding:1px 4px;border-radius:3px}",
    "</style></head><body>",
    "<h1>K3.8 LPS VALENCIA Scalability Report</h1>",
    "<p>This bounded K3.8 run compares ambient-coordinate LPS against ordinary ",
    "local-PCA LPS on VALENCIA-derived compositional geometries. Harlim ",
    "second-order charts are intentionally excluded.</p>",
    "<div class='note'><strong>Candidate grid:</strong> support sizes ",
    paste(support.grid, collapse = ", "), "; degrees ",
    paste(degree.grid, collapse = ", "), "; kernels ",
    paste(kernel.grid, collapse = ", "), "; CV folds ", cv.folds, ".</div>",
    "<h2>Runtime</h2><p><img src='", plot_runtime, "' alt='runtime plot'></p>",
    "<h2>Truth RMSE</h2><p><img src='", plot_truth, "' alt='truth rmse plot'></p>",
    "<h2>Local-PCA Minus Ambient Delta</h2>",
    "<p>Negative values mean local-PCA LPS had lower Truth RMSE than ambient LPS. ",
    "Positive values mean ambient LPS did better.</p>",
    "<p><img src='", plot_delta, "' alt='truth rmse delta plot'></p>",
    "<h2>Paired Delta Table</h2>",
    html_table(delta.table),
    "<h2>Full Result Table</h2>",
    html_table(summary.table),
    "<h2>Files</h2><ul>",
    "<li><code>", basename(csv.path), "</code></li>",
    "<li><code>", basename(rds.path), "</code></li>",
    "</ul>",
    "</body></html>"
)

writeLines(html, html.path)

cat("Wrote results:", csv.path, "\n")
cat("Wrote bundle:", rds.path, "\n")
cat("Wrote report:", html.path, "\n")
print(results)
