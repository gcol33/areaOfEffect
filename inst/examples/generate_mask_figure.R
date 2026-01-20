# Generate coastline masking figure for README
library(areaOfEffect)
library(sf)

cat("Generating Portugal coastline masking figure...\n")

# Get Portugal
pt <- get_country("PT")

# Create dummy point in Portugal
dummy <- st_as_sf(
  data.frame(id = 1),
  geometry = st_centroid(st_geometry(pt)),
  crs = 4326
)

# Without mask
cat("Computing AoE without mask...\n")
result_no_mask <- aoe(dummy, "PT")
aoe_no_mask <- aoe_geometry(result_no_mask, "aoe")

# With mask
cat("Computing AoE with land mask...\n")
result_masked <- aoe(dummy, "PT", mask = "land")
aoe_masked <- aoe_geometry(result_masked, "aoe")

# Get support geometry
support_geom <- aoe_geometry(result_masked, "original")

# Create SVG
cat("Creating SVG...\n")
svglite::svglite("man/figures/portugal-mask.svg", width = 7, height = 5)
par(mar = c(1, 1, 1, 1), bty = "n")

# Transform to equal area for plotting
crs_ea <- st_crs("+proj=laea +lat_0=39.5 +lon_0=-8 +datum=WGS84")
aoe_no_mask_ea <- st_transform(aoe_no_mask, crs_ea)
aoe_masked_ea <- st_transform(aoe_masked, crs_ea)
support_ea <- st_transform(support_geom, crs_ea)

# Plot
plot(st_geometry(aoe_no_mask_ea), border = "gray50", lty = 2, lwd = 1.5,
     xlim = st_bbox(aoe_no_mask_ea)[c(1,3)],
     ylim = st_bbox(aoe_no_mask_ea)[c(2,4)])
plot(st_geometry(aoe_masked_ea), col = rgb(0.3, 0.5, 0.7, 0.3),
     border = "steelblue", lty = 2, lwd = 1.5, add = TRUE)
plot(st_geometry(support_ea), border = "black", lwd = 2, add = TRUE)

legend("topright",
       legend = c("Portugal", "AoE (unmasked)", "AoE (land only)"),
       col = c("black", "gray50", NA),
       lty = c(1, 2, NA),
       lwd = c(2, 1.5, NA),
       fill = c(NA, NA, rgb(0.3, 0.5, 0.7, 0.5)),
       border = c(NA, NA, "steelblue"),
       bty = "n")

dev.off()
cat("Created: man/figures/portugal-mask.svg\n")
