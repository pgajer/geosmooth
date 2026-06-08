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

html.escape <- function(x) {
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    gsub(">", "&gt;", x, fixed = TRUE)
}

read.status <- function(path) {
    if (!file.exists(path)) return(NULL)
    txt <- paste(readLines(path, warn = FALSE), collapse = "\n")
    keys <- c("task_id", "dataset_id", "method", "chart_dim_rule",
              "backend_variant", "status", "started_at", "finished_at",
              "elapsed_sec", "hostname", "pid", "result_path",
              "error_message", "error_class")
    vals <- lapply(keys, function(key) {
        pattern <- paste0('"', key, '"[[:space:]]*:[[:space:]]*',
                          '("[^"]*"|null|true|false|-?[0-9.]+)')
        m <- regexec(pattern, txt)
        hit <- regmatches(txt, m)[[1L]]
        if (length(hit) < 2L) return(NA_character_)
        val <- hit[[2L]]
        if (identical(val, "null")) return(NA_character_)
        if (grepl('^"', val)) {
            return(gsub('\\"', '"', sub('"$', "", sub('^"', "", val))))
        }
        val
    })
    names(vals) <- keys
    as.data.frame(vals, stringsAsFactors = FALSE)
}

fmt <- function(x, digits = 4) {
    ifelse(is.na(x), "NA",
           ifelse(is.finite(x), formatC(x, format = "fg", digits = digits),
                  as.character(x)))
}

raw.mad <- function(x) {
    x <- x[is.finite(x)]
    if (!length(x)) return(NA_real_)
    stats::median(abs(x - stats::median(x)), na.rm = TRUE)
}

ratio.med.mad <- function(med, mad) {
    if (!is.finite(med) || !is.finite(mad)) return(NA_real_)
    if (mad == 0 && med == 0) return(NA_real_)
    if (mad == 0) return(Inf)
    med / mad
}

table.html <- function(df, digits = 4) {
    dff <- df
    for (nm in names(dff)) {
        if (is.numeric(dff[[nm]])) dff[[nm]] <- fmt(dff[[nm]], digits)
    }
    header <- paste0("<tr>", paste0("<th>", html.escape(names(dff)), "</th>",
                                   collapse = ""), "</tr>")
    body <- apply(dff, 1L, function(row) {
        paste0("<tr>", paste0("<td>", html.escape(row), "</td>", collapse = ""),
               "</tr>")
    })
    paste0("<table>", header, paste(body, collapse = "\n"), "</table>")
}

backend.palette <- c(
    monomial_tiny_ridge = "#0072B2",
    weighted_qr_drop_tiny = "#D55E00",
    orthogonal_drop_adaptive_tiny = "#009E73"
)

status.palette <- c(
    ok = "#009E73",
    nonfinite_fit = "#D55E00",
    error = "#CC79A7",
    missing = "#7a7f87"
)

shape.svg <- function(x, y, chart, fill, title) {
    if (identical(chart, "local.auto")) {
        sprintf('<rect x="%.1f" y="%.1f" width="9" height="9" fill="%s"><title>%s</title></rect>',
                x - 4.5, y - 4.5, fill, html.escape(title))
    } else {
        sprintf('<circle cx="%.1f" cy="%.1f" r="4.7" fill="%s"><title>%s</title></circle>',
                x, y, fill, html.escape(title))
    }
}

backend.legend.svg <- function(x, y, title = "Backend color", size = 10) {
    bb <- names(backend.palette)
    parts <- c(sprintf('<text x="%.1f" y="%.1f" font-size="%d" font-weight="700">%s</text>',
                       x, y, size + 1L, html.escape(title)))
    for (kk in seq_along(bb)) {
        yy <- y + 18 * kk
        parts <- c(parts,
                   sprintf('<circle cx="%.1f" cy="%.1f" r="4.7" fill="%s"/>',
                           x, yy - 3, backend.palette[[bb[[kk]]]]),
                   sprintf('<text x="%.1f" y="%.1f" font-size="%d">%s</text>',
                           x + 12, yy, size, html.escape(bb[[kk]])))
    }
    parts
}

scatter.label.layout <- function(x, y, labels, xmin, xmax, ymin, ymax,
                                 font.size = 10) {
    labels <- as.character(labels)
    n <- length(labels)
    widths <- pmax(38, nchar(labels) * font.size * 0.62 + 8)
    heights <- rep(font.size + 6, n)
    offsets <- expand.grid(
        dx = c(28, -28, 42, -42),
        dy = c(-8, 12, -24, 28, -42, 46, -60, 64, 4),
        stringsAsFactors = FALSE
    )
    offsets$anchor <- ifelse(offsets$dx < 0, "end",
                             ifelse(offsets$dx > 0, "start", "middle"))
    offsets$cost <- abs(offsets$dx) + abs(offsets$dy)
    offsets <- offsets[order(offsets$cost), , drop = FALSE]
    placed <- data.frame(x0 = numeric(), x1 = numeric(),
                         y0 = numeric(), y1 = numeric())
    out <- data.frame(text_x = numeric(n), text_y = numeric(n),
                      rect_x = numeric(n), rect_y = numeric(n),
                      rect_w = numeric(n), rect_h = numeric(n),
                      anchor = character(n), stringsAsFactors = FALSE)
    overlap.area <- function(a, placed) {
        if (!nrow(placed)) return(0)
        wx <- pmax(0, pmin(a[["x1"]], placed$x1) -
                       pmax(a[["x0"]], placed$x0))
        wy <- pmax(0, pmin(a[["y1"]], placed$y1) -
                       pmax(a[["y0"]], placed$y0))
        sum(wx * wy)
    }
    order.idx <- order(x, y)
    for (ii in order.idx) {
        best <- NULL
        best.score <- Inf
        for (jj in seq_len(nrow(offsets))) {
            tx <- x[[ii]] + offsets$dx[[jj]]
            ty <- y[[ii]] + offsets$dy[[jj]]
            anchor <- offsets$anchor[[jj]]
            if (identical(anchor, "start")) {
                rx <- tx - 4
            } else if (identical(anchor, "end")) {
                rx <- tx - widths[[ii]] + 4
            } else {
                rx <- tx - widths[[ii]] / 2
            }
            ry <- ty - font.size - 3
            box <- c(x0 = rx, x1 = rx + widths[[ii]],
                     y0 = ry, y1 = ry + heights[[ii]])
            offscreen <- sum(pmax(0, c(xmin - box[["x0"]],
                                       box[["x1"]] - xmax,
                                       ymin - box[["y0"]],
                                       box[["y1"]] - ymax)))
            score <- overlap.area(box, placed) * 1000 +
                offscreen * 1000 + offsets$cost[[jj]]
            if (score < best.score) {
                best.score <- score
                best <- list(tx = tx, ty = ty, rx = rx, ry = ry,
                             box = box, anchor = anchor)
            }
        }
        out$text_x[[ii]] <- best$tx
        out$text_y[[ii]] <- best$ty
        out$rect_x[[ii]] <- best$rx
        out$rect_y[[ii]] <- best$ry
        out$rect_w[[ii]] <- widths[[ii]]
        out$rect_h[[ii]] <- heights[[ii]]
        out$anchor[[ii]] <- best$anchor
        placed <- rbind(placed, data.frame(x0 = best$box[["x0"]],
                                           x1 = best$box[["x1"]],
                                           y0 = best$box[["y0"]],
                                           y1 = best$box[["y1"]]))
    }
    out
}

scatter.label.svg <- function(layout, labels, fill = "white", opacity = 0.82,
                              font.size = 10, point_x = NULL,
                              point_y = NULL) {
    out <- character(0)
    for (ii in seq_along(labels)) {
        if (!is.null(point_x) && !is.null(point_y)) {
            x0 <- point_x[[ii]]
            y0 <- point_y[[ii]]
            rx <- layout$rect_x[[ii]]
            ry <- layout$rect_y[[ii]]
            rw <- layout$rect_w[[ii]]
            rh <- layout$rect_h[[ii]]
            x1 <- pmin(pmax(x0, rx), rx + rw)
            y1 <- pmin(pmax(y0, ry), ry + rh)
            out <- c(out,
                     sprintf('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#5d6673" stroke-width="0.9" opacity="0.72"/>',
                             x0, y0, x1, y1))
        }
        out <- c(out,
                 sprintf('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="2.5" ry="2.5" fill="%s" opacity="%.2f" stroke="#5d6673" stroke-width="0.7"/>',
                         layout$rect_x[[ii]], layout$rect_y[[ii]],
                         layout$rect_w[[ii]], layout$rect_h[[ii]],
                         fill, opacity),
                 sprintf('<text x="%.1f" y="%.1f" text-anchor="%s" font-size="%d">%s</text>',
                         layout$text_x[[ii]], layout$text_y[[ii]],
                         layout$anchor[[ii]], font.size,
                         html.escape(labels[[ii]])))
    }
    out
}

