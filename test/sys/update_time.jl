@testset "UpdateTime" begin
    world = World()
    tick = add_resource!(world, PWNModel.Tick())

    s = PWNModel.UpdateTime(weeks_per_year=52)
    PWNModel.initialize!(s, world)
    time = get_resource(world, PWNModel.Time)

    tick.value = 0
    PWNModel.update!(s, world)
    @test time.tick == 0
    @test time.tick_of_year == 0
    @test time.year == 0

    # Somewhere in the middle of the first year.
    tick.value = 10
    PWNModel.update!(s, world)
    @test time.tick == 10
    @test time.tick_of_year == 10
    @test time.year == 0

    # Exactly one full year elapsed: wraps into year 1, week 0.
    tick.value = 52
    PWNModel.update!(s, world)
    @test time.tick == 52
    @test time.tick_of_year == 0
    @test time.year == 1

    # Partway through the second year.
    tick.value = 60
    PWNModel.update!(s, world)
    @test time.tick == 60
    @test time.tick_of_year == 8
    @test time.year == 1
end
