@testset "InitGrids" begin
    world = World(PWNModel.GridCoords)
    add_resource!(world, PWNModel.WorldSize(width=300, height=200, cell_size=10, grid_cell_size=100))

    s = PWNModel.InitGrids()
    PWNModel.initialize!(s, world)

    trees = get_resource(world, PWNModel.TreeGrid)
    @test trees.grid.width == 30
    @test trees.grid.height == 20

    space = get_resource(world, PWNModel.SpaceGrid)
    @test space.grid.width == 3  # 30/10
    @test space.grid.height == 2 # 20/10

    count = count_entities(Filter(world, (PWNModel.GridCoords,)))
    @test count == space.grid.width * space.grid.height

    for (entities, coords) in Query(world, (PWNModel.GridCoords,))
        for i in eachindex(entities)
            gc = coords[i]
            @test space.grid[gc.x, gc.y] == entities[i]
        end
    end
end

@testset "WorldSize throws on size not multiple of cell_size" begin
    @test_throws ArgumentError PWNModel.WorldSize(width=25, height=12, cell_size=10, grid_cell_size=10)
end
