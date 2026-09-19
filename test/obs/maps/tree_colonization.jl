function _setup_map_observer_world(width::Int, height::Int, cell_size::Int)
    world = World(PWNModel.Position, PWNModel.Damaged, PWNModel.Colonized)
    add_resource!(world, PWNModel.WorldSize(width=width, height=height, cell_size=10, grid_cell_size=10))

    o = PWNModel.TreeColonizationMapObserver(cell_size=cell_size)
    PWNModel.initialize!(o, world)

    return world, o
end

@testset "TreeColonizationMapObserver rejects non-multiple cell_size" begin
    world = World()
    add_resource!(world, PWNModel.WorldSize(width=100, height=100, cell_size=10, grid_cell_size=10))

    o = PWNModel.TreeColonizationMapObserver(cell_size=25)
    @test_throws ArgumentError PWNModel.initialize!(o, world)
end

@testset "TreeColonizationMapObserver dims are the world size divided by cell_size" begin
    world, o = _setup_map_observer_world(100, 40, 30)

    @test size(PWNModel.data(o, world)) == (4, 2)
end

@testset "TreeColonizationMapObserver counts colonized trees per cell" begin
    world, o = _setup_map_observer_world(100, 100, 30)

    # Both land in map cell (1, 1) (tree-grid coords 1..3).
    new_entities!(world, 1, (PWNModel.Position, PWNModel.Colonized)) do (_, positions, _)
        positions[1] = PWNModel.Position(1, 1)
    end
    new_entities!(world, 1, (PWNModel.Position, PWNModel.Colonized)) do (_, positions, _)
        positions[1] = PWNModel.Position(2, 2)
    end

    # Lands in map cell (2, 2) (tree-grid coords 4..6).
    new_entities!(world, 1, (PWNModel.Position, PWNModel.Colonized)) do (_, positions, _)
        positions[1] = PWNModel.Position(4, 4)
    end

    # Damaged but not colonized: must not be counted.
    new_entities!(world, 1, (PWNModel.Position, PWNModel.Damaged)) do (_, positions, _)
        positions[1] = PWNModel.Position(9, 9)
    end

    values = PWNModel.data(o, world)

    @test values[1, 1] == 2.0
    @test values[2, 2] == 1.0
    @test sum(values) == 3.0
end

@testset "TreeColonizationMapObserver does not carry counts over between calls" begin
    world, o = _setup_map_observer_world(100, 100, 30)

    entity = nothing
    new_entities!(world, 1, (PWNModel.Position, PWNModel.Colonized)) do (entities, positions, _)
        positions[1] = PWNModel.Position(1, 1)
        entity = entities[1]
    end

    first = PWNModel.data(o, world)
    @test first[1, 1] == 1.0

    remove_components!(world, entity, (PWNModel.Colonized,))

    second = PWNModel.data(o, world)
    @test second[1, 1] == 0.0
end
