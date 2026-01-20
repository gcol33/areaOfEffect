#' Adaptive AoE Expansion to Capture Minimum Points
#'
#' Expands the area of effect just enough to capture at least `min_points`,
#' subject to hard caps on expansion. This is useful when a fixed scale leaves
#' some supports with insufficient data for stable modelling.
#'
#' Unlike [aoe()], which applies consistent geometry across all supports,
#' `aoe_expand()` adapts the scale per-support based on local point density.
#' Use with caution: this can make AoEs incomparable across regions with
#' different point densities.
#'
#' @inheritParams aoe
#' @param min_points Minimum number of points to capture in the AoE.
#'   The function finds the smallest scale that includes at least this many points.
#' @param max_area Maximum halo area as a proportion of the original support area.
#'   Default is 2, meaning halo area cannot exceed twice the support area
#'   (total AoE <= 3x original). Set to `Inf` to disable.
#' @param max_dist Maximum expansion distance in CRS units. For the buffer method,
#'   this is the maximum buffer distance. For the stamp method, this is converted
#'   to a maximum scale based on the support's characteristic radius.
#'   Default is `NULL` (no distance cap).
#'
#' @return An `aoe_result` object (same as [aoe()]) with additional attributes:
#'   \describe{
#'     \item{target_reached}{Logical: was `min_points` achieved for all supports?
#'       Use `attr(result, "expansion_info")` for per-support details.}
#'     \item{expansion_info}{Data frame with per-support expansion details:
#'       support_id, scale_used, points_captured, target_reached, cap_hit.}
#'   }
#'
#' @details
#' ## Algorithm
#' For each support, binary search finds the minimum scale where point count >= min_points.
#' The search is bounded by:
#' - Lower: scale = 0 (core only)
#' - Upper: minimum of max_area cap and max_dist cap
#'
#' If the caps prevent reaching min_points, a warning is issued and the result
#' uses the maximum allowed scale.
#'
#' ## Caps
#' Two caps ensure AoE doesn't expand unreasonably:
#'
#' **max_area** (relative): Limits halo area to `max_area` times the original.
#' The corresponding scale is `sqrt(1 + max_area) - 1`.
#' Default max_area = 2 means scale <= 0.732 (total area <= 3x).
#'
#' **max_dist** (absolute): Limits expansion distance in CRS units.
#' For buffer method, this is the buffer distance directly.
#' For stamp method, converted to scale via `max_dist / characteristic_radius`
#' where characteristic_radius = sqrt(area / pi).
#'
#' @examples
#' library(sf)
#'
#' # Create a support with sparse points
#' support <- st_as_sf(
#'   data.frame(id = 1),
#'   geometry = st_sfc(st_polygon(list(
#'     cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))
#'   ))),
#'   crs = 32631
#' )
#'
#' # Points scattered around
#' set.seed(42)
#' pts <- st_as_sf(
#'   data.frame(id = 1:50),
#'   geometry = st_sfc(lapply(1:50, function(i) {
#'     st_point(c(runif(1, -50, 150), runif(1, -50, 150)))
#'   })),
#'   crs = 32631
#' )
#'
#' # Expand until we have at least 20 points
#' result <- aoe_expand(pts, support, min_points = 20)
#'
#' # Check expansion info
#' attr(result, "expansion_info")
#'
#' @seealso [aoe()] for fixed-scale AoE computation
#' @export
aoe_expand <- function(points, support = NULL, min_points,
                       max_area = 2, max_dist = NULL,
                       method = c("buffer", "stamp"),
                       reference = NULL, mask = NULL, coords = NULL) {

  method <- match.arg(method)

  # Validate min_points

if (missing(min_points) || !is.numeric(min_points) ||
        length(min_points) != 1 || min_points < 1) {
    stop("`min_points` must be a positive integer", call. = FALSE)
  }
  min_points <- as.integer(min_points)

  # Validate max_area
  if (!is.numeric(max_area) || length(max_area) != 1 || max_area <= 0) {
    stop("`max_area` must be a positive number", call. = FALSE)
  }

  # Validate max_dist
  if (!is.null(max_dist)) {
    if (!is.numeric(max_dist) || length(max_dist) != 1 || max_dist <= 0) {
      stop("`max_dist` must be a positive number (in CRS units)", call. = FALSE)
    }
  }

  # Handle support: NULL = auto-detect, character = country lookup
  if (is.null(support) || (is.character(support) && length(support) == 1 &&
                            tolower(support) == "auto")) {
    support <- detect_countries(points, coords)
  } else if (is.character(support)) {
    support <- do.call(rbind, lapply(support, get_country))
  }

  # Handle mask: "land" = use global land mask
  if (is.character(mask) && length(mask) == 1 && tolower(mask) == "land") {
    mask <- land
  }

  # Convert to sf
  support <- to_sf(support)
  crs <- sf::st_crs(support)
  points <- to_sf(points, crs, coords)
  reference <- to_sf(reference, crs)
  mask <- to_sf(mask, crs)

  # Input validation
  validate_inputs(points, support, reference, mask)

  n_supports <- nrow(support)

  # Reference only allowed for single support with stamp method
  if (!is.null(reference)) {
    if (method != "stamp") {
      stop("`reference` can only be used with `method = \"stamp\"`.", call. = FALSE)
    }
    if (n_supports > 1) {
      stop("`reference` can only be provided when `support` has a single row.",
           call. = FALSE)
    }
  }

  # Ensure consistent CRS
  target_crs <- sf::st_crs(support)
  points <- sf::st_transform(points, target_crs)

  # Create point IDs
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

  # Get support IDs
  support_ids <- if (!is.null(row.names(support))) {
    row.names(support)
  } else {
    as.character(seq_len(n_supports))
  }

  # Process each support
  geometries <- list()
  expansion_info <- list()

  results <- lapply(seq_len(n_supports), function(i) {
    sid <- support_ids[i]

    processed <- expand_single_support(
      points = points,
      support_row = support[i, ],
      support_id = sid,
      min_points = min_points,
      max_area = max_area,
      max_dist = max_dist,
      method = method,
      reference = reference,
      mask_geom = mask_geom,
      target_crs = target_crs
    )

    # Store geometries and expansion info
    geometries[[sid]] <<- processed$geometries
    expansion_info[[sid]] <<- processed$info

    processed$points
  })

  # Combine results
  result <- do.call(rbind, results)

  if (is.null(result) || nrow(result) == 0) {
    result <- points[0, ]
    result$point_id <- character(0)
    result$support_id <- character(0)
    result$aoe_class <- character(0)
    result$.point_id_internal <- NULL
  } else {
    result$point_id <- result$.point_id_internal
    result$.point_id_internal <- NULL

    geom_col <- attr(result, "sf_column")
    other_cols <- setdiff(names(result), c("point_id", "support_id", "aoe_class", geom_col))
    result <- result[, c("point_id", "support_id", "aoe_class", other_cols, geom_col)]
  }

  row.names(result) <- NULL

  # Build expansion info data frame
  info_df <- do.call(rbind, lapply(names(expansion_info), function(sid) {
    info <- expansion_info[[sid]]
    data.frame(
      support_id = sid,
      scale_used = info$scale,
      points_captured = info$points_captured,
      target_reached = info$target_reached,
      cap_hit = info$cap_hit,
      stringsAsFactors = FALSE
    )
  }))

  # Check if all targets reached
  all_reached <- all(info_df$target_reached)
  if (!all_reached) {
    failed <- info_df[!info_df$target_reached, ]
    warning(
      sprintf("Could not reach min_points=%d for %d support(s): %s",
              min_points, nrow(failed), paste(failed$support_id, collapse = ", ")),
      call. = FALSE
    )
  }

  # Create aoe_result with extra attributes
  # Use the mean scale for display purposes
  mean_scale <- mean(info_df$scale_used)
  aoe_result <- new_aoe_result(result, geometries, n_supports, scale = mean_scale)

  attr(aoe_result, "target_reached") <- all_reached
  attr(aoe_result, "expansion_info") <- info_df
  attr(aoe_result, "min_points") <- min_points

  class(aoe_result) <- c("aoe_expand_result", class(aoe_result))

  aoe_result
}


