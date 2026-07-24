#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
arg.value <- function(flag, default = NULL) {
    at <- match(flag, args)
    if (is.na(at)) return(default)
    if (at == length(args)) stop("Missing value after ", flag, call. = FALSE)
    args[[at + 1L]]
}

script.path <- sub(
    "^--file=", "",
    commandArgs(FALSE)[grep("^--file=", commandArgs(FALSE))]
)
repo.root <- normalizePath(
    file.path(dirname(script.path), "../../../.."),
    mustWork = TRUE
)
project.root <- normalizePath(
    arg.value(
        "--w1-project",
        "/Users/pgajer/current_projects/vaginal_community_trajectory_types"
    ),
    mustWork = TRUE
)
output.dir <- normalizePath(
    arg.value(
        "--output-dir",
        file.path(
            repo.root, "dev", "methods", "metric_graph_lowpass", "results",
            "w1_g1_g5_full_vs_200_20260724"
        )
    ),
    mustWork = FALSE
)
dir.create(output.dir, recursive = TRUE, showWarnings = FALSE)

suppressPackageStartupMessages(pkgload::load_all(repo.root, quiet = TRUE))
source(file.path(project.root, "R", "eod_w1a_g1.R"), local = .GlobalEnv)

sha256 <- function(path) unname(tools::sha256sum(path))
atomic.csv <- function(x, path) {
    tmp <- paste0(path, ".tmp-", Sys.getpid())
    utils::write.csv(x, tmp, row.names = FALSE, na = "")
    if (!file.rename(tmp, path)) stop("Could not publish ", path, call. = FALSE)
}
atomic.rds <- function(x, path) {
    tmp <- paste0(path, ".tmp-", Sys.getpid())
    saveRDS(x, tmp, version = 3)
    if (!file.rename(tmp, path)) stop("Could not publish ", path, call. = FALSE)
}
atomic.lines <- function(x, path) {
    tmp <- paste0(path, ".tmp-", Sys.getpid())
    writeLines(x, tmp)
    if (!file.rename(tmp, path)) stop("Could not publish ", path, call. = FALSE)
}

case.spec <- data.frame(
    phase = paste0("G", 1:5),
    result.relative.path = c(
        paste0(
            "analysis_output/eod_w1a_g1_graph_configs_20260723/results/",
            "W0BG1_M01_E03_N1000_R04__graph_heat_symmetric_knn.rds"
        ),
        paste0(
            "analysis_output/eod_w1b_g2_sentinel_v2_20260722/results/",
            "W0CG2_M01_E01_N0500_R01__graph_heat_kernel.rds"
        ),
        paste0(
            "analysis_output/eod_w1c_g3_sentinel_v6_20260723/results/",
            "W0DG3_M01_E01_N1000_R01__graph_heat_kernel.rds"
        ),
        paste0(
            "analysis_output/eod_w1d_g4_sentinel_v9_20260722/results/",
            "W0EG4_HD2_P100_K1_R01__graph_heat_kernel.rds"
        ),
        paste0(
            "analysis_output/eod_w1d_g5_sentinel_v8_report_r1_20260723/results/",
            "W0EG5_SIMPLEX_FACES_K1_R01__graph_heat_kernel.rds"
        )
    ),
    stringsAsFactors = FALSE
)
case.spec$result.path <- file.path(
    project.root, case.spec$result.relative.path
)
if (any(!file.exists(case.spec$result.path))) {
    stop(
        "Missing W1 result: ",
        paste(case.spec$result.path[!file.exists(case.spec$result.path)],
              collapse = ", "),
        call. = FALSE
    )
}

