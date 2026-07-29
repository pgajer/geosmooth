# Deprecated G1--G7 compatibility translators.

.deprecated.dgp <- function(replacement = "materialize.synthetic") {
  .Deprecated(replacement, package = "geosmooth")
}

.decorate.legacy.dgp <- function(x, tag, args) {
  geometry.names <- c(
    G1 = "ambient polynomial",
    G2 = "flat embedded subspace",
    G3a = "paraboloid (known curvature)",
    G3b = "sphere cap (constant curvature)",
    G3c = "1-D helix",
    G3d = "torus patch",
    G4 = "stratified 1-D segment + 2-D patch",
    G5 = "clustered / repeated measures",
    G6 = "binary surface",
    G7 = "compositional / structural zeros")
  x$geometry.family <- unname(geometry.names[tag])
  extras <- switch(
    tag,
    G1 = list(D = args$D, degree = args$degree,
              sigma = args$sigma, poly.coef = args$poly.coef),
    G2 = list(d = args$d, D = args$D, sigma = args$sigma,
              frame.seed = x$parameters$resolved.seeds$frame.seed,
              Q = x$parameters$frame.matrix, poly.coef = args$poly.coef),
    G3a = list(R = args$R, kappa = 1 / args$R, rho0 = args$rho0,
               truth = args$truth, sigma = args$sigma),
    G3b = list(R = args$R, rho0 = args$rho0,
               gaussian.curvature = 1 / args$R^2,
               truth = args$truth, sigma = args$sigma),
    G3c = list(c = args$c, sigma = args$sigma,
               truth = "sin(t) [default]"),
    G3d = list(R1 = args$R1, R2 = args$R2,
               u.range = args$u.range, v.range = args$v.range,
               truth = args$truth, sigma = args$sigma),
    G4 = list(fracA = args$fracA,
              nA = x$parameters$sampling$nA,
              nB = x$parameters$sampling$nB,
              eta = args$eta, sigma = args$sigma,
              dim.by.region = c(A = 1L, B = 2L),
              truth = "sin(pi*x1) [default]"),
    G5 = list(K = args$K, m = args$m, sigma.x = args$sigma.x,
              rho = args$rho, sigma = args$sigma,
              tau = x$parameters$response$tau,
              b = x$parameters$response$cluster.effect,
              cluster = x$parameters$sampling$cluster,
              truth = "sin(pi*x1)cos(pi*x2) [default g]"),
    G6 = list(prevalence = args$prevalence,
              alpha = x$parameters$truth$alpha,
              clip = args$clip,
              realized.prevalence = x$parameters$truth$realized.prevalence,
              realized.rate = mean(x$response),
              eta = paste0(args$amplitude, "*sin(pi*x1)")),
    G7 = list(D = args$D, alpha = rep(args$alpha, length.out = args$D),
              zero.fraction = args$zero.fraction,
              zero.parts = args$zero.parts,
              n.zero = sum(x$region == "zero"),
              sigma = args$sigma,
              truth = "sin(pi*p1)+0.5*p2 [default]"))
  x$parameters <- utils::modifyList(x$parameters, extras, keep.null = TRUE)
  x$params <- x$parameters
  x
}

.materialize.g.recipe <- function(tag, args, n, seed) {
  spec <- synthetic.registry.spec(tag, args)
  x <- materialize.synthetic(
    spec, n = n, seed = seed, rng.policy = "legacy")
  .decorate.legacy.dgp(x, tag, args)
}

#' G1 ambient-polynomial compatibility generator
#' @param n,D,degree,sigma,poly.coef,seed Legacy G1 arguments.
#' @return A `synthetic_dataset` with transitional `dgp_dataset` aliases.
#' @export
dgp.g1 <- function(n = 600L, D = 2L, degree = 2L, sigma = 0,
                   poly.coef = NULL, seed = 1L) {
  .deprecated.dgp()
  args <- list(D = D, degree = degree, sigma = sigma, poly.coef = poly.coef)
  .materialize.g.recipe("G1", args, n, seed)
}

