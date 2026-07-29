.package.source.files <- function() {
  c(
    list.files("R", pattern = "\\.[Rr]$", full.names = TRUE),
    list.files("vignettes", pattern = "\\.[Rr](md)?$", full.names = TRUE))
}

test_that("installed synthetic code has no cross-repository source calls", {
  files <- .package.source.files()
  text <- unlist(lapply(files, readLines, warn = FALSE), use.names = FALSE)
  expect_false(any(grepl(
    "source\\s*\\(\\s*['\"](?:/Users/|\\.\\./)",
    text, perl = TRUE)))
})

test_that("legacy family disposition ledger is normalized and explicit", {
  path <- geosmooth:::.synthetic.registry.asset(
    "legacy_family_disposition.csv")
  expect_true(nzchar(path) && file.exists(path))
  ledger <- utils::read.csv(path, stringsAsFactors = FALSE)
  required <- c(
    "family.id", "legacy.source", "legacy.symbols", "evidence", "decision",
    "canonical.owner", "implementation.status",
    "parity.or.retirement.record", "next.gate")
  expect_setequal(names(ledger), required)
  expect_identical(anyDuplicated(ledger$family.id), 0L)
  expect_true(all(nzchar(ledger$decision)))
  expect_true(all(nzchar(ledger$implementation.status)))
  expect_true(all(nzchar(ledger$next.gate)))
  expect_true(all(
    ledger$implementation.status %in% c(
      "implemented", "implemented-core", "implemented-noise-free",
      "implemented-g5-subset", "partial-private", "approved-pending",
      "pending-decision", "out-of-scope")))
})

test_that("deprecated DGP wrappers do not contain legacy generators", {
  wrappers <- c(
    "dgp.g1", "dgp.g2", "dgp.g3a", "dgp.g3b", "dgp.g3c", "dgp.g3d",
    "dgp.g4", "dgp.g5", "dgp.g6", "dgp.g7")
  for (name in wrappers) {
    body.text <- paste(
      deparse(body(get(name, asNamespace("geosmooth")))), collapse = "\n")
    expect_match(body.text, ".materialize.g.recipe", fixed = TRUE, info = name)
    expect_false(grepl("runif|rnorm|rbinom|rgamma", body.text), info = name)
  }
  helper.text <- paste(
    deparse(body(get(".materialize.g.recipe", asNamespace("geosmooth")))),
    collapse = "\n")
  expect_match(helper.text, "synthetic.registry.spec", fixed = TRUE)
  expect_match(helper.text, "materialize.synthetic", fixed = TRUE)
  expect_false(grepl("runif|rnorm|rbinom|rgamma", helper.text))
})
