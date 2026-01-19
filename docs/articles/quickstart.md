# Quick Start

## Overview

The `areaOfEffect` package addresses a common problem in spatial
ecology: political borders are not ecological boundaries. When sampling
within a defined region, observations near the border are influenced by
conditions outside that region.

The **area of effect** (AoE) correction expands the spatial support
outward, classifying points as:

- **Core**: inside the original support
- **Halo**: outside the original but inside the expanded AoE
- **Pruned**: outside the AoE entirely (removed)

## Quick Start

``` r

library(areaOfEffect)
library(sf)
#> Linking to GEOS 3.13.1, GDAL 3.11.4, PROJ 9.7.0; sf_use_s2() is TRUE
```

The simplest usage: pass points and a country code.

``` r

result <- aoe(pts, "AT")
```

## Austria Example

``` r

# Get Austria
austria <- get_country("AT")

# Transform to equal-area projection for accurate visualization
austria_ea <- st_transform(austria, "ESRI:54009")

# Compute AoE geometry manually for visualization
centroid <- st_centroid(st_geometry(austria_ea))
ref_coords <- st_coordinates(centroid)[1, 1:2]

# Scale with default multiplier (1 + sqrt(2) - 1 = sqrt(2))
multiplier <- sqrt(2)
austria_geom <- st_geometry(austria_ea)
aoe_geom <- (austria_geom - ref_coords) * multiplier + ref_coords
st_crs(aoe_geom) <- st_crs(austria_ea)

# Plot
par(mar = c(1, 1, 1, 1))
plot(aoe_geom, border = "gray50", lty = 2, lwd = 1.5)
plot(st_geometry(austria_ea), border = "black", lwd = 2, add = TRUE)
plot(centroid, pch = 3, cex = 1.5, lwd = 2, add = TRUE)
legend("topright",
       legend = c("Austria", "Area of Effect", "Centroid"),
       col = c("black", "gray50", "black"),
       lty = c(1, 2, NA),
       lwd = c(2, 1.5, NA),
       pch = c(NA, NA, 3),
       bg = "white")
```

![Austria (black) with its area of effect (dashed). The AoE expands
proportionally from the
centroid.](quickstart_files/figure-html/austria-visual-1.svg)

Austria (black) with its area of effect (dashed). The AoE expands
proportionally from the centroid.

## Basic Usage with Custom Support

``` r

support <- st_as_sf(
  data.frame(id = 1),
  geometry = st_sfc(st_polygon(list(
    cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))
  ))),
  crs = 32631
)
```

Create observation points:

``` r

pts <- st_as_sf(
  data.frame(
    id = 1:5,
    value = c(10, 20, 15, 25, 30)
  ),
  geometry = st_sfc(
    st_point(c(50, 50)),   # center
    st_point(c(10, 10)),   # near corner
    st_point(c(95, 50)),   # near edge
    st_point(c(120, 50)),  # outside, in halo
    st_point(c(250, 250))  # far outside
  ),
  crs = 32631
)
```

Apply the area of effect:

``` r

result <- aoe(pts, support)
print(result)
#> Area of Effect Result
#> ─────────────────────
#> Points:   4 (3 core, 1 halo)
#> Supports: 1
#> Scale:    0.414 (multiplier 1.41, theoretical halo:core 1.00)
#> 
#> Simple feature collection with 4 features and 5 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 10 ymin: 10 xmax: 120 ymax: 50
#> Projected CRS: WGS 84 / UTM zone 31N
#>   point_id support_id aoe_class id value       geometry
#> 1        1          1      core  1    10  POINT (50 50)
#> 2        2          1      core  2    20  POINT (10 10)
#> 3        3          1      core  3    15  POINT (95 50)
#> 4        4          1      halo  4    25 POINT (120 50)
```

The result contains only points inside the AoE, with their
classification:

``` r

result$aoe_class
#> [1] "core" "core" "core" "halo"
```

## Multiple Supports

Process multiple regions at once:

``` r

# Two adjacent regions
supports <- st_as_sf(
  data.frame(region = c("A", "B")),
  geometry = st_sfc(
    st_polygon(list(cbind(c(0, 50, 50, 0, 0), c(0, 0, 100, 100, 0)))),
    st_polygon(list(cbind(c(50, 100, 100, 50, 50), c(0, 0, 100, 100, 0))))
  ),
  crs = 32631
)

# Points that may fall in overlapping AoEs
pts_multi <- st_as_sf(
  data.frame(id = 1:3),
  geometry = st_sfc(
    st_point(c(25, 50)),   # inside A
    st_point(c(50, 50)),   # on boundary
    st_point(c(75, 50))    # inside B
  ),
  crs = 32631
)

result_multi <- aoe(pts_multi, supports)
print(result_multi)
#> Area of Effect Result
#> ─────────────────────
#> Points:   4 (4 core, 0 halo)
#> Supports: 2
#> Scale:    0.414 (multiplier 1.41, theoretical halo:core 1.00)
#> 
#> Simple feature collection with 4 features and 4 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 25 ymin: 50 xmax: 75 ymax: 50
#> Projected CRS: WGS 84 / UTM zone 31N
#>   point_id support_id aoe_class id      geometry
#> 1        1          1      core  1 POINT (25 50)
#> 2        2          1      core  2 POINT (50 50)
#> 3        2          2      core  2 POINT (50 50)
#> 4        3          2      core  3 POINT (75 50)
```

