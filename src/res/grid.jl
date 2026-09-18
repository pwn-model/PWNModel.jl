
# Grid resource holding values of type T on a 2D grid.
struct Grid{T}
    _values::Array{T,2}
    width::Int
    height::Int
end

# Creates a new Grid of the given size, filled with `default`.
function Grid(sx::Int, sy::Int, default::T) where {T}
    Grid{T}(fill(default, sy, sx), sx, sy)
end

Base.getindex(grid::Grid, x::Int, y::Int) = grid._values[y, x]
Base.setindex!(grid::Grid, value, x::Int, y::Int) = (grid._values[y, x] = value)

# Fill the grid with the given value.
Base.fill!(grid::Grid, v) = (fill!(grid._values, v); grid)
