#!/usr/bin/env Rscript

if (!requireNamespace("pkgload", quietly = TRUE)) {
    stop("Package 'pkgload' is required for this script.", call. = FALSE)
}

pkgload::load_all(".", quiet = TRUE)

date.tag <- "2026-06-04"
out.root <- file.path(
    getwd(),
    "split_handoffs",
    "harlim_second_order_lps_h5_expanded_eval_2026-06-04"
)
table.dir <- file.path(out.root, "tables")
fig.dir <- file.path(out.root, "report_files")
dir.create(table.dir, recursive = TRUE, showWarnings = FALSE)
dir.create(fig.dir, recursive = TRUE, showWarnings = FALSE)

p7.root <- file.path(
    "/Users/pgajer/current_projects/trend_filtering/development/slpl_tf",
    "experiments/p7_prospective_synthetic_suite"
)
geometry.registry.path <- file.path(
    p7.root,
    "config/p7_geometry_registry.csv"
)
truth.registry.path <- file.path(
    p7.root,
    "config/p7_synthetic_truth_registry.csv"
)

support.grid.base <- c(15L, 25L, 35L)
degree.grid <- c(1L, 2L)
kernel.grid <- c("gaussian", "tricube")
cv.folds <- 5L
noise.sd.multiplier <- 0.10
synthetic.n <- 80L
valencia.n <- 120L

read.csv2 <- function(path) {
    utils::read.csv(path, stringsAsFactors = FALSE,
                    na.strings = c("", "NA", "NaN"))
}

write.csv2 <- function(x, path) {
    utils::write.csv(x, path, row.names = FALSE, na = "")
    invisible(path)
}

rmse <- function(x, y) {
    sqrt(mean((as.numeric(x) - as.numeric(y))^2, na.rm = TRUE))
}

scale.unit <- function(x) {
    x <- as.numeric(x)
    x <- x - mean(x, na.rm = TRUE)
    s <- stats::sd(x, na.rm = TRUE)
    if (!is.finite(s) || s <= 0) return(x)
    x / s
}

safe.scale.matrix <- function(X) {
    X <- as.matrix(X)
    mu <- colMeans(X, na.rm = TRUE)
    centered <- sweep(X, 2L, mu, "-")
    s <- apply(centered, 2L, stats::sd, na.rm = TRUE)
    keep <- is.finite(s) & s > 0
    if (!any(keep)) return(centered)
    sweep(centered[, keep, drop = FALSE], 2L, s[keep], "/")
}

lhs.uniform <- function(n, d, seed) {
    set.seed(seed)
    out <- matrix(NA_real_, n, d)
    for (j in seq_len(d)) {
        out[, j] <- (sample(seq_len(n)) - stats::runif(n)) / n
    }
    out
}

make.foldid <- function(n, seed) {
    set.seed(seed)
    sample(rep(seq_len(cv.folds), length.out = n))
}

split.spec <- function(x, sep = "\\|") {
    if (is.null(x) || !length(x) || is.na(x) || !nzchar(x)) {
        return(character(0))
    }
    strsplit(as.character(x), sep)[[1L]]
}

parse.numeric.list <- function(x) {
    as.numeric(split.spec(x))
}

parse.center.matrix <- function(x) {
    rows <- split.spec(x)
    if (!length(rows)) return(matrix(numeric(0), 0L, 0L))
    mat <- do.call(rbind, lapply(rows, function(row) {
        as.numeric(strsplit(row, ":", fixed = TRUE)[[1L]])
    }))
    as.matrix(mat)
}

gaussian.mixture <- function(coords, centers, amplitudes, bandwidths) {
    coords <- as.matrix(coords)
    centers <- as.matrix(centers)
    bandwidths <- as.matrix(bandwidths)
    if (nrow(bandwidths) == 1L && nrow(centers) > 1L) {
        bandwidths <- bandwidths[rep(1L, nrow(centers)), , drop = FALSE]
    }
    out <- rep(0, nrow(coords))
    for (j in seq_len(nrow(centers))) {
        bw <- pmax(bandwidths[j, ], .Machine$double.eps)
        z <- sweep(coords, 2L, centers[j, ], "-")
        out <- out + amplitudes[[j]] *
            exp(-0.5 * rowSums((sweep(z, 2L, bw, "/"))^2))
    }
    out
}

make.geometry <- function(geometry.row, n) {
    seed <- as.integer(geometry.row$random.seed[[1L]])
    id <- geometry.row$geometry.id[[1L]]
    if (grepl("unit_square|paraboloid|saddle|hd_2d", id)) {
        latent <- lhs.uniform(n, 2L, seed)
        colnames(latent) <- c("u", "v")
    } else if (grepl("unit_cube|hd_3d", id)) {
        latent <- lhs.uniform(n, 3L, seed)
        colnames(latent) <- c("u", "v", "w")
    } else {
        stop("Unsupported generated geometry id: ", id, call. = FALSE)
    }

    if (grepl("paraboloid", id)) {
        X <- cbind(latent[, 1L], latent[, 2L],
                   latent[, 1L]^2 + latent[, 2L]^2)
    } else if (grepl("saddle", id)) {
        X <- cbind(latent[, 1L], latent[, 2L],
                   latent[, 1L]^2 - latent[, 2L]^2)
    } else if (grepl("hd_2d", id)) {
        set.seed(seed + 1000L)
        X <- cbind(
            matrix(latent[, 1L], n, 50L),
            matrix(latent[, 2L], n, 50L)
        )
        X <- X + stats::rnorm(n * ncol(X), sd = 0.01)
        X <- safe.scale.matrix(X)
    } else if (grepl("hd_3d", id)) {
        set.seed(seed + 1000L)
        X <- cbind(
            matrix(latent[, 1L], n, 33L),
            matrix(latent[, 2L], n, 33L),
            matrix(latent[, 3L], n, 33L)
        )
        X <- X + stats::rnorm(n * ncol(X), sd = 0.01)
        X <- safe.scale.matrix(X)
    } else {
        X <- latent
    }
    list(X = as.matrix(X), latent = latent)
}

