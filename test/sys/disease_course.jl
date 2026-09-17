@testset "DiseaseCourse" begin
    world = World(PWNModel.Infected, PWNModel.Damaged)
    time = add_resource!(world, PWNModel.Time())

    long_infected = nothing
    at_threshold = nothing
    recently_infected = nothing

    new_entities!(world, 1, (PWNModel.Infected,)) do (entities, infected)
        infected[1] = PWNModel.Infected(0)
        long_infected = entities[1]
    end
    new_entities!(world, 1, (PWNModel.Infected,)) do (entities, infected)
        infected[1] = PWNModel.Infected(5)
        at_threshold = entities[1]
    end
    new_entities!(world, 1, (PWNModel.Infected,)) do (entities, infected)
        infected[1] = PWNModel.Infected(8)
        recently_infected = entities[1]
    end

    s = PWNModel.DiseaseCourse(ticks_to_damage=5)
    time.tick = 10
    PWNModel.update!(s, world)

    @test has_components(world, long_infected, (PWNModel.Damaged,))
    @test has_components(world, at_threshold, (PWNModel.Damaged,))
    @test !has_components(world, recently_infected, (PWNModel.Damaged,))
end

@testset "DiseaseCourse skips already damaged" begin
    world = World(PWNModel.Infected, PWNModel.Damaged)
    time = add_resource!(world, PWNModel.Time())

    entity = nothing
    new_entities!(world, 1, (PWNModel.Infected, PWNModel.Damaged)) do (entities, infected, _)
        infected[1] = PWNModel.Infected(0)
        entity = entities[1]
    end

    s = PWNModel.DiseaseCourse(ticks_to_damage=5)
    time.tick = 10
    PWNModel.update!(s, world)

    @test has_components(world, entity, (PWNModel.Damaged,))
end
