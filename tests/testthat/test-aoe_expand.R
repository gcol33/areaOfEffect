test_that("aoe_expand finds minimum scale to capture target points", {
  skip_if_not_installed("sf")
  library(sf)

  # Create a square support
  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))
    ))),
    crs = 32631
  )

  # Create points: 5 in core, 10 in halo at various distances
  pts <- st_as_sf(
    data.frame(id = 1:15),
    geometry = st_sfc(
      # Core points (inside 0-100, 0-100)
      st_point(c(50, 50)),
      st_point(c(25, 25)),
      st_point(c(75, 75)),
      st_point(c(10, 90)),
      st_point(c(90, 10)),
      # Halo points at increasing distances
      st_point(c(110, 50)),   # close halo
      st_point(c(120, 50)),   # medium halo
      st_point(c(130, 50)),   # medium halo
      st_point(c(140, 50)),   # far halo
      st_point(c(150, 50)),   # far halo
      st_point(c(-10, 50)),   # close halo other side
      st_point(c(-20, 50)),   # medium halo other side
      st_point(c(-30, 50)),   # medium halo other side
      st_point(c(-40, 50)),   # far halo other side
      st_point(c(-50, 50))    # far halo other side
    ),
    crs = 32631
  )

  # Request 8 points (5 core + 3 halo needed)
  result <- aoe_expand(pts, support, min_points = 8)

  expect_s3_class(result, "aoe_expand_result")
  expect_s3_class(result, "aoe_result")
  expect_gte(nrow(result), 8)

  # Check expansion info
  info <- attr(result, "expansion_info")
  expect_true(!is.null(info))
  expect_equal(info$target_reached, TRUE)
  expect_gt(info$scale_used, 0)  # Had to expand

  # The scale should be minimal - just enough to get 8 points
  # Requesting more points should require larger scale
  result_more <- aoe_expand(pts, support, min_points = 12)
  info_more <- attr(result_more, "expansion_info")
  expect_gt(info_more$scale_used, info$scale_used)
})


test_that("aoe_expand respects max_area cap", {
  skip_if_not_installed("sf")
  library(sf)

  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))
    ))),
    crs = 32631
  )

  # Points very far away - would need huge expansion
  pts <- st_as_sf(
    data.frame(id = 1:10),
    geometry = st_sfc(
      st_point(c(50, 50)),      # core
      st_point(c(500, 50)),     # very far
      st_point(c(-400, 50)),    # very far
      st_point(c(50, 500)),     # very far
      st_point(c(50, -400)),    # very far
      st_point(c(300, 300)),    # very far
      st_point(c(-300, 300)),   # very far
      st_point(c(300, -300)),   # very far
      st_point(c(-300, -300)),  # very far
      st_point(c(1000, 1000))   # extremely far
    ),
    crs = 32631
  )

  # Request many points with strict cap
  expect_warning(
    result <- aoe_expand(pts, support, min_points = 8, max_area = 0.5),
    "Could not reach"
  )

  info <- attr(result, "expansion_info")
  expect_false(info$target_reached)
  expect_equal(info$cap_hit, "max_area")

  # Max scale for max_area = 0.5 is sqrt(1.5) - 1 ≈ 0.225
  max_scale_expected <- sqrt(1 + 0.5) - 1
  expect_lte(info$scale_used, max_scale_expected + 0.01)
})


test_that("aoe_expand respects max_dist cap", {
  skip_if_not_installed("sf")
  library(sf)

  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))
    ))),
    crs = 32631
  )

  # Points at various distances
  pts <- st_as_sf(
    data.frame(id = 1:6),
    geometry = st_sfc(
      st_point(c(50, 50)),    # core
      st_point(c(110, 50)),   # 10m from boundary
      st_point(c(130, 50)),   # 30m from boundary
      st_point(c(150, 50)),   # 50m from boundary
      st_point(c(200, 50)),   # 100m from boundary
      st_point(c(300, 50))    # 200m from boundary
    ),
    crs = 32631
  )

  # Cap at 20m expansion - should only get first 2 halo points
  expect_warning(
    result <- aoe_expand(pts, support, min_points = 5, max_dist = 20, max_area = Inf),
    "Could not reach"
  )

  info <- attr(result, "expansion_info")
  expect_false(info$target_reached)
  expect_equal(info$cap_hit, "max_dist")
})


