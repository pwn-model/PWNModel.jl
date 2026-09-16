
# SpaceGrid resource for the large-scale spatial grid.
#
# Wraps an EntityGrid only to give it a distinct resource type; access the
# grid itself through the `grid` field.
struct SpaceGrid
    grid::EntityGrid
end
