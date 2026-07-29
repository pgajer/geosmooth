# Canonical materialized synthetic dataset contract.

.new.synthetic.dataset <- function(
    spec, n, seed, rng.policy, rng.streams, sample.out, frame.matrix,
    truth.out, response.out, parameters = list(), provenance = list()) {
  geometry <- spec$geometry.spec
  gp <- geometry$parameters
  if (is.null(sample.out$predictors)) {
    X <- .embed.synthetic.geometry(
      geometry, sample.out$latent, frame.matrix = frame.matrix)
  } else {
    X <- as.matrix(sample.out$predictors)
  }
  storage.mode(X) <- "double"
  latent <- sample.out$latent
  if (!is.null(latent)) {
    latent <- as.matrix(latent)
    storage.mode(latent) <- "double"
  }
  region <- sample.out$region
  if (!is.null(region)) region <- as.character(region)
  family <- geometry$family
  if (family == "g4.segment.rectangle") {
    intrinsic.dim <- NA_integer_
    intrinsic.dim.by.region <- gp$intrinsic.dim.by.region
    codimension <- NA_integer_
    codimension.by.region <- gp$codimension.by.region
    declared.regions <- gp$declared.regions
  } else if (family == "simplex") {
    intrinsic.dim <- NA_integer_
    intrinsic.dim.by.region <- c(
      interior = gp$parts - 1L,
      zero = gp$parts -
        length(spec$sampling.spec$parameters$zero.parts) - 1L)
    codimension <- NA_integer_
    codimension.by.region <- gp$parts - intrinsic.dim.by.region
    declared.regions <- c("interior", "zero")
  } else {
    intrinsic.dim <- gp$intrinsic.dim
    intrinsic.dim.by.region <- NULL
    codimension <- ncol(X) - intrinsic.dim
    codimension.by.region <- NULL
    declared.regions <- if (is.null(region)) NULL else unique(region)
  }
  observed.regions <- if (is.null(region)) NULL else {
    if (is.null(declared.regions)) unique(region)
    else declared.regions[declared.regions %in% unique(region)]
  }
  label <- if (is.null(spec$recipe.id)) "adhoc" else
    gsub("[^A-Za-z0-9_.-]", "-", spec$recipe.id)
  dataset.id <- paste0(
    label, "__spec", spec$specification.sha256,
    "__n", n, "__seed", seed, "__rng", rng.policy)
  truth.spec <- spec$truth.spec
  response.spec <- spec$response.spec
  truth.scope <- truth.spec$parameters$scope
  truth.estimand <- truth.spec$parameters$estimand
  response.sd <- switch(
    response.spec$family,
    gaussian = response.spec$parameters$parameters$sd,
    clustered.gaussian = response.spec$parameters$parameters$residual.sd,
    NA_real_)
  object <- list(
    dataset.id = dataset.id,
    specification.sha256 = spec$specification.sha256,
    recipe.id = spec$recipe.id,
    registry.tag = spec$registry.tag,
    n = as.integer(n),
    intrinsic.dim = as.integer(intrinsic.dim),
    intrinsic.dim.by.region = intrinsic.dim.by.region,
    ambient.dim = as.integer(ncol(X)),
    codimension = as.integer(codimension),
    codimension.by.region = codimension.by.region,
    latent = latent,
    latent.mask = sample.out$latent.mask,
    predictors = X,
    truth = as.numeric(truth.out$value),
    truth.scope = truth.scope,
    truth.estimand = truth.estimand,
    response = as.numeric(response.out$value),
    region = region,
    declared.regions = declared.regions,
    observed.regions = observed.regions,
    geometry.spec = spec$geometry.spec,
    sampling.spec = spec$sampling.spec,
    truth.spec = truth.spec,
    response.spec = response.spec,
    seed = as.integer(seed),
    rng.policy = rng.policy,
    rng.streams = rng.streams,
    parameters = utils::modifyList(
      list(
        frame.matrix = frame.matrix,
        sampling = sample.out$parameters,
        truth = truth.out$parameters,
        response = response.out$parameters
      ),
      parameters),
    provenance = provenance,
    # Transitional compatibility aliases.
    U = latent,
    Z = latent,
    X = X,
    y = as.numeric(response.out$value),
    d = as.integer(intrinsic.dim),
    p = as.integer(ncol(X)),
    sigma = as.numeric(response.sd),
    gtag = spec$registry.tag,
    params = NULL
  )
  object$params <- object$parameters
  class(object) <- c("synthetic_dataset", "dgp_dataset", "list")
  attr(object, "compatibility") <- spec$compatibility
  attr(object, "metadata") <- spec$metadata
  validate.synthetic.dataset(object)
  object
}