truth.by.method.svg <- function(df, method.name) {
    ok <- df[df$status == "ok" & df$method == method.name &
                 is.finite(df$truth_rmse), , drop = FALSE]
    if (!nrow(ok)) return("<p>No finite successful rows to plot.</p>")
    datasets <- unique(ok$dataset_id)
    w <- 1100
    h <- max(430, 90 + 30 * length(datasets) + 70)
    ml <- 235
    mr <- 40
    mt <- 42
    mb <- 78
    xmax <- max(ok$truth_rmse, na.rm = TRUE) * 1.08
    xmap <- function(x) ml + (x / xmax) * (w - ml - mr)
    yslots <- seq(mt + 16, h - mb, length.out = length(datasets))
    parts <- c(
        sprintf('<svg viewBox="0 0 %d %d" role="img" aria-label="%s Truth RMSE by backend">', w, h, html.escape(method.name)),
        sprintf('<text x="%d" y="24" font-size="16" font-weight="700">%s selected Truth RMSE</text>',
                ml, toupper(method.name)),
        sprintf('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#333"/>',
                ml, h - mb + 20, w - mr, h - mb + 20)
    )
    ticks <- pretty(c(0, xmax), n = 6)
    ticks <- ticks[ticks >= 0 & ticks <= xmax]
    for (tk in ticks) {
        xx <- xmap(tk)
        parts <- c(parts,
                   sprintf('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#e4e7ec"/>',
                           xx, mt, xx, h - mb + 20),
                   sprintf('<text x="%.1f" y="%d" text-anchor="middle" font-size="11">%.3f</text>',
                           xx, h - mb + 38, tk))
    }
    for (ii in seq_along(datasets)) {
        ds <- datasets[[ii]]
        yy <- yslots[[ii]]
        parts <- c(parts,
                   sprintf('<text x="%d" y="%.1f" text-anchor="end" font-size="11">%s</text>',
                           ml - 12, yy + 4, html.escape(ds)),
                   sprintf('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#eef1f5"/>',
                           ml, yy, w - mr, yy))
        rows <- ok[ok$dataset_id == ds, , drop = FALSE]
        offsets <- seq(-8, 8, length.out = max(2L, nrow(rows)))
        for (jj in seq_len(nrow(rows))) {
            row <- rows[jj, ]
            col <- backend.palette[[row$backend_variant]]
            if (is.null(col)) col <- "#777"
            title <- sprintf("%s / %s / %s: Truth RMSE %s",
                             row$dataset_id, row$chart_dim_rule,
                             row$backend_variant, fmt(row$truth_rmse))
            parts <- c(parts, shape.svg(xmap(row$truth_rmse),
                                        yy + offsets[[jj]], row$chart_dim_rule,
                                        col, title))
        }
    }
    lx <- ml
    ly <- h - 24
    legend <- c(
        sprintf('<circle cx="%d" cy="%d" r="4.7" fill="#555"/><text x="%d" y="%d" font-size="11">auto</text>',
                lx, ly, lx + 12, ly + 4),
        sprintf('<rect x="%d" y="%d" width="9" height="9" fill="#555"/><text x="%d" y="%d" font-size="11">local.auto</text>',
                lx + 70, ly - 5, lx + 84, ly + 4)
    )
    bb <- names(backend.palette)
    for (kk in seq_along(bb)) {
        legend <- c(legend,
                    sprintf('<circle cx="%d" cy="%d" r="4.7" fill="%s"/><text x="%d" y="%d" font-size="11">%s</text>',
                            lx + 180 + 250 * (kk - 1L), ly,
                            backend.palette[[bb[[kk]]]],
                            lx + 192 + 250 * (kk - 1L), ly + 4,
                            html.escape(bb[[kk]])))
    }
    paste(c(parts, legend, "</svg>"), collapse = "\n")
}

delta.from.best.svg <- function(df) {
    ok <- df[df$status == "ok" & is.finite(df$truth_rmse), , drop = FALSE]
    if (!nrow(ok)) return("<p>No finite successful rows to plot.</p>")
    ok$key <- paste(ok$dataset_id, ok$method, ok$chart_dim_rule, sep = "\r")
    mins <- stats::aggregate(ok$truth_rmse, by = list(key = ok$key), min,
                             na.rm = TRUE)
    names(mins)[2L] <- "best_truth_rmse"
    ok <- merge(ok, mins, by = "key", all.x = TRUE)
    ok$delta <- ok$truth_rmse - ok$best_truth_rmse
    ok$arm <- paste(ok$method, ok$chart_dim_rule, sep = " / ")
    ok <- ok[ok$backend_variant != "orthogonal_drop_adaptive_tiny" |
                 ok$delta != 0 | TRUE, , drop = FALSE]
    datasets <- unique(ok$dataset_id)
    arms <- unique(ok$arm)
    w <- 1100
    h <- max(450, 95 + 25 * length(datasets))
    ml <- 240
    mr <- 40
    mt <- 45
    mb <- 75
    xmax <- max(ok$delta, na.rm = TRUE)
    xmax <- if (is.finite(xmax) && xmax > 0) xmax * 1.08 else 1
    xmap <- function(x) ml + (x / xmax) * (w - ml - mr)
    yslots <- seq(mt + 14, h - mb, length.out = length(datasets))
    parts <- c(
        sprintf('<svg viewBox="0 0 %d %d" role="img" aria-label="Truth RMSE distance from in-row best">', w, h),
        sprintf('<text x="%d" y="24" font-size="16" font-weight="700">Distance from in-method/chart best Truth RMSE</text>', ml),
        sprintf('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#333"/>',
                ml, h - mb + 18, w - mr, h - mb + 18)
    )
    ticks <- pretty(c(0, xmax), n = 5)
    ticks <- ticks[ticks >= 0 & ticks <= xmax]
    for (tk in ticks) {
        xx <- xmap(tk)
        parts <- c(parts,
                   sprintf('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#e4e7ec"/>',
                           xx, mt, xx, h - mb + 18),
                   sprintf('<text x="%.1f" y="%d" text-anchor="middle" font-size="11">%.3f</text>',
                           xx, h - mb + 36, tk))
    }
    for (ii in seq_along(datasets)) {
        ds <- datasets[[ii]]
        yy <- yslots[[ii]]
        parts <- c(parts,
                   sprintf('<text x="%d" y="%.1f" text-anchor="end" font-size="11">%s</text>',
                           ml - 12, yy + 4, html.escape(ds)),
                   sprintf('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#eef1f5"/>',
                           ml, yy, w - mr, yy))
        rows <- ok[ok$dataset_id == ds, , drop = FALSE]
        offsets <- seq(-9, 9, length.out = max(2L, nrow(rows)))
        for (jj in seq_len(nrow(rows))) {
            row <- rows[jj, ]
            col <- backend.palette[[row$backend_variant]]
            if (is.null(col)) col <- "#777"
            title <- sprintf("%s / %s / %s / %s: delta %s",
                             row$dataset_id, row$method, row$chart_dim_rule,
                             row$backend_variant, fmt(row$delta))
            parts <- c(parts, shape.svg(xmap(row$delta),
                                        yy + offsets[[jj]],
                                        row$chart_dim_rule, col, title))
        }
    }
    paste(c(parts, "</svg>"), collapse = "\n")
}

regret.vector.svg <- function(regret) {
    if (!nrow(regret)) return("<p>No successful paired regret rows to plot.</p>")
    arms <- unique(regret$arm_label)
    w <- 1320
    h <- max(460, 90 + 32 * length(arms))
    ml <- 360
    mr <- 220
    mt <- 42
    mb <- 65
    xmax <- max(regret$regret, na.rm = TRUE)
    xmax <- if (is.finite(xmax) && xmax > 0) xmax * 1.1 else 1
    xmap <- function(x) ml + (x / xmax) * (w - ml - mr)
    yslots <- seq(mt + 18, h - mb, length.out = length(arms))
    parts <- c(
        sprintf('<svg viewBox="0 0 %d %d" role="img" aria-label="Frank Friedman style regret vectors across cases">', w, h),
        sprintf('<text x="%d" y="24" font-size="16" font-weight="700">Regret vector across cases by method arm</text>', ml),
        sprintf('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#333"/>',
                ml, h - mb + 18, w - mr, h - mb + 18)
    )
    ticks <- pretty(c(0, xmax), n = 6)
    ticks <- ticks[ticks >= 0 & ticks <= xmax]
    for (tk in ticks) {
        xx <- xmap(tk)
        parts <- c(parts,
                   sprintf('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#e4e7ec"/>',
                           xx, mt, xx, h - mb + 18),
                   sprintf('<text x="%.1f" y="%d" text-anchor="middle" font-size="11">%.3f</text>',
                           xx, h - mb + 36, tk))
    }
    for (ii in seq_along(arms)) {
        arm <- arms[[ii]]
        yy <- yslots[[ii]]
        rows <- regret[regret$arm_label == arm, , drop = FALSE]
        col <- backend.palette[[rows$backend_variant[[1L]]]]
        if (is.null(col)) col <- "#777"
        parts <- c(parts,
                   sprintf('<text x="%d" y="%.1f" text-anchor="end" font-size="10">%s</text>',
                           ml - 10, yy + 4, html.escape(arm)),
                   sprintf('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#eef1f5"/>',
                           ml, yy, w - mr, yy))
        med <- stats::median(rows$regret, na.rm = TRUE)
        parts <- c(parts,
                   sprintf('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="4"/>',
                           xmap(med), yy - 10, xmap(med), yy + 10, col))
        for (jj in seq_len(nrow(rows))) {
            jitter <- ((jj - 1L) %% 5L - 2L) * 2.8
            title <- sprintf("%s / %s: regret %s, Truth RMSE %s",
                             rows$dataset_id[[jj]], arm,
                             fmt(rows$regret[[jj]]), fmt(rows$truth_rmse[[jj]]))
            parts <- c(parts,
                       sprintf('<circle cx="%.1f" cy="%.1f" r="4.2" fill="%s" opacity="0.74"><title>%s</title></circle>',
                               xmap(rows$regret[[jj]]), yy + jitter, col,
                               html.escape(title)))
        }
    }
    legend <- backend.legend.svg(w - mr + 28, mt + 12)
    paste(c(parts, legend, "</svg>"), collapse = "\n")
}

