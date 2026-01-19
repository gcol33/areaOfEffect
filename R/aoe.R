#' Classify and Prune Points by Area of Effect
#'
#' Given a set of points and one or more support polygons, `aoe()` classifies
#' points as "core" (inside original support) or "halo" (inside the area of
#' effect but outside original support), pruning all points outside.
#'
#' By default, the area of effect is computed using a buffer that produces
#' equal core and halo areas. This means the AoE has twice the area of the
#' original support, split evenly between core (inside) and halo (outside).
#'
#' @param points An `sf` object with POINT geometries.
#' @param support One of:
#'   - `sf` object with POLYGON/MULTIPOLYGON geometries
#'   - Country name or ISO code: `"France"`, `"FR"`, `"FRA"`
#'   - Vector of countries: `c("France", "Germany")`
#'   - Missing: auto-detects countries containing the points
#' @param scale Numeric scale factor (default `sqrt(2) - 1`, approximately 0.414).
#'   Controls the size of the halo relative to the core:
#'   - `sqrt(2) - 1` (default): equal core/halo areas, ratio 1:1
#'   - `1`: area ratio 1:3 (halo is 3x core area)
#'
#'   For `method = "buffer"`, determines the target halo area as
#'   `original_area * ((1 + scale)^2 - 1)`.
#'
#'   For `method = "stamp"`, the multiplier `1 + scale` is applied to distances
#'
#'   from the reference point.
#' @param method Method for computing the area of effect:
#'   - `"buffer"` (default): Uniform buffer around the support boundary.
#'     Robust for any polygon shape. Buffer distance is calculated to achieve
#'     the target halo area.
#'   - `"stamp"`: Scale vertices outward from the centroid (or reference point).
#'     Preserves shape proportions but only guarantees containment for
#'     star-shaped polygons. May leave small gaps for highly concave shapes.
#' @param reference Optional `sf` object with a single POINT geometry.
#'
#'   If `NULL` (default), the centroid of each support is used.
#'   Only valid when `support` has a single row and `method = "stamp"`.
#' @param mask Optional `sf` object with POLYGON or MULTIPOLYGON geometry.
#'   If provided, each area of effect is intersected with this mask
#'   (e.
#'   g., land boundary to exclude sea).
#' @param coords Column names for coordinates when `points` is a data.frame,
#'   e.g. `c("lon", "lat")`. If `NULL`, auto-detects common names.
#'
#' @return An `aoe_result` object (extends `sf`) containing only the supported
#'   points, with columns:
#'   \describe{
#'     \item{point_id}{Original point identifier (row name or index)}
#'     \item{support_id}{Identifier for which support the classification refers to}
#'     \item{aoe_class}{Classification: `"core"` or `"halo"`}
#'   }
#'   When multiple supports are provided, points may appear multiple times
#'   (once per support whose AoE contains them).
#'
#'   The result has S3 methods for `print()`, `summary()`, and `plot()`.
#'   Use `aoe_geometry()` to extract the AoE polygons.
#'
#' @details
#' ## Buffer method (default)
#' Computes a uniform buffer distance \eqn{d} such that the buffered area
#' equals the target. The buffer distance is found by solving:
#' \deqn{\pi d^2 + P \cdot d = A_{target}}
#' where \eqn{P} is the perimeter and \eqn{A_{target}} is the desired halo area.
#'
#' ## Stamp method
#' Applies an affine transformation to each vertex:
#' \deqn{p' = r + (1 + s)(p - r)}
#' where \eqn{r} is the reference point (centroid), \eqn{p} is each vertex,
#' and \eqn{s} is the scale factor. This method preserves shape proportions
#' but only guarantees the AoE contains the original for star-shaped polygons
#' (where the centroid can "see" all boundary points).
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
aoe <- function(points, support = NULL, scale = sqrt(2) - 1, method = c("buffer", "stamp"),
                reference = NULL, mask = NULL, coords = NULL) {
  method <- match.arg(method)
  # Handle support: NULL = auto-detect, character = country lookup
  if (is.null(support) || (is.character(support) && length(support) == 1 && tolower(support) == "auto")) {
    support <- detect_countries(points, coords)
  } else if (is.character(support)) {
    support <- do.call(rbind, lapply(support, get_country))
  }

  # Convert to sf (data.frame assumes support's CRS)
  support <- to_sf(support)
  crs <- sf::st_crs(support)
  points <- to_sf(points, crs, coords)
  reference <- to_sf(reference, crs)
  mask <- to_sf(mask, crs)

  # Input validation
  validate_inputs(points, support, reference, mask)


  # Validate scale

  if (!is.numeric(scale) || length(scale) != 1 || scale <= 0) {
    stop("`scale` must be a single positive number", call. = FALSE)
  }

  n_supports <- nrow(support)


  # Reference only allowed for single support with stamp method
  if (!is.null(reference)) {
    if (method != "stamp") {
      stop(
        "`reference` can only be used with `method = \"stamp\"`.",
        call. = FALSE
      )
    }
    if (n_supports > 1) {
      stop(
        "`reference` can only be provided when `support` has a single row.\n",
        "For multiple supports, each uses its centroid as reference.",
        call. = FALSE
      )
    }
  }

  # Ensure consistent CRS
  target_crs <- sf::st_crs(support)
  points <- sf::st_transform(points, target_crs)

  # Create point IDs from row names or indices
  point_ids <- if (!is.null(row.names(points))) {
    row.names(points)
  } else {
    as.character(seq_len(nrow(points)))
  }
  points$.point_id_internal <- point_ids

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
    as.character(seq_len(n_supports))
  }

  # Compute multiplier from scale
  multiplier <- 1 + scale

  # Process each support and collect geometries
  geometries <- list()

  results <- lapply(seq_len(n_supports), function(i) {
    sid <- support_ids[i]
    processed <- process_single_support(
      points = points,
      support_row = support[i, ],
      support_id = sid,
      method = method,
      scale = scale,
      reference = reference,
      mask_geom = mask_geom,
      target_crs = target_crs,
      multiplier = multiplier
    )

    # Store geometries
    geometries[[sid]] <<- processed$geometries

    processed$points
  })

  # Combine results
  result <- do.call(rbind, results)

  if (is.null(result) || nrow(result) == 0) {
    # Return empty sf with correct schema
    result <- points[0, ]
    result$point_id <- character(0)
    result$support_id <- character(0)
    result$aoe_class <- character(0)
    result$.point_id_internal <- NULL
  } else {
    # Rename internal point_id to point_id and reorder columns
    result$point_id <- result$.point_id_internal
    result$.point_id_internal <- NULL

    # Reorder: point_id, support_id, aoe_class, then original columns
    geom_col <- attr(result, "sf_column")
    other_cols <- setdiff(names(result), c("point_id", "support_id", "aoe_class", geom_col))
    result <- result[, c("point_id", "support_id", "aoe_class", other_cols, geom_col)]
  }

  # Reset row names to sequential
  row.names(result) <- NULL

  # Always return aoe_result (sf-based) for full functionality
  new_aoe_result(result, geometries, n_supports, scale)
}


