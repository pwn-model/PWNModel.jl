@testset "InitTrees" begin
    world =
        World(PWNModel.Position, PWNModel.GridCoords, PWNModel.Damaged, PWNModel.Colonized, Relation{PWNModel.InCell})

    ws = PWNModel.WorldSize(100, 50, 10)
    add_resource!(world, ws)
    add_resource!(world, PWNModel.Rng(1))

    gs = PWNModel.InitGrids()
    PWNModel.initialize!(gs, world)

    s = PWNModel.InitTrees(tree_probability=0.9, damage_prevalence=0.0, beetle_prevalence=0.0)
    PWNModel.initialize!(s, world)

    grid = get_resource(world, PWNModel.EntityGrid)
    space = get_resource(world, PWNModel.SpaceGrid)

    count = count_entities(Filter(world, (PWNModel.Position,)))
    @test count > 4400
    @test count < 4600

    (entities, positions) = first(Query(world, (PWNModel.Position,)))
    pos = positions[1]
    entity = entities[1]
    @test !is_zero(grid[pos.x, pos.y])

    cell = get_relations(world, entity, (PWNModel.InCell,))[1]
    @test space.grid[cld(pos.x, ws.resolution), cld(pos.y, ws.resolution)] == cell

    @test count_entities(Filter(world, (PWNModel.Damaged,))) == 0
end

@testset "InitTrees damaged" begin
    world =
        World(PWNModel.Position, PWNModel.GridCoords, PWNModel.Damaged, PWNModel.Colonized, Relation{PWNModel.InCell})

    ws = PWNModel.WorldSize(100, 50, 10)
    add_resource!(world, ws)
    add_resource!(world, PWNModel.Rng(1))

    gs = PWNModel.InitGrids()
    PWNModel.initialize!(gs, world)

    s = PWNModel.InitTrees(tree_probability=1.0, damage_prevalence=0.2, beetle_prevalence=0.0)
    PWNModel.initialize!(s, world)

    grid = get_resource(world, PWNModel.EntityGrid)
    space = get_resource(world, PWNModel.SpaceGrid)

    # tree_probability of 1.0 places exactly one tree per fine cell.
    total = count_entities(Filter(world, (PWNModel.Position,)))
    @test total == ws.width * ws.height

    damaged_count = 0
    for (entities, positions) in Query(world, (PWNModel.Position,); with=(PWNModel.Damaged,))
        for i in eachindex(entities)
            pos = positions[i]
            entity = entities[i]

            # The entity grid must point to the entity actually holding this position,
            # not to a stale duplicate from another coarse cell.
            @test grid[pos.x, pos.y] == entity

            # The InCell relation must match the coarse cell the position actually falls into.
            cell = get_relations(world, entity, (PWNModel.InCell,))[1]
            @test space.grid[cld(pos.x, ws.resolution), cld(pos.y, ws.resolution)] == cell

            damaged_count += 1
        end
    end

    expected = total * s.damage_prevalence
    @test abs(damaged_count - expected) < expected * 0.25
end

@testset "InitTrees colonized" begin
    world =
        World(PWNModel.Position, PWNModel.GridCoords, PWNModel.Damaged, PWNModel.Colonized, Relation{PWNModel.InCell})

    ws = PWNModel.WorldSize(100, 50, 10)
    add_resource!(world, ws)
    add_resource!(world, PWNModel.Rng(1))

    gs = PWNModel.InitGrids()
    PWNModel.initialize!(gs, world)

    s = PWNModel.InitTrees(tree_probability=1.0, damage_prevalence=0.2, beetle_prevalence=0.3)
    PWNModel.initialize!(s, world)

    grid = get_resource(world, PWNModel.EntityGrid)
    total = count_entities(Filter(world, (PWNModel.Position,)))

    colonized_count = 0
    for (entities, positions) in Query(world, (PWNModel.Position,); with=(PWNModel.Colonized,))
        for i in eachindex(entities)
            pos = positions[i]
            entity = entities[i]

            # Colonized trees must also be marked damaged.
            @test has_components(world, entity, (PWNModel.Damaged,))
            @test grid[pos.x, pos.y] == entity

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
