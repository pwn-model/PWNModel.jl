@testset "FixedTermination stops the run after the given number of steps" begin
    scheduler = PWNModel.Scheduler(
        World(),
        (PWNModel.FixedTermination(steps=100),),
    )

    PWNModel.run!(scheduler)

    @test get_resource(scheduler.world, PWNModel.Tick).value == 100
end

@testset "FixedTermination does not affect earlier steps" begin
    scheduler = PWNModel.Scheduler(
        World(),
        (PWNModel.FixedTermination(steps=100),),
    )

    for _ in 1:99
        @test PWNModel.step!(scheduler) == true
    end
    @test PWNModel.step!(scheduler) == false
end
