# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Package Overview

areaOfEffect is an R package for spatial support classification in ecological analysis. It classifies occurrence points as "core" (inside original support polygon) or "halo" (inside expanded area of effect but outside original), pruning points outside both. The default expansion produces equal core and halo areas.

## Development Commands

```bash
# Run tests
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "testthat::test_local()"

# Run single test file
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "testthat::test_file('tests/testthat/test-aoe.R')"

# Check package (R CMD check equivalent)
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "devtools::check()"

# Build documentation (roxygen2)
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "devtools::document()"

# Install package locally
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "devtools::install()"

# Build pkgdown site
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" -e "source('~/.R/build_pkgdown.R'); build_pkgdown_site()"
```

## Architecture

### Core Functions (R/)

- **aoe.R**: Main `aoe()` function - classifies points relative to support polygons
  - Supports country names/codes (uses bundled `countries` data) or custom sf polygons
  - Two expansion methods: `buffer` (uniform boundary expansion) and `stamp` (vertex scaling from centroid)
  - `scale` parameter controls halo size; `area` parameter finds scale achieving target masked halo area
  - `mask` parameter clips expansion (e.g., `mask = "land"` clips to coastlines)

- **aoe_border.R**: `aoe_border()` - classifies points by distance from a line (border)
  - Creates symmetric buffer zones on both sides
  - Returns `aoe_border_result` S3 class with side and core/halo classification

- **aoe_class.R**: S3 class infrastructure for `aoe_result`
  - `print`, `summary`, `plot`, and `[` methods
  - Stores geometries as attributes for later extraction

- **aoe_geometry.R**: `aoe_geometry()` - extracts support/AoE polygons from results

- **aoe_area.R**: `aoe_area()` - area diagnostics (original, raw AoE, masked AoE)

- **aoe_expand.R**: `aoe_expand()` - expand geometries without point classification

- **aoe_sample.R**: `aoe_sample()` - stratified sampling from results (by support, class, or side)

- **aoe_summary.R**: `aoe_summary()` - point counts by support and class

### Bundled Data (data/)

- `countries.rda`: Country boundaries (sf) for lookup by name or ISO code
- `land.rda`: Global land polygon for coastline masking
- `country_halos.rda`: Pre-computed country halos

### Key Dependencies

- **sf**: All spatial operations (required)
- **lwgeom**: Optional, used for `st_split()` in border splitting (fallback exists)

## Code Patterns

### Geometry Expansion

Buffer method solves for distance `d` where `π*d² + P*d = A_target` (perimeter formula), then binary searches for exact fit.

Stamp method applies affine transformation: `p' = r + (1+scale)(p - r)` from reference point.

### Area Mode vs Scale Mode

- `scale` parameter: direct geometric scaling (halo area = original × ((1+scale)² - 1))
- `area` parameter: finds scale that produces target halo area *after* mask intersection, using secant method

### S3 Classes

- `aoe_result`: Extends sf, stores geometries in `aoe_geometries` attribute
- `aoe_border_result`: Extends sf, stores border/zone geometries in `border_geometries` attribute
- Both preserve attributes through subsetting via custom `[` methods
