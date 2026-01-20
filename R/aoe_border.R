#' Classify Points by Distance from a Border
#'
#' Given a set of points and a border (line), `aoe_border()` classifies
#' points by their side relative to the border and their distance from it.
#' Creates equal-area buffer zones on both sides of the border.
#'
#' @param points An `sf` object with POINT geometries, or a data.frame with
#'   coordinate columns.
#' @param border An `sf` object with LINESTRING or MULTILINESTRING geometry
#'   representing the border.
#' @param width Buffer width in meters (for projected CRS) or degrees (for
#'   geographic CRS). Creates core zone within this distance of the border.
#'   Cannot be used together with `area`.
#' @param area Target area for each side's core zone. The function finds the
#'   buffer width that produces this area per side. If `mask` is provided,
#'   the width is adjusted to achieve the target area *after* masking.
#'   Cannot be used together with `width`.
#' @param halo_width Width of the halo zone beyond the core. If `NULL`
#'   (default), equals the core width for symmetric zones.
#' @param halo_area Target area for each side's halo zone. Alternative to
#'   `halo_width`. If `NULL` and `halo_width` is `NULL`, defaults to equal
#'   area as core.
#' @param mask Optional mask for clipping the buffer zones. Can be:
#'   - `sf` object with POLYGON or MULTIPOLYGON geometry
#'   - `"land"`: use the bundled global land mask to exclude sea areas
#' @param bbox Optional bounding box to limit the study area. Can be:
#'   - `sf` or `sfc` object (uses its bounding box)
#'   - Named vector: `c(xmin = ..., ymin = ..., xmax = ..., ymax = ...)`
#'   - `NULL`: no bbox restriction (uses buffer extent)
#' @param side_names Character vector of length 2 naming the sides.
#'   Default is `c("side_1", "side_2")`. The first name is assigned to
#'   the left side of the border (when traversing from start to end).
#' @param coords Column names for coordinates when `points` is a data.frame.
#'
#' @return An `aoe_border_result` object (extends `sf`) containing classified
#'   points with columns:
#'   \describe{
#'     \item{point_id}{Original point identifier}
#'     \item{side}{Which side of the border: value from `side_names`}
#'     \item{aoe_class}{Distance class: `"core"` or `"halo"`}
#'   }
#'   Points outside the study area are pruned (not returned).
#'
#' @details
#' The function creates symmetric buffer zones around a border line:
#'
#' 1. **Core zone**: Points within `width` (or `area`) distance of the border
#' 2. **Halo zone**: Points beyond core but within `width + halo_width`
#' 3. **Pruned**: Points outside the halo zone (not returned)
#'
#' Each zone is split by the border line to determine which side the point
#' falls on.
#'
#' ## Equal area across sides
#' When using the `area` parameter, the buffer width is calculated to produce
#' equal area on both sides of the border. With masking, the width is adjusted
#' so that the *masked* area on each side equals the target.
#'
#' @examples
#' library(sf)
#'
#' # Create a border line
#' border <- st_as_sf(
#'   data.frame(id = 1),
#'   geometry = st_sfc(st_linestring(matrix(
#'     c(0, 0, 100, 100), ncol = 2, byrow = TRUE
#'   ))),
#'   crs = 32631
#' )
#'
#' # Create points
#' pts <- st_as_sf(
#'   data.frame(id = 1:6),
#'   geometry = st_sfc(
#'     st_point(c(10, 20)),   # near border, side 1
#'     st_point(c(30, 10)),   # near border, side 2
#'     st_point(c(50, 80)),   # far from border, side 1
#'     st_point(c(80, 40)),   # far from border, side 2
#'     st_point(c(5, 5)),     # very close to border
#'     st_point(c(200, 200))  # outside study area
#'   ),
#'   crs = 32631
#' )
#'
#' # Classify by distance from border
#' result <- aoe_border(pts, border, width = 20)
#'
#' @importFrom grDevices rgb
#' @importFrom graphics legend
#' @export
aoe_border <- function(points, border, width = NULL, area = NULL,
                       halo_width = NULL, halo_area = NULL,
                       mask = NULL, bbox = NULL,
                       side_names = c("side_1", "side_2"),
                       coords = NULL) {

  # Input validation
  if (!inherits(border, "sf") && !inherits(border, "sfc")) {
    stop("`border` must be an sf or sfc object with LINESTRING geometry", call. = FALSE)
  }

  # Handle mask: "land" = use global land mask
  if (is.character(mask) && length(mask) == 1 && tolower(mask) == "land") {
    mask <- land
  }

  # Convert inputs to sf
  border <- to_sf(border)
  crs <- sf::st_crs(border)
  points <- to_sf(points, crs, coords)
  mask <- to_sf(mask, crs)

  # Validate geometry types
  border_type <- unique(sf::st_geometry_type(border))
  if (!all(border_type %in% c("LINESTRING", "MULTILINESTRING"))) {
    stop("`border` must have LINESTRING or MULTILINESTRING geometry", call. = FALSE)
  }

  if (!all(sf::st_geometry_type(points) == "POINT")) {
    stop("`points` must have POINT geometry", call. = FALSE)
  }

  # Validate width/area parameters
  if (!is.null(width) && !is.null(area)) {
    stop("Cannot specify both `width` and `area`. Use one or the other.", call. = FALSE)
  }

  if (is.null(width) && is.null(area)) {
    stop("Must specify either `width` or `area`", call. = FALSE)
  }

  if (!is.null(halo_width) && !is.null(halo_area)) {
    stop("Cannot specify both `halo_width` and `halo_area`.", call. = FALSE)
  }

  # Validate side_names
  if (length(side_names) != 2) {
    stop("`side_names` must be a character vector of length 2", call. = FALSE)
  }

  # Create point IDs
  point_ids <- if (!is.null(row.names(points))) {
    row.names(points)
  } else {
    as.character(seq_len(nrow(points)))
  }
  points$.point_id_internal <- point_ids

  # Prepare mask
  mask_geom <- NULL
  if (!is.null(mask)) {
    mask <- sf::st_transform(mask, crs)
    mask_geom <- sf::st_union(sf::st_geometry(mask))
    mask_geom <- sf::st_make_valid(mask_geom)
    sf::st_crs(mask_geom) <- crs
  }

  # Union border geometry
  border_geom <- sf::st_union(sf::st_geometry(border))
  border_geom <- sf::st_make_valid(border_geom)

  # Calculate core width
  if (!is.null(width)) {
    core_width <- width
  } else {
    # Find width that gives target area per side
    core_width <- find_border_width(border_geom, area, mask_geom, crs)
  }

  # Calculate halo width
  if (!is.null(halo_width)) {
    halo_w <- halo_width
  } else if (!is.null(halo_area)) {
    # Find additional width for halo
    halo_w <- find_halo_width(border_geom, core_width, halo_area, mask_geom, crs)
  } else {
    # Default: halo width equals core width (equal areas without masking)
    halo_w <- core_width
  }

  total_width <- core_width + halo_w

  # Create buffer zones
  core_buffer <- sf::st_buffer(border_geom, core_width)
  total_buffer <- sf::st_buffer(border_geom, total_width)

  # Apply bbox if provided
  if (!is.null(bbox)) {
    bbox_poly <- bbox_to_polygon(bbox, crs)
    core_buffer <- sf::st_intersection(core_buffer, bbox_poly)
    total_buffer <- sf::st_intersection(total_buffer, bbox_poly)
  }

  # Apply mask if provided
  if (!is.null(mask_geom)) {
    core_buffer <- sf::st_intersection(core_buffer, mask_geom)
    total_buffer <- sf::st_intersection(total_buffer, mask_geom)
  }

  core_buffer <- sf::st_make_valid(core_buffer)
  total_buffer <- sf::st_make_valid(total_buffer)

  # Split buffers by the border line to get two sides
  # Use a thin buffer around the line to create a splitting polygon
  split_result_core <- split_by_line(core_buffer, border_geom, crs)
  split_result_total <- split_by_line(total_buffer, border_geom, crs)

  side1_core <- split_result_core$side1
  side2_core <- split_result_core$side2
  side1_total <- split_result_total$side1
  side2_total <- split_result_total$side2

  # Halo = total minus core
  side1_halo <- sf::st_difference(side1_total, side1_core)
  side2_halo <- sf::st_difference(side2_total, side2_core)

  # Make valid after difference
  side1_halo <- sf::st_make_valid(side1_halo)
  side2_halo <- sf::st_make_valid(side2_halo)

  # Classify points
  result_list <- list()

  # Check each point
  for (i in seq_len(nrow(points))) {
    pt <- points[i, ]
    pt_geom <- sf::st_geometry(pt)

    # Determine side and class
    in_side1_core <- isTRUE(sf::st_intersects(pt_geom, side1_core, sparse = FALSE)[1, 1])
    in_side2_core <- isTRUE(sf::st_intersects(pt_geom, side2_core, sparse = FALSE)[1, 1])
    in_side1_halo <- isTRUE(sf::st_intersects(pt_geom, side1_halo, sparse = FALSE)[1, 1])
    in_side2_halo <- isTRUE(sf::st_intersects(pt_geom, side2_halo, sparse = FALSE)[1, 1])

    if (in_side1_core) {
      pt$side <- side_names[1]
      pt$aoe_class <- "core"
      result_list[[length(result_list) + 1]] <- pt
    } else if (in_side2_core) {
      pt$side <- side_names[2]
      pt$aoe_class <- "core"
      result_list[[length(result_list) + 1]] <- pt
    } else if (in_side1_halo) {
      pt$side <- side_names[1]
      pt$aoe_class <- "halo"
      result_list[[length(result_list) + 1]] <- pt
    } else if (in_side2_halo) {
      pt$side <- side_names[2]
      pt$aoe_class <- "halo"
      result_list[[length(result_list) + 1]] <- pt
    }
    # Otherwise pruned (not added)
  }

  # Combine results
  if (length(result_list) == 0) {
    result <- points[0, ]
    result$point_id <- character(0)
    result$side <- character(0)
    result$aoe_class <- character(0)
    result$.point_id_internal <- NULL
  } else {
    result <- do.call(rbind, result_list)
    result$point_id <- result$.point_id_internal
    result$.point_id_internal <- NULL

    # Reorder columns
    geom_col <- attr(result, "sf_column")
    other_cols <- setdiff(names(result), c("point_id", "side", "aoe_class", geom_col))
    result <- result[, c("point_id", "side", "aoe_class", other_cols, geom_col)]
  }

  row.names(result) <- NULL

  # Store geometries for plotting/analysis
  geometries <- list(
    border = border_geom,
    side1_core = side1_core,
    side2_core = side2_core,
    side1_halo = side1_halo,
    side2_halo = side2_halo,
    side_names = side_names
  )

  # Create result object
  class(result) <- c("aoe_border_result", class(result))
  attr(result, "border_geometries") <- geometries
  attr(result, "core_width") <- core_width
  attr(result, "halo_width") <- halo_w
  attr(result, "area") <- area
  attr(result, "halo_area") <- halo_area

  result
}


