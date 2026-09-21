using ArgParse
using Ark
using PWNModel

include("plot/image.jl")
include("plot/time_series.jl")
include("plot/trees_map.jl")

function parse_commandline()
    s = ArgParseSettings(description="Runs the Pine Wilt Nematode model.")

    #! format: off
    @add_arg_table! s begin
        "config"
            help = "Path to the model config file. Default: config.yaml"
            arg_type = String
    end
    #! format: on

    return parse_args(s)
end

parsed_config = parse_commandline()["config"]
config_path = parsed_config === nothing ? joinpath(@__DIR__, "config.yaml") : parsed_config

world = run_model(config_path)

#println(trees_to_string(world))
