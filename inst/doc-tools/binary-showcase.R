# Reproduce the localized-peak example in the logistic trend-filtering vignette.
library(geosmooth)
set.seed(9402L)
x <- seq(0, 1, length.out = 160)
truth <- plogis(-2 + 4.8 * exp(-((x - .4)/.15)^2))
y <- rbinom(length(x), 1, truth)
fit <- fit.logistic.trend.filtering(x, y,
    lambda = c(Inf, .1, .01, .001), backend = "banded")
assessment <- assess.logistic.trend.filtering(fit, permutations = 99,
    inner.folds = 3, outer.folds = 5, seed = 9502L,
    additional.tests = c("absolute.deviation", "total.variation"))
selected <- assessment$fit
j <- selected$selected.index
stopifnot(assessment$status == "complete",
    assessment$prediction$status == "complete",
    all(assessment$tests$status == "complete"),
    selected$diagnostics$converged[j],
    all(assessment$prediction$folds$status == "complete"))
linear <- glm(y ~ x, family = binomial())
stopifnot(linear$converged)

draw_binary_showcase <- function() {
    blue <- "#17658B"; orange <- "#B85928"; ink <- "#26343D"
    old <- par(no.readonly = TRUE)
    on.exit({layout(1); par(old)})
    layout(matrix(c(1, 1, 2, 3, 4, 4, 5, 5), 2, byrow = TRUE),
           widths = c(1, 1, 1, 1), heights = c(1, .9))
    par(oma = c(2.8, .4, 3.5, .6), family = "sans", col = ink,
        col.axis = ink, col.lab = ink, fg = ink, cex = .94,
        mgp = c(2.4, .7, 0), tcl = -.25)
    par(mar = c(4.5, 4.5, 3, 1.2))
    grid <- seq(0, 1, length.out = 600)
    plot(grid, predict(selected, grid), type = "n", ylim = c(0, 1),
         xlab = "Predictor", ylab = "Outcome probability", bty = "l",
         main = "A   Recover the probability curve", adj = 0, cex.main = 1)
    abline(h = c(.25, .5, .75), col = "#E9EDF0", lwd = .8)
    rug(x[y == 0], side = 1, col = "#84929A", ticksize = .035)
    rug(x[y == 1], side = 3, col = "#84929A", ticksize = .035)
    lines(grid, plogis(-2 + 4.8 * exp(-((grid - .4)/.15)^2)),
          col = ink, lty = 2, lwd = 2)
    lines(grid, predict(linear, data.frame(x = grid), type = "response"),
          col = "#89969D", lty = 3, lwd = 2)
    lines(grid, predict(selected, grid), col = blue, lwd = 2.5)
    legend("topright", c("Trend filter", "Known truth", "Linear logistic"),
           col = c(blue, ink, "#89969D"), lty = c(1, 2, 3), lwd = 2,
           bty = "n", cex = .85)
    mtext("Rugs: outcomes 0 below, 1 above", side = 1, line = 3.3, cex = .75)
    par(mar = c(4.5, 3.5, 3, 1.2))
    null <- assessment$permutations$statistic
    hist(null, breaks = 12, xlim = range(c(0, null, assessment$statistic)),
         col = "#DCE5EA", border = "white", main = "B   Test constancy", cex.main = 1,
         xlab = "Likelihood improvement", ylab = "Permutation count", bty = "l")
    abline(v = assessment$statistic, col = orange, lwd = 2)
    legend("top", c("Observed", sprintf("p = %.2f", assessment$p.value),
                          sprintf("Holm p = %.2f", assessment$tests$p.value.holm[assessment$tests$test == "likelihood"])),
           lty = c(1, NA, NA), col = c(orange, ink, ink), lwd = 2, bty = "n", cex = .85)
    mtext("99 shuffles; tuning repeated each time", side = 1, line = 3.3, cex = .75)
    scores <- assessment$prediction$scores$log.loss
    par(mar = c(4.5, 3.5, 3, .7))
    at <- barplot(scores, names.arg = c("Constant", "Trend filter"),
        col = c("#DCE5EA", blue), border = NA, ylim = c(0, max(scores)*1.23),
        ylab = "Held-out log loss", main = "C   Assess prediction", cex.main = 1,
        cex.names = .88, las = 1)
    text(at, scores, sprintf("%.3f", scores), pos = 3, cex = .92)
    mtext("Nested CV: 5 outer / 3 inner folds", side = 1, line = 3.3, cex = .75)
    # All three tests use the same 99 permutations and retune on every shuffle.
    shape_panel <- function(name, label, scale, units, explanation, formula) {
        value <- unname(assessment$curve.summaries[name]) * scale
        null <- assessment$permutation.statistics[[name]] * scale
        test <- assessment$tests[assessment$tests$test == name, ]
        stopifnot(nrow(test) == 1L, test$status == "complete")
        par(mar = c(4.4, 4.5, 7.2, 1.2))
        hist(null, breaks = 12, xlim = range(c(0, null, value)) * c(1, 1.08),
             col = "#DCE5EA", border = "white", main = "",
             xlab = units, ylab = "Permutation count", bty = "l")
        abline(v = value, col = orange, lwd = 2)
        title(main = sprintf("%s: %s", label,
              if (scale == 100) sprintf("%.1f percentage points", value) else sprintf("%.2f", value)),
              adj = 0, line = 5.7, cex.main = 1.05)
        mtext(formula, side = 3, line = 2.1, adj = 0, cex = 1)
        mtext(sprintf("Permutation p = %.2f   |   Holm-adjusted p = %.2f",
              test$p.value, test$p.value.holm), side = 3, line = .6, adj = 0,
              col = blue, cex = .95)
        mtext(explanation, side = 1, line = 3.2, cex = .8)
    }
    shape_panel("absolute.deviation", "D   Mean absolute departure", 100,
                "Mean absolute departure (percentage points)",
                "Average over observations; reported above in percentage points",
                expression(delta[0] == frac(1,n) ~ sum(abs(hat(p)(x[i])-bar(y)), i==1,n)))
    shape_panel("total.variation", "E   Total variation", 1,
                "Total variation (probability scale)",
                "The s values include endpoints, knots and interior turning points",
                expression(delta[1] == sum(abs(hat(p)(s[j])-hat(p)(s[j-1])), j==2,K)))
    mtext(sprintf("Orange lines: observed. All tests assess constancy; Holm adjustment covers 3 tests.  |  %d adaptive knots; numerical checks passed.",
          selected$diagnostics$working.knots[j]), outer = TRUE,
          side = 1, line = 1.2, adj = 0, cex = .85, col = "#52636D")
    mtext("Binary observations, an adaptive probability curve, and evidence", outer = TRUE,
          side = 3, line = 1.6, adj = 0, cex = 1.3, font = 2)
    mtext("Order-2 logistic trend filtering  |  160 simulated independent observations", outer = TRUE,
          side = 3, line = .2, adj = 0, cex = .9)
}
