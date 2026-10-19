@testset "InitGrids" begin
    world = World()
    add_resource!(world, PWNModel.WorldSize(width=300, height=200, cell_size=10))

    s = PWNModel.InitGrids()
    PWNModel.initialize!(s, world)

    trees = get_resource(world, PWNModel.TreeGrid)
    @test trees.grid.width == 30
    @test trees.grid.height == 20
end

@testset "WorldSize throws on size not multiple of cell_size" begin
    @test_throws ArgumentError PWNModel.WorldSize(width=25, height=12, cell_size=10)
end
