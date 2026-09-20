using Ark
using PWNModel

include("plot/image.jl")
include("plot/time_series.jl")
include("plot/trees_map.jl")

config_path = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "config.yaml")
cfg = load_config(config_path)

world = World(Position, GridCoords, Damaged, Infected, Colonized, Relation{InCell})

# Resources, as configured.
apply!(cfg, world)

# The PRNG is hard-coded to Julia's default Xoshiro256++, to stay
# bit-identical with the sibling Go implementation; only its seed is
# configurable.
add_resource!(world, Rng(cfg.seed))

tree_pop_plot = TimeSeries(
    observer=TreeColonizationObserver(),
    title="Tree colonization",
    xlabel="Tick",
    ylabel="Proportion",
)
colo_map_plot = Image(
    observer=TreeColonizationMapObserver(cell_size=100),
    colorrange=(0.0, 5.0),
)
tree_map_plot = TreesMap(title="Trees")

scheduler = Scheduler(
    world,
    (
        # Systems, as configured.
        cfg.systems...,

        # Observers
        CSV(
            observer=TreePopulationObserver(),
            file="out/tree_pop.csv",
        ),
        tree_pop_plot,
        tree_map_plot,
        colo_map_plot,
    );
    fps=cfg.tps,
)

run!(scheduler)

wait(screen(tree_pop_plot))
wait(screen(tree_map_plot))

#println(trees_to_string(world))
