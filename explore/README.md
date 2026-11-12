# Explorations

Scripts that explore the behaviour of parts of the model, one experiment per folder.
Each experiment assembles its world and systems in code and has its own `README.md`
with the question, setup, figures and observations.

Shared helpers are in [`common/`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/common): world and landscape setup, recorder systems, and plotting.
Some of them may move into the `PWNModel` package later.

## Setup

All experiments share one environment. From the `PWNModel.jl/` directory:

```
julia --project=explore -e 'using Pkg; Pkg.instantiate()'
```

Then run an experiment like this:

```
julia --project=explore explore/<experiment>/run.jl
```

Figures go to `<experiment>/out/` (not committed), as SVG via CairoMakie.

To build the web page from the READMEs and figures, run the experiments first, then:

```
julia --project=explore explore/make.jl
```

The page is written to `explore/site/`. CI publishes it to GitHub Pages on `main`.
Its landing page is [`index.md`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/index.md), written for domain experts. This README is for developers and is not part of the web page.
Experiments are listed explicitly in `make.jl` and in the workflow `experiments.yml`: add new ones to both.

## Experiments

- [`attraction_field`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/attraction_field): cross-sections of the attraction field around a single tree and a small forest.
- [`beetle_trajectories`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/beetle_trajectories): movement of beetles during maturation feeding and egg laying.
- [`forest_density`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/forest_density): how far from the release point beetles feed and lay eggs, for different forest densities.
- [`attraction_half_distance`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/attraction_half_distance): how `half_distance` affects the dominance of tree clusters.

## Archive

Experiments on approaches that were not adopted are kept in [`archive/`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/archive),
together with the model code they need, which is no longer part of the `PWNModel` package.
They are still run and shown on the web page, in a separate *Archive* section.
To archive an experiment, move it to `archive/` (adjusting relative paths), move code it needs that is removed from the package to `archive/` as well,
and list it under `ARCHIVE` in `make.jl` and in the archived experiments step of `experiments.yml`.
If an archived experiment breaks due to changes in the package and is not worth fixing, remove it from both lists.

- [`archive/octants`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/archive/octants): code of the octant attraction model (`TreeAttractionOctants`, `BeetleMovementOctants`), not an experiment.
- [`archive/attraction_half_distance_octants`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/archive/attraction_half_distance_octants): how `half_distance` affects octant selection and the dominance of tree clusters, with octant attraction.
- [`archive/beetle_trajectories_octants`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/archive/beetle_trajectories_octants): movement of beetles during maturation feeding and egg laying, with octant attraction.
