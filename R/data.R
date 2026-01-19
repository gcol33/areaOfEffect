# Avoid R CMD check note for data
utils::globalVariables("countries")

#' World Country Polygons with Pre-calculated AoE Bounds
#'
#' An `sf` object containing country polygons from Natural Earth (1:50m scale)
#' with pre-calculated bounding boxes for area of effect analysis.
#'
#' @format An `sf` data frame with 237 rows and 8 variables:
#' \describe{
#'   \item{iso2}{ISO 3166-1 alpha-2 country code (e.g., "FR", "BE")}
#'   \item{iso3}{ISO 3166-1 alpha-3 country code (e.g., "FRA", "BEL")}
#'   \item{name}{Country name}
#'   \item{continent}{Continent name}
#'   \item{bbox}{Original bounding box (xmin, ymin, xmax, ymax) in Mollweide}
#'   \item{bbox_equal_area}{AoE bounding box at scale sqrt(2)-1 (equal areas)}
#'   \item{bbox_equal_ray}{AoE bounding box at scale 1 (equal linear distance)}
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
  x_upper <- toupper(x)
  x_lower <- tolower(x)

  # Try ISO2
  idx <- which(toupper(countries$iso2) == x_upper)
  if (length(idx) == 1) return(countries[idx, ])

  # Try ISO3
  idx <- which(toupper(countries$iso3) == x_upper)
  if (length(idx) == 1) return(countries[idx, ])

  # Try exact name
  idx <- which(tolower(countries$name) == x_lower)
  if (length(idx) == 1) return(countries[idx, ])

  # Partial match on name
  idx <- grep(x, countries$name, ignore.case = TRUE)
  if (length(idx) == 1) return(countries[idx, ])
  if (length(idx) > 1) {
    stop("Multiple matches: ", paste(countries$name[idx], collapse = ", "),
         call. = FALSE)
  }

  stop("Country not found: ", x, call. = FALSE)
}
