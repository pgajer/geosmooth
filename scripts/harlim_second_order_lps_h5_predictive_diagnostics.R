#!/usr/bin/env Rscript

root <- getwd()
h5.dir <- file.path(
    root,
    "split_handoffs",
    "harlim_second_order_lps_h5_expanded_eval_2026-06-04"
)
input.table.dir <- file.path(h5.dir, "tables")
out.dir <- file.path(
    root,
    "split_handoffs",
    "harlim_second_order_lps_h5_predictive_diagnostics_2026-06-04"
)
table.dir <- file.path(out.dir, "tables")
fig.dir <- file.path(out.dir, "report_files")
dir.create(table.dir, recursive = TRUE, showWarnings = FALSE)
dir.create(fig.dir, recursive = TRUE, showWarnings = FALSE)

paired.path <- file.path(input.table.dir, "h5_lps_chart_paired_results.csv")
fit.path <- file.path(input.table.dir, "h5_lps_chart_fit_results.csv")
diag.path <- file.path(input.table.dir,
                       "h5_lps_chart_second_order_diagnostics.csv")

abs.material.threshold <- 0.005
rel.material.threshold <- 0.02

read.csv2 <- function(path) {
    utils::read.csv(path, stringsAsFactors = FALSE,
                    na.strings = c("", "NA", "NaN"))
}

write.csv2 <- function(x, path) {
    utils::write.csv(x, path, row.names = FALSE, na = "")
    invisible(path)
}

html.escape <- function(x) {
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    gsub(">", "&gt;", x, fixed = TRUE)
}

fmt <- function(x, digits = 4L) {
    ifelse(is.finite(x), formatC(x, digits = digits, format = "fg"), "NA")
}

safe.ratio <- function(num, den) {
    out <- as.numeric(num) / as.numeric(den)
    out[!is.finite(out) | !is.finite(den) | den <= .Machine$double.eps] <-
        NA_real_
    out
}

qfun <- function(x, prob) {
    x <- as.numeric(x)
    x <- x[is.finite(x)]
    if (!length(x)) return(NA_real_)
    as.numeric(stats::quantile(x, prob, na.rm = TRUE, names = FALSE))
}

median.finite <- function(x) qfun(x, 0.5)
q90.finite <- function(x) qfun(x, 0.9)
max.finite <- function(x) {
    x <- as.numeric(x)
    x <- x[is.finite(x)]
    if (!length(x)) return(NA_real_)
    max(x)
}

paired <- read.csv2(paired.path)
fits <- read.csv2(fit.path)
diag <- read.csv2(diag.path)

diag$corrected.over.fit <- safe.ratio(
    diag$corrected.residual.frobenius,
    diag$fit.residual.frobenius
)
diag$curvature.over.fit <- safe.ratio(
    diag$curvature.fitted.frobenius,
    diag$fit.residual.frobenius
)
diag$log10.design.condition <- log10(diag$design.condition)
diag$log10.design.condition[!is.finite(diag$log10.design.condition)] <-
    NA_real_

diag.split <- split(diag, diag$case.id)
diag.summary <- do.call(rbind, lapply(names(diag.split), function(case.id) {
    x <- diag.split[[case.id]]
    data.frame(
        case.id = case.id,
        n.chart.diagnostics = nrow(x),
        fit.residual.median = median.finite(x$fit.residual.frobenius),
        fit.residual.q90 = q90.finite(x$fit.residual.frobenius),
        curvature.fitted.median =
            median.finite(x$curvature.fitted.frobenius),
        curvature.fitted.q90 = q90.finite(x$curvature.fitted.frobenius),
        corrected.residual.median =
            median.finite(x$corrected.residual.frobenius),
        corrected.residual.q90 =
            q90.finite(x$corrected.residual.frobenius),
        corrected.over.fit.median = median.finite(x$corrected.over.fit),
        corrected.over.fit.q90 = q90.finite(x$corrected.over.fit),
        curvature.over.fit.median = median.finite(x$curvature.over.fit),
        curvature.over.fit.q90 = q90.finite(x$curvature.over.fit),
        design.condition.median = median.finite(x$design.condition),
        design.condition.q90 = q90.finite(x$design.condition),
        design.condition.max = max.finite(x$design.condition),
        log10.design.condition.median =
            median.finite(x$log10.design.condition),
        log10.design.condition.q90 = q90.finite(x$log10.design.condition),
        log10.design.condition.max = max.finite(x$log10.design.condition),
        first.rank.median = median.finite(x$first.rank),
        first.rank.q90 = q90.finite(x$first.rank),
        second.rank.median = median.finite(x$second.rank),
        second.rank.q90 = q90.finite(x$second.rank),
        design.rank.median = median.finite(x$design.rank),
        design.rank.q90 = q90.finite(x$design.rank),
        fallback.count = sum(as.logical(x$fallback.used), na.rm = TRUE),
        fallback.rate = mean(as.logical(x$fallback.used), na.rm = TRUE),
        stringsAsFactors = FALSE
    )
}))
rownames(diag.summary) <- NULL

