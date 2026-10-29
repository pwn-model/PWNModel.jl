# Creates a world of the given size in meters, with a 10m base cell size.
function _setup_coarse_tree_attraction_world(width::Int, height::Int)
    world = World(PWNModel.Position, PWNModel.Damaged)
    ws = PWNModel.WorldSize(width=width, height=height, cell_size=10)
    add_resource!(world, ws)
    add_resource!(world, PWNModel.Time(0, 0, 0))
    return world
end

# Places a healthy tree in every base cell of the given rectangle.
function _place_tree_block!(world, x0::Int, y0::Int, w::Int, h::Int)
    for x in x0:(x0+w-1), y in y0:(y0+h-1)
        _place_tree(world, x, y)
    end
end

function _coarse_tree_attraction(;
    tick_of_year=0, damaged_trees=false, cell_size=100, half_distance=100.0, density_weight=1.0,
)
    return PWNModel.CoarseTreeAttraction(
        tick_of_year=tick_of_year,
        damaged_trees=damaged_trees,
        cell_size=cell_size,
        half_distance=half_distance,
        density_weight=density_weight,
    )
end

@testset "CoarseTreeAttraction grid dimensions" begin
    # 2050m x 500m at 100m: 20.5 x 5 coarse cells, rounded up to 21 x 5.
    world = _setup_coarse_tree_attraction_world(2050, 500)

    s = _coarse_tree_attraction()
    PWNModel.initialize!(s, world)

    grid = get_resource(world, PWNModel.HealthyTreeAttractionCoarse).grid
    @test grid.width == 21
    @test grid.height == 5
    @test grid.cell_size == 100
end

# A coarse cell's seed is its tree count divided by the number of base
# cells in a coarse cell, raised to density_weight.
@testset "CoarseTreeAttraction seed is occupancy fraction" begin
    for weight in (0.0, 1.0, 2.0)
        world = _setup_coarse_tree_attraction_world(2000, 500)
        # 25 trees in coarse cell (1, 1), which covers 10 x 10 base cells.
        _place_tree_block!(world, 1, 1, 5, 5)

        s = _coarse_tree_attraction(density_weight=weight)
        PWNModel.initialize!(s, world)
        PWNModel.update!(s, world)

        grid = get_resource(world, PWNModel.HealthyTreeAttractionCoarse).grid
        @test isapprox(grid[1, 1], 0.25^weight; atol=1e-12)
    end
end

# A partial coarse cell along the world's edge is normalized like any other
# cell, by the number of base cells in a full coarse cell, so even a fully
# occupied one stays below 1.
@testset "CoarseTreeAttraction partial edge cell" begin
    # 205 x 50 base cells; the last coarse column (21) covers only base
    # columns 201..205, i.e. 5 x 10 of a coarse cell's 10 x 10 base cells.
    world = _setup_coarse_tree_attraction_world(2050, 500)
    _place_tree_block!(world, 201, 1, 5, 10)

    s = _coarse_tree_attraction()
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    grid = get_resource(world, PWNModel.HealthyTreeAttractionCoarse).grid
    @test isapprox(grid[21, 1], 0.5; atol=1e-12)
end

# half_distance is in meters, independent of the coarse cell size.
@testset "CoarseTreeAttraction half_distance in meters" begin
    world = _setup_coarse_tree_attraction_world(2000, 500)
    _place_tree(world, 56, 26) # coarse cell (6, 3)

    s = _coarse_tree_attraction(half_distance=300.0, density_weight=0.0)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    grid = get_resource(world, PWNModel.HealthyTreeAttractionCoarse).grid
    @test isapprox(grid[6, 3], 1.0; atol=1e-12)
    # 3 coarse cells = 300m away: half the seed.
    @test isapprox(grid[9, 3], 0.5; atol=1e-12)
    @test isapprox(grid[3, 3], 0.5; atol=1e-12)
end

@testset "CoarseTreeAttraction healthy and damaged instances are independent" begin
    world = _setup_coarse_tree_attraction_world(2000, 500)
    _place_tree(world, 56, 26) # coarse cell (6, 3)
    new_entities!(world, 1, (PWNModel.Position, PWNModel.Damaged)) do (entities, positions, _)
        positions[1] = PWNModel.Position(126, 26) # coarse cell (13, 3)
    end

    healthy = _coarse_tree_attraction(density_weight=0.0)
    PWNModel.initialize!(healthy, world)
    damaged = _coarse_tree_attraction(damaged_trees=true, density_weight=0.0)
    PWNModel.initialize!(damaged, world)

    PWNModel.update!(healthy, world)
    PWNModel.update!(damaged, world)

    healthy_grid = get_resource(world, PWNModel.HealthyTreeAttractionCoarse).grid
    damaged_grid = get_resource(world, PWNModel.DamagedTreeAttractionCoarse).grid

    @test isapprox(healthy_grid[6, 3], 1.0; atol=1e-12)
    @test isapprox(healthy_grid[13, 3], 0.5^7; atol=1e-12)
    @test isapprox(damaged_grid[13, 3], 1.0; atol=1e-12)
    @test isapprox(damaged_grid[6, 3], 0.5^7; atol=1e-12)
end

@testset "CoarseTreeAttraction rejects invalid cell_size" begin
    world = _setup_coarse_tree_attraction_world(2000, 500)

    s = _coarse_tree_attraction(cell_size=105)
    @test_throws ArgumentError PWNModel.initialize!(s, world)
end

@testset "CoarseTreeAttraction skips wrong tick of year" begin
    world = _setup_coarse_tree_attraction_world(2000, 500)
    _place_tree(world, 56, 26)

    s = _coarse_tree_attraction(tick_of_year=5)
    PWNModel.initialize!(s, world)
    PWNModel.update!(s, world)

    grid = get_resource(world, PWNModel.HealthyTreeAttractionCoarse).grid
    @test grid[6, 3] == 0.0
end
