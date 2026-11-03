function _setup_tree_attraction_world()
    world = World(PWNModel.Position, PWNModel.Damaged)
    ws = PWNModel.WorldSize(width=2000, height=500, cell_size=10)
    add_resource!(world, ws)
    add_resource!(world, PWNModel.Time(0, 0, 0))
    return world
end

function _place_tree(world, x::Int, y::Int)
    entity = nothing
    new_entities!(world, 1, (PWNModel.Position,)) do (entities, positions)
        positions[1] = PWNModel.Position(x, y)
        entity = entities[1]
    end
    return entity
end

# Places a closer isolated healthy tree at (50, 25) and a farther 3x3
# cluster of 9 healthy trees around (100, 25). A query point at (60, 25) is
# then 10 cells from the isolated tree, 39 cells from the cluster's
# nearest edge.
function _place_isolated_tree_and_cluster!(world)
    _place_tree(world, 50, 25)
    for dx in (-1):1, dy in (-1):1
        _place_tree(world, 100 + dx, 25 + dy)
    end
end

@testset "TreeAttraction single source decays multiplicatively" begin
    world = _setup_tree_attraction_world()
    _place_tree(world, 50, 25)

    half_distance = 50 * log(2)
    s = PWNModel.TreeAttraction(
        tick_of_year=0,
        damaged_trees=false,
        half_distance=half_distance,
        density_radius=20,
        density_weight=0.0,
    )
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    # A single isolated tree seeds at occupancy^0=1; 10 cells away (a
    # purely orthogonal offset, so the chamfer sweep is exact here, not
    # approximate), the value should be exactly decay^10 -- confirming
    # propagate_attraction! decays multiplicatively rather than subtracting
    # a fixed cost per step.
    decay = exp(-10.0 * log(2) / half_distance)
    grid = get_resource(world, PWNModel.HealthyTreeAttraction).attraction
    @test isapprox(grid[60, 25], decay^10; atol=1e-9)
end

# Two independently configured instances -- one for healthy trees, one for
# damaged -- can be run in the same world side by side (as they would be
# added to a real scheduler twice), each driven only by its own tree type
# and its own half_distance, without interfering with each other.
@testset "TreeAttraction healthy and damaged instances are independent" begin
    world = _setup_tree_attraction_world()
    _place_tree(world, 50, 25)

    new_entities!(world, 1, (PWNModel.Position, PWNModel.Damaged)) do (entities, positions, _)
        positions[1] = PWNModel.Position(80, 25)
    end

    healthy_half_distance = 50 * log(2)
    healthy = PWNModel.TreeAttraction(
        tick_of_year=0, damaged_trees=false, half_distance=healthy_half_distance, density_radius=20,
        density_weight=0.0,
    )
    PWNModel.initialize!(healthy, world)

    damaged_half_distance = 200 * log(2)
    damaged = PWNModel.TreeAttraction(
        tick_of_year=0, damaged_trees=true, half_distance=damaged_half_distance, density_radius=20,
        density_weight=0.0,
    )
    PWNModel.initialize!(damaged, world)

    PWNModel.update!(healthy, world)
    PWNModel.update!(damaged, world)

    healthy_grid = get_resource(world, PWNModel.HealthyTreeAttraction).attraction
    damaged_grid = get_resource(world, PWNModel.DamagedTreeAttraction).attraction

    # The healthy field is driven only by the healthy tree at (50, 25), 10
    # cells from the query point, using the healthy instance's own decay.
    healthy_decay = exp(-10.0 * log(2) / healthy_half_distance)
    @test isapprox(healthy_grid[60, 25], healthy_decay^10; atol=1e-9)

    # The damaged field is driven only by the damaged tree at (80, 25), 20
    # cells from the same query point, using the damaged instance's own
    # (different) decay -- confirming the two run independently.
    damaged_decay = exp(-10.0 * log(2) / damaged_half_distance)
    @test isapprox(damaged_grid[60, 25], damaged_decay^20; atol=1e-9)
