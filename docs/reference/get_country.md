# Get Country Polygon by Name or ISO Code

Quick accessor for country polygons from the bundled dataset.

## Usage

``` r
get_country(x)
```

## Arguments

- x:

  Country name, ISO2 code, or ISO3 code (case-insensitive)

## Value

An `sf` object with the country polygon, or error if not found.

## Examples

``` r
get_country("Belgium")
get_country("BE")
get_country("BEL")
```
