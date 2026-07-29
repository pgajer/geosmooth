# Maintained synthetic recipe and frozen-instance registries.

.synthetic.registry.asset <- function(file) {
  dev <- file.path("inst", "synthetic_registry", file)
  if (file.exists(dev)) return(dev)
  system.file("synthetic_registry", file, package = "geosmooth")
}

.synthetic.registry.row <- function(file, key, value) {
  path <- .synthetic.registry.asset(file)
  if (!nzchar(path) || !file.exists(path)) {
    stop("Synthetic registry table is unavailable: ", file, call. = FALSE)
  }
  table <- utils::read.csv(
    path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!key %in% names(table)) {
    stop("Synthetic registry table ", file, " lacks key ", key, ".",
         call. = FALSE)
  }
  row <- table[table[[key]] == value, , drop = FALSE]
  if (nrow(row) != 1L) {
    stop(
      "Synthetic registry key must resolve exactly once: ",
      file, "$", key, " = ", value, call. = FALSE)
  }
  row
}

.synthetic.raw.to.hex <- function(value) {
  paste(sprintf("%02x", as.integer(value)), collapse = "")
}

.synthetic.hex.to.raw <- function(value) {
  value <- .synthetic.scalar.character(value, "serialized registry payload")
  if (nchar(value) %% 2L != 0L ||
      grepl("[^0-9a-f]", value, perl = TRUE)) {
    stop("Serialized registry payload is not lowercase hexadecimal.",
         call. = FALSE)
  }
  pairs <- substring(
    value, seq.int(1L, nchar(value), by = 2L),
    seq.int(2L, nchar(value), by = 2L))
  as.raw(strtoi(pairs, base = 16L))
}

.synthetic.registry.payload.hex <- function(value) {
  .synthetic.raw.to.hex(
    serialize(value, NULL, ascii = FALSE, xdr = TRUE, version = 3))
}

.synthetic.registry.payload.value <- function(value) {
  unserialize(.synthetic.hex.to.raw(value))
}

.synthetic.registry.component <- function(component.id, expected.kind) {
  file <- paste0(
    switch(
      expected.kind,
      geometry = "geometries", sampling = "samplings",
      truth = "truths", response = "responses"),
    ".csv")
  row <- .synthetic.registry.row(file, "component.id", component.id)
  if (!identical(row$kind, expected.kind) ||
      !identical(row$payload.serialization, "R-xdr-v3")) {
    stop("Registry component kind or serialization is inconsistent for ",
         component.id, ".", call. = FALSE)
  }
  component <- .synthetic.registry.payload.value(row$component.payload.hex)
  if (!.is.synthetic.component(component, expected.kind) ||
      !identical(component$family, row$family) ||
      !identical(component$version, as.integer(row$version)) ||
      !identical(.synthetic.sha256(component), row$component.sha256)) {
    stop("Registry component payload failed identity validation for ",
         component.id, ".", call. = FALSE)
  }
  component
}

.synthetic.registry.resolve <- function(recipe.id) {
  row <- .synthetic.registry.row("recipes.csv", "recipe.id", recipe.id)
  if (!identical(row$status, "active") ||
      !identical(as.integer(row$version), 1L) ||
      !identical(row$payload.serialization, "R-xdr-v3")) {
    stop("Registry recipe status, version, or serialization is unsupported.",
         call. = FALSE)
  }
  spec <- synthetic.spec(
    geometry = .synthetic.registry.component(row$geometry.id, "geometry"),
    sampling = .synthetic.registry.component(row$sampling.id, "sampling"),
    truth = .synthetic.registry.component(row$truth.id, "truth"),
    response = .synthetic.registry.component(row$response.id, "response"),
    recipe.id = if (is.na(row$spec.recipe.id) ||
                       !nzchar(row$spec.recipe.id)) NULL else row$spec.recipe.id,
    registry.tag = if (is.na(row$registry.tag) ||
                         !nzchar(row$registry.tag)) NULL else row$registry.tag,
    compatibility = .synthetic.registry.payload.value(
      row$compatibility.payload.hex),
    metadata = .synthetic.registry.payload.value(row$metadata.payload.hex))
  if (!identical(spec$specification.sha256, row$specification.sha256)) {
    stop("Synthetic recipe registry hash mismatch for ", recipe.id, ".",
         call. = FALSE)
  }
  spec
}

