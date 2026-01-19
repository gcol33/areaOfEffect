# areaOfEffect

[![R-CMD-check](https://github.com/gcol33/areaOfEffect/actions/workflows/R-CMD-check.yml/badge.svg)](https://github.com/gcol33/areaOfEffect/actions/workflows/R-CMD-check.yml)
[![License:
MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Spatial Support at Scale**

The `areaOfEffect` package formalizes spatial support at scale. Given a
set of points and one or more support polygons,
[`aoe()`](https://gillescolling.com/areaOfEffect/reference/aoe.md)
classifies points as “core” (inside original support) or “halo” (inside
the area of effect but outside original support), pruning all points
outside.

## Concept

Political borders are not hard ecological boundaries. Biological
processes do not stop at administrative lines. When sampling within a
political region, observations near the border are influenced by
conditions outside that region.

The **area of effect** (AoE) corrects for this border truncation by
expanding the support outward from its centroid. Points are then
classified:

- **Core**: inside the original support
- **Halo**: outside the original support but inside the expanded area of
  effect
- **Pruned**: outside the area of effect (not returned)

By default, the AoE expands to give **equal core and halo areas**. This
is not arbitrary—it’s the unique scale where the inside and outside
contribute equally.

Sea boundaries are treated differently from political borders: they are
hard boundaries. An optional mask can be provided to enforce such
constraints.

## Why Equal Area?

The default scale (`sqrt(2) - 1 ≈ 0.414`) produces equal core and halo
areas. This emerges from a simple principle: **without domain knowledge,
the outside should matter as much as the inside**.

This is not a tuned parameter. It’s the *unique* solution to “core
equals halo”:

    (1 + s)² - 1 = 1  →  s = √2 - 1

The formula is derived, not chosen. It removes a degree of freedom from
the analyst and replaces it with a principled geometric constraint.

| Scale                | Multiplier | Area Ratio | Use Case            |
|----------------------|------------|------------|---------------------|
| **√2 − 1** (default) | **1.414**  | **1:1**    | **Symmetric prior** |
| 1                    | 2          | 1:3        | External dominance  |

## Installation

``` r

# Install from GitHub
# install.packages("pak")
pak::pak("gcol33/areaOfEffect")
```

## Usage

### Single Support

``` r

library(areaOfEffect)
library(sf)

# Create example support polygon (e.g., a country or region)
support <- st_as_sf(
  data.frame(id = 1),
  geometry = st_sfc(st_polygon(list(
    cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))
  ))),
  crs = 32631
)

# Create observation points
pts <- st_as_sf(
  data.frame(id = 1:4),
  geometry = st_sfc(
    st_point(c(50, 50)),   # core (center)
    st_point(c(10, 10)),   # core (inside)
    st_point(c(150, 50)),  # halo (outside original, inside AoE)
    st_point(c(300, 300))  # outside (will be pruned)
  ),
  crs = 32631
)

# Apply area of effect
result <- aoe(pts, support)

# View classification
result$aoe_class
#> [1] "core" "core" "halo"
```

### Multiple Supports (Parallel Processing)

When multiple supports are provided, each is processed independently.
Points can appear multiple times if they fall within multiple AoEs.

``` r

# Two adjacent admin regions
supports <- st_as_sf(
  data.frame(region = c("A", "B")),
  geometry = st_sfc(
    st_polygon(list(cbind(c(0, 50, 50, 0, 0), c(0, 0, 100, 100, 0)))),
    st_polygon(list(cbind(c(50, 100, 100, 50, 50), c(0, 0, 100, 100, 0))))
  ),
  crs = 32631
)

# Points near the shared boundary
pts <- st_as_sf(
  data.frame(id = 1:3),
  geometry = st_sfc(
    st_point(c(25, 50)),   # inside A
    st_point(c(50, 50)),   # on boundary
    st_point(c(75, 50))    # inside B
  ),
  crs = 32631
)

result <- aoe(pts, supports)
# Points may appear in both regions' output (long format)
```

### With a Mask (e.g., Land Boundary)

``` r

# Create land mask (excludes sea)
land <- st_as_sf(
  data.frame(id = 1),
  geometry = st_sfc(st_polygon(list(
    cbind(c(-50, 200, 200, -50, -50), c(0, 0, 150, 150, 0))
  ))),
  crs = 32631
)

# Apply with mask
result <- aoe(pts, support, mask = land)
```

### Diagnostic Summary

``` r

result <- aoe(pts, support)
aoe_summary(result)
#>   support_id n_total n_core n_halo prop_core prop_halo
#> 1          1       3      2      1     0.667     0.333
```

## Function Signature

``` r

aoe(points, support, scale = sqrt(2) - 1, reference = NULL, mask = NULL)
```

| Argument | Type | Default | Description |
|----|----|----|----|
| `points` | sf (POINT) | required | Points to classify and prune |
| `support` | sf (POLYGON/MULTIPOLYGON) | required | One or more support regions (each row = separate AoE) |
| `scale` | numeric | √2 − 1 | Scale factor; default gives equal core/halo areas |
| `reference` | sf (POINT) or NULL | NULL | Reference point; only valid for single support |
| `mask` | sf (POLYGON) or NULL | NULL | Hard boundary; AoE intersected with mask |

## Return Value

An `aoe_result` object (extends `sf`) containing only supported points,
with:

- `point_id` column: original point identifier
- `support_id` column: identifier for which support the classification
  refers to
- `aoe_class` column: `"core"` or `"halo"`

S3 methods: [`print()`](https://rdrr.io/r/base/print.html),
[`summary()`](https://rdrr.io/r/base/summary.html),
[`plot()`](https://rdrr.io/r/graphics/plot.default.html). Use
[`aoe_geometry()`](https://gillescolling.com/areaOfEffect/reference/aoe_geometry.md)
to extract polygons,
[`aoe_area()`](https://gillescolling.com/areaOfEffect/reference/aoe_area.md)
for area statistics.

When multiple supports are provided, points may appear multiple times
(once per support whose AoE contains them).

## Design Principles

- **Not a buffer**: AoE scales proportionally from the centroid, not by
  fixed distance
- **Derived default**: The default scale is geometrically determined,
  not tuned
- **Symmetric prior**: Equal core/halo areas = no bias toward inside or
  outside
- **Hard boundaries respected**: Optional mask for coastlines or other
  hard constraints
- **Multiple supports**: Process admin regions in parallel with long
  format output

## License

MIT

## Citation

``` bibtex
@software{areaOfEffect,
  author = {Colling, Gilles},
  title = {areaOfEffect: Spatial Support at Scale},
  year = {2026},
  url = {https://github.com/gcol33/areaOfEffect}
}
```
