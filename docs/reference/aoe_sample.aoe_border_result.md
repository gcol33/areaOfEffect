# Stratified Sampling from Border AoE Results

Sample points from an `aoe_border_result` with control over side and/or
core/halo balance.

## Usage

``` r
# S3 method for class 'aoe_border_result'
aoe_sample(
  x,
  n = NULL,
  ratio = NULL,
  by = c("side", "class"),
  replace = FALSE,
  ...
)
```

## Arguments

- x:

  An `aoe_border_result` object returned by
  [`aoe_border()`](https://gcol33.github.io/areaOfEffect/reference/aoe_border.md).

- n:

  Total number of points to sample. If `NULL`, uses all available points
  subject to the ratio constraint.

- ratio:

  Named numeric vector specifying target proportions. Names should match
  the side names used in
  [`aoe_border()`](https://gcol33.github.io/areaOfEffect/reference/aoe_border.md)
  (e.g., `c(side_1 = 0.5, side_2 = 0.5)`) or use
  `c(core = 0.5, halo = 0.5)` for distance-based sampling. Must sum to
  1.

- by:

  Character. What to stratify by:

  - `"side"` (default): sample by side of the border

  - `"class"`: sample by core/halo classification

- replace:

  Logical. Sample with replacement? Default is `FALSE`.

- ...:

  Additional arguments (ignored).

## Value

An `aoe_border_result` object containing the sampled points.

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
    st_point(c(10, 20)),
    st_point(c(30, 10)),
    st_point(c(50, 80)),
    st_point(c(80, 40)),
    st_point(c(5, 5)),
    st_point(c(95, 95))
  ),
  crs = 32631
)

result <- aoe_border(pts, border, width = 20,
                     side_names = c("west", "east"))

# Equal sampling from each side
balanced <- aoe_sample(result, ratio = c(west = 0.5, east = 0.5))

# Sample by core/halo instead
by_class <- aoe_sample(result, ratio = c(core = 0.5, halo = 0.5),
                       by = "class")
```
