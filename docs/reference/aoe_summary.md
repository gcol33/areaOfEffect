# Summarize Area of Effect Results

Compute summary statistics for an AoE classification result, including
counts and proportions of core vs halo points per support.

## Usage

``` r
aoe_summary(x)
```

## Arguments

- x:

  An `sf` object returned by
  [`aoe()`](https://gillescolling.com/areaOfEffect/reference/aoe.md).

## Value

A data frame with one row per support, containing:

- support_id:

  Support identifier

- n_total:

  Total number of supported points

- n_core:

  Number of core points

- n_halo:

  Number of halo points

- prop_core:

  Proportion of points that are core

- prop_halo:

  Proportion of points that are halo

## Examples

``` r
library(sf)

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
    st_point(c(12, 5))
  ),
  crs = 32631
)

result <- aoe(pts, support)
aoe_summary(result)
#>   support_id n_total n_core n_halo prop_core prop_halo
#> 1          1       3      2      1 0.6666667 0.3333333
```