#' Validate a canonical synthetic dataset
#' @param x A `synthetic_dataset`.
#' @return `x`, invisibly.
#' @export
validate.synthetic.dataset <- function(x) {
  required <- c(
    "dataset.id", "specification.sha256", "recipe.id", "registry.tag", "n",
    "intrinsic.dim", "intrinsic.dim.by.region", "ambient.dim",
    "codimension", "codimension.by.region", "latent", "latent.mask",
    "predictors", "truth", "truth.scope", "truth.estimand", "response",
    "region", "declared.regions", "observed.regions", "geometry.spec",
    "sampling.spec", "truth.spec", "response.spec", "seed", "rng.policy",
    "rng.streams", "parameters", "provenance")
  missing <- setdiff(required, names(x))
  if (length(missing)) {
    stop("Missing synthetic dataset fields: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }
  if (!inherits(x, "synthetic_dataset")) {
    stop("x must inherit from synthetic_dataset.", call. = FALSE)
  }
  if (!is.matrix(x$predictors) || !identical(nrow(x$predictors), x$n) ||
      ncol(x$predictors) != x$ambient.dim ||
      any(!is.finite(x$predictors))) {
    stop("predictors violate the n by ambient.dim finite-matrix contract.",
         call. = FALSE)
  }
  if (length(x$truth) != x$n || length(x$response) != x$n ||
      any(!is.finite(x$truth)) || any(!is.finite(x$response))) {
    stop("truth and response must be finite length-n vectors.",
         call. = FALSE)
  }
  if (!x$truth.scope %in% c("population", "finite.design")) {
    stop("Unknown truth.scope.", call. = FALSE)
  }
  if (!is.character(x$rng.policy) || length(x$rng.policy) != 1L ||
      !x$rng.policy %in% c("named.stream.v1", "legacy")) {
    stop("rng.policy is missing or unknown.", call. = FALSE)
  }
  expected.hash <- .synthetic.sha256(list(
    geometry.spec = x$geometry.spec,
    sampling.spec = x$sampling.spec,
    truth.spec = x$truth.spec,
    response.spec = x$response.spec,
    compatibility = attr(x, "compatibility", exact = TRUE),
    metadata = attr(x, "metadata", exact = TRUE)))
  id.is.bound <- isTRUE(attr(x, "frozen.instance", exact = TRUE)) ||
    grepl(paste0("__spec", x$specification.sha256, "__"),
          x$dataset.id, fixed = TRUE)
  if (!identical(expected.hash, x$specification.sha256) ||
      !id.is.bound ||
      !grepl("^[0-9a-f]{64}$", x$specification.sha256)) {
    stop("dataset.id and specification.sha256 are inconsistent.",
         call. = FALSE)
  }
  if (!is.null(x$region)) {
    if (length(x$region) != x$n ||
        any(!x$region %in% x$declared.regions) ||
        !identical(x$observed.regions,
                   x$declared.regions[x$declared.regions %in%
                                        unique(x$region)])) {
      stop("Region declarations and observations are inconsistent.",
           call. = FALSE)
    }
  }
  if (!is.null(x$latent)) {
    if (!is.matrix(x$latent) || nrow(x$latent) != x$n) {
      stop("latent must be NULL or an n-row matrix.", call. = FALSE)
    }
    if (is.null(x$latent.mask)) {
      if (any(!is.finite(x$latent))) {
        stop("Unmasked latent coordinates must be finite.", call. = FALSE)
      }
    } else {
      if (!identical(dim(x$latent.mask), dim(x$latent)) ||
          any(!is.finite(x$latent[x$latent.mask])) ||
          any(!is.na(x$latent[!x$latent.mask]))) {
        stop("latent and latent.mask are inconsistent.", call. = FALSE)
      }
    }
  } else if (!is.null(x$latent.mask)) {
    stop("latent.mask must be NULL when latent is NULL.", call. = FALSE)
  }
  invisible(x)
}

.synthetic.dataset.payload <- function(x) {
  list(
    contract.version = "synthetic-content-v1",
    dataset.id = x$dataset.id,
    specification.sha256 = x$specification.sha256,
    recipe.id = x$recipe.id,
    registry.tag = x$registry.tag,
    n = x$n,
    intrinsic.dim = x$intrinsic.dim,
    intrinsic.dim.by.region = x$intrinsic.dim.by.region,
    ambient.dim = x$ambient.dim,
    codimension = x$codimension,
    codimension.by.region = x$codimension.by.region,
    latent = x$latent,
    latent.mask = x$latent.mask,
    predictors = x$predictors,
    truth = x$truth,
    truth.scope = x$truth.scope,
    truth.estimand = x$truth.estimand,
    response = x$response,
    region = x$region,
    declared.regions = x$declared.regions,
    observed.regions = x$observed.regions,
    seed = x$seed,
    rng.policy = x$rng.policy,
    rng.streams = x$rng.streams,
    geometry.spec = x$geometry.spec,
    sampling.spec = x$sampling.spec,
    truth.spec = x$truth.spec,
    response.spec = x$response.spec,
    parameters = x$parameters
  )
}

#' Compute the canonical content checksum of a synthetic dataset
#' @param x A `synthetic_dataset`.
#' @return A lowercase SHA-256 string.
#' @export
synthetic.dataset.checksum <- function(x) {
  validate.synthetic.dataset(x)
  .synthetic.sha256(.synthetic.dataset.payload(x))
}

#' Compare two synthetic datasets scientifically
#' @param x,y Synthetic datasets.
#' @param tolerance Absolute-plus-relative comparison tolerance.
#' @return A list with equality and mismatch details.
#' @export
compare.synthetic.dataset <- function(x, y, tolerance = c(1e-12, 1e-10)) {
  validate.synthetic.dataset(x)
  validate.synthetic.dataset(y)
  numeric.equal <- function(a, b) {
    if (!identical(dim(a), dim(b)) || length(a) != length(b) ||
        !identical(is.na(a), is.na(b))) {
      return(FALSE)
    }
    keep <- !is.na(a)
    all(abs(a[keep] - b[keep]) <=
          tolerance[1] + tolerance[2] * abs(b[keep]))
  }
  exact.fields <- c(
    "n", "ambient.dim", "truth.scope", "region", "declared.regions",
    "observed.regions", "rng.policy")
  mismatch <- exact.fields[
    !vapply(exact.fields, function(nm) identical(x[[nm]], y[[nm]]),
            logical(1))]
  numeric.fields <- c("latent", "truth", "response")
  mismatch <- c(
    mismatch,
    numeric.fields[
      !vapply(numeric.fields, function(nm) {
        if (is.null(x[[nm]]) || is.null(y[[nm]])) {
          return(identical(x[[nm]], y[[nm]]))
        }
        numeric.equal(x[[nm]], y[[nm]])
      }, logical(1))])
  random.frame <- identical(
    x$geometry.spec$parameters$frame, "random.orthonormal") &&
    identical(
      y$geometry.spec$parameters$frame, "random.orthonormal")
  if (random.frame) {
    dx <- as.matrix(stats::dist(x$predictors))^2
    dy <- as.matrix(stats::dist(y$predictors))^2
    if (!numeric.equal(dx, dy)) mismatch <- c(mismatch, "predictor.distances")
  } else if (!numeric.equal(x$predictors, y$predictors)) {
    mismatch <- c(mismatch, "predictors")
  }
  list(equal = !length(mismatch), mismatches = unique(mismatch))
}

#' Print a canonical synthetic dataset
#' @param x A `synthetic_dataset`.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @method print synthetic_dataset
#' @export
print.synthetic_dataset <- function(x, ...) {
  cat("<synthetic_dataset> ", x$dataset.id, "\n", sep = "")
  cat("  n=", x$n, "  intrinsic=", if (is.na(x$intrinsic.dim)) "varies"
      else x$intrinsic.dim, "  ambient=", x$ambient.dim,
      "  truth=", x$truth.scope, "\n", sep = "")
  if (!is.null(x$observed.regions)) {
    cat("  observed regions: ", paste(x$observed.regions, collapse = ", "),
        "\n", sep = "")
  }
  invisible(x)
}

#' Summarize a synthetic dataset as one metadata row
#' @param x A `synthetic_dataset`.
#' @param row.names Optional row names.
#' @param optional Ignored.
#' @param ... Ignored.
#' @return A one-row data frame.
#' @export
as.data.frame.synthetic_dataset <- function(
    x, row.names = NULL, optional = FALSE, ...) {
  data.frame(
    dataset.id = x$dataset.id,
    recipe.id = x$recipe.id %||% NA_character_,
    registry.tag = x$registry.tag %||% NA_character_,
    n = x$n,
    intrinsic.dim = x$intrinsic.dim,
    ambient.dim = x$ambient.dim,
    truth.scope = x$truth.scope,
    rng.policy = x$rng.policy,
    checksum = synthetic.dataset.checksum(x),
    stringsAsFactors = FALSE)
}
