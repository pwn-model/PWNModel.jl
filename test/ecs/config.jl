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
        tree_probability: 0.9
        damage_prevalence: 0.03
        beetle_prevalence: 0.2
    """)

    @test length(cfg.systems) == 2
    @test cfg.systems[1] isa PWNModel.InitGrids

    init_trees = cfg.systems[2]
    @test init_trees isa PWNModel.InitTrees
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

@testset "Config: end-to-end from the shipped scripts/config.yaml" begin
    cfg = PWNModel.load_config(joinpath(@__DIR__, "..", "..", "scripts", "config.yaml"))
    @test cfg.seed == 1
    @test cfg.tps == 30.0
    @test !isempty(cfg.systems)

    world = World(Position, GridCoords, Damaged, Infected, Colonized, Relation{InCell})
    PWNModel.apply!(cfg, world)
    add_resource!(world, PWNModel.Rng(cfg.seed))

    ws = get_resource(world, PWNModel.WorldSize)
    @test ws.width == 400

    @test cfg.systems[end] isa PWNModel.FixedTermination
    steps = cfg.systems[end].steps

    # Intentionally not passing fps=cfg.tps here: that throttles run! to
    # real time, which would make this test take minutes; correctness
    # doesn't depend on pacing.
    scheduler = Scheduler(world, Tuple(cfg.systems))
    run!(scheduler)

    @test get_resource(scheduler.world, PWNModel.Tick).value == steps
end