#' Find buffer width that produces target area per side
#'
#' @param border_geom Border line geometry (sfc)
#' @param target_area Target area for each side
#' @param mask_geom Optional mask geometry
#' @param crs CRS of the geometries
#'
#' @return Buffer width
#' @keywords internal
find_border_width <- function(border_geom, target_area, mask_geom, crs) {
  # Binary search for the width that gives target area
  # Initial guess based on line length
  line_length <- as.numeric(sf::st_length(border_geom))

  # For a line of length L, buffer width w gives approximate area 2*L*w per side
  # So initial guess: w = target_area / (2 * L)
  w_guess <- target_area / (2 * line_length)

  # Binary search bounds
  w_low <- w_guess / 10
  w_high <- w_guess * 10

  for (iter in 1:50) {
    w_mid <- (w_low + w_high) / 2

    # Calculate area at this width
    buffer <- sf::st_buffer(border_geom, w_mid)
    if (!is.null(mask_geom)) {
      buffer <- sf::st_intersection(buffer, mask_geom)
    }
    buffer <- sf::st_make_valid(buffer)

    # Split and get area of one side
    split_result <- split_by_line(buffer, border_geom, crs)
    area_side1 <- as.numeric(sf::st_area(split_result$side1))

    # Check convergence
    if (abs(area_side1 - target_area) / target_area < 0.01) {
      return(w_mid)
    }

    if (area_side1 < target_area) {
      w_low <- w_mid
    } else {
      w_high <- w_mid
    }
  }

  warning("Width search did not fully converge", call. = FALSE)
  w_mid
}


