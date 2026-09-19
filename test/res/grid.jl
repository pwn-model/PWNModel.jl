@testset "Grid" begin
    grid = PWNModel.TreeGrid(4, 3, 1)
    @test grid.grid.width == 4
    @test grid.grid.height == 3
    @test grid.grid.cell_size == 1

    world = World()
    e = new_entity!(world, ())
    grid.grid[2, 1] = e
    @test grid.grid[2, 1] == e
    @test is_zero(grid.grid[1, 1]) == true
end
