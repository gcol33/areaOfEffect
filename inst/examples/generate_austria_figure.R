# Generate Austria AoE figure for README (matches vignette style)
library(areaOfEffect)
library(sf)

cat("Generating Austria AoE figure...\n")

# Get Austria
austria <- get_country("AT")
austria_ea <- st_transform(austria, "ESRI:54009")

# Create a point inside Austria
dummy_pt <- st_centroid(austria_ea)

# Run aoe() to get geometries
result <- aoe(dummy_pt, austria_ea)
geoms <- aoe_geometry(result, "both")

# Extract geometries
austria_geom <- geoms[geoms$type == "original", ]
aoe_geom <- geoms[geoms$type == "aoe", ]

# Create SVG
cat("Creating SVG...\n")
svglite::svglite("man/figures/austria-aoe.svg", width = 7, height = 5)
par(mar = c(1, 1, 1, 1), bty = "n")

# Plot (matching vignette style: steelblue for AoE)
plot(st_geometry(aoe_geom), border = "steelblue", lty = 2, lwd = 1.5,
     axes = FALSE, xaxt = "n", yaxt = "n")
plot(st_geometry(austria_geom), border = "black", lwd = 2, add = TRUE)

legend("topright",
       legend = c("Austria (core)", "Area of Effect"),
       col = c("black", "steelblue"),
       lty = c(1, 2),
       lwd = c(2, 1.5),
       bty = "n")

dev.off()
cat("Created: man/figures/austria-aoe.svg\n")