.synthetic.environment.fingerprint <- function(rng.policy = "legacy") {
  soft <- extSoftVersion()
  compiler.command <- tryCatch(
    trimws(system2(
      file.path(R.home("bin"), "R"),
      c("CMD", "config", "CXX17"),
      stdout = TRUE, stderr = FALSE))[1L],
    error = function(e) "")
  compiler.version <- if (nzchar(compiler.command)) {
    tryCatch(
      trimws(system2(
        compiler.command, "--version",
        stdout = TRUE, stderr = FALSE))[1L],
      error = function(e) "")
  } else {
    ""
  }
  compiler <- paste(
    c(compiler.command, compiler.version)[
      nzchar(c(compiler.command, compiler.version))],
    collapse = " | ")
  if (!nzchar(compiler)) {
    compiler <- "unavailable"
  }
  lapack <- paste0(La_library(), ";version=", La_version())
  dependencies <- c("dgraphs", "digest", "MASS", "Matrix")
  dependency.versions <- paste(
    paste0(
      dependencies, "=",
      vapply(dependencies, function(package) {
        tryCatch(
          as.character(utils::packageVersion(package)),
          error = function(e) "unavailable")
      }, character(1))),
    collapse = ";")
  list(
    r.version = R.version.string,
    platform = R.version$platform,
    architecture = R.version$arch,
    compiler = compiler,
    operating.system = paste(
      Sys.info()[c("sysname", "release", "version")], collapse = " | "),
    endianness = .Platform$endian,
    rng.kind = if (rng.policy == "legacy") {
      "Mersenne-Twister/Inversion/Rejection"
    } else {
      "L'Ecuyer-CMRG/Inversion/Rejection"
    },
    blas = unname(soft["BLAS"]),
    lapack = lapack,
    math.runtime = paste0(
      "long.double=", capabilities("long.double"),
      ";sizeof.longdouble=", .Machine$sizeof.longdouble),
    registry.version = 1L,
    evaluator.version = 1L,
    dependency.versions = dependency.versions,
    scientific.abs.tolerance = 1e-12,
    scientific.rel.tolerance = 1e-10
  )
}

.synthetic.checksum.scope.matches <- function(row) {
  current <- .synthetic.environment.fingerprint(row$rng.policy)
  fields <- names(current)
  all(vapply(fields, function(field) {
    expected <- row[[field]]
    actual <- current[[field]]
    if (is.numeric(actual)) {
      identical(as.numeric(expected), as.numeric(actual))
    } else {
      identical(as.character(expected), as.character(actual))
    }
  }, logical(1)))
}

.synthetic.registry.fixture.path <- function(relative.path) {
  relative.path <- .synthetic.scalar.character(
    relative.path, "fixture.path")
  dev <- file.path(relative.path)
  if (file.exists(dev)) return(dev)
  installed.relative <- sub("^inst/", "", relative.path)
  system.file(installed.relative, package = "geosmooth")
}

.synthetic.numeric.fields <- function(x) {
  as.double(strsplit(x, ";", fixed = TRUE)[[1L]])
}

.synthetic.gaussian.mixture.catalog <- function() {
  path <- .synthetic.registry.asset("gaussian_mixture_1d_shapes.csv")
  if (!nzchar(path) || !file.exists(path)) {
    stop("The one-dimensional shape registry is unavailable.", call. = FALSE)
  }
  utils::read.csv(path, stringsAsFactors = FALSE)
}

.synthetic.gaussian.variant.catalog <- function() {
  path <- .synthetic.registry.asset("gaussian_mixture_1d_variants.csv")
  if (!nzchar(path) || !file.exists(path)) {
    stop("The one-dimensional variant registry is unavailable.",
         call. = FALSE)
  }
  utils::read.csv(path, stringsAsFactors = FALSE)
}

