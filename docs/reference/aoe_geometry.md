# Extract AoE Geometries

Extract the original support polygons and/or the area of effect polygons
from an `aoe_result` object.

## Usage

``` r
aoe_geometry(x, which = c("aoe", "original", "both"), support_id = NULL)
```

## Arguments

- x:

  An `aoe_result` object returned by
  [`aoe()`](https://gcol33.github.io/areaOfEffect/reference/aoe.md).

- which:

  Which geometry to extract: `"aoe"` (default), `"original"`, or
  `"both"`.

- support_id:

  Optional character or numeric vector specifying which support(s) to
  extract. If `NULL` (default), extracts all.

## Value

An `sf` object with polygon geometries and columns:

- support_id:

  Support identifier

- type:

  `"original"` or `"aoe"`

## Examples

``` r
library(sf)

support <- st_as_sf(
  data.frame(region = c("A", "B")),
  geometry = st_sfc(
    st_polygon(list(cbind(c(0, 10, 10, 0, 0), c(0, 0, 10, 10, 0)))),
    st_polygon(list(cbind(c(15, 25, 25, 15, 15), c(0, 0, 10, 10, 0))))
  ),
  crs = 32631
)

pts <- st_as_sf(
  data.frame(id = 1:4),
  geometry = st_sfc(
    st_point(c(5, 5)),
    st_point(c(12, 5)),
    st_point(c(20, 5)),
    st_point(c(27, 5))
  ),
  crs = 32631
)

result <- aoe(pts, support)

# Get AoE polygons
aoe_polys <- aoe_geometry(result, "aoe")

# Get both original and AoE for comparison
both <- aoe_geometry(result, "both")

# Filter to one support (uses row names as support_id)
region_1 <- aoe_geometry(result, "aoe", support_id = "1")
```
