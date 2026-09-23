"""
Reports one of the four attraction grids computed by [`TreeAttraction`](@ref)
(healthy/damaged trees, at near/far range), for plotting (e.g. with
`plot.Image`, see `scripts/plot/image.jl`).
"""
mutable struct TreeAttractionMapObserver <: MatrixObserver
    const damaged_trees::Bool
    const far_range::Bool

    _grid::Grid{Float64}
    _values::Matrix{Float64}
end

"""
    TreeAttractionMapObserver(; damaged_trees=false, far_range=false)

  - `damaged_trees`: reports the damaged-tree attraction grid instead of the
    healthy-tree one.
  - `far_range`: reports the far-range attraction grid instead of the
    near-range one.
"""
function TreeAttractionMapObserver(; damaged_trees::Bool=false, far_range::Bool=false)
    return TreeAttractionMapObserver(damaged_trees, far_range, Grid(0, 0, 1, 0.0), zeros(Float64, 0, 0))
end

function initialize!(o::TreeAttractionMapObserver, w::World)
    o._grid = if o.damaged_trees
        o.far_range ? get_resource(w, DamagedTreeAttractionFar).grid : get_resource(w, DamagedTreeAttractionNear).grid
    else
        o.far_range ? get_resource(w, HealthyTreeAttractionFar).grid : get_resource(w, HealthyTreeAttractionNear).grid
    end
    o._values = zeros(Float64, o._grid.width, o._grid.height)
end

function data(o::TreeAttractionMapObserver, w::World)::Matrix{Float64}
    for x in 1:(o._grid.width), y in 1:(o._grid.height)
        o._values[x, y] = o._grid[x, y]
    end

    return o._values
end
