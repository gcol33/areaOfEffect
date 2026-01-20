# Pre-bundle country polygons with pre-calculated AoE bounding boxes
# and land mask for area-based AoE computation
# Run this script once to generate data/countries.rda and data/land.rda

library(sf)
library(rnaturalearth)

# ==============================================================================
# PART 1: Country polygons
# ==============================================================================

# Get country polygons at 1:50m resolution (good balance of detail/size)
countries_raw <- ne_countries(scale = 50, returnclass = "sf")

# Keep essential columns - use _eh variants which handle edge cases better
countries <- countries_raw[, c("iso_a2_eh", "iso_a3_eh", "name", "continent")]
names(countries)[1:4] <- c("iso2", "iso3", "name", "continent")

# Remove Antarctica and invalid geometries
countries <- countries[countries$continent != "Antarctica", ]
countries <- countries[!is.na(countries$iso3) & countries$iso3 != "-99", ]
countries <- st_make_valid(countries)

# Transform to equal-area projection for accurate AoE calculation
countries_ea <- st_transform(countries, "ESRI:54009")
# Mollweide equal-area

# Pre-calculate bounding boxes for each scale
calc_aoe_bbox <- function(geom, scale) {
  centroid <- st_centroid(geom)
  ref <- st_coordinates(centroid)[1, 1:2]
  multiplier <- 1 + scale

 # Scale geometry
  geom_shifted <- geom - ref
  geom_scaled <- geom_shifted * multiplier
  geom_aoe <- geom_scaled + ref

  st_bbox(geom_aoe)
}

# Calculate for both scales
scale_area <- sqrt(2) - 1  # ~0.414, equal areas
scale_ray <- 1             # equal linear distance

message("Calculating AoE bounding boxes...")
n <- nrow(countries_ea)

bbox_original <- vector("list", n)
bbox_equal_area <- vector("list", n)
bbox_equal_ray <- vector("list", n)

for (i in seq_len(n)) {
  if (i %% 20 == 0) message(sprintf("  %d/%d", i, n))

  geom <- st_geometry(countries_ea[i, ])

  bbox_original[[i]] <- as.numeric(st_bbox(geom))
  bbox_equal_area[[i]] <- as.numeric(calc_aoe_bbox(geom, scale_area))
  bbox_equal_ray[[i]] <- as.numeric(calc_aoe_bbox(geom, scale_ray))
}

# Add bbox columns as matrices (4 values: xmin, ymin, xmax, ymax)
countries$bbox <- do.call(rbind, bbox_original)
countries$bbox_equal_area <- do.call(rbind, bbox_equal_area)
countries$bbox_equal_ray <- do.call(rbind, bbox_equal_ray)

# Keep in WGS84 for user convenience
countries <- st_transform(countries, 4326)

# Simplify geometries to reduce package size
countries <- st_simplify(countries, dTolerance = 0.01, preserveTopology = TRUE)

message(sprintf("Countries dataset: %d countries, %.1f MB",
                nrow(countries),
                object.size(countries) / 1024^2))

# ==============================================================================
# PART 2: Global land mask
# ==============================================================================

message("Fetching global land mask from Natural Earth...")

# Get land polygon (excludes water bodies)
land_raw <- ne_download(scale = 50, type = "land", category = "physical",
                        returnclass = "sf")

# Disable s2 for planar geometry operations (avoids spherical geometry issues)
sf_use_s2(FALSE)

land <- st_make_valid(land_raw)
land <- st_transform(land, 4326)

# Simplify to reduce size
land <- st_simplify(land, dTolerance = 0.01, preserveTopology = TRUE)

# Union into single multipolygon for efficient intersection
land <- st_union(land)
land <- st_make_valid(land)

# Fix any remaining topology issues with zero-width buffer trick
land <- st_buffer(land, 0)

# Convert to sf object with minimal attributes
land <- st_sf(
  name = "Global Land",
  geometry = st_sfc(land, crs = 4326)
)

message(sprintf("Land mask: %.1f MB", object.size(land) / 1024^2))

# ==============================================================================
# PART 3: Precompute equal-area halos for countries
# ==============================================================================

message("Precomputing equal-area halos for countries...")
message("(This may take a while - using land mask for coastal clipping)")

# Transform land to equal-area for computation
land_ea <- st_transform(land, "ESRI:54009")
land_ea <- st_make_valid(land_ea)
land_ea <- st_buffer(land_ea, 0)  # Fix topology after projection
land_geom_ea <- st_geometry(land_ea)[[1]]
land_geom_ea <- st_sfc(land_geom_ea, crs = "ESRI:54009")

