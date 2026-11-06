# Uses _RING and _beetle_cells from beetle_movement.jl.

# Creates a world with both octant resources computed from healthy trees at
# the given offsets around a damaged brood tree at (100, 25), and `n`
# beetles at (100, 25) + `start` that emerged at `tick_of_emergence`. The
# current tick is 0. Returns the world.
function _setup_beetle_movement_octants_world(
    offsets; n=50, tick_of_emergence=0, start=(0, 0), half_distance=50.0,
)
    world = World(PWNModel.Position, PWNModel.Damaged, PWNModel.BeetlePosition, PWNModel.EmergenceTick)
    add_resource!(world, PWNModel.WorldSize(width=2000, height=500, cell_size=10))
    add_resource!(world, PWNModel.Time(0, 0, 0))
    add_resource!(world, PWNModel.Rng(1))

    if !isempty(offsets)
        new_entities!(world, length(offsets), (PWNModel.Position,)) do (_, positions)
            for (i, (dx, dy)) in enumerate(offsets)
                positions[i] = PWNModel.Position(100 + dx, 25 + dy)
            end
        end
    end
    new_entity!(world, (PWNModel.Position(100, 25), PWNModel.Damaged()))

    for damaged in (false, true)
        s = PWNModel.TreeAttractionOctants(
            tick_of_year=0, damaged_trees=damaged, half_distance=half_distance, density_radius=20,
            density_weight=0.0,
        )
        PWNModel.initialize!(s, world)
        PWNModel.update!(s, world)
    end

    new_entities!(world, n, (PWNModel.BeetlePosition, PWNModel.EmergenceTick)) do (_, positions, ticks)
        for i in eachindex(positions)
            positions[i] = PWNModel.BeetlePosition(100 + start[1], 25 + start[2])
            ticks[i] = PWNModel.EmergenceTick(tick_of_emergence)
        end
    end
    return world
end

function _beetle_movement_octants(; leave_tree_probability=0.25, emergence_flight_distance=0.0)
    return PWNModel.BeetleMovementOctants(;
        steps_per_tick=1, distance_per_step=2000.0, duration_feeding=3, feeding_probability=0.5,
        leave_tree_probability=leave_tree_probability, emergence_flight_distance=emergence_flight_distance,
    )
end

_octant_sources(attraction) = PWNModel.OctantSources(
    ntuple(k -> attraction[k] > 0 ? (Int16(k), Int16(0)) : (Int16(0), Int16(0)), Val(8)),
    ntuple(k -> Float32(attraction[k]), Val(8)),
)

@testset "select_octant without sources draws nothing" begin
    rng = PWNModel.Rng(1)
    @test PWNModel.select_octant(rng, PWNModel.OctantSources()) == 0
    @test rand(rng) == rand(PWNModel.Rng(1))
end

@testset "select_octant never selects empty octants" begin
    rng = PWNModel.Rng(1)
    r = _octant_sources((0, 0, 0.5, 0, 0, 0, 0, 0))
    @test all(PWNModel.select_octant(rng, r) == 3 for _ in 1:100)

    r = _octant_sources((0, 0.1, 0, 0, 0.3, 0, 0, 0.6))
    @test all(PWNModel.select_octant(rng, r) in (2, 5, 8) for _ in 1:1000)
end

@testset "select_octant is proportional to attraction" begin
    rng = PWNModel.Rng(1)
    weights = (0.1, 0.0, 0.2, 0.0, 0.3, 0.0, 0.4, 0.0)
    r = _octant_sources(weights)
    n = 100_000
    counts = zeros(Int, 8)
    for _ in 1:n
        counts[PWNModel.select_octant(rng, r)] += 1
    end
    for k in 1:8
        @test isapprox(counts[k] / n, weights[k]; atol=0.01)
    end
end

@testset "BeetleMovementOctants without emergence flight, spread targets" begin
    # Unlike BeetleMovement, beetles from the same cell do not all fly to the
    # same tree: each of the 8 ring trees is in its own octant.
    world = _setup_beetle_movement_octants_world(_RING)
    s = _beetle_movement_octants()
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    cells = _beetle_cells(world)
    presence = get_resource(world, PWNModel.HealthyTreeAttractionOctants).presence
    @test sum(values(cells)) == 50
    @test length(cells) > 3
    @test all(presence[x, y] for (x, y) in keys(cells))
end

