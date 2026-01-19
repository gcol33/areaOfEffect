#' Classify and Prune Points by Area of Effect
#'
#' Given a set of points and one or more support polygons, `aoe()` classifies
#' points as "core" (inside original support) or "halo" (inside the area of
#' effect but outside original support), pruning all points outside.
#'
#' The area of effect is computed by scaling each support outward from its
#' centroid. Scale is fixed at 1 (one full stamp), meaning each point on the
#' support boundary is moved to twice its distance from the centroid.
#'
#' @param points An `sf` object with POINT geometries.
#' @param support An `sf` object with POLYGON or MULTIPOLYGON geometries.
#'   Each row defines a separate support region. When multiple rows are
#'   provided, points are classified against each support independently,
#'   returning long format output where a point may appear multiple times.
#' @param reference Optional `sf` object with a single POINT geometry.
#'   If `NULL` (default), the centroid of each support is used.
#'   Only valid when `support` has a single row.
#' @param mask Optional `sf` object with POLYGON or MULTIPOLYGON geometry.
#'   If provided, each area of effect is intersected with this mask
#'   (e.g., land boundary to exclude sea).
#'
#' @return An `sf` object containing only the supported points, with columns:
#'   \describe{
#'     \item{support_id}{Identifier for which support the classification refers to}
#'     \item{aoe_class}{Classification: `"core"` or `"halo"`}
#'   }
#'   When multiple supports are provided, points may appear multiple times
#'   (once per support whose AoE contains them).
#'
#'   Attribute `"scale"` (always 1) is attached to the result.
#'
#' @details
#' The transformation applies:
#' \deqn{p' = r + 2(p - r)}
#' where \eqn{r} is the reference point (centroid) and \eqn{p} is each vertex
#' of the support boundary.
#'
#' Points exactly on the original support boundary are classified as "core".
#'
#' The support geometry is validated internally using [sf::st_make_valid()].
#'
#' @examples
#' library(sf)
#'
#' # Single support
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
#'     st_point(c(30, 30))
#'   ),
#'   crs = 32631
#' )
#'
#' result <- aoe(pts, support)
#'
#' # Multiple supports (e.g., admin regions)
#' supports <- st_as_sf(
#'   data.frame(region = c("A", "B")),
#'   geometry = st_sfc(
#'     st_polygon(list(cbind(c(0, 10, 10, 0, 0), c(0, 0, 10, 10, 0)))),
#'     st_polygon(list(cbind(c(8, 18, 18, 8, 8), c(0, 0, 10, 10, 0))))
#'   ),
#'   crs = 32631
#' )
#'
#' result <- aoe(pts, supports)
#' # Points near the boundary may appear in both regions' AoE
#'
#' @export
aoe <- function(points, support, reference = NULL, mask = NULL) {
  # Input validation
  validate_inputs(points, support, reference, mask)

  n_supports <- nrow(support)

  # Reference only allowed for single support

  if (!is.null(reference) && n_supports > 1) {
    stop(
      "`reference` can only be provided when `support` has a single row.\n",
      "For multiple supports, each uses its centroid as reference.",
      call. = FALSE
    )
  }

  # Ensure consistent CRS
  target_crs <- sf::st_crs(support)
  points <- sf::st_transform(points, target_crs)

  # Prepare mask once if provided
  mask_geom <- NULL
  if (!is.null(mask)) {
    mask <- sf::st_transform(mask, target_crs)
    mask_geom <- sf::st_union(sf::st_geometry(mask))
    mask_geom <- sf::st_make_valid(mask_geom)
    sf::st_crs(mask_geom) <- target_crs
  }

  # Get support IDs (use row names if available, else row numbers)
  support_ids <- if (!is.null(row.names(support))) {
    row.names(support)
  } else {
    seq_len(n_supports)
  }

  # Process each support
  results <- lapply(seq_len(n_supports), function(i) {
    process_single_support(
      points = points,
      support_row = support[i, ],
      support_id = support_ids[i],
      reference = reference,
      mask_geom = mask_geom,
      target_crs = target_crs
    )
  })

  # Combine results
  result <- do.call(rbind, results)

  if (is.null(result) || nrow(result) == 0) {
    # Return empty sf with correct schema
    result <- points[0, ]
    result$support_id <- character(0)
    result$aoe_class <- character(0)
  }

  # Attach metadata
  attr(result, "scale") <- 1

  # Reset row names to sequential
  row.names(result) <- NULL

  result
}


