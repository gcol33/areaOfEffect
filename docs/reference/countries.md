# World Country Polygons with Pre-calculated AoE Bounds

An `sf` object containing country polygons from Natural Earth (1:50m
scale) with pre-calculated bounding boxes for area of effect analysis.

## Usage

``` r
countries
```

## Format

An `sf` data frame with 237 rows and 8 variables:

- iso2:

  ISO 3166-1 alpha-2 country code (e.g., "FR", "BE")

- iso3:

  ISO 3166-1 alpha-3 country code (e.g., "FRA", "BEL")

- name:

  Country name

- continent:

  Continent name

- bbox:

  Original bounding box (xmin, ymin, xmax, ymax) in Mollweide

- bbox_equal_area:

  AoE bounding box at scale sqrt(2)-1 (equal areas)

- bbox_equal_ray:

  AoE bounding box at scale 1 (equal linear distance)

- geometry:

  Country polygon in WGS84 (EPSG:4326)

## Source

Natural Earth <https://www.naturalearthdata.com/>

## Examples

``` r
# Get France
france <- countries[countries$iso3 == "FRA", ]

# Use directly with aoe()
```
