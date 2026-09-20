using Ark
using PWNModel

include("plot/image.jl")
include("plot/time_series.jl")
include("plot/trees_map.jl")

config_path = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "config.yaml")
cfg = load_config(config_path)

world = World(Position, GridCoords, Damaged, Infected, Colonized, Relation{InCell})

add_resource!(world, Rng(cfg.seed))
apply!(cfg, world)

scheduler = Scheduler(world, Tuple(cfg.systems); fps=cfg.tps)

run!(scheduler)

#println(trees_to_string(world))
