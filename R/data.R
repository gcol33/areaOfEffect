# Avoid R CMD check note for data
utils::globalVariables(c("countries", "land", "country_halos"))

#' World Country Polygons with Pre-calculated AoE Bounds
#'
#' An `sf` object containing country polygons from Natural Earth (1:50m scale)
#' with pre-calculated bounding boxes for area of effect analysis.
#'
#' @format An `sf` data frame with 237 rows and 9 variables:
#' \describe{
#'   \item{iso2}{ISO 3166-1 alpha-2 country code (e.g., "FR", "BE")}
#'   \item{iso3}{ISO 3166-1 alpha-3 country code (e.g., "FRA", "BEL")}
#'   \item{name}{Country name}
#'   \item{continent}{Continent name}
#'   \item{bbox}{Original bounding box (xmin, ymin, xmax, ymax) in Mollweide}
#'   \item{bbox_equal_area}{AoE bounding box at scale sqrt(2)-1 (equal areas)}
#'   \item{bbox_equal_ray}{AoE bounding box at scale 1 (equal linear distance)}
#'   \item{halo_equal_area_scale}{Scale factor that produces halo area = country area (with land mask)}
#'   \item{geometry}{Country polygon in WGS84 (EPSG:4326)}
#' }
#'
#' @source Natural Earth \url{https://www.naturalearthdata.com/}
#'
#' @examples
#' # Get France
#' france <- countries[countries$iso3 == "FRA", ]
#'
#' # Use directly with aoe()
#' @keywords datasets
"countries"


#' Global Land Mask
#'
#' An `sf` object containing the global land polygon from Natural Earth (1:50m scale).
#' Used for masking area of effect computations to exclude ocean areas.
#'
#' @format An `sf` data frame with 1 row:
#' \describe{
#'   \item{name}{Description ("Global Land")}
#'   \item{geometry}{Land multipolygon in WGS84 (EPSG:4326)}
#' }
#'
#' @source Natural Earth \url{https://www.naturalearthdata.com/}
#'
#' @examples
#' # Use as mask to exclude sea
#' # aoe(points, support, mask = land)
#'
#' @keywords datasets
"land"


#' Pre-computed Equal-Area Country Halos
#'
#' A named list of pre-computed halo geometries for each country where the
#' halo area equals the country area (area proportion = 1). These halos
#' account for land masking (sea areas excluded).
#'
#' Each halo is a "donut" shape: the area between the original country
#' boundary and the expanded boundary, clipped to land.
#'
#' @format A named list with ISO3 country codes as names. Each element is
#'   either an `sfc` geometry (POLYGON or MULTIPOLYGON) in WGS84, or NULL
#'   if computation failed for that country.
#'
#' @source Computed from Natural Earth country polygons and land mask.
#'
#' @examples
#' # Get France's equal-area halo
#' france_halo <- country_halos[["FRA"]]
#'
#' @keywords datasets
"country_halos"


#' Get Country Polygon by Name or ISO Code
#'
#' Quick accessor for country polygons from the bundled dataset.
#'
#' @param x Country name, ISO2 code, or ISO3 code (case-insensitive)
#'
#' @return An `sf` object with the country polygon, or error if not found.
#'
#' @examples
#' get_country("Belgium")
#' get_country("BE")
#' get_country("BEL")
#'
#' @export
get_country <- function(x) {
  # Access lazy-loaded data via getExportedValue to support :: calls
  countries_data <- getExportedValue("areaOfEffect", "countries")

  x_upper <- toupper(x)
  x_lower <- tolower(x)

  # Try ISO2
  idx <- which(toupper(countries_data$iso2) == x_upper)
  if (length(idx) == 1) return(countries_data[idx, ])

  # Try ISO3
  idx <- which(toupper(countries_data$iso3) == x_upper)
  if (length(idx) == 1) return(countries_data[idx, ])

  # Try exact name
  idx <- which(tolower(countries_data$name) == x_lower)
  if (length(idx) == 1) return(countries_data[idx, ])

  # Partial match on name
  idx <- grep(x, countries_data$name, ignore.case = TRUE)
  if (length(idx) == 1) return(countries_data[idx, ])
  if (length(idx) > 1) {
    stop("Multiple matches: ", paste(countries_data$name[idx], collapse = ", "),
         call. = FALSE)
  }

  stop("Country not found: ", x, call. = FALSE)
}
