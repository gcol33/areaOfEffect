# areaOfEffect 0.1.0

Initial CRAN release.
## Core Functionality

* `aoe()` classifies points as "core" (inside support) or "halo" (inside scaled
  area of effect but outside original support), pruning points outside
* Default scale `sqrt(2) - 1` produces equal core and halo areas - a
  geometrically derived default requiring no parameter tuning
* Multiple supports processed independently with long format output
* Optional `mask` argument for hard boundaries (coastlines, etc.)

## S3 Class System

* `aoe_result` class extending `sf` with specialized methods
* `print()` method showing point counts, supports, and scale info
* `summary()` method returning area statistics
* `plot()` method visualizing points with support/AoE boundaries

## Helper Functions

* `aoe_summary()` for counts and proportions per support
* `aoe_geometry()` to extract original and AoE polygon geometries
* `aoe_area()` for area statistics including halo:core ratio and masking effects