# Function to compute halo with area = 1 (halo area = country area)
# Uses secant method to find correct scale accounting for land mask
compute_equal_area_halo <- function(country_geom, land_mask, country_name = "",
                                     tol = 0.0001, max_iter = 10) {
  original_area <- as.numeric(st_area(country_geom))
  target_halo <- original_area  # area = 1 means halo = original

  centroid <- st_centroid(country_geom)
  ref <- st_coordinates(centroid)[1, 1:2]

  # Helper to compute halo at given scale
  compute_at_scale <- function(s) {
    mult <- 1 + s
    geom_shifted <- country_geom - ref
    geom_scaled <- geom_shifted * mult
    aoe_raw <- geom_scaled + ref
    st_crs(aoe_raw) <- st_crs(country_geom)
    aoe_raw <- st_make_valid(aoe_raw)
    aoe_raw <- st_buffer(aoe_raw, 0)  # Fix any topology issues

    # Apply land mask
    aoe_masked <- st_intersection(aoe_raw, land_mask)
    aoe_masked <- st_make_valid(aoe_masked)
    aoe_masked <- st_buffer(aoe_masked, 0)

    aoe_area <- as.numeric(st_area(aoe_masked))
    halo_area <- max(0, aoe_area - original_area)

    list(aoe_raw = aoe_raw, aoe_masked = aoe_masked, halo_area = halo_area)
  }

  # Initial guess: theoretical scale for area = 1
  s0 <- sqrt(2) - 1
  result0 <- compute_at_scale(s0)
  f0 <- result0$halo_area - target_halo

  if (abs(f0) / target_halo < tol) {
    halo <- st_difference(result0$aoe_masked, country_geom)
    return(list(scale = s0, halo = st_make_valid(halo)))
  }

  # One-shot correction
 ratio <- target_halo / max(result0$halo_area, target_halo * 0.01)
  s1 <- s0 * sqrt(ratio)
  s1 <- max(s1, 0.001)

  result1 <- compute_at_scale(s1)
  f1 <- result1$halo_area - target_halo

  if (abs(f1) / target_halo < tol) {
    halo <- st_difference(result1$aoe_masked, country_geom)
    return(list(scale = s1, halo = st_make_valid(halo)))
  }

  # Secant method
  for (i in seq_len(max_iter)) {
    if (abs(f1 - f0) < 1e-10) break

    s_new <- s1 - f1 * (s1 - s0) / (f1 - f0)
    s_new <- max(s_new, 0.001)

    result_new <- compute_at_scale(s_new)
    f_new <- result_new$halo_area - target_halo

    if (abs(f_new) / target_halo < tol) {
      halo <- st_difference(result_new$aoe_masked, country_geom)
      return(list(scale = s_new, halo = st_make_valid(halo)))
    }

    s0 <- s1; f0 <- f1
    s1 <- s_new; f1 <- f_new
    result1 <- result_new
  }

  # Return best result
  halo <- st_difference(result1$aoe_masked, country_geom)
  list(scale = s1, halo = st_make_valid(halo))
}

# Compute for all countries
n <- nrow(countries_ea)
halo_scales <- numeric(n)
halo_geoms <- vector("list", n)

for (i in seq_len(n)) {
  if (i %% 10 == 0 || i == 1) {
    message(sprintf("  %d/%d: %s", i, n, countries_ea$name[i]))
  }

  # Check if country crosses dateline (in WGS84)
  country_wgs84 <- countries[i, ]
  bbox <- st_bbox(country_wgs84)
  crosses_dateline <- (bbox["xmin"] < -170 && bbox["xmax"] > 170)

  if (crosses_dateline) {
    message(sprintf("    Dateline-crossing country: %s, applying st_wrap_dateline", countries$name[i]))
    # Wrap at dateline, then project to equal-area
    country_wrapped <- st_wrap_dateline(country_wgs84,
                                         options = c("WRAPDATELINE=YES", "DATELINEOFFSET=180"))
    country_wrapped <- st_make_valid(country_wrapped)
    country_geom <- st_geometry(st_transform(country_wrapped, "ESRI:54009"))
    country_geom <- st_make_valid(country_geom)
    country_geom <- st_buffer(country_geom, 0)
  } else {
    country_geom <- st_geometry(countries_ea[i, ])
  }

  tryCatch({
    result <- compute_equal_area_halo(country_geom, land_geom_ea, countries$name[i])
    halo_scales[i] <- result$scale
    halo_geoms[[i]] <- result$halo
  }, error = function(e) {
    message(sprintf("    Warning: Failed for %s: %s", countries_ea$name[i], e$message))
    halo_scales[i] <<- NA
    halo_geoms[[i]] <<- NULL
  })
}

# Add scale and halo geometry to countries
countries$halo_equal_area_scale <- halo_scales

# Transform halos back to WGS84 and store
halo_geoms_wgs84 <- lapply(halo_geoms, function(g) {
 if (is.null(g)) return(NULL)
  st_transform(st_sfc(g, crs = "ESRI:54009"), 4326)
})

# Store halos as a separate list (too complex for a column)
country_halos <- setNames(halo_geoms_wgs84, countries$iso3)

message(sprintf("Final countries dataset: %d countries, %.1f MB",
                nrow(countries),
                object.size(countries) / 1024^2))

# ==============================================================================
# Save datasets
# ==============================================================================

usethis::use_data(countries, overwrite = TRUE, compress = "xz")
message("Saved countries to data/countries.rda")

usethis::use_data(land, overwrite = TRUE, compress = "xz")
message("Saved land mask to data/land.rda")

usethis::use_data(country_halos, overwrite = TRUE, compress = "xz")
message("Saved country halos to data/country_halos.rda")

message("Done!")