#' Process a single support for adaptive expansion
#' @noRd
expand_single_support <- function(points, support_row, support_id,
                                   min_points, max_area, max_dist,
                                   method, reference, mask_geom, target_crs) {

  # Prepare support geometry
  support_geom <- sf::st_geometry(support_row)[[1]]
  support_geom <- sf::st_sfc(support_geom, crs = target_crs)
  support_geom <- sf::st_make_valid(support_geom)

  original_area <- as.numeric(sf::st_area(support_geom))

  # Get reference point for stamp method
  ref_point <- NULL
  if (method == "stamp") {
    if (is.null(reference)) {
      ref_point <- sf::st_centroid(support_geom)
    } else {
      reference <- sf::st_transform(reference, target_crs)
      ref_point <- sf::st_geometry(reference)[[1]]
    }
  }

  # Calculate maximum scale from caps
  max_scale_area <- sqrt(1 + max_area) - 1

  max_scale_dist <- Inf
  if (!is.null(max_dist)) {
    if (method == "buffer") {
      # For buffer, max_dist is the buffer distance
      # Buffer distance d gives halo area ~ pi*d^2 + P*d
      # Approximate: scale where buffer_dist = max_dist
      # We'll use binary search anyway, so just estimate
      characteristic_radius <- sqrt(original_area / pi)
      max_scale_dist <- max_dist / characteristic_radius
    } else {
      # For stamp, expansion distance ~ scale * characteristic_radius
      characteristic_radius <- sqrt(original_area / pi)
      max_scale_dist <- max_dist / characteristic_radius
    }
  }

  max_scale <- min(max_scale_area, max_scale_dist)

  # Helper: count points at a given scale
  count_points_at_scale <- function(s) {
    if (s <= 0) {
      # Core only
      in_core <- as.logical(sf::st_intersects(points, support_geom, sparse = FALSE))
      return(list(count = sum(in_core), aoe_geom = support_geom))
    }

    mult <- 1 + s
    if (method == "buffer") {
      aoe_raw <- buffer_geometry(support_geom, scale = s, crs = target_crs)
    } else {
      aoe_raw <- scale_geometry(support_geom, ref_point, multiplier = mult, crs = target_crs)
    }
    aoe_raw <- sf::st_make_valid(aoe_raw)

    aoe_final <- aoe_raw
    if (!is.null(mask_geom)) {
      aoe_final <- sf::st_intersection(aoe_raw, mask_geom)
      aoe_final <- sf::st_make_valid(aoe_final)
    }

    in_aoe <- as.logical(sf::st_intersects(points, aoe_final, sparse = FALSE))
    list(count = sum(in_aoe), aoe_raw = aoe_raw, aoe_final = aoe_final)
  }

  # Check core-only first
  core_result <- count_points_at_scale(0)
  if (core_result$count >= min_points) {
    # Core alone is sufficient
    geometries <- list(
      original = support_geom,
      aoe_raw = support_geom,
      aoe_final = support_geom
    )

    in_original <- as.logical(sf::st_intersects(points, support_geom, sparse = FALSE))
    supported_idx <- which(in_original)

    if (length(supported_idx) == 0) {
      return(list(
        points = NULL,
        geometries = geometries,
        info = list(scale = 0, points_captured = 0, target_reached = FALSE, cap_hit = "none")
      ))
    }

    result <- points[supported_idx, ]
    result$support_id <- support_id
    result$aoe_class <- "core"

    return(list(
      points = result,
      geometries = geometries,
      info = list(scale = 0, points_captured = core_result$count,
                  target_reached = TRUE, cap_hit = "none")
    ))
  }

  # Check at max_scale
  max_result <- count_points_at_scale(max_scale)
  if (max_result$count < min_points) {
    # Can't reach target even at max scale
    cap_hit <- if (max_scale_area <= max_scale_dist) "max_area" else "max_dist"
    scale_used <- max_scale
    final_result <- max_result
    target_reached <- FALSE
  } else {
    # Binary search for minimum scale
    low <- 0
    high <- max_scale
    tolerance <- 0.001  # Scale tolerance

    final_result <- max_result
    scale_used <- max_scale

    for (i in 1:30) {  # Max iterations
      if (high - low < tolerance) break

      mid <- (low + high) / 2
      mid_result <- count_points_at_scale(mid)

      if (mid_result$count >= min_points) {
        # Can achieve target at mid, try lower
        high <- mid
        final_result <- mid_result
        scale_used <- mid
      } else {
        # Need more expansion
        low <- mid
      }
    }

    target_reached <- TRUE
    cap_hit <- "none"
  }

  # Build final geometries
  if (scale_used <= 0) {
    aoe_raw <- support_geom
    aoe_final <- support_geom
  } else {
    aoe_raw <- final_result$aoe_raw
    aoe_final <- final_result$aoe_final
  }

  geometries <- list(
    original = support_geom,
    aoe_raw = aoe_raw,
    aoe_final = aoe_final
  )

  # Classify points
  in_original <- as.logical(sf::st_intersects(points, support_geom, sparse = FALSE))
  in_aoe <- as.logical(sf::st_intersects(points, aoe_final, sparse = FALSE))
  supported_idx <- which(in_aoe)

  if (length(supported_idx) == 0) {
    return(list(
      points = NULL,
      geometries = geometries,
      info = list(scale = scale_used, points_captured = 0,
                  target_reached = FALSE, cap_hit = cap_hit)
    ))
  }

  result <- points[supported_idx, ]
  result$support_id <- support_id
  result$aoe_class <- ifelse(in_original[supported_idx], "core", "halo")

  list(
    points = result,
    geometries = geometries,
    info = list(scale = scale_used, points_captured = final_result$count,
                target_reached = target_reached, cap_hit = cap_hit)
  )
}


#' Print method for aoe_expand_result
#'
#' @param x An aoe_expand_result object
#' @param ... Additional arguments (ignored)
#'
#' @return Invisibly returns x
#' @export
print.aoe_expand_result <- function(x, ...) {
  # Call parent print
  NextMethod()

  # Add expansion-specific info
  info <- attr(x, "expansion_info")
  min_pts <- attr(x, "min_points")

  if (!is.null(info)) {
    cat("\nExpansion Info:\n")
    cat(sprintf("  Target: min_points = %d\n", min_pts))

    if (nrow(info) <= 5) {
      for (i in seq_len(nrow(info))) {
        row <- info[i, ]
        status <- if (row$target_reached) "reached" else paste0("capped by ", row$cap_hit)
        cat(sprintf("  %s: scale=%.3f, points=%d (%s)\n",
                    row$support_id, row$scale_used, row$points_captured, status))
      }
    } else {
      reached <- sum(info$target_reached)
      cat(sprintf("  %d/%d supports reached target\n", reached, nrow(info)))
      cat(sprintf("  Scale range: %.3f - %.3f\n",
                  min(info$scale_used), max(info$scale_used)))
    }
  }

  invisible(x)
}
