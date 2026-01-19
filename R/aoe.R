#' Classify and Prune Points by Area of Effect
#'
#' Given a set of points and a support polygon, `aoe()` classifies points as
#' "core" (inside original support) or "halo" (inside the area of effect but
#' outside original support), pruning all points outside the area of effect.
#'
#' The area of effect is computed by scaling the support outward from a

#' reference point. Scale is fixed at 1 (one full stamp), meaning each point
#' on the support boundary is moved to twice its distance from the reference.
#'
#' @param points An `sf` object with POINT geometries.
#' @param support An `sf` object with POLYGON or MULTIPOLYGON geometry.
#'   If multiple features, they are unioned into a single support.
#' @param reference Optional `sf` object with a single POINT geometry.
#'   If `NULL` (default), the centroid of the support is used.
#' @param mask Optional `sf` object with POLYGON or MULTIPOLYGON geometry.
#'   If provided, the area of effect is intersected with this mask
#'   (e.g., land boundary to exclude sea).
#'
#' @return An `sf` object containing only the supported points, with an
#'   additional column `aoe_class` indicating `"core"` or `"halo"`.
#'   Attributes `"scale"` and `"reference"` are attached to the result.
#'
#' @details
#' The transformation applies:
#' \deqn{p' = r + 2(p - r)}
#' where \eqn{r} is the reference point and \eqn{p} is each vertex of the
#' support boundary.
#'
#' Points exactly on the original support boundary are classified as "core".
#'
#' The support geometry is validated internally using [sf::st_make_valid()].
#'
#' @examples
#' \dontrun{
#' library(sf)
#'
#' # Create example support polygon
#' support <- st_as_sf(
#'   data.frame(id = 1),
#'   geometry = st_sfc(st_polygon(list(
#'     cbind(c(0, 10, 10, 0, 0), c(0, 0, 10, 10, 0))
#'   ))),
#'   crs = 32631
#' )
#'
#' # Create example points
#' pts <- st_as_sf(
#'   data.frame(id = 1:5),
#'   geometry = st_sfc(
#'     st_point(c(5, 5)),    # core (center)
#'     st_point(c(2, 2)),    # core
#'     st_point(c(15, 5)),   # halo
#'     st_point(c(-3, 5)),   # halo
#'     st_point(c(30, 30))   # outside, will be pruned
#'   ),
#'   crs = 32631
#' )
#'
#' result <- aoe(pts, support)
#' }
#'
#' @export
aoe <- function(points, support, reference = NULL, mask = NULL) {
  # Input validation

validate_inputs(points, support, reference, mask)

  # Ensure consistent CRS
  target_crs <- sf::st_crs(support)
  points <- sf::st_transform(points, target_crs)

  # Prepare support: union and validate
  support_geom <- sf::st_union(sf::st_geometry(support))
  support_geom <- sf::st_make_valid(support_geom)
  sf::st_crs(support_geom) <- target_crs

  # Determine reference point
if (is.null(reference)) {
    reference <- sf::st_centroid(support_geom)
  } else {
    reference <- sf::st_transform(reference, target_crs)
    reference <- sf::st_geometry(reference)[[1]]
  }

  # Scale the support (fixed scale = 1, multiplier = 2)
  aoe_geom <- scale_geometry(support_geom, reference, multiplier = 2, crs = target_crs)
  aoe_geom <- sf::st_make_valid(aoe_geom)

  # Apply mask if provided
  if (!is.null(mask)) {
    mask <- sf::st_transform(mask, target_crs)
    mask_geom <- sf::st_union(sf::st_geometry(mask))
    mask_geom <- sf::st_make_valid(mask_geom)
    aoe_geom <- sf::st_intersection(aoe_geom, mask_geom)
    aoe_geom <- sf::st_make_valid(aoe_geom)
  }

  # Classify points
  in_original <- as.logical(sf::st_intersects(points, support_geom, sparse = FALSE))
  in_aoe <- as.logical(sf::st_intersects(points, aoe_geom, sparse = FALSE))

  # Prune: keep only points inside AoE
  supported_idx <- which(in_aoe)

  if (length(supported_idx) == 0) {
    # Return empty sf with correct schema
    result <- points[0, ]
    result$aoe_class <- character(0)
    attr(result, "scale") <- 1
    attr(result, "reference") <- sf::st_sf(
      geometry = sf::st_sfc(reference, crs = target_crs)
    )
    return(result)
  }

  result <- points[supported_idx, ]

  # Classify: core if in original, halo otherwise
  result$aoe_class <- ifelse(in_original[supported_idx], "core", "halo")

  # Attach metadata as attributes
  attr(result, "scale") <- 1
  attr(result, "reference") <- sf::st_sf(
    geometry = sf::st_sfc(reference, crs = target_crs)
  )

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
#' @param reference An sfg POINT (the reference point)
#' @param multiplier Numeric scaling multiplier
#' @param crs The CRS to apply to the result
#'
#' @return Scaled sfc geometry with CRS preserved
#' @noRd
scale_geometry <- function(geom, reference, multiplier, crs) {
  ref_coords <- sf::st_coordinates(reference)

  # Extract the affine transformation:
  # p' = r + multiplier * (p - r)
  # p' = r + multiplier*p - multiplier*r
  # p' = r*(1 - multiplier) + multiplier*p

  # Use sf's affine transformation
  # First translate so reference is at origin
  # Then scale
  # Then translate back

  geom_shifted <- geom - ref_coords
  geom_scaled <- geom_shifted * multiplier
  geom_result <- geom_scaled + ref_coords

  # Restore CRS (arithmetic operations strip it)
  sf::st_crs(geom_result) <- crs

  geom_result
}
