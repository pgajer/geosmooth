#!/usr/bin/env Rscript

pkgload::load_all(".", quiet = TRUE)

`%||%` <- function(x, y) {
    if (is.null(x)) y else x
}

timestamp.eastern <- function() {
    format(as.POSIXct(Sys.time(), tz = "America/New_York"),
           "%Y-%m-%d %H:%M:%S %Z")
}

rmse <- function(a, b) {
    sqrt(mean((a - b)^2))
}

html.escape <- function(x) {
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    gsub(">", "&gt;", x, fixed = TRUE)
}

fmt <- function(x, digits = 4) {
    ifelse(is.na(x), "NA",
           ifelse(is.finite(x), formatC(x, format = "fg", digits = digits),
                  as.character(x)))
}

asset.dir <- file.path(
    "split_handoffs",
    "lps_local_auto_nonmanifold_first_batch_2026-06-05",
    "assets"
)

out.dir <- file.path(
    "split_handoffs",
    "lps_ps_lps_design_basis_focused_comparison_2026-06-06"
)
table.dir <- file.path(out.dir, "tables")
dir.create(table.dir, recursive = TRUE, showWarnings = FALSE)

dataset.files <- c(
    "LA-D1-RAW-N500.rds",
    "LA-D1-HC-Li-N500.rds",
    "SYN-PARA-LINE-N500.rds",
    "SYN-RANK-BLOCKS-N600-P100.rds"
)

backend.variants <- list(
    monomial_tiny_ridge = list(
        label = "monomial + tiny ridge",
        design.basis = "monomial",
        design.drop.tol = 1e-8,
        ridge.multiplier.grid = 1e-8,
        ridge.condition.max = Inf
    ),
    weighted_qr_drop_tiny = list(
        label = "weighted QR drop + tiny/adaptive ridge",
        design.basis = "weighted.qr.drop",
        design.drop.tol = 1e-8,
        ridge.multiplier.grid = c(0, 1e-10, 1e-8),
        ridge.condition.max = 1e12
    ),
    orthogonal_drop_ridge0 = list(
        label = "orthogonal polynomial drop, ridge 0",
        design.basis = "orthogonal.polynomial.drop",
        design.drop.tol = 1e-8,
        ridge.multiplier.grid = 0,
        ridge.condition.max = Inf
    ),
    orthogonal_drop_adaptive_tiny = list(
        label = "orthogonal polynomial drop + tiny/adaptive ridge",
        design.basis = "orthogonal.polynomial.drop",
        design.drop.tol = 1e-8,
        ridge.multiplier.grid = c(0, 1e-10, 1e-8),
        ridge.condition.max = 1e12
    )
)

methods <- c("LPS", "PS-LPS")

subset.asset <- function(dat, n.max = 160L) {
    n <- nrow(dat$X)
    if (n <= n.max) {
        idx <- seq_len(n)
    } else {
        set.seed(abs(sum(utf8ToInt(dat$dataset.id))) %% .Machine$integer.max)
        if (!is.null(dat$region.label)) {
            labs <- as.factor(dat$region.label)
            lab.counts <- table(labs)
            per.level <- pmax(1L, floor(n.max * as.numeric(lab.counts) / n))
            names(per.level) <- names(lab.counts)
            idx <- unlist(lapply(levels(labs), function(ll) {
                pool <- which(labs == ll)
                sample(pool, min(length(pool), per.level[[ll]]))
            }), use.names = FALSE)
            if (length(idx) < n.max) {
                rest <- setdiff(seq_len(n), idx)
                idx <- c(idx, sample(rest, min(length(rest), n.max - length(idx))))
            }
            idx <- sort(idx[seq_len(min(length(idx), n.max))])
        } else {
            idx <- sort(sample(seq_len(n), n.max))
        }
    }
    dat$X <- dat$X[idx, , drop = FALSE]
    dat$y <- dat$y[idx]
    dat$f <- dat$f[idx]
    dat$foldid <- if (!is.null(dat$foldid)) dat$foldid[idx] else
        rep(seq_len(5L), length.out = length(idx))
    if (!is.null(dat$latent)) {
        dat$latent <- dat$latent[idx, , drop = FALSE]
    }
    if (!is.null(dat$region.label)) {
        dat$region.label <- dat$region.label[idx]
    }
    dat$subset.n <- length(idx)
    dat
}

