function _setup_random_infection_world()
    world = World(
        PWNModel.Position,
        PWNModel.GridCoords,
        PWNModel.Damaged,
        PWNModel.Infected,
        PWNModel.Colonized,
        Relation{PWNModel.InCell},
    )

    # 2x2 coarse grid, 100 trees per coarse cell.
    ws = PWNModel.WorldSize(width=200, height=200, cell_size=10, grid_cell_size=100)
    add_resource!(world, ws)
    add_resource!(world, PWNModel.Rng(1))
    time = add_resource!(world, PWNModel.Time())

    gs = PWNModel.InitGrids()
    PWNModel.initialize!(gs, world)

    ts = PWNModel.InitTrees(cell_probability=1.0, tree_probability=1.0, damage_prevalence=0.0, beetle_prevalence=0.0)
    PWNModel.initialize!(ts, world)

    return world, time
end

@testset "RandomInfection" begin
    world, time = _setup_random_infection_world()

    s = PWNModel.RandomInfection(tick_of_infection=3, num_trees=10, cell_x=1, cell_y=1)

    for tick in 0:2
        time.tick = tick
        PWNModel.update!(s, world)
        @test count_entities(Filter(world, (PWNModel.Infected,))) == 0
    end

    # At tick 3, exactly num_trees trees get infected.
    time.tick = 3
    PWNModel.update!(s, world)

    space = get_resource(world, PWNModel.SpaceGrid)
    ws = get_resource(world, PWNModel.WorldSize)
    target = space.grid[1, 1]

    count = 0
    for (entities, positions, infected) in
        Query(world, (PWNModel.Position, PWNModel.Infected); with=(PWNModel.InCell => target,))
        for i in eachindex(entities)
            @test infected[i].infection_tick == 3
            @test positions[i].x <= ws.resolution
            @test positions[i].y <= ws.resolution
            count += 1
        end
    end
    @test count == 10
    @test count_entities(Filter(world, (PWNModel.Infected,))) == 10

    # Later ticks must not infect further trees.
    time.tick = 4
    PWNModel.update!(s, world)
    @test count_entities(Filter(world, (PWNModel.Infected,))) == 10
end

@testset "RandomInfection skips ineligible trees" begin
    world, _time = _setup_random_infection_world()

    space = get_resource(world, PWNModel.SpaceGrid)
    target = space.grid[1, 1]

    spared = nothing
    to_pre_infect = Entity[]
    first_seen = false
    for (entities, _) in Query(world, (PWNModel.Position,); with=(PWNModel.InCell => target,))
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

    s = PWNModel.RandomInfection(tick_of_infection=0, num_trees=5, cell_x=1, cell_y=1)
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

@testset "RandomInfection caps at available trees" begin
    world, _time = _setup_random_infection_world()

    # Coarse cell (1, 1) holds 10*10 = 100 trees; request far more than that.
    s = PWNModel.RandomInfection(tick_of_infection=0, num_trees=1000, cell_x=1, cell_y=1)
    PWNModel.update!(s, world)

    @test count_entities(Filter(world, (PWNModel.Infected,))) == 100
end

@testset "RandomInfection only targets specified cell" begin
    world, _time = _setup_random_infection_world()

    ws = get_resource(world, PWNModel.WorldSize)
    s = PWNModel.RandomInfection(tick_of_infection=0, num_trees=10, cell_x=2, cell_y=2)
    PWNModel.update!(s, world)

    for (_, positions) in Query(world, (PWNModel.Position,); with=(PWNModel.Infected,))
        for pos in positions
            @test pos.x > ws.resolution
            @test pos.y > ws.resolution
        end
    end
end
