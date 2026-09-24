@testset "WorldStats: entities, archetypes and memory" begin
    world = World(Position, Damaged, Colonized, Relation{InCell})

    empty = world_stats(world)
    @test empty.entities.used == 0
    @test empty.memory_used == 0
    @test length(empty.component_types) == 4
    @test !empty.locked

    new_entities!(world, 10, (Position(1, 1),))
    new_entities!(world, 5, (Position(2, 2), Damaged()))
    removed = new_entity!(world, (Position(3, 3), Damaged()))
    remove_entity!(world, removed)

    stats = world_stats(world)
    @test stats.entities.used == 15
    @test stats.entities.recycled == 1
    @test stats.entities.total == 16
    @test stats.entities.capacity >= stats.entities.total

    by_types = Dict(Set(a.component_types) => a for a in stats.archetypes)

    pos = by_types[Set([Position])]
    @test pos.size == 10
    @test pos.capacity >= pos.size
    @test pos.memory_per_entity == sizeof(Entity) + sizeof(Position)
    @test pos.memory_used == 10 * pos.memory_per_entity
    @test pos.num_relations == 0
    @test length(pos.tables) == 1

    dam = by_types[Set([Position, Damaged])]
    @test dam.size == 5

    @test stats.memory_used == sum(a -> a.memory_used, stats.archetypes)
    @test stats.memory >= stats.memory_used
    @test stats.nodes >= length(stats.archetypes)

    cell = new_entity!(world, ())
    new_entity!(world, (Position(4, 4), InCell() => cell))
    rel = only(a for a in world_stats(world).archetypes if a.num_relations > 0)
    @test rel.size == 1
    @test length(rel.tables) == 1
end