regret.failure.runtime.svg <- function(summary) {
    if (!nrow(summary)) return("<p>No regret summary rows to plot.</p>")
    rows <- summary[is.finite(summary$median_regret), , drop = FALSE]
    if (!nrow(rows)) return("<p>No finite regret summaries to plot.</p>")
    w <- 980
    h <- 620
    ml <- 100
    mr <- 210
    mt <- 55
    mb <- 75
    xmax <- max(rows$median_regret, na.rm = TRUE)
    xmax <- if (is.finite(xmax) && xmax > 0) xmax * 1.15 else 1
    ymax <- max(rows$failure_rate, na.rm = TRUE)
    ymax <- if (is.finite(ymax) && ymax > 0) ymax * 1.15 else 0.1
    xmap <- function(x) ml + (x / xmax) * (w - ml - mr)
    ymap <- function(y) h - mb - (y / ymax) * (h - mt - mb)
    rmap <- function(x) {
        vals <- rows$median_elapsed_sec
        if (!any(is.finite(vals)) || max(vals, na.rm = TRUE) <= 0) return(5)
        4 + 11 * sqrt(pmax(x, 0) / max(vals, na.rm = TRUE))
    }
    parts <- c(
        sprintf('<svg viewBox="0 0 %d %d" role="img" aria-label="Median regret versus failure rate and runtime">', w, h),
        sprintf('<text x="%d" y="28" font-size="16" font-weight="700">Method-arm summary: median regret, failure rate, runtime</text>', ml),
        sprintf('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#333"/>',
                ml, h - mb, w - mr, h - mb),
        sprintf('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#333"/>',
                ml, mt, ml, h - mb)
    )
    xticks <- pretty(c(0, xmax), n = 5)
    xticks <- xticks[xticks >= 0 & xticks <= xmax]
    for (tk in xticks) {
        xx <- xmap(tk)
        parts <- c(parts,
                   sprintf('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#e4e7ec"/>',
                           xx, mt, xx, h - mb),
                   sprintf('<text x="%.1f" y="%d" text-anchor="middle" font-size="11">%.3f</text>',
                           xx, h - mb + 22, tk))
    }
    yticks <- pretty(c(0, ymax), n = 5)
    yticks <- yticks[yticks >= 0 & yticks <= ymax]
    for (tk in yticks) {
        yy <- ymap(tk)
        parts <- c(parts,
                   sprintf('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#e4e7ec"/>',
                           ml, yy, w - mr, yy),
                   sprintf('<text x="%d" y="%.1f" text-anchor="end" font-size="11">%.2f</text>',
                           ml - 8, yy + 4, tk))
    }
    parts <- c(parts,
               sprintf('<text x="%.1f" y="%d" text-anchor="middle" font-size="12">median regret</text>',
                       (ml + w - mr) / 2, h - 23),
               sprintf('<text x="22" y="%.1f" text-anchor="middle" transform="rotate(-90 22 %.1f)" font-size="12">failure rate</text>',
                       (mt + h - mb) / 2, (mt + h - mb) / 2))
    for (ii in seq_len(nrow(rows))) {
        row <- rows[ii, ]
        col <- backend.palette[[row$backend_variant]]
        if (is.null(col)) col <- "#777"
        radius <- rmap(row$median_elapsed_sec)
        title <- sprintf("%s: median regret %s, failure rate %s, median runtime %s sec",
                         row$arm_label, fmt(row$median_regret),
                         fmt(row$failure_rate), fmt(row$median_elapsed_sec))
        parts <- c(parts,
                   sprintf('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" opacity="0.72"><title>%s</title></circle>',
                           xmap(row$median_regret), ymap(row$failure_rate),
                           radius, col, html.escape(title)),
                   sprintf('<text x="%.1f" y="%.1f" font-size="9">%s</text>',
                           xmap(row$median_regret) + radius + 3,
                           ymap(row$failure_rate) + 3,
                           html.escape(row$short_label)))
    }
    lx <- w - mr + 20
    ly <- mt + 10
    bb <- names(backend.palette)
    legend <- c(sprintf('<text x="%d" y="%d" font-size="12" font-weight="700">Backend color</text>',
                        lx, ly))
    for (kk in seq_along(bb)) {
        legend <- c(legend,
                    sprintf('<circle cx="%d" cy="%d" r="5" fill="%s"/><text x="%d" y="%d" font-size="10">%s</text>',
                            lx, ly + 20 * kk, backend.palette[[bb[[kk]]]],
                            lx + 12, ly + 4 + 20 * kk, html.escape(bb[[kk]])))
    }
    legend <- c(legend,
                sprintf('<text x="%d" y="%d" font-size="12" font-weight="700">Point size</text>',
                        lx, ly + 105),
                sprintf('<text x="%d" y="%d" font-size="10">median elapsed_sec</text>',
                        lx, ly + 124))
    paste(c(parts, legend, "</svg>"), collapse = "\n")
}

finite.plot.rows <- function(summary, xvar, yvar) {
    summary[is.finite(summary[[xvar]]) & is.finite(summary[[yvar]]),
            , drop = FALSE]
}

median.time.regret.svg <- function(summary) {
    rows <- finite.plot.rows(summary, "median_elapsed_sec", "median_regret")
    if (!nrow(rows)) return("<p>No finite median time/regret rows to plot.</p>")
    w <- 1140
    h <- 620
    ml <- 95
    mr <- 260
    mt <- 52
    mb <- 78
    xmax <- max(rows$median_elapsed_sec + ifelse(is.finite(rows$elapsed_mad),
                                                 rows$elapsed_mad, 0),
                na.rm = TRUE)
    ymax <- max(rows$median_regret + ifelse(is.finite(rows$regret_mad),
                                            rows$regret_mad, 0),
                na.rm = TRUE)
    xmax <- if (is.finite(xmax) && xmax > 0) xmax * 1.08 else 1
    ymax <- if (is.finite(ymax) && ymax > 0) ymax * 1.18 else 1
    xmap <- function(x) ml + (pmax(x, 0) / xmax) * (w - ml - mr)
    ymap <- function(y) h - mb - (pmax(y, 0) / ymax) * (h - mt - mb)
    parts <- c(
        sprintf('<svg viewBox="0 0 %d %d" role="img" aria-label="Median elapsed time versus median regret with MAD error bars">', w, h),
        sprintf('<text x="%d" y="28" font-size="16" font-weight="700">Median elapsed time versus median regret</text>', ml),
        sprintf('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#333"/>',
                ml, h - mb, w - mr, h - mb),
        sprintf('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#333"/>',
                ml, mt, ml, h - mb)
    )
    xticks <- pretty(c(0, xmax), n = 6)
    xticks <- xticks[xticks >= 0 & xticks <= xmax]
    for (tk in xticks) {
        xx <- xmap(tk)
        parts <- c(parts,
                   sprintf('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#e4e7ec"/>',
                           xx, mt, xx, h - mb),
                   sprintf('<text x="%.1f" y="%d" text-anchor="middle" font-size="11">%s</text>',
                           xx, h - mb + 22, html.escape(fmt(tk, 4))))
    }
    yticks <- pretty(c(0, ymax), n = 6)
    yticks <- yticks[yticks >= 0 & yticks <= ymax]
    for (tk in yticks) {
        yy <- ymap(tk)
        parts <- c(parts,
                   sprintf('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#e4e7ec"/>',
                           ml, yy, w - mr, yy),
                   sprintf('<text x="%d" y="%.1f" text-anchor="end" font-size="11">%.3f</text>',
                           ml - 8, yy + 4, tk))
    }
    parts <- c(parts,
               sprintf('<text x="%.1f" y="%d" text-anchor="middle" font-size="12">median elapsed time T_med (sec)</text>',
                       (ml + w - mr) / 2, h - 25),
               sprintf('<text x="22" y="%.1f" text-anchor="middle" transform="rotate(-90 22 %.1f)" font-size="12">median regret R_med</text>',
                       (mt + h - mb) / 2, (mt + h - mb) / 2))
    label.layout <- scatter.label.layout(
        xmap(rows$median_elapsed_sec), ymap(rows$median_regret),
        rows$short_label, ml + 2, w - mr - 8, mt + 2, h - mb - 2
    )
    for (ii in seq_len(nrow(rows))) {
        row <- rows[ii, ]
        col <- backend.palette[[row$backend_variant]]
        if (is.null(col)) col <- "#555"
        x <- row$median_elapsed_sec
        y <- row$median_regret
        tx <- ifelse(is.finite(row$elapsed_mad), row$elapsed_mad, 0)
        ry <- ifelse(is.finite(row$regret_mad), row$regret_mad, 0)
        title <- sprintf("%s: T_med %s, T_mad %s, R_med %s, R_mad %s",
                         row$short_label, fmt(x), fmt(tx), fmt(y), fmt(ry))
        parts <- c(parts,
                   sprintf('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#cc0000" stroke-width="1.6"/>',
                           xmap(x - tx), ymap(y), xmap(x + tx), ymap(y)),
                   sprintf('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#cc0000" stroke-width="1.6"/>',
                           xmap(x), ymap(y - ry), xmap(x), ymap(y + ry)),
                   sprintf('<circle cx="%.1f" cy="%.1f" r="5.2" fill="%s"><title>%s</title></circle>',
                           xmap(x), ymap(y), col, html.escape(title)))
    }
    parts <- c(parts, scatter.label.svg(
        label.layout, rows$short_label,
        point_x = xmap(rows$median_elapsed_sec),
        point_y = ymap(rows$median_regret)
    ))
    legend <- backend.legend.svg(w - mr + 32, mt + 12)
    paste(c(parts, legend, "</svg>"), collapse = "\n")
}

