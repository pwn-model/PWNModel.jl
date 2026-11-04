"""
    TreeStand(; x_min, y_min, x_max, y_max, tree_probability, damage_prevalence, beetle_prevalence)

An axis-aligned rectangular forest stand for [`InitTreeStands`](@ref).

Bounds are in meters. A grid cell belongs to the stand if its center is
within `[x_min, x_max)` and `[y_min, y_max)`. The other parameters have the
same meaning as for [`InitTrees`](@ref) within a forested km² block.
"""
Base.@kwdef struct TreeStand
    x_min::Float64
    y_min::Float64
    x_max::Float64
    y_max::Float64
    tree_probability::Float64
    damage_prevalence::Float64
    beetle_prevalence::Float64
end

"""
    InitTreeStands(; stands)

Initializes trees and their damage and beetle colonization state, like
[`InitTrees`](@ref), but from a list of rectangular [`TreeStand`](@ref)s
with their own parameters instead of randomly forested km² blocks.

Where stands overlap, later stands overwrite earlier ones. Cells outside of
all stands remain empty.

In a config file, `stands` is a list of mappings with the fields of
`TreeStand`, without a `type` key.
"""
struct InitTreeStands <: System
    stands::Vector{TreeStand}
end

InitTreeStands(; stands::AbstractVector) = InitTreeStands(TreeStand[_tree_stand(s) for s in stands])

_tree_stand(s::TreeStand) = s
# From a config file: same checks for unknown and missing keys as for any other config entry.
_tree_stand(s::AbstractDict) = _construct(TreeStand, s)

# Range of 1-based cell indices along one axis whose centers are within [lo, hi).
function _stand_cell_range(lo::Float64, hi::Float64, cell_size::Int, n::Int)
    first = Int(clamp(ceil(lo / cell_size + 0.5), 1, n + 1))
    last = Int(clamp(ceil(hi / cell_size + 0.5), 1, n + 1)) - 1
    return first:last
end

function initialize!(s::InitTreeStands, w::World)
    trees = get_resource(w, TreeGrid)
    rng = get_resource(w, Rng)

    width, height, cs = trees.grid.width, trees.grid.height, trees.grid.cell_size

    # Index of the stand each cell belongs to, 0 for none. Later stands overwrite earlier ones.
    stand_index = Grid(width, height, cs, 0)
    for (i, stand) in enumerate(s.stands)
        for x in _stand_cell_range(stand.x_min, stand.x_max, cs, width),
            y in _stand_cell_range(stand.y_min, stand.y_max, cs, height)

            stand_index[x, y] = i
        end
    end

    cells = Position[]
    damaged = Position[]
    colonized = Position[]

    for x in 1:width, y in 1:height
        i = stand_index[x, y]
        if i == 0
            continue
        end
        stand = s.stands[i]
        if stand.tree_probability < 1.0 && rand(rng) > stand.tree_probability
            continue
        end
        r = rand(rng)
        if r < stand.damage_prevalence
            if r < stand.damage_prevalence * stand.beetle_prevalence
                push!(colonized, Position(x, y))
            else
                push!(damaged, Position(x, y))
            end
        else
            push!(cells, Position(x, y))
        end
    end

    new_entities!(w, length(cells), (Position,)) do (entities, positions)
        for i in eachindex(entities)
            positions[i] = cells[i]
            trees.grid[cells[i].x, cells[i].y] = entities[i]
        end
    end

    new_entities!(w, length(damaged), (Position, Damaged)) do (entities, positions, _)
        for i in eachindex(entities)
            positions[i] = damaged[i]
            trees.grid[damaged[i].x, damaged[i].y] = entities[i]
        end
    end

    new_entities!(w, length(colonized), (Position, Damaged, Colonized)) do (entities, positions, _, _)
        for i in eachindex(entities)
            positions[i] = colonized[i]
            trees.grid[colonized[i].x, colonized[i].y] = entities[i]
        end
    end
end
