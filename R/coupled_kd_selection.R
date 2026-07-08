.coupled.kd.design.ncol <- function(chart.dim, degree) {
    as.integer(choose(as.integer(chart.dim) + as.integer(degree),
                      as.integer(degree)))
}

.coupled.kd.max.feasible.chart.dim <- function(support.size,
                                               degree,
                                               ambient.dim,
                                               design.margin = 2L) {
    support.size <- as.integer(support.size)
    degree <- as.integer(degree)
    ambient.dim <- as.integer(ambient.dim)
    design.margin <- as.integer(design.margin)
    if (!is.finite(support.size) || support.size < 1L ||
        !is.finite(degree) || degree < 0L ||
        !is.finite(ambient.dim) || ambient.dim < 1L ||
        !is.finite(design.margin) || design.margin < 0L) {
        stop("Invalid coupled k-d feasibility inputs.", call. = FALSE)
    }
    dims <- seq_len(ambient.dim)
    ok <- choose(dims + degree, degree) + design.margin <= support.size
    if (!any(ok)) {
        return(NA_integer_)
    }
    as.integer(max(dims[ok]))
}

.coupled.kd.resolve.auto.dim <- function(auto.chart.dim,
                                         support.size,
                                         degree) {
    if (is.null(auto.chart.dim)) {
        stop("'auto' chart-dimension seeds require 'auto.chart.dim'.",
             call. = FALSE)
    }
    if (is.function(auto.chart.dim)) {
        value <- auto.chart.dim(support.size = support.size, degree = degree)
    } else if (is.data.frame(auto.chart.dim)) {
        required <- c("support.size", "degree", "chart.dim")
        if (!all(required %in% names(auto.chart.dim))) {
            stop("'auto.chart.dim' data frames must contain support.size, ",
                 "degree, and chart.dim columns.", call. = FALSE)
        }
        hit <- auto.chart.dim[
            as.integer(auto.chart.dim$support.size) == as.integer(support.size) &
                as.integer(auto.chart.dim$degree) == as.integer(degree),
            ,
            drop = FALSE
        ]
        if (nrow(hit) != 1L) {
            stop("'auto.chart.dim' must provide exactly one seed for ",
                 "each support.size/degree pair.", call. = FALSE)
        }
        value <- hit$chart.dim[[1L]]
    } else if (!is.null(names(auto.chart.dim))) {
        key <- paste(as.integer(support.size), as.integer(degree), sep = ":")
        if (!key %in% names(auto.chart.dim)) {
            key <- as.character(as.integer(support.size))
        }
        if (!key %in% names(auto.chart.dim)) {
            stop("'auto.chart.dim' named vectors must contain support or ",
                 "support:degree keys.", call. = FALSE)
        }
        value <- auto.chart.dim[[key]]
    } else if (length(auto.chart.dim) == 1L) {
        value <- auto.chart.dim[[1L]]
    } else {
        stop("'auto.chart.dim' must be a scalar, named vector, data frame, ",
             "or function.", call. = FALSE)
    }
    value <- as.integer(value)
    if (length(value) != 1L || !is.finite(value) || value < 1L) {
        stop("'auto.chart.dim' resolved to an invalid dimension.",
             call. = FALSE)
    }
    value
}

.coupled.kd.source.rank <- function(source) {
    match(source, c("numeric", "auto_seed", "guard", "manual",
                    "local_auto_policy"))
}

.coupled.kd.stage.rank <- function(stage) {
    match(stage, c("skeleton", "local_refine", "guard", "full_reference"))
}

.coupled.kd.reuse.key <- function(support.size,
                                  kernel,
                                  max.chart.dim,
                                  reuse.type) {
    if (identical(reuse.type, "weighted")) {
        paste(as.integer(support.size), as.character(kernel),
              as.integer(max.chart.dim), sep = "\r")
    } else {
        paste(as.integer(support.size), as.integer(max.chart.dim),
              sep = "\r")
    }
}

