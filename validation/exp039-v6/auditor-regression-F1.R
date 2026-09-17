# Replayed audit test; only its package-loading path is adapted.
pkgload::load_all('.', quiet=TRUE)
library(testthat)
test_that('a two-observation path cannot select a smoothing time after adding a constant', {
    adj <- list(2L,c(1L,3L),c(2L,4L),3L)
    weights <- list(1,c(1,1e-8),c(1e-8,1),1)
    grid <- c(.01,.1,1,1000)
    y <- c(1000,NA,NA,1001)
    b <- metric.graph.lowpass.basis(adj,weights,weight.type='conductance',spectrum='full',
                                  numerical.policy='verified.fallback')
    p <- apply.metric.graph.lowpass.path(b,y,grid)
    expect_identical(p$tuning[[1]]$status,'unresolved_flat_gcv')
    expect_false(p$tuning[[1]]$bracketed)
    expect_error(fit.metric.graph.lowpass(adj,weights,y,weight.type='conductance',spectrum='full',
                    eta.grid=grid,numerical.policy='verified.fallback'),'GCV is flat')
})
