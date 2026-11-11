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
