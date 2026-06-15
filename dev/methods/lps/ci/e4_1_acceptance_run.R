# =============================================================================
# E4.1 Part B — ACCEPTANCE invocation (ratified configuration, pinned)
#
# Ratification: orchestrator 2026-06-12
# (dev/methods/lps/audit_contracts/tiers1to4/
# e4_1_k_ratification_orchestrator_2026-06-12.md):
#   K = 20, kernel tricube, DGP = frozen audited row G3a-R1-smooth-s010-n1200
#   (curvature R = 1, geometry seed 1, sigma = 0.1 KNOWN), n = 1200, R = 500,
#   conditional-on-design coverage, drift-guarded fast path (guards at
#   replicate 1, every 25th, and the last; fit.every.replicate available to
#   the auditor). GATE: interior average coverage in [0.93, 0.97] (known
#   sigma) / [0.92, 0.98] (plug-in). STUDY: boundary and top-curvature-decile
#   strata reported separately, never averaged into the interior headline.
#   The manifest records K, kernel, design seed, realized interior mean and
#   max bias/se, both coverages, and the strata.
#
# This driver pins the ratified arguments so the acceptance configuration is
# code under version control, not an operator's command line. The only
# accepted overrides are out.dir and fit.every.replicate (the auditor's
# no-shortcut reproduction); anything else errors.
#
# Usage: Rscript dev/methods/lps/ci/e4_1_acceptance_run.R [out.dir=...] [fit.every.replicate=TRUE]
# =============================================================================

source("dev/methods/lps/ci/e4_1_k_calibration.R")  # loads package + study + binding (CLI-guarded)

run.e4.1.acceptance <- function(out.dir = file.path(
                                    "audit_artifacts",
                                    format(Sys.time(),
                                           "e4_1_acceptance_%Y%m%dT%H%M%SZ",
                                           tz = "UTC")),
                                fit.every.replicate = FALSE) {
    lib <- e41.load.audited.dgp.library()
    fn <- e41.audited.g3a.dgp.fn(lib)
    run.e4.1.coverage.study(
        n = 1200L,
        R.replicates = 500L,
        sigma = 0.1,
        support.size = 20L,                 # ratified 2026-06-12
        kernel = "tricube",                 # ratified 2026-06-12
        curvature.radius = 1,               # pinned with the registry row
        base.seed = 20260611L,              # replicate-noise stream s0 + r
        geometry.seed = 1L,                 # the frozen row's design seed
        level = 0.95,
        drift.check.every = 25L,
        drift.tol = 1e-10,
        fit.every.replicate = fit.every.replicate,
        dgp.fn = fn,
        dgp.source = "amendment1-g3a",      # acceptance-candidate context
        out.dir = out.dir
    )
}

## ---- CLI ---------------------------------------------------------------------
if (sys.nframe() == 0L) {
    args <- commandArgs(trailingOnly = TRUE)
    overrides <- list()
    for (a in args) {
        kv <- strsplit(a, "=", fixed = TRUE)[[1L]]
        if (length(kv) != 2L) stop("arguments must be key=value, got: ", a)
        if (!kv[[1L]] %in% c("out.dir", "fit.every.replicate")) {
            stop("the acceptance configuration is pinned by ratification; ",
                 "only out.dir and fit.every.replicate may be set (got '",
                 kv[[1L]], "').")
        }
        overrides[[kv[[1L]]]] <- utils::type.convert(kv[[2L]], as.is = TRUE)
    }
    do.call(run.e4.1.acceptance, overrides)
}
