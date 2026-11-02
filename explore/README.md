# Explorations

Scripts that explore the behaviour of parts of the model, one experiment per folder.
Each experiment assembles its world and systems in code and has its own `README.md`
with the question, setup, figures and observations.

Shared helpers are in [`common/`](common/): world and landscape setup, recorder systems, and plotting.
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

## Experiments

- [`beetle_trajectories`](beetle_trajectories/): movement of beetles during maturation feeding and egg laying.
