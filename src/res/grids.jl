
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
    # Source of the attraction value per cell, i.e. the index (see
    # cell_index) of the tree cell it was propagated from. NO_CELL where
    # there is no source at all.
    source::Grid{UInt32}
end

# DamagedTreeAttraction resource: attraction field driven by damaged trees.
struct DamagedTreeAttraction
    # Attraction field of damaged trees, updated once per year.
    attraction::Grid{Float64}
    # Presence of damaged trees per cell, updated together with attraction.
    presence::Grid{Bool}
    # Source of the attraction value per cell, i.e. the index (see
    # cell_index) of the tree cell it was propagated from. NO_CELL where
    # there is no source at all.
    source::Grid{UInt32}
end

# FeedingInfectedBeetles resource.
struct FeedingInfectedBeetles
    grid::Grid{UInt32}
end

# HealthyTreeAttractionOctants resource: the most attractive healthy tree in
# each octant around every cell.
struct HealthyTreeAttractionOctants
    # Sources per cell and octant (see OctantSources), updated once per year.
    sources::Grid{OctantSources}
    # Presence of healthy trees per cell, updated together with sources.
    presence::Grid{Bool}
end

# DamagedTreeAttractionOctants resource: the most attractive damaged tree in
# each octant around every cell.
struct DamagedTreeAttractionOctants
    # Sources per cell and octant (see OctantSources), updated once per year.
    sources::Grid{OctantSources}
    # Presence of damaged trees per cell, updated together with sources.
    presence::Grid{Bool}
end
