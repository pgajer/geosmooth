# Check that a flat two-observation score path cannot select a smoothing time.
pkgload::load_all('.',quiet=TRUE)
library(testthat)
test_that('scorewise acceptable errors cannot tune a structurally flat two-observation path', {
    x <- readRDS('validation/exp039-v7/tolerance-boundary-input.rds')
    b <- metric.graph.lowpass.basis(x$adj,x$weights,weight.type='conductance',spectrum='full',
                                  numerical.policy='verified.fallback')
    p <- apply.metric.graph.lowpass.path(b,x$y,x$grid)
    expect_identical(p$tuning[[1]]$status,'unresolved_flat_gcv')
    fit <- function(grid) fit.metric.graph.lowpass(x$adj,x$weights,x$y,weight.type='conductance',
                  spectrum='full',numerical.policy='verified.fallback',eta.grid=grid)
    expect_error(fit(x$grid),'GCV is flat')
    fixed <- fit(x$grid[1])
    expect_error(refit(fixed,x$y,per.column.gcv=TRUE,eta.grid=x$grid),'GCV is flat')
})