run.fit <- function(dat, method.id, variant.id, variant) {
    t0 <- proc.time()
    warning.messages <- character()
    fit <- withCallingHandlers(
        tryCatch({
            if (identical(method.id, "LPS")) {
                fit.lps(
                    X = dat$X,
                    y = dat$y,
                    foldid = dat$foldid,
                    support.grid = c(15L, 25L),
                    degree.grid = 2L,
                    kernel.grid = "tricube",
                    coordinate.method = "local.pca",
                    chart.dim = "auto",
                    backend = "auto",
                    design.basis = variant$design.basis,
                    design.drop.tol = variant$design.drop.tol,
                    ridge.multiplier.grid = variant$ridge.multiplier.grid,
                    ridge.condition.max = variant$ridge.condition.max,
                    unstable.action = "na"
                )
            } else {
                fit.ps.lps(
                    X = dat$X,
                    y = dat$y,
                    foldid = dat$foldid,
                    support.grid = c(15L, 25L),
                    degree.grid = 2L,
                    kernel.grid = "tricube",
                    chart.dim = "auto",
                    lambda.sync.grid = c(0, 0.01, 0.1),
                    lambda.sync.search = "grid",
                    lambda.ridge = 0,
                    design.basis = variant$design.basis,
                    design.drop.tol = variant$design.drop.tol,
                    ridge.multiplier.grid = variant$ridge.multiplier.grid,
                    ridge.condition.max = variant$ridge.condition.max
                )
            }
        }, error = function(e) e),
        warning = function(w) {
            warning.messages <<- c(warning.messages, conditionMessage(w))
            invokeRestart("muffleWarning")
        }
    )
    elapsed <- unname((proc.time() - t0)[["elapsed"]])

    base <- data.frame(
        dataset.id = dat$dataset.id,
        source.file = dat$source.file,
        method = method.id,
        variant.id = variant.id,
        variant.label = variant$label,
        n = nrow(dat$X),
        ambient.dim = ncol(dat$X),
        status = "ok",
        message = paste(unique(warning.messages), collapse = " | "),
        truth.rmse = NA_real_,
        observed.rmse = NA_real_,
        cv.rmse.observed = NA_real_,
        selected.support = NA_integer_,
        selected.degree = NA_integer_,
        selected.kernel = NA_character_,
        selected.chart.dim = NA_character_,
        selected.lambda.sync = NA_real_,
        finite.cv.candidates = NA_integer_,
        total.cv.candidates = NA_integer_,
        ridge.multiplier.selected = NA_real_,
        ridge.condition = NA_real_,
        ridge.status = NA_character_,
        frame.cols.min = NA_real_,
        frame.cols.median = NA_real_,
        frame.cols.max = NA_real_,
        frame.kept.min = NA_real_,
        frame.kept.median = NA_real_,
        frame.kept.max = NA_real_,
        elapsed.sec = elapsed,
        stringsAsFactors = FALSE
    )

    if (inherits(fit, "error")) {
        base$status <- "error"
        base$message <- conditionMessage(fit)
        return(base)
    }

    base$truth.rmse <- rmse(fit$fitted.values, dat$f)
    base$observed.rmse <- rmse(fit$fitted.values, dat$y)
    base$cv.rmse.observed <- fit$selected$cv.rmse.observed[[1L]] %||% NA_real_
    base$selected.support <- fit$selected$support.size[[1L]] %||% NA_integer_
    base$selected.degree <- fit$selected$degree[[1L]] %||% NA_integer_
    base$selected.kernel <- fit$selected$kernel[[1L]] %||% NA_character_
    base$selected.chart.dim <- paste(fit$chart.dim.by.anchor %||% fit$chart.dim,
                                     collapse = ",")
    base$selected.lambda.sync <- fit$selected$lambda.sync[[1L]] %||% NA_real_
    base$finite.cv.candidates <- sum(is.finite(fit$cv.table$cv.rmse.observed))
    base$total.cv.candidates <- nrow(fit$cv.table)
    base$ridge.multiplier.selected <- fit$ridge.multiplier.selected %||%
        fit$selected$ridge.multiplier.selected[[1L]] %||% NA_real_
    base$ridge.condition <- fit$ridge.condition %||% NA_real_
    base$ridge.status <- fit$ridge.status %||% NA_character_

    fs <- fit$frame.design.summary
    if (is.data.frame(fs) && nrow(fs) > 0L) {
        if ("design.cols" %in% names(fs)) {
            base$frame.cols.min <- min(fs$design.cols, na.rm = TRUE)
            base$frame.cols.median <- median(fs$design.cols, na.rm = TRUE)
            base$frame.cols.max <- max(fs$design.cols, na.rm = TRUE)
        }
        if ("design.cols.kept" %in% names(fs)) {
            base$frame.kept.min <- min(fs$design.cols.kept, na.rm = TRUE)
            base$frame.kept.median <- median(fs$design.cols.kept, na.rm = TRUE)
            base$frame.kept.max <- max(fs$design.cols.kept, na.rm = TRUE)
        }
    }
    if (!is.finite(base$truth.rmse) || !is.finite(base$cv.rmse.observed)) {
        base$status <- "nonfinite_fit"
        msg <- paste(
            "No finite selected fit or CV score was available under this",
            "backend/guard configuration."
        )
        base$message <- paste(c(base$message, msg)[nzchar(c(base$message, msg))],
                              collapse = " | ")
    }
    base
}

