#' Stratified Sampling from AoE Results
#'
#' Sample points from an `aoe_result` with control over core/halo balance.
#' This is useful when core regions dominate due to point density, and you
#' want balanced representation for modelling.
#'
#' @param x An `aoe_result` object returned by [aoe()] or [aoe_expand()].
#' @param n Total number of points to sample. If `NULL`, uses all available
#'   points subject to the ratio constraint (i.e., downsamples the larger group).
#' @param ratio Named numeric vector specifying the target proportion of core
#'   and halo points. Must sum to 1. Default is `c(core = 0.5, halo = 0.5)`
#'   for equal representation.
#' @param replace Logical. Sample with replacement? Default is `FALSE`.
#'   If `FALSE` and `n` exceeds available points in a stratum, that stratum
#'   contributes all its points.
#' @param by Character. Stratification grouping:
#'   - `"overall"` (default): sample from all points regardless of support
#'   - `"support"`: apply ratio within each support separately
#'
#' @return An `aoe_result` object containing the sampled points, preserving
#'   all original columns and attributes. Has additional attribute
#'   `sample_info` with details about the sampling.
#'
#' @details
#' ## Sampling modes
#'
#' **Fixed n**: When `n` is specified, the function samples exactly `n` points
#' (or fewer if not enough available), distributed according to `ratio`.
#'
#' **Balanced downsampling**: When `n` is `NULL`, the function downsamples
#' the larger stratum to match the smaller one according to `ratio`.
#' For example, with ratio `c(core = 0.5, halo = 0.5)` and 100 core + 20 halo
#' points, it returns 20 core + 20 halo = 40 points.
#'
#' ## Multiple supports
#'
#' With `by = "support"`, sampling is done independently within each support,
#' then results are combined. This ensures each support contributes balanced
#' samples. With `by = "overall"`, all points are pooled first.
#'
#' @examples
#' library(sf)
#'
#' support <- st_as_sf(
#'   data.frame(id = 1),
#'   geometry = st_sfc(st_polygon(list(
#'     cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))
#'   ))),
#'   crs = 32631
#' )
#'
#' # Many points in core, few in halo
#' set.seed(42)
#' pts <- st_as_sf(
#'   data.frame(id = 1:60),
#'   geometry = st_sfc(c(
#'     lapply(1:50, function(i) st_point(c(runif(1, 10, 90), runif(1, 10, 90)))),
#'     lapply(1:10, function(i) st_point(c(runif(1, 110, 140), runif(1, 10, 90))))
#'   )),
#'   crs = 32631
#' )
#'
#' result <- aoe(pts, support, scale = 1)
#'
#' # Balance core/halo (downsamples core to match halo)
#' balanced <- aoe_sample(result)
#'
#' # Fixed sample size with 70/30 split
#' sampled <- aoe_sample(result, n = 20, ratio = c(core = 0.7, halo = 0.3))
#'
#' @seealso [aoe()] for computing AoE classifications
#' @export
aoe_sample <- function(x, n = NULL, ratio = c(core = 0.5, halo = 0.5),
                       replace = FALSE, by = c("overall", "support")) {

if (!inherits(x, "aoe_result")) {
    stop("`x` must be an aoe_result object (from aoe() or aoe_expand())",
         call. = FALSE)
  }

  by <- match.arg(by)

 # Validate ratio
  if (!is.numeric(ratio) || length(ratio) != 2) {
    stop("`ratio` must be a numeric vector of length 2", call. = FALSE)
  }
  if (is.null(names(ratio))) {
    names(ratio) <- c("core", "halo")
  }
  if (!all(c("core", "halo") %in% names(ratio))) {
    stop("`ratio` must have names 'core' and 'halo'", call. = FALSE)
  }
  ratio <- ratio[c("core", "halo")]  # ensure order
  if (abs(sum(ratio) - 1) > 1e-10) {
    stop("`ratio` must sum to 1", call. = FALSE)
  }
  if (any(ratio < 0)) {
    stop("`ratio` values must be non-negative", call. = FALSE)
  }

  # Validate n
  if (!is.null(n)) {
    if (!is.numeric(n) || length(n) != 1 || n < 1) {
      stop("`n` must be a positive integer", call. = FALSE)
    }
    n <- as.integer(n)
  }

  # Validate replace
  if (!is.logical(replace) || length(replace) != 1) {
    stop("`replace` must be TRUE or FALSE", call. = FALSE)
  }

  if (nrow(x) == 0) {
    attr(x, "sample_info") <- data.frame(
      n_core_available = 0L,
      n_halo_available = 0L,
      n_core_sampled = 0L,
      n_halo_sampled = 0L,
      stringsAsFactors = FALSE
    )
    return(x)
  }

  if (by == "overall") {
    result <- sample_stratum(x, n, ratio, replace)
  } else {
    # Sample within each support
    supports <- unique(x$support_id)
    sampled_list <- lapply(supports, function(sid) {
      subset_x <- x[x$support_id == sid, ]
      sample_stratum(subset_x, n, ratio, replace)
    })

    # Combine results
    result <- do.call(rbind, lapply(sampled_list, function(s) s$data))

    # Combine sample info
    info_list <- lapply(sampled_list, function(s) s$info)
    combined_info <- data.frame(
      support_id = supports,
      n_core_available = sapply(info_list, function(i) i$n_core_available),
      n_halo_available = sapply(info_list, function(i) i$n_halo_available),
      n_core_sampled = sapply(info_list, function(i) i$n_core_sampled),
      n_halo_sampled = sapply(info_list, function(i) i$n_halo_sampled),
      stringsAsFactors = FALSE
    )

    # Preserve aoe_result class and attributes
    class(result) <- class(x)
    for (att in c("aoe_geometries", "aoe_n_supports", "aoe_scale", "aoe_area")) {
      attr(result, att) <- attr(x, att)
    }
    attr(result, "sample_info") <- combined_info

    return(result)
  }

  # For overall sampling, extract data and info
  sampled_data <- result$data
  sample_info <- result$info

  # Preserve aoe_result class and attributes
  class(sampled_data) <- class(x)
  for (att in c("aoe_geometries", "aoe_n_supports", "aoe_scale", "aoe_area")) {
    attr(sampled_data, att) <- attr(x, att)
  }
  attr(sampled_data, "sample_info") <- sample_info

  sampled_data
}


