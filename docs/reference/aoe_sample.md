# Stratified Sampling from AoE Results

Sample points from an `aoe_result` with control over core/halo balance.
This is useful when core regions dominate due to point density, and you
want balanced representation for modelling.

## Usage

``` r
aoe_sample(
  x,
  n = NULL,
  ratio = c(core = 0.5, halo = 0.5),
  replace = FALSE,
  by = c("overall", "support")
)
```

## Arguments

- x:

  An `aoe_result` object returned by
  [`aoe()`](https://gcol33.github.io/areaOfEffect/reference/aoe.md) or
  [`aoe_expand()`](https://gcol33.github.io/areaOfEffect/reference/aoe_expand.md).

- n:

  Total number of points to sample. If `NULL`, uses all available points
  subject to the ratio constraint (i.e., downsamples the larger group).

- ratio:

  Named numeric vector specifying the target proportion of core and halo
  points. Must sum to 1. Default is `c(core = 0.5, halo = 0.5)` for
  equal representation.

- replace:

  Logical. Sample with replacement? Default is `FALSE`. If `FALSE` and
  `n` exceeds available points in a stratum, that stratum contributes
  all its points.

- by:

  Character. Stratification grouping:

  - `"overall"` (default): sample from all points regardless of support

  - `"support"`: apply ratio within each support separately

## Value

An `aoe_result` object containing the sampled points, preserving all
original columns and attributes. Has additional attribute `sample_info`
with details about the sampling.

## Details

### Sampling modes

**Fixed n**: When `n` is specified, the function samples exactly `n`
points (or fewer if not enough available), distributed according to
`ratio`.

**Balanced downsampling**: When `n` is `NULL`, the function downsamples
the larger stratum to match the smaller one according to `ratio`. For
example, with ratio `c(core = 0.5, halo = 0.5)` and 100 core + 20 halo
points, it returns 20 core + 20 halo = 40 points.

### Multiple supports

With `by = "support"`, sampling is done independently within each
support, then results are combined. This ensures each support
contributes balanced samples. With `by = "overall"`, all points are
pooled first.

## See also

[`aoe()`](https://gcol33.github.io/areaOfEffect/reference/aoe.md) for
computing AoE classifications

## Examples

``` r
library(sf)

support <- st_as_sf(
  data.frame(id = 1),
  geometry = st_sfc(st_polygon(list(
    cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))
  ))),
  crs = 32631
)

# Many points in core, few in halo
set.seed(42)
pts <- st_as_sf(
  data.frame(id = 1:60),
  geometry = st_sfc(c(
    lapply(1:50, function(i) st_point(c(runif(1, 10, 90), runif(1, 10, 90)))),
    lapply(1:10, function(i) st_point(c(runif(1, 110, 140), runif(1, 10, 90))))
  )),
  crs = 32631
)

result <- aoe(pts, support, scale = 1)

# Balance core/halo (downsamples core to match halo)
balanced <- aoe_sample(result)

# Fixed sample size with 70/30 split
sampled <- aoe_sample(result, n = 20, ratio = c(core = 0.7, halo = 0.3))
```