assets <- lapply(dataset.files, function(ff) {
    path <- file.path(asset.dir, ff)
    dat <- readRDS(path)
    dat$source.file <- ff
    subset.asset(dat)
})
names(assets) <- sub("\\.rds$", "", dataset.files)

rows <- list()
rr <- 0L
for (dat in assets) {
    for (method.id in methods) {
        for (variant.id in names(backend.variants)) {
            rr <- rr + 1L
            message(sprintf("[%s] %s / %s / %s",
                            timestamp.eastern(), dat$dataset.id, method.id,
                            variant.id))
            rows[[rr]] <- run.fit(dat, method.id, variant.id,
                                  backend.variants[[variant.id]])
            message(sprintf("    status=%s truth.rmse=%s elapsed=%.2fs",
                            rows[[rr]]$status,
                            fmt(rows[[rr]]$truth.rmse),
                            rows[[rr]]$elapsed.sec))
        }
    }
}

results <- do.call(rbind, rows)
summary.path <- file.path(table.dir, "lps_ps_lps_design_basis_summary.csv")
write.csv(results, summary.path, row.names = FALSE)

failures <- results[results$status != "ok" |
                        !is.finite(results$truth.rmse) |
                        is.na(results$truth.rmse), ]
failure.path <- file.path(table.dir, "lps_ps_lps_design_basis_failures.csv")
write.csv(failures, failure.path, row.names = FALSE)

table.html <- function(df, digits = 4) {
    dff <- df
    for (nm in names(dff)) {
        if (is.numeric(dff[[nm]])) {
            dff[[nm]] <- fmt(dff[[nm]], digits = digits)
        }
    }
    header <- paste0("<tr>", paste0("<th>", html.escape(names(dff)), "</th>",
                                   collapse = ""), "</tr>")
    body <- apply(dff, 1L, function(row) {
        paste0("<tr>", paste0("<td>", html.escape(row), "</td>", collapse = ""),
               "</tr>")
    })
    paste0("<table>", header, paste(body, collapse = "\n"), "</table>")
}

