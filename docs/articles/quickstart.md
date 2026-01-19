# Getting Started with areaOfEffect

## Overview

The `areaOfEffect` package addresses a common problem in spatial
ecology: political borders are not ecological boundaries. When sampling
within a defined region (e.g., a country or protected area),
observations near the border are influenced by conditions outside that
region. Simply cropping data to administrative boundaries introduces
edge effects.

The **area of effect** (AoE) correction expands the spatial support
outward, classifying points as:

- **Core**: inside the original support (fully representative)
- **Halo**: outside the original but inside the expanded AoE (influenced
  by external conditions)
- **Pruned**: outside the AoE entirely (removed)

## Basic Usage

``` r

library(areaOfEffect)
library(sf)
#> Linking to GEOS 3.13.1, GDAL 3.11.4, PROJ 9.7.0; sf_use_s2() is TRUE
```

Create a simple support polygon:

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
#> Simple feature collection with 4 features and 4 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 10 ymin: 10 xmax: 120 ymax: 50
#> Projected CRS: WGS 84 / UTM zone 31N
#>   id value support_id aoe_class       geometry
#> 1  1    10          1      core  POINT (50 50)
#> 2  2    20          1      core  POINT (10 10)
#> 3  3    15          1      core  POINT (95 50)
#> 4  4    25          1      halo POINT (120 50)
```

The result contains only points inside the AoE, with their
classification:

``` r

result$aoe_class
#> [1] "core" "core" "core" "halo"
```

## Understanding the Transformation

The AoE is constructed by scaling the support geometry outward from a
reference point (by default, the centroid). With fixed scale = 1, each
boundary vertex is moved to twice its distance from the reference:
``` math
p' = r + 2(p - r)
```

where $`r`$ is the reference point and $`p`$ is each boundary vertex.

This doubles the effective spatial extent while maintaining the shape
and orientation of the original support.

## Multiple Supports

When working with multiple administrative regions, you can process them
all at once:

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
#> Simple feature collection with 6 features and 3 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: 25 ymin: 50 xmax: 75 ymax: 50
#> Projected CRS: WGS 84 / UTM zone 31N
#>   id support_id aoe_class      geometry
#> 1  1          1      core POINT (25 50)
#> 2  2          1      core POINT (50 50)
#> 3  3          1      halo POINT (75 50)
#> 4  1          2      halo POINT (25 50)
#> 5  2          2      core POINT (50 50)
#> 6  3          2      core POINT (75 50)
```

Points can appear multiple times (once per support whose AoE contains
them). The `support_id` column indicates which support the
classification refers to.

## Diagnostic Summary

Use
[`aoe_summary()`](https://gcol33.github.io/areaOfEffect/reference/aoe_summary.md)
to get statistics for each support:

``` r

aoe_summary(result)
#>   support_id n_total n_core n_halo prop_core prop_halo
#> 1          1       4      3      1      0.75      0.25
```

This returns counts and proportions of core vs halo points per support.

## Using a Mask

For coastal regions, sea is a hard boundary that should not be crossed.
Provide a mask to constrain the AoE:

``` r

# Land polygon (excludes sea)
land <- st_read("path/to/land.shp")

# AoE will be intersected with land
result <- aoe(pts, support, mask = land)
```

## Custom Reference Point

By default, the centroid of each support is used as the reference point.
For single-support cases, you can specify a different reference:

``` r

# Reference at origin corner
ref <- st_as_sf(
  data.frame(id = 1),
  geometry = st_sfc(st_point(c(0, 0))),
  crs = 32631
)

result_custom <- aoe(pts, support, reference = ref)
```

Note: custom reference is only allowed when `support` has a single row.
For multiple supports, each uses its own centroid.

## Accessing Metadata

The result includes attributes with metadata:

``` r

# Scale used (always 1)
attr(result, "scale")
#> [1] 1
```

## Why Fixed Scale?

The scale is fixed at 1 to ensure:

1.  **Reproducibility**: All analyses use the same definition
2.  **Comparability**: Results across studies are directly comparable
3.  **Interpretability**: “We applied the AoE correction” is unambiguous

If you need to explore different scales, that functionality belongs in
separate analysis code, not in the core AoE operator.

## Summary

- [`aoe()`](https://gcol33.github.io/areaOfEffect/reference/aoe.md)
  classifies points as “core” or “halo” based on their position relative
  to the original and expanded support
- Multiple supports can be processed at once (long format output)
- Points outside the AoE are automatically pruned
- Sea and other hard boundaries can be enforced via the `mask` argument
- Scale is fixed at 1 for methodological consistency
- Use
  [`aoe_summary()`](https://gcol33.github.io/areaOfEffect/reference/aoe_summary.md)
  for diagnostic statistics
