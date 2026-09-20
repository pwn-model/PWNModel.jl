@testset "Tick" begin
    tick = PWNModel.Tick()
    @test tick.value == 0

    tick2 = PWNModel.Tick(3)
    @test tick2.value == 3
end
