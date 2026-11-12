# Forest gap

## Question

How likely do beetles carrying nematodes cross a gap between two forests,
during maturation feeding and over their whole life?
Which share of their feeding and egg laying happens on the other side of the gap?
How does this depend on the width of the gap?

## Setup

All parameters are set where the systems are created, in [`run.jl`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/forest_gap/run.jl).

- **Landscape**: 2 km high, 10 m cells, created by `InitTreeStands` with two stands,
  both 1000 m wide and with `tree_probability` 0.9 and `damage_prevalence` 0.03:
  a west forest from 0 to 1000 m, and an east forest from the end of the gap to the east edge of the world.
  Between them is a gap without trees.
  The world's width adapts to the gap: 1000 m + gap + 1000 m, from 2.1 km to 12 km.
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
As trees and attraction fields are static here, this gives the same movement behaviour as weekly ticks;
only the order of random numbers differs.

**Crossing**: a beetle has crossed the gap if any of its movement steps ends in the east forest,
on a tree or not.
The crossing probability is the share of all released beetles (of all runs) that crossed the gap
during maturation feeding (the first 3 weeks), resp. at any time during their life.
Beetles that die or leave the world before crossing count as not crossed.

**Events**: a feeding or egg laying event is a movement step that ends on a tree of the type the beetle targets
(as counted by `BeetleMovement` in the `FeedingInfectedBeetles` grid, so a beetle staying on a tree counts once per step).
Events on damaged trees are egg laying, all others feeding.
The event share is the share of events (of all runs) that are in the east forest,
for feeding events during maturation feeding, resp. for egg laying events over the beetles' lifetime.

### Scenarios

The experiment runs seven scenarios that differ only in the gap width: 100, 250, 500, 1000, 2500, 5000 and 10000 m.
Everything else is the same.

Each scenario runs 10 times, with random seeds 1 to 10, so with 10 different landscapes and 100,000 beetles in total.
The results are pooled over these runs. The seeds are the same for all scenarios.

## Running

From the `PWNModel.jl/` directory:

```
julia --project=explore explore/forest_gap/run.jl
```

Figures are written to `out/` as SVG (and PNG), and the table as Markdown.
They are not committed, but shown on the web page.

## Figures

### Landscapes

The landscapes of all gap widths (rows) in the first run, on the same scale.
Green cells are healthy trees, brown cells damaged trees, the star is the release point.
Gray is outside the world, as smaller gaps give narrower worlds.

![Landscapes](out/landscapes.svg)

### Crossing probability and events

Crossing probabilities and event shares by gap width, as a figure and as a table
(see [Setup](#setup) for definitions). Solid lines are per-beetle probabilities, dashed lines per-event shares:

- **Probability immature**: probability that a beetle crosses the gap during maturation feeding (the first 3 weeks).
- **Probability lifetime**: probability that a beetle crosses the gap at any time during its life.
- **Feeding events**: share of maturation feeding events that are on the other side of the gap, in the east forest.
- **Egg-laying events**: share of egg laying events, over the beetles' whole life, that are on the other side of the gap.

Both axes of the figure are logarithmic.

![Crossing probability](out/crossing_probability.svg)

<!-- include out/crossing_probability.md -->

## Observations

TODO
