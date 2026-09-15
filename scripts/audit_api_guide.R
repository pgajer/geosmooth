# Run from the package root: Rscript scripts/audit_api_guide.R --check
# Read-only by default; --write explicitly refreshes the signature appendix.
args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) args <- "--check"
stopifnot(length(args) == 1L, args %in% c("--check", "--write"))
# Parses source without loading the package or running compiled code.
ns <- readLines("NAMESPACE", warn = FALSE)
exports <- sub("^export[(](.*)[)]$", "\\1",
               grep("^export[(]", ns, value = TRUE))
reexports <- sub("^importFrom[(]dgraphs,(.*)[)]$", "\\1",
                 grep("^importFrom[(]dgraphs,", ns, value = TRUE))
reexports <- intersect(exports, reexports)
guide <- readLines("vignettes/function-guide.Rmd", warn = FALSE)
# Strip Markdown link wrappers before checking the canonical catalog rows.
guide <- gsub("\\[(`[^`]+`)\\]\\([^)]*\\)", "\\1", guide)
catalog <- sub("^\\| `([^`]+)[(][)]`.*$", "\\1",
               grep("^\\| `[^`]+[(][)]` \\|", guide, value = TRUE))
dependency.catalog <- sub("^dgraphs::", "", catalog[grepl("^dgraphs::", catalog)])
catalog <- catalog[!grepl("::", catalog)]
imports <- sub("^importFrom[(]dgraphs,(.*)[)]$", "\\1",
               grep("^importFrom[(]dgraphs,", ns, value = TRUE))
stopifnot(!anyDuplicated(catalog), setequal(catalog, exports),
          !anyDuplicated(dependency.catalog), setequal(dependency.catalog, imports))
definitions <- list()
for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  parsed <- parse(path, keep.source = TRUE)
  refs <- attr(parsed, "srcref")
  for (i in seq_along(parsed)) {
    expr <- parsed[[i]]
    if (!is.call(expr) || !is.symbol(expr[[1L]]) ||
        !as.character(expr[[1L]]) %in% c("<-", "=") || length(expr) != 3L ||
        !is.call(expr[[3L]]) || !identical(expr[[3L]][[1L]], as.name("function"))) next
    name <- as.character(expr[[2L]])
    if (!name %in% exports) next
    # Build a function expression for deparsing; never evaluate its body/defaults.
    signature <- deparse(call("function", expr[[3L]][[2L]], NULL), width.cutoff = 88L)
    signature[length(signature)] <- sub(" NULL$", "", tail(signature, 1L))
    signature[1L] <- sub("^function", name, signature[1L])
    signature <- sub("[[:blank:]]+$", "", signature)
    definitions[[name]] <- list(path = path, line = as.integer(refs[[i]][1L]),
                               n = length(expr[[3L]][[2L]]), signature = signature)
  }
}
stopifnot(setequal(names(definitions), setdiff(exports, reexports)))
s3 <- grep("^S3method[(]", ns, value = TRUE)
out <- c(
  "# geosmooth API signature appendix", "",
  "Generated from the current source by `Rscript scripts/audit_api_guide.R --write`.",
  "Companion to [the API review](api-review-2026-09-14.md).", "",
  sprintf("There are %d explicit exports: %d local functions and %d dgraphs re-exports; %d S3 registrations are counted separately.",
          length(exports), length(definitions), length(reexports), length(s3)), "",
  "Counts below include `...` as one argument and exclude arguments forwarded through it.",
  "Defaults are unevaluated source expressions. The guide is checked for exactly one catalog row per export.", "",
  "## Local signatures", ""
)
for (name in sort(names(definitions))) {
  d <- definitions[[name]]
  out <- c(out, paste0("### ", name), "",
           sprintf("%d arguments. Source: [%s](../../../%s#L%d).", d$n, d$path, d$path, d$line),
           "", "```r", d$signature, "```", "")
}
out <- c(out, "## Related dgraphs functions (not geosmooth exports)", "",
         "These geometry and sampling functions are owned by dgraphs. Call them with dgraphs::; they are imported for internal recipe construction but not re-exported.", "",
         paste0("- `dgraphs::", sort(imports), "()`"), "", "## Registered S3 methods", "",
         "Use the corresponding generic; these registrations are not additional explicit exports.", "",
         "```r", s3, "```", "")
appendix <- "dev/notes/package/api-signatures.md"
if (args == "--write") writeLines(out, appendix) else if (
    !file.exists(appendix) || !identical(readLines(appendix, warn = FALSE), out)) {
    stop("Signature appendix is stale; run make update-api. No files were changed.", call. = FALSE)
}
# Verify installed-help aliases from their maintained Rd sources, not filenames.
rd.files <- list.files("man", pattern = "[.]Rd$", full.names = TRUE)
aliases <- unlist(lapply(rd.files, function(path) {
    rd <- tools::parse_Rd(path)
    tags <- vapply(rd, attr, "", which = "Rd_tag")
    unlist(lapply(rd[tags == "\\alias"], as.character), use.names = FALSE)
}), use.names = FALSE)
methods <- sub("^S3method[(]([^,]+),([^,)]+).*$", "\\1.\\2", s3)
missing <- setdiff(c(exports, methods, "geosmooth", "geosmooth-package"), aliases)
if (length(missing)) stop("Missing help aliases: ", paste(missing, collapse = ", "))
cat(sprintf("Guide coverage verified: %d/%d exports, no duplicate catalog rows.\n", length(catalog), length(exports)))
cat(sprintf("Recorded %d local signatures, %d re-exports, and %d S3 registrations.\n", length(definitions), length(reexports), length(s3)))