.synthetic.ssrhe.recipe.ids <- function() {
  one.d <- as.vector(outer(
    sprintf("S%02d", 1:16), paste0("V", 1:3), paste, sep = "."))
  flat <- paste0("ssrhe.flat.d", 2:4, ".v1")
  curvature <- c(35L, 85L, 125L, 150L, 200L)
  quad <- unlist(lapply(2:4, function(d) {
    unlist(lapply(seq_len(d), function(k) {
      sprintf(
        "ssrhe.quadform.d%d.k%d.c%03d.v1", d, k, curvature)
    }), use.names = FALSE)
  }), use.names = FALSE)
  c(one.d, flat, quad)
}

.synthetic.one.d.recipe.spec <- function(recipe.id) {
  pieces <- strsplit(recipe.id, ".", fixed = TRUE)[[1L]]
  shapes <- .synthetic.gaussian.mixture.catalog()
  variants <- .synthetic.gaussian.variant.catalog()
  shape <- shapes[shapes$shape.id == pieces[1L], , drop = FALSE]
  variant <- variants[variants$variant.id == pieces[2L], , drop = FALSE]
  if (nrow(shape) != 1L || nrow(variant) != 1L) {
    stop("Unknown one-dimensional SSRHE recipe: ", recipe.id,
         call. = FALSE)
  }
  sampling <- switch(
    variant$variant.id,
    V1 = synthetic.sampling.uniform.interval(0, 1, order = "ascending"),
    V2 = synthetic.sampling.truncated.normal(
      mean = 0.5, sd = 0.2, lower = 0, upper = 1,
      order = "ascending", algorithm = "inverse.cdf.v1"),
    V3 = synthetic.sampling.gapped.uniform(
      intervals = rbind(c(0.02, 0.42), c(0.58, 0.98)),
      allocation = "fixed.proportion",
      probabilities = c(0.42, 0.58),
      rounding = "floor.first.remainder.last",
      order = "ascending",
      algorithm = "sequential.interval.runif.v1"))
  response <- switch(
    variant$variant.id,
    V1 = synthetic.response.gaussian(0.08),
    V2 = synthetic.response.heteroskedastic.gaussian(0.045, 0.14),
    V3 = synthetic.response.laplace.outlier(
      laplace.scale = 0.055, outlier.fraction = 0.04,
      outlier.sd = 0.45, minimum.outliers = 1L,
      count.rounding = "round",
      laplace.algorithm = "uniform.inverse.v1"))
  synthetic.spec(
    synthetic.quadform(1L, 1L, frame = "canonical"),
    sampling,
    synthetic.truth.gaussian.mixture(
      centers = matrix(.synthetic.numeric.fields(shape$means), ncol = 1L),
      scales = .synthetic.numeric.fields(shape$sds),
      weights = .synthetic.numeric.fields(shape$weights),
      normalize = "sample.max"),
    response,
    recipe.id = recipe.id,
    registry.tag = paste0(pieces[1L], "_", pieces[2L]),
    compatibility = list(
      seed.policy = "ssrhe.1d.v1",
      source = "ssrhe_order3_l1_validation_helpers.R"),
    metadata = list(
      shape.id = shape$shape.id,
      shape.name = shape$shape.name,
      variant.id = variant$variant.id,
      variant.name = variant$variant.name))
}

