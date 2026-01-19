# Plot method for aoe_result

Visualize an AoE classification result, showing points colored by class
and optionally the support and AoE boundaries.

## Usage

``` r
# S3 method for class 'aoe_result'
plot(
  x,
  support_id = NULL,
  show_aoe = TRUE,
  show_original = TRUE,
  col_core = "#2E7D32",
  col_halo = "#F57C00",
  col_original = "#000000",
  col_aoe = "#9E9E9E",
  pch = 16,
  cex = 0.8,
  main = NULL,
  ...
)
```

## Arguments

- x:

  An aoe_result object

- support_id:

  Optional: filter to specific support(s)

- show_aoe:

  Logical; show AoE boundary (default TRUE)

- show_original:

  Logical; show original support boundary (default TRUE)

- col_core:

  Color for core points (default "#2E7D32", green)

- col_halo:

  Color for halo points (default "#F57C00", orange)

- col_original:

  Color for original support boundary (default "#000000")

- col_aoe:

  Color for AoE boundary (default "#9E9E9E")

- pch:

  Point character (default 16)

- cex:

  Point size (default 0.8)

- main:

  Plot title (default auto-generated)

- ...:

  Additional arguments passed to plot

## Value

Invisibly returns x

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

set.seed(42)
pts <- st_as_sf(
  data.frame(id = 1:50),
  geometry = st_sfc(lapply(1:50, function(i) {
    st_point(c(runif(1, -5, 15), runif(1, -5, 15)))
  })),
  crs = 32631
)

result <- aoe(pts, support)
plot(result)
```
