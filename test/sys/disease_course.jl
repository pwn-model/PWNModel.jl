@testset "DiseaseCourse" begin
    world = World(PWNModel.NematodeInfected, PWNModel.Damaged)
    tick = add_resource!(world, PWNModel.Tick())

    long_infected = nothing
    at_threshold = nothing
    recently_infected = nothing

    new_entities!(world, 1, (PWNModel.NematodeInfected,)) do (entities, infected)
        infected[1] = PWNModel.NematodeInfected(0)
        long_infected = entities[1]
    end
    new_entities!(world, 1, (PWNModel.NematodeInfected,)) do (entities, infected)
        infected[1] = PWNModel.NematodeInfected(5)
        at_threshold = entities[1]
    end
    new_entities!(world, 1, (PWNModel.NematodeInfected,)) do (entities, infected)
        infected[1] = PWNModel.NematodeInfected(8)
        recently_infected = entities[1]
    end

    s = PWNModel.DiseaseCourse(ticks_to_damage=5)
    for _ in 0:10
        PWNModel.update!(s, world)
        tick.value += 1
    end

    @test has_components(world, long_infected, (PWNModel.Damaged,))
    @test has_components(world, at_threshold, (PWNModel.Damaged,))
    @test !has_components(world, recently_infected, (PWNModel.Damaged,))
end

@testset "DiseaseCourse skips already damaged" begin
    world = World(PWNModel.NematodeInfected, PWNModel.Damaged)
    tick = add_resource!(world, PWNModel.Tick())

    entity = nothing
    new_entities!(world, 1, (PWNModel.NematodeInfected, PWNModel.Damaged)) do (entities, infected, _)
        infected[1] = PWNModel.NematodeInfected(0)
        entity = entities[1]
    end

    s = PWNModel.DiseaseCourse(ticks_to_damage=5)
    for _ in 0:10
        PWNModel.update!(s, world)
        tick.value += 1
    end

    @test has_components(world, entity, (PWNModel.Damaged,))
end