#' G2 embedded-flat compatibility generator
#' @param n,d,D,sigma,seed,frame.seed,poly.coef Legacy G2 arguments.
#' @return A canonical synthetic dataset.
#' @export
dgp.g2 <- function(n = 600L, d = 2L, D = 3L, sigma = 0, seed = 1L,
                   frame.seed = NULL, poly.coef = NULL) {
  .deprecated.dgp()
  args <- list(d = d, D = D, sigma = sigma,
               frame.seed = frame.seed, poly.coef = poly.coef)
  .materialize.g.recipe("G2", args, n, seed)
}

#' G3a paraboloid compatibility generator
#' @param n,R,truth,sigma,rho0,seed Legacy G3a arguments.
#' @return A canonical synthetic dataset.
#' @export
dgp.g3a <- function(n = 600L, R = 1, truth = c("smooth", "linear"),
                    sigma = 0.1, rho0 = 1, seed = 1L) {
  .deprecated.dgp()
  truth <- match.arg(truth)
  args <- list(R = R, truth = truth, sigma = sigma, rho0 = rho0)
  .materialize.g.recipe("G3a", args, n, seed)
}

#' G3b sphere-cap compatibility generator
#' @param n,R,rho0,truth,sigma,seed Legacy G3b arguments.
#' @return A canonical synthetic dataset.
#' @export
dgp.g3b <- function(n = 600L, R = 2, rho0 = 1,
                    truth = c("smooth", "linear"),
                    sigma = 0.1, seed = 1L) {
  .deprecated.dgp()
  truth <- match.arg(truth)
  args <- list(R = R, rho0 = rho0, truth = truth, sigma = sigma)
  .materialize.g.recipe("G3b", args, n, seed)
}

#' G3c helix compatibility generator
#' @param n,c,truth.fn,sigma,seed Legacy G3c arguments.
#' @return A canonical synthetic dataset.
#' @export
dgp.g3c <- function(n = 600L, c = 0.2, truth.fn = sin,
                    sigma = 0.1, seed = 1L) {
  .deprecated.dgp()
  if (!missing(truth.fn)) {
    stop("Arbitrary truth.fn closures are no longer materializable; use a ",
         "versioned synthetic.truth.named() evaluator.", call. = FALSE)
  }
  args <- list(pitch = c, sigma = sigma)
  x <- .materialize.g.recipe("G3c", args, n, seed)
  .decorate.legacy.dgp(x, "G3c", list(c = c, sigma = sigma))
}

#' G3d torus-patch compatibility generator
#' @param n,R1,R2,u.range,v.range,truth,sigma,seed Legacy G3d arguments.
#' @return A canonical synthetic dataset.
#' @export
dgp.g3d <- function(
    n = 600L, R1 = 1, R2 = 0.35,
    u.range = c(-pi / 2, pi / 2), v.range = c(-pi / 2, pi / 2),
    truth = c("smooth", "linear"), sigma = 0.1, seed = 1L) {
  .deprecated.dgp()
  truth <- match.arg(truth)
  args <- list(R1 = R1, R2 = R2, u.range = u.range, v.range = v.range,
               truth = truth, sigma = sigma)
  .materialize.g.recipe("G3d", args, n, seed)
}

#' G4 stratified compatibility generator
#' @param n,fracA,eta,truth.fn,sigma,seed Legacy G4 arguments.
#' @return A canonical synthetic dataset.
#' @export
dgp.g4 <- function(
    n = 600L, fracA = 0.5, eta = 0.02,
    truth.fn = function(X) sin(pi * X[, 1]),
    sigma = 0.1, seed = 1L) {
  .deprecated.dgp()
  if (!missing(truth.fn)) {
    stop("Arbitrary truth.fn closures are no longer materializable; use a ",
         "versioned synthetic.truth.named() evaluator.", call. = FALSE)
  }
  args <- list(fracA = fracA, eta = eta, sigma = sigma)
  .materialize.g.recipe("G4", args, n, seed)
}

