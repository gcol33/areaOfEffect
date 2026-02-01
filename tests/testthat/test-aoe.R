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
      st_point(c(15, 5)),   # halo (outside original, inside scaled with scale=1)
      st_point(c(50, 50))   # outside (should be pruned)
    ),
    crs = 32631
  )

  result <- aoe(pts, support, scale = 1)

  # Should return 3 points (one pruned)
  expect_equal(nrow(result), 3)

  # Check it's an aoe_result

  expect_s3_class(result, "aoe_result")
  expect_s3_class(result, "sf")

  # Check columns exist
  expect_true("point_id" %in% names(result))
  expect_true("support_id" %in% names(result))
  expect_true("aoe_class" %in% names(result))

  # Check classification
  expect_true(all(result$aoe_class[result$id %in% c(1, 2)] == "core"))
  expect_equal(result$aoe_class[result$id == 3], "halo")

  # Check attributes
  expect_equal(attr(result, "aoe_scale"), 1)
  expect_equal(attr(result, "aoe_n_supports"), 1)
  expect_true(!is.null(attr(result, "aoe_geometries")))
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

  result <- aoe(pts, supports, scale = 1)

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
  expect_s3_class(result, "aoe_result")
  expect_true("point_id" %in% names(result))
  expect_true("aoe_class" %in% names(result))
  expect_true("support_id" %in% names(result))
  expect_equal(attr(result, "aoe_scale"), sqrt(2) - 1)
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

  # data.frame input works (returns aoe_result)
  df_result <- aoe(data.frame(x = 5, y = 5), support)
  expect_s3_class(df_result, "aoe_result")
  expect_true("aoe_class" %in% names(df_result))

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
    aoe(pts, supports, scale = 1, method = "stamp", reference = ref),
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

  result <- aoe(pts, support, scale = 1, method = "stamp", reference = custom_ref)

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

  result <- aoe(pts, support, scale = 1, mask = mask)

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
      st_point(c(15, 5)),   # halo (with scale=1)
      st_point(c(12, 5))    # halo (with scale=1)
    ),
    crs = 32631
  )

  result <- aoe(pts, support, scale = 1)
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


# Tests for aoe_result S3 class

test_that("print.aoe_result works", {
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
    data.frame(id = 1:3),
    geometry = st_sfc(
      st_point(c(5, 5)),
      st_point(c(15, 5)),
      st_point(c(2, 2))
    ),
    crs = 32631
  )

  result <- aoe(pts, support)

  # Should print without error
  expect_output(print(result), "Area of Effect Result")
  expect_output(print(result), "Points:")
  expect_output(print(result), "Supports:")
})

test_that("summary.aoe_result returns aoe_summary_result", {
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
    data.frame(id = 1:3),
    geometry = st_sfc(
      st_point(c(5, 5)),
      st_point(c(15, 5)),
      st_point(c(2, 2))
    ),
    crs = 32631
  )

  result <- aoe(pts, support)
  summ <- summary(result)

  expect_s3_class(summ, "aoe_summary_result")
  expect_true("area_original" %in% names(summ))
  expect_true("area_aoe" %in% names(summ))
  expect_true("area_ratio" %in% names(summ))
})

test_that("subsetting aoe_result preserves class", {
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
    data.frame(id = 1:3),
    geometry = st_sfc(
      st_point(c(5, 5)),
      st_point(c(15, 5)),
      st_point(c(2, 2))
    ),
    crs = 32631
  )

  result <- aoe(pts, support)
  subset_result <- result[1:2, ]

  expect_s3_class(subset_result, "aoe_result")
  expect_true(!is.null(attr(subset_result, "aoe_geometries")))
})


# Tests for aoe_geometry

test_that("aoe_geometry extracts geometries correctly", {
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
    data.frame(id = 1:3),
    geometry = st_sfc(
      st_point(c(5, 5)),
      st_point(c(15, 5)),
      st_point(c(2, 2))
    ),
    crs = 32631
  )

  result <- aoe(pts, support)

  # Get AoE geometry
  aoe_geom <- aoe_geometry(result, "aoe")
  expect_s3_class(aoe_geom, "sf")
  expect_equal(nrow(aoe_geom), 1)
  expect_equal(aoe_geom$type[1], "aoe")

  # Get original geometry
  orig_geom <- aoe_geometry(result, "original")
  expect_equal(nrow(orig_geom), 1)
  expect_equal(orig_geom$type[1], "original")

  # Get both
  both_geom <- aoe_geometry(result, "both")
  expect_equal(nrow(both_geom), 2)
})

