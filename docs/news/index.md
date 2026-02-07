# Changelog

## areaOfEffect 0.2.5

- Reposition package as general spatial classification tool (not
  ecology-specific)
- Updated README with Statement of Need section and clearer feature
  descriptions
- Updated DESCRIPTION title and description to be domain-agnostic
- Added CRAN badges and installation instructions

## areaOfEffect 0.2.4

CRAN release: 2026-02-06

- Fixed `\dontrun{}` in `aoe_sample.aoe_border_result` example -
  replaced with complete, self-contained example that runs in \< 5
  seconds (CRAN policy compliance)

## areaOfEffect 0.1.0

Initial CRAN release. \## Core Functionality

- [`aoe()`](https://gcol33.github.io/areaOfEffect/reference/aoe.md)
  classifies points as “core” (inside support) or “halo” (inside scaled
  area of effect but outside original support), pruning points outside
- Default scale `sqrt(2) - 1` produces equal core and halo areas - a
  geometrically derived default requiring no parameter tuning
- Multiple supports processed independently with long format output
- Optional `mask` argument for hard boundaries (coastlines, etc.)

### S3 Class System

- `aoe_result` class extending `sf` with specialized methods
- [`print()`](https://rdrr.io/r/base/print.html) method showing point
  counts, supports, and scale info
- [`summary()`](https://rdrr.io/r/base/summary.html) method returning
  area statistics
- [`plot()`](https://rdrr.io/r/graphics/plot.default.html) method
  visualizing points with support/AoE boundaries

### Helper Functions

- [`aoe_summary()`](https://gcol33.github.io/areaOfEffect/reference/aoe_summary.md)
  for counts and proportions per support
- [`aoe_geometry()`](https://gcol33.github.io/areaOfEffect/reference/aoe_geometry.md)
  to extract original and AoE polygon geometries
- [`aoe_area()`](https://gcol33.github.io/areaOfEffect/reference/aoe_area.md)
  for area statistics including halo:core ratio and masking effects
