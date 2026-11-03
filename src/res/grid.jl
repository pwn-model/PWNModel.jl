
# Cell coordinates on a grid.
struct Cell
    x::Int
    y::Int
end

# NO_CELL is a placeholder for the absence of a cell, e.g. of an attraction
# source. The sibling Go implementation uses (-1, -1), as its grid is
# 0-based.
const NO_CELL = Cell(0, 0)

# Grid resource holding values of type T on a 2D grid.
struct Grid{T}
    _values::Array{T,2}
    width::Int
    height::Int
    cell_size::Int # Cell size of the grid in meters.
end

# Creates a new Grid of the given size, filled with `default`.
function Grid(sx::Int, sy::Int, cell_size::Int, default::T) where {T}
    Grid{T}(fill(default, sy, sx), sx, sy, cell_size)
end

Base.getindex(grid::Grid, x::Int, y::Int) = grid._values[y, x]
Base.setindex!(grid::Grid, value, x::Int, y::Int) = (grid._values[y, x] = value)

# Fill the grid with the given value.
Base.fill!(grid::Grid, v) = (fill!(grid._values, v); grid)
