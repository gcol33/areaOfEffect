# The Area of Effect Concept

## The Problem: Border Truncation

When analyzing spatial data within political or administrative
boundaries, a fundamental assumption is often violated: that the
sampling region represents the ecological extent of the processes being
studied.

Consider sampling species occurrences within a country. Observations
near the border are influenced by conditions *outside* that country. A
forest that spans the border, a river that crosses it, or simply the
continuous nature of climate and habitat means that truncating at the
border introduces systematic bias.

This is **border truncation**: the artificial constraint of ecological
processes to administrative boundaries.

## What AoE Is Not

Before explaining what AoE does, it’s important to clarify what it is
*not*: - **Not a buffer**: Buffers add a fixed distance. AoE scales
proportionally from a reference point. - **Not a distance-based
operation**: There is no distance threshold or decay function. - **Not a
tunable parameter**: Scale is fixed at 1. This is a method, not a knob.

## The Area of Effect

The **area of effect** (AoE) is the spatial extent over which
observations within a support are influenced by external conditions. It
is computed by scaling the support geometry outward from a reference
point (typically the centroid).

With scale fixed at 1, the transformation is:

``` math
p' = r + 2(p - r)
```

where: - $`r`$ is the reference point (centroid) - $`p`$ is each vertex
of the support boundary - $`p'`$ is the transformed vertex

This doubles the distance from the reference point to each boundary
vertex, effectively expanding the support to twice its spatial extent
while preserving shape and orientation.

## Core and Halo Classification

Points within the AoE are classified into two categories:

1.  **Core**: Points inside the original support. These are fully
    contained within the sampling region and represent “pure”
    observations unaffected by border effects.

2.  **Halo**: Points outside the original support but inside the
    expanded AoE. These observations are influenced by conditions in the
    border zone and may require different treatment in analysis.

Points outside the AoE are **pruned** (removed). They are too distant to
be meaningfully related to the support region.

    #> Linking to GEOS 3.13.1, GDAL 3.11.4, PROJ 9.7.0; sf_use_s2() is TRUE

![Point classification by AoE. Core points (green) are inside the
original support. Halo points (orange) are in the expanded region.
Points outside the AoE are
pruned.](theory_files/figure-html/classification-1.png)

Point classification by AoE. Core points (green) are inside the original
support. Halo points (orange) are in the expanded region. Points outside
the AoE are pruned.

## Why Scale = 1?

The scale is fixed at 1 for several reasons:

1.  **Reproducibility**: Every analysis uses the same definition. “We
    applied the AoE correction” is unambiguous.

2.  **Comparability**: Results across studies, regions, and time periods
    are directly comparable.

3.  **Interpretability**: Scale = 1 means “one full stamp” - the support
    is extended by its own characteristic scale.

4.  **Methodological consistency**: Good correction methods
    (rarefaction, bias correction) don’t expose free parameters unless
    absolutely necessary.

If you need to explore different scales for sensitivity analysis, that
belongs in separate code, not in the core AoE definition.

## Hard vs Soft Boundaries

AoE distinguishes between two types of boundaries:

**Political borders (soft)**: Administrative lines have no ecological
meaning. The AoE freely crosses them. A country border does not stop
species from dispersing or climate from varying.

**Sea boundaries (hard)**: Physical barriers like coastlines are true
boundaries. The optional `mask` argument enforces these constraints by
intersecting the AoE with a land polygon.

![Hard boundaries constrain the AoE. The dashed line shows the
theoretical AoE; the solid gray area shows the AoE after applying a land
mask.](theory_files/figure-html/mask-concept-1.png)

Hard boundaries constrain the AoE. The dashed line shows the theoretical
AoE; the solid gray area shows the AoE after applying a land mask.

## Multiple Supports

Real-world analyses often involve multiple administrative regions
(countries, provinces, protected areas). AoE handles these naturally:

- Each support is processed independently
- Each uses its own centroid as reference
- Points can fall within multiple AoEs (when regions are adjacent)
- Output is in long format: one row per point-support combination

This enables cross-border analyses and studies of nested administrative
structures without repeated preprocessing.

## Summary

The area of effect provides a principled correction for border
truncation in spatial analysis:

- **Fixed definition**: Scale = 1, no tuning
- **Categorical output**: Core, halo, or pruned
- **Soft/hard boundaries**: Political borders ignored, physical barriers
  respected
- **Multiple supports**: Process many regions at once

The result is a reproducible, interpretable method that can be
consistently applied across studies.
