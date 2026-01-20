# Classify Points by Distance from a Border

Given a set of points and a border (line), `aoe_border()` classifies
points by their side relative to the border and their distance from it.
Creates equal-area buffer zones on both sides of the border.

## Usage

``` r
aoe_border(
  points,
  border,
  width = NULL,
  area = NULL,
  halo_width = NULL,
  halo_area = NULL,
  mask = NULL,
  bbox = NULL,
  side_names = c("side_1", "side_2"),
  coords = NULL
)
```

## Arguments

- points:

  An `sf` object with POINT geometries, or a data.frame with coordinate
  columns.

- border:

  An `sf` object with LINESTRING or MULTILINESTRING geometry
  representing the border.

- width:

  Buffer width in meters (for projected CRS) or degrees (for geographic
  CRS). Creates core zone within this distance of the border. Cannot be
  used together with `area`.

- area:

  Target area for each side's core zone. The function finds the buffer
  width that produces this area per side. If `mask` is provided, the
  width is adjusted to achieve the target area *after* masking. Cannot
  be used together with `width`.

- halo_width:

  Width of the halo zone beyond the core. If `NULL` (default), equals
  the core width for symmetric zones.

- halo_area:

  Target area for each side's halo zone. Alternative to `halo_width`. If
  `NULL` and `halo_width` is `NULL`, defaults to equal area as core.

- mask:

  Optional mask for clipping the buffer zones. Can be:

  - `sf` object with POLYGON or MULTIPOLYGON geometry

  - `"land"`: use the bundled global land mask to exclude sea areas

- bbox:

  Optional bounding box to limit the study area. Can be:

  - `sf` or `sfc` object (uses its bounding box)

  - Named vector: `c(xmin = ..., ymin = ..., xmax = ..., ymax = ...)`

  - `NULL`: no bbox restriction (uses buffer extent)

- side_names:

  Character vector of length 2 naming the sides. Default is
  `c("side_1", "side_2")`. The first name is assigned to the left side
  of the border (when traversing from start to end).

- coords:

  Column names for coordinates when `points` is a data.frame.

## Value

An `aoe_border_result` object (extends `sf`) containing classified
points with columns:

- point_id:

  Original point identifier

- side:

  Which side of the border: value from `side_names`

- aoe_class:

  Distance class: `"core"` or `"halo"`

Points outside the study area are pruned (not returned).

## Details

The function creates symmetric buffer zones around a border line:

1.  **Core zone**: Points within `width` (or `area`) distance of the
    border

2.  **Halo zone**: Points beyond core but within `width + halo_width`

3.  **Pruned**: Points outside the halo zone (not returned)

Each zone is split by the border line to determine which side the point
falls on.

### Equal area across sides

When using the `area` parameter, the buffer width is calculated to
produce equal area on both sides of the border. With masking, the width
is adjusted so that the *masked* area on each side equals the target.

## Examples

``` r
library(sf)

# Create a border line
border <- st_as_sf(
  data.frame(id = 1),
  geometry = st_sfc(st_linestring(matrix(
    c(0, 0, 100, 100), ncol = 2, byrow = TRUE
  ))),
  crs = 32631
)

# Create points
pts <- st_as_sf(
  data.frame(id = 1:6),
  geometry = st_sfc(
    st_point(c(10, 20)),   # near border, side 1
    st_point(c(30, 10)),   # near border, side 2
    st_point(c(50, 80)),   # far from border, side 1
    st_point(c(80, 40)),   # far from border, side 2
    st_point(c(5, 5)),     # very close to border
    st_point(c(200, 200))  # outside study area
  ),
  crs = 32631
)

# Classify by distance from border
result <- aoe_border(pts, border, width = 20)
```
