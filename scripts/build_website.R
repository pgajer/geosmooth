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
# The pinned dgraphs development API is ahead of CRAN. pkgdown guesses rdrr
# URLs for it, but those pages do not exist. Keep the code labels and the
# guide's installed-help instructions instead of publishing broken links.
for (file in list.files("docs", pattern = "[.]html$", recursive = TRUE, full.names = TRUE)) {
    page <- xml2::read_html(file)
    guessed <- xml2::xml_find_all(page, paste0(
        ".//a[starts-with(@href, 'https://rdrr.io/pkg/dgraphs/') or ",
        "starts-with(@href, 'https://rdrr.io/cran/dgraphs/')]") )
    if (length(guessed)) {
        xml2::xml_name(guessed) <- "span"
        for (attribute in c("href", "target", "rel", "class", "data-pkgdown"))
            xml2::xml_attr(guessed, attribute) <- NULL
        xml2::write_html(page, file)
    }
}
