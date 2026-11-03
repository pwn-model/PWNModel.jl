# Beetle trajectories

## Question

How do beetles carrying nematodes move through the landscape during maturation feeding and egg laying?
How far do they get, and how strongly are they drawn towards trees?

## Setup

All parameters are set where the systems are created, in [`run.jl`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/beetle_trajectories/run.jl).

- **Landscape**: 1 km × 1 km, 10 m cells.
- **Attraction**: two `TreeAttraction` fields (healthy and damaged trees), `half_distance` 50 m, `density_radius` 20 m, `density_weight` 1.
- **Beetles**: 100 beetles released in the center of the world at tick 0, from a damaged tree placed there
  (or an existing tree there made damaged).
- **Mortality**: `BeetleMortality`, with life expectancy drawn from an exponential distribution with a mean of 5 weeks
  (as in `BeetleEmergence`).
- **Movement**: `BeetleMovementByField` with 7 steps per week, 3 weeks of maturation feeding (attracted by healthy trees),
  then 8 weeks of egg laying (attracted by damaged trees). `leave_tree_probability` 0.25, `random_walk_probability` 0.6.

To record every single movement step, the model runs with one movement step per tick, and phase durations scaled by 7.
As trees and attraction fields are static here, this gives the same movement behaviour as weekly ticks.

### Scenarios

The experiment runs two scenarios that differ only in the tree landscape, created by `InitTrees`.
Everything else is the same, including the random seed.

| Scenario      | `tree_probability` | `damage_prevalence` |
| ------------- | ------------------ | ------------------- |
| Dense forest  | 0.9                | 0.03                |
| Sparse forest | 0.025              | 0.25                |

## Running

From the `PWNModel.jl/` directory:

```
julia --project=explore explore/beetle_trajectories/run.jl
```

Figures are written to `out/` as SVG (and PNG). They are not committed, but shown on the web page.

## Figures

### Trajectories by phase

Trajectories during maturation feeding (left) and egg laying (right), within 200 m of the release point,
for both scenarios (rows).
Green cells are healthy trees, brown cells damaged trees, the star is the release point,
and colored dots are beetle positions at the end of the phase.

![Trajectories by phase](out/trajectories.svg)

### Displacement

Distance of each beetle from the release point over movement steps (gray), with median and 10–90 % quantile band,
for both scenarios.

![Displacement](out/displacement.svg)

### Individual trajectories

Trajectories of the first 20 beetles, one panel each, colored by phase (blue: maturation feeding, orange: egg laying).
A cross marks where a beetle died, and the panel title gives the week of death.

#### Dense forest

![Individual trajectories, dense forest](out/trajectories_individual_dense.svg)

#### Sparse forest

![Individual trajectories, sparse forest](out/trajectories_individual_sparse.svg)

## Observations

TODO