case <- merge(paired, diag.summary, by = "case.id", all.x = TRUE)
case$delta.abs <- case$delta.truth.rmse
case$delta.rel <- case$delta.truth.rmse / case$pca.truth.rmse
case$fallback.category <- ifelse(
    case$second.fallback.rate >= 1 - .Machine$double.eps,
    "full",
    ifelse(case$second.fallback.rate > 0, "partial", "none")
)
case$effective.second.order.case <- case$fallback.category != "full" &
    case$pca.fit.status == "ok" & case$second.fit.status == "ok"
case$high.dim.flag <- case$ambient.dimension >= 10L
case$singular.flag <- grepl(
    "singular|nearline|cone|cusp|folded",
    case$case.id,
    ignore.case = TRUE
)
case$valencia.flag <- grepl("valencia", case$case.id, ignore.case = TRUE) |
    grepl("valencia", case$geometry.family, ignore.case = TRUE)
case$geometry.bucket <- ifelse(
    case$valencia.flag,
    "valencia_probe",
    ifelse(case$high.dim.flag,
           ifelse(grepl("3d", case$case.id, ignore.case = TRUE),
                  "highdim_3d", "highdim_2d"),
           ifelse(case$singular.flag,
                  ifelse(grepl("3d", case$case.id, ignore.case = TRUE),
                         "singular_3d", "singular_2d"),
                  ifelse(grepl("3d", case$case.id, ignore.case = TRUE),
                         "curved_3d", "curved_2d")))
)
case$support.delta <- case$second.selected.support.size -
    case$pca.selected.support.size
case$degree.delta <- case$second.selected.degree - case$pca.selected.degree
case$chart.dim.delta <- case$second.selected.chart.dim -
    case$pca.selected.chart.dim
case$same.support <- case$support.delta == 0
case$same.degree <- case$degree.delta == 0
case$same.kernel <- case$pca.selected.kernel == case$second.selected.kernel
case$same.chart.dim <- case$chart.dim.delta == 0
case$material.abs.exceeded <- abs(case$delta.abs) > abs.material.threshold
case$material.rel.exceeded <- abs(case$delta.rel) > rel.material.threshold
case$practical.outcome <- ifelse(
    case$fallback.category == "full",
    "full_fallback_noninformative",
    ifelse(
        !case$material.abs.exceeded & !case$material.rel.exceeded,
        "practical_tie",
        ifelse(case$delta.abs < 0,
               "material_second_order_win",
               "material_pca_win")
    )
)

predictor.cols <- c(
    "ambient.dimension",
    "high.dim.flag",
    "singular.flag",
    "valencia.flag",
    "second.selected.support.size",
    "second.selected.degree",
    "second.selected.chart.dim",
    "support.delta",
    "degree.delta",
    "chart.dim.delta",
    "runtime.ratio.second_over_pca",
    "second.fallback.rate",
    "fit.residual.median",
    "fit.residual.q90",
    "curvature.fitted.median",
    "curvature.fitted.q90",
    "corrected.residual.median",
    "corrected.residual.q90",
    "corrected.over.fit.median",
    "corrected.over.fit.q90",
    "curvature.over.fit.median",
    "curvature.over.fit.q90",
    "design.condition.median",
    "design.condition.q90",
    "design.condition.max",
    "log10.design.condition.median",
    "log10.design.condition.q90",
    "log10.design.condition.max",
    "first.rank.median",
    "second.rank.median",
    "design.rank.median"
)