test_that("aoe_geometry filters by support_id", {
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
      st_point(c(5, 5)),
      st_point(c(25, 5))
    ),
    crs = 32631
  )

  result <- aoe(pts, supports)

  # Filter to one support
  geom_1 <- aoe_geometry(result, "aoe", support_id = "1")
  expect_equal(nrow(geom_1), 1)
  expect_equal(geom_1$support_id[1], "1")
})


# Tests for aoe_area

test_that("aoe respects scale parameter", {
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
    data.frame(id = 1:2),
    geometry = st_sfc(
      st_point(c(5, 5)),   # core
      st_point(c(12, 5))   # might be halo or pruned depending on scale
    ),
    crs = 32631
  )

  # Default scale = sqrt(2) - 1 (equal areas)
  result1 <- aoe(pts, support)
  expect_equal(attr(result1, "aoe_scale"), sqrt(2) - 1, tolerance = 0.001)

  # Scale = 1 (ray-equal)
  result2 <- aoe(pts, support, scale = 1)
  expect_equal(attr(result2, "aoe_scale"), 1)
  expect_equal(nrow(result2), 2)  # both points included with scale=1

  # Very small scale should prune the halo point
  result3 <- aoe(pts, support, scale = 0.1)
  expect_equal(attr(result3, "aoe_scale"), 0.1)
  expect_equal(nrow(result3), 1)  # only core point

  # Scale validation
  expect_error(aoe(pts, support, scale = 0), "positive")
  expect_error(aoe(pts, support, scale = -1), "positive")
  expect_error(aoe(pts, support, scale = "foo"), "positive")
})

test_that("aoe_area computes correct statistics", {
  skip_if_not_installed("sf")
  library(sf)

  # 10x10 square = 100 m² area
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

  # Test with scale = 1 for predictable area values
  result <- aoe(pts, support, scale = 1)
  area_stats <- aoe_area(result)

  expect_s3_class(area_stats, "aoe_area_result")
  expect_equal(nrow(area_stats), 1)

  # Core area should be 100 m²
  expect_equal(area_stats$area_core[1], 100, tolerance = 0.01)

  # Halo area should be 300 m² (3x core with scale=1)
  expect_equal(area_stats$area_halo[1], 300, tolerance = 0.01)

  # Total AoE area should be 400 m² (4x core with scale=1)
  expect_equal(area_stats$area_aoe[1], 400, tolerance = 0.01)

  # Halo:core ratio should be 3 with scale=1
  expect_equal(area_stats$halo_core_ratio[1], 3, tolerance = 0.01)

  # No mask, so no masking
  expect_equal(area_stats$pct_masked[1], 0, tolerance = 0.01)
})

test_that("aoe_area with default scale gives equal areas", {
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

  # Default scale should give equal core/halo areas
  result <- aoe(pts, support)
  area_stats <- aoe_area(result)

  # Halo:core ratio should be ~1.0 with default scale
  expect_equal(area_stats$halo_core_ratio[1], 1, tolerance = 0.01)
})

test_that("aoe_area shows masking effect", {
  skip_if_not_installed("sf")
  library(sf)

  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(40, 60, 60, 40, 40), c(40, 40, 60, 60, 40))
    ))),
    crs = 32631
  )

  # Mask that covers only part
  mask <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 55, 55, 0, 0), c(0, 0, 100, 100, 0))
    ))),
    crs = 32631
  )

  pts <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_point(c(50, 50))),
    crs = 32631
  )

  result <- aoe(pts, support, scale = 1, mask = mask)
  area_stats <- aoe_area(result)

  # Some area should be masked
  expect_true(area_stats$pct_masked[1] > 0)

  # Halo:core ratio should be less than 3 due to masking
  expect_true(area_stats$halo_core_ratio[1] < 3)

  # Total AoE should be less than theoretical 4x core
  expect_true(area_stats$area_aoe[1] < area_stats$area_core[1] * 4)
})


# Tests for plot.aoe_result

test_that("plot.aoe_result runs without error", {
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
    data.frame(id = 1:3),
    geometry = st_sfc(
      st_point(c(5, 5)),
      st_point(c(15, 5)),
      st_point(c(2, 2))
    ),
    crs = 32631
  )

  result <- aoe(pts, support)

  # Should plot without error
  expect_silent(plot(result))
  expect_silent(plot(result, show_aoe = FALSE))
  expect_silent(plot(result, show_original = FALSE))
})


# Tests for area parameter

test_that("area and scale are mutually exclusive", {
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

  expect_error(aoe(pts, support, scale = 1, area = 1), "both")
})

