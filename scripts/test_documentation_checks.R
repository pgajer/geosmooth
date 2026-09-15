# Negative fixtures run only in temporary copies. Neither source nor appendix
# may change during read-only verification.
root <- normalizePath(".")
script <- file.path(root, "scripts/audit_api_guide.R")
before <- tools::md5sum("dev/notes/package/api-signatures.md")
stopifnot(system2(file.path(R.home("bin"), "Rscript"), c(shQuote(script), "--check")) == 0)
stopifnot(identical(before, tools::md5sum("dev/notes/package/api-signatures.md")))
staging <- tempfile("geosmooth-doc-fixture-"); dir.create(staging)
files <- c("NAMESPACE", "vignettes/function-guide.Rmd", "dev/notes/package/api-signatures.md",
           list.files("R", pattern = "[.]R$", full.names = TRUE),
           list.files("man", pattern = "[.]Rd$", full.names = TRUE))
for (name in files) {
    destination <- file.path(staging, name)
    dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    stopifnot(file.copy(file.path(root, name), destination))
}
old <- setwd(staging)
tryCatch({
    guide <- readLines("vignettes/function-guide.Rmd")
    catalog <- grep("^\\| \\[?`fit[.]lps[(][)]`", guide)
    stopifnot(length(catalog) == 1L)
    writeLines(guide[-catalog], "vignettes/function-guide.Rmd")
    status <- system2(file.path(R.home("bin"), "Rscript"),
                      c(shQuote(script), "--check"), stdout = FALSE, stderr = FALSE)
    stopifnot(status != 0)
    writeLines(guide, "vignettes/function-guide.Rmd")
    rd <- readLines("man/fit.lps.Rd")
    writeLines(rd[rd != "\\alias{fit.lps}"], "man/fit.lps.Rd")
    status <- system2(file.path(R.home("bin"), "Rscript"),
                      c(shQuote(script), "--check"), stdout = FALSE, stderr = FALSE)
    stopifnot(status != 0)
    writeLines(rd, "man/fit.lps.Rd")
    appendix <- "dev/notes/package/api-signatures.md"
    write("stale fixture", appendix, append = TRUE)
    status <- system2(file.path(R.home("bin"), "Rscript"),
                      c(shQuote(script), "--check"), stdout = FALSE, stderr = FALSE)
    stopifnot(status != 0, tail(readLines(appendix), 1) == "stale fixture")
}, finally = {setwd(old); unlink(staging, recursive = TRUE)})
cat("Missing catalog, missing help alias, and stale appendix fixtures failed as intended; read-only checks preserved files.\n")
