# Quick Start

## Overview

The `areaOfEffect` package classifies spatial points by their position
relative to a region’s boundary—without requiring sf expertise.

**Dataframe in → dataframe out.**

Points are classified as:

- **Core**: inside the original support

- **Halo**: outside the original but inside the area of effect

- **Pruned**: outside the AoE entirely (removed)

By default, halos are defined as **equal area to the core**—a
proportion-based definition that enables consistent cross-region
comparisons.

## Getting Started

``` r

library(areaOfEffect)
library(sf)
#> Linking to GEOS 3.13.1, GDAL 3.11.4, PROJ 9.7.0; sf_use_s2() is TRUE
```

### From a Dataframe

The simplest usage: pass a dataframe with coordinates and a country
name.

``` r

# Your occurrence data
observations <- data.frame(
  species = c("Oak", "Beech", "Pine", "Spruce"),
  lon = c(14.5, 15.2, 16.8, 20.0),
  lat = c(47.5, 48.1, 47.2, 48.5)
)

# Classify relative to Austria
result <- aoe(observations, "Austria")
result$aoe_class
#> [1] "core" "core" "halo"
```

The package auto-detects coordinate columns (lon/lat, x/y,
longitude/latitude, etc.).

### From sf Objects

sf objects work directly:

``` r

result <- aoe(pts_sf, "AT")
```

## Austria Example

``` r

# Get Austria and transform to equal-area projection
austria <- get_country("AT")
austria_ea <- st_transform(austria, "ESRI:54009")

# Create a point inside Austria
dummy_pt <- st_centroid(austria_ea)
#> Warning: st_centroid assumes attributes are constant over geometries

# Run aoe() to get geometries (uses buffer method by default)
result <- aoe(dummy_pt, austria_ea)
geoms <- aoe_geometry(result, "both")

# Extract geometries
austria_geom <- geoms[geoms$type == "original", ]
aoe_geom <- geoms[geoms$type == "aoe", ]

# Plot
par(mar = c(1, 1, 1, 1))
plot(st_geometry(aoe_geom), border = "steelblue", lty = 2, lwd = 1.5)
plot(st_geometry(austria_geom), border = "black", lwd = 2, add = TRUE)
legend("topright",
       legend = c("Austria (core)", "Area of Effect"),
       col = c("black", "steelblue"),
       lty = c(1, 2),
       lwd = c(2, 1.5))
```

![Austria (black) with its area of effect (dashed blue). The halo has
equal area to the
core.](quickstart_files/figure-html/austria-visual-1.svg)

Austria (black) with its area of effect (dashed blue). The halo has
equal area to the core.

## Basic Usage with Custom Polygons

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

# Get geometries for visualization
aoe_masked <- aoe_geometry(result_coast, "aoe")
support_geom <- aoe_geometry(result_coast, "original")

par(mar = c(1, 1, 1, 1))
plot(st_geometry(land), col = NA, border = "steelblue", lwd = 2,
     xlim = c(-10, 110), ylim = c(-10, 90))
plot(st_geometry(aoe_masked), col = rgb(0.5, 0.5, 0.5, 0.3),
     border = "steelblue", lty = 2, add = TRUE)
plot(st_geometry(support_geom), border = "black", lwd = 2, add = TRUE)

# Add points with colors
cols <- ifelse(result_coast$aoe_class == "core", "forestgreen", "darkorange")
plot(st_geometry(result_coast), col = cols, pch = 16, cex = 1.5, add = TRUE)

# Show pruned point
plot(st_geometry(pts_coast)[4], col = "gray60", pch = 4, cex = 1.2, add = TRUE)

text(85, 75, "SEA", col = "steelblue", font = 2, cex = 1.2)

legend("topleft",
       legend = c("Support", "AoE (masked)", "Coastline", "Core", "Halo", "Pruned"),
       col = c("black", "steelblue", "steelblue", "forestgreen", "darkorange", "gray60"),
       lty = c(1, 2, 1, NA, NA, NA),
       lwd = c(2, 1, 2, NA, NA, NA),
       pch = c(NA, NA, NA, 16, 16, 4),
       pt.cex = c(NA, NA, NA, 1.5, 1.5, 1.2))
```

![AoE with land mask. The AoE is clipped to the land
boundary.](quickstart_files/figure-html/mask-example-1.svg)

AoE with land mask. The AoE is clipped to the land boundary.

## Scale Parameter

The `scale` parameter controls halo size as a proportion of core area.

``` r

# Default: equal core/halo areas (scale = sqrt(2) - 1)
result_default <- aoe(pts, support)

# Scale = 1: larger halo (3:1 area ratio)
result_large <- aoe(pts, support, scale = 1)
```

| Scale                   | Halo:Core Area |
|-------------------------|----------------|
| `sqrt(2) - 1` (default) | 1:1            |
| `1`                     | 3:1            |
| `0.5`                   | 1.25:1         |

## Diagnostics

``` r

aoe_summary(result)
#>   support_id n_total n_core n_halo prop_core prop_halo
#> 1          1       4      3      1      0.75      0.25
```

## Summary

- [`aoe()`](https://gcol33.github.io/areaOfEffect/reference/aoe.md)
  classifies points as “core” or “halo”

- Works with dataframes or sf objects

- Pass country codes directly: `aoe(df, "AT")`

- Area-based halos enable consistent cross-country comparisons

- Use `mask` for coastlines and hard boundaries

- Use
  [`aoe_summary()`](https://gcol33.github.io/areaOfEffect/reference/aoe_summary.md)
  for diagnostics
