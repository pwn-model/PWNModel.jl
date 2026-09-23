function _setup_beetles_map_observer_world(width::Int, height::Int, cell_size::Int)
    world = World(PWNModel.BeetlePosition)
    add_resource!(world, PWNModel.WorldSize(width=width, height=height, cell_size=10, grid_cell_size=10))

    o = PWNModel.BeetlesMapObserver(cell_size=cell_size)
    PWNModel.initialize!(o, world)

    return world, o
end

@testset "BeetlesMapObserver rejects non-multiple cell_size" begin
    world = World()
    add_resource!(world, PWNModel.WorldSize(width=100, height=100, cell_size=10, grid_cell_size=10))

    o = PWNModel.BeetlesMapObserver(cell_size=25)
    @test_throws ArgumentError PWNModel.initialize!(o, world)
end

@testset "BeetlesMapObserver dims are the world size divided by cell_size" begin
    world, o = _setup_beetles_map_observer_world(100, 40, 30)

    @test size(PWNModel.data(o, world)) == (4, 2)
end

@testset "BeetlesMapObserver counts beetles per cell" begin
    world, o = _setup_beetles_map_observer_world(100, 100, 30)

    # Both land in map cell (1, 1) (tree-grid coords 1..3).
    new_entities!(world, 1, (PWNModel.BeetlePosition,)) do (_, positions)
        positions[1] = PWNModel.BeetlePosition(1, 1)
    end
    new_entities!(world, 1, (PWNModel.BeetlePosition,)) do (_, positions)
        positions[1] = PWNModel.BeetlePosition(2, 2)
    end

    # Lands in map cell (2, 2) (tree-grid coords 4..6).
    new_entities!(world, 1, (PWNModel.BeetlePosition,)) do (_, positions)
        positions[1] = PWNModel.BeetlePosition(4, 4)
    end

    values = PWNModel.data(o, world)

    @test values[1, 1] == 2.0
    @test values[2, 2] == 1.0
    @test sum(values) == 3.0
end

@testset "BeetlesMapObserver does not carry counts over between calls" begin
    world, o = _setup_beetles_map_observer_world(100, 100, 30)

    entity = nothing
    new_entities!(world, 1, (PWNModel.BeetlePosition,)) do (entities, positions)
        positions[1] = PWNModel.BeetlePosition(1, 1)
        entity = entities[1]
    end

    first = PWNModel.data(o, world)
    @test first[1, 1] == 1.0

    remove_entity!(world, entity)

    second = PWNModel.data(o, world)
    @test second[1, 1] == 0.0
end
