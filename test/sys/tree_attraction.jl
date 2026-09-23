function _setup_tree_attraction_world()
    world = World(PWNModel.Position, PWNModel.Damaged)
    ws = PWNModel.WorldSize(width=2000, height=500, cell_size=10, grid_cell_size=100)
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

    s = PWNModel.TreeAttraction(tick_of_year=0, scale=50, density_radius=20, density_weight=0.0)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    # A single isolated tree seeds at occupancy^0=1; 10 cells away (a
    # purely orthogonal offset, so the chamfer sweep is exact here, not
    # approximate), the value should be exactly decay^10 -- confirming
    # fill_grid! decays multiplicatively rather than subtracting a fixed
    # cost per step.
    decay = exp(-10.0 / 50.0)
    grid = get_resource(world, PWNModel.HealthyTreeAttraction).grid
    @test isapprox(grid[60, 25], decay^10; atol=1e-9)
end

@testset "TreeAttraction has no hard cutoff" begin
    world = _setup_tree_attraction_world()
    _place_tree(world, 50, 25)

    s = PWNModel.TreeAttraction(tick_of_year=0, scale=10, density_radius=20, density_weight=0.0)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    # Multiplicative decay never hits an exact 0, however far from any
    # source: even at the far opposite corner of the world, the value
    # must be strictly positive.
    grid = get_resource(world, PWNModel.HealthyTreeAttraction).grid
    @test grid[200, 50] > 0.0
end

@testset "TreeAttraction zero weight favours closer isolated tree" begin
    world = _setup_tree_attraction_world()
    _place_isolated_tree_and_cluster!(world)

    s = PWNModel.TreeAttraction(tick_of_year=0, scale=200, density_radius=20, density_weight=0.0)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    # At weight 0 every source seeds at 1 regardless of clustering, so
    # max-relaxation just tracks the nearest source: the closer isolated
    # tree (10 cells away) must win over the farther cluster (39 cells to
    # its nearest tree).
    grid = get_resource(world, PWNModel.HealthyTreeAttraction).grid
    decay = exp(-10.0 / 200.0)
    @test isapprox(grid[60, 25], decay^10; atol=1e-9)
end

@testset "TreeAttraction weight lets farther denser cluster win" begin
    world = _setup_tree_attraction_world()
    _place_isolated_tree_and_cluster!(world)

    s = PWNModel.TreeAttraction(tick_of_year=0, scale=200, density_radius=20, density_weight=1.0)
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
    grid = get_resource(world, PWNModel.HealthyTreeAttraction).grid
    decay = exp(-10.0 / 200.0)
    max_count = (2.0 * 2.0 + 1.0)^2 # density_radius=20, cell_size=10 -> density_radius_cells=2.
    isolated_value = (1.0 / max_count) * decay^10
    cluster_value = (9.0 / max_count) * decay^39
    @test cluster_value > isolated_value
    @test isapprox(grid[60, 25], cluster_value; atol=1e-9)
end

@testset "TreeAttraction field never exceeds one" begin
    world = _setup_tree_attraction_world()
    for dx in (-2):2, dy in (-2):2
        _place_tree(world, 50 + dx, 25 + dy)
    end

    s = PWNModel.TreeAttraction(tick_of_year=0, scale=200, density_radius=20, density_weight=5.0)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    # A fully-occupied patch (a tree in every cell of its own
    # density_radius window) has an occupancy fraction of exactly 1, so
    # its seed is exactly 1 regardless of density_weight -- and since
    # fill_grid!'s max-relaxation can never exceed the largest seed
    # anywhere in the grid, no cell of the resulting field can exceed 1
    # either, however densely populated the world is or how high
    # density_weight is set.
    grid = get_resource(world, PWNModel.HealthyTreeAttraction).grid
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
    s = PWNModel.TreeAttraction(tick_of_year=0, scale=50, density_radius=7, density_weight=0.0)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    grid = get_resource(world, PWNModel.HealthyTreeAttraction).grid
    @test isapprox(grid[50, 25], 1.0; atol=1e-9)
end

@testset "TreeAttraction skips wrong tick of year" begin
    world = _setup_tree_attraction_world()
    _place_tree(world, 50, 25)

    s = PWNModel.TreeAttraction(tick_of_year=5, scale=200, density_radius=20, density_weight=1.0)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    grid = get_resource(world, PWNModel.HealthyTreeAttraction).grid
    @test grid[50, 25] == 0.0
end
