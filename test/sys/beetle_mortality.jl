@testset "BeetleMortality removes beetles at or past tick_of_death" begin
    world = World(PWNModel.LifeExpectancy)
    add_resource!(world, PWNModel.Time(10, 0, 0))

    s = PWNModel.BeetleMortality()

    # Death was in the past.
    past = nothing
    new_entities!(world, 1, (PWNModel.LifeExpectancy,)) do (entities, le)
        le[1] = PWNModel.LifeExpectancy(5)
        past = entities[1]
    end
    # Death is exactly this tick (inclusive boundary).
    at_threshold = nothing
    new_entities!(world, 1, (PWNModel.LifeExpectancy,)) do (entities, le)
        le[1] = PWNModel.LifeExpectancy(10)
        at_threshold = entities[1]
    end
    # Death is still in the future.
    future = nothing
    new_entities!(world, 1, (PWNModel.LifeExpectancy,)) do (entities, le)
        le[1] = PWNModel.LifeExpectancy(11)
        future = entities[1]
    end

    PWNModel.update!(s, world)

    @test !is_alive(world, past)
    @test !is_alive(world, at_threshold)
    @test is_alive(world, future)
end

@testset "BeetleMortality no deaths is a no-op" begin
    world = World(PWNModel.LifeExpectancy)
    add_resource!(world, PWNModel.Time(0, 0, 0))

    s = PWNModel.BeetleMortality()

    alive = nothing
    new_entities!(world, 1, (PWNModel.LifeExpectancy,)) do (entities, le)
        le[1] = PWNModel.LifeExpectancy(100)
        alive = entities[1]
    end

    PWNModel.update!(s, world)

    @test is_alive(world, alive)
end

@testset "BeetleMortality no entities is a no-op" begin
    world = World(PWNModel.LifeExpectancy)
    add_resource!(world, PWNModel.Time(0, 0, 0))

    s = PWNModel.BeetleMortality()

    PWNModel.update!(s, world)
end

@testset "BeetleMortality _to_remove buffer resets across ticks" begin
    world = World(PWNModel.LifeExpectancy)
    add_resource!(world, PWNModel.Time(0, 0, 0))

    s = PWNModel.BeetleMortality()

    dead = nothing
    new_entities!(world, 1, (PWNModel.LifeExpectancy,)) do (entities, le)
        le[1] = PWNModel.LifeExpectancy(0)
        dead = entities[1]
    end

    PWNModel.update!(s, world)
    @test !is_alive(world, dead)

    # If the reused _to_remove buffer weren't cleared, this second tick
    # (with no newly-dead entities) would try to remove the already-dead
    # entity again and throw.
    PWNModel.update!(s, world)
end
