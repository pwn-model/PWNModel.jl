
# TreeGrid resource for the small-scale trees grid.
#
# Wraps a Grid{Entity} only to give it a distinct resource type; access the
# grid itself through the `grid` field.
struct TreeGrid
    grid::Grid{Entity}
end

TreeGrid(sx::Int, sy::Int, cell_size::Int) = TreeGrid(Grid(sx, sy, cell_size, zero_entity))

# HealthyTreeAttraction resource: attraction field driven by healthy trees.
struct HealthyTreeAttraction
    # Attraction field of healthy trees, updated once per year.
    attraction::Grid{Float64}
    # Presence of healthy trees per cell, updated together with attraction.
    presence::Grid{Bool}
end

# DamagedTreeAttraction resource: attraction field driven by damaged trees.
struct DamagedTreeAttraction
    # Attraction field of damaged trees, updated once per year.
    attraction::Grid{Float64}
    # Presence of damaged trees per cell, updated together with attraction.
    presence::Grid{Bool}
end

# FeedingInfectedBeetles resource.
struct FeedingInfectedBeetles
    grid::Grid{UInt32}
end
