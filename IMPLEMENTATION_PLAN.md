# areaOfEffect Implementation Plan

## Overview

This plan outlines improvements to the areaOfEffect package, focusing on:
1. Better output structure (S3 class with methods)
2. Geometry access (`aoe_geometry()`)
3. ID preservation
4. Diagnostic helpers (`aoe_area()`)
5. Visualization (`plot()` method)

All changes maintain backwards compatibility with existing API.

---

## Phase 1: S3 Class Infrastructure

### 1.1 Create `aoe_result` S3 class

**File**: `R/aoe_class.R`

```r
# Constructor (internal)
new_aoe_result <- function(points, geometries, scale, n_supports) {

  structure(

    points,
    class = c("aoe_result", "sf", "data.frame"),
+    aoe_geometries = geometries,
    aoe_scale = scale,
    aoe_n_supports = n_supports
  )
}
```

**Attributes stored**:
- `aoe_geometries`: list of sf objects (original support, AoE, masked AoE per support)
- `aoe_scale`: numeric (always 1)
- `aoe_n_supports`: integer

### 1.2 Modify `aoe()` to return `aoe_result`

**Changes to `R/aoe.R`**:

1. Collect geometries during processing:
   ```r
   # In process_single_support(), also return:
   # - original support geometry
   # - scaled AoE geometry (before mask)
   # - final AoE geometry (after mask, if applicable)
   ```

2. Wrap result in `new_aoe_result()`

3. Add `point_id` column preserving original row identifiers

**Column structure after change**:
| Column | Description |
|--------|-------------|
| `point_id` | Original point identifier (row name or index) |
| `support_id` | Which support this classification refers to |
| `aoe_class` | "core" or "halo" |
| `geometry` | Point geometry (sf) |
| *(original columns)* | All columns from input points |

---

## Phase 2: Print Method

### 2.1 `print.aoe_result()`

**File**: `R/aoe_class.R`

```r
#' @export
print.aoe_result <- function(x, ...) {
  n_points <- nrow(x)
  n_supports <- attr(x, "aoe_n_supports")
  n_core <- sum(x$aoe_class == "core")
  n_halo <- sum(x$aoe_class == "halo")


  cat("Area of Effect Result\n")
  cat("─────────────────────\n")
  cat(sprintf("Points:   %d (%d core, %d halo)\n", n_points, n_core, n_halo))
  cat(sprintf("Supports: %d\n", n_supports))
  cat(sprintf("Scale:    %d (fixed)\n", attr(x, "aoe_scale")))
  cat("\n")

  # Print first few rows as sf
  NextMethod()
}
```

**Example output**:
```
Area of Effect Result
─────────────────────
Points:   847 (612 core, 235 halo)
Supports: 3
Scale:    1 (fixed)

Simple feature collection with 847 features and 4 fields
Geometry type: POINT
...
```

---

## Phase 3: Summary Method

### 3.1 Enhance `aoe_summary()` → `summary.aoe_result()`

**File**: `R/aoe_class.R`

Keep `aoe_summary()` as standalone function, but also register as S3 method.

```r
#' @export
summary.aoe_result <- function(object, ...) {
  # Return aoe_summary_result S3 class
  result <- aoe_summary(object)
  class(result) <- c("aoe_summary_result", "data.frame")

  # Add area information if geometries available
  geoms <- attr(object, "aoe_geometries")
  if (!is.null(geoms)) {
    result$area_original <- vapply(geoms, function(g) {
      as.numeric(sf::st_area(g$original))
    }, numeric(1))
    result$area_aoe <- vapply(geoms, function(g) {
      as.numeric(sf::st_area(g$aoe_final))
    }, numeric(1))
    result$area_ratio <- result$area_aoe / result$area_original
  }

  result
}

#' @export
print.aoe_summary_result <- function(x, ...) {
  cat("Area of Effect Summary\n")
  cat("──────────────────────\n\n")

  # Format nicely
  print.data.frame(x, row.names = FALSE)
}
```

**Example output**:
```
Area of Effect Summary
──────────────────────

 support_id n_total n_core n_halo prop_core prop_halo  area_original     area_aoe area_ratio
          A     312    245     67      0.79      0.21   1.234e+10     4.936e+10       4.00
          B     298    201     97      0.67      0.33   8.921e+09     3.568e+10       4.00
          C     237    166     71      0.70      0.30   5.443e+09     2.177e+10       4.00
```

---

## Phase 4: Geometry Access

### 4.1 `aoe_geometry()` function

**File**: `R/aoe_geometry.R`

