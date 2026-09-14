@testset "InitTrees" begin
    world = World(PWNModel.Position)
    grid = PWNModel.TreeGrid(100, 50)
    add_resource!(world, grid)

    s = PWNModel.InitTrees(0.9)
    PWNModel.initialize!(s, world)

    count = count_entities(Filter(world, (PWNModel.Position,)))
    @test count > 4400
    @test count < 4600

    (_, positions) = first(Query(world, (PWNModel.Position,)))
    pos = positions[1]
    @test !is_zero(grid[pos.x, pos.y])
end
