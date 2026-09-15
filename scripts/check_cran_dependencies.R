# A release prerequisite, separate from development CI's pinned source override.
# Run from the package root. Never substitutes installed development packages.
desc <- read.dcf("DESCRIPTION")[1L, ]
fields <- intersect(c("Depends", "Imports", "LinkingTo", "Suggests"), names(desc))
specs <- trimws(unlist(strsplit(paste(desc[fields], collapse = ","), ",")))
specs <- unique(specs[nzchar(specs)])
available <- available.packages(repos = "https://cloud.r-project.org", type = "source")
base.packages <- rownames(installed.packages(priority = "base"))
failures <- character()
for (spec in specs) {
  package <- sub("[[:space:]]*[(].*$", "", spec)
  if (package == "R" || package %in% base.packages) next
  if (!package %in% rownames(available)) {
    failures <- c(failures, paste(package, "is unavailable from CRAN"))
    next
  }
  version <- available[package, "Version"]
  if (grepl("[(]", spec)) {
    requirement <- sub(".*[(](.*)[)]", "\\1", spec)
    parts <- strsplit(trimws(requirement), "[[:space:]]+")[[1L]]
    comparison <- utils::compareVersion(version, parts[2L])
    ok <- switch(parts[1L], ">=" = comparison >= 0, ">" = comparison > 0,
                 "<=" = comparison <= 0, "<" = comparison < 0,
                 "==" = comparison == 0, FALSE)
    if (!ok) failures <- c(failures, paste(spec, "required; CRAN supplies", version))
  }
}
if (length(failures)) stop(paste(c("CRAN dependency gate failed:", failures), collapse = "\n"), call. = FALSE)
cat("All declared package dependencies are available from CRAN at the required versions.\n")
