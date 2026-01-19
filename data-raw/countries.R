# Pre-bundle country polygons with pre-calculated AoE bounding boxes
# Run this script once to generate data/countries.rda

library(sf)
library(rnaturalearth)

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

message(sprintf("Final dataset: %d countries, %.1f MB",
                nrow(countries),
                object.size(countries) / 1024^2))

# Save
usethis::use_data(countries, overwrite = TRUE, compress = "xz")

message("Saved to data/countries.rda")
