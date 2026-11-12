# Forest density

## Question

How far from the release point do beetles carrying nematodes feed on healthy trees and lay eggs on damaged trees,
and how does this depend on forest density?

## Setup

All parameters are set where the systems are created, in [`run.jl`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/forest_density/run.jl).

- **Landscape**: 2 km × 2 km, 10 m cells, created by `InitTrees` with `km2_probability` 1.
  `tree_probability` is varied (see below), `damage_prevalence` is 0.03.
- **Attraction**: two `TreeAttraction` systems (healthy and damaged trees), `half_distance` 50 m, `density_radius` 20 m, `density_weight` 1.
- **Beetles**: 10,000 beetles released in the center of the world at tick 0, from a damaged tree placed there
  (or an existing tree there made damaged).
- **Mortality**: `BeetleMortality`, with life span drawn from an exponential distribution with a mean of 5 weeks,
  capped at a maximum age of 18 weeks (as in `BeetleEmergence`).
  The simulation runs for 18 weeks, until all beetles are dead.
- **Movement**: one `BeetleMovement` system with 7 steps per week and up to 2 km per step, 3 weeks of maturation feeding
  (attracted by healthy trees), then each step feeding or egg laying (attracted by damaged trees) with probability 0.5.
  `leave_tree_probability` 0.25.

The model runs with its normal weekly time step.

**Events**: a feeding event is a movement step that a beetle ends on a healthy tree while looking for healthy trees,
an egg laying event is a step that a beetle ends on a damaged tree while looking for damaged trees.
These are the events that `NematodeInfection` uses.
A beetle that stays on a tree for several steps causes one event per step.
Distances are measured between the centers of the release cell and the tree's cell.

### Scenarios

The experiment runs four scenarios that differ only in `tree_probability`: 0.9, 0.75, 0.5 and 0.25.
Everything else is the same, including the random seed.

## Running

From the `PWNModel.jl/` directory:

```
julia --project=explore explore/forest_density/run.jl
```

Figures are written to `out/` as SVG (and PNG). They are not committed, but shown on the web page.

## Figures

### Event distances

Number of feeding events (left) and egg laying events (right) by distance from the release point,
for all forest densities (rows), summed over the whole simulation. Bins are 50 m wide.
Each panel gives the total number of events and their median distance.
The maps on the left show the trees in a 200 m × 200 m section around the release point (star):
green cells are healthy trees, brown cells damaged trees.

![Event distances](out/event_distances.svg)

## Observations

TODO
