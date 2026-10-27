# Run from geosmooth root with BLAS/OpenMP restricted to one thread.
root <- normalizePath('.')
out <- file.path(root,'dev/html/pca-pls-vignette')
dir.create(out,recursive=TRUE,showWarnings=FALSE)
# Native binaries were compiled optimized during the immediately preceding
# package integration; do not silently rebuild them in a different mode.
pkgload::load_all('../dgraphs',recompile=FALSE,quiet=TRUE)
pkgload::load_all('.',recompile=FALSE,quiet=TRUE)
writeLines(c(paste('Started',Sys.time()),
    paste('geosmooth',system('git rev-parse HEAD',intern=TRUE)),
    paste('dgraphs',system('git -C ../dgraphs rev-parse HEAD',intern=TRUE)),
    'Load mode: source_optimized; reused preceding verified native builds',
    'Numerical threads: 1; allocation ceiling: 6 workers, 30 GiB',
    capture.output(sessionInfo())),file.path(out,'runtime.txt'))
Sys.setenv(GEOSMOOTH_VIGNETTE_AUDIT=file.path(out,'results.rds'))
rmarkdown::render('vignettes/pca-pls-chart-comparison.Rmd',output_dir=out,
                  intermediates_dir=out,quiet=FALSE,clean=FALSE)
writeLines(paste('Completed',Sys.time()),file.path(out,'complete.txt'))