#' Sample from a single stratum (internal)
#' @noRd
sample_stratum <- function(x, n, ratio, replace) {
  is_core <- x$aoe_class == "core"
  n_core <- sum(is_core)
  n_halo <- sum(!is_core)

  core_idx <- which(is_core)
  halo_idx <- which(!is_core)

  if (is.null(n)) {
    # Balanced downsampling: match to limiting stratum
    # Find max n that respects ratio
    if (ratio["core"] > 0 && ratio["halo"] > 0) {
      # Both needed: find limiting factor
      max_n_from_core <- if (ratio["core"] > 0) n_core / ratio["core"] else Inf
      max_n_from_halo <- if (ratio["halo"] > 0) n_halo / ratio["halo"] else Inf
      n <- floor(min(max_n_from_core, max_n_from_halo))
    } else if (ratio["core"] == 0) {
      n <- n_halo
    } else {
      n <- n_core
    }
  }

  # Calculate target counts
  target_core <- round(n * ratio["core"])
  target_halo <- n - target_core  # ensure sum is exactly n

  # Adjust if not enough points available (without replacement)
  if (!replace) {
    actual_core <- min(target_core, n_core)
    actual_halo <- min(target_halo, n_halo)
  } else {
    actual_core <- target_core
    actual_halo <- target_halo
  }

  # Handle edge cases
  if (actual_core == 0 && length(core_idx) == 0) {
    sampled_core <- integer(0)
  } else if (actual_core > 0 && length(core_idx) > 0) {
    sampled_core <- sample(core_idx, actual_core, replace = replace)
  } else if (actual_core > 0 && length(core_idx) == 0) {
    sampled_core <- integer(0)
    actual_core <- 0
  } else {
    sampled_core <- integer(0)
  }

  if (actual_halo == 0 && length(halo_idx) == 0) {
    sampled_halo <- integer(0)
  } else if (actual_halo > 0 && length(halo_idx) > 0) {
    sampled_halo <- sample(halo_idx, actual_halo, replace = replace)
  } else if (actual_halo > 0 && length(halo_idx) == 0) {
    sampled_halo <- integer(0)
    actual_halo <- 0
  } else {
    sampled_halo <- integer(0)
  }

  sampled_idx <- c(sampled_core, sampled_halo)

  if (length(sampled_idx) == 0) {
    sampled_data <- x[0, ]
  } else {
    sampled_data <- x[sampled_idx, ]
  }

  info <- data.frame(
    n_core_available = n_core,
    n_halo_available = n_halo,
    n_core_sampled = length(sampled_core),
    n_halo_sampled = length(sampled_halo),
    stringsAsFactors = FALSE
  )

  list(data = sampled_data, info = info)
}