#' Process a single support region
#'
#' @param points sf POINT object
#' @param support_row Single row from support sf
#' @param support_id Identifier for this support
#' @param method Method for computing AoE ("buffer" or "stamp")
#' @param scale Scale factor for halo area
#' @param reference Optional reference point (sf or NULL)
#' @param mask_geom Prepared mask geometry (sfc or NULL)
#' @param target_crs Target CRS
#' @param multiplier Scaling multiplier (1 + scale)
#'
#' @return A list with:
#'   - `points`: sf object with classified points for this support, or NULL if empty
#'   - `geometries`: list with original, aoe_raw, and aoe_final geometries
#' @noRd
process_single_support <- function(points, support_row, support_id,
                                   method, scale, reference, mask_geom,
                                   target_crs, multiplier) {

  # Prepare support geometry
  support_geom <- sf::st_geometry(support_row)[[1]]
  support_geom <- sf::st_sfc(support_geom, crs = target_crs)
  support_geom <- sf::st_make_valid(support_geom)

  # Compute AoE geometry based on method
  if (method == "buffer") {
    # Buffer method: compute buffer distance for target halo area
    aoe_geom_raw <- buffer_geometry(support_geom, scale = scale, crs = target_crs)
  } else {
    # Stamp method: scale vertices from reference point
    if (is.null(reference)) {
      ref_point <- sf::st_centroid(support_geom)
    } else {
      reference <- sf::st_transform(reference, target_crs)
      ref_point <- sf::st_geometry(reference)[[1]]
    }
    aoe_geom_raw <- scale_geometry(support_geom, ref_point,
                                   multiplier = multiplier, crs = target_crs)
  }
  aoe_geom_raw <- sf::st_make_valid(aoe_geom_raw)

  # Apply mask if provided
  aoe_geom_final <- aoe_geom_raw
  if (!is.null(mask_geom)) {
    aoe_geom_final <- sf::st_intersection(aoe_geom_raw, mask_geom)
    aoe_geom_final <- sf::st_make_valid(aoe_geom_final)
  }

  # Store geometries
  geometries <- list(
    original = support_geom,
    aoe_raw = aoe_geom_raw,
    aoe_final = aoe_geom_final
  )

  # Classify points
  in_original <- as.logical(sf::st_intersects(points, support_geom, sparse = FALSE))
  in_aoe <- as.logical(sf::st_intersects(points, aoe_geom_final, sparse = FALSE))

  # Prune: keep only points inside AoE
  supported_idx <- which(in_aoe)

  if (length(supported_idx) == 0) {
    return(list(points = NULL, geometries = geometries))
  }

  result <- points[supported_idx, ]
  result$support_id <- support_id
  result$aoe_class <- ifelse(in_original[supported_idx], "core", "halo")

  list(points = result, geometries = geometries)
}


