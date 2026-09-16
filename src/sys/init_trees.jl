struct InitTrees <: System
    tree_probability::Float64
    damage_prevalence::Float64
end

InitTrees(tree_probability::Float64) = InitTrees(tree_probability, 0.0)

function initialize!(s::InitTrees, w::World)
    ws = get_resource(w, WorldSize)
    space = get_resource(w, SpaceGrid)
    trees = get_resource(w, EntityGrid)
    rng = get_resource(w, Rng)

    cells = Position[]
    sizehint!(cells, ws.resolution^2)
    damaged = Position[]
    sizehint!(damaged, ceil(Int, ws.resolution^2 * s.damage_prevalence * 1.2))

    for x in 1:space.grid.width, y in 1:space.grid.height
        empty!(cells)
        empty!(damaged)
        cell = space.grid[x, y]

        for dx in 1:ws.resolution, dy in 1:ws.resolution
            if s.tree_probability < 1.0 && rand(rng) > s.tree_probability
                continue
            end
            xx = (x - 1) * ws.resolution + dx
            yy = (y - 1) * ws.resolution + dy
            if rand(rng) < s.damage_prevalence
                push!(damaged, Position(xx, yy))
            else
                push!(cells, Position(xx, yy))
            end
        end

        new_entities!(w, length(cells), (Position, InCell => cell)) do (entities, positions, _)
            for i in eachindex(entities)
                positions[i] = cells[i]
                trees[cells[i].x, cells[i].y] = entities[i]
            end
        end

        new_entities!(w, length(damaged), (Position, InCell => cell, Damaged)) do (entities, positions, _, _)
            for i in eachindex(entities)
                positions[i] = damaged[i]
                trees[damaged[i].x, damaged[i].y] = entities[i]
            end
        end
    end
end
