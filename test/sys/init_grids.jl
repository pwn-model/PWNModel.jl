@testset "InitGrids" begin
    world = World(PWNModel.GridCoords)
    add_resource!(world, PWNModel.WorldSize(30, 20, 10))

    s = PWNModel.InitGrids()
    PWNModel.initialize!(s, world)

    trees = get_resource(world, PWNModel.EntityGrid)
    @test trees.width == 30
    @test trees.height == 20

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

@testset "InitGrids throws on size not multiple of resolution" begin
    world = World(PWNModel.GridCoords)
    add_resource!(world, PWNModel.WorldSize(25, 12, 10))

    s = PWNModel.InitGrids()
    @test_throws ArgumentError PWNModel.initialize!(s, world)
end
