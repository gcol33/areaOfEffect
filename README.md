# areaOfEffect

[![R-CMD-check](https://github.com/gcol33/areaOfEffect/actions/workflows/R-CMD-check.yml/badge.svg)](https://github.com/gcol33/areaOfEffect/actions/workflows/R-CMD-check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Classify occurrence records relative to country borders — without writing sf code.**

Dataframe in → dataframe out. No CRS headaches. No buffer distance guessing.

<p align="center">
  <img src="man/figures/austria-aoe.svg" alt="Austria with Area of Effect" width="500">
</p>

## Quick Start

```r
library(areaOfEffect)

# Your occurrence data
observations <- data.frame(
  species = c("A", "B", "C", "D"),
  lon = c(14.5, 15.2, 16.8, 20.0),
  lat = c(47.5, 48.1, 47.2, 48.5)
)

# One line - get back a classified dataframe
result <- aoe(observations, "Austria")
result$aoe_class
#> [1] "core" "core" "halo"
# (point D pruned - outside area of effect)
```

## Philosophy

areaOfEffect does not invent new geometry. It standardizes a common spatial task: classifying points by their position relative to a region's boundary.

**Instead of choosing arbitrary buffer distances, halos are defined as a fixed proportion of region area** — enabling consistent cross-country comparisons without CRS expertise.

This is the kind of spatial task ecologists repeatedly reimplement with subtle errors. This package handles:

- Coordinate column auto-detection
- Country lookup by name or ISO code
- Equal-area projection (done correctly)
- Area-based buffer calculation
- Point classification
- Clean dataframe output

You don't need to learn CRS theory, when buffering in degrees is wrong, or why `st_covers()` sometimes returns `FALSE`. You just get a column that says `core` or `halo`.

## Statement of Need

Political borders are not hard ecological boundaries. Biological processes do not stop at administrative lines. When sampling within a political region, observations near the border are influenced by conditions outside that region.

The **area of effect** corrects for this border truncation by expanding the support outward. Points are then classified:

- **Core**: inside the original support
- **Halo**: outside the original support but inside the expanded area of effect
- **Pruned**: outside the area of effect (not returned)

By default, the halo has **equal area to the core** — a scale-free, proportion-based definition that enables consistent cross-country comparisons.

## Features

- **Dataframe workflow**: Plain dataframes with coordinates go in, classified dataframes come out
- **Country lookup**: Pass ISO codes or names directly (`"AT"`, `"Austria"`)
- **Auto-detection**: Omit support to detect countries from points
- **Area-based halos**: Proportion of region area, not arbitrary distances
- **Multiple supports**: Process admin regions with long format output
- **Masking**: Coastlines and other hard constraints
- **S3 methods**: `print()`, `summary()`, `plot()`

## Installation

```r
# Install from GitHub
# install.packages("pak")
pak::pak("gcol33/areaOfEffect")
```

## Usage

### From a Dataframe

```r
library(areaOfEffect)

# Plain dataframe with coordinates
df <- data.frame(
  id = 1:4,
  longitude = c(14.5, 15.2, 16.8, 20.0),
  latitude = c(47.5, 48.1, 47.2, 48.5)
)

# Classify relative to Austria
result <- aoe(df, "Austria")
```

### From sf Objects

```r
library(sf)

# sf points work too
pts_sf <- st_as_sf(df, coords = c("longitude", "latitude"), crs = 4326)
result <- aoe(pts_sf, "AT")
```

### Multiple Countries

```r
# Austria + Germany
result <- aoe(df, c("AT", "DE"))

# Auto-detect countries from points
result <- aoe(df)
```

### With Mask (e.g., Land Only)

```r
result <- aoe(df, "Austria", mask = land_polygon)
```

## Scale

The `scale` parameter controls halo size as a proportion of core area.

Default: `sqrt(2) - 1` ≈ 0.414, which gives **equal core and halo areas**.

| Scale | Halo:Core Area |
|-------|----------------|
| `sqrt(2) - 1` (default) | 1:1 |
| `1` | 3:1 |
| `0.5` | 1.25:1 |

## Documentation

- [Quick Start Vignette](https://gcol33.github.io/areaOfEffect/articles/quickstart.html)
- [Function Reference](https://gcol33.github.io/areaOfEffect/reference/index.html)

## Support

I'm a PhD student who builds R packages in my free time because I believe good tools should be free and open.

If this package saved you time, buying me a coffee is a nice way to say thanks.

[![Buy Me A Coffee](https://img.shields.io/badge/-Buy%20me%20a%20coffee-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/gcol33)

## License

MIT

## Citation

```bibtex
@software{areaOfEffect,
  author = {Colling, Gilles},
  title = {areaOfEffect: Area-Based Spatial Classification for Ecological Data},
  year = {2025},
  url = {https://github.com/gcol33/areaOfEffect}
}
```