snr.scatter.svg <- function(summary, xvar, yvar, xlab, ylab, title) {
    rows <- finite.plot.rows(summary, xvar, yvar)
    if (!nrow(rows)) return("<p>No finite SNR rows to plot.</p>")
    w <- 1120
    h <- 580
    ml <- 92
    mr <- 260
    mt <- 52
    mb <- 76
    xmax <- max(rows[[xvar]], na.rm = TRUE)
    ymax <- max(rows[[yvar]], na.rm = TRUE)
    xmax <- if (is.finite(xmax) && xmax > 0) xmax * 1.15 else 1
    ymax <- if (is.finite(ymax) && ymax > 0) ymax * 1.15 else 1
    xmap <- function(x) ml + (pmax(x, 0) / xmax) * (w - ml - mr)
    ymap <- function(y) h - mb - (pmax(y, 0) / ymax) * (h - mt - mb)
    parts <- c(
        sprintf('<svg viewBox="0 0 %d %d" role="img" aria-label="%s">', w, h, html.escape(title)),
        sprintf('<text x="%d" y="28" font-size="16" font-weight="700">%s</text>', ml, html.escape(title)),
        sprintf('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#333"/>',
                ml, h - mb, w - mr, h - mb),
        sprintf('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#333"/>',
                ml, mt, ml, h - mb)
    )
    xticks <- pretty(c(0, xmax), n = 6)
    xticks <- xticks[xticks >= 0 & xticks <= xmax]
    for (tk in xticks) {
        xx <- xmap(tk)
        parts <- c(parts,
                   sprintf('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#e4e7ec"/>',
                           xx, mt, xx, h - mb),
                   sprintf('<text x="%.1f" y="%d" text-anchor="middle" font-size="11">%.2f</text>',
                           xx, h - mb + 22, tk))
    }
    yticks <- pretty(c(0, ymax), n = 6)
    yticks <- yticks[yticks >= 0 & yticks <= ymax]
    for (tk in yticks) {
        yy <- ymap(tk)
        parts <- c(parts,
                   sprintf('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#e4e7ec"/>',
                           ml, yy, w - mr, yy),
                   sprintf('<text x="%d" y="%.1f" text-anchor="end" font-size="11">%.2f</text>',
                           ml - 8, yy + 4, tk))
    }
    parts <- c(parts,
               sprintf('<text x="%.1f" y="%d" text-anchor="middle" font-size="12">%s</text>',
                       (ml + w - mr) / 2, h - 25, html.escape(xlab)),
               sprintf('<text x="22" y="%.1f" text-anchor="middle" transform="rotate(-90 22 %.1f)" font-size="12">%s</text>',
                       (mt + h - mb) / 2, (mt + h - mb) / 2,
                       html.escape(ylab)))
    label.layout <- scatter.label.layout(
        xmap(rows[[xvar]]), ymap(rows[[yvar]]), rows$short_label,
        ml + 2, w - mr - 8, mt + 2, h - mb - 2
    )
    for (ii in seq_len(nrow(rows))) {
        row <- rows[ii, ]
        col <- backend.palette[[row$backend_variant]]
        if (is.null(col)) col <- "#555"
        x <- row[[xvar]]
        y <- row[[yvar]]
        title.row <- sprintf("%s: %s %s, %s %s",
                             row$short_label, xvar, fmt(x), yvar, fmt(y))
        parts <- c(parts,
                   sprintf('<circle cx="%.1f" cy="%.1f" r="5.2" fill="%s"><title>%s</title></circle>',
                           xmap(x), ymap(y), col, html.escape(title.row)))
    }
    parts <- c(parts, scatter.label.svg(
        label.layout, rows$short_label,
        point_x = xmap(rows[[xvar]]),
        point_y = ymap(rows[[yvar]])
    ))
    legend <- backend.legend.svg(w - mr + 32, mt + 12)
    paste(c(parts, legend, "</svg>"), collapse = "\n")
}

runtime.arm.svg <- function(status) {
    rows <- status[is.finite(status$elapsed_sec), , drop = FALSE]
    if (!nrow(rows)) return("<p>No elapsed-time rows to plot.</p>")
    rows$arm <- paste(rows$method, rows$chart_dim_rule, rows$backend_variant,
                      sep = " / ")
    arms <- unique(rows$arm)
    w <- 1180
    h <- max(440, 95 + 28 * length(arms))
    ml <- 315
    mr <- 45
    mt <- 42
    mb <- 60
    xmin <- max(0.1, min(rows$elapsed_sec, na.rm = TRUE) * 0.8)
    xmax <- max(rows$elapsed_sec, na.rm = TRUE) * 1.18
    lmin <- log10(xmin)
    lmax <- log10(xmax)
    xmap <- function(x) ml + ((log10(pmax(x, xmin)) - lmin) /
                                  (lmax - lmin)) * (w - ml - mr)
    yslots <- seq(mt + 16, h - mb, length.out = length(arms))
    parts <- c(
        sprintf('<svg viewBox="0 0 %d %d" role="img" aria-label="Runtime by backend arm">', w, h),
        sprintf('<text x="%d" y="24" font-size="16" font-weight="700">Task wall time by method/chart/backend</text>', ml),
        sprintf('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#333"/>',
                ml, h - mb + 18, w - mr, h - mb + 18)
    )
    ticks <- 10 ^ seq(floor(lmin), ceiling(lmax))
    ticks <- ticks[ticks >= xmin & ticks <= xmax]
    for (tk in ticks) {
        xx <- xmap(tk)
        parts <- c(parts,
                   sprintf('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#e4e7ec"/>',
                           xx, mt, xx, h - mb + 18),
                   sprintf('<text x="%.1f" y="%d" text-anchor="middle" font-size="11">%s</text>',
                           xx, h - mb + 36, html.escape(format(tk, scientific = FALSE))))
    }
    if (xmax >= 5400 && xmin <= 5400) {
        xx <- xmap(5400)
        parts <- c(parts,
                   sprintf('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#aa0000" stroke-dasharray="4 4"/>',
                           xx, mt, xx, h - mb + 18),
                   sprintf('<text x="%.1f" y="%d" text-anchor="middle" font-size="11" fill="#aa0000">5400 sec</text>',
                           xx, mt - 8))
    }
    for (ii in seq_along(arms)) {
        arm <- arms[[ii]]
        yy <- yslots[[ii]]
        parts <- c(parts,
                   sprintf('<text x="%d" y="%.1f" text-anchor="end" font-size="10">%s</text>',
                           ml - 10, yy + 4, html.escape(arm)),
                   sprintf('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#eef1f5"/>',
                           ml, yy, w - mr, yy))
        rr <- rows[rows$arm == arm, , drop = FALSE]
        offsets <- seq(-7, 7, length.out = max(2L, nrow(rr)))
        for (jj in seq_len(nrow(rr))) {
            row <- rr[jj, ]
            col <- status.palette[[row$status]]
            if (is.null(col)) col <- "#777"
            title <- sprintf("%s / %s: %s sec (%s)",
                             row$dataset_id, arm, fmt(row$elapsed_sec),
                             row$status)
            parts <- c(parts,
                       sprintf('<circle cx="%.1f" cy="%.1f" r="4.3" fill="%s" opacity="0.82"><title>%s</title></circle>',
                               xmap(row$elapsed_sec), yy + offsets[[jj]],
                               col, html.escape(title)))
        }
    }
    paste(c(parts, "</svg>"), collapse = "\n")
}

runtime.dataset.svg <- function(status) {
    rows <- status[is.finite(status$elapsed_sec), , drop = FALSE]
    if (!nrow(rows)) return("<p>No elapsed-time rows to plot.</p>")
    datasets <- unique(rows$dataset_id)
    methods <- unique(rows$method)
    w <- 1050
    h <- max(410, 90 + 28 * length(datasets))
    ml <- 235
    mr <- 40
    mt <- 42
    mb <- 60
    xmin <- max(0.1, min(rows$elapsed_sec, na.rm = TRUE) * 0.8)
    xmax <- max(rows$elapsed_sec, na.rm = TRUE) * 1.18
    lmin <- log10(xmin)
    lmax <- log10(xmax)
    xmap <- function(x) ml + ((log10(pmax(x, xmin)) - lmin) /
                                  (lmax - lmin)) * (w - ml - mr)
    yslots <- seq(mt + 16, h - mb, length.out = length(datasets))
    method.cols <- c(lps = "#0072B2", ps_lps = "#D55E00")
    parts <- c(
        sprintf('<svg viewBox="0 0 %d %d" role="img" aria-label="Runtime split by dataset">', w, h),
        sprintf('<text x="%d" y="24" font-size="16" font-weight="700">Task wall time by dataset</text>', ml),
        sprintf('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#333"/>',
                ml, h - mb + 18, w - mr, h - mb + 18)
    )
    ticks <- 10 ^ seq(floor(lmin), ceiling(lmax))
    ticks <- ticks[ticks >= xmin & ticks <= xmax]
    for (tk in ticks) {
        xx <- xmap(tk)
        parts <- c(parts,
                   sprintf('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#e4e7ec"/>',
                           xx, mt, xx, h - mb + 18),
                   sprintf('<text x="%.1f" y="%d" text-anchor="middle" font-size="11">%s</text>',
                           xx, h - mb + 36, html.escape(format(tk, scientific = FALSE))))
    }
    for (ii in seq_along(datasets)) {
        ds <- datasets[[ii]]
        yy <- yslots[[ii]]
        parts <- c(parts,
                   sprintf('<text x="%d" y="%.1f" text-anchor="end" font-size="11">%s</text>',
                           ml - 12, yy + 4, html.escape(ds)),
                   sprintf('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#eef1f5"/>',
                           ml, yy, w - mr, yy))
        for (mm in seq_along(methods)) {
            method <- methods[[mm]]
            rr <- rows[rows$dataset_id == ds & rows$method == method, ,
                       drop = FALSE]
            if (!nrow(rr)) next
            vals <- stats::quantile(rr$elapsed_sec, c(0.5, 1), na.rm = TRUE)
            parts <- c(parts,
                       sprintf('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="2" opacity="0.6"/>',
                               xmap(vals[[1L]]), yy + 5 * (mm - 1.5),
                               xmap(vals[[2L]]), yy + 5 * (mm - 1.5),
                               method.cols[[method]] %||% "#777"),
                       sprintf('<circle cx="%.1f" cy="%.1f" r="4.2" fill="%s"><title>%s %s median %s max %s sec</title></circle>',
                               xmap(vals[[1L]]), yy + 5 * (mm - 1.5),
                               method.cols[[method]] %||% "#777",
                               html.escape(ds), html.escape(method),
                               fmt(vals[[1L]]), fmt(vals[[2L]])))
        }
    }
    lx <- ml
    ly <- h - 18
    legend <- c(
        sprintf('<circle cx="%d" cy="%d" r="4.2" fill="%s"/><text x="%d" y="%d" font-size="11">LPS median to max</text>',
                lx, ly, method.cols[["lps"]], lx + 12, ly + 4),
        sprintf('<circle cx="%d" cy="%d" r="4.2" fill="%s"/><text x="%d" y="%d" font-size="11">PS-LPS median to max</text>',
                lx + 150, ly, method.cols[["ps_lps"]], lx + 162, ly + 4)
    )
    paste(c(parts, legend, "</svg>"), collapse = "\n")
}

