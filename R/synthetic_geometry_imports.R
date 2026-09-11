# Re-export the migrated public interfaces during the transition.

#' @importFrom dgraphs edge.lengths.synthetic.geometry
#' @examples
#' geometry <- synthetic.quadform(1L, 1L)
#' edge.lengths.synthetic.geometry(geometry, matrix(0), matrix(2))
#' @export
dgraphs::edge.lengths.synthetic.geometry

#' @importFrom dgraphs embed.synthetic.geometry
#' @examples
#' geometry <- synthetic.circle()
#' embed.synthetic.geometry(geometry, matrix(c(0, pi / 2), ncol = 1))
#' @export
dgraphs::embed.synthetic.geometry

#' @importFrom dgraphs quadform.gradient
#' @examples
#' geometry <- synthetic.quadform(1L, 2L, forms = list(matrix(1)))
#' quadform.gradient(geometry, matrix(c(-1, 0, 1), ncol = 1))
#' @export
dgraphs::quadform.gradient

#' @importFrom dgraphs quadform.metric
#' @examples
#' geometry <- synthetic.quadform(1L, 2L, forms = list(matrix(1)))
#' quadform.metric(geometry, matrix(c(0, 1), ncol = 1))
#' @export
dgraphs::quadform.metric

#' @importFrom dgraphs synthetic.circle
#' @examples
#' synthetic.circle(radius = 2, angle.range = c(0, pi))
#' @export
dgraphs::synthetic.circle

#' @importFrom dgraphs synthetic.helix
#' @examples
#' synthetic.helix(pitch = 0.25, t.range = c(0, pi))
#' @export
dgraphs::synthetic.helix

#' @importFrom dgraphs synthetic.point.line.junction
#' @examples
#' synthetic.point.line.junction(c(0, 0), c(0, 0), c(1, 0), c(0, 1))
#' @export
dgraphs::synthetic.point.line.junction

#' @importFrom dgraphs synthetic.quadform
#' @examples
#' synthetic.quadform(1L, 2L, forms = list(matrix(0.5)))
#' @export
dgraphs::synthetic.quadform

#' @importFrom dgraphs synthetic.sampling.clustered
#' @examples
#' synthetic.sampling.clustered(3L, 5L, within.sd = 0.1)
#' @export
dgraphs::synthetic.sampling.clustered

#' @importFrom dgraphs synthetic.sampling.dirichlet.zeros
#' @examples
#' synthetic.sampling.dirichlet.zeros(
#'   concentration = rep(1, 3), zero.fraction = 0.2, zero.parts = 1L
#' )
#' @export
dgraphs::synthetic.sampling.dirichlet.zeros

#' @importFrom dgraphs synthetic.sampling.gapped.uniform
#' @examples
#' intervals <- rbind(c(-1, -0.25), c(0.25, 1))
#' synthetic.sampling.gapped.uniform(intervals, probabilities = c(0.5, 0.5))
#' @export
dgraphs::synthetic.sampling.gapped.uniform

#' @importFrom dgraphs synthetic.sampling.grid.interval
#' @examples
#' synthetic.sampling.grid.interval(0, 2 * pi, endpoints = "exclude.lower")
#' @export
dgraphs::synthetic.sampling.grid.interval

#' @importFrom dgraphs synthetic.sampling.truncated.normal
#' @examples
#' synthetic.sampling.truncated.normal(0, 1, -2, 2)
#' @export
dgraphs::synthetic.sampling.truncated.normal

#' @importFrom dgraphs synthetic.sampling.uniform.box
#' @examples
#' synthetic.sampling.uniform.box(lower = c(-1, 0), upper = c(1, 2))
#' @export
dgraphs::synthetic.sampling.uniform.box

#' @importFrom dgraphs synthetic.sampling.uniform.disk
#' @examples
#' synthetic.sampling.uniform.disk(radius = 2)
#' @export
dgraphs::synthetic.sampling.uniform.disk

#' @importFrom dgraphs synthetic.sampling.uniform.interval
#' @examples
#' synthetic.sampling.uniform.interval(0, 1, order = "ascending")
#' @export
dgraphs::synthetic.sampling.uniform.interval

#' @importFrom dgraphs synthetic.sampling.uniform.rectangle
#' @examples
#' synthetic.sampling.uniform.rectangle(c(-1, -2), c(1, 2))
#' @export
dgraphs::synthetic.sampling.uniform.rectangle

#' @importFrom dgraphs synthetic.simplex
#' @examples
#' synthetic.simplex(parts = 3L)
#' @export
dgraphs::synthetic.simplex

#' @importFrom dgraphs synthetic.sphere.cap
#' @examples
#' synthetic.sphere.cap(radius = 2, footprint.radius = 1)
#' @export
dgraphs::synthetic.sphere.cap

#' @importFrom dgraphs synthetic.stratified
#' @examples
#' point <- synthetic.stratum.point("point", c(0, 0))
#' line <- synthetic.stratum.segment("line", c(0, 1), c(0, 0), c(1, 0))
#' synthetic.stratified(list(point, line))
#' @export
dgraphs::synthetic.stratified

#' @importFrom dgraphs synthetic.stratum.point
#' @examples
#' synthetic.stratum.point("origin", c(0, 0))
#' @export
dgraphs::synthetic.stratum.point

#' @importFrom dgraphs synthetic.stratum.rectangle
#' @examples
#' synthetic.stratum.rectangle(
#'   "square", rbind(c(-1, 1), c(-1, 1)), c(0, 0), diag(2)
#' )
#' @export
dgraphs::synthetic.stratum.rectangle

#' @importFrom dgraphs synthetic.stratum.segment
#' @examples
#' synthetic.stratum.segment("line", c(-1, 1), c(0, 0), c(1, 0))
#' @export
dgraphs::synthetic.stratum.segment

#' @importFrom dgraphs synthetic.torus.patch
#' @examples
#' synthetic.torus.patch(major.radius = 2, minor.radius = 0.5)
#' @export
dgraphs::synthetic.torus.patch

#' @importFrom dgraphs synthetic.trefoil
#' @examples
#' synthetic.trefoil(scale = 0.5, t.range = c(0, pi))
#' @export
dgraphs::synthetic.trefoil
