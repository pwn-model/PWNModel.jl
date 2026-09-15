@testset "InitGrids" begin
    world = World()
    add_resource!(world, PWNModel.WorldSize(25, 12, 10))

    s = PWNModel.InitGrids()
    PWNModel.initialize!(s, world)

    trees = get_resource(world, PWNModel.EntityGrid)
    @test trees.width == 25
    @test trees.height == 12

    space = get_resource(world, PWNModel.SpaceGrid)
    @test space.grid.width == 3  # ceil(25/10)
    @test space.grid.height == 2 # ceil(12/10)
end