#' Find additional halo width for target halo area
#'
#' @param border_geom Border line geometry
#' @param core_width Width of core zone
#' @param target_halo_area Target area for halo per side
#' @param mask_geom Optional mask geometry
#' @param crs CRS
#'
#' @return Additional width for halo
#' @keywords internal
find_halo_width <- function(border_geom, core_width, target_halo_area, mask_geom, crs) {
  # Similar binary search for halo width
  line_length <- as.numeric(sf::st_length(border_geom))

  # Initial guess
  w_guess <- target_halo_area / (2 * line_length)
  w_low <- w_guess / 10
  w_high <- w_guess * 10

  for (iter in 1:50) {
    w_mid <- (w_low + w_high) / 2
    total_width <- core_width + w_mid

    # Calculate halo area
    core_buffer <- sf::st_buffer(border_geom, core_width)
    total_buffer <- sf::st_buffer(border_geom, total_width)

    if (!is.null(mask_geom)) {
      core_buffer <- sf::st_intersection(core_buffer, mask_geom)
      total_buffer <- sf::st_intersection(total_buffer, mask_geom)
    }

    core_buffer <- sf::st_make_valid(core_buffer)
    total_buffer <- sf::st_make_valid(total_buffer)

    split_core <- split_by_line(core_buffer, border_geom, crs)
    split_total <- split_by_line(total_buffer, border_geom, crs)

    halo_side1 <- sf::st_difference(split_total$side1, split_core$side1)
    halo_side1 <- sf::st_make_valid(halo_side1)
    area_halo1 <- as.numeric(sf::st_area(halo_side1))

    if (abs(area_halo1 - target_halo_area) / target_halo_area < 0.01) {
      return(w_mid)
    }

    if (area_halo1 < target_halo_area) {
      w_low <- w_mid
    } else {
      w_high <- w_mid
    }
  }

  warning("Halo width search did not fully converge", call. = FALSE)
  w_mid
}


