struct InitGrids <: System end

function initialize!(::InitGrids, w::World)
    ws = get_resource(w, WorldSize)

    add_resource!(w, EntityGrid(ws.width, ws.height))

    grid_width = cld(ws.width, ws.resolution)
    grid_height = cld(ws.height, ws.resolution)
    add_resource!(w, SpaceGrid(EntityGrid(grid_width, grid_height)))
end
