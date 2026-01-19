# Classify and Prune Points by Area of Effect

Given a set of points and one or more support polygons, `aoe()`
classifies points as "core" (inside original support) or "halo" (inside
the area of effect but outside original support), pruning all points
outside.

## Usage

``` r
aoe(points, support, reference = NULL, mask = NULL)
```

## Arguments

- points:

  An `sf` object with POINT geometries.

- support:

  An `sf` object with POLYGON or MULTIPOLYGON geometries. Each row
  defines a separate support region. When multiple rows are provided,
  points are classified against each support independently, returning
  long format output where a point may appear multiple times.

- reference:

  Optional `sf` object with a single POINT geometry. If `NULL`
  (default), the centroid of each support is used. Only valid when
  `support` has a single row.

- mask:

  Optional `sf` object with POLYGON or MULTIPOLYGON geometry. If
  provided, each area of effect is intersected with this mask (e.g.,
  land boundary to exclude sea).

## Value

An `sf` object containing only the supported points, with columns:

- support_id:

  Identifier for which support the classification refers to

- aoe_class:

  Classification: `"core"` or `"halo"`

When multiple supports are provided, points may appear multiple times
(once per support whose AoE contains them).

Attribute `"scale"` (always 1) is attached to the result.

## Details

The area of effect is computed by scaling each support outward from its
centroid. Scale is fixed at 1 (one full stamp), meaning each point on
the support boundary is moved to twice its distance from the centroid.

The transformation applies: \$\$p' = r + 2(p - r)\$\$ where \\r\\ is the
reference point (centroid) and \\p\\ is each vertex of the support
boundary.

Points exactly on the original support boundary are classified as
"core".

The support geometry is validated internally using
[`sf::st_make_valid()`](https://r-spatial.github.io/sf/reference/valid.html).

## Examples

``` r
library(sf)

# Single support
support <- st_as_sf(
  data.frame(id = 1),
  geometry = st_sfc(st_polygon(list(
    cbind(c(0, 10, 10, 0, 0), c(0, 0, 10, 10, 0))
  ))),
  crs = 32631
)

pts <- st_as_sf(
  data.frame(id = 1:4),
  geometry = st_sfc(
    st_point(c(5, 5)),
    st_point(c(2, 2)),
    st_point(c(15, 5)),
    st_point(c(30, 30))
  ),
  crs = 32631
)

result <- aoe(pts, support)

# Multiple supports (e.g., admin regions)
supports <- st_as_sf(
  data.frame(region = c("A", "B")),
  geometry = st_sfc(
    st_polygon(list(cbind(c(0, 10, 10, 0, 0), c(0, 0, 10, 10, 0)))),
    st_polygon(list(cbind(c(8, 18, 18, 8, 8), c(0, 0, 10, 10, 0))))
  ),
  crs = 32631
)

result <- aoe(pts, supports)
# Points near the boundary may appear in both regions' AoE
```
