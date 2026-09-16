@testset "InitTrees" begin
    world = World(PWNModel.Position, PWNModel.GridCoords, Relation{PWNModel.InCell})

    ws = PWNModel.WorldSize(100, 50, 10)
    add_resource!(world, ws)
    add_resource!(world, PWNModel.Rng(1))

    gs = PWNModel.InitGrids()
    PWNModel.initialize!(gs, world)

    s = PWNModel.InitTrees(0.9)
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
end
