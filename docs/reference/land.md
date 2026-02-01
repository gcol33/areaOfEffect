# Global Land Mask

An `sf` object containing the global land polygon from Natural Earth
(1:50m scale). Used for masking area of effect computations to exclude
ocean areas.

## Usage

``` r
land
```

## Format

An `sf` data frame with 1 row:

- name:

  Description ("Global Land")

- geometry:

  Land multipolygon in WGS84 (EPSG:4326)

## Source

Natural Earth <https://www.naturalearthdata.com/>

## Examples

``` r
# Use as mask to exclude sea
# \donttest{
dummy <- sf::st_as_sf(
  data.frame(id = 1),
  geometry = sf::st_sfc(sf::st_point(c(14.5, 47.5))),
  crs = 4326
)
result <- aoe(dummy, "AT", mask = land)
# }
```