artifact.link <- function(label, href) {
    sprintf('<a href="%s">%s</a>', html.escape(href), html.escape(label))
}

args <- parse.args(commandArgs(trailingOnly = TRUE))
run.dir <- args$run_dir
if (is.null(run.dir)) {
    stop("Usage: Rscript merge_lps_ps_lps_backend_broader_p7x_run.R ",
         "--run_dir=<path>", call. = FALSE)
}
run.dir <- normalizePath(run.dir, mustWork = TRUE)
tasks <- utils::read.csv(file.path(run.dir, "task_manifest.csv"),
                         stringsAsFactors = FALSE, colClasses = "character")

status.list <- lapply(tasks$status_path, read.status)
status <- do.call(rbind, status.list[!vapply(status.list, is.null, logical(1L))])
if (is.null(status)) {
    status <- data.frame(task_id = character(), dataset_id = character(),
                         method = character(), chart_dim_rule = character(),
                         backend_variant = character(), status = character(),
                         stringsAsFactors = FALSE)
}
status <- merge(tasks[, c("task_id", "batch_id", "dataset_id",
                          "geometry_family", "method", "chart_dim_rule",
                          "backend_variant", "result_path", "status_path",
                          "log_path")],
                status,
                by = c("task_id", "dataset_id", "method", "chart_dim_rule",
                       "backend_variant", "result_path"),
                all.x = TRUE,
                suffixes = c("", ".status"))
status$status[is.na(status$status)] <- "missing"
status$elapsed_sec <- suppressWarnings(as.numeric(status$elapsed_sec))
utils::write.csv(status, file.path(run.dir, "tables", "task_status.csv"),
                 row.names = FALSE, quote = TRUE)

okish <- status$status %in% c("ok", "nonfinite_fit") &
    file.exists(status$result_path)
summaries <- lapply(status$result_path[okish], function(path) {
    readRDS(path)$summary
})
combined <- if (length(summaries)) do.call(rbind, summaries) else data.frame()
utils::write.csv(combined, file.path(run.dir, "tables", "combined_results.csv"),
                 row.names = FALSE, quote = TRUE)

coverage <- if (nrow(status)) {
    arm.keys <- unique(status[, c("method", "chart_dim_rule",
                                  "backend_variant"), drop = FALSE])
    coverage.list <- lapply(seq_len(nrow(arm.keys)), function(ii) {
        key <- arm.keys[ii, ]
        rows <- status[status$method == key$method &
                           status$chart_dim_rule == key$chart_dim_rule &
                           status$backend_variant == key$backend_variant,
                       , drop = FALSE]
        data.frame(
            method = key$method,
            chart_dim_rule = key$chart_dim_rule,
            backend_variant = key$backend_variant,
            planned = nrow(rows),
            ok = sum(rows$status == "ok", na.rm = TRUE),
            nonfinite_fit = sum(rows$status == "nonfinite_fit", na.rm = TRUE),
            error = sum(rows$status == "error", na.rm = TRUE),
            missing = sum(rows$status == "missing", na.rm = TRUE),
            median_elapsed_sec = stats::median(rows$elapsed_sec, na.rm = TRUE),
            max_elapsed_sec = max(rows$elapsed_sec, na.rm = TRUE),
            stringsAsFactors = FALSE
        )
    })
    do.call(rbind, coverage.list)
} else {
    data.frame()
}
utils::write.csv(coverage, file.path(run.dir, "tables", "coverage_by_arm.csv"),
                 row.names = FALSE, quote = TRUE)

best <- if (nrow(combined)) {
    best.list <- lapply(split(combined, combined$dataset_id), function(dd) {
        rows <- dd[dd$status == "ok" & is.finite(dd$truth_rmse), ]
        if (!nrow(rows)) return(NULL)
        rows[which.min(rows$truth_rmse),
             c("dataset_id", "geometry_family", "method", "chart_dim_rule",
               "backend_variant", "truth_rmse", "observed_rmse",
               "selected_cv_rmse_observed", "elapsed_sec")]
    })
    best.list <- best.list[!vapply(best.list, is.null, logical(1L))]
    if (length(best.list)) do.call(rbind, best.list) else data.frame()
} else {
    data.frame()
}
utils::write.csv(best, file.path(run.dir, "tables", "best_by_dataset.csv"),
                 row.names = FALSE, quote = TRUE)

regret <- if (nrow(combined)) {
    ok <- combined[combined$status == "ok" & is.finite(combined$truth_rmse),
                   , drop = FALSE]
    if (nrow(ok)) {
        ok$arm_label <- paste(ok$method, ok$chart_dim_rule,
                              ok$backend_variant, sep = " / ")
        ok$short_label <- paste0(ifelse(ok$method == "ps_lps", "PS", "LPS"),
                                 "-",
                                 ifelse(ok$chart_dim_rule == "local.auto",
                                        "LA", "A"),
                                 "-",
                                 c(monomial_tiny_ridge = "M",
                                   weighted_qr_drop_tiny = "QR",
                                   orthogonal_drop_adaptive_tiny = "O")[
                                       ok$backend_variant])
        case.best <- stats::aggregate(
            ok$truth_rmse,
            by = list(dataset_id = ok$dataset_id),
            FUN = min,
            na.rm = TRUE
        )
        names(case.best)[2L] <- "case_best_truth_rmse"
        ok <- merge(ok, case.best, by = "dataset_id", all.x = TRUE)
        ok$regret <- ok$truth_rmse - ok$case_best_truth_rmse
        ok$regret_ratio <- ok$truth_rmse / ok$case_best_truth_rmse
        ok[, c("dataset_id", "geometry_family", "method", "chart_dim_rule",
               "backend_variant", "arm_label", "short_label", "truth_rmse",
               "case_best_truth_rmse", "regret", "regret_ratio",
               "elapsed_sec"), drop = FALSE]
    } else {
        data.frame()
    }
} else {
    data.frame()
}
utils::write.csv(regret, file.path(run.dir, "tables", "regret_by_case.csv"),
                 row.names = FALSE, quote = TRUE)

regret.summary <- if (nrow(coverage)) {
    arm.base <- coverage
    arm.base$arm_label <- paste(arm.base$method, arm.base$chart_dim_rule,
                                arm.base$backend_variant, sep = " / ")
    arm.base$short_label <- paste0(
        ifelse(arm.base$method == "ps_lps", "PS", "LPS"), "-",
        ifelse(arm.base$chart_dim_rule == "local.auto", "LA", "A"), "-",
        c(monomial_tiny_ridge = "M",
          weighted_qr_drop_tiny = "QR",
          orthogonal_drop_adaptive_tiny = "O")[arm.base$backend_variant]
    )
    arm.base$failure_rate <- with(
        arm.base,
        (nonfinite_fit + error + missing) / pmax(planned, 1)
    )
    if (nrow(regret)) {
        reg.list <- lapply(split(regret, regret$arm_label), function(dd) {
            med <- stats::median(dd$regret, na.rm = TRUE)
            mad <- raw.mad(dd$regret)
            data.frame(
                arm_label = dd$arm_label[[1L]],
                n_regret_cases = nrow(dd),
                mean_regret = mean(dd$regret, na.rm = TRUE),
                median_regret = med,
                regret_mad = mad,
                regret_snr = ratio.med.mad(med, mad),
                max_regret = max(dd$regret, na.rm = TRUE),
                mean_regret_ratio = mean(dd$regret_ratio, na.rm = TRUE),
                stringsAsFactors = FALSE
            )
        })
        reg.stats <- do.call(rbind, reg.list)
        merge(arm.base, reg.stats, by = "arm_label", all.x = TRUE)
    } else {
        arm.base$n_regret_cases <- 0L
        arm.base$mean_regret <- NA_real_
        arm.base$median_regret <- NA_real_
        arm.base$regret_mad <- NA_real_
        arm.base$regret_snr <- NA_real_
        arm.base$max_regret <- NA_real_
        arm.base$mean_regret_ratio <- NA_real_
        arm.base
    }
} else {
    data.frame()
}
if (nrow(regret.summary)) {
    regret.summary$elapsed_mad <- NA_real_
    for (ii in seq_len(nrow(regret.summary))) {
        rows <- status[status$method == regret.summary$method[[ii]] &
                           status$chart_dim_rule ==
                           regret.summary$chart_dim_rule[[ii]] &
                           status$backend_variant ==
                           regret.summary$backend_variant[[ii]] &
                           is.finite(status$elapsed_sec), , drop = FALSE]
        regret.summary$elapsed_mad[[ii]] <- raw.mad(rows$elapsed_sec)
    }
    regret.summary$elapsed_snr <- mapply(
        ratio.med.mad,
        regret.summary$median_elapsed_sec,
        regret.summary$elapsed_mad
    )
}
utils::write.csv(regret.summary,
                 file.path(run.dir, "tables", "regret_summary_by_arm.csv"),
                 row.names = FALSE, quote = TRUE)

status.count <- as.data.frame(table(status$status), stringsAsFactors = FALSE)
names(status.count) <- c("status", "n")

fail <- status[status$status %in% c("error", "missing"), , drop = FALSE]
slow.rows <- status[is.finite(status$elapsed_sec), , drop = FALSE]
slow.rows <- slow.rows[order(-slow.rows$elapsed_sec), , drop = FALSE]
slow.rows <- head(slow.rows[, c("dataset_id", "method", "chart_dim_rule",
                                "backend_variant", "status", "elapsed_sec",
                                "error_class"), drop = FALSE], 14L)

timeout5400 <- status[is.finite(status$elapsed_sec) &
                          status$elapsed_sec > 5400, , drop = FALSE]
timeout5400.count <- nrow(timeout5400)
timeout5400.ok <- sum(timeout5400$status == "ok", na.rm = TRUE)

