# Story: areaOfEffect

## Claim
Classifies points as core (inside a region), halo (in a buffer around it) or dropped, with a default buffer whose area equals the region's.

## Audience
Ecologists and geographers who filter occurrence or survey points by region in R with sf.

## Relation
- to: sf (builds on it for projection, buffering, point-in-polygon)
- phrase: run through sf in one call
- same: sf objects in and out
- differs: the buffer width is derived from the region (equal-area default)
- home: vignettes/theory.Rmd

## Arcs

### A1 Core, halo or dropped
- question: which of my points are inside, near or far from the region?
- answer: aoe() with a country name, ISO code, polygon or auto-detection
- home: vignettes/quickstart.Rmd
- also: README Usage

### A2 A buffer width derived from the region
- question: how wide should the buffer be?
- answer: default scale sqrt(2) - 1 gives halo area equal to core area
- evidence: analytic, (1 + s)^2 - 1 = 1
- home: vignettes/theory.Rmd
- also: README opening and Buffer size

### A3 Coastlines
- question: what about buffer area that falls into the sea?
- answer: mask = "land" with area = 1 solves after clipping
- home: vignettes/theory.Rmd (Hard vs Soft Boundaries); quickstart (Using a Mask)
- also: README

### A4 Borders, minimum counts, balanced samples
- answer: aoe_border(), aoe_expand(), aoe_sample()
- home: reference pages
- also: README list

## Non-goals
Theory article, "What AoE is Not".

## Documents
- DESCRIPTION: claim, equal-area default, mask
- README / landing: claim, relation, first call, mask, scale table, routing
- Get Started (quickstart): one path from points to classified points
- articles: theory (explanation)

## Open
- None.
