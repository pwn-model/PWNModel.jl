struct InitGrids <: System end

function initialize!(::InitGrids, w::World)
    ws = get_resource(w, WorldSize)

    add_resource!(w, TreeGrid(ws.width, ws.height, ws.cell_size))

    grid_width = ws.width ÷ ws.resolution
    grid_height = ws.height ÷ ws.resolution
    grid = Grid(grid_width, grid_height, ws.grid_cell_size, zero_entity)

    new_entities!(w, grid_width * grid_height, (GridCoords,)) do (entities, coords)
        i = 1
        for x in 1:grid_width, y in 1:grid_height
            coords[i] = GridCoords(x, y)
            grid[x, y] = entities[i]
            i += 1
        end
    end

    add_resource!(w, SpaceGrid(grid))
end
