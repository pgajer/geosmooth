# Helpers used during the gflow-to-geosmooth split.

`%||%` <- function(a, b) if (is.null(a)) b else a

.geosmooth.ge1.missing.native <- function(feature, phase = "GE2") {
    stop(
        feature, " is not available in geosmooth GE1. ",
        "It is scheduled for ", phase, ".",
        call. = FALSE
    )
}

.geosmooth.gflow.bridge <- function(name) {
    if (!requireNamespace("gflow", quietly = TRUE)) {
        stop(
            "This graph-geodesic support path temporarily requires the ",
            "'gflow' package during the geosmooth split.",
            call. = FALSE
        )
    }
    get(name, envir = asNamespace("gflow"), inherits = FALSE)
}

.validate.metric.graph.lowpass.graph <- function(adj.list, weight.list) {
    .geosmooth.gflow.bridge(".validate.metric.graph.lowpass.graph")(
        adj.list, weight.list
    )
}

.graph.geodesic.fields <- function(graph, stage = "final") {
    .geosmooth.gflow.bridge(".graph.geodesic.fields")(graph, stage = stage)
}

.validate.graph.geodesic.payload <- function(adj.list, weight.list, fields) {
    .geosmooth.gflow.bridge(".validate.graph.geodesic.payload")(
        adj.list, weight.list, fields
    )
}

shortest.path <- function(graph, edge.lengths, vertices) {
    .geosmooth.gflow.bridge("shortest.path")(graph, edge.lengths, vertices)
}

.pttf.geometry.edge.table <- function(adj.list, weight.list) {
    .geosmooth.gflow.bridge(".pttf.geometry.edge.table")(adj.list, weight.list)
}

.pttf.geometry.all.source.distances <- function(adj, weights) {
    .geosmooth.gflow.bridge(".pttf.geometry.all.source.distances")(adj, weights)
}

.exact.knn.index <- function(X, k) {
    n <- nrow(X)
    out <- matrix(NA_integer_, nrow = n, ncol = k)
    for (i in seq_len(n)) {
        d <- rowSums((t(t(X) - X[i, ]))^2)
        d[[i]] <- Inf
        out[i, ] <- order(d, seq_len(n))[seq_len(k)]
    }
    out
}