end

@testset "TreeAttraction has no hard cutoff" begin
    world = _setup_tree_attraction_world()
    _place_tree(world, 50, 25)

    s = PWNModel.TreeAttraction(
        tick_of_year=0,
        damaged_trees=false,
        half_distance=10 * log(2),
        density_radius=20,
        density_weight=0.0,
    )
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    # Multiplicative decay never hits an exact 0, however far from any
    # source: even at the far opposite corner of the world, the value
    # must be strictly positive.
    grid = get_resource(world, PWNModel.HealthyTreeAttraction).attraction
    @test grid[200, 50] > 0.0
end

@testset "TreeAttraction zero weight favours closer isolated tree" begin
    world = _setup_tree_attraction_world()
    _place_isolated_tree_and_cluster!(world)

    half_distance = 200 * log(2)
    s = PWNModel.TreeAttraction(
        tick_of_year=0,
        damaged_trees=false,
        half_distance=half_distance,
        density_radius=20,
        density_weight=0.0,
    )
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    # At weight 0 every source seeds at 1 regardless of clustering, so
    # max-relaxation just tracks the nearest source: the closer isolated
    # tree (10 cells away) must win over the farther cluster (39 cells to
    # its nearest tree).
    grid = get_resource(world, PWNModel.HealthyTreeAttraction).attraction
    decay = exp(-10.0 * log(2) / half_distance)
    @test isapprox(grid[60, 25], decay^10; atol=1e-9)

    source = get_resource(world, PWNModel.HealthyTreeAttraction).source
    @test source[60, 25] == PWNModel.Cell(50, 25)
end

@testset "TreeAttraction weight lets farther denser cluster win" begin
    world = _setup_tree_attraction_world()
    _place_isolated_tree_and_cluster!(world)

    half_distance = 200 * log(2)
    s = PWNModel.TreeAttraction(
        tick_of_year=0,
        damaged_trees=false,
        half_distance=half_distance,
        density_radius=20,
        density_weight=1.0,
    )
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    # At weight 1, each seed is its occupancy fraction (local count / cells
    # in a density_radius window): the cluster's 9/25 versus the isolated
    # tree's 1/25 (density_radius=20, cell_size=10 -> a 5x5=25-cell
    # window). The cluster's contribution ((9/25)*decay^39) can still
    # out-reach the isolated tree's ((1/25)*decay^10) despite being 3x
    # farther away, and despite both being scaled down by the same
    # normalization -- a deterministic "pick the highest neighbour"
    # consumer is now pulled towards the farther, denser cluster instead
    # of the closer lone tree.
    grid = get_resource(world, PWNModel.HealthyTreeAttraction).attraction
    decay = exp(-10.0 * log(2) / half_distance)
    max_count = (2.0 * 2.0 + 1.0)^2 # density_radius=20, cell_size=10 -> density_radius_cells=2.
    isolated_value = (1.0 / max_count) * decay^10
    cluster_value = (9.0 / max_count) * decay^39
    @test cluster_value > isolated_value
    @test isapprox(grid[60, 25], cluster_value; atol=1e-9)

    # The source is the cluster's nearest tree, not the closer lone tree.
    source = get_resource(world, PWNModel.HealthyTreeAttraction).source
    @test source[60, 25] == PWNModel.Cell(99, 25)
end

