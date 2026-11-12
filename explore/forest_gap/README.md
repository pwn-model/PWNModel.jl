# Forest gap

## Question

How likely do beetles carrying nematodes cross a gap between two forests,
during maturation feeding and over their whole life?
How does this depend on the width of the gap?

## Setup

All parameters are set where the systems are created, in [`run.jl`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/forest_gap/run.jl).

- **Landscape**: 3 km × 2 km, 10 m cells, created by `InitTreeStands` with two stands,
  both with `tree_probability` 0.9 and `damage_prevalence` 0.03:
  a west forest from 0 to 1000 m, and an east forest from the end of the gap to the east edge of the world (3000 m).
  Between them is a gap without trees.
- **Attraction**: two `TreeAttraction` systems (healthy and damaged trees), `half_distance` 50 m, `density_radius` 20 m, `density_weight` 1.
- **Beetles**: 10,000 beetles released at tick 0 from a damaged tree placed in the easternmost column of cells of the west forest,
  right at the edge of the gap (or an existing tree there made damaged).
- **Mortality**: `BeetleMortality`, with life span drawn from an exponential distribution with a mean of 5 weeks,
  capped at a maximum age of 18 weeks (as in `BeetleEmergence`).
  The simulation runs for 18 weeks, until all beetles are dead.
- **Movement**: one `BeetleMovement` system with 7 steps per week and up to 2 km per step, 3 weeks of maturation feeding
  (attracted by healthy trees), then each step feeding or egg laying (attracted by damaged trees) with probability 0.5.
  `leave_tree_probability` 0.25, `emergence_flight_distance` 100 m.

To record every single movement step, the model runs with one movement step per tick, and phase durations scaled by 7.
As trees and attraction fields are static here, this gives the same movement behaviour as weekly ticks.

**Crossing**: a beetle has crossed the gap if any of its movement steps ends in the east forest,
on a tree or not.
The crossing probability is the share of all released beetles that crossed the gap
during maturation feeding (the first 3 weeks), resp. at any time during their life.
Beetles that die or leave the world before crossing count as not crossed.

### Scenarios

The experiment runs four scenarios that differ only in the gap width: 100, 250, 500 and 1000 m.
Everything else is the same, including the random seed. Each scenario runs once.

## Running

From the `PWNModel.jl/` directory:

```
julia --project=explore explore/forest_gap/run.jl
```

Figures are written to `out/` as SVG (and PNG). They are not committed, but shown on the web page.

## Figures

### Landscapes

The landscapes of all gap widths (panels).
Green cells are healthy trees, brown cells damaged trees, the star is the release point.

![Landscapes](out/landscapes.svg)

### Crossing probability

Probability to cross the gap during maturation feeding and over the beetles' lifetime, by gap width,
as a figure and as a table.

![Crossing probability](out/crossing_probability.svg)

<!-- include out/crossing_probability.md -->

## Observations

TODO
