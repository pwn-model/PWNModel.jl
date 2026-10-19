function _setup_random_release_world()
    world = World(
        PWNModel.Position,
        PWNModel.Damaged,
        PWNModel.Infected,
        PWNModel.Colonized,
    )

    # 20x20 cells, one tree per cell.
    ws = PWNModel.WorldSize(width=200, height=200, cell_size=10)
    add_resource!(world, ws)
    add_resource!(world, PWNModel.Rng(1))
    time = add_resource!(world, PWNModel.Time())

    gs = PWNModel.InitGrids()
    PWNModel.initialize!(gs, world)

    ts = PWNModel.InitTrees(km2_probability=1.0, tree_probability=1.0, damage_prevalence=0.0, beetle_prevalence=0.0)
    PWNModel.initialize!(ts, world)

    return world, time
end

@testset "RandomRelease" begin
    world, time = _setup_random_release_world()

    s = PWNModel.RandomRelease(tick_of_infection=3, num_trees=10)

    for tick in 0:2
        time.tick = tick
        PWNModel.update!(s, world)
        @test count_entities(Filter(world, (PWNModel.Infected,))) == 0
    end

    # At tick 3, exactly num_trees trees get infected.
    time.tick = 3
    PWNModel.update!(s, world)

    count = 0
    for (entities, infected) in Query(world, (PWNModel.Infected,))
        for i in eachindex(entities)
            @test infected[i].infection_tick == 3
            count += 1
        end
    end
    @test count == 10

    # Later ticks must not infect further trees.
    time.tick = 4
    PWNModel.update!(s, world)
    @test count_entities(Filter(world, (PWNModel.Infected,))) == 10
end

@testset "RandomRelease skips ineligible trees" begin
    world, _time = _setup_random_release_world()

    # Mark all trees as already infected, except one.
    spared = nothing
    to_pre_infect = Entity[]
    first_seen = false
    for (entities, _) in Query(world, (PWNModel.Position,))
        for e in entities
            if !first_seen
                spared = e
                first_seen = true
                continue
            end
            push!(to_pre_infect, e)
        end
    end
    for e in to_pre_infect
        add_components!(world, e, (PWNModel.Infected(-1),))
    end

    s = PWNModel.RandomRelease(tick_of_infection=0, num_trees=5)
    PWNModel.update!(s, world)

    newly_infected = 0
    for (entities, infected) in Query(world, (PWNModel.Infected,))
        for i in eachindex(entities)
            if infected[i].infection_tick == 0
                newly_infected += 1
                @test entities[i] == spared
            end
        end
    end
    @test newly_infected == 1
end

@testset "RandomRelease caps at available trees" begin
    world, _time = _setup_random_release_world()

    # The world holds 20*20 = 400 trees; request far more than that.
    s = PWNModel.RandomRelease(tick_of_infection=0, num_trees=1000)
    PWNModel.update!(s, world)

    @test count_entities(Filter(world, (PWNModel.Infected,))) == 400
end