truth.coordinates <- function(geometry, truth.row) {
    domain <- truth.row$coordinate.domain[[1L]]
    if (domain %in% c("latent_uv", "latent_uvw", "latent_x")) {
        return(geometry$latent)
    }
    if (identical(domain, "ambient")) return(geometry$X)
    geometry$latent
}

make.truth <- function(geometry, truth.row) {
    family <- truth.row$truth.family[[1L]]
    coords <- truth.coordinates(geometry, truth.row)
    if (grepl("gaussian_mixture", family)) {
        values <- gaussian.mixture(
            coords = coords,
            centers = parse.center.matrix(truth.row$center.spec[[1L]]),
            amplitudes = parse.numeric.list(truth.row$amplitude.spec[[1L]]),
            bandwidths = parse.center.matrix(truth.row$bandwidth.spec[[1L]])
        )
        return(scale.unit(values))
    }
    stop("Unsupported truth family: ", family, call. = FALSE)
}

latent.truth <- function(latent) {
    latent <- as.matrix(latent)
    d <- ncol(latent)
    if (d == 2L) {
        centers <- matrix(
            c(0.20, 0.30,
              0.60, 0.72,
              0.82, 0.24),
            ncol = 2L,
            byrow = TRUE
        )
        amplitudes <- c(1.00, 0.74, 0.54)
        bandwidths <- matrix(
            c(0.10, 0.16,
              0.14, 0.09,
              0.08, 0.12),
            ncol = 2L,
            byrow = TRUE
        )
        values <- gaussian.mixture(latent, centers, amplitudes, bandwidths)
        values <- values + 0.15 * sin(2 * pi * latent[, 1L]) *
            cos(2 * pi * latent[, 2L])
        return(scale.unit(values))
    }
    centers <- matrix(
        c(0.20, 0.25, 0.35,
          0.60, 0.72, 0.30,
          0.78, 0.30, 0.72,
          0.44, 0.50, 0.84),
        ncol = 3L,
        byrow = TRUE
    )
    amplitudes <- c(1.00, 0.78, 0.60, 0.45)
    bandwidths <- matrix(
        c(0.12, 0.15, 0.10,
          0.14, 0.10, 0.16,
          0.09, 0.13, 0.12,
          0.18, 0.12, 0.10),
        ncol = 3L,
        byrow = TRUE
    )
    values <- gaussian.mixture(latent, centers, amplitudes, bandwidths)
    values <- values + 0.10 * sin(2 * pi * latent[, 1L]) *
        cos(2 * pi * latent[, 2L]) +
        0.08 * sin(2 * pi * latent[, 3L])
    scale.unit(values)
}

embed.random <- function(base, ambient.dim, seed, noise.sd = 0.01) {
    base <- as.matrix(base)
    if (ambient.dim <= ncol(base)) return(base)
    set.seed(seed)
    Q <- qr.Q(qr(matrix(stats::rnorm(ambient.dim * ncol(base)),
                       ambient.dim, ncol(base))))
    out <- base %*% t(Q)
    out + stats::rnorm(nrow(out) * ncol(out), sd = noise.sd)
}

