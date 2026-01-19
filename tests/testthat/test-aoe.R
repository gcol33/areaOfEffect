test_that("aoe classifies points correctly", {
  skip_if_not_installed("sf")
  library(sf)

  # Create a simple square support (0-10, 0-10)
  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 10, 10, 0, 0), c(0, 0, 10, 10, 0))
    ))),
    crs = 32631
  )

  # Create test points
  pts <- st_as_sf(
    data.frame(id = 1:4),
    geometry = st_sfc(
      st_point(c(5, 5)),    # core (center)
      st_point(c(2, 2)),    # core (inside)
      st_point(c(15, 5)),   # halo (outside original, inside scaled)
      st_point(c(50, 50))   # outside (should be pruned)
    ),
    crs = 32631
  )

  result <- aoe(pts, support)

  # Should return 3 points (one pruned)
  expect_equal(nrow(result), 3)

  # Check classification
  expect_true(all(result$aoe_class[result$id %in% c(1, 2)] == "core"))
  expect_equal(result$aoe_class[result$id == 3], "halo")

  # Check attributes
  expect_equal(attr(result, "scale"), 1)
  expect_true(inherits(attr(result, "reference"), "sf"))
})

test_that("aoe returns empty sf with correct schema when no points supported", {
  skip_if_not_installed("sf")
  library(sf)

  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 1, 1, 0, 0), c(0, 0, 1, 1, 0))
    ))),
    crs = 32631
  )

  pts <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_point(c(100, 100))),
    crs = 32631
  )

  result <- aoe(pts, support)

  expect_equal(nrow(result), 0)
  expect_true("aoe_class" %in% names(result))
  expect_equal(attr(result, "scale"), 1)
})

test_that("aoe validates inputs correctly", {
  skip_if_not_installed("sf")
  library(sf)

  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 10, 10, 0, 0), c(0, 0, 10, 10, 0))
    ))),
    crs = 32631
  )

  # Non-sf points
  expect_error(aoe(data.frame(x = 1, y = 1), support), "must be an sf object")

  # Non-POINT geometry
  line_pts <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_linestring(cbind(c(0, 1), c(0, 1)))),
    crs = 32631
  )
  expect_error(aoe(line_pts, support), "POINT geometries")

  # Non-POLYGON support
  pts <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_point(c(5, 5))),
    crs = 32631
  )
  point_support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_point(c(5, 5))),
    crs = 32631
  )
  expect_error(aoe(pts, point_support), "POLYGON or MULTIPOLYGON")
})

test_that("aoe respects custom reference point", {
  skip_if_not_installed("sf")
  library(sf)

  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 10, 10, 0, 0), c(0, 0, 10, 10, 0))
    ))),
    crs = 32631
  )

  pts <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_point(c(5, 5))),
    crs = 32631
  )

  custom_ref <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_point(c(0, 0))),
    crs = 32631
  )

  result <- aoe(pts, support, reference = custom_ref)

  expect_equal(nrow(result), 1)
  expect_equal(result$aoe_class, "core")
})

test_that("aoe applies mask correctly", {
  skip_if_not_installed("sf")
  library(sf)

  # Support centered at (50, 50) with size 20x20
  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(40, 60, 60, 40, 40), c(40, 40, 60, 60, 40))
    ))),
    crs = 32631
  )

  # Mask that covers only left half (x < 55)
  mask <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 55, 55, 0, 0), c(0, 0, 100, 100, 0))
    ))),
    crs = 32631
  )

  # Point in halo region on right side (outside mask)
  pts <- st_as_sf(
    data.frame(id = 1:2),
    geometry = st_sfc(
      st_point(c(50, 50)),  # core, inside mask
      st_point(c(70, 50))   # would be halo, but outside mask
    ),
    crs = 32631
  )

  result <- aoe(pts, support, mask = mask)

  # Only one point should remain (the core one inside mask)
  expect_equal(nrow(result), 1)
  expect_equal(result$aoe_class, "core")
})

test_that("points on original boundary are classified as core", {
  skip_if_not_installed("sf")
  library(sf)

  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 10, 10, 0, 0), c(0, 0, 10, 10, 0))
    ))),
    crs = 32631
  )

  # Point exactly on boundary
  pts <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_point(c(10, 5))),
    crs = 32631
  )

  result <- aoe(pts, support)

  expect_equal(nrow(result), 1)
  expect_equal(result$aoe_class, "core")
})
