@testset "Termination" begin
    term = PWNModel.Termination()
    @test term.terminate == false

    term2 = PWNModel.Termination(true)
    @test term2.terminate == true
end
