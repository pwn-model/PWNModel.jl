
# TreeGrid resource for the small-scale trees grid.
#
# Wraps a Grid{Entity} only to give it a distinct resource type; access the
# grid itself through the `grid` field.
struct TreeGrid
    grid::Grid{Entity}
end

TreeGrid(sx::Int, sy::Int) = TreeGrid(Grid(sx, sy, zero_entity))

# SpaceGrid resource for the large-scale spatial grid.
#
# Wraps a Grid{Entity} only to give it a distinct resource type; access the
# grid itself through the `grid` field.
struct SpaceGrid
    grid::Grid{Entity}
end
