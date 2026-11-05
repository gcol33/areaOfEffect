# Pre-bundle country polygons with pre-calculated AoE bounding boxes
# and land mask for area-based AoE computation
# Run this script once to generate data/countries.rda and data/land.rda

library(sf)
library(rnaturalearth)

# ==============================================================================
# PART 1: Country polygons
# ==============================================================================

# Country polygons at 1:10m resolution. The 1:50m coastline is too coarse for
# coastal cities: Lisbon falls into the Tagus estuary.
countries_raw <- ne_countries(scale = 10, returnclass = "sf")

# Keep essential columns - use _eh variants which handle edge cases better
countries <- countries_raw[, c("iso_a2_eh", "iso_a3_eh", "name", "continent")]
names(countries)[1:4] <- c("iso2", "iso3", "name", "continent")

# Remove Antarctica and invalid geometries
countries <- countries[countries$continent != "Antarctica", ]
countries <- countries[!is.na(countries$iso3) & countries$iso3 != "-99", ]
countries <- st_make_valid(countries)

# Simplify on the sphere (s2, tolerance in metres). Planar simplification,
# in WGS84 or in Mollweide, leaves self-crossing rings in the countries that
# span the antimeridian (Russia, the United States, Fiji).
sf_use_s2(TRUE)
simplify_tol <- 1000
countries_full <- countries
countries <- st_simplify(countries, dTolerance = simplify_tol, preserveTopology = TRUE)
countries <- st_make_valid(countries)

# A territory smaller than the tolerance can simplify to nothing; keep its
# full-resolution outline instead.
empty <- st_is_empty(countries)
if (any(empty)) {
  message("Kept unsimplified: ", paste(countries$name[empty], collapse = ", "))
  st_geometry(countries)[empty] <- st_geometry(countries_full)[empty]
}

# Transform to equal-area projection for accurate AoE calculation (Mollweide)
countries_ea <- st_transform(countries, "ESRI:54009")
countries_ea <- st_make_valid(countries_ea)

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

message(sprintf("Countries dataset: %d countries, %.1f MB",
                nrow(countries),
                object.size(countries) / 1024^2))

# ==============================================================================
# PART 2: Global land mask
# ==============================================================================

message("Fetching global land mask from Natural Earth...")

# Get land polygon (excludes water bodies)
land_raw <- ne_download(scale = 10, type = "land", category = "physical",
                        returnclass = "sf")

land <- st_make_valid(land_raw)
land <- st_transform(land, 4326)

# Simplify and union on the sphere, as for the countries
land <- st_simplify(land, dTolerance = simplify_tol, preserveTopology = TRUE)
land <- st_make_valid(land)
land <- st_union(land)
land <- st_make_valid(land)

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
# Validate on the sphere and save
# ==============================================================================

# The package runs with s2 on, so every shipped geometry must be valid on
# the sphere, not only in the planar projection it was built in.
sf_use_s2(TRUE)
s2_valid <- function(g) s2::s2_is_valid(st_as_s2(st_geometry(g), check = FALSE))
# Repair one geometry on the sphere: s2 rebuild first, then a planar (GEOS)
# repair, then a planar union of its polygon parts, keeping the first result
# that is valid on the sphere.
fix_one_s2 <- function(x) {
  r <- tryCatch(st_make_valid(x), error = function(e) NULL)
  if (!is.null(r) && isTRUE(all(s2_valid(r)))) return(r)
  sf_use_s2(FALSE)
  on.exit(sf_use_s2(TRUE))
  r <- st_make_valid(x)
  sf_use_s2(TRUE)
  if (isTRUE(all(s2_valid(r)))) return(r)
  sf_use_s2(FALSE)
  st_union(st_cast(st_collection_extract(r, "POLYGON"), "POLYGON"))
}
fix_s2 <- function(g, label, required = TRUE) {
  geom <- st_geometry(g)
  bad <- which(!s2_valid(geom))
  for (i in bad) geom[i] <- fix_one_s2(geom[i])
  still <- which(!s2_valid(geom))
  if (length(still)) {
    msg <- sprintf("%s: %d geometries still invalid on the sphere (%s)",
                   label, length(still), paste(head(still), collapse = ", "))
    if (required) stop(msg)
    message("    ", msg)
  }
  if (!inherits(g, "sf")) return(geom)
  st_geometry(g) <- geom
  g
}
countries <- fix_s2(countries, "countries")
land <- fix_s2(land, "land")
# The halos ship as a dataset and are not used by the package functions, so
# one that cannot be made valid on the sphere is kept and reported.
for (iso in names(country_halos)) {
  if (!is.null(country_halos[[iso]]))
    country_halos[[iso]] <- fix_s2(country_halos[[iso]], paste0("halo_", iso),
                                   required = FALSE)
}


usethis::use_data(countries, overwrite = TRUE, compress = "xz")
message("Saved countries to data/countries.rda")

usethis::use_data(land, overwrite = TRUE, compress = "xz")
message("Saved land mask to data/land.rda")

usethis::use_data(country_halos, overwrite = TRUE, compress = "xz")
message("Saved country halos to data/country_halos.rda")

message("Done!")
