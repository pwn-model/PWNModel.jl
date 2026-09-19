@testset "DamageTrees skips wrong tick of year" begin
    world = World(PWNModel.Position, PWNModel.Damaged)
    time = add_resource!(world, PWNModel.Time(0, 1, 0))
    add_resource!(world, PWNModel.Rng(1))

    s = PWNModel.DamageTrees(tick_of_year=0, damage_probability=1.0, removal_probability=1.0)

    healthy = nothing
    new_entities!(world, 1, (PWNModel.Position,)) do (entities, _)
        healthy = entities[1]
    end
    damaged = nothing
    new_entities!(world, 1, (PWNModel.Position, PWNModel.Damaged)) do (entities, _, _)
        damaged = entities[1]
    end

    PWNModel.update!(s, world)

    @test !has_components(world, healthy, (PWNModel.Damaged,))
    @test is_alive(world, damaged)
end

@testset "DamageTrees damages all with probability one" begin
    world = World(PWNModel.Position, PWNModel.Damaged)
    add_resource!(world, PWNModel.Time(0, 3, 0))
    add_resource!(world, PWNModel.Rng(1))
    add_resource!(world, PWNModel.TreeGrid(1, 1, 10))

    s = PWNModel.DamageTrees(tick_of_year=3, damage_probability=1.0, removal_probability=0.0)

    entities = Entity[]
    new_entities!(world, 5, (PWNModel.Position,)) do (es, positions)
        for i in eachindex(es)
            positions[i] = PWNModel.Position(i, 0)
        end
        append!(entities, es)
    end

    PWNModel.update!(s, world)

    for e in entities
        @test has_components(world, e, (PWNModel.Damaged,))
    end
end

@testset "DamageTrees zero probabilities is a no-op" begin
    world = World(PWNModel.Position, PWNModel.Damaged)
    add_resource!(world, PWNModel.Time(0, 3, 0))
    add_resource!(world, PWNModel.Rng(1))
    add_resource!(world, PWNModel.TreeGrid(1, 1, 10))

    s = PWNModel.DamageTrees(tick_of_year=3, damage_probability=0.0, removal_probability=0.0)

    healthy = nothing
    new_entities!(world, 1, (PWNModel.Position,)) do (entities, _)
        healthy = entities[1]
    end
    damaged = nothing
    new_entities!(world, 1, (PWNModel.Position, PWNModel.Damaged)) do (entities, _, _)
        damaged = entities[1]
    end

    PWNModel.update!(s, world)

    @test !has_components(world, healthy, (PWNModel.Damaged,))
    @test is_alive(world, damaged)
    @test has_components(world, damaged, (PWNModel.Damaged,))
end

@testset "DamageTrees removes all with probability one" begin
    world = World(PWNModel.Position, PWNModel.Damaged)
    add_resource!(world, PWNModel.Time(0, 3, 0))
    add_resource!(world, PWNModel.Rng(1))
    grid = PWNModel.TreeGrid(5, 1, 10)
    add_resource!(world, grid)

    s = PWNModel.DamageTrees(tick_of_year=3, damage_probability=0.0, removal_probability=1.0)

    entities = Entity[]
    positions = PWNModel.Position[]
    new_entities!(world, 5, (PWNModel.Position, PWNModel.Damaged)) do (es, ps, _)
        for i in eachindex(es)
            ps[i] = PWNModel.Position(i, 1)
            grid.grid[i, 1] = es[i]
        end
        append!(entities, es)
        append!(positions, ps)
    end

    PWNModel.update!(s, world)

    for (e, pos) in zip(entities, positions)
        @test !is_alive(world, e)
        @test is_zero(grid.grid[pos.x, pos.y])
    end
end

@testset "DamageTrees requires Position to damage" begin
    world = World(PWNModel.Position, PWNModel.Damaged)
    add_resource!(world, PWNModel.Time(0, 3, 0))
    add_resource!(world, PWNModel.Rng(1))
    add_resource!(world, PWNModel.TreeGrid(1, 1, 10))

    s = PWNModel.DamageTrees(tick_of_year=3, damage_probability=1.0, removal_probability=0.0)

    # An entity without Position is ineligible for damage, regardless of
    # damage_probability.
    no_pos = new_entity!(world, ())

    PWNModel.update!(s, world)

    @test !has_components(world, no_pos, (PWNModel.Damaged,))
end
