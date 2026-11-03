
# NO_CELL is a placeholder cell index for the absence of a cell, e.g. of an
# attraction source. See cell_index.
const NO_CELL = typemax(UInt32)

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

# checkbounds for cells (x, y) of a grid: with Bool as first argument,
# reports whether (x, y) is within the grid, otherwise throws a BoundsError
# if it is not. Mirrors the sibling Go implementation's `Grid.Contains`.
Base.checkbounds(::Type{Bool}, grid::Grid, x::Int, y::Int) = checkbounds(Bool, grid._values, y, x)

function Base.checkbounds(grid::Grid, x::Int, y::Int)
    checkbounds(Bool, grid, x, y) || throw(BoundsError(grid, (x, y)))
    return nothing
end

# cell_index returns the (1-based) linear index of the cell at (x, y), as
# used for the grid's own storage. Only valid for grids with less than
# NO_CELL cells, so that NO_CELL is never a valid index. Mirrors the sibling
# Go implementation's `Grid.Index`, which is 0-based.
cell_index(grid::Grid, x::Int, y::Int) = UInt32(LinearIndices(grid._values)[y, x])

# cell_coords returns the coordinates (x, y) of the cell with the given
# linear index. Inverse of cell_index.
function cell_coords(grid::Grid, idx::UInt32)
    c = CartesianIndices(grid._values)[idx]
    return c[2], c[1]
end

# Fill the grid with the given value.
Base.fill!(grid::Grid, v) = (fill!(grid._values, v); grid)