adapt.geometry <- function(bundle, result) {
    phase.id <- result$phase.id
    if (is.null(phase.id) ||
        !phase.id %in% c("W1d-G4", "W1d-G5")) {
        return(bundle)
    }
    index.path <- file.path(
        project.root, "analysis_output", "eod_w0e_g4g5",
        "geometry_asset_index.csv"
    )
    index <- utils::read.csv(index.path, stringsAsFactors = FALSE)
    wanted <- result$geometry.adapter$source.geometry.asset.sha256
    at <- match(wanted, index$geometry.asset.sha256)
    if (is.na(at)) stop("Could not resolve geometry asset ", wanted, call. = FALSE)
    geometry.path <- file.path(
        project.root, "analysis_output", "eod_w0e_g4g5",
        index$geometry.asset.relative.path[[at]]
    )
    if (!identical(sha256(geometry.path), wanted)) {
        stop("Geometry asset checksum mismatch: ", geometry.path, call. = FALSE)
    }
    geometry <- readRDS(geometry.path)
    point.metadata <- bundle$point.table[
        , !grepl("^x[0-9]+$", names(bundle$point.table)), drop = FALSE
    ]
    coordinates <- as.data.frame(geometry$X)
    names(coordinates) <- paste0("x", seq_len(ncol(coordinates)))
    bundle$point.table <- cbind(point.metadata, coordinates)
    bundle$graph.manifest <- geometry$graph.manifest
    bundle$graph.edges <- geometry$graph.edges
    zero <- bundle$graph.edges$edge.length == 0
    if (any(zero)) {
        positive <- bundle$graph.edges$edge.length[
            bundle$graph.edges$edge.length > 0
        ]
        if (!length(positive)) stop("Geometry graph has no positive edge.")
        bundle$graph.edges$edge.length[zero] <- max(
            .Machine$double.eps, min(positive) * 1e-6
        )
    }
    attr(bundle, "geometry.asset.path") <- geometry.path
    bundle
}

parse.eta <- function(parameter.id) {
    out <- suppressWarnings(as.numeric(sub("^.*;eta=", "", parameter.id)))
    if (any(!is.finite(out))) {
        stop("Could not parse eta from parameter.id.", call. = FALSE)
    }
    out
}

normalize.path <- function(path, X, graph) {
    n <- nrow(X)
    vapply(seq_along(path$eta.grid), function(j) {
        geosmooth::normalize.density(
            path$fitted.values[, j],
            X = X,
            method.id = "graph_heat_kernel",
            density.control = list(
                mass.tol = 1e-8,
                neg.tol = 1e-12,
                clip.negative = TRUE,
                renormalize = TRUE
            ),
            adj.list = graph$adj.list,
            return.details = TRUE
        )$rho
    }, numeric(n))
}

density.metrics <- function(estimate, truth, q) {
    estimate <- pmax(as.numeric(estimate), 0)
    truth <- pmax(as.numeric(truth), 0)
    q <- as.numeric(q)
    c(
        tv = 0.5 * sum(q * abs(estimate - truth)),
        rmse = sqrt(mean((estimate - truth)^2)),
        hellinger = sqrt(0.5 * sum(
            q * (sqrt(estimate) - sqrt(truth))^2
        ))
    )
}

candidate.rows <- list()
case.rows <- list()
graph.rows <- list()
selected.rows <- list()
oracle.rows <- list()
provenance.rows <- list()

