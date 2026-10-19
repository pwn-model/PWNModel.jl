Base.@kwdef struct InitTrees <: System
    km2_probability::Float64
    tree_probability::Float64
    damage_prevalence::Float64
    beetle_prevalence::Float64
end

function initialize!(s::InitTrees, w::World)
    trees = get_resource(w, TreeGrid)
    rng = get_resource(w, Rng)

    # Ties away from zero, like Go's math.Round.
    cells_per_km2 = round(Int, 1000.0 / trees.grid.cell_size, RoundNearestTiesAway)
    cells_size = trees.grid.cell_size * cells_per_km2

    num_cells = trees.grid.width * trees.grid.height
    cells = Position[]
    sizehint!(cells, num_cells)
    damaged = Position[]
    sizehint!(damaged, ceil(Int, num_cells * s.damage_prevalence * 1.2))
    colonized = Position[]
    sizehint!(colonized, ceil(Int, num_cells * s.damage_prevalence * s.beetle_prevalence * 1.2))

    hectares = Grid(cld(trees.grid.width, cells_per_km2), cld(trees.grid.height, cells_per_km2), cells_size, false)
    for x in 1:hectares.width, y in 1:hectares.height
        if rand(rng) < s.km2_probability
            hectares[x, y] = true
        end
    end

    for x in 1:trees.grid.width, y in 1:trees.grid.height
        if !hectares[cld(x, cells_per_km2), cld(y, cells_per_km2)]
            continue
        end
        if s.tree_probability < 1.0 && rand(rng) > s.tree_probability
            continue
        end
        r = rand(rng)
        if r < s.damage_prevalence
            if r < s.damage_prevalence * s.beetle_prevalence
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
