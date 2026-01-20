# Generate example images for areaOfEffect package
library(areaOfEffect)
library(sf)

# Create output directory
out_dir <- normalizePath("~/iCloudDrive/claude/areaOfEffect", mustWork = FALSE)
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
cat("Output directory:", out_dir, "\n")

# Create support polygon
support <- st_as_sf(
  data.frame(id = 1),
  geometry = st_sfc(st_polygon(list(
    cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))
  ))),
  crs = 32631
)

# === Figure 1: Basic AoE concept ===
png(file.path(out_dir, "aoe_basic.png"), width = 800, height = 600, res = 120)
par(mar = c(1, 1, 2, 1), bty = "n")

set.seed(42)
pts <- st_as_sf(
  data.frame(id = 1:20),
  geometry = st_sfc(c(
    lapply(1:10, function(i) st_point(c(runif(1, 10, 90), runif(1, 10, 90)))),
    lapply(1:7, function(i) st_point(c(runif(1, 100, 140), runif(1, 10, 90)))),
    lapply(1:3, function(i) st_point(c(runif(1, 200, 250), runif(1, 50, 150))))
  )),
  crs = 32631
)

result <- aoe(pts, support, scale = 1)
geoms <- aoe_geometry(result, "both")
support_geom <- geoms[geoms$type == "original", ]
aoe_geom <- geoms[geoms$type == "aoe", ]

plot(st_geometry(aoe_geom), border = "steelblue", lty = 2, lwd = 2,
     xlim = c(-50, 270), ylim = c(-50, 170), main = "Area of Effect Classification")
plot(st_geometry(support_geom), border = "black", lwd = 2, add = TRUE)

# Plot all points
in_aoe <- st_intersects(pts, aoe_geom, sparse = FALSE)
cols <- ifelse(result$aoe_class == "core", "forestgreen",
               ifelse(result$aoe_class == "halo", "darkorange", "gray50"))
plot(st_geometry(result), col = cols, pch = 16, cex = 1.5, add = TRUE)
plot(st_geometry(pts[!in_aoe, ]), col = "gray50", pch = 4, cex = 1.2, add = TRUE)

legend("topright",
       legend = c("Support (core)", "AoE", "Core points", "Halo points", "Pruned"),
       col = c("black", "steelblue", "forestgreen", "darkorange", "gray50"),
       lty = c(1, 2, NA, NA, NA),
       lwd = c(2, 2, NA, NA, NA),
       pch = c(NA, NA, 16, 16, 4))

dev.off()
cat("Created: aoe_basic.png\n")

# === Figure 2: aoe_expand() ===
png(file.path(out_dir, "aoe_expand.png"), width = 800, height = 600, res = 120)
par(mar = c(1, 1, 2, 1), bty = "n")

set.seed(42)
pts_sparse <- st_as_sf(
  data.frame(id = 1:15),
  geometry = st_sfc(c(
    lapply(1:3, function(i) st_point(c(runif(1, 30, 70), runif(1, 30, 70)))),
    lapply(1:12, function(i) st_point(c(runif(1, -50, 200), runif(1, -50, 200))))
  )),
  crs = 32631
)

result_expand <- aoe_expand(pts_sparse, support, min_points = 8)
info <- attr(result_expand, "expansion_info")

geoms_exp <- aoe_geometry(result_expand, "both")
support_geom <- geoms_exp[geoms_exp$type == "original", ]
aoe_exp <- geoms_exp[geoms_exp$type == "aoe", ]

plot(st_geometry(aoe_exp), border = "steelblue", lty = 2, lwd = 2,
     xlim = c(-80, 230), ylim = c(-80, 230),
     main = sprintf("aoe_expand(): scale=%.3f to capture %d points",
                    info$scale_used, info$points_captured))
plot(st_geometry(support_geom), border = "black", lwd = 2, add = TRUE)

cols <- ifelse(result_expand$aoe_class == "core", "forestgreen", "darkorange")
plot(st_geometry(result_expand), col = cols, pch = 16, cex = 1.5, add = TRUE)

# Show pruned
in_result <- pts_sparse$id %in% result_expand$id
plot(st_geometry(pts_sparse[!in_result, ]), col = "gray50", pch = 4, cex = 1.2, add = TRUE)

legend("topright",
       legend = c("Support", "Expanded AoE", "Core", "Halo", "Pruned"),
       col = c("black", "steelblue", "forestgreen", "darkorange", "gray50"),
       lty = c(1, 2, NA, NA, NA),
       lwd = c(2, 2, NA, NA, NA),
       pch = c(NA, NA, 16, 16, 4))

dev.off()
cat("Created: aoe_expand.png\n")

# === Figure 3: aoe_sample() ===
png(file.path(out_dir, "aoe_sample.png"), width = 1000, height = 500, res = 120)
par(mfrow = c(1, 2), mar = c(1, 1, 2, 1), bty = "n")

set.seed(42)
pts_imbal <- st_as_sf(
  data.frame(id = 1:60),
  geometry = st_sfc(c(
    lapply(1:50, function(i) st_point(c(runif(1, 10, 90), runif(1, 10, 90)))),
    lapply(1:10, function(i) st_point(c(runif(1, 105, 140), runif(1, 10, 90))))
  )),
  crs = 32631
)

result_imbal <- aoe(pts_imbal, support, scale = 1)
geoms_imbal <- aoe_geometry(result_imbal, "both")
support_geom <- geoms_imbal[geoms_imbal$type == "original", ]
aoe_imbal <- geoms_imbal[geoms_imbal$type == "aoe", ]

# Before sampling
plot(st_geometry(aoe_imbal), border = "steelblue", lty = 2, lwd = 2,
     xlim = c(-30, 170), ylim = c(-30, 130),
     main = sprintf("Before: %d core, %d halo",
                    sum(result_imbal$aoe_class == "core"),
                    sum(result_imbal$aoe_class == "halo")))
plot(st_geometry(support_geom), border = "black", lwd = 2, add = TRUE)
cols <- ifelse(result_imbal$aoe_class == "core", "forestgreen", "darkorange")
plot(st_geometry(result_imbal), col = cols, pch = 16, cex = 1.2, add = TRUE)

# After sampling
set.seed(123)
sampled <- aoe_sample(result_imbal)

plot(st_geometry(aoe_imbal), border = "steelblue", lty = 2, lwd = 2,
     xlim = c(-30, 170), ylim = c(-30, 130),
     main = sprintf("After aoe_sample(): %d core, %d halo",
                    sum(sampled$aoe_class == "core"),
                    sum(sampled$aoe_class == "halo")))
plot(st_geometry(support_geom), border = "black", lwd = 2, add = TRUE)
cols_s <- ifelse(sampled$aoe_class == "core", "forestgreen", "darkorange")
plot(st_geometry(sampled), col = cols_s, pch = 16, cex = 1.5, add = TRUE)

dev.off()
cat("Created: aoe_sample.png\n")

cat("\nAll images generated in:", out_dir, "\n")
