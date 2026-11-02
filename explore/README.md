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
Experiments are listed explicitly in `make.jl` and in the workflow `experiments.yml`: add new ones to both.

## Experiments

- [`beetle_trajectories`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/beetle_trajectories): movement of beetles during maturation feeding and egg laying.
- [`attraction_field`](https://github.com/pwn-model/PWNModel.jl/blob/main/explore/attraction_field): cross-sections of the attraction field around a single tree and a small forest.