effective <- case[case$effective.second.order.case, , drop = FALSE]
cor.rows <- lapply(predictor.cols, function(col) {
    x <- effective[[col]]
    if (is.logical(x)) x <- as.numeric(x)
    ok <- is.finite(x) & is.finite(effective$delta.abs)
    if (sum(ok) < 4L || length(unique(x[ok])) < 2L) {
        rho.abs <- NA_real_
        rho.rel <- NA_real_
    } else {
        rho.abs <- suppressWarnings(stats::cor(
            x[ok],
            effective$delta.abs[ok],
            method = "spearman"
        ))
        rho.rel <- suppressWarnings(stats::cor(
            x[ok],
            effective$delta.rel[ok],
            method = "spearman"
        ))
    }
    data.frame(
        predictor = col,
        spearman.delta.abs = rho.abs,
        spearman.delta.rel = rho.rel,
        n.used = sum(ok),
        stringsAsFactors = FALSE
    )
})
correlations <- do.call(rbind, cor.rows)
correlations$abs.rho <- pmax(abs(correlations$spearman.delta.abs),
                             abs(correlations$spearman.delta.rel),
                             na.rm = TRUE)
correlations$abs.rho[!is.finite(correlations$abs.rho)] <- NA_real_
correlations <- correlations[order(correlations$abs.rho, decreasing = TRUE,
                                   na.last = TRUE), ]
rownames(correlations) <- NULL

group.summary <- aggregate(
    cbind(delta.abs, delta.rel, runtime.ratio.second_over_pca,
          second.fallback.rate) ~ geometry.bucket,
    data = case,
    FUN = function(x) c(n = length(x),
                        median = stats::median(x, na.rm = TRUE),
                        mean = mean(x, na.rm = TRUE),
                        min = min(x, na.rm = TRUE),
                        max = max(x, na.rm = TRUE))
)

practical.counts <- as.data.frame(table(
    case$geometry.bucket,
    case$practical.outcome
), stringsAsFactors = FALSE)
names(practical.counts) <- c("geometry.bucket", "practical.outcome", "count")

case.path <- file.path(table.dir,
                       "h5_1_case_level_predictive_diagnostics.csv")
cor.path <- file.path(table.dir, "h5_1_predictor_rank_correlations.csv")
group.path <- file.path(table.dir, "h5_1_geometry_bucket_summary.csv")
counts.path <- file.path(table.dir, "h5_1_practical_outcome_counts.csv")
write.csv2(case, case.path)
write.csv2(correlations, cor.path)
write.csv2(group.summary, group.path)
write.csv2(practical.counts, counts.path)

point.color <- function(x) {
    out <- rep("#4b5563", length(x))
    out[x == "material_second_order_win"] <- "#2f855a"
    out[x == "material_pca_win"] <- "#c53030"
    out[x == "practical_tie"] <- "#718096"
    out[x == "full_fallback_noninformative"] <- "#dd6b20"
    out
}

figure.paths <- list(
    delta.band = file.path(fig.dir, "h5_1_delta_practical_band.png"),
    rel.family = file.path(fig.dir, "h5_1_relative_delta_by_family.png"),
    condition = file.path(fig.dir, "h5_1_delta_vs_condition.png"),
    ratios = file.path(fig.dir, "h5_1_delta_vs_curvature_ratios.png"),
    fallback = file.path(fig.dir, "h5_1_delta_by_fallback_category.png"),
    top.panel = file.path(fig.dir, "h5_1_top_win_loss_panel.png"),
    valencia = file.path(fig.dir, "h5_1_valencia_probe.png")
)

plot.delta.band <- function() {
    df <- case[order(case$delta.abs), , drop = FALSE]
    png(figure.paths$delta.band, width = 1250,
        height = max(820, 34 * nrow(df) + 260), res = 130)
    par(mar = c(4.7, 13, 3, 1))
    y <- seq_len(nrow(df))
    xlim <- range(c(df$delta.abs, -abs.material.threshold,
                    abs.material.threshold), na.rm = TRUE)
    plot(df$delta.abs, y,
         yaxt = "n",
         ylab = "",
         xlab = "Delta Truth RMSE (second.order.svd - pca)",
         pch = ifelse(df$fallback.category == "full", 1, 19),
         col = point.color(df$practical.outcome),
         xlim = xlim,
         main = "Absolute Delta With Practical-Equivalence Band")
    rect(-abs.material.threshold, 0,
         abs.material.threshold, nrow(df) + 1,
         col = grDevices::adjustcolor("#718096", alpha.f = 0.12),
         border = NA)
    points(df$delta.abs, y,
           pch = ifelse(df$fallback.category == "full", 1, 19),
           col = point.color(df$practical.outcome))
    axis(2, at = y, labels = df$case.id, las = 1, cex.axis = 0.68)
    abline(v = 0, col = "gray35", lty = 2)
    legend("bottomright",
           legend = c("material second-order", "material PCA",
                      "practical tie", "full fallback"),
           pch = c(19, 19, 19, 1),
           col = c("#2f855a", "#c53030", "#718096", "#dd6b20"),
           bty = "n")
    dev.off()
}

