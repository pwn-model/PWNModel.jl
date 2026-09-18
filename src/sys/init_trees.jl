Base.@kwdef struct InitTrees <: System
    tree_probability::Float64
    damage_prevalence::Float64
    beetle_prevalence::Float64
end

function initialize!(s::InitTrees, w::World)
    ws = get_resource(w, WorldSize)
    space = get_resource(w, SpaceGrid)
    trees = get_resource(w, TreeGrid)
    rng = get_resource(w, Rng)

    cells = Position[]
    sizehint!(cells, ws.resolution^2)
    damaged = Position[]
    sizehint!(damaged, ceil(Int, ws.resolution^2 * s.damage_prevalence * 1.2))
    colonized = Position[]
    sizehint!(colonized, ceil(Int, ws.resolution^2 * s.damage_prevalence * s.beetle_prevalence * 1.2))

    for x in 1:space.grid.width, y in 1:space.grid.height
        empty!(cells)
        empty!(damaged)
        empty!(colonized)
        cell = space.grid[x, y]

        for dx in 1:ws.resolution, dy in 1:ws.resolution
            if s.tree_probability < 1.0 && rand(rng) > s.tree_probability
                continue
            end
            xx = (x - 1) * ws.resolution + dx
            yy = (y - 1) * ws.resolution + dy
            r = rand(rng)
            if r < s.damage_prevalence
                if r < s.damage_prevalence * s.beetle_prevalence
                    push!(colonized, Position(xx, yy))
                else
                    push!(damaged, Position(xx, yy))
                end
            else
                push!(cells, Position(xx, yy))
            end
        end

        new_entities!(w, length(cells), (Position, InCell => cell)) do (entities, positions, _)
            for i in eachindex(entities)
                positions[i] = cells[i]
                trees.grid[cells[i].x, cells[i].y] = entities[i]
            end
        end

        new_entities!(w, length(damaged), (Position, InCell => cell, Damaged)) do (entities, positions, _, _)
            for i in eachindex(entities)
                positions[i] = damaged[i]
                trees.grid[damaged[i].x, damaged[i].y] = entities[i]
            end
        end

        new_entities!(
            w,
            length(colonized),
            (Position, InCell => cell, Damaged, Colonized),
        ) do (entities, positions, _, _, _)
            for i in eachindex(entities)
                positions[i] = colonized[i]
                trees.grid[colonized[i].x, colonized[i].y] = entities[i]
            end
        end
    end
end
