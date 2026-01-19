#' Compute Area Statistics for AoE
#'
#' Calculate area statistics for the original supports and their areas of
#' effect, including expansion ratios, masking effects, and core/halo balance.
#'
#' @param x An `aoe_result` object returned by [aoe()].
#'
#' @return An `aoe_area_result` data frame with one row per support:
#'   \describe{
#'     \item{support_id}{Support identifier}
#'     \item{area_core}{Area of core region (same as original support)}
#'     \item{area_halo}{Area of halo region (AoE minus core, after masking)}
#'     \item{area_aoe}{Total AoE area after masking}
#'     \item{halo_core_ratio}{Ratio of halo to core area (theoretically 3.0 without mask)}
#'     \item{pct_masked}{Percentage of theoretical AoE area removed by masking}
#'   }
#'
#' @details
#' With scale \eqn{s}, the AoE expands by multiplier \eqn{(1+s)} from centroid,
#' resulting in \eqn{(1+s)^2} times the area. The theoretical halo:core ratio
#' is \eqn{(1+s)^2 - 1}:
#' - Scale 1 (default): ratio 3.0 (core 1 part, halo 3 parts)
#' - Scale 0.414: ratio 1.0 (equal areas)
#'
#' Masking reduces the halo (and thus the ratio) when the AoE extends beyond
#' hard boundaries.
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
#'   data.frame(id = 1:3),
#'   geometry = st_sfc(
#'     st_point(c(5, 5)),
#'     st_point(c(15, 5)),
#'     st_point(c(2, 2))
#'   ),
#'   crs = 32631
#' )
#'
#' result <- aoe(pts, support)
#' aoe_area(result)
#'
#' @export
aoe_area <- function(x) {

  if (!inherits(x, "aoe_result")) {
    stop("`x` must be an aoe_result object (from aoe())", call. = FALSE)
  }

  geoms <- attr(x, "aoe_geometries")

  if (is.null(geoms) || length(geoms) == 0) {
    stop("No geometries stored in result", call. = FALSE)
  }

  result <- do.call(rbind, lapply(names(geoms), function(sid) {
    g <- geoms[[sid]]

    area_core <- as.numeric(sf::st_area(g$original))
    area_aoe_raw <- as.numeric(sf::st_area(g$aoe_raw))
    area_aoe_final <- as.numeric(sf::st_area(g$aoe_final))

    # Halo = AoE minus core (but core might extend beyond masked AoE in edge cases)
    area_halo <- max(0, area_aoe_final - area_core)

    data.frame(
      support_id = sid,
      area_core = area_core,
      area_halo = area_halo,
      area_aoe = area_aoe_final,
      stringsAsFactors = FALSE
    )
  }))

  # Derived metrics
  result$halo_core_ratio <- result$area_halo / result$area_core

  # Calculate masking based on actual scale used
  scale <- attr(x, "aoe_scale")
  multiplier <- 1 + scale
  theoretical_aoe <- result$area_core * multiplier^2
  result$pct_masked <- 100 * (theoretical_aoe - result$area_aoe) / theoretical_aoe

  class(result) <- c("aoe_area_result", "data.frame")
  attr(result, "scale") <- scale
  row.names(result) <- NULL
  result
}


#' Print method for aoe_area_result
#'
#' @param x An aoe_area_result object
#' @param ... Additional arguments (ignored)
#'
#' @return Invisibly returns x
#' @export
print.aoe_area_result <- function(x, ...) {
  cat("AoE Area Statistics\n")
  cat(strrep("\u2500", 19), "\n\n", sep = "")

  # Format for display
  x_print <- x
  area_cols <- c("area_core", "area_halo", "area_aoe")

  # Determine unit based on max area
  max_area <- max(unlist(x[area_cols]), na.rm = TRUE)
  use_km2 <- max_area > 1e6

  for (col in area_cols) {
    if (col %in% names(x_print)) {
      vals <- x_print[[col]]
      if (use_km2) {
        x_print[[col]] <- sprintf("%.2f", vals / 1e6)
      } else {
        x_print[[col]] <- sprintf("%.0f", vals)
      }
    }
  }

  x_print$halo_core_ratio <- sprintf("%.2f", x$halo_core_ratio)
  x_print$pct_masked <- sprintf("%.1f%%", x$pct_masked)

  # Add unit indicator to column names
  unit <- if (use_km2) "km\u00b2" else "m\u00b2"
  names(x_print)[names(x_print) == "area_core"] <- paste0("area_core (", unit, ")")
  names(x_print)[names(x_print) == "area_halo"] <- paste0("area_halo (", unit, ")")
  names(x_print)[names(x_print) == "area_aoe"] <- paste0("area_aoe (", unit, ")")

  print.data.frame(x_print, row.names = FALSE)

  # Show theoretical ratio based on scale

  scale <- attr(x, "scale")
  if (!is.null(scale)) {
    theoretical_ratio <- (1 + scale)^2 - 1
    cat(sprintf("\nNote: Theoretical halo:core ratio is %.2f (scale=%.3g, no masking)\n",
                theoretical_ratio, scale))
  }

  invisible(x)
}
