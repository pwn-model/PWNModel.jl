@testset "TreeGrid" begin
    grid = PWNModel.TreeGrid(4, 3)
    @test size(grid.trees) == (3, 4)
    @test grid.width == 4
    @test grid.height == 3
end
