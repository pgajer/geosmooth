.legacy.parity.fixture.path <- function() {
  dev <- tryCatch(
    testthat::test_path("..", "fixtures", "g1_g7_legacy_parity_v1.rds"),
    error = function(e) "")
  if (nzchar(dev) && file.exists(dev)) return(dev)
  installed <- system.file(
    "testdata", "g1_g7_legacy_parity_v1.rds", package = "geosmooth")
  if (nzchar(installed) && file.exists(installed)) return(installed)
  ""
}

test_that("G1--G7 legacy wrappers reproduce frozen scientific fields", {
  fixture.path <- .legacy.parity.fixture.path()
  skip_if(!nzchar(fixture.path), "legacy parity fixture is unavailable")
  fixtures <- readRDS(fixture.path)
  expect_identical(
    attr(fixtures, "source.revision"),
    "5ecf721eae2765d8cde01d7fb82b17ff8bde8599")

  for (case.id in names(fixtures)) {
    fixture <- fixtures[[case.id]]
    actual <- suppressWarnings(
      do.call(get(fixture$fun, envir = asNamespace("geosmooth")),
              fixture$args))
    expected <- fixture$scientific
    for (field in names(expected)) {
      if (is.numeric(expected[[field]])) {
        expect_equal(actual[[field]], expected[[field]], tolerance = 1e-14,
                     info = paste(case.id, field))
      } else {
        expect_identical(actual[[field]], expected[[field]],
                         info = paste(case.id, field))
      }
    }
  }
})
