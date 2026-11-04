"""
Reports the source cell of the attraction grid computed by
[`TreeAttraction`](@ref) (healthy or damaged trees), i.e. the tree cell each
cell's attraction value was propagated from, for plotting (e.g. with
`plot.Image`, see `scripts/plot/image.jl`).

To make cells sharing a source show up as patches of one color, with
neighbouring patches clearly distinct, each source's cell index (see
[`cell_index`](@ref)) is scrambled by an integer hash into a pseudo-random
value in `[0, 1)`. Plot it with `colorrange: [0.0, 1.0]` and a colormap with
many distinct colors, e.g. `glasbey_hv_n256` or `turbo`. Cells without any
source are reported as `NaN`, which `plot.Image` leaves blank.
"""
mutable struct TreeAttractionSourceMap <: MatrixObserver
    const damaged_trees::Bool

    _grid::Grid{UInt32}
    _values::Matrix{Float64}
end

"""
    TreeAttractionSourceMap(; damaged_trees=false)

  - `damaged_trees`: reports the damaged-tree attraction sources instead of
    the healthy-tree ones.
"""
function TreeAttractionSourceMap(; damaged_trees::Bool=false)
    return TreeAttractionSourceMap(damaged_trees, Grid(0, 0, 1, NO_CELL), zeros(Float64, 0, 0))
end

function initialize!(o::TreeAttractionSourceMap, w::World)
    o._grid = if o.damaged_trees
        get_resource(w, DamagedTreeAttraction).source
    else
        get_resource(w, HealthyTreeAttraction).source
    end
    o._values = zeros(Float64, o._grid.width, o._grid.height)
end

function data(o::TreeAttractionSourceMap, w::World)::Matrix{Float64}
    for x in 1:(o._grid.width), y in 1:(o._grid.height)
        source = o._grid[x, y]
        o._values[x, y] = source == NO_CELL ? NaN : _hash_to_unit(source)
    end

    return o._values
end

# _hash_to_unit maps a cell index to a pseudo-random Float64 in [0, 1), via
# the SplitMix64 finalizer (so that consecutive indices, i.e. neighbouring
# cells, get unrelated values) and the top 53 bits of the result.
function _hash_to_unit(index::UInt32)::Float64
    z = UInt64(index) + 0x9e3779b97f4a7c15
    z = (z ⊻ (z >> 30)) * 0xbf58476d1ce4e5b9
    z = (z ⊻ (z >> 27)) * 0x94d049bb133111eb
    z = z ⊻ (z >> 31)
    return Float64(z >> 11) * 0x1.0p-53
end
