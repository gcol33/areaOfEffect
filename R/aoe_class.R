#' Create an aoe_result object
#'
#' Internal constructor for the aoe_result S3 class.
#'
#' @param points An sf data frame with classified points
#' @param geometries A named list of geometry information per support
#' @param n_supports Integer, number of supports processed
#' @param scale Numeric scale factor used (NULL if area mode)
#' @param area Numeric area proportion used (NULL if scale mode)
#'
#' @return An aoe_result object
#' @noRd
new_aoe_result <- function(points, geometries, n_supports, scale = NULL, area = NULL) {
  structure(
    points,
    class = c("aoe_result", class(points)),
    aoe_geometries = geometries,
    aoe_scale = scale,
    aoe_area = area,
    aoe_n_supports = n_supports
  )
}


#' Print method for aoe_result
#'
#' @param x An aoe_result object
#' @param ... Additional arguments passed to print.sf
#'
#' @return Invisibly returns x
#' @export
print.aoe_result <- function(x, ...) {
  n_points <- nrow(x)
  n_supports <- attr(x, "aoe_n_supports")
  n_core <- sum(x$aoe_class == "core", na.rm = TRUE)
  n_halo <- sum(x$aoe_class == "halo", na.rm = TRUE)
  scale <- attr(x, "aoe_scale")
  area <- attr(x, "aoe_area")

  cat("Area of Effect Result\n")
  cat(strrep("\u2500", 21), "\n", sep = "")
  cat(sprintf("Points:   %d (%d core, %d halo)\n", n_points, n_core, n_halo))
  cat(sprintf("Supports: %d\n", n_supports))

  if (!is.null(area)) {
    cat(sprintf("Area:     %.3g (target halo = %.3g x original)\n", area, area))
  } else if (!is.null(scale)) {
    cat(sprintf("Scale:    %.3g (multiplier %.3g, theoretical halo:core %.2f)\n",
                scale, 1 + scale, (1 + scale)^2 - 1))
  }
  cat("\n")

  # Print as sf
  NextMethod()
}


#' Summary method for aoe_result
#'
#' @param object An aoe_result object
#' @param ... Additional arguments (ignored)
#'
#' @return An aoe_summary_result object
#' @export
summary.aoe_result <- function(object, ...) {
  # Use existing aoe_summary logic
  result <- aoe_summary(object)

  # Add area information if geometries available

  geoms <- attr(object, "aoe_geometries")
  if (!is.null(geoms) && length(geoms) > 0) {
    result$area_original <- vapply(geoms, function(g) {
      as.numeric(sf::st_area(g$original))
    }, numeric(1))
    result$area_aoe <- vapply(geoms, function(g) {
      as.numeric(sf::st_area(g$aoe_final))
    }, numeric(1))
    result$area_ratio <- result$area_aoe / result$area_original
  }

  class(result) <- c("aoe_summary_result", "data.frame")
  result
}


#' Print method for aoe_summary_result
#'
#' @param x An aoe_summary_result object
#' @param ... Additional arguments (ignored)
#'
#' @return Invisibly returns x
#' @export
print.aoe_summary_result <- function(x, ...) {
  cat("Area of Effect Summary\n")
  cat(strrep("\u2500", 22), "\n\n", sep = "")

  # Format for display
  print.data.frame(x, row.names = FALSE)

  invisible(x)
}


#' Subset method for aoe_result
#'
#' Preserves aoe_result attributes when subsetting.
#'
#' @param x An aoe_result object
#' @param i Row indices
#' @param ... Additional arguments passed to sf subsetting
#'
#' @return An aoe_result object (or sf if support_id removed)
#' @export
`[.aoe_result` <- function(x, i, ...) {
  result <- NextMethod()

  # Preserve attributes if still a valid aoe_result
  if (inherits(result, "sf") &&
      "aoe_class" %in% names(result) &&
      "support_id" %in% names(result)) {
    # Filter geometries to remaining supports
    remaining_supports <- unique(result$support_id)
    old_geoms <- attr(x, "aoe_geometries")
    new_geoms <- old_geoms[names(old_geoms) %in% as.character(remaining_supports)]

    attr(result, "aoe_geometries") <- new_geoms
    attr(result, "aoe_scale") <- attr(x, "aoe_scale")
    attr(result, "aoe_area") <- attr(x, "aoe_area")
    attr(result, "aoe_n_supports") <- length(remaining_supports)
    class(result) <- c("aoe_result", class(result)[!class(result) == "aoe_result"])
  }

  result
}


