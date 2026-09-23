
# TreeGrid resource for the small-scale trees grid.
#
# Wraps a Grid{Entity} only to give it a distinct resource type; access the
# grid itself through the `grid` field.
struct TreeGrid
    grid::Grid{Entity}
end

TreeGrid(sx::Int, sy::Int, cell_size::Int) = TreeGrid(Grid(sx, sy, cell_size, zero_entity))

# SpaceGrid resource for the large-scale spatial grid.
#
# Wraps a Grid{Entity} only to give it a distinct resource type; access the
# grid itself through the `grid` field.
struct SpaceGrid
    grid::Grid{Entity}
end

# HealthyTreeAttractionNear resource: near-field attraction driven by healthy trees.
struct HealthyTreeAttractionNear
    grid::Grid{Float64}
end

# HealthyTreeAttractionFar resource: far-field attraction driven by healthy trees.
struct HealthyTreeAttractionFar
    grid::Grid{Float64}
end

# DamagedTreeAttractionNear resource: near-field attraction driven by damaged trees.
struct DamagedTreeAttractionNear
    grid::Grid{Float64}
end

# DamagedTreeAttractionFar resource: far-field attraction driven by damaged trees.
struct DamagedTreeAttractionFar
    grid::Grid{Float64}
end
