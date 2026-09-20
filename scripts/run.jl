using Ark
using PWNModel

include("plot/image.jl")
include("plot/time_series.jl")
include("plot/trees_map.jl")

config_path = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "config.yaml")

world = run_model(config_path)

#println(trees_to_string(world))