for (case.index in seq_len(nrow(case.spec))) {
    phase <- case.spec$phase[[case.index]]
    result.path <- case.spec$result.path[[case.index]]
    result <- readRDS(result.path)
    bundle <- readRDS(result$bundle.path)
    bundle <- adapt.geometry(bundle, result)
    point <- bundle$point.table
    X <- as.matrix(
        point[, grep("^x[0-9]+$", names(point)), drop = FALSE]
    )
    n <- nrow(X)
    selected.id <- if (phase == "G1") {
        result$selected.candidate.id
    } else {
        result$brier.selected.candidate.id
    }
    selected.row <- result$candidate.results[
        result$candidate.results$candidate.id == selected.id, , drop = FALSE
    ]
    if (nrow(selected.row) != 1L) {
        stop("Selected candidate is not unique for ", phase, call. = FALSE)
    }
    all.candidate <- result$candidate.results
    all.candidate$eta <- parse.eta(all.candidate$parameter.id)
    all.candidate <- all.candidate[
        order(all.candidate$graph.id, all.candidate$eta), , drop = FALSE
    ]
    graph.ids <- unique(all.candidate$graph.id)
    retained <- min(200L, n)
    mass <- as.numeric(point$y) / sum(point$y)
    saved <- result$candidate.point.estimates
    q <- as.numeric(point$q)
    truth <- as.numeric(point$rho.truth)
    phase.candidate.rows <- list()
    phase.graph.rows <- list()
    for (graph.index in seq_along(graph.ids)) {
        graph.id <- graph.ids[[graph.index]]
        candidate <- all.candidate[
            all.candidate$graph.id == graph.id, , drop = FALSE
        ]
        graph <- eod_w1a_graph(bundle, graph.id)
        graph.k <- suppressWarnings(as.integer(sub(
            "^symmetric_knn_k0*", "", graph.id
        )))
        conductance.k <- if (phase == "G1") 5L else graph.k
        if (is.na(conductance.k)) {
            stop("Could not resolve conductance.local.k for ", graph.id)
        }

        full.seconds <- system.time({
            full.basis <- geosmooth::metric.graph.lowpass.basis(
                graph$adj.list,
                graph$weight.list,
                conductance.rule = "self.tuned.gaussian",
                conductance.local.k = conductance.k,
                laplacian.type = "unnormalized",
                n.eigenpairs = n,
                eigen.solver = "dense",
                dense.eigen.threshold = max(200L, n)
            )
        })[["elapsed"]]
        truncated.seconds <- system.time({
            truncated.basis <- geosmooth::metric.graph.lowpass.basis(
                graph$adj.list,
                graph$weight.list,
                conductance.rule = "self.tuned.gaussian",
                conductance.local.k = conductance.k,
                laplacian.type = "unnormalized",
                n.eigenpairs = retained,
                eigen.solver = if (retained < n) "sparse" else "dense",
                dense.eigen.threshold = max(200L, n),
                dense.fallback = "never"
            )
        })[["elapsed"]]
        full.path <- geosmooth::apply.metric.graph.lowpass.path(
            full.basis,
            mass,
            candidate$eta,
            filter.type = "heat_kernel",
            unresolved.action = "error"
        )
        truncated.path <- geosmooth::apply.metric.graph.lowpass.path(
            truncated.basis,
            mass,
            candidate$eta,
            filter.type = "heat_kernel",
            truncation.tol = 1e-4,
            unresolved.action = "allow"
        )
        full.rho <- normalize.path(full.path, X, graph)
        truncated.rho <- normalize.path(truncated.path, X, graph)

        saved.max <- numeric(nrow(candidate))
        for (j in seq_len(nrow(candidate))) {
            observed <- saved[
                saved$candidate.id == candidate$candidate.id[[j]],
                , drop = FALSE
            ]
            observed <- observed[
                match(point$point.id, observed$point.id), , drop = FALSE
            ]
            if (nrow(observed) != n || anyNA(observed$rho.hat)) {
                stop("Saved W1 path is incomplete for ", phase, call. = FALSE)
            }
            saved.max[[j]] <- max(abs(full.rho[, j] - observed$rho.hat))
        }

        graph.candidate.rows <- vector("list", nrow(candidate))
        for (j in seq_len(nrow(candidate))) {
            raw.diff <- full.path$fitted.values[, j] -
                truncated.path$fitted.values[, j]
            rho.diff <- density.metrics(truncated.rho[, j], full.rho[, j], q)
            full.truth <- density.metrics(full.rho[, j], truth, q)
            truncated.truth <- density.metrics(truncated.rho[, j], truth, q)
            graph.candidate.rows[[j]] <- data.frame(
                phase = phase,
                dataset.id = result$dataset.id,
                graph.id = graph.id,
                graph.k = graph.k,
                candidate.id = candidate$candidate.id[[j]],
                eta = candidate$eta[[j]],
                selected.by.w1 = candidate$candidate.id[[j]] == selected.id,
                spectrally.resolved.at.1e4 =
                    truncated.path$resolution$spectrally.resolved[[j]],
                retained.cutoff.weight =
                    truncated.path$resolution$retained.cutoff.weight[[j]],
                w1.saved.max.abs.error = saved.max[[j]],
                raw.rmse = sqrt(mean(raw.diff^2)),
                raw.max.abs = max(abs(raw.diff)),
                density.tv = rho.diff[["tv"]],
                density.rmse = rho.diff[["rmse"]],
                density.hellinger = rho.diff[["hellinger"]],
                full.truth.tv = full.truth[["tv"]],
                truncated.truth.tv = truncated.truth[["tv"]],
                full.truth.rmse = full.truth[["rmse"]],
                truncated.truth.rmse = truncated.truth[["rmse"]],
                full.truth.hellinger = full.truth[["hellinger"]],
                truncated.truth.hellinger = truncated.truth[["hellinger"]],
                stringsAsFactors = FALSE
            )
        }
        graph.candidate <- do.call(rbind, graph.candidate.rows)
        phase.candidate.rows[[graph.index]] <- graph.candidate
        phase.graph.rows[[graph.index]] <- data.frame(
            phase = phase,
            dataset.id = result$dataset.id,
            graph.id = graph.id,
            graph.k = graph.k,
            n.edges = sum(lengths(graph$adj.list)) / 2,
            n.candidates = nrow(candidate),
            full.backend = full.basis$spectral$backend,
            truncated.backend = truncated.basis$spectral$backend,
            full.basis.elapsed.sec = unname(full.seconds),
            truncated.basis.elapsed.sec = unname(truncated.seconds),
            max.w1.saved.max.abs.error = max(saved.max),
            max.raw.rmse = max(graph.candidate$raw.rmse),
            max.raw.max.abs = max(graph.candidate$raw.max.abs),
            max.density.tv = max(graph.candidate$density.tv),
            max.density.rmse = max(graph.candidate$density.rmse),
            max.density.hellinger =
                max(graph.candidate$density.hellinger),
            unresolved.candidates.at.1e4 =
                sum(!graph.candidate$spectrally.resolved.at.1e4),
            stringsAsFactors = FALSE
        )
    }
    phase.candidate <- do.call(rbind, phase.candidate.rows)
    phase.graph <- do.call(rbind, phase.graph.rows)
    candidate.rows[[case.index]] <- phase.candidate
    graph.rows[[case.index]] <- phase.graph
    selected.rows[[case.index]] <- phase.candidate[
        phase.candidate$selected.by.w1, , drop = FALSE
    ]
    for (measure in c("tv", "rmse", "hellinger")) {
        full.name <- paste0("full.truth.", measure)
        truncated.name <- paste0("truncated.truth.", measure)
        full.best <- which.min(phase.candidate[[full.name]])
        truncated.best <- which.min(phase.candidate[[truncated.name]])
        oracle.rows[[length(oracle.rows) + 1L]] <- data.frame(
            phase = phase,
            dataset.id = result$dataset.id,
            measure = measure,
            full.oracle.candidate.id =
                phase.candidate$candidate.id[[full.best]],
            truncated.oracle.candidate.id =
                phase.candidate$candidate.id[[truncated.best]],
            oracle.candidate.agreement = full.best == truncated.best,
            full.oracle.eta = phase.candidate$eta[[full.best]],
            truncated.oracle.eta = phase.candidate$eta[[truncated.best]],
            full.oracle.graph.id = phase.candidate$graph.id[[full.best]],
            truncated.oracle.graph.id =
                phase.candidate$graph.id[[truncated.best]],
            full.oracle.value = phase.candidate[[full.name]][[full.best]],
            truncated.oracle.value =
                phase.candidate[[truncated.name]][[truncated.best]],
            stringsAsFactors = FALSE
        )
    }
    case.rows[[case.index]] <- data.frame(
        phase = phase,
        dataset.id = result$dataset.id,
        n = n,
        n.graphs = length(graph.ids),
        n.candidates = nrow(phase.candidate),
        retained.eigenpairs = retained,
        full.backends = paste(unique(phase.graph$full.backend), collapse = ";"),
        truncated.backends =
            paste(unique(phase.graph$truncated.backend), collapse = ";"),
        full.basis.elapsed.sec = sum(phase.graph$full.basis.elapsed.sec),
        truncated.basis.elapsed.sec =
            sum(phase.graph$truncated.basis.elapsed.sec),
        max.w1.saved.max.abs.error =
            max(phase.candidate$w1.saved.max.abs.error),
        max.raw.rmse = max(phase.candidate$raw.rmse),
        max.raw.max.abs = max(phase.candidate$raw.max.abs),
        max.density.tv = max(phase.candidate$density.tv),
        max.density.rmse = max(phase.candidate$density.rmse),
        max.density.hellinger = max(phase.candidate$density.hellinger),
        unresolved.candidates.at.1e4 =
            sum(!phase.candidate$spectrally.resolved.at.1e4),
        stringsAsFactors = FALSE
    )
    provenance.rows[[case.index]] <- data.frame(
        phase = phase,
        result.path = normalizePath(result.path),
        result.sha256 = sha256(result.path),
        bundle.path = normalizePath(result$bundle.path),
        bundle.sha256 = sha256(result$bundle.path),
        geometry.asset.path = if (is.null(attr(
            bundle,
            "geometry.asset.path"
        ))) {
            NA_character_
        } else {
            attr(bundle, "geometry.asset.path")
        },
        stringsAsFactors = FALSE
    )
    message(
        "Completed ", phase, ": ", result$dataset.id, " across ",
        length(graph.ids), " graphs"
    )
}

