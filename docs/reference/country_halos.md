# Pre-computed Equal-Area Country Halos

A named list of pre-computed halo geometries for each country where the
halo area equals the country area (area proportion = 1). These halos
account for land masking (sea areas excluded).

## Usage

``` r
country_halos
```

## Format

A named list with ISO3 country codes as names. Each element is either an
`sfc` geometry (POLYGON or MULTIPOLYGON) in WGS84, or NULL if
computation failed for that country.

## Source

Computed from Natural Earth country polygons and land mask.

## Details

Each halo is a "donut" shape: the area between the original country
boundary and the expanded boundary, clipped to land.

## Examples

``` r
# Get France's equal-area halo
france_halo <- country_halos[["FRA"]]
```
