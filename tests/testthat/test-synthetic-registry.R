.read.synthetic.registry.table <- function(file) {
  path <- geosmooth:::.synthetic.registry.asset(file)
  expect_true(nzchar(path) && file.exists(path), info = file)
  utils::read.csv(path, stringsAsFactors = FALSE)
}

test_that("normalized synthetic registry foreign keys resolve", {
  recipes <- .read.synthetic.registry.table("recipes.csv")
  components <- do.call(
    rbind,
    lapply(
      c("geometries.csv", "samplings.csv", "truths.csv", "responses.csv"),
      .read.synthetic.registry.table))
  expect_setequal(recipes$recipe.id, synthetic.registry.ids())
  expect_identical(anyDuplicated(recipes$recipe.id), 0L)
  expect_identical(anyDuplicated(components$component.id), 0L)
  for (field in c("geometry.id", "sampling.id", "truth.id", "response.id")) {
    expect_true(all(recipes[[field]] %in% components$component.id),
                info = field)
  }
  kind.by.field <- c(
    geometry.id = "geometry", sampling.id = "sampling",
    truth.id = "truth", response.id = "response")
  for (field in names(kind.by.field)) {
    observed <- components$kind[
      match(recipes[[field]], components$component.id)]
    expect_true(all(observed == kind.by.field[[field]]), info = field)
  }
})

test_that("every registry recipe reproduces its specification hash", {
  recipes <- .read.synthetic.registry.table("recipes.csv")
  for (i in seq_len(nrow(recipes))) {
    spec <- synthetic.registry.spec(recipes$recipe.id[i])
    expect_identical(
      spec$specification.sha256, recipes$specification.sha256[i],
      info = recipes$recipe.id[i])
  }
})

test_that("instance and checksum ledgers are normalized and scoped", {
  recipes <- .read.synthetic.registry.table("recipes.csv")
  instances <- .read.synthetic.registry.table("instances.csv")
  checksums <- .read.synthetic.registry.table("checksums.csv")
  expect_true(all(instances$recipe.id %in% recipes$recipe.id))
  expect_setequal(checksums$instance.id, instances$instance.id)
  expect_identical(
    checksums$content.sha256[
      match(instances$instance.id, checksums$instance.id)],
    instances$content.sha256)
  expect_true(all(checksums$payload.contract == "synthetic-content-v1"))
  expect_true(all(checksums$serialization == "R-xdr-v3"))
  expect_true(all(nzchar(checksums$r.version)))
  expect_true(all(nzchar(checksums$platform)))
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