.coupled.kd.candidate.table <- function(support.grid,
                                        degree.grid,
                                        chart.dim.grid,
                                        ambient.dim,
                                        kernel.grid = "gaussian",
                                        bandwidth.multiplier.grid = 1,
                                        stage = "full_reference",
                                        chart.dim.max = NULL,
                                        design.margin = 2L,
                                        auto.chart.dim = NULL,
                                        reuse.type = c("weighted", "chart")) {
    reuse.type <- match.arg(reuse.type)
    stage <- match.arg(stage, c("skeleton", "local_refine", "guard",
                               "full_reference"))
    ambient.dim <- as.integer(ambient.dim)
    if (length(ambient.dim) != 1L || !is.finite(ambient.dim) ||
        ambient.dim < 1L) {
        stop("'ambient.dim' must be a positive integer scalar.", call. = FALSE)
    }
    design.margin <- as.integer(design.margin)
    if (length(design.margin) != 1L || !is.finite(design.margin) ||
        design.margin < 0L) {
        stop("'design.margin' must be a nonnegative integer scalar.",
             call. = FALSE)
    }
    support.grid <- .klp.clean.support.grid(support.grid, n = Inf)
    degree.grid <- .klp.clean.degree.grid(degree.grid)
    kernel.grid <- .klp.clean.kernel.grid(kernel.grid)
    bandwidth.multiplier.grid <- .klp.clean.bandwidth.multiplier.grid(
        bandwidth.multiplier.grid
    )
    chart.grid <- .local.chart.clean.chart.dim.grid(chart.dim.grid)
    if (is.null(chart.dim.max)) {
        decoded <- lapply(chart.grid$chart.dim, function(x) {
            tryCatch(.local.chart.decode.chart.dim(x), error = function(e) NA)
        })
        numeric.dim <- unlist(lapply(decoded, function(x) {
            if (is.numeric(x) && length(x) == 1L && is.finite(x)) {
                as.integer(x)
            } else {
                NA_integer_
            }
        }), use.names = FALSE)
        chart.dim.max <- if (any(is.finite(numeric.dim))) {
            max(numeric.dim, na.rm = TRUE)
        } else {
            ambient.dim
        }
    }
    chart.dim.max <- as.integer(chart.dim.max)
    if (length(chart.dim.max) != 1L || !is.finite(chart.dim.max) ||
        chart.dim.max < 1L) {
        stop("'chart.dim.max' must be a positive integer scalar.",
             call. = FALSE)
    }

    rows <- vector("list", length(support.grid) * length(degree.grid) *
                       length(kernel.grid) *
                       length(bandwidth.multiplier.grid) *
                       nrow(chart.grid))
    rr <- 0L
    for (support.size in support.grid) {
        for (degree in degree.grid) {
            d.feasible.max <- .coupled.kd.max.feasible.chart.dim(
                support.size = support.size,
                degree = degree,
                ambient.dim = ambient.dim,
                design.margin = design.margin
            )
            d.hi <- suppressWarnings(min(chart.dim.max, ambient.dim,
                                         d.feasible.max, na.rm = TRUE))
            if (!is.finite(d.hi)) {
                d.hi <- NA_integer_
            }
            for (kernel in kernel.grid) {
                for (bandwidth.multiplier in bandwidth.multiplier.grid) {
                    for (ii in seq_len(nrow(chart.grid))) {
                        label <- chart.grid$chart.dim[[ii]]
                        decoded <- .local.chart.decode.chart.dim(label)
                        source <- "numeric"
                        raw <- NA_integer_
                        clipped <- NA_integer_
                        seed.clipped <- FALSE
                        skip.reason <- NA_character_
                        feasible <- TRUE
                        if (identical(decoded, "local.auto")) {
                            source <- "local_auto_policy"
                            feasible <- FALSE
                            skip.reason <- "local_auto_separate_policy"
                        } else if (identical(decoded, "auto")) {
                            source <- "auto_seed"
                            raw <- .coupled.kd.resolve.auto.dim(
                                auto.chart.dim = auto.chart.dim,
                                support.size = support.size,
                                degree = degree
                            )
                            clipped <- if (is.finite(d.hi)) {
                                as.integer(min(raw, d.hi))
                            } else {
                                NA_integer_
                            }
                            seed.clipped <- is.finite(clipped) &&
                                !identical(as.integer(raw),
                                           as.integer(clipped))
                        } else if (is.null(decoded)) {
                            source <- "manual"
                            raw <- ambient.dim
                            clipped <- raw
                        } else {
                            raw <- as.integer(decoded)
                            clipped <- raw
                        }
                        design.ncol <- if (is.finite(clipped)) {
                            .coupled.kd.design.ncol(clipped, degree)
                        } else {
                            NA_integer_
                        }
                        if (isTRUE(feasible)) {
                            if (!is.finite(clipped) || clipped < 1L) {
                                feasible <- FALSE
                                skip.reason <- "chart_dim_unavailable"
                            } else if (clipped > ambient.dim) {
                                feasible <- FALSE
                                skip.reason <- "chart_dim_exceeds_ambient"
                            } else if (clipped > chart.dim.max) {
                                feasible <- FALSE
                                skip.reason <- "chart_dim_exceeds_max"
                            } else if (!is.finite(d.feasible.max) ||
                                       clipped > d.feasible.max ||
                                       design.ncol + design.margin >
                                           support.size) {
                                feasible <- FALSE
                                skip.reason <- "design_underdetermined"
                            }
                        }
                        rr <- rr + 1L
                        rows[[rr]] <- data.frame(
                            candidate.id = NA_integer_,
                            stage = stage,
                            support.size = as.integer(support.size),
                            chart.dim = if (is.finite(clipped)) {
                                as.character(as.integer(clipped))
                            } else {
                                label
                            },
                            chart.dim.source = source,
                            chart.dim.raw = raw,
                            chart.dim.clipped = clipped,
                            chart.dim.seed.clipped = seed.clipped,
                            chart.dim.max = as.integer(chart.dim.max),
                            kernel = as.character(kernel),
                            degree = as.integer(degree),
                            bandwidth.multiplier =
                                as.numeric(bandwidth.multiplier),
                            design.ncol = design.ncol,
                            design.margin = as.integer(design.margin),
                            feasible = feasible,
                            skip.reason = skip.reason,
                            reuse.key = NA_character_,
                            score = NA_real_,
                            elapsed.sec = NA_real_,
                            stringsAsFactors = FALSE
                        )
                    }
                }
            }
        }
    }
    out <- do.call(rbind, rows[seq_len(rr)])
    out$stage.rank <- .coupled.kd.stage.rank(out$stage)
    out$source.rank <- .coupled.kd.source.rank(out$chart.dim.source)
    out$eval.key <- paste(out$support.size, out$degree, out$kernel,
                          format(out$bandwidth.multiplier, digits = 17L),
                          out$chart.dim.clipped, out$feasible,
                          out$skip.reason, sep = "\r")
    out <- out[order(out$support.size, out$degree, out$kernel,
                     out$bandwidth.multiplier, out$chart.dim.clipped,
                     out$stage.rank, out$source.rank,
                     out$chart.dim.raw, na.last = TRUE), , drop = FALSE]
    out <- out[!duplicated(out$eval.key), , drop = FALSE]

    feasible <- out$feasible & is.finite(out$chart.dim.clipped)
    group.cols <- if (identical(reuse.type, "weighted")) {
        c("support.size", "kernel")
    } else {
        "support.size"
    }
    out$reuse.chart.dim.max <- NA_integer_
    if (any(feasible)) {
        split.key <- do.call(
            paste,
            c(out[feasible, group.cols, drop = FALSE], sep = "\r")
        )
        max.by.group <- tapply(out$chart.dim.clipped[feasible], split.key,
                               max, na.rm = TRUE)
        all.key <- do.call(
            paste,
            c(out[, group.cols, drop = FALSE], sep = "\r")
        )
        out$reuse.chart.dim.max[feasible] <- as.integer(max.by.group[all.key[feasible]])
        out$reuse.key[feasible] <- mapply(
            .coupled.kd.reuse.key,
            support.size = out$support.size[feasible],
            kernel = out$kernel[feasible],
            max.chart.dim = out$reuse.chart.dim.max[feasible],
            MoreArgs = list(reuse.type = reuse.type),
            USE.NAMES = FALSE
        )
    }
    out <- out[, c(
        "candidate.id", "stage", "support.size", "chart.dim",
        "chart.dim.source", "chart.dim.raw", "chart.dim.clipped",
        "chart.dim.seed.clipped", "chart.dim.max", "kernel", "degree",
        "bandwidth.multiplier", "design.ncol", "design.margin",
        "feasible", "skip.reason", "reuse.key", "reuse.chart.dim.max",
        "score", "elapsed.sec"
    )]
    rownames(out) <- NULL
    out$candidate.id <- seq_len(nrow(out))
    out
}
