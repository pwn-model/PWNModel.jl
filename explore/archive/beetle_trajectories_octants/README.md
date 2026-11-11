# Beetle trajectories (octants)

> **Archived.** The octant attraction model examined here (`TreeAttractionOctants`, `BeetleMovementOctants`)
> was not adopted, and is no longer part of the model.
> The same experiment with radial attraction (`TreeAttraction`, `BeetleMovement`) is covered by the experiment *Beetle trajectories*.

## Question

How do beetles carrying nematodes move through the landscape during maturation feeding and egg laying, with octant attraction?
How far do they get, and how strongly are they drawn towards trees?

## Setup

All parameters are set where the systems are created, in [`run.jl`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/archive/beetle_trajectories_octants/run.jl).

- **Landscape**: 2 km × 2 km, 10 m cells.
- **Attraction**: two `TreeAttractionOctants` systems (healthy and damaged trees), `half_distance` 50 m, `density_radius` 20 m, `density_weight` 1.
  Beetles select the most attractive tree of one of 8 directions (octants), drawn weighted by its attraction.
  The archived code of the octant systems is in [`archive/octants`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/archive/octants).
- **Beetles**: 10,000 beetles released in the center of the world at tick 0, from a damaged tree placed there
  (or an existing tree there made damaged).
- **Mortality**: `BeetleMortality`, with life span drawn from an exponential distribution with a mean of 5 weeks,
  capped at a maximum age of 18 weeks (as in `BeetleEmergence`).
  The simulation runs for 18 weeks, until all beetles are dead.
- **Movement**: one `BeetleMovementOctants` system with 7 steps per week and up to 2 km per step, 3 weeks of maturation feeding
  (attracted by healthy trees), then each step feeding or egg laying (attracted by damaged trees) with probability 0.5.
  `leave_tree_probability` 0.25.

To record every single movement step, the model runs with one movement step per tick, and phase durations scaled by 7.
As trees and attraction fields are static here, this gives the same movement behaviour as weekly ticks.

With octant attraction, a beetle leaving a tree selects among the other trees around it right away,
instead of first flying out of the area attracted by the tree it leaves.

### Scenarios

The experiment runs three scenarios that differ only in the tree landscape.
Everything else is the same, including the random seed.

| Scenario                | `tree_probability`  | `damage_prevalence` |
| ----------------------- | ------------------- | ------------------- |
| Dense forest            | 0.9                 | 0.03                |
| Sparse forest           | 0.025               | 0.25                |
| Half dense, half sparse | 0.9 (W) / 0.025 (E) | 0.03 (W) / 0.25 (E) |

The first two are created by `InitTrees`, the third by `InitTreeStands` with two stands:
dense forest in the west half and sparse forest in the east half.
The release point is in the easternmost column of cells of the dense half, right at the boundary.

## Running

From the `PWNModel.jl/` directory:

```
julia --project=explore explore/archive/beetle_trajectories_octants/run.jl
```

Figures are written to `out/` as SVG (and PNG). They are not committed, but shown on the web page.

## Figures

### Trajectories by phase

Trajectories of the first 100 beetles during maturation feeding (top) and egg laying (bottom), within 500 m of the release point,
for all scenarios (columns).
Green cells are healthy trees, brown cells damaged trees, the star is the release point,
and colored dots are beetle positions at the end of the phase, or where they died during the phase.

![Trajectories by phase](out/trajectories.svg)

### Attraction sources

Most attractive octant source per cell, for healthy trees (top, drawing beetles during maturation feeding)
and damaged trees (bottom, drawing beetles during egg laying), within 500 m of the release point,
for all scenarios (columns).
Each cell has a source tree in each of 8 directions (octants), and beetles select among them with probabilities
proportional to their attraction. The map shows only the most attractive one, i.e. the most likely target.
Cells of one color have the same most likely target.
Colors are random per source tree; neighbouring patches can occasionally get similar colors.
Unlike with radial attraction (`TreeAttraction`), a tree's own cell is never its own source, so tree cells show their most attractive other tree.
The star is the release point.

![Attraction sources](out/attraction_sources.svg)

### Displacement

Distance of the first 100 beetles from the release point over movement steps (gray),
with median and 10–90 % quantile band over all beetles, for all scenarios.
The y axis is limited to the 90 % quantile, so a few far-flying beetles are cut off.

![Displacement](out/displacement.svg)

### Distance distribution

Distribution of distances from the release point after 2, 4, 8, 12 and 16 weeks (rows),
over the beetles alive at that time, for all scenarios (columns). Bins are 50 m wide.
Each panel gives the number of beetles alive and their median distance.

![Distance distribution](out/distance_distribution.svg)

### Individual trajectories

Trajectories of the first 20 beetles, one panel each, colored by phase (blue: maturation feeding, orange: egg laying).
A cross marks where a beetle died, and the panel title gives the week of death.

#### Dense forest

![Individual trajectories, dense forest](out/trajectories_individual_dense.svg)

#### Sparse forest

![Individual trajectories, sparse forest](out/trajectories_individual_sparse.svg)

#### Half dense, half sparse

![Individual trajectories, half dense, half sparse](out/trajectories_individual_mixed.svg)

## Observations

TODO
