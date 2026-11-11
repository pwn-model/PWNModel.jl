# Attraction half distance

## Question

How does `half_distance` of the attraction kernel affect how strongly clusters of trees dominate over scattered trees?
How far do the clusters' catchments reach, and how many scattered trees are never targeted?

## Setup

All parameters are set in [`run.jl`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/attraction_half_distance/run.jl).

- **Landscape**: 2 km × 2 km, 10 m cells.
  Three round, fully stocked clusters with radii of 30 m, 60 m and 120 m,
  and scattered trees in 2.5 % of all other cells, placed at random.
  All trees are healthy.
- **Attraction**: healthy-tree attraction with `density_radius` 20 m and `density_weight` 1.
  `half_distance` is varied: 12.5, 25, 50 (the default), 100 and 200 m.
  Damaged-tree attraction works the same way, so it is not shown separately.
- **Attraction model**: `TreeAttraction` (radial attraction, used by `BeetleMovement`).
  There are no beetles. Only the attraction is calculated, once.

With `density_weight` 1, each tree's attraction starts at its local occupancy:
the fraction of cells with a tree within `density_radius` (here, a square of 5 × 5 cells).
Inside a cluster, this is 1. For a lone scattered tree, it is 1/25.
Attraction halves every `half_distance` meters.
A cluster tree therefore stays more attractive than a lone tree up to `half_distance` × log₂ 25 ≈ 4.6 × `half_distance` farther away:
58 m at 12.5 m, 232 m at 50 m, and 929 m at 200 m.

**Terms used below**
- *Source*: the tree a cell takes its attraction from. Beetles in that cell fly towards it.
- *Catchment*: all cells that have a given tree as their source.
- A scattered tree is *not targeted* if it is the source of no cell other than its own.
  Beetles flying through the landscape are then never drawn towards it.

## Running

From the `PWNModel.jl/` directory:

```
julia --project=explore explore/attraction_half_distance/run.jl
```

Figures are written to `out/` as SVG (and PNG). They are not committed, but shown on the web page.

## Figures

### Catchments

The source of each cell, for each `half_distance` (panels).
Blue cells take their attraction from a cluster tree, orange cells from a scattered tree.
Darker lines are the boundaries between catchments.
The catchment of a whole cluster is shown as one, without the boundaries between its trees.
Black circles are the clusters.
Dots are scattered trees: filled if targeted, hollow if not targeted.

![Radial catchments](out/radial_catchments.svg)

### Summary

Share of the area whose source is a cluster tree,
and share of scattered trees that are not targeted, over `half_distance`.
The dashed line marks the default of 50 m.

![Radial summary](out/radial_summary.svg)

## Observations

- Clusters take over more and more of the landscape as `half_distance` grows.
  The share of the area whose source is a cluster tree grows from 4 % at 12.5 m to 17 % at 50 m and 86 % at 200 m.
- Many scattered trees are never targeted, even outside the clusters' catchments.
  This is because scattered trees also compete with each other:
  a scattered tree with a neighbor within 20 m has twice the occupancy of a lone tree, so it wins up to `half_distance` farther away.
  The share of scattered trees that are not targeted grows from 1 % at 12.5 m to 39 % at 50 m and 96 % at 200 m.
  With large `half_distance`, beetles following radial attraction effectively only fly towards clusters
  and the densest groups of scattered trees.

The same question for the octant attraction model is covered by the archived experiment *Attraction half distance (octants)*.