#' Split a polygon by a line into two sides
#'
#' @param polygon Polygon geometry to split
#' @param line Line geometry to split by
#' @param crs CRS
#'
#' @return List with side1 and side2 geometries
#' @keywords internal
split_by_line <- function(polygon, line, crs) {
  # Create a very large polygon that spans the extent
  bbox <- sf::st_bbox(polygon)
  expand <- max(bbox["xmax"] - bbox["xmin"], bbox["ymax"] - bbox["ymin"]) * 2

  # Get line endpoints and extend
  line_coords <- sf::st_coordinates(line)

  # Create perpendicular offset polygons on each side of the line
  # Use st_buffer with single side (not available in sf, so use workaround)

  # Alternative: create a blade polygon from the line and split
  # Buffer the line slightly and use that to create two half-planes

  # Simpler approach: use sf::st_split if available, otherwise use blade method
  tryCatch({
    # Try using lwgeom::st_split if available
    if (requireNamespace("lwgeom", quietly = TRUE)) {
      split_geom <- lwgeom::st_split(polygon, line)
      parts <- sf::st_collection_extract(split_geom, "POLYGON")

      if (length(parts) >= 2) {
        # Assign to sides based on centroid position relative to line
        centroids <- sf::st_centroid(parts)
        # Determine which side each part is on
        # Use signed distance or cross product
        side_assignments <- determine_sides(centroids, line)

        side1_idx <- which(side_assignments == 1)
        side2_idx <- which(side_assignments == 2)

        side1 <- sf::st_union(parts[side1_idx])
        side2 <- sf::st_union(parts[side2_idx])

        return(list(side1 = side1, side2 = side2))
      }
    }

    # Fallback: use buffer-based splitting
    split_by_buffer(polygon, line, crs)

  }, error = function(e) {
    # Fallback
    split_by_buffer(polygon, line, crs)
  })
}


