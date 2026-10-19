@testset "InitTrees" begin
    world = World(PWNModel.Position, PWNModel.Damaged, PWNModel.Colonized)

    ws = PWNModel.WorldSize(width=1000, height=500, cell_size=10, )
    add_resource!(world, ws)
    add_resource!(world, PWNModel.Rng(1))

    gs = PWNModel.InitGrids()
    PWNModel.initialize!(gs, world)

    s = PWNModel.InitTrees(km2_probability=1.0, tree_probability=0.9, damage_prevalence=0.0, beetle_prevalence=0.0)
    PWNModel.initialize!(s, world)

    grid = get_resource(world, PWNModel.TreeGrid)

    count = count_entities(Filter(world, (PWNModel.Position,)))
    @test count > 4400
    @test count < 4600

    (entities, positions) = first(Query(world, (PWNModel.Position,)))
    pos = positions[1]
    @test grid.grid[pos.x, pos.y] == entities[1]

    @test count_entities(Filter(world, (PWNModel.Damaged,))) == 0
end

@testset "InitTrees damaged" begin
    world = World(PWNModel.Position, PWNModel.Damaged, PWNModel.Colonized)

    ws = PWNModel.WorldSize(width=1000, height=500, cell_size=10, )
    add_resource!(world, ws)
    add_resource!(world, PWNModel.Rng(1))

    gs = PWNModel.InitGrids()
    PWNModel.initialize!(gs, world)

    s = PWNModel.InitTrees(km2_probability=1.0, tree_probability=1.0, damage_prevalence=0.2, beetle_prevalence=0.0)
    PWNModel.initialize!(s, world)

    grid = get_resource(world, PWNModel.TreeGrid)

    # tree_probability of 1.0 places exactly one tree per fine cell.
    total = count_entities(Filter(world, (PWNModel.Position,)))
    @test total == ws.width * ws.height

    damaged_count = 0
    for (entities, positions) in Query(world, (PWNModel.Position,); with=(PWNModel.Damaged,))
        for i in eachindex(entities)
            pos = positions[i]
            entity = entities[i]

            # The entity grid must point to the entity actually holding this position,
            # not to a stale duplicate.
            @test grid.grid[pos.x, pos.y] == entity

            damaged_count += 1
        end
    end

    expected = total * s.damage_prevalence
    @test abs(damaged_count - expected) < expected * 0.25
end

@testset "InitTrees colonized" begin
    world = World(PWNModel.Position, PWNModel.Damaged, PWNModel.Colonized)

    ws = PWNModel.WorldSize(width=1000, height=500, cell_size=10, )
    add_resource!(world, ws)
    add_resource!(world, PWNModel.Rng(1))

    gs = PWNModel.InitGrids()
    PWNModel.initialize!(gs, world)

    s = PWNModel.InitTrees(km2_probability=1.0, tree_probability=1.0, damage_prevalence=0.2, beetle_prevalence=0.3)
    PWNModel.initialize!(s, world)

    grid = get_resource(world, PWNModel.TreeGrid)
    total = count_entities(Filter(world, (PWNModel.Position,)))

    colonized_count = 0
    for (entities, positions) in Query(world, (PWNModel.Position,); with=(PWNModel.Colonized,))
        for i in eachindex(entities)
            pos = positions[i]
            entity = entities[i]

            # Colonized trees must also be marked damaged.
            @test has_components(world, entity, (PWNModel.Damaged,))
            @test grid.grid[pos.x, pos.y] == entity

            colonized_count += 1
        end
    end

    expected_colonized = total * s.damage_prevalence * s.beetle_prevalence
    @test abs(colonized_count - expected_colonized) < expected_colonized * 0.25

    damaged_only_count = 0
    for (entities,) in Query(world, (); with=(PWNModel.Damaged,), without=(PWNModel.Colonized,))
        damaged_only_count += length(entities)
    end

    expected_damaged_only = total * s.damage_prevalence * (1 - s.beetle_prevalence)
    @test abs(damaged_only_count - expected_damaged_only) < expected_damaged_only * 0.25
end

@testset "InitTrees forests whole km² blocks" begin
    world = World(PWNModel.Position, PWNModel.Damaged, PWNModel.Colonized)

    # 3.5 x 2 km: 4 x 2 blocks of 1 km², the last column only half as wide.
    ws = PWNModel.WorldSize(width=3500, height=2000, cell_size=10)
    add_resource!(world, ws)
    add_resource!(world, PWNModel.Rng(1))

    PWNModel.initialize!(PWNModel.InitGrids(), world)

    s = PWNModel.InitTrees(km2_probability=0.5, tree_probability=1.0, damage_prevalence=0.0, beetle_prevalence=0.0)
    PWNModel.initialize!(s, world)

    block_cells = 100 # 1000 m / 10 m
    counts = Dict{Tuple{Int,Int},Int}()
    for (_, positions) in Query(world, (PWNModel.Position,))
        for pos in positions
            block = (cld(pos.x, block_cells), cld(pos.y, block_cells))
            counts[block] = get(counts, block, 0) + 1
        end
    end

    # With tree_probability of 1.0, each block is either fully forested or empty.
    for ((bx, by), count) in counts
        w = min(block_cells, ws.width - (bx - 1) * block_cells)
        h = min(block_cells, ws.height - (by - 1) * block_cells)
        @test count == w * h
    end
end