#' Auto-detect countries containing points
#' @noRd
detect_countries <- function(points, coords) {
  pts_sf <- to_sf(points, sf::st_crs(4326), coords)
  pts_sf <- sf::st_transform(pts_sf, 4326)
  hits <- lengths(sf::st_intersects(countries, pts_sf)) > 0
  if (!any(hits)) stop("No countries contain the provided points", call. = FALSE)
  result <- countries[hits, ]
  message("Countries: ", paste(result$name, collapse = ", "))
  result
}

#' Convert to sf
#' @noRd
to_sf <- function(x, crs = NULL, coords = NULL) {
  if (is.null(x)) return(NULL)
  if (inherits(x, "Spatial")) return(sf::st_as_sf(x))
  if (is.data.frame(x) && !inherits(x, "sf")) {
    if (is.null(coords)) {
      coords <- detect_coords(names(x))
      if (is.null(coords)) {
        stop("Cannot detect coordinate columns. Use coords = c('x', 'y')", call. = FALSE)
      }
    }
    return(sf::st_as_sf(x, coords = coords, crs = crs))
  }
  x
}

#' Detect coordinate columns
#' @noRd
detect_coords <- function(nms) {
  nms_lower <- tolower(nms)
  # Try common pairs
  pairs <- list(
    c("x", "y"), c("lon", "lat"), c("longitude", "latitude"),
    c("lng", "lat"), c("long", "lat"), c("easting", "northing")
  )
  for (p in pairs) {
    idx <- match(p, nms_lower)
    if (!anyNA(idx)) return(nms[idx])
  }
  NULL
}

#' Convert sf to sp
#' @noRd
#' @importFrom methods as
to_sp <- function(x) {
  as(x, "Spatial")
}

#' Convert sf to data.frame with coordinates
#' @noRd
to_df <- function(x) {
  coords <- sf::st_coordinates(x)
  df <- sf::st_drop_geometry(x)
  df$x <- coords[, 1]
  df$y <- coords[, 2]
  df
}

#' Validate inputs for aoe()
#' @noRd
validate_inputs <- function(points, support, reference, mask) {
  # Check points
  if (!inherits(points, "sf")) {
    stop("`points` must be an sf object (use st_as_sf() to convert)", call. = FALSE)
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


#' Buffer geometry to achieve target halo area
#'
#' Computes a buffer distance that produces a halo with the target area.
#' Uses binary search to find the exact buffer distance, since the analytical
#' formula (quadratic) is only approximate for concave shapes.
#'
#' @param geom An sfc geometry
#' @param scale Scale factor (halo area = original_area * ((1 + scale)^2 - 1))
#' @param crs The CRS to apply to the result
#'
#' @return Buffered sfc geometry with CRS preserved
#' @noRd
buffer_geometry <- function(geom, scale, crs) {
  # Calculate target total area (original + halo)
  original_area <- as.numeric(sf::st_area(geom))
  multiplier <- 1 + scale
  target_total_area <- original_area * multiplier^2

  # Use quadratic formula for initial estimate
  target_halo_area <- original_area * (multiplier^2 - 1)
  boundary <- sf::st_cast(geom, "MULTILINESTRING")
  perimeter <- as.numeric(sf::st_length(boundary))
  discriminant <- perimeter^2 + 4 * pi * target_halo_area
  initial_dist <- (-perimeter + sqrt(discriminant)) / (2 * pi)

  # Binary search to find exact buffer distance
  # Start with bounds around the initial estimate
  low <- initial_dist * 0.5
  high <- initial_dist * 2.0
  tolerance <- target_total_area * 0.0001  # 0.01% tolerance

  for (i in 1:50) {  # Max 50 iterations
    mid <- (low + high) / 2
    buffered <- sf::st_buffer(geom, mid)
    current_area <- as.numeric(sf::st_area(buffered))

    if (abs(current_area - target_total_area) < tolerance) {
      break
    }

    if (current_area < target_total_area) {
      low <- mid
    } else {
      high <- mid
    }
  }

  # Final buffer with found distance
  geom_result <- sf::st_buffer(geom, mid)

  # Ensure CRS is set
  sf::st_crs(geom_result) <- crs

  geom_result
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