decision.summary <- data.frame(
    question = c(
        "Does orthogonal_drop_adaptive_tiny improve LPS robustness?",
        "Is weighted_qr_drop_tiny ready for routine runs?",
        "Is PS-LPS guarded/drop ready without runtime controls?",
        "What should the next backend comparison do?"
    ),
    answer = c(
        "Yes as a candidate: it produced ok LPS fits on all planned rows in this run, where monomial and weighted-QR LPS often returned nonfinite selected fits.",
        "No: it had nonfinite LPS fits and severe PS-LPS runtime tails, so it should be dropped from routine broad comparisons or kept only for profiling.",
        "Not yet: PS-LPS produced many finite fits, but guarded/drop variants created long-tail tasks, including manually killed rows and several successful tasks above 5400 seconds.",
        "Run a cleaner monomial_tiny_ridge versus orthogonal_drop_adaptive_tiny comparison with hard per-task timeouts and explicit planned/ok/nonfinite/error accounting."
    ),
    stringsAsFactors = FALSE
)

backend.learning.summary <- data.frame(
    method = c("<strong>LPS</strong>", "<strong>PS-LPS</strong>"),
    monomial_tiny_ridge = c(
        paste0(
            "<ul>",
            "<li>Operationally fragile in this broad run: only 5/14 OK for ",
            "<code>auto</code> and 5/14 OK for <code>local.auto</code>.</li>",
            "<li>The failures were nonfinite selected fits, so this backend is ",
            "not robust enough as the routine LPS backend on these fixtures.</li>",
            "<li>It remains a useful reference because it is the simplest ",
            "ridge-stabilized monomial design.</li>",
            "</ul>"
        ),
        paste0(
            "<ul>",
            "<li>Completed all planned PS-LPS rows: 14/14 OK for ",
            "<code>auto</code> and 14/14 OK for <code>local.auto</code>.</li>",
            "<li>It was much faster than the PS-LPS drop variants in this run, ",
            "though still slower than ordinary LPS.</li>",
            "<li>This is the best current PS-LPS operational baseline for the ",
            "next focused comparison.</li>",
            "</ul>"
        )
    ),
    weighted_qr_drop_tiny = c(
        paste0(
            "<ul>",
            "<li>Did not solve the LPS robustness problem: only 4/14 OK for ",
            "<code>auto</code> and 4/14 OK for <code>local.auto</code>.</li>",
            "<li>It adds rank-dropping complexity without a clear accuracy or ",
            "stability payoff here.</li>",
            "<li>Recommendation: remove from routine broad comparisons; keep ",
            "only for targeted profiling/debugging if needed.</li>",
            "</ul>"
        ),
        paste0(
            "<ul>",
            "<li>Produced finite PS-LPS fits in most rows, but only 12/14 OK ",
            "for each chart rule.</li>",
            "<li>It was part of the severe long-runtime tail, with manually ",
            "killed rows and very slow successful rows.</li>",
            "<li>Recommendation: do not treat as deployable until hard timeouts ",
            "and additional profiling are in place.</li>",
            "</ul>"
        )
    ),
    orthogonal_drop_adaptive_tiny = c(
        paste0(
            "<ul>",
            "<li>Strongest LPS robustness result: 14/14 OK for ",
            "<code>auto</code> and 14/14 OK for <code>local.auto</code>.</li>",
            "<li>Runtime stayed in the ordinary-LPS range, so the robustness gain ",
            "did not create a large operational penalty.</li>",
            "<li>Recommendation: carry forward as the main LPS backend candidate ",
            "against <code>monomial_tiny_ridge</code>.</li>",
            "</ul>"
        ),
        paste0(
            "<ul>",
            "<li>Produced finite PS-LPS fits in most rows, but only 12/14 OK ",
            "for each chart rule.</li>",
            "<li>Accuracy was often competitive, but runtime tails remain a ",
            "blocking operational concern for broad prospective runs.</li>",
            "<li>Recommendation: keep as an experimental PS-LPS backend only ",
            "under hard timeout accounting.</li>",
            "</ul>"
        )
    ),
    stringsAsFactors = FALSE
)

variable.dictionary <- data.frame(
    variable = c("Truth RMSE", "selected CV RMSE", "Observed RMSE", "ok",
                 "nonfinite_fit", "error", "missing", "finite_cv_candidates",
                 "total_cv_candidates", "elapsed_sec", "regret",
                 "regret ratio", "R_med", "R_mad", "R_snr", "failure_rate",
                 "T_med", "T_mad", "T_snr"),
    meaning = c(
        "Synthetic target error: sqrt(mean((fhat - f)^2)); lower is better.",
        "Observed cross-validation score selected by the method; it estimates prediction error without using the truth function.",
        "sqrt(mean((fhat - y)^2)) on the full observed response; useful as an overfit/smoothing diagnostic, not the target criterion.",
        "The task completed and produced finite selected fitted values and finite selected CV score.",
        "The R task completed but the selected fit or selected observed CV score was nonfinite.",
        "The worker process exited nonzero or was killed before producing a completed result summary.",
        "A planned task did not produce a status file.",
        "Number of finite CV/search candidates available to the selector for that task.",
        "Number of planned CV/search candidates for that task.",
        "End-to-end isolated R task wall time in seconds, including CV/search/final fit as applicable.",
        "Truth RMSE minus the best successful Truth RMSE in the same dataset/case.",
        "Truth RMSE divided by the best successful Truth RMSE in the same dataset/case.",
        "Median regret across successful cases for a method arm.",
        "Median absolute deviation of regret values around R_med.",
        "Regret signal-to-noise ratio, R_med / R_mad; lower is better when both quantities are finite.",
        "Fraction of planned tasks that were nonfinite, errored, or missing.",
        "Median elapsed time across finite task timings for a method arm.",
        "Median absolute deviation of elapsed times around T_med.",
        "Elapsed-time signal-to-noise ratio, T_med / T_mad; larger means elapsed times are large relative to their median absolute deviation."
    ),
    stringsAsFactors = FALSE
)

table.html.raw <- function(df, digits = 4) {
    dff <- df
    for (nm in names(dff)) {
        if (is.numeric(dff[[nm]])) dff[[nm]] <- fmt(dff[[nm]], digits)
    }
    header <- paste0("<tr>", paste0("<th>", html.escape(names(dff)), "</th>",
                                   collapse = ""), "</tr>")
    body <- apply(dff, 1L, function(row) {
        paste0("<tr>", paste0("<td>", row, "</td>", collapse = ""), "</tr>")
    })
    paste0("<table>", header, paste(body, collapse = "\n"), "</table>")
}

raw.artifacts <- data.frame(
    artifact = c("run_config.csv", "task_manifest.csv", "combined_results.csv",
                 "task_status.csv", "coverage_by_arm.csv",
                 "best_by_dataset.csv", "regret_by_case.csv",
                 "regret_summary_by_arm.csv", "python_launcher.log",
                 "launcher script", "worker script", "merge/report script"),
    link = c(
        artifact.link("run_config.csv", "../run_config.csv"),
        artifact.link("task_manifest.csv", "../task_manifest.csv"),
        artifact.link("combined_results.csv", "../tables/combined_results.csv"),
        artifact.link("task_status.csv", "../tables/task_status.csv"),
        artifact.link("coverage_by_arm.csv", "../tables/coverage_by_arm.csv"),
        artifact.link("best_by_dataset.csv", "../tables/best_by_dataset.csv"),
        artifact.link("regret_by_case.csv", "../tables/regret_by_case.csv"),
        artifact.link("regret_summary_by_arm.csv",
                      "../tables/regret_summary_by_arm.csv"),
        artifact.link("python_launcher.log", "../logs/python_launcher.log"),
        html.escape("/Users/pgajer/current_projects/geosmooth/scripts/launch_lps_ps_lps_backend_broader_p7x_run.py"),
        html.escape("/Users/pgajer/current_projects/geosmooth/scripts/run_lps_ps_lps_backend_broader_p7x_task.R"),
        html.escape("/Users/pgajer/current_projects/geosmooth/scripts/merge_lps_ps_lps_backend_broader_p7x_run.R")
    ),
    stringsAsFactors = FALSE
)

