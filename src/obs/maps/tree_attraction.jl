"""
Reports the attraction grid computed by [`TreeAttraction`](@ref) (healthy or
damaged trees), for plotting (e.g. with `plot.Image`, see
`scripts/plot/image.jl`).
"""
mutable struct TreeAttractionMapObserver <: MatrixObserver
    const damaged_trees::Bool

    _grid::Grid{Float64}
    _values::Matrix{Float64}
end

"""
    TreeAttractionMapObserver(; damaged_trees=false)

  - `damaged_trees`: reports the damaged-tree attraction grid instead of the
    healthy-tree one.
"""
function TreeAttractionMapObserver(; damaged_trees::Bool=false)
    return TreeAttractionMapObserver(damaged_trees, Grid(0, 0, 1, 0.0), zeros(Float64, 0, 0))
end

function initialize!(o::TreeAttractionMapObserver, w::World)
    o._grid = if o.damaged_trees
        get_resource(w, DamagedTreeAttraction).grid
    else
        get_resource(w, HealthyTreeAttraction).grid
    end
    o._values = zeros(Float64, o._grid.width, o._grid.height)
end

function data(o::TreeAttractionMapObserver, w::World)::Matrix{Float64}
    for x in 1:(o._grid.width), y in 1:(o._grid.height)
        o._values[x, y] = log(o._grid[x, y])
    end

    return o._values
end
