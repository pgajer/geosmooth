#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
group <- if (length(args)) args[[1]] else "smoke"

test.dir <- file.path("tests", "testthat")
all.files <- sort(list.files(test.dir, pattern = "^test-.*\\.R$", full.names = FALSE))

validation.files <- c(
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

group.files <- list(
    all = all.files,
    smoke = setdiff(
        all.files,
        c(
            validation.files,
            "test-ge4-ssrhe-hessian-energy.R",
            "test-graph-trend-filtering.R",
            "test-ps-lps.R"
        )
    ),
    lps = grep("^test-(ge7-lps-api|lps-)", all.files, value = TRUE),
    "ps-lps" = "test-ps-lps.R",
    od = grep("^test-state-density-od", all.files, value = TRUE),
    graph = grep(
        "^test-(ge5-graph-boundary|graph-|metric-graph-lowpass|pttf-)",
        all.files,
        value = TRUE
    ),
    ssrhe = "test-ge4-ssrhe-hessian-energy.R",
    validation = validation.files
)

if (!group %in% names(group.files)) {
    stop(
        "Unknown test group '", group, "'. Available groups: ",
        paste(names(group.files), collapse = ", "),
        call. = FALSE
    )
}

files <- group.files[[group]]
missing <- setdiff(files, all.files)
if (length(missing)) {
    stop(
        "Test group '", group, "' references missing files: ",
        paste(missing, collapse = ", "),
        call. = FALSE
    )
}
if (!length(files)) {
    stop("Test group '", group, "' selected no test files.", call. = FALSE)
}

cat(
    "Running geosmooth test group '", group, "' with ",
    length(files), " file(s):\n",
    sep = ""
)
cat(paste0("  - ", files), sep = "\n")
cat("\n")

pkgload::load_all(".", quiet = TRUE)
for (file in files) {
    testthat::test_file(file.path(test.dir, file))
}
