# Entry point for a standalone executable built with PackageCompiler.jl's
# `create_app` (see build/compile.jl). Mirrors scripts/run.jl's model-driving
# logic, minus its GLMakie-based plotting includes: those live in a separate
# environment (scripts/Project.toml) that a compiled app has no reason to
# pull in.

"""
    run_model(config_path::AbstractString; out_dir::Union{AbstractString,Nothing}=nothing) -> World

Runs the model from the config file at `config_path`: builds a `World` with
the model's fixed component set, wires up the PRNG from `cfg.seed` (the PRNG
implementation itself is fixed, to keep it bit-identical with the sibling Go
implementation), applies the config's resources, and runs its systems to
completion via a `Scheduler`. Returns the `World`, e.g. for inspection after
the run.

If `out_dir` is given, the model runs with `out_dir` (created if missing) as
the working directory, so that all relative paths in the config (e.g. output
files) are resolved against it. `config_path` itself is resolved against the
original working directory, which is restored afterwards.
"""
function run_model(config_path::AbstractString; out_dir::Union{AbstractString,Nothing}=nothing)
    cfg = load_config(config_path)
    out_dir === nothing && return _run_model(cfg)

    mkpath(out_dir)
    return cd(() -> _run_model(cfg), out_dir)
end

function _run_model(cfg::Config)
    world = World(
        Position, GridCoords, Damaged, Infected, Colonized, Relation{InCell},
        BeetlePosition, EmergenceTick, LifeExpectancy,
    )
    add_resource!(world, Rng(cfg.seed))
    apply!(cfg, world)

    scheduler = Scheduler(world, Tuple(cfg.systems); tps=cfg.tps, fps=cfg.fps)
    run!(scheduler)

    return world
end

"""
    julia_main() -> Cint

Runs the model from a config file, whose path is the app's positional
command line argument (defaulting to "config.yaml" in the current directory).
Like the sibling Go executable and scripts/run.jl, it takes an optional
`-o DIR`/`--out-dir DIR`/`--out-dir=DIR` option (see [`run_model`](@ref)'s
`out_dir`).

This is the entry-point signature `PackageCompiler.create_app` looks for
and calls automatically.
"""
function julia_main()::Cint
    config_path, out_dir = _parse_app_args(ARGS)
    run_model(config_path; out_dir=out_dir)
    return 0
end

# A minimal command line parser for julia_main, which keeps the compiled app
# free of an ArgParse dependency.
function _parse_app_args(args::AbstractVector{<:AbstractString})
    config_path = nothing
    out_dir = nothing
    i = 1
    while i <= length(args)
        arg = args[i]
        if arg == "-o" || arg == "--out-dir"
            i < length(args) || error("missing value for option $arg")
            out_dir = args[i+1]
            i += 1
        elseif startswith(arg, "--out-dir=")
            out_dir = arg[(length("--out-dir=")+1):end]
        elseif startswith(arg, "-") && arg != "-"
            error("unknown option $arg")
        elseif config_path === nothing
            config_path = arg
        else
            error("unexpected argument $arg")
        end
        i += 1
    end
    return something(config_path, "config.yaml"), out_dir
end