.synthetic.ssrhe.surface.recipe.spec <- function(recipe.id) {
  is.flat <- grepl("^ssrhe\\.flat\\.", recipe.id)
  if (is.flat) {
    match <- regexec("^ssrhe\\.flat\\.d([234])\\.v1$", recipe.id)
    pieces <- regmatches(recipe.id, match)[[1L]]
    if (!length(pieces)) return(NULL)
    d <- as.integer(pieces[2L])
    forms <- list()
    ambient.dim <- d
    metadata <- list(family = "flat", intrinsic.dim = d)
    seed.policy <- "ssrhe.flat.v1"
  } else {
    match <- regexec(
      "^ssrhe\\.quadform\\.d([234])\\.k([1-4])\\.c([0-9]{3})\\.v1$",
      recipe.id)
    pieces <- regmatches(recipe.id, match)[[1L]]
    if (!length(pieces)) return(NULL)
    d <- as.integer(pieces[2L])
    index.k <- as.integer(pieces[3L])
    curvature <- as.integer(pieces[4L]) / 100
    if (index.k > d ||
        !as.integer(pieces[4L]) %in% c(35L, 85L, 125L, 150L, 200L)) {
      return(NULL)
    }
    coefficient.base <- switch(
      as.character(d),
      "2" = c(1, 1),
      "3" = c(1, 1, 1.5),
      "4" = c(1, 1, 2, 4))
    signs <- c(rep(1, index.k), rep(-1, d - index.k))
    coefficients <- curvature * coefficient.base
    forms <- list(diag(signs * coefficients, d))
    ambient.dim <- d + 1L
    metadata <- list(
      family = "quadform", intrinsic.dim = d,
      index.k = index.k, curvature = curvature,
      coefficients = coefficients)
    seed.policy <- "ssrhe.quadform.v1"
  }
  synthetic.spec(
    synthetic.quadform(
      d, ambient.dim, forms = forms, frame = "canonical"),
    synthetic.sampling.uniform.box(-1, 1, order = "draw"),
    synthetic.truth.named("ssrhe.shared.smooth.v1"),
    synthetic.response.gaussian(0.08),
    recipe.id = recipe.id,
    registry.tag = recipe.id,
    compatibility = list(
      seed.policy = seed.policy,
      source = "ssrhe_order3_l1_validation_helpers.R"),
    metadata = metadata)
}

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
synthetic.registry.ids <- function() {
  c(names(.synthetic.recipe.defaults()), .synthetic.ssrhe.recipe.ids())
}

# Build registry rows without consulting generated ledgers. This function is
# private to registry regeneration and parameterized G-family compatibility.
.synthetic.registry.spec.from.code <- function(
    recipe.id, parameters = list()) {
  recipe.id <- .synthetic.scalar.character(recipe.id, "recipe.id")
  if (grepl("^S[0-9]{2}\\.V[1-3]$", recipe.id)) {
    if (length(parameters)) {
      stop("One-dimensional registry recipes do not accept overrides.",
           call. = FALSE)
    }
    return(.synthetic.one.d.recipe.spec(recipe.id))
  }
  if (grepl("^ssrhe\\.(flat|quadform)\\.", recipe.id)) {
    if (length(parameters)) {
      stop("SSRHE surface registry recipes do not accept overrides.",
           call. = FALSE)
    }
    spec <- .synthetic.ssrhe.surface.recipe.spec(recipe.id)
    if (is.null(spec)) {
      stop("Unknown synthetic recipe ID: ", recipe.id, call. = FALSE)
    }
    return(spec)
  }
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
  spec <- .synthetic.recipe.spec(recipe.id, args)
  spec
}

#' Resolve a maintained synthetic recipe
#'
#' Default recipes are reconstructed from normalized component foreign keys.
#' Parameter overrides are accepted only for the legacy G-family compatibility
#' surface and remain content-bound, non-frozen specifications.
#'
#' @param recipe.id One of `synthetic.registry.ids()`.
#' @param parameters Optional named parameter overrides.
#' @return A validated `synthetic_spec`.
#' @export
synthetic.registry.spec <- function(recipe.id, parameters = list()) {
  recipe.id <- .synthetic.scalar.character(recipe.id, "recipe.id")
  if (!is.list(parameters) || is.null(names(parameters)) && length(parameters)) {
    stop("parameters must be a named list.", call. = FALSE)
  }
  if (!length(parameters)) {
    return(.synthetic.registry.resolve(recipe.id))
  }
  if (!recipe.id %in% names(.synthetic.recipe.defaults())) {
    stop("Registry parameter overrides are supported only for G1--G7.",
         call. = FALSE)
  }
  .synthetic.registry.spec.from.code(recipe.id, parameters)
}