test_that("area parameter validates input", {
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

  expect_error(aoe(pts, support, area = 0), "positive")
  expect_error(aoe(pts, support, area = -1), "positive")
  expect_error(aoe(pts, support, area = "foo"), "positive")
})

test_that("area parameter produces correct halo area without mask", {
  skip_if_not_installed("sf")
  library(sf)

  # 10x10 square = 100 m² area
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

  # area = 1 means halo area = 100 m² (same as original)
  result <- aoe(pts, support, area = 1)
  area_stats <- aoe_area(result)

  # Halo area should equal core area (within tolerance)
  expect_equal(area_stats$halo_core_ratio[1], 1, tolerance = 0.01)

  # Check attribute is set
  expect_equal(attr(result, "aoe_area"), 1)
  expect_null(attr(result, "aoe_scale"))
})

test_that("area parameter produces correct halo area with mask", {
  skip_if_not_installed("sf")
  library(sf)

  # 20x20 square = 400 m² area
  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(40, 60, 60, 40, 40), c(40, 40, 60, 60, 40))
    ))),
    crs = 32631
  )

  # Mask that clips part of the AoE
  mask <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(30, 70, 70, 30, 30), c(30, 30, 65, 65, 30))
    ))),
    crs = 32631
  )

  pts <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_point(c(50, 50))),
    crs = 32631
  )

  # area = 0.5 means halo area should be 200 m² (half of original)
  result <- aoe(pts, support, area = 0.5, mask = mask)
  area_stats <- aoe_area(result)

  # Halo area should be 0.5 times core area (within tolerance)
  # The mask clips the AoE, but the algorithm should find a scale that
  # produces the correct masked halo area
  expect_equal(area_stats$halo_core_ratio[1], 0.5, tolerance = 0.02)
})

test_that("print.aoe_result shows area instead of scale when using area", {
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

  result <- aoe(pts, support, area = 1)

  expect_output(print(result), "Area:")
})

test_that("subsetting aoe_result preserves area attribute", {
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
    data.frame(id = 1:2),
    geometry = st_sfc(
      st_point(c(5, 5)),
      st_point(c(12, 5))
    ),
    crs = 32631
  )

  result <- aoe(pts, support, area = 1)
  subset_result <- result[1, ]

  expect_equal(attr(subset_result, "aoe_area"), 1)
})


# Tests for largest_polygon parameter

test_that("largest_polygon filters to largest polygon in MULTIPOLYGON", {
  skip_if_not_installed("sf")
  library(sf)

  # Create MULTIPOLYGON with 'mainland' (100x100) and 'island' (10x10)
  mainland <- st_polygon(list(cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))))
  island <- st_polygon(list(cbind(c(150, 160, 160, 150, 150), c(40, 40, 50, 50, 40))))

  multi <- st_multipolygon(list(mainland, island))
  support <- st_as_sf(data.frame(id = 1), geometry = st_sfc(multi, crs = 32631))

  # Points: one on mainland, one on island
  pts <- st_as_sf(
    data.frame(id = 1:2),
    geometry = st_sfc(
      st_point(c(50, 50)),   # mainland
      st_point(c(155, 45))   # island
    ),
    crs = 32631
  )

  # With largest_polygon = TRUE (default), island point should be pruned
  expect_message(
    result1 <- aoe(pts, support),
    "largest polygon"
  )
  expect_equal(nrow(result1), 1)
  expect_equal(result1$id[1], 1)

  # With largest_polygon = FALSE, both points classified
  result2 <- aoe(pts, support, largest_polygon = FALSE)
  expect_equal(nrow(result2), 2)
})

test_that("largest_polygon does nothing for single POLYGON", {
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

  # No message when there's only one polygon
  expect_silent(result <- aoe(pts, support))
  expect_equal(nrow(result), 1)
})

test_that("largest_polygon message shows correct statistics", {
  skip_if_not_installed("sf")
  library(sf)

  # Mainland = 10000 m², island = 100 m² (99% mainland)
  mainland <- st_polygon(list(cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))))
  island <- st_polygon(list(cbind(c(150, 160, 160, 150, 150), c(40, 40, 50, 50, 40))))

  multi <- st_multipolygon(list(mainland, island))
  support <- st_as_sf(data.frame(id = 1), geometry = st_sfc(multi, crs = 32631))

  pts <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_point(c(50, 50))),
    crs = 32631
  )

  # Message should show ~99% and 1 dropped polygon
  expect_message(
    aoe(pts, support),
    "99"
  )
  expect_message(
    aoe(pts, support),
    "1 smaller polygon"
  )
})
