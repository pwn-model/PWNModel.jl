
# WorldSize resource
struct WorldSize
    width::Int      # Width of the world in tree diameters
    height::Int     # Height of the world in tree diameters
    resolution::Int # Resolution of the spatial grid in tree diameters per cell
end

# to_coords calculates (1-based) space grid coords from (1-based) tree coords.
to_coords(ws::WorldSize, x::Int, y::Int) = (fld(x - 1, ws.resolution) + 1, fld(y - 1, ws.resolution) + 1)