make.custom.geometry <- function(generator, n, seed) {
    dim <- if (grepl("_3d|hypersurface_3d", generator)) 3L else 2L
    latent <- lhs.uniform(n, dim, seed)
    centered <- 2 * latent - 1
    if (grepl("cone_tip|cusp|folded|nearline", generator)) {
        latent[1L, seq_len(min(2L, dim))] <- 0.5
        centered[1L, seq_len(min(2L, dim))] <- 0
    }
    u <- centered[, 1L]
    v <- centered[, 2L]
    if (dim == 3L) w <- centered[, 3L]
    X <- switch(
        generator,
        paraboloid_mild = cbind(u, v, 0.35 * (u^2 + v^2)),
        paraboloid_sharp = cbind(u, v, 1.15 * (u^2 + 0.6 * v^2)),
        anisotropic_bowl = cbind(u, v, 0.9 * u^2 + 0.2 * v^2),
        saddle_cross = cbind(u, v, u * v),
        saddle_quadratic = cbind(u, v, 0.9 * u^2 - 0.45 * v^2),
        monkey_saddle = cbind(u, v, u^3 - 3 * u * v^2),
        corrugated_sheet = cbind(
            u, v, 0.25 * sin(2 * pi * latent[, 1L]) +
                0.15 * cos(2 * pi * latent[, 2L])
        ),
        sphere_patch = {
            theta <- 1.25 * u
            phi <- 0.95 * v
            cbind(cos(phi) * cos(theta),
                  cos(phi) * sin(theta),
                  sin(phi))
        },
        torus_patch = {
            theta <- 1.35 * u
            phi <- 1.15 * v
            R <- 1.2
            r <- 0.35
            cbind((R + r * cos(phi)) * cos(theta),
                  (R + r * cos(phi)) * sin(theta),
                  r * sin(phi))
        },
        swiss_roll = {
            t <- 1.5 * pi * (1 + latent[, 1L])
            cbind(t * cos(t) / 6, v, t * sin(t) / 6)
        },
        helicoid = {
            r <- 0.25 + latent[, 1L]
            theta <- 2 * pi * (latent[, 2L] - 0.5)
            cbind(r * cos(theta), r * sin(theta), theta / pi)
        },
        cone_tip_singular = cbind(u, v, sqrt(u^2 + v^2)),
        cusp_ridge_singular = cbind(u, v, abs(u)^1.5 + 0.20 * v^2),
        folded_sheet_singular = cbind(u, v^2, abs(u) + 0.25 * v),
        nearline_paraboloid_singular = {
            vv <- 0.04 * v + 0.12 * u
            cbind(u, vv, 0.75 * u^2 + 0.35 * vv^2)
        },
        nearline_saddle_singular = {
            vv <- 0.04 * v - 0.10 * u
            cbind(u, vv, 0.75 * u^2 - 0.35 * vv^2)
        },
        curved_hypersurface_3d = cbind(
            u, v, w, 0.45 * (u^2 + v^2 + w^2)
        ),
        saddle_hypersurface_3d = cbind(
            u, v, w, 0.55 * (u^2 + v^2 - w^2)
        ),
        cusp_hypersurface_3d = cbind(
            u, v, w, abs(u)^1.5 + 0.25 * v^2 - 0.20 * w^2
        ),
        highdim_curved_paraboloid_2d = embed.random(
            cbind(u, v, 0.75 * u^2 + 0.35 * v^2),
            ambient.dim = 30L,
            seed = seed + 2000L
        ),
        highdim_curved_saddle_2d = embed.random(
            cbind(u, v, 0.75 * u^2 - 0.35 * v^2),
            ambient.dim = 30L,
            seed = seed + 2100L
        ),
        highdim_curved_hypersurface_3d = embed.random(
            cbind(u, v, w, 0.45 * (u^2 + v^2 + w^2)),
            ambient.dim = 36L,
            seed = seed + 2200L
        ),
        stop("Unknown custom generator: ", generator, call. = FALSE)
    )
    list(X = as.matrix(X), latent = latent)
}

load.linf.asset <- function(name, linf.root) {
    local.path <- file.path(linf.root, "data", paste0(name, ".rda"))
    env <- new.env(parent = emptyenv())
    if (file.exists(local.path)) {
        load(local.path, envir = env)
        return(get(name, envir = env))
    }
    data(list = name, package = "linf", envir = env)
    get(name, envir = env)
}

plain.sample <- function(n.total, n, seed) {
    set.seed(seed)
    sort(sample(seq_len(n.total), n))
}

