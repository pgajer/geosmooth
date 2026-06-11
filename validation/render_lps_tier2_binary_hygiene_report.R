# Render the Tier-2 (E2.14 + E2.12) results report.
#
# Report source:  validation/lps_tier2_binary_hygiene_report.Rmd
# Output:         dev/notes/lps/lps_tier2_binary_hygiene_report_2026-06-11.html
#                 (self-contained; committed on the Tier-2 branch)
#
# The report consumes only committed CSV artifacts under reports/ (generated
# by validation/export_tier2_report_inputs.R and the committed validation
# scripts); rendering performs no result computation.
#
# Run from the package root:
#   Rscript validation/render_lps_tier2_binary_hygiene_report.R

build.datetime <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z",
                         tz = "America/New_York")
Sys.setenv(BUILD_DATETIME = build.datetime)

out.dir <- file.path("dev", "notes", "lps")
dir.create(out.dir, recursive = TRUE, showWarnings = FALSE)

rmarkdown::render(
    input = file.path("validation", "lps_tier2_binary_hygiene_report.Rmd"),
    output_file = "lps_tier2_binary_hygiene_report_2026-06-11.html",
    output_dir = out.dir,
    knit_root_dir = normalizePath("."),
    quiet = TRUE
)
cat("rendered", file.path(out.dir,
    "lps_tier2_binary_hygiene_report_2026-06-11.html"),
    "at", build.datetime, "\n")
