struct InitGrids <: System end

function initialize!(::InitGrids, w::World)
    ws = get_resource(w, WorldSize)
    if ws.width % ws.resolution != 0 || ws.height % ws.resolution != 0
        throw(
            ArgumentError(
                "world size ($(ws.width) x $(ws.height)) must be a multiple of the grid resolution ($(ws.resolution))",
            ),
        )
    end

    add_resource!(w, EntityGrid(ws.width, ws.height))

    grid_width = ws.width ÷ ws.resolution
    grid_height = ws.height ÷ ws.resolution
    grid = EntityGrid(grid_width, grid_height)

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
