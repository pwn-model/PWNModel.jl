@testset "GridCoords" begin
    coords = PWNModel.GridCoords(1, 2)
    @test coords.x == 1
    @test coords.y == 2
end