candidate.table <- do.call(rbind, candidate.rows)
case.table <- do.call(rbind, case.rows)
graph.table <- do.call(rbind, graph.rows)
selected.table <- do.call(rbind, selected.rows)
oracle.table <- do.call(rbind, oracle.rows)
provenance.table <- do.call(rbind, provenance.rows)
study.summary <- data.frame(
    quantity = c(
        "phases",
        "graphs",
        "candidates",
        "maximum_full_api_vs_saved_w1_absolute_error",
        "maximum_selected_density_tv_full_vs_200",
        "maximum_selected_density_rmse_full_vs_200",
        "maximum_selected_density_hellinger_full_vs_200",
        "oracle_candidate_agreements",
        "oracle_candidate_comparisons",
        "candidates_spectrally_unresolved_at_1e-4"
    ),
    value = c(
        length(unique(candidate.table$phase)),
        nrow(graph.table),
        nrow(candidate.table),
        max(candidate.table$w1.saved.max.abs.error),
        max(selected.table$density.tv),
        max(selected.table$density.rmse),
        max(selected.table$density.hellinger),
        sum(oracle.table$oracle.candidate.agreement),
        nrow(oracle.table),
        sum(!candidate.table$spectrally.resolved.at.1e4)
    ),
    stringsAsFactors = FALSE
)