Points can appear multiple times (once per support whose AoE contains
them).

## Diagnostic Summary

``` r

aoe_summary(result)
#>   support_id n_total n_core n_halo prop_core prop_halo
#> 1          1       4      3      1      0.75      0.25
```

## Using a Mask (Coastlines)

For coastal regions, sea is a hard boundary. Provide a mask to constrain
the AoE:

``` r

# Create a coastal support
support_coast <- st_as_sf(
  data.frame(id = 1),
  geometry = st_sfc(st_polygon(list(
    cbind(c(40, 80, 80, 40, 40), c(20, 20, 60, 60, 20))
  ))),
  crs = 32631
)

# Create land mask (irregular coastline)
land <- st_as_sf(
  data.frame(id = 1),
  geometry = st_sfc(st_polygon(list(cbind(
    c(0, 100, 100, 70, 50, 30, 0, 0),
    c(0, 0, 50, 60, 55, 70, 60, 0)
  )))),
  crs = 32631
)

# Create some points
pts_coast <- st_as_sf(
  data.frame(id = 1:4),
  geometry = st_sfc(
    st_point(c(60, 40)),  # core
    st_point(c(50, 30)),  # core
    st_point(c(30, 40)),  # halo (on land)
    st_point(c(90, 70))   # would be halo but in sea
  ),
  crs = 32631
)

# Apply with mask
result_coast <- aoe(pts_coast, support_coast, mask = land)

# Compute theoretical AoE for visualization
centroid_coast <- c(60, 40)
support_coords <- cbind(c(40, 80, 80, 40, 40), c(20, 20, 60, 60, 20))
multiplier <- sqrt(2)
aoe_theoretical <- st_polygon(list(
  centroid_coast + multiplier * (support_coords - centroid_coast)
))

# Get masked AoE
aoe_masked <- aoe_geometry(result_coast, "aoe")

par(mar = c(1, 1, 1, 1))
plot(aoe_theoretical, border = "gray70", lty = 2,
     xlim = c(-10, 110), ylim = c(-10, 90))
plot(st_geometry(land), col = NA, border = "steelblue", lwd = 2, add = TRUE)
plot(st_geometry(aoe_masked), col = rgb(0.5, 0.5, 0.5, 0.3),
     border = NA, add = TRUE)
plot(st_geometry(support_coast), border = "black", lwd = 2, add = TRUE)

# Add points with colors
cols <- ifelse(result_coast$aoe_class == "core", "forestgreen", "darkorange")
plot(st_geometry(result_coast), col = cols, pch = 16, cex = 1.5, add = TRUE)

# Show pruned point
plot(st_geometry(pts_coast)[4], col = "gray60", pch = 4, cex = 1.2, add = TRUE)

text(85, 75, "SEA", col = "steelblue", font = 2, cex = 1.2)

legend("topleft",
       legend = c("Support", "AoE (theoretical)", "AoE (masked)",
                  "Coastline", "Core", "Halo", "Pruned"),
       col = c("black", "gray70", rgb(0.5, 0.5, 0.5, 0.5), "steelblue",
               "forestgreen", "darkorange", "gray60"),
       lty = c(1, 2, NA, 1, NA, NA, NA),
       lwd = c(2, 1, NA, 2, NA, NA, NA),
       pch = c(NA, NA, 15, NA, 16, 16, 4),
       pt.cex = c(NA, NA, 2, NA, 1.5, 1.5, 1.2),
       bg = "white")
```

![AoE with land mask. The theoretical AoE (dashed) is clipped to the
land boundary.](quickstart_files/figure-html/mask-example-1.svg)

AoE with land mask. The theoretical AoE (dashed) is clipped to the land
boundary.

## Scale Parameter

The default scale is `sqrt(2) - 1`, which gives equal core and halo
areas. You can adjust it:

``` r

# Default: equal core/halo areas
result_default <- aoe(pts, support)

# Scale = 1: larger halo (1:3 area ratio)
result_large <- aoe(pts, support, scale = 1)
```

## Summary

- [`aoe()`](https://gillescolling.com/areaOfEffect/reference/aoe.md)
  classifies points as “core” or “halo”
- Pass country codes directly: `aoe(pts, "AT")`
- Multiple supports produce long format output
- Use `mask` for coastlines and hard boundaries
- Default scale gives equal core/halo areas
- Use
  [`aoe_summary()`](https://gillescolling.com/areaOfEffect/reference/aoe_summary.md)
  for diagnostics
