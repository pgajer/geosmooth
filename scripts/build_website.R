# Run from the package root with the tested development dependency installed.
pkgdown::build_site(preview = FALSE)
# Build a second view from the same Rd topics, then restore the task index.
alphabetical <- pkgdown::as_pkgdown(".")
topics <- paste0("`", sort(alphabetical$topics$name), "`")
alphabetical$meta$reference <- list(list(
    title = "Functions A–Z",
    desc = "Exported functions and S3 methods. Call the corresponding generic for a fitted object's methods.",
    contents = topics))
pkgdown::build_reference_index(alphabetical)
stopifnot(file.copy("docs/reference/index.html", "docs/reference/alphabetical.html", overwrite = TRUE))
pkgdown::build_reference_index()