```r
#' Extract AoE Geometries
#'
#' @param x An `aoe_result` object
#' @param which Which geometry to extract: "original", "aoe", or "both"
#' @param support_id Optional: filter to specific support(s)
#'
#' @return An sf object with polygon geometries
#' @export
aoe_geometry <- function(x, which = c("aoe", "original", "both"),
                         support_id = NULL) {
  which <- match.arg(which)
  geoms <- attr(x, "aoe_geometries")

  if (is.null(geoms)) {
    stop("No geometries stored. Rerun aoe() with store_geometry = TRUE",
         call. = FALSE)
  }

  # Filter by support_id if specified
  if (!is.null(support_id)) {
    geoms <- geoms[names(geoms) %in% as.character(support_id)]
  }

  # Extract requested geometries
  result <- switch(which,
    "original" = do.call(rbind, lapply(names(geoms), function(sid) {
      sf::st_sf(
        support_id = sid,
        type = "original",
        geometry = geoms[[sid]]$original
      )
    })),
    "aoe" = do.call(rbind, lapply(names(geoms), function(sid) {
      sf::st_sf(
        support_id = sid,
        type = "aoe",
        geometry = geoms[[sid]]$aoe_final
      )
    })),
    "both" = do.call(rbind, lapply(names(geoms), function(sid) {
      rbind(
        sf::st_sf(support_id = sid, type = "original",
                  geometry = geoms[[sid]]$original),
        sf::st_sf(support_id = sid, type = "aoe",
                  geometry = geoms[[sid]]$aoe_final)
      )
    }))
  )

  result
}
```

**Usage**:
```r
result <- aoe(pts, supports)

# Get AoE polygons
aoe_polys <- aoe_geometry(result, "aoe")

# Get both for comparison
both <- aoe_geometry(result, "both")

# Filter to one support
region_a <- aoe_geometry(result, "aoe", support_id = "A")
```

---

## Phase 5: Plot Method

### 5.1 `plot.aoe_result()`
**File**: `R/aoe_class.R`

```r
#' @export
plot.aoe_result <- function(x,
                            support_id = NULL,
                            show_aoe = TRUE,
                            show_original = TRUE,
                            col_core = "#2E7D32",
                            col_halo = "#F57C00",
                            col_original = "#000000",
                            col_aoe = "#9E9E9E",
                            pch = 16,
                            cex = 0.8,
                            main = NULL,
                            ...) {

  # Filter to support if specified
  if (!is.null(support_id)) {
    x <- x[x$support_id %in% support_id, ]
  }

  geoms <- attr(x, "aoe_geometries")

  # Determine plot extent
  pts_bbox <- sf::st_bbox(x)

  if (!is.null(geoms) && show_aoe) {
    aoe_geom <- aoe_geometry(x, "aoe", support_id)
    aoe_bbox <- sf::st_bbox(aoe_geom)
    pts_bbox <- c(
      xmin = min(pts_bbox["xmin"], aoe_bbox["xmin"]),
      ymin = min(pts_bbox["ymin"], aoe_bbox["ymin"]),
      xmax = max(pts_bbox["xmax"], aoe_bbox["xmax"]),
      ymax = max(pts_bbox["ymax"], aoe_bbox["ymax"])
    )
  }

  # Set up plot
  if (is.null(main)) {
    n_sup <- length(unique(x$support_id))
    main <- sprintf("AoE: %d points, %d support%s",
                    nrow(x), n_sup, if(n_sup > 1) "s" else "")
  }

  plot(1, type = "n",
       xlim = c(pts_bbox["xmin"], pts_bbox["xmax"]),
       ylim = c(pts_bbox["ymin"], pts_bbox["ymax"]),
       asp = 1, main = main, xlab = "", ylab = "", ...)

  # Draw geometries if available
  if (!is.null(geoms)) {
    if (show_aoe) {
      aoe_geom <- aoe_geometry(x, "aoe", support_id)
      plot(sf::st_geometry(aoe_geom),
           border = col_aoe, lty = 2, lwd = 1, add = TRUE)
    }
    if (show_original) {
      orig_geom <- aoe_geometry(x, "original", support_id)
      plot(sf::st_geometry(orig_geom),
           border = col_original, lwd = 2, add = TRUE)
    }
  }

  # Draw points
  core_pts <- x[x$aoe_class == "core", ]
  halo_pts <- x[x$aoe_class == "halo", ]

  if (nrow(halo_pts) > 0) {
    plot(sf::st_geometry(halo_pts),
         col = col_halo, pch = pch, cex = cex, add = TRUE)
  }
  if (nrow(core_pts) > 0) {
    plot(sf::st_geometry(core_pts),
         col = col_core, pch = pch, cex = cex, add = TRUE)
  }

  # Legend
  legend("topright",
         legend = c("Core", "Halo", "Original", "AoE"),
         col = c(col_core, col_halo, col_original, col_aoe),
         pch = c(pch, pch, NA, NA),
         lty = c(NA, NA, 1, 2),
         lwd = c(NA, NA, 2, 1),
         bg = "white",
         cex = 0.8)

  invisible(x)
}
```