truth.plot.svg <- function(df) {
    ok <- df[df$status == "ok" & is.finite(df$truth.rmse), ]
    datasets <- unique(ok$dataset.id)
    variants <- unique(ok$variant.id)
    methods.local <- unique(ok$method)
    w <- 1100
    h <- 520
    ml <- 190
    mr <- 40
    mt <- 45
    mb <- 95
    ymax <- max(ok$truth.rmse) * 1.12
    ymap <- function(y) h - mb - (y / ymax) * (h - mt - mb)
    xslots <- seq(ml, w - mr, length.out = length(datasets))
    variant.offsets <- seq(-55, 55, length.out = length(variants))
    method.offsets <- c("LPS" = -7, "PS-LPS" = 7)
    colors <- c(
        monomial_tiny_ridge = "#0072B2",
        weighted_qr_drop_tiny = "#009E73",
        orthogonal_drop_ridge0 = "#D55E00",
        orthogonal_drop_adaptive_tiny = "#CC79A7"
    )
    shapes <- c("LPS" = "circle", "PS-LPS" = "square")
    parts <- c(
        sprintf('<svg viewBox="0 0 %d %d" role="img" aria-label="Truth RMSE by backend variant">', w, h),
        sprintf('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#333"/>',
                ml, h - mb, w - mr, h - mb),
        sprintf('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#333"/>',
                ml, mt, ml, h - mb)
    )
    ticks <- pretty(c(0, ymax), n = 5)
    ticks <- ticks[ticks >= 0 & ticks <= ymax]
    for (tk in ticks) {
        yy <- ymap(tk)
        parts <- c(parts,
                   sprintf('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#e3e5e8"/>',
                           ml, yy, w - mr, yy),
                   sprintf('<text x="%d" y="%.1f" text-anchor="end" font-size="12">%.3f</text>',
                           ml - 10, yy + 4, tk))
    }
    for (ii in seq_along(datasets)) {
        ds <- datasets[[ii]]
        parts <- c(parts,
                   sprintf('<text x="%.1f" y="%d" text-anchor="middle" font-size="11">%s</text>',
                           xslots[[ii]], h - 55, html.escape(ds)))
        for (jj in seq_along(variants)) {
            vv <- variants[[jj]]
            for (method.id in methods.local) {
                row <- ok[ok$dataset.id == ds & ok$variant.id == vv &
                              ok$method == method.id, ]
                if (nrow(row) == 0L) next
                xx <- xslots[[ii]] + variant.offsets[[jj]] +
                    method.offsets[[method.id]]
                yy <- ymap(row$truth.rmse[[1L]])
                parts <- c(parts,
                           sprintf('<line x1="%.1f" y1="%d" x2="%.1f" y2="%.1f" stroke="#b6bbc2" stroke-width="1"/>',
                                   xx, h - mb, xx, yy))
                title <- sprintf("%s / %s / %s: Truth RMSE %s",
                                 ds, method.id, vv, fmt(row$truth.rmse[[1L]]))
                if (identical(shapes[[method.id]], "circle")) {
                    parts <- c(parts,
                               sprintf('<circle cx="%.1f" cy="%.1f" r="5" fill="%s"><title>%s</title></circle>',
                                       xx, yy, colors[[vv]], html.escape(title)))
                } else {
                    parts <- c(parts,
                               sprintf('<rect x="%.1f" y="%.1f" width="10" height="10" fill="%s"><title>%s</title></rect>',
                                       xx - 5, yy - 5, colors[[vv]],
                                       html.escape(title)))
                }
            }
        }
    }
    lx <- 650
    ly <- 35
    for (jj in seq_along(variants)) {
        vv <- variants[[jj]]
        parts <- c(parts,
                   sprintf('<circle cx="%d" cy="%d" r="5" fill="%s"/>',
                           lx, ly + 18 * (jj - 1), colors[[vv]]),
                   sprintf('<text x="%d" y="%d" font-size="12">%s</text>',
                           lx + 12, ly + 4 + 18 * (jj - 1),
                           html.escape(backend.variants[[vv]]$label)))
    }
    parts <- c(parts,
               sprintf('<circle cx="%d" cy="%d" r="5" fill="#333"/>',
                       lx, ly + 92),
               sprintf('<text x="%d" y="%d" font-size="12">LPS</text>',
                       lx + 12, ly + 96),
               sprintf('<rect x="%d" y="%d" width="10" height="10" fill="#333"/>',
                       lx - 5, ly + 109),
               sprintf('<text x="%d" y="%d" font-size="12">PS-LPS</text>',
                       lx + 12, ly + 118),
               '<text x="25" y="30" font-size="14" font-weight="700">Truth RMSE</text>',
               "</svg>")
    paste(parts, collapse = "\n")
}

best <- do.call(rbind, lapply(split(results, results$dataset.id), function(dd) {
    ok <- dd[dd$status == "ok" & is.finite(dd$truth.rmse), ]
    if (nrow(ok) == 0L) return(NULL)
    ok[which.min(ok$truth.rmse), c("dataset.id", "method", "variant.id",
                                   "truth.rmse", "observed.rmse",
                                   "cv.rmse.observed", "elapsed.sec")]
}))

compact <- results[, c(
    "dataset.id", "method", "variant.id", "status", "truth.rmse",
    "observed.rmse", "cv.rmse.observed", "selected.support",
    "selected.lambda.sync", "ridge.multiplier.selected", "ridge.condition",
    "ridge.status", "finite.cv.candidates", "total.cv.candidates",
    "elapsed.sec", "message"
)]

