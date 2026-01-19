# areaOfEffect

[![R-CMD-check](https://github.com/gcol33/areaOfEffect/actions/workflows/R-CMD-check.yml/badge.svg)](https://github.com/gcol33/areaOfEffect/actions/workflows/R-CMD-check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Spatial Support at Scale**

The `areaOfEffect` package formalizes spatial support at scale. Given a set of points and a support polygon, `aoe()` classifies points as "core" (inside original support) or "halo" (inside the area of effect but outside original support), pruning all points outside the area of effect.

## Concept

Political borders are not hard ecological boundaries. Biological processes do not stop at administrative lines. When sampling within a political region, observations near the border are influenced by conditions outside that region.

The **area of effect** (AoE) corrects for this border truncation by expanding the support outward from a reference point. Points are then classified:

- **Core**: inside the original support
- **Halo**: outside the original support but inside the expanded area of effect
- **Pruned**: outside the area of effect (not returned)

Scale is fixed at 1 (one full stamp), meaning each vertex of the support boundary is moved to twice its distance from the reference point. This is a principled default, not a tunable parameter.

Sea boundaries are treated differently from political borders: they are hard boundaries. An optional mask can be provided to enforce such constraints.

## Installation

```r
# Install from GitHub
# install.packages("pak")
pak::pak("gcol33/areaOfEffect")
```

## Usage

```r
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

### With a Mask (e.g., Land Boundary)

```r
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

### Custom Reference Point

```r
# Use a specific reference point instead of centroid
ref <- st_as_sf(
  data.frame(id = 1),
  geometry = st_sfc(st_point(c(25, 25))),
  crs = 32631
)

result <- aoe(pts, support, reference = ref)
```

## Function Signature

```r
aoe(points, support, reference = NULL, mask = NULL)
```

| Argument    | Type                      | Default | Description                                      |
|-------------|---------------------------|---------|--------------------------------------------------|
| `points`    | sf (POINT)                | required| Points to classify and prune                     |
| `support`   | sf (POLYGON/MULTIPOLYGON) | required| Original spatial support                         |
| `reference` | sf (POINT) or NULL        | NULL    | Reference point; if NULL, uses centroid          |
| `mask`      | sf (POLYGON) or NULL      | NULL    | Hard boundary; AoE intersected with mask         |

## Return Value

An `sf` object containing only supported points, with:

- `aoe_class` column: `"core"` or `"halo"`
- `scale` attribute: always `1`
- `reference` attribute: the reference point used

## Design Principles

- **Not a buffer**: AoE is a principled methodological correction, not a distance-based operation
- **Fixed scale**: Scale is fixed at 1 to ensure reproducible, comparable results
- **Hard boundaries respected**: Optional mask for coastlines or other hard constraints
- **Minimal API**: One function, four arguments, no hidden complexity

## License

MIT

## Citation

```bibtex
@software{areaOfEffect,
  author = {Colling, Gilles},
  title = {areaOfEffect: Spatial Support at Scale},
  year = {2025},
  url = {https://github.com/gcol33/areaOfEffect}
}
```
