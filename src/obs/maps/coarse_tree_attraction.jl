"""
Reports the log of the coarse attraction grid computed by
[`CoarseTreeAttraction`](@ref) (healthy or damaged trees), for plotting
(e.g. with `plot.Image`, see `scripts/plot/image.jl`).
"""
mutable struct CoarseTreeAttractionMap <: MatrixObserver
    const damaged_trees::Bool

    _grid::Grid{Float64}
    _values::Matrix{Float64}
end

"""
    CoarseTreeAttractionMap(; damaged_trees)

  - `damaged_trees`: reports the damaged-tree coarse attraction grid instead
    of the healthy-tree one.
"""
function CoarseTreeAttractionMap(; damaged_trees::Bool)
    return CoarseTreeAttractionMap(damaged_trees, Grid(0, 0, 1, 0.0), zeros(Float64, 0, 0))
end

function initialize!(o::CoarseTreeAttractionMap, w::World)
    o._grid = if o.damaged_trees
        get_resource(w, DamagedTreeAttractionCoarse).grid
    else
        get_resource(w, HealthyTreeAttractionCoarse).grid
    end
    o._values = zeros(Float64, o._grid.width, o._grid.height)
end

function data(o::CoarseTreeAttractionMap, w::World)::Matrix{Float64}
    for x in 1:(o._grid.width), y in 1:(o._grid.height)
        o._values[x, y] = log(o._grid[x, y])
    end

    return o._values
end