#' G5 clustered compatibility generator
#' @param K,m,sigma.x,rho,sigma,g,seed Legacy G5 arguments.
#' @return A canonical synthetic dataset.
#' @export
dgp.g5 <- function(
    K = 40L, m = 20L, sigma.x = 0.05, rho = 0.6, sigma = 0.1,
    g = function(x) sin(pi * x[, 1]) * cos(pi * x[, 2]), seed = 1L) {
  .deprecated.dgp()
  if (!missing(g)) {
    stop("Arbitrary g closures are no longer materializable; use a versioned ",
         "synthetic.truth.named() evaluator.", call. = FALSE)
  }
  args <- list(K = K, m = m, sigma.x = sigma.x, rho = rho, sigma = sigma)
  .materialize.g.recipe("G5", args, NULL, seed)
}

#' G6 binary-surface compatibility generator
#' @param n,prevalence,eta.fn,clip,seed Legacy G6 arguments.
#' @return A canonical synthetic dataset.
#' @export
dgp.g6 <- function(
    n = 600L, prevalence = 0.5,
    eta.fn = function(x) 1.5 * sin(pi * x[, 1]),
    clip = c(0.05, 0.95), seed = 1L) {
  .deprecated.dgp()
  if (!missing(eta.fn)) {
    stop("Arbitrary eta.fn closures are no longer materializable; use ",
         "synthetic.truth.logit().", call. = FALSE)
  }
  args <- list(prevalence = prevalence, amplitude = 1.5, clip = clip)
  .materialize.g.recipe("G6", args, n, seed)
}

#' G7 structural-zero compatibility generator
#' @param n,D,alpha,zero.fraction,zero.parts,truth.fn,sigma,seed Legacy G7 arguments.
#' @return A canonical synthetic dataset.
#' @export
dgp.g7 <- function(
    n = 600L, D = 5L, alpha = 1, zero.fraction = 0.5,
    zero.parts = NULL,
    truth.fn = function(X) sin(pi * X[, 1]) + 0.5 * X[, 2],
    sigma = 0.1, seed = 1L) {
  .deprecated.dgp()
  if (!missing(truth.fn)) {
    stop("Arbitrary truth.fn closures are no longer materializable; use a ",
         "versioned synthetic.truth.named() evaluator.", call. = FALSE)
  }
  if (is.null(zero.parts)) zero.parts <- as.integer(D)
  if (!length(zero.parts)) .stop.empty.zero.parts()
  args <- list(D = D, alpha = alpha, zero.fraction = zero.fraction,
               zero.parts = zero.parts, sigma = sigma)
  .materialize.g.recipe("G7", args, n, seed)
}

#' Materialize a maintained G recipe
#' @param gtag G1--G7 tag.
#' @param args Named arguments including optional `n` and `seed`.
#' @return A canonical synthetic dataset.
#' @export
dgp.materialize <- function(gtag, args = list()) {
  .deprecated.dgp("materialize.synthetic")
  defaults <- .synthetic.recipe.defaults()[[gtag]]
  if (is.null(defaults)) stop("Unknown G-tag: ", gtag, call. = FALSE)
  n <- args$n %||% if (gtag == "G5") NULL else 600L
  seed <- args$seed %||% 1L
  args$n <- NULL
  args$seed <- NULL
  if (gtag == "G3c" && !is.null(args$c)) {
    args$pitch <- args$c
    args$c <- NULL
  }
  spec <- synthetic.registry.spec(gtag, args)
  materialize.synthetic(spec, n = n, seed = seed, rng.policy = "legacy")
}

#' SHA-256 of canonical dataset content
#' @param ds A synthetic dataset.
#' @return A lowercase SHA-256 string.
#' @export
dgp.content.sha256 <- function(ds) synthetic.dataset.checksum(ds)

#' Print a legacy DGP dataset
#' @param x A `dgp_dataset`.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @method print dgp_dataset
#' @export
print.dgp_dataset <- function(x, ...) {
  if (inherits(x, "synthetic_dataset")) return(print.synthetic_dataset(x, ...))
  NextMethod()
}