atomic.csv(candidate.table, file.path(output.dir, "candidate_comparison.csv"))
atomic.csv(case.table, file.path(output.dir, "case_summary.csv"))
atomic.csv(graph.table, file.path(output.dir, "graph_summary.csv"))
atomic.csv(selected.table, file.path(output.dir, "w1_selected_comparison.csv"))
atomic.csv(oracle.table, file.path(output.dir, "oracle_selection_comparison.csv"))
atomic.csv(provenance.table, file.path(output.dir, "source_provenance.csv"))
atomic.csv(study.summary, file.path(output.dir, "study_summary.csv"))
atomic.rds(
    list(
        case.spec = case.spec,
        candidate.comparison = candidate.table,
        case.summary = case.table,
        graph.summary = graph.table,
        selected.comparison = selected.table,
        oracle.selection = oracle.table,
        provenance = provenance.table,
        study.summary = study.summary
    ),
    file.path(output.dir, "comparison_results.rds")
)
atomic.lines(
    capture.output(utils::sessionInfo()),
    file.path(output.dir, "sessionInfo.txt")
)
source.paths <- c(
    file.path(repo.root, "R", "metric_graph_lowpass.R"),
    file.path(repo.root, "tests", "testthat", "test-metric-graph-lowpass.R"),
    normalizePath(script.path)
)
atomic.csv(
    data.frame(
        path = source.paths,
        sha256 = vapply(source.paths, sha256, character(1)),
        stringsAsFactors = FALSE
    ),
    file.path(output.dir, "source_checksums.csv")
)
atomic.lines(
    c(
        paste("repository:", repo.root),
        paste("git_head:", system2(
            "git", c("-C", repo.root, "rev-parse", "HEAD"),
            stdout = TRUE
        )),
        "git_status:",
        system2(
            "git", c("-C", repo.root, "status", "--short"),
            stdout = TRUE
        )
    ),
    file.path(output.dir, "git_provenance.txt")
)

cat("\nCase summary\n")
print(case.table, row.names = FALSE)
cat("\nW1-selected candidate comparison\n")
print(
    selected.table[
        , c(
            "phase", "dataset.id", "graph.id", "eta",
            "spectrally.resolved.at.1e4", "raw.rmse", "raw.max.abs",
            "density.tv", "density.rmse", "density.hellinger"
        )
    ],
    row.names = FALSE
)
cat("\nArtifacts:", output.dir, "\n")
