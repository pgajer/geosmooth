#!/usr/bin/env Rscript

repo <- normalizePath(getwd(), mustWork = TRUE)
if (!file.exists(file.path(repo, "DESCRIPTION"))) {
  stop("Run this script from the geosmooth repository root.", call. = FALSE)
}
if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("Package 'pkgload' is required.", call. = FALSE)
}

pkgload::load_all(repo, quiet = TRUE)
registry.dir <- file.path(repo, "inst", "synthetic_registry")
dir.create(registry.dir, recursive = TRUE, showWarnings = FALSE)

component.rows <- list()
recipe.rows <- list()
component.id <- function(component) {
  hash <- geosmooth:::.synthetic.sha256(component)
  id <- paste(component$kind, component$family, substr(hash, 1, 16), sep = ".")
  component.rows[[id]] <<- data.frame(
    component.id = id,
    kind = component$kind,
    family = component$family,
    version = component$version,
    parameters = geosmooth:::.synthetic.registry.json.text(
      component$parameters),
    component.sha256 = hash,
    stringsAsFactors = FALSE)
  id
}

for (recipe.id in synthetic.registry.ids()) {
  spec <- geosmooth:::.synthetic.registry.spec.from.code(recipe.id)
  recipe.rows[[recipe.id]] <- data.frame(
    recipe.id = recipe.id,
    spec.recipe.id = if (is.null(spec$recipe.id)) "" else spec$recipe.id,
    registry.tag = if (is.null(spec$registry.tag)) "" else spec$registry.tag,
    geometry.id = component.id(spec$geometry.spec),
    sampling.id = component.id(spec$sampling.spec),
    truth.id = component.id(spec$truth.spec),
    response.id = component.id(spec$response.spec),
    compatibility.recipe =
      geosmooth:::.synthetic.registry.json.text(spec$compatibility),
    metadata = geosmooth:::.synthetic.registry.json.text(spec$metadata),
    specification.sha256 = spec$specification.sha256,
    status = "active",
    version = 1L,
    stringsAsFactors = FALSE)
}

components <- do.call(rbind, component.rows)
recipes <- do.call(rbind, recipe.rows)
row.names(components) <- NULL
row.names(recipes) <- NULL
components <- components[order(components$kind, components$component.id), ]
recipes <- recipes[order(recipes$recipe.id, method = "radix"), ]

plural <- c(
  geometry = "geometries", sampling = "samplings",
  truth = "truths", response = "responses")
for (kind in names(plural)) {
  table <- components[components$kind == kind, , drop = FALSE]
  utils::write.csv(
    table, file.path(registry.dir, paste0(plural[[kind]], ".csv")),
    row.names = FALSE, quote = TRUE)
}
utils::write.csv(
  recipes, file.path(registry.dir, "recipes.csv"),
  row.names = FALSE, quote = TRUE)

instances <- utils::read.csv(
  file.path(registry.dir, "instances.csv"), stringsAsFactors = FALSE)
instances <- instances[, c(
  "instance.id", "recipe.id", "n", "seed", "rng.policy",
  "status", "version")]
fixture.dir <- file.path(registry.dir, "fixtures")
dir.create(fixture.dir, recursive = TRUE, showWarnings = FALSE)
content.sha256 <- character(nrow(instances))
fixture.path <- character(nrow(instances))
for (i in seq_len(nrow(instances))) {
  spec <- geosmooth:::.synthetic.registry.resolve(instances$recipe.id[i])
  object <- materialize.synthetic(
    spec,
    n = instances$n[i],
    seed = instances$seed[i],
    rng.policy = instances$rng.policy[i],
    validate = TRUE)
  object$dataset.id <- instances$instance.id[i]
  attr(object, "frozen.instance.id") <- instances$instance.id[i]
  content.sha256[i] <- geosmooth:::.synthetic.sha256(
    geosmooth:::.synthetic.dataset.payload(object))
  filename <- paste0(instances$instance.id[i], ".rds")
  saveRDS(
    object, file.path(fixture.dir, filename),
    ascii = FALSE, version = 3, compress = "xz")
  fixture.path[i] <- file.path(
    "inst", "synthetic_registry", "fixtures", filename)
}
instances$checksum.id <- paste0(instances$instance.id, ".content.v1")
instances$fixture.path <- fixture.path
instances$content.sha256 <- content.sha256
instances <- instances[, c(
  "instance.id", "recipe.id", "n", "seed", "rng.policy",
  "checksum.id", "fixture.path", "status", "version", "content.sha256")]
utils::write.csv(
  instances, file.path(registry.dir, "instances.csv"),
  row.names = FALSE, quote = TRUE)

environment.rows <- list()
checksum.rows <- lapply(seq_len(nrow(instances)), function(i) {
  fingerprint <- geosmooth:::.synthetic.environment.fingerprint(
    instances$rng.policy[i])
  fingerprint.values <- vapply(
    fingerprint, as.character, character(1))
  if (any(!nzchar(fingerprint.values)) ||
      any(grepl("unknown|unavailable", fingerprint.values,
                ignore.case = TRUE))) {
    stop(
      "Registry generation requires a complete environment fingerprint.",
      call. = FALSE)
  }
  fingerprint.id <-
    geosmooth:::.synthetic.environment.fingerprint.id(fingerprint)
  environment.rows[[fingerprint.id]] <<- data.frame(
    environment.fingerprint.id = fingerprint.id,
    as.data.frame(fingerprint, stringsAsFactors = FALSE),
    fingerprint.sha256 = geosmooth:::.synthetic.sha256(fingerprint),
    status = "active",
    stringsAsFactors = FALSE,
    check.names = FALSE)
  data.frame(
    checksum.id = instances$checksum.id[i],
    instance.id = instances$instance.id[i],
    content.sha256 = instances$content.sha256[i],
    payload.contract = "synthetic-content-v1",
    serialization = "R-xdr-v3",
    environment.fingerprint.id = fingerprint.id,
    scientific.abs.tolerance = 1e-12,
    scientific.rel.tolerance = 1e-10,
    status = instances$status[i],
    stringsAsFactors = FALSE,
    check.names = FALSE)
})
checksums <- do.call(rbind, checksum.rows)
environments <- do.call(rbind, environment.rows)
row.names(environments) <- NULL
environments <- environments[
  order(environments$environment.fingerprint.id, method = "radix"),
  , drop = FALSE]
utils::write.csv(
  environments,
  file.path(registry.dir, "environment_fingerprints.csv"),
  row.names = FALSE, quote = TRUE)
utils::write.csv(
  checksums, file.path(registry.dir, "checksums.csv"),
  row.names = FALSE, quote = TRUE)

for (instance.id in instances$instance.id) {
  materialize.synthetic.instance(instance.id, validate = TRUE)
}
