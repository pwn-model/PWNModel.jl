module _ConfigTestExternal

import PWNModel: System

Base.@kwdef struct XyTermination <: System
    steps::Int
end

end # module

@testset "Config: resolves systems by name and constructs them from params" begin
    cfg = PWNModel.parse_config("""
    systems:
      - type: InitGrids
      - type: InitTrees
        cell_probability: 0.6
        tree_probability: 0.9
        damage_prevalence: 0.03
        beetle_prevalence: 0.2
    """)

    @test length(cfg.systems) == 2
    @test cfg.systems[1] isa PWNModel.InitGrids

    init_trees = cfg.systems[2]
    @test init_trees isa PWNModel.InitTrees
    @test init_trees.cell_probability == 0.6
    @test init_trees.tree_probability == 0.9
    @test init_trees.damage_prevalence == 0.03
    @test init_trees.beetle_prevalence == 0.2
end

@testset "Config: unknown system type raises an error" begin
    @test_throws ArgumentError PWNModel.parse_config("""
    systems:
      - type: NoSuchSystem
    """)
end

@testset "Config: missing type field raises an error" begin
    @test_throws ArgumentError PWNModel.parse_config("""
    systems:
      - steps: 10
    """)
end

@testset "Config: an unknown top-level key raises an error" begin
    err = try
        PWNModel.parse_config("""
        seeed: 1
        """)
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    @test occursin("\"seeed\"", err.msg)
end

@testset "Config: an unknown entry parameter raises an error naming it" begin
    # Misspelled (optional or required) parameters, as well as parameters to
    # a type that takes none, at the top level of an entry and nested inside
    # one.
    for (src, key) in [
        """
        systems:
          - type: InitTrees
            cell_probability: 0.6
            tree_probability: 0.9
            damage_prevalence: 0.03
            beetle_prevalence: 0.2
            cell_probabilty: 0.6
        """ => "cell_probabilty",
        """
        systems:
          - type: InitGrids
            bogus: 1
        """ => "bogus",
        """
        resources:
          - type: WorldSize
            widht: 4000
            height: 3000
            cell_size: 10
            grid_cell_size: 500
        """ => "widht",
        """
        systems:
          - type: CSV
            observer:
              type: TreePopulationObserver
              bogus: 1
            file: out/tree_pop.csv
        """ => "bogus",
    ]
        err = try
            PWNModel.parse_config(src)
            nothing
        catch e
            e
        end
        @test err isa ArgumentError
        @test occursin("\"$key\"", err.msg)
    end
end

@testset "Config: resources are resolved and applied to a world" begin
    cfg = PWNModel.parse_config("""
    resources:
      - type: WorldSize
        width: 4000
        height: 3000
        cell_size: 10
        grid_cell_size: 500
    """)
    @test length(cfg.resources) == 1

    world = World()
    PWNModel.apply!(cfg, world)

    ws = get_resource(world, PWNModel.WorldSize)
    @test ws.width == 400
    @test ws.height == 300
    @test ws.cell_size == 10
    @test ws.resolution == 50
end

@testset "Config: a type that is merely `using`'d, not defined, is not resolvable" begin
    # PWNModel itself does `using Ark`, so `World` is a visible name inside
    # it, but PWNModel doesn't define it -- this must stay unreachable from
    # config files, or any config could reach into a dependency's types.
    @test_throws ArgumentError PWNModel.resolve_type("World", Any)
end

@testset "Config: external modules are only usable after allow_external_module" begin
    @test_throws ArgumentError PWNModel.resolve_type("_ConfigTestExternal.XyTermination", PWNModel.System)

    PWNModel.allow_external_module(_ConfigTestExternal)

    T = PWNModel.resolve_type("_ConfigTestExternal.XyTermination", PWNModel.System)
    @test T === _ConfigTestExternal.XyTermination

    cfg = PWNModel.parse_config("""
    systems:
      - type: _ConfigTestExternal.XyTermination
        steps: 42
    """)
    @test cfg.systems[1] isa _ConfigTestExternal.XyTermination
    @test cfg.systems[1].steps == 42
end

@testset "Config: an unknown module prefix raises an error" begin
    @test_throws ArgumentError PWNModel.resolve_type("NoSuchModule.SomeType", Any)
end

@testset "Config: Main is allowed by default, unlike other external modules" begin
    # Unlike a genuine third-party dependency, Main is the running script's
    # own top-level namespace (e.g. where scripts/run.jl's plotting types
    # end up), so it needs no allow_external_module call.
    Base.eval(Main, :(struct _ConfigTestMainType <: $(PWNModel.System) end))
    T = PWNModel.resolve_type("Main._ConfigTestMainType", PWNModel.System)
    @test T === Main._ConfigTestMainType
end

@testset "Config: a nested `type:` value (e.g. a reporter's observer) is resolved recursively" begin
    cfg = PWNModel.parse_config("""
    systems:
      - type: CSV
        observer:
          type: TreePopulationObserver
        file: out/tree_pop.csv
        sep: ";"
    """)

    @test length(cfg.systems) == 1
    csv = cfg.systems[1]
    @test csv isa PWNModel.CSV
    @test csv.observer isa PWNModel.TreePopulationObserver
    @test csv.file == "out/tree_pop.csv"
    @test csv.sep == ";"
end

@testset "Config: a nested value resolved to the wrong kind fails at construction" begin
    # TreeColonizationMapObserver is a MatrixObserver, but CSV's `observer`
    # keyword is typed RowObserver: Julia's own keyword-argument type
    # checking is what rejects the mismatch here (raising a TypeError),
    # since the config mechanism itself resolves nested values
    # unconstrained (see `_resolve_value`).
    @test_throws TypeError PWNModel.parse_config("""
    systems:
      - type: CSV
        observer:
          type: TreeColonizationMapObserver
          cell_size: 100
        file: out/tree_pop.csv
    """)
end

@testset "Config: end-to-end from an inline config" begin
    # Deliberately inline, not the repo's own scripts/config.yaml: that one
    # also references the GLMakie-based plotting types from
    # scripts/plot/*.jl (as "Main.TimeSeries" etc.), which aren't loaded
    # (and, being GLMakie-dependent, can't be loaded) in this package's own
    # test environment -- see allow_external_module's docstring. That part
    # is instead verified by hand, by running scripts/run.jl's config
    # loading in the scripts/ environment.
    cfg = PWNModel.parse_config("""
    seed: 1
    tps: 30
    fps: 20
    resources:
      - type: WorldSize
        width: 4000
        height: 3000
        cell_size: 10
        grid_cell_size: 500
    systems:
      - type: InitGrids
      - type: FixedTermination
        steps: 10
    """)
    @test cfg.seed == 1
    @test cfg.tps == 30.0
    @test cfg.fps == 20.0
    @test !isempty(cfg.systems)

    world = World(Position, GridCoords, Damaged, Infected, Colonized, Relation{InCell})
    PWNModel.apply!(cfg, world)
    add_resource!(world, PWNModel.Rng(cfg.seed))

    ws = get_resource(world, PWNModel.WorldSize)
    @test ws.width == 400

    @test cfg.systems[end] isa PWNModel.FixedTermination
    steps = cfg.systems[end].steps

    # Intentionally not passing tps=cfg.tps here: that throttles run! to
    # real time, which would make this test take minutes; correctness
    # doesn't depend on pacing.
    scheduler = Scheduler(world, Tuple(cfg.systems))
    run!(scheduler)

    @test get_resource(scheduler.world, PWNModel.Tick).value == steps
end
