#!/usr/bin/env Rscript

repo <- normalizePath(getwd(), mustWork = TRUE)
if (!file.exists(file.path(repo, "DESCRIPTION"))) {
  stop("Run this script from the geosmooth repository root.", call. = FALSE)
}
if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("Package 'pkgload' is required.", call. = FALSE)
}

options(geosmooth.registry.verify = FALSE)
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
    component.sha256 = hash,
    stringsAsFactors = FALSE)
  id
}

for (recipe.id in synthetic.registry.ids()) {
  spec <- synthetic.registry.spec(recipe.id)
  recipe.rows[[recipe.id]] <- data.frame(
    recipe.id = recipe.id,
    registry.tag = spec$registry.tag,
    geometry.id = component.id(spec$geometry.spec),
    sampling.id = component.id(spec$sampling.spec),
    truth.id = component.id(spec$truth.spec),
    response.id = component.id(spec$response.spec),
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
checksums <- data.frame(
  checksum.id = paste0(instances$instance.id, ".content.v1"),
  instance.id = instances$instance.id,
  content.sha256 = instances$content.sha256,
  payload.contract = "synthetic-content-v1",
  serialization = "R-xdr-v3",
  r.version = R.version.string,
  platform = R.version$platform,
  architecture = R.version$arch,
  endianness = .Platform$endian,
  status = instances$status,
  stringsAsFactors = FALSE)
utils::write.csv(
  checksums, file.path(registry.dir, "checksums.csv"),
  row.names = FALSE, quote = TRUE)