@testset "BeetleMovementOctants targets by attraction" begin
    # Two trees in opposite octants, 15 and 30 cells away. At a half
    # distance of 50 m (5 cells), the nearer one is 2^3 = 8 times as
    # attractive, so it gets 8/9 of the beetles.
    n = 9000
    world = _setup_beetle_movement_octants_world(((15, 0), (-30, 0)); n=n)
    s = _beetle_movement_octants()
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    cells = _beetle_cells(world)
    @test sum(values(cells)) == n
    @test isapprox(get(cells, (115, 25), 0) / n, 8 / 9; atol=0.015)
    @test isapprox(get(cells, (70, 25), 0) / n, 1 / 9; atol=0.015)
end

@testset "BeetleMovementOctants emergence flight only once" begin
    world = _setup_beetle_movement_octants_world(_RING)
    s = _beetle_movement_octants(; leave_tree_probability=0.0, emergence_flight_distance=300.0)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)
    before = _beetle_cells(world)

    get_resource(world, PWNModel.Time).tick = 1
    PWNModel.update!(s, world)

    @test _beetle_cells(world) == before
end

@testset "BeetleMovementOctants emergence flight out of world dies" begin
    world = _setup_beetle_movement_octants_world(_RING)
    s = _beetle_movement_octants(; emergence_flight_distance=2000.0)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    # From (100, 25) in a 200 x 50 cell world, the flight of up to 200 cells
    # leaves the world in most directions and distances.
    cells = _beetle_cells(world)
    presence = get_resource(world, PWNModel.HealthyTreeAttractionOctants).presence
    total = sum(values(cells); init=0)
    @test 0 < total < 50
    @test all(checkbounds(Bool, presence, x, y) for (x, y) in keys(cells))
end

@testset "BeetleMovementOctants leaving a tree flies to another tree" begin
    # Beetles on the ring tree at (115, 25), emerged in an earlier tick (no
    # emergence flight), all leaving: they fly directly to other ring trees,
    # without a walk phase, and none leaves the world.
    world = _setup_beetle_movement_octants_world(_RING; tick_of_emergence=-1, start=(15, 0))
    s = _beetle_movement_octants(; leave_tree_probability=1.0)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    cells = _beetle_cells(world)
    presence = get_resource(world, PWNModel.HealthyTreeAttractionOctants).presence
    @test sum(values(cells)) == 50
    @test !haskey(cells, (115, 25))
    @test all(presence[x, y] for (x, y) in keys(cells))
end

@testset "BeetleMovementOctants staying on a tree" begin
    world = _setup_beetle_movement_octants_world(_RING; tick_of_emergence=-1, start=(15, 0))
    s = _beetle_movement_octants(; leave_tree_probability=0.0)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    @test _beetle_cells(world) == Dict((115, 25) => 50)
    feeding = get_resource(world, PWNModel.FeedingInfectedBeetles).grid
    @test feeding[115, 25] == 50
end

@testset "BeetleMovementOctants without visible trees stays" begin
    # No healthy trees at all; beetles emerged in an earlier tick (no
    # emergence flight) and still feeding (no feeding draw), so they neither
    # move nor draw any random number.
    world = _setup_beetle_movement_octants_world((); tick_of_emergence=-1, start=(30, 10))
    s = _beetle_movement_octants()
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    @test _beetle_cells(world) == Dict((130, 35) => 50)
    @test rand(get_resource(world, PWNModel.Rng)) == rand(PWNModel.Rng(1))
end

@testset "BeetleMovementOctants partial flight" begin
    # A single tree 30 cells away, but only 10 cells of flight per step: the
    # beetles get 10 cells closer per step and reach it in the third step.
    world = _setup_beetle_movement_octants_world(((30, 0),); tick_of_emergence=-1, start=(0, 0))
    s = PWNModel.BeetleMovementOctants(;
        steps_per_tick=1, distance_per_step=100.0, duration_feeding=3, feeding_probability=0.5,
        leave_tree_probability=0.0, emergence_flight_distance=0.0,
    )
    PWNModel.initialize!(s, world)
    for expected in (110, 120, 130)
        PWNModel.update!(s, world)
        @test _beetle_cells(world) == Dict((expected, 25) => 50)
    end
end

@testset "BeetleMovementOctants from config" begin
    cfg = PWNModel.parse_config("""
    systems:
      - type: BeetleMovementOctants
        steps_per_tick: 4
        distance_per_step: 500
        emergence_flight_distance: 200
        duration_feeding: 3
        feeding_probability: 0.5
        leave_tree_probability: 0.2
    """)
    s = cfg.systems[1]
    @test s isa PWNModel.BeetleMovementOctants
    @test s.steps_per_tick == 4
    @test s.distance_per_step === 500.0
    @test s.emergence_flight_distance === 200.0
    @test s.leave_tree_probability == 0.2
end
