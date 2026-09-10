#' Refine a path on a quadratic graph surface
#'
#' Internal solver for the surface \eqn{F(u) = (u, u^T A u)} over a disk or
#' rectangle. Initialization uses approximately equal surface-length segments.
#'
#' @param A Finite symmetric 2 by 2 quadratic-form matrix.
#' @param from,to Numeric vectors of two domain coordinates, inside `domain`.
#' @param domain A list with `kind = "ball"`, numeric `center` and positive
#'   `radius`, or `kind = "box"` and numeric `lower` and `upper` bounds.
#' @param method Either `"single_point"` or `"local_network"` refinement.
#' @param neighborhood `"neighbors"` uses immediate neighbors and the larger
#'   adjacent domain edge length as sampling radius. `"fixed_disk"` keeps the
#'   initial maximum domain edge length as radius. `"fixed_span"` also extends
#'   each side of the section until its accumulated domain edge length reaches
#'   that radius or a global endpoint.
#' @param seed Whole-number seed between zero and \eqn{2^{32}-1}. Dedicated
#'   C++ streams do not create or modify R's random state.
#' @param length_scale Positive surface-length reference for absolute tolerances.
#' @param initial_edges Initial segment count, between 2 and 256.
#' @param candidates Accepted disk draws per visit, between 1 and 256. Draws
#'   outside the domain are rejected; exact duplicates are removed afterwards.
#' @param max_epochs Maximum refinement rounds; zero returns initialization only.
#' @param plateau_epochs Stop after this many consecutive rounds with relative
#'   length decrease below `1e-5`.
#' @param max_vertices Maximum path size, at most 257 and greater than
#'   `initial_edges`.
#' @param max_edge_calls Maximum number of newly integrated edges.
#' @param max_seconds Wall-clock allowance in seconds. A single bounded
#'   integration can overrun a very short allowance.
#' @param cache_edges Maximum cached edges, between zero and 65536.
#' @param rejection_cap Maximum attempts per accepted candidate or shuffle draw.
#' @param random_orientation Randomize internal endpoint orientation once per
#'   call. Returned paths always follow the caller's endpoint order.
#' @param trace Retain a bounded in-memory refinement trace. Default `FALSE`.
#' @param trace_limit Maximum retained trace events, between zero and 10000.
#'
#' @return A list containing domain `path` and three-dimensional `surface_path`,
#'   estimated `length` and `error_estimate`, initialization, configuration,
#'   random-generator identity, counters, termination reason and optional trace.
#'   Status is `"candidate"`, `"direct_fallback"` or `"no_path"`. A calculation
#'   limit preserves the last completed path; a no-path result has missing
#'   length. `state_saving` is always `FALSE`: no files or resumable checkpoints
#'   are created. User interrupts propagate to R.
#'
#' @details Numerical error estimates are not rigorous interval bounds and the
#'   returned path is not guaranteed to be globally shortest. This internal
#'   interface supports one quadratic height over a two-dimensional domain.
#'   It requires neither Python nor runtime compilation. Use independent R
#'   processes, not concurrent C++ threads, for parallel solves.
#' @keywords internal
quadform_geodesics_solver <- function(A, from, to, domain,
    method = c("single_point", "local_network"),
    neighborhood = c("fixed_span", "neighbors", "fixed_disk"), seed = 1,
    length_scale = 1, initial_edges = 16L, candidates = 32L,
    max_epochs = 8L, plateau_epochs = 2L, max_vertices = 257L,
    max_edge_calls = 200000, max_seconds = Inf, cache_edges = 65536L,
    rejection_cap = 1000L, random_orientation = TRUE,
    trace = FALSE, trace_limit = 1000L) {
  method <- match.arg(method)
  neighborhood <- match.arg(neighborhood)
  options <- as.list(environment())
  options[c("A", "from", "to", "domain")] <- NULL
  rcpp_quadform_geodesics_solver(A, from, to, domain, options)
}