#' Determine which side of a line each point is on
#'
#' @param points Points to classify
#' @param line Line geometry
#'
#' @return Vector of side assignments (1 or 2)
#' @keywords internal
determine_sides <- function(points, line) {
  # Get line direction
  coords <- sf::st_coordinates(line)

  # Use first and last points to determine line direction
  p1 <- coords[1, c("X", "Y")]
  p2 <- coords[nrow(coords), c("X", "Y")]

  # Direction vector
  dx <- p2["X"] - p1["X"]
  dy <- p2["Y"] - p1["Y"]

  # For each point, compute cross product to determine side
  pt_coords <- sf::st_coordinates(points)

  sides <- sapply(seq_len(nrow(pt_coords)), function(i) {
    px <- pt_coords[i, "X"] - p1["X"]
    py <- pt_coords[i, "Y"] - p1["Y"]

    # Cross product: dx*py - dy*px
    cross <- dx * py - dy * px

    if (cross >= 0) 1 else 2
  })

  sides
}


#' Split polygon using buffer method (fallback)
#'
#' @param polygon Polygon to split
#' @param line Line to split by
#' @param crs CRS
#'
#' @return List with side1 and side2
#' @keywords internal
split_by_buffer <- function(polygon, line, crs) {
  # Create a thin blade along the line
  blade_width <- 0.001 # Very thin

  # Get bounding box and create half-planes
  bbox <- sf::st_bbox(polygon)
  expand <- max(bbox["xmax"] - bbox["xmin"], bbox["ymax"] - bbox["ymin"]) * 3

  # Get line endpoints
  coords <- sf::st_coordinates(line)
  p1 <- coords[1, c("X", "Y")]
  p2 <- coords[nrow(coords), c("X", "Y")]

  # Direction and perpendicular
  dx <- p2["X"] - p1["X"]
  dy <- p2["Y"] - p1["Y"]
  len <- sqrt(dx^2 + dy^2)
  dx <- dx / len
  dy <- dy / len

  # Perpendicular direction
  px <- -dy
  py <- dx

  # Create two half-plane polygons
  # Side 1: offset in perpendicular direction
  # Side 2: offset in opposite perpendicular direction

  # Extend line endpoints far beyond bbox
  ext1 <- c(p1["X"] - dx * expand, p1["Y"] - dy * expand)
  ext2 <- c(p2["X"] + dx * expand, p2["Y"] + dy * expand)

  # Create side 1 polygon (perpendicular offset)
  side1_poly <- sf::st_polygon(list(rbind(
    ext1,
    ext2,
    c(ext2[1] + px * expand * 2, ext2[2] + py * expand * 2),
    c(ext1[1] + px * expand * 2, ext1[2] + py * expand * 2),
    ext1
  )))
  side1_poly <- sf::st_sfc(side1_poly, crs = crs)

  # Create side 2 polygon (opposite perpendicular)
  side2_poly <- sf::st_polygon(list(rbind(
    ext1,
    ext2,
    c(ext2[1] - px * expand * 2, ext2[2] - py * expand * 2),
    c(ext1[1] - px * expand * 2, ext1[2] - py * expand * 2),
    ext1
  )))
  side2_poly <- sf::st_sfc(side2_poly, crs = crs)

  # Intersect with original polygon
  side1 <- sf::st_intersection(polygon, side1_poly)
  side2 <- sf::st_intersection(polygon, side2_poly)

  side1 <- sf::st_make_valid(side1)
  side2 <- sf::st_make_valid(side2)

  list(side1 = side1, side2 = side2)
}


#' Convert bbox to polygon
#'
#' @param bbox Bounding box (sf, sfc, or named vector)
#' @param crs CRS to use
#'
#' @return sfc polygon
#' @keywords internal
bbox_to_polygon <- function(bbox, crs) {
  if (inherits(bbox, "sf") || inherits(bbox, "sfc")) {
    bbox <- sf::st_bbox(bbox)
  }

  poly <- sf::st_as_sfc(bbox)
  sf::st_crs(poly) <- crs
  poly
}


