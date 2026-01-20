# Adaptive AoE Expansion to Capture Minimum Points

Expands the area of effect just enough to capture at least `min_points`,
subject to hard caps on expansion. This is useful when a fixed scale
leaves some supports with insufficient data for stable modelling.

## Usage

``` r
aoe_expand(
  points,
  support = NULL,
  min_points,
  max_area = 2,
  max_dist = NULL,
  method = c("buffer", "stamp"),
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

- min_points:

  Minimum number of points to capture in the AoE. The function finds the
  smallest scale that includes at least this many points.

- max_area:

  Maximum halo area as a proportion of the original support area.
  Default is 2, meaning halo area cannot exceed twice the support area
  (total AoE \<= 3x original). Set to `Inf` to disable.

- max_dist:

  Maximum expansion distance in CRS units. For the buffer method, this
  is the maximum buffer distance. For the stamp method, this is
  converted to a maximum scale based on the support's characteristic
  radius. Default is `NULL` (no distance cap).

- method:

  Method for computing the area of effect:

  - `"buffer"` (default): Uniform buffer around the support boundary.
    Robust for any polygon shape. Buffer distance is calculated to
    achieve the target halo area.

  - `"stamp"`: Scale vertices outward from the centroid (or reference
    point). Preserves shape proportions but only guarantees containment
    for star-shaped polygons. May leave small gaps for highly concave
    shapes.

- reference:

  Optional `sf` object with a single POINT geometry.

  If `NULL` (default), the centroid of each support is used. Only valid
  when `support` has a single row and `method = "stamp"`.

- mask:

  Optional mask for clipping the area of effect. Can be:

  - `sf` object with POLYGON or MULTIPOLYGON geometry

  - `"land"`: use the bundled global land mask to exclude sea areas If
    provided, each area of effect is intersected with this mask.

- coords:

  Column names for coordinates when `points` is a data.frame, e.g.
  `c("lon", "lat")`. If `NULL`, auto-detects common names.

## Value

An `aoe_result` object (same as
[`aoe()`](https://gcol33.github.io/areaOfEffect/reference/aoe.md)) with
additional attributes:

- target_reached:

  Logical: was `min_points` achieved for all supports? Use
  `attr(result, "expansion_info")` for per-support details.

- expansion_info:

  Data frame with per-support expansion details: support_id, scale_used,
  points_captured, target_reached, cap_hit.

## Details

Unlike
[`aoe()`](https://gcol33.github.io/areaOfEffect/reference/aoe.md), which
applies consistent geometry across all supports, `aoe_expand()` adapts
the scale per-support based on local point density. Use with caution:
this can make AoEs incomparable across regions with different point
densities.

### Algorithm

For each support, binary search finds the minimum scale where point
count \>= min_points. The search is bounded by:

- Lower: scale = 0 (core only)

- Upper: minimum of max_area cap and max_dist cap

If the caps prevent reaching min_points, a warning is issued and the
result uses the maximum allowed scale.

### Caps

Two caps ensure AoE doesn't expand unreasonably:

**max_area** (relative): Limits halo area to `max_area` times the
original. The corresponding scale is `sqrt(1 + max_area) - 1`. Default
max_area = 2 means scale \<= 0.732 (total area \<= 3x).

**max_dist** (absolute): Limits expansion distance in CRS units. For
buffer method, this is the buffer distance directly. For stamp method,
converted to scale via `max_dist / characteristic_radius` where
characteristic_radius = sqrt(area / pi).

## See also

[`aoe()`](https://gcol33.github.io/areaOfEffect/reference/aoe.md) for
fixed-scale AoE computation

## Examples

``` r
library(sf)

# Create a support with sparse points
support <- st_as_sf(
  data.frame(id = 1),
  geometry = st_sfc(st_polygon(list(
    cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))
  ))),
  crs = 32631
)

# Points scattered around
set.seed(42)
pts <- st_as_sf(
  data.frame(id = 1:50),
  geometry = st_sfc(lapply(1:50, function(i) {
    st_point(c(runif(1, -50, 150), runif(1, -50, 150)))
  })),
  crs = 32631
)

# Expand until we have at least 20 points
result <- aoe_expand(pts, support, min_points = 20)

# Check expansion info
attr(result, "expansion_info")
```
