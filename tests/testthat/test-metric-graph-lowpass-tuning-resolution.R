test_that("tuning resolves score differences using both pointwise budgets", {
    classify <- function(c, r=c, grid=seq_along(c), reason=NULL) {
        geosmooth:::.metric.graph.gcv.tuning(c,rep("valid",length(c)),grid,r,reason)
    }
    # Individually accurate scores can straddle the same exact value. Using
    # only one pointwise tolerance for their difference incorrectly separates them.
    for (scores in list(c(1-7e-8,1+7e-8),c(1-9e-8,1,1+9e-8))) {
        x <- classify(scores)
        expect_identical(x$status,"unresolved_flat_gcv")
        expect_false(x$selection.allowed)
        expect_true(is.na(x$best.idx))
        expect_error(geosmooth:::.metric.graph.require.tuning(x),"GCV is flat")
    }
    # Poor alternatives elsewhere do not make two overlapping contenders resolved.
    x <- classify(c(1,1+1.5e-7,2))
    expect_identical(x$status,"multiple_near_minima")
    expect_equal(x$near.minimum.indices,1:2)
    expect_false(x$selection.allowed)
    expect_error(geosmooth:::.metric.graph.require.tuning(x),"differences are numerically unresolved")
    # Candidate and reference disagree about the nominal minimum; retain both.
    x <- classify(c(1,1+1.5e-7,2),c(1+1e-7,1+.5e-7,2))
    expect_equal(x$candidate.minimum.index,1L)
    expect_equal(x$reference.minimum.index,2L)
    expect_false(x$selection.allowed)
    # Conversely, an interior minimum that remains separated is selectable.
    x <- classify(c(2,1,3),c(2+1e-8,1-1e-8,3))
    expect_identical(x$status,"unique_grid_minimum")
    expect_true(x$selection.allowed && x$bracketed)
    expect_equal(x$best.idx,2L)
    expect_gt(x$separation.margin,0)
    expect_silent(geosmooth:::.metric.graph.require.tuning(x))
    # A large arbitrary score perturbation cannot defeat an exact structural veto.
    x <- classify(c(1,1.001,2),reason="one_dimensional_observed_residual_space")
    expect_identical(x$status,"unresolved_flat_gcv")
    expect_false(x$selection.allowed)
    # A fixed time, even repeated in the input, remains a prescribed application.
    x <- classify(c(1,1),grid=c(.1,.1),reason="one_dimensional_observed_residual_space")
    expect_identical(x$status,"single_candidate")
    expect_true(x$selection.allowed)
    expect_false(x$bracketed)
    # Duplicate indices do not create distinct competing smoothing times.
    x <- classify(c(2,1,1,3),grid=c(1,2,2,3))
    expect_equal(x$best.idx,2L)
    expect_equal(x$near.minimum.indices,c(2L,3L))
    expect_true(x$bracketed)
})

test_that("the observed residual dimension identifies flat disconnected paths", {
    # One component has two observations, the other has one: residual dimension
    # is one although the total observed count is three. Exact GCV is 3/2.
    adj <- list(2L,c(1L,3L),2L,5L,4L)
    weights <- list(1,c(1,2),2,3,3)
    grid <- c(.01,.1,1,100)
    y <- c(0,NA,1,7,NA)
    b <- metric.graph.lowpass.basis(adj,weights,weight.type="conductance",
                                   spectrum="full",numerical.policy="verified.fallback")
    p <- apply.metric.graph.lowpass.path(b,y,grid)
    expect_equal(p$gcv.scores,rep(1.5,4),tolerance=1e-8)
    expect_identical(p$tuning[[1]]$structural.flat.reason,"one_dimensional_observed_residual_space")
    expect_false(p$tuning[[1]]$selection.allowed)
    fit <- function(times) fit.metric.graph.lowpass(adj,weights,y,weight.type="conductance",
                   spectrum="full",numerical.policy="verified.fallback",eta.grid=times)
    expect_error(fit(grid),"GCV is flat")
    fixed <- fit(grid[1])
    expect_error(refit(fixed,y,per.column.gcv=TRUE,eta.grid=grid),"GCV is flat")
    expect_true(all(is.finite(refit(fixed,y)$fitted.values)))
})

test_that("the auditor's nine-vertex weak-chain example cannot choose a time", {
    set.seed(6172026)
    for (i in seq_len(72)) {
        n <- sample(4:9,1); w <- runif(n-1,.5,2)
        w[sample.int(n-1,1)] <- 10^sample(c(-3,-5,-6,-7,-8,-9),1)
    }
    adj <- lapply(seq_len(n),function(j) as.integer(c(j-1,j+1)[c(j>1,j<n)]))
    weights <- lapply(seq_len(n),function(j) w[pmin(j,adj[[j]])])
    y <- rep(NA_real_,n);y[c(1,n)] <- c(0,1)
    grid <- 10^seq(-3,4,length.out=12)
    b <- metric.graph.lowpass.basis(adj,weights,weight.type="conductance",spectrum="full",
                                   numerical.policy="verified.fallback")
    p <- apply.metric.graph.lowpass.path(b,y,grid)
    expect_equal(p$gcv.scores,rep(1,12),tolerance=1.001e-7)
    expect_identical(p$tuning[[1]]$status,"unresolved_flat_gcv")
    expect_equal(p$tuning[[1]]$near.minimum.indices,1:12)
    expect_false(p$tuning[[1]]$selection.allowed)
    fit <- function(times) fit.metric.graph.lowpass(adj,weights,y,weight.type="conductance",
                   spectrum="full",numerical.policy="verified.fallback",eta.grid=times)
    expect_error(fit(grid),"GCV is flat")
    fixed <- fit(grid[1])
    expect_error(refit(fixed,y,per.column.gcv=TRUE,eta.grid=grid),"GCV is flat")
    expect_true(all(is.finite(refit(fixed,y)$fitted.values)))
})

test_that("fit and refit refuse overlapping contenders even on a nonflat path", {
    n <- 5L
    adj <- lapply(seq_len(n),function(i) as.integer(c(i-1L,i+1L)[c(i>1L,i<n)]))
    weights <- lapply(seq_len(n),function(i) (1:4)[pmin(i,adj[[i]])])
    b <- metric.graph.lowpass.basis(adj,weights,weight.type="conductance",spectrum="full",
                                   numerical.policy="verified.fallback")
    grid <- c(.0001,.00010000001,.1)
    p <- apply.metric.graph.lowpass.path(b,0:4,grid)
    expect_identical(p$tuning[[1]]$status,"multiple_near_minima")
    expect_false(p$tuning[[1]]$selection.allowed)
    expect_true(is.na(p$tuning[[1]]$best.idx))
    fit <- function(times) fit.metric.graph.lowpass(adj,weights,0:4,weight.type="conductance",
                    spectrum="full",numerical.policy="verified.fallback",eta.grid=times)
    expect_error(fit(grid),"differences are numerically unresolved")
    fixed <- fit(grid[1])
    expect_error(refit(fixed,0:4,per.column.gcv=TRUE,eta.grid=grid),"differences are numerically unresolved")
    expect_true(all(is.finite(refit(fixed,0:4)$fitted.values)))
})