html <- paste0(
'<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>LPS / PS-LPS Focused Design-Basis Backend Comparison</title>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
       color: #222b35; margin: 0; background: #fbfbfc; }
main { max-width: 1120px; margin: 0 auto; padding: 32px 28px 52px; }
h1 { font-size: 34px; margin: 0 0 10px; }
h2 { margin-top: 34px; border-top: 1px solid #d8dce1; padding-top: 20px; }
p, li { line-height: 1.55; }
table { border-collapse: collapse; width: 100%; margin: 14px 0 18px;
        font-size: 13px; }
th, td { border-bottom: 1px solid #dfe3e8; padding: 7px 8px;
         text-align: left; vertical-align: top; }
th { background: #eef1f5; position: sticky; top: 0; }
code { background: #eef1f5; padding: 1px 4px; border-radius: 4px; }
.note { background: #eef6ff; border-left: 4px solid #2c7fb8;
        padding: 12px 14px; }
.warn { background: #fff5e6; border-left: 4px solid #d55e00;
        padding: 12px 14px; }
a { color: #1f6feb; }
</style>
</head>
<body>
<main>
<h1>LPS / PS-LPS Focused Design-Basis Backend Comparison</h1>
<p><strong>Generated:</strong> ', html.escape(timestamp.eastern()), '</p>

<h2>Purpose</h2>
<p>This focused backend comparison checks whether the new guarded local
polynomial design backends behave sensibly on a small set of frozen
non-manifold fixtures. The comparison is intentionally small: it is a backend
audit exercise, not a performance claim about final model defaults.</p>

<p>The synthetic target is Truth RMSE,</p>
<p style="text-align:center;">TruthRMSE =
sqrt{ n^{-1} sum_i (hat f_i - f_i)^2 }.</p>
<p>Observed CV RMSE is used only as the non-oracle selection score inside each
method; Truth RMSE is used after fitting to audit how well the selected fit
recovered the known synthetic function.</p>

<h2>Methods</h2>
<p>The run uses deterministic subsamples of four frozen first-batch assets:
<code>', paste(html.escape(dataset.files), collapse = '</code>, <code>'),
'</code>. Each fit uses <code>chart.dim = "auto"</code>, local PCA coordinates,
degree 2, tricube kernel, and support grid <code>{15, 25}</code>.
PS-LPS uses <code>lambda.sync.grid = {0, 0.01, 0.1}</code> with grid search and
the normal-cache solver.</p>

<p>The backend variants are:</p>
<ul>
<li><code>monomial_tiny_ridge</code>: standard monomial design with fixed tiny
scale-relative ridge.</li>
<li><code>weighted_qr_drop_tiny</code>: weighted-QR rank/drop guard followed by
zero or tiny ridge subject to a condition cap.</li>
<li><code>orthogonal_drop_ridge0</code>: orthogonalized local polynomial basis
with dropped rank-deficient columns and no ridge.</li>
<li><code>orthogonal_drop_adaptive_tiny</code>: the same orthogonal basis plus
zero-or-tiny adaptive ridge subject to a condition cap.</li>
</ul>

<h2>Truth RMSE Overview</h2>
<p>The figure shows selected-fit Truth RMSE for each dataset. Circles denote
LPS and squares denote PS-LPS. Lower values are better.</p>',
truth.plot.svg(results),
'
<h2>Best Row Per Dataset</h2>',
table.html(best),
'
<h2>Compact Result Table</h2>
<p>The full CSV is written to
<a href="tables/lps_ps_lps_design_basis_summary.csv">tables/lps_ps_lps_design_basis_summary.csv</a>.
This compact table keeps the key fit and numerical diagnostics visible.</p>',
table.html(compact),
'
<h2>Interpretation</h2>
<p>This run asks whether the backend choices are numerically explicit and
auditable. A successful result is not necessarily the lowest Truth RMSE; it is
also important that failures are reported as failures, rank drops are visible,
and ridge choices are recorded.</p>
<p>The orthogonal basis with zero ridge should be interpreted as a change of
basis for the same local polynomial prediction space after rank-deficient
directions are dropped. Once a ridge is added, the penalty is applied in the
orthogonalized coefficient coordinates, so it is not algebraically identical
to ridge on raw monomial coefficients. For prediction this is usually the
more stable numerical target, but the distinction should be audited before
promoting defaults.</p>',
if (nrow(failures) > 0L) {
    paste0('<div class="warn"><strong>Failures or non-finite fits were observed.</strong> ',
           'See <a href="tables/lps_ps_lps_design_basis_failures.csv">',
           'tables/lps_ps_lps_design_basis_failures.csv</a>.</div>')
} else {
    '<div class="note"><strong>No fit errors or non-finite Truth RMSE values were observed.</strong></div>'
},
'
<h2>Assets</h2>
<ul>
<li><a href="tables/lps_ps_lps_design_basis_summary.csv">Summary CSV</a></li>
<li><a href="tables/lps_ps_lps_design_basis_failures.csv">Failure CSV</a></li>
<li>Script: <code>scripts/lps_ps_lps_design_basis_focused_comparison.R</code></li>
</ul>
</main>
</body>
</html>
')

html.path <- file.path(out.dir, "lps_ps_lps_design_basis_focused_comparison.html")
writeLines(html, html.path, useBytes = TRUE)

cat("Wrote:\n")
cat(" - ", normalizePath(summary.path), "\n", sep = "")
cat(" - ", normalizePath(failure.path), "\n", sep = "")
cat(" - ", normalizePath(html.path), "\n", sep = "")
