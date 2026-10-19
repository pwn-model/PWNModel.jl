struct InitGrids <: System end

function initialize!(::InitGrids, w::World)
    ws = get_resource(w, WorldSize)

    add_resource!(w, TreeGrid(ws.width, ws.height, ws.cell_size))
end
