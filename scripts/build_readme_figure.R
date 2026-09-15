# The guide and README share this installed, executable recipe.
pkgload::load_all(quiet = TRUE)
dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)
grDevices::png("man/figures/first-fit.png", width = 1080, height = 600, res = 150)
source("inst/doc-tools/first-fit.R", local = new.env(parent = globalenv()))
grDevices::dev.off()
