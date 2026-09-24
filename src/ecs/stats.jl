"""
Statistics of a single table (a set of entities with the same components and
relation targets) of an [`ArchetypeStats`](@ref).
"""
struct TableStats
    # Number of entities in the table.
    size::Int
    # Number of entities the table has reserved memory for.
    capacity::Int
    # Memory reserved for the table's entities and components, in bytes.
    memory::Int
    # Memory used by the table's entities and components, in bytes.
    memory_used::Int
end

"""
Statistics of a single archetype (a unique set of component types) of a
[`WorldStats`](@ref).
"""
struct ArchetypeStats
    # The archetype's component types.
    component_types::Vector{DataType}
    # Statistics of the archetype's active tables.
    tables::Vector{TableStats}
    # Number of inactive tables, available for reuse (relation archetypes only).
    free_tables::Int
    # Number of relation components of the archetype.
    num_relations::Int
    # Number of entities in all tables of the archetype.
    size::Int
    # Sum of the capacity of all tables of the archetype.
    capacity::Int
    # Memory reserved for the archetype's entities and components, in bytes.
    memory::Int
    # Memory used by the archetype's entities and components, in bytes.
    memory_used::Int
    # Memory per entity (entity ID plus components), in bytes.
    memory_per_entity::Int
end

"""
Entity statistics of a [`WorldStats`](@ref).
"""
struct EntityStats
    # Number of alive entities.
    used::Int
    # Number of entity IDs available for recycling.
    recycled::Int
    # Total number of entity IDs ever allocated (used + recycled).
    total::Int
    # Capacity of the entity ID pool.
    capacity::Int
end

"""
    WorldStats

Statistics of a `World`: its component types, archetypes and their tables,
entities and memory. Created via [`world_stats`](@ref).

Mirrors `stats.World` from the sibling Go implementation's
`github.com/mlange-42/ark/ecs/stats` package, which Ark.jl has no equivalent
of. Instead of being computed by Ark itself, it is assembled from Ark.jl's
*internal* data structures, so it may break with any Ark.jl version bump;
the tests in `test/ecs/stats.jl` are there to catch that.

Memory is estimated as the entities column's capacity times each entity's
(ID plus components) size, instead of measuring every component column
individually, so it ignores differences between storage modes and any
per-column capacity differences.
"""
struct WorldStats
    # Component types, indexed by component ID.
    component_types::Vector{DataType}
    # Archetype statistics, indexed by archetype ID.
    archetypes::Vector{ArchetypeStats}
    # Number of archetype graph nodes, including those without an archetype.
    nodes::Int
    # Entity statistics.
    entities::EntityStats
    # Memory reserved for entities and components, in bytes.
    memory::Int
    # Memory used by entities and components, in bytes.
    memory_used::Int
    # Number of cached (registered) filters.
    cached_filters::Int
    # Whether the world is currently locked (e.g. by an active query).
    locked::Bool
end

# Number of elements v has reserved memory for, without reallocating.
_capacity(v::Vector) = length(v.ref.mem) - Base.memoryrefoffset(v.ref) + 1

"""
    world_stats(world::World) -> WorldStats

Collects statistics of `world`. See [`WorldStats`](@ref).
"""
function world_stats(world::World)
    registry = world._registry
    component_types = copy(registry.types)

    archetypes = ArchetypeStats[]
    memory = 0
    memory_used = 0
    for arch in world._archetypes
        types = DataType[registry.types[id] for id in arch.components]
        per_entity = sizeof(Entity) + sum(sizeof, types; init=0)

        tables = TableStats[]
        for table_id in arch.tables.ids
            entities = world._tables[table_id].entities._data
            size = length(entities)
            cap = _capacity(entities)
            push!(tables, TableStats(size, cap, cap * per_entity, size * per_entity))
        end

        size = sum(t -> t.size, tables; init=0)
        cap = sum(t -> t.capacity, tables; init=0)
        arch_memory = cap * per_entity
        arch_memory_used = size * per_entity
        memory += arch_memory
        memory_used += arch_memory_used

        push!(
            archetypes,
            ArchetypeStats(
                types, tables, length(arch.free_tables), Int(arch.num_relations),
                size, cap, arch_memory, arch_memory_used, per_entity,
            ),
        )
    end

    # The pool's first entry is the reserved zero entity, not a usable one.
    pool = world._entity_pool
    total = length(pool.entities) - 1
    used = sum(a -> a.size, archetypes; init=0)
    entities = EntityStats(used, total - used, total, _capacity(pool.entities) - 1)

    cached_filters = length(world._cache.filters) - length(world._cache.free_indices)

    return WorldStats(
        component_types, archetypes, length(world._graph.nodes), entities,
        memory, memory_used, cached_filters, is_locked(world),
    )
end
