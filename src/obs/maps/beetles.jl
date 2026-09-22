
"""
Reports the number of live beetles per grid cell of `cell_size` (in
meters), aggregated over the base tree grid.
"""
mutable struct BeetlesMapObserver <: MatrixObserver
    const cell_size::Int

    _units_per_cell::Int
    _counts::Matrix{Float64}
end

"""
    BeetlesMapObserver(; cell_size)

  - `cell_size`: aggregation cell size in meters. Must be a multiple of the
    world's base cell size.
"""
function BeetlesMapObserver(; cell_size::Int)
    return BeetlesMapObserver(cell_size, 1, zeros(Float64, 0, 0))
end

function initialize!(o::BeetlesMapObserver, w::World)
    ws = get_resource(w, WorldSize)
    if o.cell_size % ws.cell_size != 0
        throw(ArgumentError("cell_size of the beetles map observer must be a multiple of the world's base cell size."))
    end
    o._units_per_cell = o.cell_size ÷ ws.cell_size

    width, height = cld(ws.width, o._units_per_cell), cld(ws.height, o._units_per_cell)
    o._counts = zeros(Float64, width, height)
end

function data(o::BeetlesMapObserver, w::World)::Matrix{Float64}
    fill!(o._counts, 0.0)

    for (_, positions) in Query(w, (BeetlePosition,))
        for pos in positions
            x, y = to_coords(o, pos.x, pos.y)
            o._counts[x, y] += 1
        end
    end

    return o._counts
end

# to_coords calculates (1-based) map-grid coords from (1-based) tree grid coords.
to_coords(o::BeetlesMapObserver, x::Int, y::Int) =
    (fld(x - 1, o._units_per_cell) + 1, fld(y - 1, o._units_per_cell) + 1)
