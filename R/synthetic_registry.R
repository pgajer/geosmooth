# Maintained synthetic recipe and frozen-instance registries.

.synthetic.poly2.plan <- c(
  b0 = 0.5, b1 = 1.0, b2 = -0.7,
  b11 = 0.4, b12 = 0.3, b22 = -0.6)

.synthetic.recipe.defaults <- function() {
  list(
    G1 = list(D = 2L, degree = 2L, sigma = 0, poly.coef = NULL),
    G2 = list(d = 2L, D = 3L, sigma = 0,
              frame.seed = NULL, poly.coef = NULL),
    G3a = list(R = 1, truth = "smooth", sigma = 0.1, rho0 = 1),
    G3b = list(R = 2, rho0 = 1, truth = "smooth", sigma = 0.1),
    G3c = list(pitch = 0.2, sigma = 0.1),
    G3d = list(
      R1 = 1, R2 = 0.35,
      u.range = c(-pi / 2, pi / 2),
      v.range = c(-pi / 2, pi / 2),
      truth = "smooth", sigma = 0.1),
    G4 = list(fracA = 0.5, eta = 0.02, sigma = 0.1),
    G5 = list(K = 40L, m = 20L, sigma.x = 0.05,
              rho = 0.6, sigma = 0.1),
    G6 = list(prevalence = 0.5, amplitude = 1.5,
              clip = c(0.05, 0.95)),
    G7 = list(D = 5L, alpha = 1, zero.fraction = 0.5,
              zero.parts = NULL, sigma = 0.1))
}

.synthetic.recipe.spec <- function(recipe.id, args) {
  compatibility <- list(
    recipe = recipe.id,
    seed.policy = "geosmooth.g1.g7.v1")
  if (recipe.id == "G1") {
    D <- .synthetic.scalar.integer(args$D, "D", 1L)
    coefficients <- args$poly.coef
    if (is.null(coefficients)) {
      if (D != 2L) {
        stop("G1 D > 2 requires poly.coef.", call. = FALSE)
      }
      coefficients <- .synthetic.poly2.plan
    }
    return(synthetic.spec(
      synthetic.quadform(D, D, forms = list(), frame = "canonical"),
      synthetic.sampling.uniform.box(-1, 1, order = "draw"),
      synthetic.truth.polynomial(coefficients, "latent"),
      synthetic.response.gaussian(args$sigma),
      recipe.id = "g1.ambient.polynomial.v1", registry.tag = "G1",
      compatibility = compatibility, metadata = args))
  }
  if (recipe.id == "G2") {
    d <- .synthetic.scalar.integer(args$d, "d", 1L)
    D <- .synthetic.scalar.integer(args$D, "D", d + 1L)
    coefficients <- args$poly.coef
    if (is.null(coefficients)) {
      if (d != 2L) stop("G2 d != 2 requires poly.coef.", call. = FALSE)
      coefficients <- .synthetic.poly2.plan
    }
    compatibility$frame.seed <- args$frame.seed
    return(synthetic.spec(
      synthetic.quadform(
        d, D, forms = list(), frame = "random.orthonormal",
        frame.algorithm = "legacy.base.qr.gaussian.v1"),
      synthetic.sampling.uniform.box(-1, 1, order = "draw"),
      synthetic.truth.polynomial(coefficients, "latent"),
      synthetic.response.gaussian(args$sigma),
      recipe.id = "g2.flat.embedded.v1", registry.tag = "G2",
      compatibility = compatibility, metadata = args))
  }
  truth.2d <- function(kind) {
    if (identical(kind, "linear")) {
      synthetic.truth.named("intrinsic.linear.first.v1")
    } else {
      synthetic.truth.named("intrinsic.smooth2.v1")
    }
  }
  if (recipe.id == "G3a") {
    R <- .synthetic.scalar.double(args$R, "R", 0, strict = TRUE)
    return(synthetic.spec(
      synthetic.quadform(
        2L, 3L, forms = list(diag(1 / (2 * R), 2L)),
        frame = "canonical"),
      synthetic.sampling.uniform.disk(args$rho0),
      truth.2d(args$truth),
      synthetic.response.gaussian(args$sigma),
      recipe.id = "g3a.paraboloid.v1", registry.tag = "G3a",
      compatibility = compatibility, metadata = args))
  }
  if (recipe.id == "G3b") {
    return(synthetic.spec(
      synthetic.sphere.cap(
        radius = args$R, footprint.radius = args$rho0),
      synthetic.sampling.uniform.disk(args$rho0),
      truth.2d(args$truth),
      synthetic.response.gaussian(args$sigma),
      recipe.id = "g3b.sphere.cap.v1", registry.tag = "G3b",
      compatibility = compatibility, metadata = args))
  }
  if (recipe.id == "G3c") {
    return(synthetic.spec(
      synthetic.helix(pitch = args$pitch),
      synthetic.sampling.uniform.interval(0, 2 * pi),
      synthetic.truth.named("helix.sin.v1"),
      synthetic.response.gaussian(args$sigma),
      recipe.id = "g3c.helix.v1", registry.tag = "G3c",
      compatibility = compatibility, metadata = args))
  }
  if (recipe.id == "G3d") {
    return(synthetic.spec(
      synthetic.torus.patch(
        major.radius = args$R1, minor.radius = args$R2,
        u.range = args$u.range, v.range = args$v.range),
      synthetic.sampling.uniform.rectangle(
        c(args$u.range[1], args$v.range[1]),
        c(args$u.range[2], args$v.range[2])),
      truth.2d(args$truth),
      synthetic.response.gaussian(args$sigma),
      recipe.id = "g3d.torus.patch.v1", registry.tag = "G3d",
      compatibility = compatibility, metadata = args))
  }
  if (recipe.id == "G4") {
    return(synthetic.spec(
      .synthetic.g4.segment.rectangle(args$eta),
      synthetic.sampling.stratified(
        args$fracA, "legacy.g4.stratum.sequential.v1"),
      synthetic.truth.named("g4.ridge.v1"),
      synthetic.response.gaussian(args$sigma),
      recipe.id = "g4.stratified.v1", registry.tag = "G4",
      compatibility = compatibility, metadata = args))
  }
  if (recipe.id == "G5") {
    return(synthetic.spec(
      synthetic.quadform(2L, 2L, forms = list(), frame = "canonical"),
      synthetic.sampling.clustered(
        args$K, args$m, within.sd = args$sigma.x),
      synthetic.truth.named("g5.smooth.v1"),
      synthetic.response.clustered.gaussian(args$sigma, args$rho),
      recipe.id = "g5.clustered.v1", registry.tag = "G5",
      compatibility = compatibility, metadata = args))
  }
  if (recipe.id == "G6") {
    return(synthetic.spec(
      synthetic.quadform(2L, 2L, forms = list(), frame = "canonical"),
      synthetic.sampling.uniform.box(-1, 1, order = "draw"),
      synthetic.truth.logit(
        amplitude = args$amplitude,
        target.prevalence = args$prevalence, clip = args$clip),
      synthetic.response.bernoulli(),
      recipe.id = "g6.binary.surface.v1", registry.tag = "G6",
      compatibility = compatibility, metadata = args))
  }
  if (recipe.id == "G7") {
    D <- .synthetic.scalar.integer(args$D, "D", 2L)
    zero.parts <- if (is.null(args$zero.parts)) D else args$zero.parts
    return(synthetic.spec(
      synthetic.simplex(D),
      synthetic.sampling.dirichlet.zeros(
        args$alpha, args$zero.fraction, zero.parts,
        zero.row.policy = "first"),
      synthetic.truth.named("g7.smooth.v1"),
      synthetic.response.gaussian(args$sigma),
      recipe.id = "g7.simplex.zeros.v1", registry.tag = "G7",
      compatibility = compatibility, metadata = args))
  }
  stop("Unknown synthetic recipe ID: ", recipe.id, call. = FALSE)
}