#' Process a single support region
#'
#' @param points sf POINT object
#' @param support_row Single row from support sf
#' @param support_id Identifier for this support
#' @param reference Optional reference point (sf or NULL)
#' @param mask_geom Prepared mask geometry (sfc or NULL)
#' @param target_crs Target CRS
#'
#' @return sf object with classified points for this support, or NULL if empty
#' @noRd
process_single_support <- function(points, support_row, support_id,
                                   reference, mask_geom, target_crs) {

  # Prepare support geometry
  support_geom <- sf::st_geometry(support_row)[[1]]
  support_geom <- sf::st_sfc(support_geom, crs = target_crs)
  support_geom <- sf::st_make_valid(support_geom)

  # Determine reference point
  if (is.null(reference)) {
    ref_point <- sf::st_centroid(support_geom)
  } else {
    reference <- sf::st_transform(reference, target_crs)
    ref_point <- sf::st_geometry(reference)[[1]]
  }

  # Scale the support (fixed scale = 1, multiplier = 2)
  aoe_geom <- scale_geometry(support_geom, ref_point, multiplier = 2, crs = target_crs)
  aoe_geom <- sf::st_make_valid(aoe_geom)

  # Apply mask if provided
  if (!is.null(mask_geom)) {
    aoe_geom <- sf::st_intersection(aoe_geom, mask_geom)
    aoe_geom <- sf::st_make_valid(aoe_geom)
  }

  # Classify points
  in_original <- as.logical(sf::st_intersects(points, support_geom, sparse = FALSE))
  in_aoe <- as.logical(sf::st_intersects(points, aoe_geom, sparse = FALSE))

  # Prune: keep only points inside AoE
  supported_idx <- which(in_aoe)

  if (length(supported_idx) == 0) {
    return(NULL)
  }

  result <- points[supported_idx, ]
  result$support_id <- support_id
  result$aoe_class <- ifelse(in_original[supported_idx], "core", "halo")

  result
}


#' Validate inputs for aoe()
#'
#' @param points Points input
#' @param support Support input
#' @param reference Reference input
#' @param mask Mask input
#'
#' @return NULL invisibly; raises errors on invalid input
#' @noRd
validate_inputs <- function(points, support, reference, mask) {
  # Check points
  if (!inherits(points, "sf")) {
    stop("`points` must be an sf object", call. = FALSE)
  }
  point_types <- unique(sf::st_geometry_type(points))
  if (!all(point_types %in% c("POINT"))) {
    stop("`points` must contain only POINT geometries", call. = FALSE)
  }

  # Check support
  if (!inherits(support, "sf")) {
    stop("`support` must be an sf object", call. = FALSE)
  }
  support_types <- unique(sf::st_geometry_type(support))
  valid_support <- c("POLYGON", "MULTIPOLYGON")
  if (!all(support_types %in% valid_support)) {
    stop("`support` must contain only POLYGON or MULTIPOLYGON geometries",
         call. = FALSE)
  }

  # Check reference
  if (!is.null(reference)) {
    if (!inherits(reference, "sf") && !inherits(reference, "sfc")) {
      stop("`reference` must be an sf or sfc object", call. = FALSE)
    }
    ref_types <- unique(sf::st_geometry_type(reference))
    if (!all(ref_types %in% c("POINT"))) {
      stop("`reference` must be a POINT geometry", call. = FALSE)
    }
    if (length(sf::st_geometry(reference)) != 1) {
      stop("`reference` must contain exactly one point", call. = FALSE)
    }
  }

  # Check mask
  if (!is.null(mask)) {
    if (!inherits(mask, "sf") && !inherits(mask, "sfc")) {
      stop("`mask` must be an sf or sfc object", call. = FALSE)
    }
    mask_types <- unique(sf::st_geometry_type(mask))
    valid_mask <- c("POLYGON", "MULTIPOLYGON")
    if (!all(mask_types %in% valid_mask)) {
      stop("`mask` must contain only POLYGON or MULTIPOLYGON geometries",
           call. = FALSE)
    }
  }

  invisible(NULL)
}


#' Scale geometry from a reference point
#'
#' @param geom An sfc geometry
#' @param reference An sfg POINT or sfc (the reference point)
#' @param multiplier Numeric scaling multiplier
#' @param crs The CRS to apply to the result
#'
#' @return Scaled sfc geometry with CRS preserved
#' @noRd
scale_geometry <- function(geom, reference, multiplier, crs) {
  ref_coords <- sf::st_coordinates(reference)[1, 1:2]

  # Affine transformation: p' = r + multiplier * (p - r)
  geom_shifted <- geom - ref_coords
  geom_scaled <- geom_shifted * multiplier
  geom_result <- geom_scaled + ref_coords

  # Restore CRS (arithmetic operations strip it)
  sf::st_crs(geom_result) <- crs

  geom_result
}
