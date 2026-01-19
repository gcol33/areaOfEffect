test_that("aoe classifies points correctly (single support)", {
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

  # Check columns exist
  expect_true("support_id" %in% names(result))
  expect_true("aoe_class" %in% names(result))

  # Check classification
  expect_true(all(result$aoe_class[result$id %in% c(1, 2)] == "core"))
  expect_equal(result$aoe_class[result$id == 3], "halo")

  # Check attributes
  expect_equal(attr(result, "scale"), 1)
})

test_that("aoe handles multiple supports (long format)", {
  skip_if_not_installed("sf")
  library(sf)

  # Two overlapping supports
  supports <- st_as_sf(
    data.frame(region = c("A", "B")),
    geometry = st_sfc(
      st_polygon(list(cbind(c(0, 10, 10, 0, 0), c(0, 0, 10, 10, 0)))),
      st_polygon(list(cbind(c(8, 18, 18, 8, 8), c(0, 0, 10, 10, 0))))
    ),
    crs = 32631
  )

  pts <- st_as_sf(
    data.frame(id = 1:3),
    geometry = st_sfc(
      st_point(c(5, 5)),   # inside A only
      st_point(c(9, 5)),   # inside both A and B
      st_point(c(15, 5))   # inside B only
    ),
    crs = 32631
  )

  result <- aoe(pts, supports)

  # Point at (9,5) should appear twice (once for each support)
  expect_true(nrow(result) >= 3)

  # Check support_id values
  expect_true(all(result$support_id %in% c("1", "2")))

  # Check that id=2 appears in both supports
  id2_rows <- result[result$id == 2, ]
  expect_true(nrow(id2_rows) == 2)
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
  expect_true("support_id" %in% names(result))
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

test_that("aoe errors when reference provided with multiple supports", {
  skip_if_not_installed("sf")
  library(sf)

  supports <- st_as_sf(
    data.frame(id = 1:2),
    geometry = st_sfc(
      st_polygon(list(cbind(c(0, 10, 10, 0, 0), c(0, 0, 10, 10, 0)))),
      st_polygon(list(cbind(c(20, 30, 30, 20, 20), c(0, 0, 10, 10, 0))))
    ),
    crs = 32631
  )

  pts <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_point(c(5, 5))),
    crs = 32631
  )

  ref <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_point(c(0, 0))),
    crs = 32631
  )

  expect_error(
    aoe(pts, supports, reference = ref),
    "single row"
  )
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


# Tests for aoe_summary

test_that("aoe_summary computes correct statistics", {
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
    data.frame(id = 1:4),
    geometry = st_sfc(
      st_point(c(5, 5)),    # core
      st_point(c(2, 2)),    # core
      st_point(c(15, 5)),   # halo
      st_point(c(12, 5))    # halo
    ),
    crs = 32631
  )

  result <- aoe(pts, support)
  summary <- aoe_summary(result)

  expect_equal(nrow(summary), 1)
  expect_equal(summary$n_total, 4)
  expect_equal(summary$n_core, 2)
  expect_equal(summary$n_halo, 2)
  expect_equal(summary$prop_core, 0.5)
  expect_equal(summary$prop_halo, 0.5)
})

test_that("aoe_summary handles multiple supports", {
  skip_if_not_installed("sf")
  library(sf)

  supports <- st_as_sf(
    data.frame(region = c("A", "B")),
    geometry = st_sfc(
      st_polygon(list(cbind(c(0, 10, 10, 0, 0), c(0, 0, 10, 10, 0)))),
      st_polygon(list(cbind(c(20, 30, 30, 20, 20), c(0, 0, 10, 10, 0))))
    ),
    crs = 32631
  )

  pts <- st_as_sf(
    data.frame(id = 1:2),
    geometry = st_sfc(
      st_point(c(5, 5)),    # inside A
      st_point(c(25, 5))    # inside B
    ),
    crs = 32631
  )

  result <- aoe(pts, supports)
  summary <- aoe_summary(result)

  expect_equal(nrow(summary), 2)
  expect_true(all(c("1", "2") %in% summary$support_id))
})

test_that("aoe_summary handles empty results", {
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
  summary <- aoe_summary(result)

  expect_equal(nrow(summary), 0)
})

test_that("aoe_summary validates input", {
  expect_error(aoe_summary(data.frame(a = 1)), "sf object")

  skip_if_not_installed("sf")
  library(sf)

  # Missing aoe_class column
  fake_sf <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_point(c(1, 1))),
    crs = 32631
  )
  expect_error(aoe_summary(fake_sf), "aoe_class")
})