#' Plot method for aoe_result
#'
#' Visualize an AoE classification result, showing points colored by class
#' and optionally the support and AoE boundaries.
#'
#' @param x An aoe_result object
#' @param support_id Optional: filter to specific support(s)
#' @param show_aoe Logical; show AoE boundary (default TRUE)
#' @param show_original Logical; show original support boundary (default TRUE)
#' @param col_core Color for core points (default "#2E7D32", green)
#' @param col_halo Color for halo points (default "#F57C00", orange)
#' @param col_original Color for original support boundary (default "#000000")
#' @param col_aoe Color for AoE boundary (default "#9E9E9E")
#' @param pch Point character (default 16)
#' @param cex Point size (default 0.8)
#' @param main Plot title (default auto-generated)
#' @param ... Additional arguments passed to plot
#'
#' @return Invisibly returns x
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
#' set.seed(42)
#' pts <- st_as_sf(
#'   data.frame(id = 1:50),
#'   geometry = st_sfc(lapply(1:50, function(i) {
#'     st_point(c(runif(1, -5, 15), runif(1, -5, 15)))
#'   })),
#'   crs = 32631
#' )
#'
#' result <- aoe(pts, support)
#' plot(result)
#'
#' @export
plot.aoe_result <- function(x,
                            support_id = NULL,
                            show_aoe = TRUE,
                            show_original = TRUE,
                            col_core = "#2E7D32",
                            col_halo = "#F57C00",
                            col_original = "#000000",
                            col_aoe = "#9E9E9E",
                            pch = 16,
                            cex = 0.8,
                            main = NULL,
                            ...) {

  # Filter to support if specified
  if (!is.null(support_id)) {
    x <- x[x$support_id %in% support_id, ]
  }

  geoms <- attr(x, "aoe_geometries")

  # Filter geometries to match filtered data
  if (!is.null(support_id) && !is.null(geoms)) {
    geoms <- geoms[names(geoms) %in% as.character(support_id)]
  }

  # Determine plot extent
  pts_bbox <- sf::st_bbox(x)

  if (!is.null(geoms) && length(geoms) > 0 && show_aoe) {
    aoe_geoms <- do.call(c, lapply(geoms, function(g) g$aoe_final))
    aoe_bbox <- sf::st_bbox(aoe_geoms)
    pts_bbox <- c(
      xmin = min(pts_bbox["xmin"], aoe_bbox["xmin"]),
      ymin = min(pts_bbox["ymin"], aoe_bbox["ymin"]),
      xmax = max(pts_bbox["xmax"], aoe_bbox["xmax"]),
      ymax = max(pts_bbox["ymax"], aoe_bbox["ymax"])
    )
  }

  # Set up plot
  if (is.null(main)) {
    n_sup <- length(unique(x$support_id))
    main <- sprintf("AoE: %d points, %d support%s",
                    nrow(x), n_sup, if (n_sup > 1) "s" else "")
  }

  graphics::plot(1, type = "n",
       xlim = c(pts_bbox["xmin"], pts_bbox["xmax"]),
       ylim = c(pts_bbox["ymin"], pts_bbox["ymax"]),
       asp = 1, main = main, xlab = "", ylab = "", ...)

  # Draw geometries if available
  if (!is.null(geoms) && length(geoms) > 0) {
    if (show_aoe) {
      for (g in geoms) {
        graphics::plot(sf::st_geometry(g$aoe_final),
             border = col_aoe, lty = 2, lwd = 1, add = TRUE)
      }
    }
    if (show_original) {
      for (g in geoms) {
        graphics::plot(sf::st_geometry(g$original),
             border = col_original, lwd = 2, add = TRUE)
      }
    }
  }

  # Draw points
  core_pts <- x[x$aoe_class == "core", ]
  halo_pts <- x[x$aoe_class == "halo", ]

  if (nrow(halo_pts) > 0) {
    graphics::plot(sf::st_geometry(halo_pts),
         col = col_halo, pch = pch, cex = cex, add = TRUE)
  }
  if (nrow(core_pts) > 0) {
    graphics::plot(sf::st_geometry(core_pts),
         col = col_core, pch = pch, cex = cex, add = TRUE)
  }

  # Legend
  graphics::legend("topright",
         legend = c("Core", "Halo", "Original", "AoE"),
         col = c(col_core, col_halo, col_original, col_aoe),
         pch = c(pch, pch, NA, NA),
         lty = c(NA, NA, 1, 2),
         lwd = c(NA, NA, 2, 1),
         bg = "white",
         cex = 0.8)

  invisible(x)
}