#' List maintained synthetic recipe IDs
#' @return Character recipe IDs.
#' @export
synthetic.registry.ids <- function() names(.synthetic.recipe.defaults())

#' Resolve a maintained synthetic recipe
#'
#' @param recipe.id One of `synthetic.registry.ids()`.
#' @param parameters Optional named parameter overrides.
#' @return A validated `synthetic_spec`.
#' @export
synthetic.registry.spec <- function(recipe.id, parameters = list()) {
  recipe.id <- .synthetic.scalar.character(recipe.id, "recipe.id")
  defaults <- .synthetic.recipe.defaults()[[recipe.id]]
  if (is.null(defaults)) {
    stop("Unknown synthetic recipe ID: ", recipe.id, call. = FALSE)
  }
  if (!is.list(parameters) || is.null(names(parameters)) && length(parameters)) {
    stop("parameters must be a named list.", call. = FALSE)
  }
  unknown <- setdiff(names(parameters), names(defaults))
  if (length(unknown)) {
    stop("Unknown parameters for ", recipe.id, ": ",
         paste(unknown, collapse = ", "), call. = FALSE)
  }
  args <- utils::modifyList(defaults, parameters, keep.null = TRUE)
  .synthetic.recipe.spec(recipe.id, args)
}

.synthetic.instance.path <- function() {
  dev <- file.path("inst", "synthetic_registry", "instances.csv")
  if (file.exists(dev)) return(dev)
  system.file("synthetic_registry", "instances.csv", package = "geosmooth")
}

#' Materialize a frozen synthetic instance
#' @param instance.id Frozen instance ID.
#' @param validate Whether to validate and checksum the result.
#' @return A `synthetic_dataset` whose `dataset.id` is `instance.id`.
#' @export
materialize.synthetic.instance <- function(instance.id, validate = TRUE) {
  instance.id <- .synthetic.scalar.character(instance.id, "instance.id")
  path <- .synthetic.instance.path()
  if (!nzchar(path) || !file.exists(path)) {
    stop("Synthetic instance registry is not installed.", call. = FALSE)
  }
  registry <- utils::read.csv(path, stringsAsFactors = FALSE)
  row <- registry[registry$instance.id == instance.id, , drop = FALSE]
  if (nrow(row) != 1L) {
    stop("Unknown or duplicated synthetic instance ID: ", instance.id,
         call. = FALSE)
  }
  spec <- synthetic.registry.spec(row$recipe.id)
  object <- materialize.synthetic(
    spec, n = row$n, seed = row$seed, rng.policy = row$rng.policy,
    validate = FALSE)
  object$dataset.id <- instance.id
  attr(object, "frozen.instance") <- TRUE
  if (validate) {
    validate.synthetic.dataset(object)
    checksum <- synthetic.dataset.checksum(object)
    if (!identical(checksum, row$content.sha256)) {
      stop("Frozen instance checksum mismatch for ", instance.id,
           ": expected ", row$content.sha256, ", obtained ", checksum,
           call. = FALSE)
    }
  }
  object
}
