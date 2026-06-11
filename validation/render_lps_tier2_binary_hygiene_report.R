# Render the Tier-2 (E2.14 + E2.12) results report, HTML + PDF.
#
# Report source:  validation/lps_tier2_binary_hygiene_report.Rmd
# Outputs:        dev/notes/lps/lps_tier2_binary_hygiene_report_2026-06-11.html
#                 dev/notes/lps/lps_tier2_binary_hygiene_report_2026-06-11.pdf
#                 (both committed on the Tier-2 branch)
#
# The report consumes only committed CSV artifacts under reports/ (generated
# by validation/export_tier2_report_inputs.R and the committed validation
# scripts); rendering performs no result computation. The PDF build uses the
# MacTeX xelatex via /Library/TeX/texbin (prepended to PATH below if
# missing); figures are vector (cairo_pdf) in the PDF and raster (ragg_png)
# in the HTML.
#
# Run from the package root:
#   Rscript validation/render_lps_tier2_binary_hygiene_report.R

build.datetime <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z",
                         tz = "America/New_York")
Sys.setenv(BUILD_DATETIME = build.datetime)

texbin <- "/Library/TeX/texbin"
if (dir.exists(texbin) &&
    !grepl(texbin, Sys.getenv("PATH"), fixed = TRUE)) {
    Sys.setenv(PATH = paste(texbin, Sys.getenv("PATH"), sep = ":"))
}

out.dir <- file.path("dev", "notes", "lps")
dir.create(out.dir, recursive = TRUE, showWarnings = FALSE)
input <- file.path("validation", "lps_tier2_binary_hygiene_report.Rmd")

rmarkdown::render(
    input = input,
    output_format = "html_document",
    output_file = "lps_tier2_binary_hygiene_report_2026-06-11.html",
    output_dir = out.dir,
    knit_root_dir = normalizePath("."),
    quiet = TRUE
)
cat("rendered", file.path(out.dir,
    "lps_tier2_binary_hygiene_report_2026-06-11.html"),
    "at", build.datetime, "\n")

rmarkdown::render(
    input = input,
    output_format = "pdf_document",
    output_file = "lps_tier2_binary_hygiene_report_2026-06-11.pdf",
    output_dir = out.dir,
    knit_root_dir = normalizePath("."),
    quiet = TRUE
)
cat("rendered", file.path(out.dir,
    "lps_tier2_binary_hygiene_report_2026-06-11.pdf"),
    "at", build.datetime, "\n")
