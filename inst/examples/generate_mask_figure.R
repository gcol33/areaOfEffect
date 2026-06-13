# Generate coastline masking figure for README
library(areaOfEffect)
library(sf)

# Save and restore par on exit
oldpar <- par(no.readonly = TRUE)
on.exit(par(oldpar), add = TRUE)

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
result_no_mask <- aoe(dummy, "PT", largest_polygon = FALSE)
aoe_no_mask <- aoe_geometry(result_no_mask, "aoe")

# With mask + area=1 for equal land area
cat("Computing AoE with land mask (equal land area)...\n")
result_masked <- aoe(dummy, "PT", mask = "land", area = 1, largest_polygon = FALSE)
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

# Plot. The map is width-bound (the Azores sit far west of the mainland), so the
# mainland and its halo land in the upper-right under the legend. Extend xlim to
# the right to shift the map left and open a clear column for the top-right legend.
bb <- st_bbox(aoe_no_mask_ea)
xlim <- c(bb[1], bb[3] + 0.23 * (bb[3] - bb[1]))

plot(st_geometry(aoe_no_mask_ea), border = "gray50", lty = 2, lwd = 1.5,
     xlim = xlim,
     ylim = bb[c(2, 4)],
     axes = FALSE, xaxt = "n", yaxt = "n")
plot(st_geometry(aoe_masked_ea), col = rgb(0.3, 0.5, 0.7, 0.3),
     border = "steelblue", lty = 2, lwd = 1.5, add = TRUE)
plot(st_geometry(support_ea), border = "black", lwd = 2, add = TRUE)

legend("topright",
       legend = c("Portugal", "AoE (unmasked)", "AoE (land only)"),
       col = c("black", "gray50", "steelblue"),
       lty = c(1, 2, 2),
       lwd = c(2, 1.5, 1.5),
       bty = "n",
       inset = 0.02)

dev.off()
cat("Created: man/figures/portugal-mask.svg\n")
