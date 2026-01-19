# Classify and Prune Points by Area of Effect

Given a set of points and one or more support polygons, `aoe()`
classifies points as "core" (inside original support) or "halo" (inside
the area of effect but outside original support), pruning all points
outside.

## Usage

``` r
aoe(
  points,
  support = NULL,
  scale = sqrt(2) - 1,
  reference = NULL,
  mask = NULL,
  coords = NULL
)
```

## Arguments

- points:

  An `sf` object with POINT geometries.

- support:

  One of:

  - `sf` object with POLYGON/MULTIPOLYGON geometries

  - Country name or ISO code: `"France"`, `"FR"`, `"FRA"`

  - Vector of countries: `c("France", "Germany")`

  - Missing: auto-detects countries containing the points

- scale:

  Numeric scale factor (default `sqrt(2) - 1`, approximately 0.414). The
  multiplier applied to distances from the reference point is
  `1 + scale`. Common values:

  - `sqrt(2) - 1` (default): equal core/halo areas, ratio 1:1

  - `1`: equal linear distance inside/outside, area ratio 1:3

- reference:

  Optional `sf` object with a single POINT geometry. If `NULL`
  (default), the centroid of each support is used. Only valid when
  `support` has a single row.

- mask:

  Optional `sf` object with POLYGON or MULTIPOLYGON geometry. If
  provided, each area of effect is intersected with this mask (e.g.,
  land boundary to exclude sea).

- coords:

  Column names for coordinates when `points` is a data.frame, e.g.
  `c("lon", "lat")`. If `NULL`, auto-detects common names.

## Value

An `aoe_result` object (extends `sf`) containing only the supported
points, with columns:

- point_id:

  Original point identifier (row name or index)

- support_id:

  Identifier for which support the classification refers to

- aoe_class:

  Classification: `"core"` or `"halo"`

When multiple supports are provided, points may appear multiple times
(once per support whose AoE contains them).

The result has S3 methods for
[`print()`](https://rdrr.io/r/base/print.html),
[`summary()`](https://rdrr.io/r/base/summary.html), and
[`plot()`](https://rdrr.io/r/graphics/plot.default.html). Use
[`aoe_geometry()`](https://gillescolling.com/areaOfEffect/reference/aoe_geometry.md)
to extract the AoE polygons.

## Details

The area of effect is computed by scaling each support outward from its
centroid. By default, scale is `sqrt(2) - 1` (~0.414), which produces
equal core and halo areas. This means the AoE has twice the area of the
original support, split evenly between core (inside) and halo (outside).

The transformation applies: \$\$p' = r + (1 + s)(p - r)\$\$ where \\r\\
is the reference point (centroid), \\p\\ is each vertex of the support
boundary, and \\s\\ is the scale factor.

With scale \\s\\, the area multiplier is \\(1 + s)^2\\:

- Scale 1: multiplier 2, area 4x original, halo:core = 3:1

- Scale 0.414: multiplier ~1.414, area 2x original, halo:core = 1:1

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
