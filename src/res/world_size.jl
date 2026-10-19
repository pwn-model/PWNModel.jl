
"""
WorldSize resource.
"""
struct WorldSize
    width::Int     # Width of the world in tree diameters.
    height::Int    # Height of the world in tree diameters.
    cell_size::Int # Cell size of the tree grid in meters.
end

"""
Creates a new WorldSize.

Arguments are:

  - World width in meters
  - World height in meters
  - Cell size of the tree grid in meters
"""
function WorldSize(; width::Int, height::Int, cell_size::Int)
    if width % cell_size != 0
        throw(ArgumentError("World width must be a multiple of cell_size"))
    end
    if height % cell_size != 0
        throw(ArgumentError("World height must be a multiple of cell_size"))
    end
    return WorldSize(width ÷ cell_size, height ÷ cell_size, cell_size)
end
