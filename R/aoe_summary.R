#' Summarize Area of Effect Results
#'
#' Compute summary statistics for an AoE classification result, including
#' counts and proportions of core vs halo points per support.
#'
#' @param x An `sf` object returned by [aoe()].
#'
#' @return A data frame with one row per support, containing:
#'   \describe{
#'     \item{support_id}{Support identifier}
#'     \item{n_total}{Total number of supported points}
#'     \item{n_core}{Number of core points}
#'     \item{n_halo}{Number of halo points}
#'     \item{prop_core}{Proportion of points that are core}
#'     \item{prop_halo}{Proportion of points that are halo}
#'   }
#'
#' @examples
#' library(sf)
#'
#' support <- st_as_sf(
#'   data.frame(id = 1),
#'   geometry = st_sfc(st_polygon(list(
#'     cbind(c(0, 10, 10, 0, 0), c(0, 0, 10, 10, 0))
#'   ))),
#'   crs = 32631
#' )
#'
#' pts <- st_as_sf(
#'   data.frame(id = 1:4),
#'   geometry = st_sfc(
#'     st_point(c(5, 5)),
#'     st_point(c(2, 2)),
#'     st_point(c(15, 5)),
#'     st_point(c(12, 5))
#'   ),
#'   crs = 32631
#' )
#'
#' result <- aoe(pts, support)
#' aoe_summary(result)
#'
#' @export
aoe_summary <- function(x) {
  if (!inherits(x, "sf")) {
    stop("`x` must be an sf object (result from aoe())", call. = FALSE)
  }

  if (!"aoe_class" %in% names(x)) {
    stop("`x` must have an 'aoe_class' column (result from aoe())", call. = FALSE)
  }

  if (!"support_id" %in% names(x)) {
    stop("`x` must have a 'support_id' column (result from aoe())", call. = FALSE)
  }

  if (nrow(x) == 0) {
    return(data.frame(
      support_id = character(0),
      n_total = integer(0),
      n_core = integer(0),
      n_halo = integer(0),
      prop_core = numeric(0),
      prop_halo = numeric(0),
      stringsAsFactors = FALSE
    ))
  }

  # Aggregate by support_id
  support_ids <- unique(x$support_id)

  summaries <- lapply(support_ids, function(sid) {
    subset_x <- x[x$support_id == sid, ]
    n_total <- nrow(subset_x)
    n_core <- sum(subset_x$aoe_class == "core")
    n_halo <- sum(subset_x$aoe_class == "halo")

    data.frame(
      support_id = sid,
      n_total = n_total,
      n_core = n_core,
      n_halo = n_halo,
      prop_core = n_core / n_total,
      prop_halo = n_halo / n_total,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, summaries)
}