#' Print method for aoe_border_result
#'
#' @param x An aoe_border_result object
#' @param ... Additional arguments (ignored)
#'
#' @return Invisibly returns x
#' @export
print.aoe_border_result <- function(x, ...) {
  geoms <- attr(x, "border_geometries")
  side_names <- geoms$side_names

  n_total <- nrow(x)
  n_side1 <- sum(x$side == side_names[1])
  n_side2 <- sum(x$side == side_names[2])
  n_core <- sum(x$aoe_class == "core")
  n_halo <- sum(x$aoe_class == "halo")

  cat("Border AoE Result\n")
  cat(strrep("\u2500", 17), "\n", sep = "")
  cat(sprintf("Points: %d (%s: %d, %s: %d)\n",
              n_total, side_names[1], n_side1, side_names[2], n_side2))
  cat(sprintf("Classification: %d core, %d halo\n", n_core, n_halo))

  core_width <- attr(x, "core_width")
  halo_width <- attr(x, "halo_width")
  cat(sprintf("Core width: %.1f, Halo width: %.1f\n", core_width, halo_width))

  cat("\n")
  NextMethod()
}


#' Plot method for aoe_border_result
#'
#' @param x An aoe_border_result object
#' @param ... Additional arguments passed to plot
#'
#' @return NULL (called for side effect)
#' @export
plot.aoe_border_result <- function(x, ...) {
  geoms <- attr(x, "border_geometries")
  side_names <- geoms$side_names

  # Set up colors
  col_side1_core <- rgb(0.2, 0.4, 0.8, 0.3)
  col_side2_core <- rgb(0.8, 0.4, 0.2, 0.3)
  col_side1_halo <- rgb(0.2, 0.4, 0.8, 0.15)
  col_side2_halo <- rgb(0.8, 0.4, 0.2, 0.15)

  # Plot halos first (background)
  plot(geoms$side1_halo, col = col_side1_halo, border = NA, ...)
  plot(geoms$side2_halo, col = col_side2_halo, border = NA, add = TRUE)

  # Plot cores
  plot(geoms$side1_core, col = col_side1_core, border = NA, add = TRUE)
  plot(geoms$side2_core, col = col_side2_core, border = NA, add = TRUE)

  # Plot border
  plot(geoms$border, col = "black", lwd = 2, add = TRUE)

  # Plot points
  if (nrow(x) > 0) {
    pt_cols <- ifelse(x$side == side_names[1], "steelblue", "darkorange")
    pt_pch <- ifelse(x$aoe_class == "core", 16, 1)
    plot(sf::st_geometry(x), col = pt_cols, pch = pt_pch, cex = 1.2, add = TRUE)
  }

  # Legend
  legend("topright",
         legend = c(
           paste(side_names[1], "(core)"),
           paste(side_names[1], "(halo)"),
           paste(side_names[2], "(core)"),
           paste(side_names[2], "(halo)"),
           "Border"
         ),
         fill = c(col_side1_core, col_side1_halo, col_side2_core, col_side2_halo, NA),
         border = c(NA, NA, NA, NA, NA),
         col = c(NA, NA, NA, NA, "black"),
         lwd = c(NA, NA, NA, NA, 2),
         bty = "n")

  invisible(NULL)
}


