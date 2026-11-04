function _setup_source_map_observer_world(width::Int, height::Int; damaged_trees::Bool=false)
    world = World()
    source = Grid(width, height, 10, NO_CELL)
    attraction = Grid(width, height, 10, 0.0)
    presence = Grid(width, height, 10, false)
    if damaged_trees
        add_resource!(world, PWNModel.DamagedTreeAttraction(attraction, presence, source))
    else
        add_resource!(world, PWNModel.HealthyTreeAttraction(attraction, presence, source))
    end

    o = PWNModel.TreeAttractionSourceMap(damaged_trees=damaged_trees)
    PWNModel.initialize!(o, world)

    return world, o, source
end

@testset "TreeAttractionSourceMap dims match the source grid" begin
    world, o, _ = _setup_source_map_observer_world(5, 3)

    @test size(PWNModel.data(o, world)) == (5, 3)
end

@testset "TreeAttractionSourceMap reports NaN where there is no source" begin
    world, o, _ = _setup_source_map_observer_world(4, 4)

    @test all(isnan, PWNModel.data(o, world))
end

@testset "TreeAttractionSourceMap maps sources to stable values in [0, 1)" begin
    for damaged_trees in (false, true)
        world, o, source = _setup_source_map_observer_world(4, 4; damaged_trees=damaged_trees)

        a = cell_index(source, 1, 1)
        b = cell_index(source, 2, 1)
        source[1, 1] = a
        source[1, 2] = a
        source[2, 1] = b
        source[2, 2] = b

        values = PWNModel.data(o, world)

        @test values[1, 1] == values[1, 2]
        @test values[2, 1] == values[2, 2]
        @test values[1, 1] != values[2, 1]
        @test 0.0 <= values[1, 1] < 1.0
        @test 0.0 <= values[2, 1] < 1.0
        @test isnan(values[3, 3])

        # Updated in place on each call.
        source[3, 3] = a
        @test PWNModel.data(o, world)[3, 3] == values[1, 1]
    end
end

@testset "TreeAttractionSourceMap scatters neighbouring indices" begin
    # Consecutive indices must not map to similar values, or neighbouring
    # patches would get near-identical colors.
    values = [PWNModel._hash_to_unit(UInt32(i)) for i in 1:1000]
    @test all(v -> 0.0 <= v < 1.0, values)
    @test length(unique(values)) == 1000
    @test sum(abs.(diff(values))) / 999 > 0.25
end
