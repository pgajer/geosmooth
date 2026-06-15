# =============================================================================
# E4.1 — binding to the AUDITED Amendment-1 G3a generator
#
# The DGP library lives on branch `codex/geosmooth-dgp-library`, audit-accepted
# at commit 58f5ab93b433b73d60c291fc6daebd53644054e8 ("Add DGP-library re-audit
# verdict (accepted; all 10 tags)"; the library source last changed in its
# parent 9a62f72). This worktree's branch does not contain the library, so the
# binding loads `R/dgp_library.R` from git AT THE PINNED COMMIT (recording the
# commit and the file's git blob id), materializes the frozen registry row, and
# verifies the materialized object's content SHA-256 against the frozen
# registry (`inst/dgp_registry/dgp_registry.csv` at the same commit) before
# anything consumes it. A checksum mismatch is a hard stop.
#
# E4.1's pinned row (orchestrator resolution 2026-06-12, Item 4b):
#   G3a-R1-smooth-s010-n1200  = dgp.materialize("G3a",
#       list(n = 1200L, R = 1, truth = "smooth", sigma = 0.10, seed = 1L))
#   frozen sha256 b5a2e07699378e74eecbeeef5fb2b1108e3701a43601c4623babb81a9d204614
#
# The coverage protocol is conditional-on-design (resolution Item 4c): the
# study consumes the row's frozen (U, X, truth) and redraws replicate noise on
# its own seeds (s0 + r); the row's frozen `y` participates only in the
# checksum verification.
# =============================================================================

E41.DGP.AUDITED.COMMIT <- "58f5ab93b433b73d60c291fc6daebd53644054e8"
E41.DGP.DATASET.ID <- "G3a-R1-smooth-s010-n1200"
E41.DGP.ARGS <- list(n = 1200L, R = 1, truth = "smooth", sigma = 0.10,
                     seed = 1L)

e41.load.audited.dgp.library <- function(commit = E41.DGP.AUDITED.COMMIT) {
    git <- function(...) system2("git", c(...), stdout = TRUE)
    head.ok <- tryCatch(length(git("cat-file", "-e",
                                   paste0(commit, "^{commit}"))) == 0L,
                        error = function(e) FALSE,
                        warning = function(w) FALSE)
    src <- tryCatch(
        git("show", paste0(commit, ":R/dgp_library.R")),
        error = function(e) stop("cannot read R/dgp_library.R at the audited ",
                                 "commit ", commit, ": ", conditionMessage(e),
                                 call. = FALSE)
    )
    blob.oid <- tryCatch(
        git("rev-parse", paste0(commit, ":R/dgp_library.R"))[[1L]],
        error = function(e) NA_character_
    )
    registry.text <- git("show",
                         paste0(commit, ":inst/dgp_registry/dgp_registry.csv"))
    registry <- utils::read.csv(text = paste(registry.text, collapse = "\n"),
                                stringsAsFactors = FALSE)
    tf <- tempfile(fileext = ".R")
    writeLines(src, tf)
    env <- new.env(parent = globalenv())
    source(tf, local = env)
    unlink(tf)
    list(
        env = env,
        commit = commit,
        head.verified = head.ok,
        blob.oid = blob.oid,
        registry = registry
    )
}

e41.materialize.audited.g3a <- function(lib,
                                        dataset.id = E41.DGP.DATASET.ID,
                                        args = E41.DGP.ARGS) {
    row <- lib$registry[lib$registry$dataset.id == dataset.id, , drop = FALSE]
    if (nrow(row) != 1L) {
        stop("registry row '", dataset.id, "' not found (or not unique) in ",
             "the frozen registry at commit ", lib$commit, ".", call. = FALSE)
    }
    ds <- lib$env$dgp.materialize("G3a", args)
    sha <- lib$env$dgp.content.sha256(ds)
    if (!identical(sha, row$sha256)) {
        stop("audited-G3a checksum mismatch for '", dataset.id, "': ",
             "materialized ", sha, " vs frozen ", row$sha256, ". The binding ",
             "must not be consumed.", call. = FALSE)
    }
    list(
        dataset = ds,
        registry.row = row,
        content.sha256 = sha,
        binding = list(
            dgp.commit = lib$commit,
            dgp.blob.oid = lib$blob.oid,
            dataset.id = dataset.id,
            args = args,
            verified = TRUE
        )
    )
}

# Adapter for dev/methods/lps/ci/e4_1_coverage_study.R's `dgp.fn` seam. The acceptance
# configuration IS the frozen row; any other (n, curvature.radius, seed) is an
# error, never a silent re-parametrization.
e41.audited.g3a.dgp.fn <- function(lib = NULL) {
    if (is.null(lib)) lib <- e41.load.audited.dgp.library()
    function(n, curvature.radius, seed) {
        if (!identical(as.integer(n), E41.DGP.ARGS$n) ||
            !isTRUE(all.equal(curvature.radius, E41.DGP.ARGS$R)) ||
            !identical(as.integer(seed), as.integer(E41.DGP.ARGS$seed))) {
            stop("the audited G3a binding serves exactly ",
                 E41.DGP.DATASET.ID, " (n=1200, R=1, seed=1); got n=", n,
                 ", curvature.radius=", curvature.radius, ", seed=", seed,
                 ".", call. = FALSE)
        }
        g3a <- e41.materialize.audited.g3a(lib)
        ds <- g3a$dataset
        list(
            U = ds$U,
            X = ds$X,
            truth = ds$truth,
            seed = ds$seed,
            dgp.source = "amendment1-g3a",
            binding = g3a$binding
        )
    }
}
