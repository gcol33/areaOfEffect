test_that("aoe_sample balances core/halo with default ratio", {
  skip_if_not_installed("sf")
  library(sf)

  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))
    ))),
    crs = 32631
  )

  # 50 core points, 10 halo points
  set.seed(42)
  pts <- st_as_sf(
    data.frame(id = 1:60),
    geometry = st_sfc(c(
      lapply(1:50, function(i) st_point(c(runif(1, 10, 90), runif(1, 10, 90)))),
      lapply(1:10, function(i) st_point(c(runif(1, 110, 140), runif(1, 10, 90))))
    )),
    crs = 32631
  )

  result <- aoe(pts, support, scale = 1)

  # Default balanced sampling (n = NULL, ratio = 0.5/0.5)
  set.seed(123)
  sampled <- aoe_sample(result)

  # Should downsample to match halo (10 core + 10 halo = 20)
  expect_equal(nrow(sampled), 20)
  expect_equal(sum(sampled$aoe_class == "core"), 10)
  expect_equal(sum(sampled$aoe_class == "halo"), 10)

  # Check it's still an aoe_result
  expect_s3_class(sampled, "aoe_result")

  # Check sample_info attribute
  info <- attr(sampled, "sample_info")
  expect_true(!is.null(info))
  expect_equal(info$n_core_available, 50)
  expect_equal(info$n_halo_available, 10)
})


test_that("aoe_sample respects fixed n with ratio", {
  skip_if_not_installed("sf")
  library(sf)

  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))
    ))),
    crs = 32631
  )

  set.seed(42)
  pts <- st_as_sf(
    data.frame(id = 1:60),
    geometry = st_sfc(c(
      lapply(1:50, function(i) st_point(c(runif(1, 10, 90), runif(1, 10, 90)))),
      lapply(1:10, function(i) st_point(c(runif(1, 110, 140), runif(1, 10, 90))))
    )),
    crs = 32631
  )

  result <- aoe(pts, support, scale = 1)

  # Sample 20 points with 70/30 split
  set.seed(123)
  sampled <- aoe_sample(result, n = 20, ratio = c(core = 0.7, halo = 0.3))

  expect_equal(nrow(sampled), 20)
  expect_equal(sum(sampled$aoe_class == "core"), 14)  # 70% of 20
  expect_equal(sum(sampled$aoe_class == "halo"), 6)   # 30% of 20
})


test_that("aoe_sample handles insufficient points gracefully", {
  skip_if_not_installed("sf")
  library(sf)

  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))
    ))),
    crs = 32631
  )

  # Only 5 core, 3 halo
  pts <- st_as_sf(
    data.frame(id = 1:8),
    geometry = st_sfc(
      st_point(c(50, 50)),
      st_point(c(25, 25)),
      st_point(c(75, 75)),
      st_point(c(10, 10)),
      st_point(c(90, 90)),
      st_point(c(110, 50)),
      st_point(c(120, 50)),
      st_point(c(130, 50))
    ),
    crs = 32631
  )

  result <- aoe(pts, support, scale = 1)

  # Request more than available (without replacement)
  set.seed(123)
  sampled <- aoe_sample(result, n = 100, ratio = c(core = 0.5, halo = 0.5))

  # Should get all available (5 core + 3 halo = 8 max, but limited by ratio)
  # With n=100 and 0.5/0.5, target is 50 core + 50 halo
  # But only 5 core and 3 halo available, so get 5 + 3 = 8
  expect_lte(nrow(sampled), 8)
})


test_that("aoe_sample works with replacement", {
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
      st_point(c(75, 75)),
      st_point(c(110, 50)),
      st_point(c(120, 50))
    ),
    crs = 32631
  )

  result <- aoe(pts, support, scale = 1)

  # Sample more than available with replacement
  set.seed(123)
  sampled <- aoe_sample(result, n = 20, ratio = c(core = 0.5, halo = 0.5),
                        replace = TRUE)

  expect_equal(nrow(sampled), 20)
  expect_equal(sum(sampled$aoe_class == "core"), 10)
  expect_equal(sum(sampled$aoe_class == "halo"), 10)
})