test_that("aoe_expand returns scale=0 when core has enough points", {
  skip_if_not_installed("sf")
  library(sf)

  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))
    ))),
    crs = 32631
  )

  # All points in core
  pts <- st_as_sf(
    data.frame(id = 1:10),
    geometry = st_sfc(lapply(1:10, function(i) {
      st_point(c(runif(1, 10, 90), runif(1, 10, 90)))
    })),
    crs = 32631
  )

  result <- aoe_expand(pts, support, min_points = 5)

  info <- attr(result, "expansion_info")
  expect_equal(info$scale_used, 0)
  expect_true(info$target_reached)
  expect_true(all(result$aoe_class == "core"))
})


test_that("aoe_expand validates inputs", {
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

  # Missing min_points
  expect_error(aoe_expand(pts, support), "min_points")

  # Invalid min_points
  expect_error(aoe_expand(pts, support, min_points = -1), "min_points")
  expect_error(aoe_expand(pts, support, min_points = "abc"), "min_points")

  # Invalid max_area
  expect_error(aoe_expand(pts, support, min_points = 1, max_area = -1), "max_area")

  # Invalid max_dist
  expect_error(aoe_expand(pts, support, min_points = 1, max_dist = -1), "max_dist")
})


test_that("aoe_expand works with multiple supports", {
  skip_if_not_installed("sf")
  library(sf)

  # Two adjacent supports
  supports <- st_as_sf(
    data.frame(region = c("A", "B")),
    geometry = st_sfc(
      st_polygon(list(cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0)))),
      st_polygon(list(cbind(c(150, 250, 250, 150, 150), c(0, 0, 100, 100, 0))))
    ),
    crs = 32631
  )

  # Points: some in A, some in B, some in between
  pts <- st_as_sf(
    data.frame(id = 1:8),
    geometry = st_sfc(
      st_point(c(50, 50)),    # core A
      st_point(c(25, 75)),    # core A
      st_point(c(110, 50)),   # halo A
      st_point(c(200, 50)),   # core B
      st_point(c(175, 75)),   # core B
      st_point(c(140, 50)),   # halo B (and maybe halo A)
      st_point(c(125, 50)),   # between (halo for both potentially)
      st_point(c(500, 500))   # outside
    ),
    crs = 32631
  )

  result <- aoe_expand(pts, supports, min_points = 3)

  expect_s3_class(result, "aoe_expand_result")

  info <- attr(result, "expansion_info")
  expect_equal(nrow(info), 2)
  # Support IDs are row names (1, 2), not column values
  expect_true(all(c("1", "2") %in% info$support_id))
})


test_that("aoe_expand print method works", {
  skip_if_not_installed("sf")
  library(sf)

  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))
    ))),
    crs = 32631
  )

  pts <- st_as_sf(
    data.frame(id = 1:5),
    geometry = st_sfc(
      st_point(c(50, 50)),
      st_point(c(25, 25)),
      st_point(c(110, 50)),
      st_point(c(120, 50)),
      st_point(c(130, 50))
    ),
    crs = 32631
  )

  result <- aoe_expand(pts, support, min_points = 4)

  output <- capture.output(print(result))
  expect_true(any(grepl("Expansion Info", output)))
  expect_true(any(grepl("min_points", output)))
})


test_that("aoe_expand works with mask", {
  skip_if_not_installed("sf")
  library(sf)

  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))
    ))),
    crs = 32631
  )

  # Mask that clips the right side
  mask <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(-200, 120, 120, -200, -200), c(-200, -200, 200, 200, -200))
    ))),
    crs = 32631
  )

  # Points on both sides
  pts <- st_as_sf(
    data.frame(id = 1:6),
    geometry = st_sfc(
      st_point(c(50, 50)),    # core
      st_point(c(110, 50)),   # halo, inside mask
      st_point(c(150, 50)),   # outside mask (should be excluded)
      st_point(c(-10, 50)),   # halo, inside mask
      st_point(c(-50, 50)),   # halo, inside mask
      st_point(c(-100, 50))   # halo, inside mask
    ),
    crs = 32631
  )

  result <- aoe_expand(pts, support, min_points = 4, mask = mask)

  # Point at (150, 50) should never be included because it's outside mask
  expect_false(3 %in% result$id)
})
