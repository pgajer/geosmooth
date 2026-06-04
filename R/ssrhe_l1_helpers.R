# Private SSRHE L1 helper subset used by LPL-TF and SLPLiFT in GE1.
# Extracted from gflow/R/ssrhe_hessian_energy.R; the public SSRHE API moves in GE4.

.validate.ssrhe.positive.integer <- function (x, name) 
{
    if (length(x) != 1L || is.na(x) || !is.finite(x) || x < 1 || abs(x - round(x)) > 
        .Machine$double.eps^0.5) {
        stop(sprintf("%s must be a positive integer scalar.", name), call. = FALSE)
    }
    as.integer(round(x))
}

.validate.ssrhe.numeric.scalar <- function (x, name) 
{
    if (length(x) != 1L || is.na(x) || !is.finite(x)) {
        stop(sprintf("%s must be a finite numeric scalar.", name), call. = FALSE)
    }
    as.double(x)
}

.prepare.ssrhe.response.matrix <- function (y, n, name) 
{
    is.matrix.input <- is.matrix(y) || inherits(y, "Matrix") || (is.data.frame(y) && 
        ncol(y) > 1L)
    if (is.matrix.input) {
        Y <- if (inherits(y, "Matrix")) 
            as.matrix(y)
        else as.matrix(y)
        if (nrow(Y) != n) 
            stop(sprintf("nrow(%s) must be %d.", name, n), call. = FALSE)
        col.names <- colnames(Y)
    }
    else {
        if (length(y) != n) 
            stop(sprintf("%s must have length %d.", name, n), call. = FALSE)
        Y <- matrix(y, ncol = 1L)
        col.names <- NULL
    }
    storage.mode(Y) <- "double"
    if (any(is.infinite(Y))) {
        stop(sprintf("%s cannot contain infinite values.", name), call. = FALSE)
    }
    observed <- is.finite(Y)
    list(Y = Y, observed = observed, col.names = col.names)
}

.prepare.ssrhe.weight.matrix <- function (weights, y.info, n) 
{
    p <- ncol(y.info$Y)
    if (is.null(weights)) {
        W <- matrix(1, nrow = n, ncol = p)
    }
    else if (is.matrix(weights) || inherits(weights, "Matrix") || is.data.frame(weights)) {
        W <- if (inherits(weights, "Matrix")) 
            as.matrix(weights)
        else as.matrix(weights)
        if (!identical(dim(W), dim(y.info$Y))) {
            stop("weights matrix must have the same dimensions as y.", call. = FALSE)
        }
    }
    else {
        if (length(weights) != n) 
            stop("weights vector must have length nrow(X).", call. = FALSE)
        W <- matrix(as.double(weights), nrow = n, ncol = p)
    }
    storage.mode(W) <- "double"
    if (any(!is.finite(W)) || any(W < 0)) {
        stop("weights must be finite and nonnegative.", call. = FALSE)
    }
    W[!y.info$observed] <- 0
    W
}

.validate.ssrhe.nonnegative.scalar <- function (x, name) 
{
    if (length(x) != 1L || is.na(x) || !is.finite(x) || x < 0) {
        stop(sprintf("%s must be a finite nonnegative numeric scalar.", name), call. = FALSE)
    }
    as.double(x)
}

.validate.ssrhe.lambda.grid <- function (x, name) 
{
    if (!is.numeric(x) || !length(x) || any(is.na(x)) || any(!is.finite(x)) || any(x < 
        0)) {
        stop(sprintf("%s must be a nonempty finite nonnegative numeric vector.", 
            name), call. = FALSE)
    }
    sort(unique(as.double(x)))
}

.prepare.ssrhe.cv.folds <- function (observed, nfolds, fold.id) 
{
    n <- length(observed)
    if (is.null(fold.id)) {
        nfolds <- .validate.ssrhe.positive.integer(nfolds, "nfolds")
        observed.idx <- which(observed)
        if (length(observed.idx) < 2L) {
            stop("At least two observed positive-weight labels are required for CV.", 
                call. = FALSE)
        }
        nfolds <- min(nfolds, length(observed.idx))
        out <- integer(n)
        out[observed.idx] <- rep(seq_len(nfolds), length.out = length(observed.idx))
    }
    else {
        if (length(fold.id) != n) {
            stop("fold.id must have length nrow(X).", call. = FALSE)
        }
        out <- as.integer(fold.id)
        out[is.na(out) | out < 1L | !observed] <- 0L
    }
    folds <- sort(unique(out[out > 0L]))
    if (length(folds) < 2L) {
        stop("At least two nonempty validation folds are required.", call. = FALSE)
    }
    for (ff in folds) {
        n.validation <- sum(out == ff)
        n.training <- sum(observed & out != ff)
        if (n.validation < 1L || n.training < 1L) {
            stop("Each validation fold must leave at least one training label.", 
                call. = FALSE)
        }
    }
    out
}