plot.rel.family <- function() {
    fam <- unique(case$geometry.bucket)
    x <- seq_along(fam)
    png(figure.paths$rel.family, width = 1250, height = 780, res = 130)
    par(mar = c(9, 4.5, 3, 1))
    plot(NA, xlim = c(0.5, length(fam) + 0.5),
         ylim = range(c(case$delta.rel, -rel.material.threshold,
                        rel.material.threshold), na.rm = TRUE),
         xaxt = "n", xlab = "", ylab = "Relative Delta",
         main = "Relative Delta by Geometry Bucket")
    rect(0.5, -rel.material.threshold, length(fam) + 0.5,
         rel.material.threshold,
         col = grDevices::adjustcolor("#718096", alpha.f = 0.12),
         border = NA)
    for (i in seq_along(fam)) {
        ids <- which(case$geometry.bucket == fam[[i]])
        jittered <- rep(i, length(ids)) +
            seq(-0.14, 0.14, length.out = length(ids))
        points(jittered, case$delta.rel[ids],
               pch = ifelse(case$fallback.category[ids] == "full", 1, 19),
               col = point.color(case$practical.outcome[ids]))
    }
    abline(h = 0, col = "gray35", lty = 2)
    axis(1, at = x, labels = fam, las = 2, cex.axis = 0.75)
    dev.off()
}

plot.condition <- function() {
    png(figure.paths$condition, width = 1100, height = 760, res = 130)
    par(mar = c(4.5, 4.5, 3, 1))
    plot(case$log10.design.condition.median,
         case$delta.abs,
         xlab = "Median log10(design condition)",
         ylab = "Delta Truth RMSE",
         pch = ifelse(case$fallback.category == "full", 1, 19),
         col = point.color(case$practical.outcome),
         main = "Delta Versus Condition Summary")
    abline(h = 0, col = "gray35", lty = 2)
    abline(h = c(-abs.material.threshold, abs.material.threshold),
           col = "gray70", lty = 3)
    text(case$log10.design.condition.median[case$valencia.flag],
         case$delta.abs[case$valencia.flag],
         labels = "VALENCIA", pos = 4, cex = 0.8)
    dev.off()
}

plot.ratios <- function() {
    png(figure.paths$ratios, width = 1350, height = 680, res = 130)
    par(mfrow = c(1, 2), mar = c(4.5, 4.5, 3, 1))
    plot(case$curvature.over.fit.median, case$delta.abs,
         xlab = "Median curvature fitted / fit residual",
         ylab = "Delta Truth RMSE",
         pch = ifelse(case$fallback.category == "full", 1, 19),
         col = point.color(case$practical.outcome),
         main = "Curvature Ratio")
    abline(h = 0, col = "gray35", lty = 2)
    plot(case$corrected.over.fit.median, case$delta.abs,
         xlab = "Median corrected residual / fit residual",
         ylab = "Delta Truth RMSE",
         pch = ifelse(case$fallback.category == "full", 1, 19),
         col = point.color(case$practical.outcome),
         main = "Corrected Residual Ratio")
    abline(h = 0, col = "gray35", lty = 2)
    dev.off()
}

plot.fallback <- function() {
    cats <- c("none", "partial", "full")
    png(figure.paths$fallback, width = 1000, height = 680, res = 130)
    par(mar = c(4.5, 4.5, 3, 1))
    plot(NA, xlim = c(0.5, 3.5),
         ylim = range(case$delta.abs, na.rm = TRUE),
         xaxt = "n", xlab = "Fallback Category",
         ylab = "Delta Truth RMSE",
         main = "Delta by Fallback Category")
    for (i in seq_along(cats)) {
        ids <- which(case$fallback.category == cats[[i]])
        if (!length(ids)) next
        jittered <- rep(i, length(ids)) +
            seq(-0.12, 0.12, length.out = length(ids))
        points(jittered, case$delta.abs[ids],
               pch = ifelse(case$fallback.category[ids] == "full", 1, 19),
               col = point.color(case$practical.outcome[ids]))
    }
    abline(h = 0, col = "gray35", lty = 2)
    axis(1, at = seq_along(cats), labels = cats)
    dev.off()
}

