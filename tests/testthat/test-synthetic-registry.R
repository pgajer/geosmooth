.read.synthetic.registry.table <- function(file) {
  path <- geosmooth:::.synthetic.registry.asset(file)
  expect_true(nzchar(path) && file.exists(path), info = file)
  utils::read.csv(
    path, stringsAsFactors = FALSE, check.names = FALSE)
}

test_that("normalized component foreign keys resolve exactly once", {
  recipes <- .read.synthetic.registry.table("recipes.csv")
  table.by.field <- c(
    geometry.id = "geometries.csv",
    sampling.id = "samplings.csv",
    truth.id = "truths.csv",
    response.id = "responses.csv")
  kind.by.field <- c(
    geometry.id = "geometry", sampling.id = "sampling",
    truth.id = "truth", response.id = "response")

  expect_setequal(recipes$recipe.id, synthetic.registry.ids())
  expect_identical(anyDuplicated(recipes$recipe.id), 0L)
  expect_true(all(recipes$status == "active"))
  expect_true(all(recipes$version == 1L))
  expect_true(all(recipes$payload.serialization == "R-xdr-v3"))

  all.component.ids <- character()
  for (field in names(table.by.field)) {
    components <- .read.synthetic.registry.table(table.by.field[[field]])
    expect_identical(anyDuplicated(components$component.id), 0L, info = field)
    expect_true(all(components$kind == kind.by.field[[field]]), info = field)
    expect_true(all(components$version >= 1L), info = field)
    expect_true(all(components$payload.serialization == "R-xdr-v3"),
                info = field)
    expect_true(all(nzchar(components$component.payload.hex)), info = field)
    for (id in recipes[[field]]) {
      expect_identical(sum(components$component.id == id), 1L, info = id)
      component <- geosmooth:::.synthetic.registry.component(
        id, kind.by.field[[field]])
      row <- components[components$component.id == id, , drop = FALSE]
      expect_identical(
        geosmooth:::.synthetic.sha256(component),
        row$component.sha256,
        info = id)
    }
    all.component.ids <- c(all.component.ids, components$component.id)
  }
  expect_identical(anyDuplicated(all.component.ids), 0L)
})

test_that("every registry recipe is reconstructed from normalized rows", {
  recipes <- .read.synthetic.registry.table("recipes.csv")
  for (i in seq_len(nrow(recipes))) {
    spec <- synthetic.registry.spec(recipes$recipe.id[i])
    expect_identical(
      spec$specification.sha256, recipes$specification.sha256[i],
      info = recipes$recipe.id[i])
    expect_identical(
      geosmooth:::.synthetic.registry.resolve(recipes$recipe.id[i]),
      spec,
      info = recipes$recipe.id[i])
  }
})

test_that("instance, checksum, and fixture foreign keys are complete", {
  recipes <- .read.synthetic.registry.table("recipes.csv")
  instances <- .read.synthetic.registry.table("instances.csv")
  checksums <- .read.synthetic.registry.table("checksums.csv")
  required.scope <- c(
    "r.version", "platform", "architecture", "compiler",
    "operating.system", "endianness", "rng.kind", "blas", "lapack",
    "math.runtime", "registry.version", "evaluator.version",
    "dependency.versions", "scientific.abs.tolerance",
    "scientific.rel.tolerance")

  expect_identical(anyDuplicated(instances$instance.id), 0L)
  expect_identical(anyDuplicated(instances$checksum.id), 0L)
  expect_identical(anyDuplicated(checksums$checksum.id), 0L)
  expect_true(all(instances$recipe.id %in% recipes$recipe.id))
  expect_true(all(instances$status == "active"))
  expect_true(all(instances$version == 1L))
  expect_true(all(required.scope %in% names(checksums)))
  expect_true(all(checksums$payload.contract == "synthetic-content-v1"))
  expect_true(all(checksums$serialization == "R-xdr-v3"))

  for (i in seq_len(nrow(instances))) {
    instance <- instances[i, , drop = FALSE]
    checksum <- checksums[
      checksums$checksum.id == instance$checksum.id, , drop = FALSE]
    expect_identical(nrow(checksum), 1L, info = instance$instance.id)
    expect_identical(
      checksum$instance.id, instance$instance.id,
      info = instance$instance.id)
    expect_identical(
      checksum$content.sha256, instance$content.sha256,
      info = instance$instance.id)
    fixture.path <- geosmooth:::.synthetic.registry.fixture.path(
      instance$fixture.path)
    expect_true(
      nzchar(fixture.path) && file.exists(fixture.path),
      info = instance$instance.id)
    fixture <- readRDS(fixture.path)
    expect_identical(
      validate.synthetic.dataset(fixture), fixture,
      info = instance$instance.id)
    object <- materialize.synthetic.instance(instance$instance.id)
    expect_identical(object$dataset.id, instance$instance.id)
    expect_identical(
      attr(object, "frozen.instance.id", exact = TRUE),
      instance$instance.id)
    if (geosmooth:::.synthetic.checksum.scope.matches(checksum)) {
      expect_identical(
        synthetic.dataset.checksum(object),
        instance$content.sha256,
        info = instance$instance.id)
      expect_identical(
        attr(object, "verification.scope", exact = TRUE),
        "exact-environment")
    } else {
      expect_true(
        compare.synthetic.dataset(object, fixture)$equal,
        info = instance$instance.id)
      expect_identical(
        attr(object, "verification.scope", exact = TRUE),
        "scientific-parity")
    }
  }

  for (field in required.scope) {
    value <- as.character(checksums[[field]])
    expect_true(all(nzchar(value)), info = field)
    expect_false(any(grepl(
      "unknown|unavailable", value, ignore.case = TRUE)),
      info = field)
  }
})

test_that("ordinary API behavior has no process-wide verification bypass", {
  source.files <- Sys.glob(file.path(
    test_path("..", "..", "R"), "*.R"))
  source <- paste(
    unlist(lapply(source.files, readLines, warn = FALSE)),
    collapse = "\n")
  expect_false(grepl("geosmooth.registry.verify", source, fixed = TRUE))

  old <- options(geosmooth.registry.verify = FALSE)
  on.exit(options(old), add = TRUE)
  spec <- synthetic.registry.spec("G1")
  expect_identical(
    spec,
    geosmooth:::.synthetic.registry.resolve("G1"))
})

test_that("specification hashes do not depend on collation", {
  original <- Sys.getlocale("LC_COLLATE")
  on.exit(try(Sys.setlocale("LC_COLLATE", original), silent = TRUE), add = TRUE)
  expected <- synthetic.registry.spec("G2")$specification.sha256
  changed <- try(Sys.setlocale("LC_COLLATE", "C"), silent = TRUE)
  skip_if(inherits(changed, "try-error"), "C collation is unavailable")
  expect_identical(
    synthetic.registry.spec("G2")$specification.sha256, expected)
})

test_that("legacy parameter overrides remain content-bound but non-frozen", {
  registered <- synthetic.registry.spec("G3a")
  altered <- synthetic.registry.spec("G3a", list(R = 2))
  expect_false(identical(
    registered$specification.sha256, altered$specification.sha256))
  object <- materialize.synthetic(
    altered, n = 20, seed = 1, rng.policy = "legacy")
  expect_match(
    object$dataset.id, altered$specification.sha256, fixed = TRUE)
})
