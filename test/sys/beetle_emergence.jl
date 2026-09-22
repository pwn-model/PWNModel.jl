function _new_beetle_emergence_world()
    return World(
        PWNModel.Position, PWNModel.Damaged, PWNModel.Infected,
        PWNModel.BeetlePosition, PWNModel.EmergenceTick, PWNModel.LifeExpectancy,
    )
end

@testset "BeetleEmergence skips wrong tick of year" begin
    world = _new_beetle_emergence_world()
    add_resource!(world, PWNModel.Time(0, 1, 0))
    add_resource!(world, PWNModel.Rng(1))

    s = PWNModel.BeetleEmergence(tick_of_year=0, beetles_per_tree=5, life_expectancy=10.0)

    new_entities!(world, 1, (PWNModel.Position, PWNModel.Damaged, PWNModel.Infected)) do (_, positions, _, infected)
        positions[1] = PWNModel.Position(1, 2)
        infected[1] = PWNModel.Infected(0)
    end

    PWNModel.update!(s, world)

    @test count_entities(Filter(world, (PWNModel.BeetlePosition,))) == 0
end

@testset "BeetleEmergence creates beetles from source trees" begin
    world = _new_beetle_emergence_world()
    time = add_resource!(world, PWNModel.Time(20, 3, 0))
    add_resource!(world, PWNModel.Rng(1))

    s = PWNModel.BeetleEmergence(tick_of_year=3, beetles_per_tree=4, life_expectancy=10.0)

    new_entities!(world, 2, (PWNModel.Position, PWNModel.Damaged, PWNModel.Infected)) do (_, positions, _, infected)
        positions[1] = PWNModel.Position(1, 2)
        positions[2] = PWNModel.Position(5, 6)
        infected[1] = PWNModel.Infected(0)
        infected[2] = PWNModel.Infected(0)
    end

    PWNModel.update!(s, world)

    counts = Dict{Tuple{Int,Int},Int}()
    total = 0
    for (_, beetle_positions, emergence_ticks, life_expectancies) in
        Query(world, (PWNModel.BeetlePosition, PWNModel.EmergenceTick, PWNModel.LifeExpectancy))
        for i in eachindex(beetle_positions)
            bp = beetle_positions[i]
            key = (bp.x, bp.y)
            counts[key] = get(counts, key, 0) + 1
            @test emergence_ticks[i].tick_of_emergence == time.tick
            # randexp is never negative, so death can never precede the
            # current tick.
            @test life_expectancies[i].tick_of_death >= time.tick
            total += 1
        end
    end

    @test total == 8
    @test counts[(1, 2)] == 4 # each source tree must emerge exactly beetles_per_tree beetles
    @test counts[(5, 6)] == 4
end

@testset "BeetleEmergence requires both Damaged and Infected" begin
    world = _new_beetle_emergence_world()
    add_resource!(world, PWNModel.Time(0, 3, 0))
    add_resource!(world, PWNModel.Rng(1))

    s = PWNModel.BeetleEmergence(tick_of_year=3, beetles_per_tree=5, life_expectancy=10.0)

    new_entities!(world, 1, (PWNModel.Position, PWNModel.Damaged)) do (_, positions, _)
        positions[1] = PWNModel.Position(1, 1)
    end
    new_entities!(world, 1, (PWNModel.Position, PWNModel.Infected)) do (_, positions, infected)
        positions[1] = PWNModel.Position(2, 2)
        infected[1] = PWNModel.Infected(0)
    end

    PWNModel.update!(s, world)

    # Only trees with both Damaged and Infected are emergence sources.
    @test count_entities(Filter(world, (PWNModel.BeetlePosition,))) == 0
end

@testset "BeetleEmergence no source trees is a no-op" begin
    world = _new_beetle_emergence_world()
    add_resource!(world, PWNModel.Time(0, 3, 0))
    add_resource!(world, PWNModel.Rng(1))

    s = PWNModel.BeetleEmergence(tick_of_year=3, beetles_per_tree=5, life_expectancy=10.0)

    PWNModel.update!(s, world)

    @test count_entities(Filter(world, (PWNModel.BeetlePosition,))) == 0
end

@testset "BeetleEmergence source tree buffer does not leak across ticks" begin
    world = _new_beetle_emergence_world()
    add_resource!(world, PWNModel.Time(0, 3, 0))
    add_resource!(world, PWNModel.Rng(1))

    s = PWNModel.BeetleEmergence(tick_of_year=3, beetles_per_tree=2, life_expectancy=10.0)

    new_entities!(world, 1, (PWNModel.Position, PWNModel.Damaged, PWNModel.Infected)) do (_, positions, _, infected)
        positions[1] = PWNModel.Position(1, 1)
        infected[1] = PWNModel.Infected(0)
    end

    PWNModel.update!(s, world)
    PWNModel.update!(s, world)

    # The reused _source_trees buffer must be cleared after each update!; if
    # it weren't, the second tick's query would append onto the first
    # tick's leftover entries and over-count emerged beetles.
    @test count_entities(Filter(world, (PWNModel.BeetlePosition,))) == 4
end
