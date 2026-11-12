# Run from the package root with a compatible dgraphs installed.
pkgload::load_all(recompile = FALSE, quiet = TRUE)
source("inst/doc-tools/binary-showcase.R")
dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)
grDevices::png("man/figures/binary-showcase.png", width = 2100, height = 1700,
               res = 170, bg = "white", type = "cairo")
draw_binary_showcase()
grDevices::dev.off()
# Optional local record for checking and reproducing the numerical annotations.
args <- commandArgs(trailingOnly = TRUE)
if (length(args)) saveRDS(list(x = x, y = y, truth = truth,
    assessment = assessment, linear = linear, session = sessionInfo()), args[1])
print(assessment)
print(assessment$tests)
print(selected$diagnostics[j, ])
