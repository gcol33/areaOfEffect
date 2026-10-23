run_without_sf_attached <- function(code) {
  pkg_path <- getNamespaceInfo("areaOfEffect", "path")
  load_line <- if (dir.exists(file.path(pkg_path, "Meta"))) {
    sprintf("library(areaOfEffect, lib.loc = %s)", deparse(dirname(pkg_path)))
  } else {
    sprintf("pkgload::load_all(%s, export_all = FALSE, helpers = FALSE, quiet = TRUE)",
            deparse(pkg_path))
  }
  script <- tempfile(fileext = ".R")
  on.exit(unlink(script), add = TRUE)
  writeLines(c(
    load_line,
    "stopifnot(!'package:sf' %in% search())",
    code
  ), script)
  rscript <- file.path(R.home("bin"), "Rscript")
  out <- suppressWarnings(system2(rscript, c("--vanilla", shQuote(script)),
                                  stdout = TRUE, stderr = TRUE))
  list(status = attr(out, "status") %||% 0L, output = out)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

test_that("aoe() and bundled data work without attaching sf", {
  res <- run_without_sf_attached(c(
    "be <- get_country('BEL')",
    "stopifnot(inherits(be, 'sf'), inherits(sf::st_geometry(be), 'sfc'))",
    "pts <- data.frame(lon = c(4.4, 4.5, 6), lat = c(50.8, 50.9, 50.6))",
    "r <- aoe(pts, 'Belgium')",
    "stopifnot(inherits(r, 'aoe_result'), nrow(r) == 3)",
    "fr <- countries[countries$iso3 == 'FRA', ]",
    "stopifnot(inherits(sf::st_geometry(fr), 'sfc'))",
    "cat('OK\\n')"
  ))
  expect_equal(res$status, 0L, info = paste(res$output, collapse = "\n"))
  expect_true("OK" %in% res$output)
})
