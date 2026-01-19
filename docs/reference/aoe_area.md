# Compute Area Statistics for AoE

Calculate area statistics for the original supports and their areas of
effect, including expansion ratios, masking effects, and core/halo
balance.

## Usage

``` r
aoe_area(x)
```

## Arguments

- x:

  An `aoe_result` object returned by
  [`aoe()`](https://gillescolling.com/areaOfEffect/reference/aoe.md).

## Value

An `aoe_area_result` data frame with one row per support:

- support_id:

  Support identifier

- area_core:

  Area of core region (same as original support)

- area_halo:

  Area of halo region (AoE minus core, after masking)

- area_aoe:

  Total AoE area after masking

- halo_core_ratio:

  Ratio of halo to core area (theoretically 3.0 without mask)

- pct_masked:

  Percentage of theoretical AoE area removed by masking

## Details

With scale \\s\\, the AoE expands by multiplier \\(1+s)\\ from centroid,
resulting in \\(1+s)^2\\ times the area. The theoretical halo:core ratio
is \\(1+s)^2 - 1\\:

- Scale 1 (default): ratio 3.0 (core 1 part, halo 3 parts)

- Scale 0.414: ratio 1.0 (equal areas)

Masking reduces the halo (and thus the ratio) when the AoE extends
beyond hard boundaries.

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
  data.frame(id = 1:3),
  geometry = st_sfc(
    st_point(c(5, 5)),
    st_point(c(15, 5)),
    st_point(c(2, 2))
  ),
  crs = 32631
)

result <- aoe(pts, support)
aoe_area(result)
#> AoE Area Statistics
#> ───────────────────
#> 
#>  support_id area_core (m²) area_halo (m²) area_aoe (m²) halo_core_ratio
#>           1            100            100           200            1.00
#>  pct_masked
#>        0.0%
#> 
#> Note: Theoretical halo:core ratio is 1.00 (scale=0.414, no masking)
```