test_that("aoe_sample by = 'support' samples within each support", {
  skip_if_not_installed("sf")
  library(sf)

  # Two supports
  supports <- st_as_sf(
    data.frame(region = c("A", "B")),
    geometry = st_sfc(
      st_polygon(list(cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0)))),
      st_polygon(list(cbind(c(200, 300, 300, 200, 200), c(0, 0, 100, 100, 0))))
    ),
    crs = 32631
  )

  # Points in both supports
  pts <- st_as_sf(
    data.frame(id = 1:12),
    geometry = st_sfc(
      # Support A: 4 core, 2 halo
      st_point(c(50, 50)),
      st_point(c(25, 25)),
      st_point(c(75, 75)),
      st_point(c(10, 10)),
      st_point(c(110, 50)),
      st_point(c(120, 50)),
      # Support B: 3 core, 3 halo
      st_point(c(250, 50)),
      st_point(c(225, 25)),
      st_point(c(275, 75)),
      st_point(c(310, 50)),
      st_point(c(320, 50)),
      st_point(c(330, 50))
    ),
    crs = 32631
  )

  result <- aoe(pts, supports, scale = 1)

  set.seed(123)
  sampled <- aoe_sample(result, by = "support")

  # Check sample_info has per-support info
  info <- attr(sampled, "sample_info")
  expect_equal(nrow(info), 2)
  expect_true("support_id" %in% names(info))
})


test_that("aoe_sample validates inputs", {
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
    geometry = st_sfc(st_point(c(5, 5)), st_point(c(15, 5))),
    crs = 32631
  )

  result <- aoe(pts, support, scale = 1)

  # Not an aoe_result
  expect_error(aoe_sample(pts), "aoe_result")

  # Invalid ratio
  expect_error(aoe_sample(result, ratio = c(0.3, 0.3)), "sum to 1")
  expect_error(aoe_sample(result, ratio = c(a = 0.5, b = 0.5)), "core.*halo")
  expect_error(aoe_sample(result, ratio = c(-0.1, 1.1)), "non-negative")

  # Invalid n
  expect_error(aoe_sample(result, n = -1), "positive")
  expect_error(aoe_sample(result, n = "abc"), "positive")

  # Invalid replace
  expect_error(aoe_sample(result, replace = "yes"), "TRUE or FALSE")
})


test_that("aoe_sample handles empty result", {
  skip_if_not_installed("sf")
  library(sf)

  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 10, 10, 0, 0), c(0, 0, 10, 10, 0))
    ))),
    crs = 32631
  )

  # Point outside AoE
  pts <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_point(c(500, 500))),
    crs = 32631
  )

  result <- aoe(pts, support, scale = 1)

  sampled <- aoe_sample(result)
  expect_equal(nrow(sampled), 0)
})


test_that("aoe_sample preserves aoe_result attributes", {
  skip_if_not_installed("sf")
  library(sf)

  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))
    ))),
    crs = 32631
  )

  set.seed(42)
  pts <- st_as_sf(
    data.frame(id = 1:20),
    geometry = st_sfc(c(
      lapply(1:15, function(i) st_point(c(runif(1, 10, 90), runif(1, 10, 90)))),
      lapply(1:5, function(i) st_point(c(runif(1, 110, 140), runif(1, 10, 90))))
    )),
    crs = 32631
  )

  result <- aoe(pts, support, scale = 0.5)

  set.seed(123)
  sampled <- aoe_sample(result, n = 10)

  # Check attributes preserved
  expect_equal(attr(sampled, "aoe_scale"), 0.5)
  expect_equal(attr(sampled, "aoe_n_supports"), 1)
  expect_true(!is.null(attr(sampled, "aoe_geometries")))
})


test_that("aoe_sample handles only core or only halo points", {
  skip_if_not_installed("sf")
  library(sf)

  support <- st_as_sf(
    data.frame(id = 1),
    geometry = st_sfc(st_polygon(list(
      cbind(c(0, 100, 100, 0, 0), c(0, 0, 100, 100, 0))
    ))),
    crs = 32631
  )

  # Only core points
  pts_core <- st_as_sf(
    data.frame(id = 1:5),
    geometry = st_sfc(lapply(1:5, function(i) st_point(c(50, 50)))),
    crs = 32631
  )

  result_core <- aoe(pts_core, support, scale = 1)

  # With ratio requiring halo, should only get core
  sampled <- aoe_sample(result_core, ratio = c(core = 0.5, halo = 0.5))
  expect_equal(nrow(sampled), 0)  # Can't satisfy ratio with 0 halo

  # With all-core ratio
  sampled_all_core <- aoe_sample(result_core, n = 3, ratio = c(core = 1, halo = 0))
  expect_equal(nrow(sampled_all_core), 3)
  expect_true(all(sampled_all_core$aoe_class == "core"))
})
