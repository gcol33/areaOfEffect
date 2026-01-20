# areaOfEffect

[![R-CMD-check](https://github.com/gcol33/areaOfEffect/actions/workflows/R-CMD-check.yml/badge.svg)](https://github.com/gcol33/areaOfEffect/actions/workflows/R-CMD-check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Classify occurrence records relative to country borders, without writing sf code.**

Ecological processes like dispersal are isotropic: a species spreads equally in all directions. Political borders are not. When you sample within a country, the border truncates the process, creating anisotropic artifacts near edges. The **area of effect** expands sampling outward to correct for this mismatch.

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

## Why Equal Area?

Points are classified as **core** (inside the country), **halo** (outside but within the buffer), or **pruned** (too far out).

By default, the halo has equal area to the core. Why? Because buffer distance in meters is arbitrary and scale-dependent. A 10km buffer means something different for Luxembourg than for Brazil. Equal area gives a consistent correction factor across regions, and scales automatically without CRS expertise.

## What It Handles

The package wraps sf operations that ecologists tend to get wrong:

- Coordinate column detection (handles `lon`/`long`/`longitude`/`x`, etc.)
- Country lookup by name or ISO code
- Equal-area projection for accurate buffering
- Area-proportional buffer calculation
- Point-in-polygon classification
- Coastline masking (optional)

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

> "Software is like sex: it's better when it's free." — Linus Torvalds

I'm a PhD student who builds R packages in my free time because I believe good tools should be free and open. I started these projects for my own work and figured others might find them useful too.

If this package saved you some time, buying me a coffee is a nice way to say thanks. It helps with my coffee addiction.

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
