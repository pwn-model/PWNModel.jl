# Attraction field

## Question

What does the attraction field of `TreeAttraction` look like around a single tree and around a small forest?
Where do their fields meet, and how does this depend on `density_weight`?

## Setup

All parameters are set in [`run.jl`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/attraction_field/run.jl).

- **Landscape**: 1000 m × 400 m, 10 m cells.
  A single tree at x = 295 m, and a round, fully stocked forest with a radius of 60 m, centered at x = 695 m.
  Both are centered on the transect at y = 195 m.
- **Attraction**: `TreeAttraction` for healthy trees, `half_distance` 50 m, `density_radius` 20 m.
  `density_weight` is varied: 0, 1 and 2.

For each `density_weight`, the field is calculated three times: for the single tree and the forest together,
and for each of them alone. As the field is the maximum over all sources, the combined field is the maximum
of the two separate ones, and the fields meet where these are equal.

## Running

From the `PWNModel.jl/` directory:

```
julia --project=explore explore/attraction_field/run.jl
```

Figures are written to `out/` as SVG (and PNG). They are not committed, but shown on the web page.

## Figures

### Cross-sections

Attraction along the transect (log scale), for the tree and the forest together (black)
and for each of them alone (dashed). The orange line marks where the fields meet.
Green areas are trees.

![Cross-sections](out/cross_sections.svg)

### Maps

The attraction field (natural log, same coloring as the attraction view of the default `config.yaml`)
with the trees (light green) and the transect (dashed).
The orange line is where the fields of the tree and the forest meet.

![Field maps](out/field_maps.svg)

## Observations

- With `density_weight` 0, all trees seed the field with the same value,
  and the fields meet halfway between the tree and the forest edge.
- With `density_weight` 1, the single tree's seed is lower than the forest's, by its local occupancy (1 of 25 cells).
  The forest's field takes over 70 m from the tree.
- With `density_weight` 2, the forest's field is higher than the tree's even at the tree itself.
  Beetles following the field gradient pass the tree without stopping there.