**Usage**:
```r
result <- aoe(pts, supports)

# Basic plot
plot(result)

# Single support
plot(result, support_id = "A")

# Custom colors
plot(result, col_core = "blue", col_halo = "red")

# Without AoE boundary
plot(result, show_aoe = FALSE)
```

---

## Phase 6: Area Diagnostics

### 6.1 `aoe_area()` function

**File**: `R/aoe_area.R`

```r
#' Compute Area Statistics for AoE
#'
#' @param x An `aoe_result` object, or support sf for standalone use
#' @param mask Optional mask (if x is support sf)
#'
#' @return Data frame with area statistics per support
#' @export
aoe_area <- function(x, mask = NULL) {

 if (inherits(x, "aoe_result")) {
    # Extract from stored geometries
    geoms <- attr(x, "aoe_geometries")
    if (is.null(geoms)) {
      stop("No geometries stored", call. = FALSE)
    }

    result <- do.call(rbind, lapply(names(geoms), function(sid) {
      g <- geoms[[sid]]
      data.frame(
        support_id = sid,
        area_original = as.numeric(sf::st_area(g$original)),
        area_aoe_raw = as.numeric(sf::st_area(g$aoe_raw)),
        area_aoe_final = as.numeric(sf::st_area(g$aoe_final)),
        stringsAsFactors = FALSE
      )
    }))

  } else if (inherits(x, "sf")) {
    # Compute directly from support
    # ... standalone computation
  }

  # Derived metrics
  result$expansion_ratio <- result$area_aoe_raw / result$area_original
  result$area_masked <- result$area_aoe_raw - result$area_aoe_final
  result$pct_masked <- 100 * result$area_masked / result$area_aoe_raw

  class(result) <- c("aoe_area_result", "data.frame")
  result
}

#' @export
print.aoe_area_result <- function(x, ...) {
  cat("AoE Area Statistics\n")
  cat("───────────────────\n\n")

  # Format areas nicely (km² if large)
  x_print <- x
  area_cols <- c("area_original", "area_aoe_raw", "area_aoe_final", "area_masked")

  for (col in area_cols) {
    if (col %in% names(x_print)) {
      # Convert to km² if > 1e6 m²
      vals <- x_print[[col]]
      if (max(vals, na.rm = TRUE) > 1e6) {
        x_print[[col]] <- sprintf("%.1f km²", vals / 1e6)
      } else {
        x_print[[col]] <- sprintf("%.0f m²", vals)
      }
    }
  }

  x_print$expansion_ratio <- sprintf("%.2fx", x$expansion_ratio)
  x_print$pct_masked <- sprintf("%.1f%%", x$pct_masked)

  print.data.frame(x_print, row.names = FALSE)
}
```

**Example output**:
```
AoE Area Statistics
───────────────────

 support_id area_original  area_aoe_raw area_aoe_final  area_masked expansion_ratio pct_masked
          A    12340.5 km²    49362.0 km²    41205.3 km²    8156.7 km²           4.00x     16.5%
          B     8921.2 km²    35684.8 km²    35684.8 km²       0.0 km²           4.00x      0.0%
```

---

## Implementation Order

| Phase | Component | Effort | Dependencies |
|-------|-----------|--------|--------------|
| 1 | S3 class infrastructure | Medium | None |
| 2 | `print.aoe_result()` | Low | Phase 1 |
| 3 | `summary.aoe_result()` | Low | Phase 1 |
| 4 | `aoe_geometry()` | Medium | Phase 1 |
| 5 | `plot.aoe_result()` | Medium | Phase 1, 4 |
| 6 | `aoe_area()` | Low | Phase 1 |

**Recommended order**: 1 → 2 → 3 → 4 → 6 → 5

Phase 1 is foundational. Phases 2-3-4-6 can be done in any order after Phase 1. Phase 5 depends on Phase 4 for geometry access.

---

## File Structure After Implementation

```
R/
├── aoe.R              # Main function (modified)
├── aoe_class.R        # S3 class, print, summary, plot methods
├── aoe_geometry.R     # aoe_geometry() extractor
├── aoe_area.R         # aoe_area() diagnostics
└── aoe_summary.R      # Standalone summary (kept for backwards compat)
```

---

## Backwards Compatibility

- `aoe()` still returns an sf-compatible object
- All existing code using `result$aoe_class`, `result$support_id` continues to work
- `aoe_summary()` remains available as standalone function
- New functionality is additive

---

## Testing Requirements

Each phase requires tests for:
1. Basic functionality
2. Edge cases (empty results, single support, many supports)
3. S3 method dispatch
4. Attribute preservation through subsetting

---

## Documentation Updates

- Update `aoe.Rd` with new return structure
- Add `aoe_geometry.Rd`
- Add `aoe_area.Rd`
- Update vignettes with plot examples
- Add "Working with Results" vignette