#' Resolve the legacy seed for an SSRHE registry recipe
#'
#' @param recipe.id A one-dimensional, flat, or quadform SSRHE recipe ID.
#' @param replicate Positive replicate number.
#' @param n Sample size. Required for flat and quadform recipes.
#' @param base.seed One-dimensional suite base seed.
#' @return A validated integer seed.
#' @export
synthetic.registry.seed <- function(
    recipe.id, replicate = 1L, n = NULL, base.seed = 273001L) {
  recipe.id <- .synthetic.scalar.character(recipe.id, "recipe.id")
  replicate <- .synthetic.scalar.integer(replicate, "replicate", 1L)
  if (grepl("^S[0-9]{2}\\.V[1-3]$", recipe.id)) {
    pieces <- strsplit(recipe.id, ".", fixed = TRUE)[[1L]]
    shape <- as.integer(sub("^S", "", pieces[1L]))
    variant <- as.integer(sub("^V", "", pieces[2L]))
    return(.validate.synthetic.seed(
      as.double(base.seed) + shape * 1000 + variant * 100 + replicate))
  }
  n <- .synthetic.scalar.integer(n, "n", 1L)
  spec <- .synthetic.ssrhe.surface.recipe.spec(recipe.id)
  if (is.null(spec)) {
    stop("recipe.id is not an SSRHE registry recipe.", call. = FALSE)
  }
  metadata <- spec$metadata
  if (metadata$family == "flat") {
    seed <- 283000 + 1000 * metadata$intrinsic.dim + 10 * n + replicate
  } else {
    seed <- 291000 + 1000 * metadata$intrinsic.dim +
      100 * metadata$index.k + round(100 * metadata$curvature) +
      10 * n + replicate
  }
  .validate.synthetic.seed(seed)
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
  row <- .synthetic.registry.row("instances.csv", "instance.id", instance.id)
  checksum.row <- .synthetic.registry.row(
    "checksums.csv", "checksum.id", row$checksum.id)
  if (!identical(checksum.row$instance.id, instance.id) ||
      !identical(checksum.row$content.sha256, row$content.sha256)) {
    stop("Frozen instance checksum foreign key is inconsistent.",
         call. = FALSE)
  }
  fixture.path <- .synthetic.registry.fixture.path(row$fixture.path)
  if (!nzchar(fixture.path) || !file.exists(fixture.path)) {
    stop("Frozen instance fixture is unavailable: ", row$fixture.path,
         call. = FALSE)
  }
  spec <- synthetic.registry.spec(row$recipe.id)
  object <- materialize.synthetic(
    spec, n = row$n, seed = row$seed, rng.policy = row$rng.policy,
    validate = FALSE)
  object$dataset.id <- instance.id
  attr(object, "frozen.instance.id") <- instance.id
  if (validate) {
    validate.synthetic.dataset(object)
    checksum <- synthetic.dataset.checksum(object)
    if (.synthetic.checksum.scope.matches(checksum.row)) {
      if (!identical(checksum, row$content.sha256)) {
        stop("Frozen instance checksum mismatch for ", instance.id,
             ": expected ", row$content.sha256, ", obtained ", checksum,
             call. = FALSE)
      }
      attr(object, "verification.scope") <- "exact-environment"
    } else {
      fixture <- readRDS(fixture.path)
      comparison <- compare.synthetic.dataset(
        object, fixture,
        tolerance = c(
          checksum.row$scientific.abs.tolerance,
          checksum.row$scientific.rel.tolerance))
      if (!comparison$equal) {
        stop(
          "Frozen instance failed cross-environment scientific parity: ",
          paste(comparison$mismatches, collapse = ", "), call. = FALSE)
      }
      attr(object, "verification.scope") <- "scientific-parity"
    }
  }
  object
}
