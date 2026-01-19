#' Extract AoE Geometries
#'
#' Extract the original support polygons and/or the area of effect polygons
#' from an `aoe_result` object.
#'
#' @param x An `aoe_result` object returned by [aoe()].
#' @param which Which geometry to extract: `"aoe"` (default), `"original"`,
#'   or `"both"`.
#' @param support_id Optional character or numeric vector specifying which
#'   support(s) to extract. If `NULL` (default), extracts all.
#'
#' @return An `sf` object with polygon geometries and columns:
#'   \describe{
#'     \item{support_id}{Support identifier}
#'     \item{type}{`"original"` or `"aoe"`}
#'   }
#'
#' @examples
#' library(sf)
#'
#' support <- st_as_sf(
#'   data.frame(region = c("A", "B")),
#'   geometry = st_sfc(
#'     st_polygon(list(cbind(c(0, 10, 10, 0, 0), c(0, 0, 10, 10, 0)))),
#'     st_polygon(list(cbind(c(15, 25, 25, 15, 15), c(0, 0, 10, 10, 0))))
#'   ),
#'   crs = 32631
#' )
#'
#' pts <- st_as_sf(
#'   data.frame(id = 1:4),
#'   geometry = st_sfc(
#'     st_point(c(5, 5)),
#'     st_point(c(12, 5)),
#'     st_point(c(20, 5)),
#'     st_point(c(27, 5))
#'   ),
#'   crs = 32631
#' )
#'
#' result <- aoe(pts, support)
#'
#' # Get AoE polygons
#' aoe_polys <- aoe_geometry(result, "aoe")
#'
#' # Get both original and AoE for comparison
#' both <- aoe_geometry(result, "both")
#'
#' # Filter to one support (uses row names as support_id)
#' region_1 <- aoe_geometry(result, "aoe", support_id = "1")
#'
#' @export
aoe_geometry <- function(x, which = c("aoe", "original", "both"),
                         support_id = NULL) {

  if (!inherits(x, "aoe_result")) {
    stop("`x` must be an aoe_result object (from aoe())", call. = FALSE)
  }

  which <- match.arg(which)
  geoms <- attr(x, "aoe_geometries")

  if (is.null(geoms) || length(geoms) == 0) {
    stop("No geometries stored in result", call. = FALSE)
  }

  # Filter by support_id if specified
  if (!is.null(support_id)) {
    geoms <- geoms[names(geoms) %in% as.character(support_id)]
    if (length(geoms) == 0) {
      stop("No matching support_id found", call. = FALSE)
    }
  }

  # Extract requested geometries
  result <- switch(which,
    "original" = do.call(rbind, lapply(names(geoms), function(sid) {
      sf::st_sf(
        support_id = sid,
        type = "original",
        geometry = geoms[[sid]]$original
      )
    })),
    "aoe" = do.call(rbind, lapply(names(geoms), function(sid) {
      sf::st_sf(
        support_id = sid,
        type = "aoe",
        geometry = geoms[[sid]]$aoe_final
      )
    })),
    "both" = do.call(rbind, lapply(names(geoms), function(sid) {
      rbind(
        sf::st_sf(
          support_id = sid,
          type = "original",
          geometry = geoms[[sid]]$original
        ),
        sf::st_sf(
          support_id = sid,
          type = "aoe",
          geometry = geoms[[sid]]$aoe_final
        )
      )
    }))
  )

  row.names(result) <- NULL
  result
}
