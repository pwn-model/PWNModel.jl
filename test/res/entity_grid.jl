@testset "EntityGrid" begin
    grid = PWNModel.EntityGrid(4, 3)
    @test grid.width == 4
    @test grid.height == 3

    world = World()
    e = new_entity!(world, ())
    grid[2, 1] = e
    @test grid[2, 1] == e
    @test is_zero(grid[1, 1]) == true
end
