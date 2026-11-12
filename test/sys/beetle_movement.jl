# Creates a world with both attraction fields computed from healthy trees at
# the given offsets around a damaged brood tree at (100, 25), and `n` beetles
# at the brood tree that emerged at `tick_of_emergence`. The current tick is
# 0. Returns the world.
function _setup_beetle_movement_world(offsets; n=50, tick_of_emergence=0)
    world = World(
        PWNModel.Position, PWNModel.Damaged, PWNModel.BeetlePosition, PWNModel.EmergenceTick, PWNModel.WalkDirection,
    )
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

    new_entities!(
        world, n, (PWNModel.BeetlePosition, PWNModel.EmergenceTick, PWNModel.WalkDirection),
    ) do (_, positions, ticks, directions)
        for i in eachindex(positions)
            positions[i] = PWNModel.BeetlePosition(100, 25)
            ticks[i] = PWNModel.EmergenceTick(tick_of_emergence)
            directions[i] = PWNModel.WalkDirection()
        end
    end
    return world
end

const _RING = ((-15, 0), (15, 0), (0, -15), (0, 15), (-12, -12), (12, 12), (-12, 12), (12, -12))

function _beetle_movement(; leave_tree_probability=0.25, emergence_flight_distance, distance_per_step=2000.0)
    return PWNModel.BeetleMovement(;
        steps_per_tick=1, distance_per_step=distance_per_step, duration_feeding=3, feeding_probability=0.5,
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

# Without an emergence flight, no random numbers are drawn for it: emerging
# beetles still feeding (no feeding draw), not on a healthy tree (no leave
# draw), fly to their target without using the RNG at all.
@testset "BeetleMovement without emergence flight draws no random numbers" begin
    world = _setup_beetle_movement_world(_RING)
    s = _beetle_movement(; emergence_flight_distance=0.0)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    @test rand(get_resource(world, PWNModel.Rng)) == rand(PWNModel.Rng(1))
end

# Positions and walk directions of all beetles.
function _beetle_walks(world)
    walks = Tuple{PWNModel.BeetlePosition,PWNModel.WalkDirection}[]
    for (_, positions, directions) in Query(world, (PWNModel.BeetlePosition, PWNModel.WalkDirection))
        append!(walks, zip(positions, directions))
    end
    return walks
end

_is_walking(d::PWNModel.WalkDirection) = d.dx != 0 || d.dy != 0

# A beetle leaving the only tree (whose area is the whole world) with a budget
# of 5 cells per step runs out of budget before leaving the area. It stores
# its direction and mode, and continues in the next step without drawing any
# random numbers, instead of flying back to the tree.
@testset "BeetleMovement walk continues in stored direction" begin
    world = _setup_beetle_movement_world(((0, 0),); n=20, tick_of_emergence=-1)
    s = _beetle_movement(; leave_tree_probability=1.0, emergence_flight_distance=0.0, distance_per_step=50.0)
    PWNModel.initialize!(s, world)

    PWNModel.update!(s, world)
    first_walks = _beetle_walks(world)
    @test length(first_walks) == 20
    for (p, d) in first_walks
        @test _is_walking(d)
        @test d.on_the_way
        @test d.feeding
        @test 4 <= hypot(p.x - 100, p.y - 25) <= 6
    end

    rng = get_resource(world, PWNModel.Rng)
    expected = copy(rng.xoshiro)
    PWNModel.update!(s, world)
    @test rng.xoshiro == expected

    second_walks = _beetle_walks(world)
    @test length(second_walks) == 20
    for ((p1, d1), (p2, d2)) in zip(first_walks, second_walks)
        @test d2 == d1
        # Each step rounds to cells, off by up to ~0.7 cells.
        @test 8.5 <= hypot(p2.x - 100, p2.y - 25) <= 11.5
        # Still moving away from the tree, in the stored direction.
        @test (p2.x - p1.x) * d1.dx + (p2.y - p1.y) * d1.dy > 4
    end
end

# With two trees 30 cells apart, beetles leaving the west tree towards the
# east leave its area after 15 cells, i.e. in their third step, and then fly
# to the east tree. Beetles on a tree never have a stored direction.
@testset "BeetleMovement walk direction is cleared when leaving the area" begin
    world = _setup_beetle_movement_world(((0, 0), (30, 0)); n=50, tick_of_emergence=-1)
    s = _beetle_movement(; leave_tree_probability=1.0, emergence_flight_distance=0.0, distance_per_step=50.0)
    PWNModel.initialize!(s, world)
    presence = get_resource(world, PWNModel.HealthyTreeAttraction).presence

    reached_east = false
    for _ in 1:10
        PWNModel.update!(s, world)
        for (p, d) in _beetle_walks(world)
            presence[p.x, p.y] && @test !_is_walking(d)
            _is_walking(d) && @test !presence[p.x, p.y]
            reached_east |= (p.x, p.y) == (130, 25)
        end
    end
    @test reached_east
end

# Beetles in the egg laying phase between a healthy (east) and a damaged (west)
# tree, 30 cells from each, with a budget of 5 cells per step, fly towards one
# of them by mode. They keep their mode while on the way, without drawing it
# anew, until they arrive.
@testset "BeetleMovement keeps mode while flying to a target" begin
    world = _setup_beetle_movement_world(((60, 0),); n=20, tick_of_emergence=-10)
    for (_, positions) in Query(world, (PWNModel.BeetlePosition,))
        fill!(positions, PWNModel.BeetlePosition(130, 25))
    end
    s = _beetle_movement(; leave_tree_probability=0.0, emergence_flight_distance=0.0, distance_per_step=50.0)
    PWNModel.initialize!(s, world)

    PWNModel.update!(s, world)
    first_walks = _beetle_walks(world)
    for (p, d) in first_walks
        @test d.on_the_way
        @test !_is_walking(d)
        @test p == PWNModel.BeetlePosition(d.feeding ? 135 : 125, 25)
    end
    # Both modes occur.
    @test length(unique(d.feeding for (_, d) in first_walks)) == 2

    rng = get_resource(world, PWNModel.Rng)
    expected = copy(rng.xoshiro)
    for _ in 1:4
        PWNModel.update!(s, world)
    end
    @test rng.xoshiro == expected
    for ((_, d1), (p, d)) in zip(first_walks, _beetle_walks(world))
        @test d.on_the_way
        @test d.feeding == d1.feeding
        @test p == PWNModel.BeetlePosition(d1.feeding ? 155 : 105, 25)
    end

    # Arrived after 6 steps, no longer on the way.
    PWNModel.update!(s, world)
    for ((_, d1), (p, d)) in zip(first_walks, _beetle_walks(world))
        @test d == PWNModel.WalkDirection()
        @test p == PWNModel.BeetlePosition(d1.feeding ? 160 : 100, 25)
    end
end
