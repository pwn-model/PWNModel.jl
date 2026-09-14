@testset "Position" begin
    pos = PWNModel.Position(1, 2)
    @test pos.x == 1
    @test pos.y == 2
end
