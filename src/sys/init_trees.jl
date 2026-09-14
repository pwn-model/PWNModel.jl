struct InitTrees <: System
    tree_probability::Float64
end

function initialize!(s::InitTrees, w::World)
    grid = get_resource(w, TreeGrid)

    positions = [
        Position(x, y)
        for x in 1:grid.width, y in 1:grid.height
        if s.tree_probability >= 1 || rand() < s.tree_probability
    ]

    new_entities!(w, length(positions), (Position,)) do (entities, comp_positions)
        for i in eachindex(entities)
            pos = positions[i]
            comp_positions[i] = pos
            grid[pos.x, pos.y] = entities[i]
        end
    end
end