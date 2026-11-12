# Forest density

## Question

How far from the release point do beetles carrying nematodes feed on healthy trees and lay eggs on damaged trees,
how far do the beetles get in each phase of their life, and how does this depend on forest density?

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

The model time step is one week, but the experiment runs one movement step per tick (i.e. daily ticks),
with all durations scaled accordingly, to record the position of every beetle after every step.
Trees and attraction fields are static here, so this gives the same movement as weekly ticks.
Only the order of random numbers differs, and beetles die on the day their life span ends instead of at the end of the week.

**Events**: a feeding event is a movement step that a beetle ends on a healthy tree while looking for healthy trees,
an egg laying event is a step that a beetle ends on a damaged tree while looking for damaged trees.
These are the events that `NematodeInfection` uses.
Feeding events happen in both phases: during maturation feeding (the first 3 weeks), and afterwards in the steps
in which a beetle feeds instead of laying eggs. Feeding events therefore reach further from the release point
than the maximum distances of the maturation feeding phase.
A beetle that stays on a tree for several steps causes one event per step.
Distances are measured between the centers of the release cell and the tree's cell.

**Maximum distances**: for each beetle, the largest distance from the release point that it reaches after any movement step,
separately in the maturation feeding phase (the first 3 weeks) and in the egg laying phase (after that,
with feeding and egg laying alternating, see above).
Only beetles that live long enough to reach the egg laying phase count for it.
Distances are measured between the centers of the release cell and the beetle's cell.
Beetles that leave the world (about 1 km from the release point) die. They count as "beyond edge" in the phase they leave in.

### Scenarios

The experiment runs four scenarios that differ only in `tree_probability`: 0.9, 0.75, 0.5 and 0.25.
Everything else is the same.

Each scenario runs 10 times, with random seeds 1 to 10, so with 10 different landscapes.
The results are aggregated over these runs, as the distances to the nearest damaged trees
vary a lot between landscapes.
The seeds are the same for all scenarios.

## Running

From the `PWNModel.jl/` directory:

```
julia --project=explore explore/forest_density/run.jl
```

Figures are written to `out/` as SVG (and PNG), and the tables as Markdown.
They are not committed, but shown on the web page.

## Figures

### Event distances

Number of feeding events (left) and egg laying events (right) by distance from the release point,
for all forest densities (rows), summed over the whole simulation and averaged over the 10 runs. Bins are 50 m wide.
Each panel gives the mean total number of events per run, and the median and 95 % quantile of the distances
over the events of all runs, each with its range over the single runs.
The dashed line is the 95 % quantile over all runs.
The maps on the left show the trees of the first run in a 200 m × 200 m section around the release point (star):
green cells are healthy trees, brown cells damaged trees.

![Event distances](out/event_distances.svg)

### Event distance quantiles

Median, 95 % and 99 % quantiles of the distances of feeding and egg laying events from the release point,
for all forest densities (rows), over the events of all runs.

<!-- include out/event_distances.md -->

### Maximum distances

Number of beetles by their maximum distance from the release point in the maturation feeding phase (left)
and in the egg laying phase (right), for all forest densities (rows), averaged over the 10 runs. Bins are 50 m wide.
Each panel gives the mean number of beetles per run that reach the phase, the share of them that leave the world
in the phase (if any), and the median and 95 % quantile of the maximum distances over the beetles of all runs,
each with its range over the single runs.
The dashed line is the 95 % quantile over all runs.
The maps on the left are the same as above.

![Maximum distances](out/max_distances.svg)

### Maximum distance quantiles

Median, 95 % and 99 % quantiles of the maximum distances of beetles from the release point per phase,
for all forest densities (rows), over the beetles of all runs.

<!-- include out/max_distances.md -->

## Observations

TODO
