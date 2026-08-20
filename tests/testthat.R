library(testthat)
library(geosmooth)

validation.contexts <- gsub(
  "^test-|\\.R$", "",
  c(
    "test-lps-bandwidth-multiplier.R",
    "test-lps-binary-metric-consistency.R",
    "test-lps-binary-separation.R",
    "test-lps-binomial-na-consistency.R",
    "test-lps-nested-grouped-cv.R",
    "test-lps-ridge-alignment.R",
    "test-lps-tier0-correctness.R",
    "test-lps-tier0-correctness-extended.R",
    "test-lps-tier4-uncertainty.R",
    "test-odcv5-all-method-smoke-report.R"
  )
)

if (identical(tolower(Sys.getenv("NOT_CRAN")), "true")) {
  test_check("geosmooth")
} else {
  # These acceptance and scientific-validation studies remain available via
  # `make test-validation` and `make test-all`, but are too CPU-intensive for
  # CRAN's shared check farm.
  test_check(
    "geosmooth",
    filter = paste(validation.contexts, collapse = "|"),
    invert = TRUE
  )
}