plot.top.panel <- function() {
    usable <- case[case$effective.second.order.case, , drop = FALSE]
    wins <- usable[order(usable$delta.abs), , drop = FALSE]
    losses <- usable[order(usable$delta.abs, decreasing = TRUE), ,
                     drop = FALSE]
    top <- rbind(head(wins, 5), head(losses, 5))
    top$label <- paste0(top$case.id, "\n",
                        "cond=", fmt(top$log10.design.condition.median, 3L),
                        " ratio=", fmt(top$curvature.over.fit.median, 3L))
    png(figure.paths$top.panel, width = 1300, height = 780, res = 130)
    par(mar = c(11, 4.5, 3, 1))
    cols <- ifelse(top$delta.abs < 0, "#2f855a", "#c53030")
    bp <- barplot(top$delta.abs, names.arg = top$label,
                  las = 2, col = cols,
                  ylab = "Delta Truth RMSE",
                  main = "Top Effective Second-Order Wins and PCA Wins")
    abline(h = 0, col = "gray35", lty = 2)
    text(bp, top$delta.abs,
         labels = paste0("d=", fmt(top$delta.rel, 3L)),
         pos = ifelse(top$delta.abs < 0, 1, 3),
         cex = 0.72)
    dev.off()
}

plot.valencia <- function() {
    v <- case[case$valencia.flag, , drop = FALSE]
    nonv <- case[!case$valencia.flag, , drop = FALSE]
    metrics <- c("delta.abs", "delta.rel",
                 "runtime.ratio.second_over_pca",
                 "log10.design.condition.median",
                 "curvature.over.fit.median")
    labels <- c("absolute delta", "relative delta", "runtime ratio",
                "median log10 condition", "curvature/fit ratio")
    vals <- as.numeric(v[1L, metrics])
    med <- vapply(metrics, function(m) stats::median(nonv[[m]], na.rm = TRUE),
                  numeric(1L))
    q10 <- vapply(metrics, function(m) qfun(nonv[[m]], 0.10), numeric(1L))
    q90 <- vapply(metrics, function(m) qfun(nonv[[m]], 0.90), numeric(1L))
    png(figure.paths$valencia, width = 1150, height = 720, res = 130)
    par(mar = c(8, 4.5, 3, 1))
    y <- seq_along(metrics)
    xlim <- range(c(vals, med, q10, q90), na.rm = TRUE)
    plot(NA, xlim = xlim, ylim = c(0.5, length(metrics) + 0.5),
         yaxt = "n", xlab = "Metric Value", ylab = "",
         main = "VALENCIA-Derived Probe Versus Synthetic Distribution")
    segments(q10, y, q90, y, col = "gray55", lwd = 4)
    points(med, y, pch = 19, col = "#2b6cb0")
    points(vals, y, pch = 18, col = "#dd6b20", cex = 1.4)
    axis(2, at = y, labels = labels, las = 1, cex.axis = 0.8)
    legend("bottomright",
           legend = c("non-VALENCIA median", "non-VALENCIA 10-90%",
                      "VALENCIA"),
           pch = c(19, NA, 18), lwd = c(NA, 4, NA),
           col = c("#2b6cb0", "gray55", "#dd6b20"),
           bty = "n")
    dev.off()
}

plot.delta.band()
plot.rel.family()
plot.condition()
plot.ratios()
plot.fallback()
plot.top.panel()
plot.valencia()

counts <- as.data.frame(table(case$practical.outcome),
                        stringsAsFactors = FALSE)
names(counts) <- c("practical.outcome", "count")
effective.counts <- as.data.frame(table(
    effective$practical.outcome
), stringsAsFactors = FALSE)
names(effective.counts) <- c("practical.outcome", "count")
top.cors <- head(correlations[is.finite(correlations$abs.rho), ], 8)

report.path <- file.path(out.dir,
                         "h5_predictive_diagnostics_addendum_report.html")
rel.band <- paste0("+/-", rel.material.threshold * 100, "%")
abs.band <- paste0("+/-", abs.material.threshold)

