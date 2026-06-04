#' Compute Low-Pass Filter of a Function Over a Graph
#'
#' Computes the low-pass filter of a function over a graph using the graph
#' Fourier transform (GFT). The filter is applied by summing the contributions
#' of the eigenvectors starting from a specified index, effectively filtering out
#' high-frequency components.
#'
#' @param init.ev Integer scalar giving the 1-based index of the first
#'   eigenvector to include in the low-pass reconstruction.
#' @param evectors Numeric matrix of graph Laplacian eigenvectors, with one
#'   eigenvector per column.
#' @param y.gft Numeric matrix or vector of GFT coefficients. The first column
#'   is used when a matrix is supplied.
#'
#' @return Numeric vector of filtered function values over graph vertices.
#'
#' @export
graph.low.pass.filter <- function(init.ev, evectors, y.gft) {
    if (!is.numeric(init.ev) || length(init.ev) != 1L || init.ev < 1) {
        stop("'init.ev' must be a positive integer")
    }
    init.ev <- as.integer(init.ev)

    if (!is.matrix(evectors) && !is.numeric(evectors)) {
        stop("'evectors' must be a numeric matrix")
    }

    if (!is.matrix(y.gft) && !is.numeric(y.gft)) {
        stop("'y.gft' must be a numeric matrix")
    }

    if (!is.matrix(evectors)) {
        evectors <- as.matrix(evectors)
    }

    if (!is.matrix(y.gft)) {
        y.gft <- as.matrix(y.gft)
    }

    nev <- ncol(evectors)

    if (init.ev > nev) {
        stop("'init.ev' cannot exceed the number of eigenvectors")
    }

    if (nrow(y.gft) < nev) {
        stop("'y.gft' must have at least as many rows as there are eigenvectors")
    }

    if (ncol(y.gft) < 1L) {
        stop("'y.gft' must have at least one column")
    }

    low.pass.y <- numeric(nrow(evectors))

    for (k in init.ev:nev) {
        low.pass.y <- low.pass.y + y.gft[k, 1L] * as.numeric(evectors[, k])
    }

    low.pass.y
}