@testset "TreeAttraction field never exceeds one" begin
    world = _setup_tree_attraction_world()
    for dx in (-2):2, dy in (-2):2
        _place_tree(world, 50 + dx, 25 + dy)
    end

    s = PWNModel.TreeAttraction(
        tick_of_year=0, damaged_trees=false, half_distance=200 * log(2), density_radius=20, density_weight=5.0,
    )
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    # A fully-occupied patch (a tree in every cell of its own
    # density_radius window) has an occupancy fraction of exactly 1, so
    # its seed is exactly 1 regardless of density_weight -- and since
    # propagate_attraction!'s max-relaxation can never exceed the largest
    # seed anywhere in the grid, no cell of the resulting field can exceed
    # 1 either, however densely populated the world is or how high
    # density_weight is set.
    grid = get_resource(world, PWNModel.HealthyTreeAttraction).attraction
    @test isapprox(grid[50, 25], 1.0; atol=1e-9)
    @test maximum(grid._values) <= 1.0 + 1e-9
end

@testset "TreeAttraction zero weight skips density_radius validation" begin
    world = _setup_tree_attraction_world()
    _place_tree(world, 50, 25)

    # At density_weight 0, fill_from_query! takes a fast path that seeds
    # every source at 1 directly, without ever consulting density_radius
    # -- so an invalid density_radius (here, not a multiple of the
    # world's 10m cell size) must not throw during initialize!.
    s = PWNModel.TreeAttraction(
        tick_of_year=0,
        damaged_trees=false,
        half_distance=50 * log(2),
        density_radius=7,
        density_weight=0.0,
    )
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    grid = get_resource(world, PWNModel.HealthyTreeAttraction).attraction
    @test isapprox(grid[50, 25], 1.0; atol=1e-9)
end

@testset "TreeAttraction skips wrong tick of year" begin
    world = _setup_tree_attraction_world()
    _place_tree(world, 50, 25)

    s = PWNModel.TreeAttraction(
        tick_of_year=5,
        damaged_trees=false,
        half_distance=200 * log(2),
        density_radius=20,
        density_weight=1.0,
    )
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    grid = get_resource(world, PWNModel.HealthyTreeAttraction).attraction
    @test grid[50, 25] == 0.0
end

# Presence is updated together with the attraction field, only on
# tick_of_year, and only for the instance's own tree type.
@testset "TreeAttraction presence on tick of year" begin
    world = _setup_tree_attraction_world()
    e = _place_tree(world, 50, 25)

    new_entities!(world, 1, (PWNModel.Position, PWNModel.Damaged)) do (entities, positions, _)
        positions[1] = PWNModel.Position(80, 25)
    end

    healthy = PWNModel.TreeAttraction(
        tick_of_year=0, damaged_trees=false, half_distance=50.0, density_radius=20, density_weight=1.0,
    )
    PWNModel.initialize!(healthy, world)
    damaged = PWNModel.TreeAttraction(
        tick_of_year=0, damaged_trees=true, half_distance=50.0, density_radius=20, density_weight=1.0,
    )
    PWNModel.initialize!(damaged, world)

    PWNModel.update!(healthy, world)
    PWNModel.update!(damaged, world)

    healthy_presence = get_resource(world, PWNModel.HealthyTreeAttraction).presence
    damaged_presence = get_resource(world, PWNModel.DamagedTreeAttraction).presence
    @test healthy_presence[50, 25]
    @test !healthy_presence[80, 25]
    @test damaged_presence[80, 25]
    @test !damaged_presence[50, 25]

    # A tree becoming damaged is not reflected outside tick_of_year...
    add_components!(world, e, (PWNModel.Damaged(),))
    time = get_resource(world, PWNModel.Time)
    time.tick_of_year = 1
    PWNModel.update!(healthy, world)
    PWNModel.update!(damaged, world)

    @test healthy_presence[50, 25]
    @test !damaged_presence[50, 25]

    # ...but on the next tick_of_year.
    time.tick_of_year = 0
    PWNModel.update!(healthy, world)
    PWNModel.update!(damaged, world)

    @test !healthy_presence[50, 25]
    @test damaged_presence[50, 25]
end

