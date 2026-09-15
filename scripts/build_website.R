# Run from the package root with the tested development dependency installed.
pkgdown::build_site(preview = FALSE)
# Build a second view from the same Rd topics, then restore the task index.
ns <- readLines("NAMESPACE", warn = FALSE)
exports <- sub("^export[(](.*)[)]$", "\\1", grep("^export[(]", ns, value = TRUE))
pkgdown::build_reference_index(override = list(reference = list(
    list(title = "Functions A–Z", contents = sort(exports)))))
stopifnot(file.copy("docs/reference/index.html", "docs/reference/alphabetical.html", overwrite = TRUE))
pkgdown::build_reference_index()