#' Stratified Sampling from Border AoE Results
#'
#' Sample points from an `aoe_border_result` with control over side and/or
#' core/halo balance.
#'
#' @param x An `aoe_border_result` object returned by [aoe_border()].
#' @param n Total number of points to sample. If `NULL`, uses all available
#'   points subject to the ratio constraint.
#' @param ratio Named numeric vector specifying target proportions. Names
#'   should match the side names used in `aoe_border()` (e.g.,
#'   `c(side_1 = 0.5, side_2 = 0.5)`) or use `c(core = 0.5, halo = 0.5)`
#'   for distance-based sampling. Must sum to 1.
#' @param by Character. What to stratify by:
#'   - `"side"` (default): sample by side of the border
#'   - `"class"`: sample by core/halo classification
#' @param replace Logical. Sample with replacement? Default is `FALSE`.
#' @param ... Additional arguments (ignored).
#'
#' @return An `aoe_border_result` object containing the sampled points.
#'
#' @examples
#' \dontrun{
#' result <- aoe_border(pts, border, width = 1000,
#'                      side_names = c("west", "east"))
#'
#' # Equal sampling from each side
#' balanced <- aoe_sample(result, ratio = c(west = 0.5, east = 0.5))
#'
#' # Sample by core/halo instead
#' by_class <- aoe_sample(result, ratio = c(core = 0.5, halo = 0.5),
#'                        by = "class")
#' }
#'
#' @importFrom stats setNames
#' @export
aoe_sample.aoe_border_result <- function(x, n = NULL,
                                          ratio = NULL,
                                          by = c("side", "class"),
                                          replace = FALSE,
                                          ...) {
  by <- match.arg(by)
  geoms <- attr(x, "border_geometries")
  side_names <- geoms$side_names

 # Set default ratio based on 'by'
  if (is.null(ratio)) {
    if (by == "side") {
      ratio <- setNames(c(0.5, 0.5), side_names)
    } else {
      ratio <- c(core = 0.5, halo = 0.5)
    }
  }

  # Validate ratio
  if (!is.numeric(ratio) || length(ratio) != 2) {
    stop("`ratio` must be a numeric vector of length 2", call. = FALSE)
  }
  if (abs(sum(ratio) - 1) > 1e-10) {
    stop("`ratio` must sum to 1", call. = FALSE)
  }
  if (any(ratio < 0)) {
    stop("`ratio` values must be non-negative", call. = FALSE)
  }

  # Determine stratification column and validate names
 if (by == "side") {
    strat_col <- "side"
    if (is.null(names(ratio))) {
      names(ratio) <- side_names
    }
    if (!all(names(ratio) %in% side_names)) {
      stop(sprintf("`ratio` names must match side names: '%s' and '%s'",
                   side_names[1], side_names[2]), call. = FALSE)
    }
    ratio <- ratio[side_names]  # ensure order
  } else {
    strat_col <- "aoe_class"
    if (is.null(names(ratio))) {
      names(ratio) <- c("core", "halo")
    }
    if (!all(c("core", "halo") %in% names(ratio))) {
      stop("`ratio` must have names 'core' and 'halo'", call. = FALSE)
    }
    ratio <- ratio[c("core", "halo")]
  }

  if (nrow(x) == 0) {
    return(x)
  }

  # Get indices for each stratum
  strat_values <- names(ratio)
  is_group1 <- x[[strat_col]] == strat_values[1]
  n_group1 <- sum(is_group1)
  n_group2 <- sum(!is_group1)

  group1_idx <- which(is_group1)
  group2_idx <- which(!is_group1)

  if (is.null(n)) {
    # Balanced downsampling
    if (ratio[1] > 0 && ratio[2] > 0) {
      max_n_from_g1 <- n_group1 / ratio[1]
      max_n_from_g2 <- n_group2 / ratio[2]
      n <- floor(min(max_n_from_g1, max_n_from_g2))
    } else if (ratio[1] == 0) {
      n <- n_group2
    } else {
      n <- n_group1
    }
  }

  # Calculate targets
  target_g1 <- round(n * ratio[1])
  target_g2 <- n - target_g1

  # Adjust for availability
  if (!replace) {
    actual_g1 <- min(target_g1, n_group1)
    actual_g2 <- min(target_g2, n_group2)
  } else {
    actual_g1 <- target_g1
    actual_g2 <- target_g2
  }

  # Sample
  sampled_g1 <- if (actual_g1 > 0 && length(group1_idx) > 0) {
    sample(group1_idx, actual_g1, replace = replace)
  } else {
    integer(0)
  }

  sampled_g2 <- if (actual_g2 > 0 && length(group2_idx) > 0) {
    sample(group2_idx, actual_g2, replace = replace)
  } else {
    integer(0)
  }

  sampled_idx <- c(sampled_g1, sampled_g2)

  if (length(sampled_idx) == 0) {
    result <- x[0, ]
  } else {
    result <- x[sampled_idx, ]
  }

  # Preserve class and attributes
  class(result) <- class(x)
  for (att in c("border_geometries", "core_width", "halo_width", "area", "halo_area")) {
    attr(result, att) <- attr(x, att)
  }

  # Add sample info
  info <- list()
  info[[paste0("n_", strat_values[1], "_available")]] <- n_group1
  info[[paste0("n_", strat_values[2], "_available")]] <- n_group2
  info[[paste0("n_", strat_values[1], "_sampled")]] <- length(sampled_g1)
  info[[paste0("n_", strat_values[2], "_sampled")]] <- length(sampled_g2)
  attr(result, "sample_info") <- as.data.frame(info)

  result
}
