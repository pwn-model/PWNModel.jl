using ArgParse
using Ark
using PWNModel
using GLMakie

include("plot/window.jl")
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
config_path = parsed_config === nothing ? "config.yaml" : parsed_config

# Outside the REPL (`julia run.jl`), Julia by default handles Ctrl+C by exiting
# the process directly instead of throwing an `InterruptException`, which does
# not work while plot windows are open. Throw it here, like in the REPL.
Base.exit_on_sigint(false)

# Some terminals (e.g. VS Code's integrated PowerShell on Windows) start
# programs with the console in a mode where Ctrl+C arrives as a plain input
# character instead of as a signal, so Julia never sees it. The REPL resets
# the mode anyway, but a script has to do it itself.
if stdin isa Base.TTY
    ccall(:jl_tty_set_mode, Int32, (Ptr{Cvoid}, Int32), stdin.handle, 0)
end

# Ctrl+C aborts the run without reaching the plot systems' windows, so close
# them explicitly.
world = try
    run_model(config_path)
catch e
    GLMakie.closeall()
    e isa InterruptException || rethrow()
    @info "Simulation interrupted"
    nothing
end

#println(trees_to_string(world))