html <- c(
    "<!doctype html>",
    "<html><head><meta charset='utf-8'>",
    "<title>H5.1 Predictive Diagnostics Addendum</title>",
    "<style>",
    "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;margin:32px;line-height:1.45;color:#1f2933}",
    "h1,h2{color:#111827}.note{background:#eef6ff;border-left:4px solid #2b6cb0;padding:10px 12px}.warn{background:#fff7ed;border-left:4px solid #dd6b20;padding:10px 12px}img{max-width:100%;height:auto;border:1px solid #e5e7eb;margin:8px 0 22px 0}ul{max-width:950px}",
    "</style></head><body>",
    "<h1>H5.1 Predictive Diagnostics Addendum</h1>",
    paste0("<p>Generated ", html.escape(format(
        Sys.time(), "%Y-%m-%d %H:%M:%S %Z", tz = "America/New_York"
    )), ".</p>"),
    "<div class='note'>No models were refit. This addendum uses the existing H5 paired, fit, and second-order diagnostic CSV artifacts.</div>",
    "<h2>Materiality Rule</h2>",
    paste0("<p>Absolute Delta uses second-order Truth RMSE minus PCA Truth RMSE. Relative Delta divides by PCA Truth RMSE. Practical ties are cases inside both the ",
           html.escape(abs.band), " absolute band and the ",
           html.escape(rel.band), " relative band. Full fallback cases are labeled non-informative for second-order accuracy.</p>"),
    "<h2>Headline</h2>",
    paste0("<p>Cases: ", nrow(case), "; effective second-order cases: ",
           nrow(effective), "; full fallback cases: ",
           sum(case$fallback.category == "full"), ".</p>"),
    paste0("<p>Practical outcomes: ",
           html.escape(paste(paste0(counts$practical.outcome, "=",
                                    counts$count), collapse = "; ")),
           ".</p>"),
    paste0("<p>Strongest available rank-correlation signals are modest: ",
           html.escape(paste(paste0(top.cors$predictor, " (rho~",
                                    fmt(top.cors$abs.rho, 3L), ")"),
                             collapse = "; ")),
           ".</p>"),
    "<div class='warn'>This 27-case single-replicate suite is useful for choosing H6 diagnostics, not for claiming predictive success.</div>",
    "<h2>1. Absolute Delta and Practical Band</h2>",
    paste0("<img src='report_files/",
           basename(figure.paths$delta.band), "' alt='Delta practical band'>"),
    "<h2>2. Relative Delta by Geometry Bucket</h2>",
    paste0("<img src='report_files/",
           basename(figure.paths$rel.family), "' alt='Relative delta by family'>"),
    "<h2>3. Delta Versus Condition</h2>",
    paste0("<img src='report_files/",
           basename(figure.paths$condition), "' alt='Delta versus condition'>"),
    "<h2>4. Delta Versus Curvature and Residual Ratios</h2>",
    paste0("<img src='report_files/",
           basename(figure.paths$ratios), "' alt='Delta versus ratios'>"),
    "<h2>5. Delta by Fallback Category</h2>",
    paste0("<img src='report_files/",
           basename(figure.paths$fallback), "' alt='Delta by fallback'>"),
    "<h2>6. Top Win/Loss Diagnostic Panel</h2>",
    paste0("<img src='report_files/",
           basename(figure.paths$top.panel), "' alt='Top win loss panel'>"),
    "<h2>7. VALENCIA Probe</h2>",
    paste0("<img src='report_files/",
           basename(figure.paths$valencia), "' alt='VALENCIA probe'>"),
    "<h2>CSV Artifacts</h2>",
    "<ul>",
    "<li>tables/h5_1_case_level_predictive_diagnostics.csv</li>",
    "<li>tables/h5_1_predictor_rank_correlations.csv</li>",
    "<li>tables/h5_1_geometry_bucket_summary.csv</li>",
    "<li>tables/h5_1_practical_outcome_counts.csv</li>",
    "</ul>",
    "</body></html>"
)
writeLines(html, report.path)

cat("Wrote:", out.dir, "\n")
cat("Case rows:", nrow(case), "\n")
cat("Effective second-order cases:", nrow(effective), "\n")
cat("Practical outcome counts:\n")
print(counts, row.names = FALSE)
cat("Top correlations:\n")
print(top.cors[, c("predictor", "spearman.delta.abs",
                   "spearman.delta.rel", "abs.rho", "n.used")],
      row.names = FALSE)

invisible(case)
