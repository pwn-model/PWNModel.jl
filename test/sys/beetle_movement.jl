# Creates a world with both attraction fields computed from healthy trees at
# the given offsets around a damaged brood tree at (100, 25), and `n` beetles
# at the brood tree that emerged at `tick_of_emergence`. The current tick is
# 0. Returns the world.
function _setup_beetle_movement_world(offsets; n=50, tick_of_emergence=0)
    world = World(PWNModel.Position, PWNModel.Damaged, PWNModel.BeetlePosition, PWNModel.EmergenceTick)
    add_resource!(world, PWNModel.WorldSize(width=2000, height=500, cell_size=10))
    add_resource!(world, PWNModel.Time(0, 0, 0))
    add_resource!(world, PWNModel.Rng(1))

    new_entities!(world, length(offsets), (PWNModel.Position,)) do (_, positions)
        for (i, (dx, dy)) in enumerate(offsets)
            positions[i] = PWNModel.Position(100 + dx, 25 + dy)
        end
    end
    new_entity!(world, (PWNModel.Position(100, 25), PWNModel.Damaged()))

    for damaged in (false, true)
        s = PWNModel.TreeAttraction(
            tick_of_year=0, damaged_trees=damaged, half_distance=50.0, density_radius=20, density_weight=0.0,
        )
        PWNModel.initialize!(s, world)
        PWNModel.update!(s, world)
    end

    new_entities!(world, n, (PWNModel.BeetlePosition, PWNModel.EmergenceTick)) do (_, positions, ticks)
        for i in eachindex(positions)
            positions[i] = PWNModel.BeetlePosition(100, 25)
            ticks[i] = PWNModel.EmergenceTick(tick_of_emergence)
        end
    end
    return world
end

const _RING = ((-15, 0), (15, 0), (0, -15), (0, 15), (-12, -12), (12, 12), (-12, 12), (12, -12))

function _beetle_movement(; leave_tree_probability=0.25, emergence_flight_distance)
    return PWNModel.BeetleMovement(;
        steps_per_tick=1, distance_per_step=2000.0, duration_feeding=3, feeding_probability=0.5,
        leave_tree_probability=leave_tree_probability, emergence_flight_distance=emergence_flight_distance,
    )
end

# Number of beetles per cell.
function _beetle_cells(world)
    counts = Dict{Tuple{Int,Int},Int}()
    for (_, positions) in Query(world, (PWNModel.BeetlePosition,))
        for p in positions
            counts[(p.x, p.y)] = get(counts, (p.x, p.y), 0) + 1
        end
    end
    return counts
end

@testset "BeetleMovement without emergence flight, same target" begin
    world = _setup_beetle_movement_world(_RING)
    s = _beetle_movement(; emergence_flight_distance=0.0)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    @test length(_beetle_cells(world)) == 1
end

@testset "BeetleMovement emergence flight spreads targets" begin
    world = _setup_beetle_movement_world(_RING)
    s = _beetle_movement(; emergence_flight_distance=300.0)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    cells = _beetle_cells(world)
    presence = get_resource(world, PWNModel.HealthyTreeAttraction).presence
    @test length(cells) > 3
    @test all(presence[x, y] for (x, y) in keys(cells))
end

@testset "BeetleMovement emergence flight only once" begin
    world = _setup_beetle_movement_world(_RING)
    s = _beetle_movement(; leave_tree_probability=0.0, emergence_flight_distance=300.0)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)
    before = _beetle_cells(world)

    get_resource(world, PWNModel.Time).tick = 1
    PWNModel.update!(s, world)

    @test _beetle_cells(world) == before
end

@testset "BeetleMovement emergence flight out of world dies" begin
    world = _setup_beetle_movement_world(_RING)
    s = _beetle_movement(; emergence_flight_distance=2000.0)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    # From (100, 25) in a 200 x 50 cell world, the flight of up to 200 cells
    # leaves the world in most directions and distances.
    cells = _beetle_cells(world)
    presence = get_resource(world, PWNModel.HealthyTreeAttraction).presence
    total = sum(values(cells); init=0)
    @test 0 < total < 50
    @test all(checkbounds(Bool, presence, x, y) for (x, y) in keys(cells))
end

# A beetle leaving the only tree of its target type walks until it leaves the
# world (as all cells have that tree as source), and dies.
@testset "BeetleMovement leave tree out of world dies" begin
    # Emerged in an earlier tick, so no emergence flight. Starts on the only
    # healthy tree.
    world = _setup_beetle_movement_world(((0, 0),); n=10, tick_of_emergence=-1)
    s = _beetle_movement(; leave_tree_probability=1.0, emergence_flight_distance=0.0)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    @test isempty(_beetle_cells(world))
end