# The seeds computed by fill_from_query!, with the summed-area table and
# the seeding fused into one pass, match a brute-force window count,
# including near the world's edges.
@testset "TreeAttraction seeds match brute force" begin
    world = World(PWNModel.Position, PWNModel.Damaged)
    ws = PWNModel.WorldSize(width=300, height=200, cell_size=10)
    add_resource!(world, ws)
    add_resource!(world, PWNModel.Time(0, 0, 0))

    rng = PWNModel.Rng(1)
    w, h = ws.width, ws.height
    for _ in 1:200
        _place_tree(world, floor(Int, rand(rng) * w) + 1, floor(Int, rand(rng) * h) + 1)
    end

    s = PWNModel.TreeAttraction(
        tick_of_year=0, damaged_trees=false, half_distance=50.0, density_radius=40, density_weight=1.5,
    )
    PWNModel.initialize!(s, world)
    PWNModel.fill_from_query!(s, s._filter)

    r = s._density_radius_cells
    mismatches = 0
    for x in 1:w, y in 1:h
        if !s._presence[x, y]
            mismatches += s._attraction[x, y] != 0.0
            continue
        end
        count = 0
        for xx in max(x-r, 1):min(x+r, w), yy in max(y-r, 1):min(y+r, h)
            count += s._presence[xx, yy]
        end
        mismatches += s._attraction[x, y] != (count / s._max_count)^s.density_weight
    end
    @test mismatches == 0
end

# Without any matching tree, no cell has a source.
@testset "TreeAttraction no trees no source" begin
    world = _setup_tree_attraction_world()

    s = PWNModel.TreeAttraction(
        tick_of_year=0, damaged_trees=false, half_distance=50.0, density_radius=20, density_weight=1.0,
    )
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    source = get_resource(world, PWNModel.HealthyTreeAttraction).source
    @test all(==(PWNModel.NO_CELL), source._values)
end

# Every cell's traced source is a tree cell, the cell's value is exactly
# that source's seed decayed over the octile distance between them, and no
# other tree contributes more -- i.e. the source is the tree that wins the
# max-relaxation, checked by brute force over all trees.
@testset "TreeAttraction source matches brute force" begin
    world = World(PWNModel.Position, PWNModel.Damaged)
    ws = PWNModel.WorldSize(width=300, height=200, cell_size=10)
    add_resource!(world, ws)
    add_resource!(world, PWNModel.Time(0, 0, 0))

    rng = PWNModel.Rng(1)
    w, h = ws.width, ws.height
    for _ in 1:40
        _place_tree(world, floor(Int, rand(rng) * w) + 1, floor(Int, rand(rng) * h) + 1)
    end

    s = PWNModel.TreeAttraction(
        tick_of_year=0, damaged_trees=false, half_distance=50.0, density_radius=40, density_weight=1.5,
    )
    PWNModel.initialize!(s, world)
    PWNModel.fill_from_query!(s, s._filter)

    seeds = copy(s._attraction._values)
    trees = [PWNModel.Cell(x, y) for x in 1:w, y in 1:h if s._presence[x, y]]

    PWNModel.propagate_attraction!(s._attraction, s._source, s.half_distance)

    decay = exp(-ws.cell_size * log(2) / s.half_distance)
    function contribution(x, y, c)
        dx, dy = abs(x - c.x), abs(y - c.y)
        dist = max(dx, dy) + (sqrt(2.0) - 1) * min(dx, dy)
        return seeds[c.y, c.x] * decay^dist
    end

    not_tree, wrong_value, outranked = 0, 0, 0
    for x in 1:w, y in 1:h
        c = s._source[x, y]
        if c == PWNModel.NO_CELL || !s._presence[c.x, c.y]
            not_tree += 1
            continue
        end
        v = s._attraction[x, y]
        wrong_value += !isapprox(contribution(x, y, c), v; rtol=1e-9)
        outranked += any(t -> contribution(x, y, t) > v * (1 + 1e-9), trees)
    end
    @test not_tree == 0
    @test wrong_value == 0
    @test outranked == 0
end