stratified.sample <- function(n, labels, seed) {
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

choose.truth.centers <- function(X) {
    Z <- safe.scale.matrix(X)
    pc <- stats::prcomp(Z, center = FALSE, scale. = FALSE)
    score <- pc$x[, seq_len(min(2L, ncol(pc$x))), drop = FALSE]
    if (ncol(score) == 1L) score <- cbind(score, 0)
    targets <- rbind(
        c(stats::quantile(score[, 1L], 0.20),
          stats::quantile(score[, 2L], 0.50)),
        c(stats::quantile(score[, 1L], 0.75),
          stats::quantile(score[, 2L], 0.30)),
        c(stats::quantile(score[, 1L], 0.55),
          stats::quantile(score[, 2L], 0.80))
    )
    vapply(seq_len(nrow(targets)), function(i) {
        which.min(rowSums((score - matrix(targets[i, ], nrow(score), 2L,
                                          byrow = TRUE))^2))
    }, integer(1L))
}

valencia.truth <- function(X) {
    Z <- safe.scale.matrix(X)
    centers <- choose.truth.centers(X)
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
    scale.unit(f)
}

make.valencia.case <- function(seed = 1601L) {
    if (!requireNamespace("linf", quietly = TRUE)) return(NULL)
    linf.root <- path.expand("~/current_projects/linf")
    if (dir.exists(linf.root) && file.exists(file.path(linf.root,
                                                       "DESCRIPTION"))) {
        pkgload::load_all(linf.root, quiet = TRUE)
    }
    asset <- tryCatch(
        load.linf.asset("valencia_linf_hypercube_1k", linf.root),
        error = function(e) NULL
    )
    if (is.null(asset) || is.null(asset$rel4)) return(NULL)
    Xfull <- as.matrix(asset$rel4)
    strata <- if (!is.null(asset$meta$dominant_component)) {
        asset$meta$dominant_component
    } else {
        NULL
    }
    n <- min(valencia.n, nrow(Xfull))
    idx <- if (!is.null(strata) && length(strata) == nrow(Xfull)) {
        stratified.sample(n, strata, seed)
    } else {
        plain.sample(nrow(Xfull), n, seed)
    }
    X <- Xfull[idx, , drop = FALSE]
    truth <- valencia.truth(X)
    list(
        case.id = "valencia_rel4_linf_4d",
        dataset.id = "valencia_linf_hypercube_1k_rel4_subset",
        truth.id = "valencia_rel4_pca_gaussian_mixture_h5",
        geometry.family = "valencia_derived_4d",
        source.kind = "valencia_linf_hypercube_1k",
        intrinsic.dimension = NA_integer_,
        X = X,
        truth = truth,
        foldid = make.foldid(nrow(X), seed + 7000L),
        registry.geometry.id = NA_character_,
        registry.truth.id = NA_character_,
        notes = "VALENCIA-derived 4D rel4 composition subset; synthetic PCA-space Gaussian truth"
    )
}

case.specs <- data.frame(
    case.id = c(
        "curved_2d_paraboloid",
        "curved_2d_saddle_registry",
        "highdim_embedded_2d",
        "highdim_embedded_3d"
    ),
    geometry.id = c(
        "p7c_ctrl_2d_paraboloid_n400_seed202",
        "p7c_ctrl_2d_saddle_n400_seed203",
        "p7c_hd_2d_diagonal_embed100_n400_seed402",
        "p7c_hd_3d_diagonal_embed99_n600_seed403"
    ),
    truth.id = c(
        "p7d_paraboloid_latent_three_gaussian_v1",
        "p7d_saddle_latent_three_gaussian_v1",
        "p7d_hd2_latent_three_gaussian_v1",
        "p7d_hd3_latent_four_gaussian_v1"
    ),
    stringsAsFactors = FALSE
)

custom.case.specs <- data.frame(
    case.id = c(
        "paraboloid_mild_2d",
        "paraboloid_sharp_2d",
        "anisotropic_bowl_2d",
        "saddle_cross_2d",
        "saddle_quadratic_2d",
        "monkey_saddle_2d",
        "corrugated_sheet_2d",
        "sphere_patch_2d",
        "torus_patch_2d",
        "swiss_roll_2d",
        "helicoid_2d",
        "cone_tip_singular_2d",
        "cusp_ridge_singular_2d",
        "folded_sheet_singular_2d",
        "nearline_paraboloid_singular_2d",
        "nearline_saddle_singular_2d",
        "curved_hypersurface_3d",
        "saddle_hypersurface_3d",
        "cusp_hypersurface_singular_3d",
        "highdim_curved_paraboloid_2d",
        "highdim_curved_saddle_2d",
        "highdim_curved_hypersurface_3d"
    ),
    generator = c(
        "paraboloid_mild",
        "paraboloid_sharp",
        "anisotropic_bowl",
        "saddle_cross",
        "saddle_quadratic",
        "monkey_saddle",
        "corrugated_sheet",
        "sphere_patch",
        "torus_patch",
        "swiss_roll",
        "helicoid",
        "cone_tip_singular",
        "cusp_ridge_singular",
        "folded_sheet_singular",
        "nearline_paraboloid_singular",
        "nearline_saddle_singular",
        "curved_hypersurface_3d",
        "saddle_hypersurface_3d",
        "cusp_hypersurface_3d",
        "highdim_curved_paraboloid_2d",
        "highdim_curved_saddle_2d",
        "highdim_curved_hypersurface_3d"
    ),
    intrinsic.dimension = c(rep(2L, 16L), rep(3L, 3L), 2L, 2L, 3L),
    geometry.family = c(
        rep("custom_curved_2d", 11L),
        rep("custom_singular_2d", 5L),
        "custom_curved_3d",
        "custom_curved_3d",
        "custom_singular_3d",
        "custom_highdim_curved_2d",
        "custom_highdim_curved_2d",
        "custom_highdim_curved_3d"
    ),
    seed = seq.int(9101L, 9101L + 21L),
    stringsAsFactors = FALSE
)

build.synthetic.case <- function(spec, geometry.registry, truth.registry) {
    geometry.row <- geometry.registry[
        geometry.registry$geometry.id == spec$geometry.id,
        ,
        drop = FALSE
    ]
    truth.row <- truth.registry[
        truth.registry$truth.id == spec$truth.id,
        ,
        drop = FALSE
    ]
    if (nrow(geometry.row) != 1L || nrow(truth.row) != 1L) {
        stop("Missing registry row for case: ", spec$case.id, call. = FALSE)
    }
    n <- min(synthetic.n, as.integer(geometry.row$n[[1L]]))
    geometry <- make.geometry(geometry.row, n)
    truth <- make.truth(geometry, truth.row)
    seed <- as.integer(geometry.row$random.seed[[1L]])
    list(
        case.id = spec$case.id,
        dataset.id = geometry.row$geometry.id[[1L]],
        truth.id = truth.row$truth.id[[1L]],
        geometry.family = geometry.row$geometry.family[[1L]],
        source.kind = geometry.row$source.kind[[1L]],
        intrinsic.dimension = geometry.row$intrinsic.dimension[[1L]],
        X = geometry$X,
        truth = truth,
        foldid = make.foldid(nrow(geometry$X), seed + 7000L),
        registry.geometry.id = geometry.row$geometry.id[[1L]],
        registry.truth.id = truth.row$truth.id[[1L]],
        notes = geometry.row$notes[[1L]]
    )
}

build.custom.case <- function(spec) {
    geometry <- make.custom.geometry(
        generator = spec$generator[[1L]],
        n = synthetic.n,
        seed = spec$seed[[1L]]
    )
    truth <- latent.truth(geometry$latent)
    list(
        case.id = spec$case.id[[1L]],
        dataset.id = paste0("h5_", spec$case.id[[1L]]),
        truth.id = paste0("h5_truth_", spec$case.id[[1L]]),
        geometry.family = spec$geometry.family[[1L]],
        source.kind = "generated_h5_curved_singular",
        intrinsic.dimension = spec$intrinsic.dimension[[1L]],
        X = geometry$X,
        truth = truth,
        foldid = make.foldid(nrow(geometry$X), spec$seed[[1L]] + 7000L),
        registry.geometry.id = NA_character_,
        registry.truth.id = NA_character_,
        notes = paste("Custom H5 curved/singular generator:",
                      spec$generator[[1L]])
    )
}

selected.value <- function(fit, name, default = NA) {
    if (is.null(fit) || is.null(fit$selected) ||
        is.null(fit$selected[[name]])) {
        return(default)
    }
    fit$selected[[name]][[1L]]
}

fallback.reasons.text <- function(summary) {
    reasons <- summary$fallback.reasons
    if (is.null(reasons) || !nrow(reasons)) return("")
    paste(paste0(reasons$fallback.reason, ":", reasons$count),
          collapse = ";")
}

fit.one.method <- function(case, y, method) {
    support.grid <- support.grid.base[support.grid.base <= nrow(case$X)]
    error <- NA_character_
    fit <- NULL
    elapsed <- system.time({
        fit <- tryCatch(
            fit.lps(
                X = case$X,
                y = y,
                foldid = case$foldid,
                support.grid = support.grid,
                degree.grid = degree.grid,
                kernel.grid = kernel.grid,
                coordinate.method = "local.pca",
                chart.dim = "auto",
                local.chart.method = method,
                auto.chart.support.metric = "coordinates",
                auto.chart.selection.metric = "coordinates",
                backend = "R"
            ),
            error = function(e) {
                error <<- conditionMessage(e)
                NULL
            }
        )
    })[["elapsed"]]
    list(fit = fit, elapsed.sec = as.numeric(elapsed), error = error)
}

fit.summary.row <- function(case, method, fit.result, y) {
    fit <- fit.result$fit
    status <- if (is.null(fit)) "error" else "ok"
    diag.summary <- if (!is.null(fit)) {
        fit$local.chart.diagnostics.summary
    } else {
        .klp.local.chart.diagnostics.summary(NULL, method)
    }
    data.frame(
        case.id = case$case.id,
        dataset.id = case$dataset.id,
        truth.id = case$truth.id,
        geometry.family = case$geometry.family,
        source.kind = case$source.kind,
        method = method,
        fit.status = status,
        fit.error = fit.result$error,
        n = nrow(case$X),
        ambient.dimension = ncol(case$X),
        intrinsic.dimension = case$intrinsic.dimension,
        selected.support.size = selected.value(fit, "support.size"),
        selected.degree = selected.value(fit, "degree"),
        selected.kernel = selected.value(fit, "kernel", NA_character_),
        selected.chart.dim = if (is.null(fit)) NA_integer_ else fit$chart.dim,
        cv.rmse.observed = selected.value(fit, "cv.rmse.observed"),
        full.rmse.observed = if (is.null(fit)) {
            NA_real_
        } else {
            rmse(fit$fitted.values, y)
        },
        truth.rmse = if (is.null(fit)) {
            NA_real_
        } else {
            rmse(fit$fitted.values, case$truth)
        },
        runtime.sec = fit.result$elapsed.sec,
        local.chart.method = if (is.null(fit)) method else fit$local.chart.method,
        local.chart.method.effective = if (is.null(fit)) {
            method
        } else {
            fit$local.chart.method.effective
        },
        fallback.count = diag.summary$fallback.count,
        fallback.rate = diag.summary$fallback.rate,
        fallback.reasons = fallback.reasons.text(diag.summary),
        any.pca.fallback.used = diag.summary$any.pca.fallback.used,
        any.structured.failure = diag.summary$any.structured.failure,
        min.design.rank = diag.summary$min.design.rank,
        median.design.rank = diag.summary$median.design.rank,
        max.design.rank = diag.summary$max.design.rank,
        median.design.condition = diag.summary$median.design.condition,
        max.design.condition = diag.summary$max.design.condition,
        stringsAsFactors = FALSE
    )
}

diagnostic.rows <- function(case, fit.result) {
    fit <- fit.result$fit
    if (is.null(fit) || is.null(fit$local.chart.diagnostics) ||
        !nrow(fit$local.chart.diagnostics)) {
        return(data.frame())
    }
    out <- fit$local.chart.diagnostics
    out$case.id <- case$case.id
    out$dataset.id <- case$dataset.id
    out$truth.id <- case$truth.id
    out
}

evaluate.case <- function(case) {
    noise.sd <- noise.sd.multiplier * stats::sd(case$truth)
    if (!is.finite(noise.sd) || noise.sd <= 0) noise.sd <- noise.sd.multiplier
    set.seed(abs(sum(utf8ToInt(case$case.id))) + 20260604L)
    y <- case$truth + stats::rnorm(length(case$truth), sd = noise.sd)
    pca <- fit.one.method(case, y, "pca")
    second <- fit.one.method(case, y, "second.order.svd")
    fit.rows <- rbind(
        fit.summary.row(case, "pca", pca, y),
        fit.summary.row(case, "second.order.svd", second, y)
    )
    diag.rows <- diagnostic.rows(case, second)
    pca.row <- fit.rows[fit.rows$method == "pca", , drop = FALSE]
    second.row <- fit.rows[fit.rows$method == "second.order.svd", ,
                           drop = FALSE]
    pair.row <- data.frame(
        case.id = case$case.id,
        dataset.id = case$dataset.id,
        truth.id = case$truth.id,
        geometry.family = case$geometry.family,
        source.kind = case$source.kind,
        n = nrow(case$X),
        ambient.dimension = ncol(case$X),
        intrinsic.dimension = case$intrinsic.dimension,
        noise.sd = noise.sd,
        pca.truth.rmse = pca.row$truth.rmse,
        second.truth.rmse = second.row$truth.rmse,
        delta.truth.rmse = second.row$truth.rmse - pca.row$truth.rmse,
        pca.observed.rmse = pca.row$full.rmse.observed,
        second.observed.rmse = second.row$full.rmse.observed,
        delta.observed.rmse =
            second.row$full.rmse.observed - pca.row$full.rmse.observed,
        pca.cv.rmse = pca.row$cv.rmse.observed,
        second.cv.rmse = second.row$cv.rmse.observed,
        pca.selected.support.size = pca.row$selected.support.size,
        second.selected.support.size = second.row$selected.support.size,
        pca.selected.degree = pca.row$selected.degree,
        second.selected.degree = second.row$selected.degree,
        pca.selected.kernel = pca.row$selected.kernel,
        second.selected.kernel = second.row$selected.kernel,
        pca.selected.chart.dim = pca.row$selected.chart.dim,
        second.selected.chart.dim = second.row$selected.chart.dim,
        pca.runtime.sec = pca.row$runtime.sec,
        second.runtime.sec = second.row$runtime.sec,
        runtime.ratio.second_over_pca =
            second.row$runtime.sec / pmax(pca.row$runtime.sec,
                                          .Machine$double.eps),
        second.fallback.count = second.row$fallback.count,
        second.fallback.rate = second.row$fallback.rate,
        second.fallback.reasons = second.row$fallback.reasons,
        second.any.pca.fallback.used = second.row$any.pca.fallback.used,
        second.any.structured.failure = second.row$any.structured.failure,
        second.median.design.rank = second.row$median.design.rank,
        second.max.design.rank = second.row$max.design.rank,
        second.median.design.condition = second.row$median.design.condition,
        second.max.design.condition = second.row$max.design.condition,
        pca.fit.status = pca.row$fit.status,
        second.fit.status = second.row$fit.status,
        pca.fit.error = pca.row$fit.error,
        second.fit.error = second.row$fit.error,
        notes = case$notes,
        stringsAsFactors = FALSE
    )
    pair.row$outcome <- ifelse(
        !is.finite(pair.row$delta.truth.rmse),
        "failed",
        ifelse(pair.row$delta.truth.rmse < -1e-10, "second.order.svd",
               ifelse(pair.row$delta.truth.rmse > 1e-10, "pca", "tied"))
    )
    list(pair = pair.row, fits = fit.rows, diagnostics = diag.rows)
}

html.escape <- function(x) {
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x
}

fmt <- function(x, digits = 4L) {
    ifelse(is.finite(x), formatC(x, digits = digits, format = "fg"), "NA")
}

render.table <- function(df, columns, n = nrow(df)) {
    df <- df[seq_len(min(n, nrow(df))), columns, drop = FALSE]
    header <- paste0("<tr>", paste0("<th>", html.escape(names(df)), "</th>",
                                    collapse = ""), "</tr>")
    body <- apply(df, 1L, function(row) {
        paste0("<tr>", paste0("<td>", html.escape(row), "</td>",
                              collapse = ""), "</tr>")
    })
    paste0("<table>", header, paste(body, collapse = "\n"), "</table>")
}

plot.paired.rmse <- function(paired, path) {
    ok <- is.finite(paired$pca.truth.rmse) &
        is.finite(paired$second.truth.rmse)
    df <- paired[ok, , drop = FALSE]
    ord <- order(df$delta.truth.rmse)
    df <- df[ord, , drop = FALSE]
    png(path, width = 1200, height = max(760, 34 * nrow(df) + 220),
        res = 130)
    par(mar = c(4.5, 12, 3, 1))
    y <- seq_len(nrow(df))
    xlim <- range(c(df$pca.truth.rmse, df$second.truth.rmse), na.rm = TRUE)
    plot(NA, xlim = xlim, ylim = c(0.5, nrow(df) + 0.5),
         yaxt = "n", ylab = "", xlab = "Truth RMSE",
         main = "Paired Truth RMSE by Chart Method")
    axis(2, at = y, labels = df$case.id, las = 1, cex.axis = 0.75)
    abline(v = pretty(xlim), col = "gray92", lwd = 0.8)
    segments(df$pca.truth.rmse, y, df$second.truth.rmse, y,
             col = "gray55", lwd = 2)
    points(df$pca.truth.rmse, y, pch = 19, col = "#2b6cb0")
    points(df$second.truth.rmse, y, pch = 19, col = "#b83280")
    legend("bottomright", legend = c("pca", "second.order.svd"),
           pch = 19, col = c("#2b6cb0", "#b83280"), bty = "n")
    dev.off()
}

plot.delta <- function(paired, path) {
    ok <- is.finite(paired$delta.truth.rmse)
    df <- paired[ok, , drop = FALSE]
    ord <- order(df$delta.truth.rmse)
    df <- df[ord, , drop = FALSE]
    png(path, width = 1200, height = max(760, 34 * nrow(df) + 220),
        res = 130)
    par(mar = c(4.5, 12, 3, 1))
    y <- seq_len(nrow(df))
    xlim <- range(c(df$delta.truth.rmse, 0), na.rm = TRUE)
    plot(df$delta.truth.rmse, y, yaxt = "n", ylab = "",
         xlab = "Delta Truth RMSE (second.order.svd - pca)",
         xlim = xlim, pch = 19,
         col = ifelse(df$delta.truth.rmse < 0, "#2f855a", "#c53030"),
         main = "Paired Truth RMSE Delta")
    axis(2, at = y, labels = df$case.id, las = 1, cex.axis = 0.75)
    abline(v = 0, col = "gray40", lty = 2)
    dev.off()
}

plot.runtime <- function(paired, path) {
    ok <- is.finite(paired$runtime.ratio.second_over_pca)
    df <- paired[ok, , drop = FALSE]
    ord <- order(df$runtime.ratio.second_over_pca)
    df <- df[ord, , drop = FALSE]
    png(path, width = 1200, height = max(760, 34 * nrow(df) + 220),
        res = 130)
    par(mar = c(4.5, 12, 3, 1))
    y <- seq_len(nrow(df))
    plot(df$runtime.ratio.second_over_pca, y, yaxt = "n", ylab = "",
         xlab = "Runtime ratio (second.order.svd / pca)",
         log = "x", pch = 19, col = "#805ad5",
         main = "Runtime Ratio")
    axis(2, at = y, labels = df$case.id, las = 1, cex.axis = 0.75)
    abline(v = 1, col = "gray40", lty = 2)
    dev.off()
}

plot.fallbacks <- function(paired, path) {
    png(path, width = 1200, height = max(760, 34 * nrow(paired) + 240),
        res = 130)
    par(mar = c(7, 4, 3, 1))
    barplot(paired$second.fallback.rate,
            names.arg = paired$case.id,
            las = 2,
            cex.names = 0.7,
            col = "#dd6b20",
            ylab = "Fallback rate",
            main = "Second-Order Chart Fallback Rate")
    dev.off()
}

write.report <- function(paired, fit.results, real.case.included,
                         report.path, figure.paths) {
    paired.display <- paired
    paired.display$pca.truth.rmse <- fmt(paired$pca.truth.rmse)
    paired.display$second.truth.rmse <- fmt(paired$second.truth.rmse)
    paired.display$delta.truth.rmse <- fmt(paired$delta.truth.rmse)
    paired.display$runtime.ratio.second_over_pca <-
        fmt(paired$runtime.ratio.second_over_pca)
    paired.display$second.fallback.rate <- fmt(paired$second.fallback.rate)
    counts <- table(paired$outcome)
    counts.text <- paste(paste0(names(counts), ": ", as.integer(counts)),
                         collapse = "; ")
    median.delta <- stats::median(paired$delta.truth.rmse, na.rm = TRUE)
    best.case <- paired$case.id[which.min(paired$delta.truth.rmse)]
    worst.case <- paired$case.id[which.max(paired$delta.truth.rmse)]
    html <- c(
        "<!doctype html>",
        "<html><head><meta charset='utf-8'>",
        "<title>H5 Expanded LPS Chart Comparison</title>",
        "<style>",
        "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;margin:32px;line-height:1.45;color:#1f2933}",
        "h1,h2{color:#111827} table{border-collapse:collapse;font-size:13px} th,td{border:1px solid #d1d5db;padding:5px 7px;text-align:left} th{background:#f3f4f6} img{max-width:100%;height:auto;border:1px solid #e5e7eb} .note{background:#fff7ed;border-left:4px solid #dd6b20;padding:10px 12px}",
        "</style></head><body>",
        "<h1>H5 Expanded dim &gt; 1 LPS Chart Comparison</h1>",
        paste0("<p>Generated ", html.escape(format(Sys.time(),
            "%Y-%m-%d %H:%M:%S %Z", tz = "America/New_York")), ".</p>"),
        "<div class='note'><strong>Scope.</strong> H4 was only a smoke and wiring phase. This revised H5 report excludes flat geometries and uses a curved/singular paired suite comparing ordinary local-PCA LPS with opt-in second-order-local-SVD LPS. It does not change defaults and does not claim statistical significance.</div>",
        "<h2>Summary</h2>",
        paste0("<p>Paired cases: ", nrow(paired), ". Outcomes by truth RMSE delta: ",
               html.escape(counts.text), ".</p>"),
        "<p>Flat datasets are intentionally excluded because they primarily exercise the known second-order fallback/identity behavior rather than curved-chart differences.</p>",
        paste0("<p>Median delta (second.order.svd - pca): ",
               html.escape(fmt(median.delta, 5L)), ". Negative values favor second-order charts. Best case: ",
               html.escape(best.case), ". Worst case: ", html.escape(worst.case),
               ".</p>"),
        paste0("<p>VALENCIA-derived case included: ",
               ifelse(real.case.included, "yes", "no"), ".</p>"),
        "<h2>Truth RMSE Pairing</h2>",
        paste0("<img src='", html.escape(basename(dirname(figure.paths$paired))),
               "/", html.escape(basename(figure.paths$paired)), "' alt='Paired truth RMSE plot'>"),
        "<h2>Truth RMSE Delta</h2>",
        paste0("<img src='", html.escape(basename(dirname(figure.paths$delta))),
               "/", html.escape(basename(figure.paths$delta)), "' alt='Delta truth RMSE plot'>"),
        "<h2>Runtime Ratio</h2>",
        paste0("<img src='", html.escape(basename(dirname(figure.paths$runtime))),
               "/", html.escape(basename(figure.paths$runtime)), "' alt='Runtime ratio plot'>"),
        "<h2>Fallback Diagnostics</h2>",
        paste0("<img src='", html.escape(basename(dirname(figure.paths$fallback))),
               "/", html.escape(basename(figure.paths$fallback)), "' alt='Fallback plot'>"),
        "<p>Second-order fallback rates were recorded from final fitted-chart diagnostics. Ordinary PCA fits report no effective fallback diagnostics.</p>",
        "<h2>Paired Results</h2>",
        render.table(
            paired.display,
            c("case.id", "geometry.family", "n", "ambient.dimension",
              "pca.truth.rmse", "second.truth.rmse", "delta.truth.rmse",
              "outcome", "runtime.ratio.second_over_pca",
              "second.fallback.rate")
        ),
        "<h2>Interpretation</h2>",
        "<p>This revised H5 pass separates implementation readiness from accuracy evidence. The implementation is ready as an opt-in experimental chart method when tests pass. The accuracy evidence is paired across curved and singular cases, so it should guide whether to run a larger study rather than justify changing defaults.</p>",
        "<p>Positive deltas favor ordinary PCA charts; negative deltas favor second-order charts. Mixed results or runtime costs should be interpreted conservatively.</p>",
        "<h2>Artifacts</h2>",
        "<ul>",
        "<li>tables/h5_lps_chart_paired_results.csv</li>",
        "<li>tables/h5_lps_chart_fit_results.csv</li>",
        "<li>tables/h5_lps_chart_second_order_diagnostics.csv</li>",
        "<li>h5_lps_chart_expanded_eval_bundle.rds</li>",
        "</ul>",
        "</body></html>"
    )
    writeLines(html, report.path)
    invisible(report.path)
}

geometry.registry <- read.csv2(geometry.registry.path)
truth.registry <- read.csv2(truth.registry.path)
registry.cases <- lapply(seq_len(nrow(case.specs)), function(i) {
    build.synthetic.case(case.specs[i, , drop = FALSE],
                         geometry.registry,
                         truth.registry)
})
custom.cases <- lapply(seq_len(nrow(custom.case.specs)), function(i) {
    build.custom.case(custom.case.specs[i, , drop = FALSE])
})
valencia.case <- make.valencia.case()
cases <- c(registry.cases, custom.cases)
real.case.included <- !is.null(valencia.case)
if (real.case.included) cases[[length(cases) + 1L]] <- valencia.case
flat.case <- vapply(cases, function(case) {
    grepl("flat|unit_square|unit_cube", case$case.id) ||
        grepl("flat|unit_square|unit_cube", case$geometry.family) ||
        grepl("flat|unit_square|unit_cube", case$dataset.id)
}, logical(1L), USE.NAMES = FALSE)
if (any(flat.case)) {
    stop("H5 revised suite must exclude flat cases: ",
         paste(vapply(cases[flat.case], `[[`, character(1L), "case.id"),
               collapse = ", "),
         call. = FALSE)
}
curved.or.singular <- vapply(cases, function(case) {
    grepl("curved|singular|saddle|paraboloid|valencia",
          case$case.id) ||
        grepl("curved|singular|controlled_2d_curved|controlled_highdim|valencia",
              case$geometry.family)
}, logical(1L), USE.NAMES = FALSE)
if (sum(curved.or.singular) < 20L) {
    stop("H5 revised suite requires at least 20 curved/singular cases.",
         call. = FALSE)
}

rows <- lapply(cases, evaluate.case)
paired <- do.call(rbind, lapply(rows, `[[`, "pair"))
fit.results <- do.call(rbind, lapply(rows, `[[`, "fits"))
diagnostics <- do.call(rbind, lapply(rows, `[[`, "diagnostics"))
if (is.null(diagnostics)) diagnostics <- data.frame()

paired.path <- file.path(table.dir, "h5_lps_chart_paired_results.csv")
fit.path <- file.path(table.dir, "h5_lps_chart_fit_results.csv")
diag.path <- file.path(table.dir, "h5_lps_chart_second_order_diagnostics.csv")
bundle.path <- file.path(out.root, "h5_lps_chart_expanded_eval_bundle.rds")
report.path <- file.path(out.root, "h5_lps_chart_expanded_eval_report.html")

write.csv2(paired, paired.path)
write.csv2(fit.results, fit.path)
write.csv2(diagnostics, diag.path)
saveRDS(
    list(
        paired = paired,
        fit.results = fit.results,
        diagnostics = diagnostics,
        case.specs = case.specs,
        custom.case.specs = custom.case.specs,
        support.grid = support.grid.base,
        degree.grid = degree.grid,
        kernel.grid = kernel.grid,
        cv.folds = cv.folds,
        noise.sd.multiplier = noise.sd.multiplier,
        geometry.registry.path = geometry.registry.path,
        truth.registry.path = truth.registry.path,
        real.case.included = real.case.included,
        flat.cases.excluded = TRUE,
        curved.or.singular.case.count = sum(curved.or.singular)
    ),
    bundle.path
)

figure.paths <- list(
    paired = file.path(fig.dir, "h5_truth_rmse_paired_segments.png"),
    delta = file.path(fig.dir, "h5_delta_truth_rmse.png"),
    runtime = file.path(fig.dir, "h5_runtime_ratio.png"),
    fallback = file.path(fig.dir, "h5_second_order_fallback_rate.png")
)
plot.paired.rmse(paired, figure.paths$paired)
plot.delta(paired, figure.paths$delta)
plot.runtime(paired, figure.paths$runtime)
plot.fallbacks(paired, figure.paths$fallback)
write.report(paired, fit.results, real.case.included, report.path,
             figure.paths)

cat("Wrote H5 output directory:", out.root, "\n")
cat("Paired rows:", nrow(paired), "\n")
cat("VALENCIA-derived case included:", real.case.included, "\n")
cat("Outcome counts:\n")
print(table(paired$outcome))
cat("Median delta truth RMSE:",
    stats::median(paired$delta.truth.rmse, na.rm = TRUE), "\n")
cat("Worst delta truth RMSE:",
    max(paired$delta.truth.rmse, na.rm = TRUE), "\n")
cat("Max second-order fallback rate:",
    max(paired$second.fallback.rate, na.rm = TRUE), "\n")

invisible(paired)