.ssrhe.hessian.l1.penalty.matrix <- function (A, row.scaling = c("none", "l2")) 
{
    row.scaling <- match.arg(row.scaling)
    A.sparse <- methods::as(A, "dgCMatrix")
    row.scale <- rep(1, nrow(A.sparse))
    if (identical(row.scaling, "l2")) {
        row.norm <- sqrt(Matrix::rowSums(A.sparse^2))
        nz <- is.finite(row.norm) & row.norm > 0
        row.scale[nz] <- 1/row.norm[nz]
        A.sparse <- Matrix::Diagonal(x = row.scale) %*% A.sparse
        A.sparse <- methods::as(A.sparse, "dgCMatrix")
    }
    use.svd <- nrow(A) >= ncol(A)
    list(D = if (use.svd) as.matrix(A.sparse) else A.sparse, D.sparse = A.sparse, 
        svd = use.svd, representation = if (use.svd) "dense" else "sparse", row.scaling = row.scaling, 
        row.scale = row.scale)
}

.ssrhe.hessian.l1.diagnostics <- function (A, D.info) 
{
    A.sparse <- methods::as(A, "dgCMatrix")
    scaled <- D.info$D.sparse
    row.norm <- sqrt(Matrix::rowSums(A.sparse^2))
    scaled.row.norm <- sqrt(Matrix::rowSums(scaled^2))
    list(nrow = nrow(A.sparse), ncol = ncol(A.sparse), nnzero = Matrix::nnzero(A.sparse), 
        density = Matrix::nnzero(A.sparse)/(nrow(A.sparse) * ncol(A.sparse)), row.norm = list(min = suppressWarnings(min(row.norm, 
            na.rm = TRUE)), median = stats::median(row.norm), max = suppressWarnings(max(row.norm, 
            na.rm = TRUE)), zero = sum(!is.finite(row.norm) | row.norm == 0)), scaled.row.norm = list(min = suppressWarnings(min(scaled.row.norm, 
            na.rm = TRUE)), median = stats::median(scaled.row.norm), max = suppressWarnings(max(scaled.row.norm, 
            na.rm = TRUE)), zero = sum(!is.finite(scaled.row.norm) | scaled.row.norm == 
            0)), row.scaling = D.info$row.scaling, representation = D.info$representation, 
        svd = D.info$svd)
}

.ssrhe.hessian.l1.coef.matrix <- function (path, lambda.grid, n) 
{
    beta <- tryCatch(as.matrix(stats::coef(path, lambda = lambda.grid)$beta), error = function(e) NULL)
    if (is.null(beta) || !identical(dim(beta), c(as.integer(n), length(lambda.grid)))) {
        beta <- vapply(lambda.grid, function(lambda) {
            tryCatch(as.vector(stats::coef(path, lambda = lambda)$beta), error = function(e) rep(NA_real_, 
                n))
        }, numeric(n))
    }
    beta
}

.validate.ssrhe.hessian.l1.lambda.grid <- function (lambda.grid, lambda.selection) 
{
    if (is.null(lambda.grid)) {
        if (identical(lambda.selection, "fixed")) {
            stop("lambda.grid is required when lambda.selection = 'fixed'.", call. = FALSE)
        }
        return(NULL)
    }
    lambda.grid <- .validate.ssrhe.lambda.grid(lambda.grid, "lambda.grid")
    if (identical(lambda.selection, "fixed") && length(lambda.grid) != 1L) {
        stop("lambda.selection = 'fixed' requires exactly one lambda value.", call. = FALSE)
    }
    lambda.grid
}

.validate.ssrhe.hessian.l1.solver.args <- function (n.lambda, nfolds, fold.id, observed, maxsteps, minlam, approx, rtol, btol, 
    eps, solver = c("genlasso", "admm", "auto"), row.scaling = c("none", "l2"), admm.rho = 1, 
    admm.maxiter = 2000L, admm.abstol = 1e-04, admm.reltol = 0.001, verbose) 
{
    n.lambda <- .validate.ssrhe.positive.integer(n.lambda, "n.lambda")
    nfolds <- .validate.ssrhe.positive.integer(nfolds, "nfolds")
    maxsteps <- .validate.ssrhe.positive.integer(maxsteps, "maxsteps")
    solver <- match.arg(solver)
    row.scaling <- match.arg(row.scaling)
    minlam <- .validate.ssrhe.nonnegative.scalar(minlam, "minlam")
    rtol <- .validate.ssrhe.nonnegative.scalar(rtol, "rtol")
    btol <- .validate.ssrhe.nonnegative.scalar(btol, "btol")
    eps <- .validate.ssrhe.nonnegative.scalar(eps, "eps")
    admm.rho <- .validate.ssrhe.numeric.scalar(admm.rho, "admm.rho")
    if (!is.finite(admm.rho) || admm.rho <= 0) {
        stop("admm.rho must be a finite positive numeric scalar.", call. = FALSE)
    }
    admm.maxiter <- .validate.ssrhe.positive.integer(admm.maxiter, "admm.maxiter")
    admm.abstol <- .validate.ssrhe.nonnegative.scalar(admm.abstol, "admm.abstol")
    admm.reltol <- .validate.ssrhe.nonnegative.scalar(admm.reltol, "admm.reltol")
    if (!is.null(fold.id)) {
        fold.id <- .prepare.ssrhe.cv.folds(observed, nfolds, fold.id)
    }
    list(n.lambda = n.lambda, nfolds = nfolds, fold.id = fold.id, maxsteps = maxsteps, 
        minlam = minlam, approx = isTRUE(approx), rtol = rtol, btol = btol, eps = eps, 
        solver = solver, row.scaling = row.scaling, admm.rho = admm.rho, admm.maxiter = admm.maxiter, 
        admm.abstol = admm.abstol, admm.reltol = admm.reltol, verbose = isTRUE(verbose))
}

