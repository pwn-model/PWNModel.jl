# Entry point for a standalone executable built with PackageCompiler.jl's
# `create_app` (see build/compile.jl). Mirrors scripts/run.jl's model-driving
# logic, minus its GLMakie-based plotting includes: those live in a separate
# environment (scripts/Project.toml) that a compiled app has no reason to
# pull in.

"""
    run_model(config_path::AbstractString) -> World

Runs the model from the config file at `config_path`: builds a `World` with
the model's fixed component set, wires up the PRNG from `cfg.seed` (the PRNG
implementation itself is fixed, to keep it bit-identical with the sibling Go
implementation), applies the config's resources, and runs its systems to
completion via a `Scheduler`. Returns the `World`, e.g. for inspection after
the run.
"""
function run_model(config_path::AbstractString)
    cfg = load_config(config_path)

    world = World(Position, GridCoords, Damaged, Infected, Colonized, Relation{InCell})
    add_resource!(world, Rng(cfg.seed))
    apply!(cfg, world)

    scheduler = Scheduler(world, Tuple(cfg.systems); fps=cfg.tps)
    run!(scheduler)

    return world
end

"""
    julia_main() -> Cint

Runs the model from a config file, whose path is the app's first command
line argument (defaulting to "config.yaml" in the current directory).

This is the entry-point signature `PackageCompiler.create_app` looks for
and calls automatically.
"""
function julia_main()::Cint
    config_path = length(ARGS) >= 1 ? ARGS[1] : "config.yaml"
    run_model(config_path)
    return 0
end
