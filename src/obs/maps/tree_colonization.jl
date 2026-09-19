
"""
Reports the number of colonized trees per grid cell of `cell_size` (in
meters), aggregated over the base tree grid.

Mirrors the [`Colonization`](@ref) system's density aggregation, but exposed
as a [`MatrixObserver`](@ref) for plotting (e.g. with `plot.Image`, see
`scripts/plot/image.jl`).
"""
mutable struct TreeColonizationMapObserver <: MatrixObserver
    const cell_size::Int

    _units_per_cell::Int
    _counts::Matrix{Float64}
end

"""
    TreeColonizationMapObserver(; cell_size)

  - `cell_size`: aggregation cell size in meters. Must be a multiple of the
    world's base cell size.
"""
function TreeColonizationMapObserver(; cell_size::Int)
    return TreeColonizationMapObserver(cell_size, 1, zeros(Float64, 0, 0))
end

function initialize!(o::TreeColonizationMapObserver, w::World)
    ws = get_resource(w, WorldSize)
    if o.cell_size % ws.cell_size != 0
        throw(
            ArgumentError(
                "cell_size of the tree colonization map observer must be a multiple of the world's base cell size.",
            ),
        )
    end
    o._units_per_cell = o.cell_size ÷ ws.cell_size

    width, height = cld(ws.width, o._units_per_cell), cld(ws.height, o._units_per_cell)
    o._counts = zeros(Float64, width, height)
end

function data(o::TreeColonizationMapObserver, w::World)::Matrix{Float64}
    fill!(o._counts, 0.0)

    for (_, positions) in Query(w, (Position,); with=(Colonized,))
        for pos in positions
            x, y = to_coords(o, pos.x, pos.y)
            o._counts[x, y] += 1
        end
    end

    return o._counts
end

# to_coords calculates (1-based) map-grid coords from (1-based) tree grid coords.
to_coords(o::TreeColonizationMapObserver, x::Int, y::Int) =
    (fld(x - 1, o._units_per_cell) + 1, fld(y - 1, o._units_per_cell) + 1)