html <- paste0(
'<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Broader P7X LPS / PS-LPS Backend Comparison</title>
<script>
window.MathJax = { tex: { inlineMath: [["\\\\(","\\\\)"], ["$","$"]],
                          displayMath: [["\\\\[","\\\\]"]] } };
</script>
<script defer src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js"></script>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
       color: #222b35; margin: 0; background: #fbfbfc; }
main { max-width: 1240px; margin: 0 auto; padding: 32px 30px 56px; }
h1 { font-size: 34px; margin: 0 0 10px; }
h2 { margin-top: 34px; border-top: 1px solid #d8dce1; padding-top: 20px; }
h3 { margin-top: 24px; }
p, li { line-height: 1.55; max-width: 1050px; }
table { border-collapse: collapse; width: 100%; margin: 14px 0 18px;
        font-size: 12px; }
th, td { border-bottom: 1px solid #dfe3e8; padding: 6px 7px;
         text-align: left; vertical-align: top; }
th { background: #eef1f5; }
table.learning-grid { font-size: 12px; }
table.learning-grid th:first-child, table.learning-grid td:first-child {
    width: 90px; white-space: nowrap;
}
table.learning-grid ul { margin: 0; padding-left: 18px; }
table.learning-grid li { margin: 0 0 5px; line-height: 1.35; max-width: none; }
code { background: #eef1f5; padding: 1px 4px; border-radius: 4px; }
.note { background: #eef6ff; border-left: 4px solid #2c7fb8;
        padding: 12px 14px; }
.warn { background: #fff5e6; border-left: 4px solid #d55e00;
        padding: 12px 14px; margin: 14px 0; }
.decision { background: #f2fbf6; border-left: 4px solid #009E73;
            padding: 12px 14px; margin: 14px 0; }
a { color: #1f6feb; }
svg { max-width: 100%; height: auto; background: #fff; border: 1px solid #e1e5ea; }
.math { font-family: Georgia, "Times New Roman", serif; font-size: 17px; }
.figure-caption { font-size: 13px; color: #374151; margin: 8px 0 22px;
                  max-width: 1080px; }
.figure-caption strong { color: #111827; }
</style>
</head>
<body><main>
<h1>Broader P7X-Style LPS / PS-LPS Backend Comparison</h1>
<p><strong>Run directory:</strong> <code>', html.escape(run.dir), '</code></p>
<p><strong>Report built:</strong> ', html.escape(format(Sys.time(),
 "%Y-%m-%d %H:%M:%S %Z")), '</p>

<h2>Purpose And Main Questions</h2>
<p>This report summarizes a broader P7X-style backend comparison for ordinary
local polynomial smoothing (LPS) and prediction-synchronized LPS (PS-LPS). The
run used frozen first-batch non-manifold/P7X-style fixtures, both
<code>chart.dim = "auto"</code> and <code>chart.dim = "local.auto"</code>, a
support grid <code>15:35</code>, degree 2, and the tricube kernel.</p>
<p>The main questions are:</p>
<ul>
<li>Does <code>orthogonal_drop_adaptive_tiny</code> make LPS more robust than
the monomial and weighted-QR/drop variants?</li>
<li>Do the guarded/drop variants remain practical once PS-LPS synchronization
and lambda search are included?</li>
<li>Which backend variants should continue into the next focused comparison,
and which should be dropped from routine broad runs?</li>
</ul>
<div class="note">This HTML report consumes precomputed run artifacts and does
not rerun the experiment.</div>

<h2>Methods And Labels</h2>
<p>The report compares <em>method arms</em>.  A method arm is the combination</p>
<p class="math">\\[
  a = (\\text{estimator family},\\ \\text{chart-dimension rule},\\
       \\text{linear-algebra backend}).
\\]</p>
<p>Thus a label such as <code>ps_lps / local.auto /
orthogonal_drop_adaptive_tiny</code> means prediction-synchronized LPS, using
anchor-specific automatic chart dimensions, and using the orthogonalized
rank-dropping local polynomial backend.</p>

<h3>LPS: Local Polynomial Smoother</h3>
<p>The label <code>lps</code> denotes ordinary local polynomial smoothing.
For each anchor point \\(x_i\\), the method chooses a neighborhood
\\(N_i(k)\\), builds local chart coordinates \\(z_{ij}\\) for neighbors
\\(j \\in N_i(k)\\), forms a degree-\\(q\\) polynomial feature map
\\(\\phi_q(z_{ij})\\), and solves an independent weighted local least-squares
problem</p>
<p class="math">\\[
  \\widehat\\beta_i
  =
  \\arg\\min_\\beta
  \\sum_{j\\in N_i(k)}
  w_{ij}\\,\\{y_j - \\phi_q(z_{ij})^\\top\\beta\\}^2
  + \\lambda_{\\rm ridge}\\|\\beta\\|_2^2 .
\\]</p>
<p>The fitted value at the anchor is</p>
<p class="math">\\[
  \\widehat f_i = \\phi_q(0)^\\top\\widehat\\beta_i .
\\]</p>
<p>In this run LPS uses candidate support sizes \\(k\\in\\{15,16,\\ldots,35\\}\\),
degree \\(q=2\\), and the tricube kernel.  Cross-validation selects the support
size within each task.</p>

<h3>PS-LPS: Prediction-Synchronized LPS</h3>
<p>The label <code>ps_lps</code> denotes prediction-synchronized LPS.  It starts
from the same local chart frames as LPS, but estimates all local chart
coefficients jointly.  The objective keeps local data-fit terms and adds a
synchronization penalty that discourages overlapping charts from making
different predictions on the same points:</p>
<p class="math">\\[
  \\min_{\\{\\beta_i\\}}
  \\sum_i \\sum_{j\\in N_i(k)}
  w_{ij}\\,\\{y_j - \\phi_q(z_{ij})^\\top\\beta_i\\}^2
  + \\lambda_{\\rm sync}
  \\sum_{(i,i^\\prime)}\\sum_{j\\in N_i(k)\\cap N_{i^\\prime}(k)}
  \\omega_{ii^\\prime j}
  \\{\\phi_q(z_{ij})^\\top\\beta_i
     - \\phi_q(z_{i^\\prime j})^\\top\\beta_{i^\\prime}\\}^2
  + \\lambda_{\\rm ridge}\\sum_i\\|\\beta_i\\|_2^2 .
\\]</p>
<p>Here \\(\\lambda_{\\rm sync}\\) controls how strongly overlapping local
polynomial predictions are synchronized.  The label <code>guarded</code> in the
raw artifacts means \\(\\lambda_{\\rm sync}\\) was selected by the guarded search
policy rather than by a full dense grid.</p>

<h3>Chart-Dimension Rules</h3>
<p>The chart-dimension rule determines the dimension \\(d\\) of the local PCA chart
used before constructing polynomial features.</p>
<ul>
<li><code>auto</code>: estimate one global chart dimension \\(d\\) from the
observed data and use it for every anchor.</li>
<li><code>local.auto</code>: estimate an anchor-specific dimension \\(d_i\\), so
different parts of a heterogeneous state space may use different local chart
dimensions.</li>
</ul>

<h3>Backend Variants</h3>
<p>The backend variant controls how the weighted local polynomial least-squares
systems are stabilized.</p>
<ul>
<li><code>monomial_tiny_ridge</code>: use the standard monomial polynomial
design with a tiny ridge term.</li>
<li><code>weighted_qr_drop_tiny</code>: use weighted QR/rank dropping on the
monomial design, then a tiny ridge grid.</li>
<li><code>orthogonal_drop_adaptive_tiny</code>: transform the weighted local
polynomial design to an orthogonalized basis, drop rank-deficient directions,
and use the smallest allowed ridge needed by the guarded solver.</li>
</ul>
<p>These backend labels are not separate statistical models in isolation; they
are numerical/stabilization variants of the same LPS or PS-LPS smoother family.</p>

<h2>Run Design And Measures</h2>
<p>Each planned task was isolated in its own R worker process. A task-level
failure therefore records a status row without stopping the rest of the run.
The full run planned ', nrow(status), ' tasks: dataset by chart-dimension rule
by method by backend variant.</p>
<p class="math">Truth RMSE = sqrt( n<sup>-1</sup> sum<sub>i=1</sub><sup>n</sup>
( fhat<sub>i</sub> - f<sub>i</sub> )<sup>2</sup> ).</p>
<p><strong>Truth RMSE</strong> is the synthetic target error because the truth
function is known for these fixtures. <strong>Selected CV RMSE</strong> is the
observed cross-validation score used by the selector; it aims to estimate
prediction error without using the truth. <strong>Observed RMSE</strong> is
computed against the noisy observed response and is useful mainly as an
overfit/smoothing diagnostic.</p>
<h3>Variable Dictionary</h3>',
table.html(variable.dictionary),

'<h2>Fit Status Accounting</h2>
<p>Status accounting comes before score interpretation. Accuracy summaries below
only use rows with status <code>ok</code>, so the planned/ok/nonfinite/error
counts are part of the result, not bookkeeping.</p>
<h3>Status Counts</h3>',
table.html(status.count),
'<h3>Arm Coverage</h3>
<p>The <code>planned</code> column counts all tasks in the task manifest; it is
not limited to tasks with result RDS files.</p>',
if (nrow(coverage)) table.html(coverage) else "<p>No completed rows yet.</p>",

'<h2>Frank/Friedman-Style Summary Across Cases</h2>
<p>Following the spirit of Frank and Friedman-style simulation summaries, this
section treats each dataset as a case and summarizes every method arm by its
<em>vector of regrets across cases</em>, plus runtime and failure rate.  This is
more informative than asking only which arm won each individual dataset.</p>
<p>For method arm \\(a\\) and case \\(c\\), let</p>
<p class="math">\\[
  R_{a,c} = \\operatorname{TruthRMSE}_{a,c}.
\\]</p>
<p>Among successful finite rows in the same case, define the in-case reference</p>
<p class="math">\\[
  R_c^* = \\min_{a\\in\\mathcal A_c} R_{a,c}.
\\]</p>
<p>The regret and regret ratio are</p>
<p class="math">\\[
  \\Delta_{a,c} = R_{a,c} - R_c^*,
  \\qquad
  \\rho_{a,c} = \\frac{R_{a,c}}{R_c^*}.
\\]</p>
<p>Here \\(\\Delta_{a,c}=0\\) means that arm \\(a\\) was tied for best successful
Truth RMSE on case \\(c\\).  Missing, errored, and nonfinite rows are not assigned
a regret value; they are accounted for separately through the failure rate</p>
<p class="math">\\[
  \\pi_a =
  \\frac{\\#\\{\\text{nonfinite, error, or missing tasks for }a\\}}
       {\\#\\{\\text{planned tasks for }a\\}}.
\\]</p>
<h3>Method Performance Measures</h3>
<p>For each method arm \\(a\\), the report summarizes performance by the regret
vector \\(\\{\\Delta_{a,c}\\}\\), task failures, and elapsed-time vector
\\(\\{T_{a,c}\\}\\).  The arm-level regret summaries are</p>
<p class="math">\\[
  R_{\\rm med}(a) = \\operatorname{median}_c\\Delta_{a,c},
\\]</p>
<p class="math">\\[
  R_{\\rm mad}(a)
  =
  \\operatorname{median}_c
  \\left|\\Delta_{a,c}-R_{\\rm med}(a)\\right|,
\\]</p>
<p class="math">\\[
  R_{\\rm snr}(a) =
  \\frac{R_{\\rm med}(a)}{R_{\\rm mad}(a)}.
\\]</p>
<p>Here \\(R_{\\rm med}\\) measures typical distance from the in-case best
successful method arm.  \\(R_{\\rm mad}\\) measures how variable that regret is
across cases.  The ratio \\(R_{\\rm snr}\\) is a scale-free diagnostic of whether
typical regret is large relative to its across-case dispersion.  Lower
\\(R_{\\rm med}\\) and lower failure rate are better; \\(R_{\\rm snr}\\) should be
interpreted together with \\(R_{\\rm med}\\), because a stable but large regret is
not desirable.</p>
<p>The elapsed-time summaries use the same construction:</p>
<p class="math">\\[
  T_{\\rm med}(a) = \\operatorname{median}_c T_{a,c},
  \\qquad
  T_{\\rm mad}(a)
  =
  \\operatorname{median}_c |T_{a,c}-T_{\\rm med}(a)|,
\\]</p>
<p class="math">\\[
  T_{\\rm snr}(a) =
  \\frac{T_{\\rm med}(a)}{T_{\\rm mad}(a)}.
\\]</p>
<p>\\(T_{\\rm med}\\) measures typical task cost.  \\(T_{\\rm mad}\\) measures
runtime instability across cases.  \\(T_{\\rm snr}\\) is mainly a runtime
regularity diagnostic; it should not be read as accuracy.</p>
<h3>Median Runtime Versus Median Regret</h3>
<p>Each point is one method arm.  Red horizontal bars show \\(T_{\\rm mad}\\), and
red vertical bars show \\(R_{\\rm mad}\\).</p>',
median.time.regret.svg(regret.summary),
'<p class="figure-caption"><strong>Figure 1.</strong> Median runtime versus
median regret.  Each labeled point is one method arm.  The x-axis shows median
elapsed task time \\(T_{\\rm med}\\) and the y-axis shows median regret
\\(R_{\\rm med}\\) relative to the best successful arm in each case.  Red bars
show median absolute deviations.  Lower-left arms are preferable when failure
rates are acceptable.</p>',
'<h3>Regret SNR Versus Runtime SNR</h3>
<p>This plot compares the relative stability of regret and elapsed time across
cases.  It is a diagnostic view, not a winner-selection rule.</p>',
snr.scatter.svg(regret.summary, "regret_snr", "elapsed_snr",
                "R_snr = R_med / R_mad",
                "T_snr = T_med / T_mad",
                "Regret SNR versus elapsed-time SNR"),
'<p class="figure-caption"><strong>Figure 2.</strong> Regret signal-to-noise
ratio versus elapsed-time signal-to-noise ratio.  The x-axis is
\\(R_{\\rm snr}=R_{\\rm med}/R_{\\rm mad}\\), and the y-axis is
\\(T_{\\rm snr}=T_{\\rm med}/T_{\\rm mad}\\).  This figure shows whether typical
regret and runtime are large relative to their across-case dispersion; it is a
stability diagnostic rather than a standalone ranking rule.</p>',
'<h3>Regret SNR Versus Failure Rate</h3>
<p>This plot separates regret stability from task reliability.  Arms with high
failure rate remain operationally risky even if their finite successful rows
look stable.</p>',
snr.scatter.svg(regret.summary, "regret_snr", "failure_rate",
                "R_snr = R_med / R_mad",
                "failure rate",
                "Regret SNR versus failure rate"),
'<p class="figure-caption"><strong>Figure 3.</strong> Regret signal-to-noise
ratio versus failure rate.  The x-axis is \\(R_{\\rm snr}\\), and the y-axis is
the fraction of planned tasks that were nonfinite, errored, missing, or timed
out.  Arms high on the y-axis are operationally risky even if their successful
finite rows have low regret.</p>',
'
<h3>Regret Vectors</h3>
<p>Each dot is one dataset/case.  The thick vertical tick is the median regret
for that method arm.  A good arm should have small regrets across many cases,
not merely win one isolated case.</p>',
regret.vector.svg(regret),
'<p class="figure-caption"><strong>Figure 4.</strong> Regret vectors across
cases by method arm.  Each dot is one case-level regret
\\(\\Delta_{a,c}=R_{a,c}-R_c^*\\); the thick vertical tick marks the median
regret for that arm.  The best arms have dots clustered close to zero across
many cases, not only a few isolated wins.</p>',
'<h3>Regret Summary Table</h3>
<p>This short table is included to make the plotted quantities auditable.  The
full case-level regret vector is linked as <code>regret_by_case.csv</code>.</p>',
if (nrow(regret.summary)) {
    cols <- c("short_label", "method", "chart_dim_rule", "backend_variant",
              "planned", "ok", "nonfinite_fit", "error", "failure_rate",
              "n_regret_cases", "median_regret", "regret_mad",
              "regret_snr", "mean_regret", "max_regret",
              "median_elapsed_sec", "elapsed_mad", "elapsed_snr")
    table.html(regret.summary[, cols, drop = FALSE])
} else {
    "<p>No regret summary rows available.</p>"
},

'<h2>Runtime And Timeout Results</h2>
<p><code>elapsed_sec</code> is end-to-end isolated R task wall time, including
CV/search/final fit as applicable. Runtime is a first-class result here because
PS-LPS guarded/drop variants can have a severe long tail.</p>
<div class="warn">The original launcher did not enforce a hard timeout for this
run. Eight long-tail tasks were manually terminated and appear as
<code>worker_exit_-15</code> errors in <code>task_status.csv</code>. In
addition, ', timeout5400.count, ' tasks exceeded 5400 seconds, including ',
timeout5400.ok, ' tasks that eventually succeeded. A strict 5400 second timeout
would therefore have killed several successful guarded/drop PS-LPS rows, not
only the eight manually killed rows.</div>
<h3>Runtime By Arm</h3>
<p>The x-axis is log-scaled seconds. The red dashed line marks 5400 seconds.</p>',
runtime.arm.svg(status),
'<p class="figure-caption"><strong>Figure 5.</strong> Task wall time by
method, chart-dimension rule, and backend.  Each point is one isolated task,
shown on a log-scaled elapsed-time axis.  The red dashed line marks 5400
seconds, the operational timeout threshold used for interpretation.</p>',
'<h3>Runtime By Dataset</h3>
<p>For each dataset and method, the point is the median task time and the line
extends to the maximum task time. This shows which datasets dominate runtime.</p>',
runtime.dataset.svg(status),
'<p class="figure-caption"><strong>Figure 6.</strong> Task wall time by
dataset.  For each dataset and method family, the point is the median elapsed
time and the line extends to the maximum elapsed time.  This identifies which
datasets create the dominant runtime burden.</p>',
'<h3>Slowest Rows</h3>',
if (nrow(slow.rows)) table.html(slow.rows) else "<p>No elapsed-time rows.</p>",
'<h3>Timeout/Error Rows</h3>
<p><code>combined_results.csv</code> contains completed result summaries, while
<code>task_status.csv</code> contains all ', nrow(status), ' planned tasks.
The table below is intentionally short because only task-level errors and
missing statuses are shown.</p>',
if (nrow(fail)) {
    table.html(fail[, c("task_id", "dataset_id", "method", "chart_dim_rule",
                        "backend_variant", "status", "elapsed_sec",
                        "error_class", "error_message"), drop = FALSE])
} else {
    '<div class="note">No task-level errors or missing statuses were recorded.</div>'
},

'<h2>Results Summary And Discussion</h2>',
table.html(decision.summary),
'<h3>What We Learned</h3>
<p>The table below summarizes the practical interpretation by smoother family
and backend variant.  The bullets that follow give the shorter decision-level
takeaway.</p>',
sub("<table>", "<table class=\"learning-grid\">",
    table.html.raw(backend.learning.summary)),
'<ul>
<li><strong>Positive LPS evidence:</strong>
<code>orthogonal_drop_adaptive_tiny</code> is the strongest robustness candidate
for LPS in this run because it avoided the nonfinite selected-fit failures seen
in the other LPS backend variants.</li>
<li><strong>Negative operational evidence:</strong>
<code>weighted_qr_drop_tiny</code> is not ready for routine broad comparisons.
It had LPS nonfinite failures and was part of the PS-LPS long-runtime tail.</li>
<li><strong>Mixed PS-LPS evidence:</strong> PS-LPS often completed and produced
finite fits, but the guarded/drop variants need runtime controls before their
accuracy can be interpreted as deployable evidence.</li>
<li><strong>Remaining uncertainty:</strong> the comparisons are descriptive.
The manually killed rows and the very slow successful rows mean that backend
policy should be decided after a cleaner run with hard timeouts.</li>
</ul>
<div class="decision">Recommended next step: drop routine
<code>weighted_qr_drop_tiny</code> from broad comparisons, compare
<code>monomial_tiny_ridge</code> versus
<code>orthogonal_drop_adaptive_tiny</code>, and enforce a hard per-task timeout
with planned/ok/nonfinite/error accounting in the report.</div>

<h2>Linked Audit Artifacts</h2>
<p>Large raw tables are linked here rather than printed in the report body.</p>',
table.html.raw(raw.artifacts),

'<h2>Reproducibility Appendix</h2>
<p>The experiment was generated by a preparer, isolated R worker tasks, a Python
supervisor, and this merge/report script. The report can be regenerated without
rerunning the workers with:</p>
<pre><code>Rscript /Users/pgajer/current_projects/geosmooth/scripts/merge_lps_ps_lps_backend_broader_p7x_run.R --run_dir=', html.escape(run.dir), '</code></pre>
<p>The launch command and worker-level details are recorded in
<code>run_config.csv</code>, <code>task_manifest.csv</code>, and
<code>logs/python_launcher.log</code>. Result-generation timestamps live in the
task status JSON files and in <code>task_status.csv</code>; this report build
timestamp is shown at the top of the page.</p>',
'</main></body></html>')

html.path <- file.path(run.dir, "reports",
                       "lps_ps_lps_backend_broader_p7x_comparison.html")
writeLines(html, html.path, useBytes = TRUE)

cat("Status table:", file.path(run.dir, "tables", "task_status.csv"), "\n")
cat("Combined results:", file.path(run.dir, "tables", "combined_results.csv"), "\n")
cat("Coverage:", file.path(run.dir, "tables", "coverage_by_arm.csv"), "\n")
cat("Best:", file.path(run.dir, "tables", "best_by_dataset.csv"), "\n")
cat("HTML report:", html.path, "\n")
cat("Task counts:\n")
print(status.count, row.names = FALSE)
