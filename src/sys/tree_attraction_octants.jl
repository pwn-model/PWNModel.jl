# TreeAttractionOctants computes, for every cell, the most attractive tree in
# each of the 8 half-open octants around it (see OctantSources), meant for a
# consumer that selects an octant by the attraction values of its sources
# and moves directly to the selected octant's source tree. A cell's own tree
# is never one of its sources, so that a beetle on a tree "sees" only other
# trees.
#
# Attraction is defined just like for TreeAttraction: each tree seeds with
# its local occupancy fraction raised to density_weight (see
# DensitySeeding), decayed by half every half_distance meters of chamfer
# distance. Unlike TreeAttraction's single max-relaxed field, the octant
# sources are never shadowed by nearer but less attractive trees in the
# same octant (see propagate_octants!).
#
# It computes healthy- or damaged-tree octants, never both: add it to the
# scheduler twice, once with damaged_trees=false and once true, to get both,
# each with its own parameters.
mutable struct TreeAttractionOctants <: System
    # tick_of_year when the octant sources are calculated.
    const tick_of_year::Int

    # damaged_trees selects which trees this instance computes octant
    # sources from and which resource it publishes to: false uses healthy
    # trees and publishes HealthyTreeAttractionOctants, true uses damaged
    # trees and publishes DamagedTreeAttractionOctants.
    const damaged_trees::Bool

    # half_distance is the distance, in meters, at which a tree's
    # attraction has decayed to half its seed value. It also sets the
    # exchange rate between distance and density: a tree whose seed is k
    # times another's is equally attractive half_distance*log2(k) meters
    # farther away. See TreeAttraction.
    const half_distance::Float64

    # density_radius is the radius, in meters, within which a tree's own
    # same-type neighbours are counted towards its local density. Must be a
    # multiple of the world's base cell size. Unused, and not validated,
    # when density_weight is 0. See TreeAttraction.
    const density_radius::Int

    # density_weight is the exponent applied to a tree's local occupancy
    # fraction to get its seed, in (0, 1]: 0 seeds every tree at 1, 1 makes
    # the seed scale linearly with local occupancy. See TreeAttraction.
    const density_weight::Float64

    # _seeds is the reused seed grid passed to propagate_octants!.
    _seeds::Grid{Float64}

    # _presence marks the cells containing a matching tree. Recalculated
    # together with the octant sources, and published along with them.
    _presence::Grid{Bool}

    # _sources holds the octant sources of each cell. Published.
    _sources::Grid{OctantSources}

    # _buffers are the reused scratch columns of propagate_octants!.
    _buffers::OctantBuffers

    # _density scales each tree's seed by its local density.
    _density::DensitySeeding

    function TreeAttractionOctants(
        tick_of_year::Int, damaged_trees::Bool, half_distance::Float64, density_radius::Int, density_weight::Float64,
    )
        return new(
            tick_of_year, damaged_trees, half_distance, density_radius, density_weight,
            Grid(0, 0, 1, 0.0), Grid(0, 0, 1, false), Grid(0, 0, 1, OctantSources()), OctantBuffers(0),
        )
    end
end

TreeAttractionOctants(;
    tick_of_year::Int, damaged_trees::Bool, half_distance::Float64, density_radius::Int,
    density_weight::Float64,
) = TreeAttractionOctants(tick_of_year, damaged_trees, half_distance, density_radius, density_weight)

function initialize!(s::TreeAttractionOctants, w::World)
    ws = get_resource(w, WorldSize)

    # Offsets to sources range from -(size-1) to size-1 cells per axis, and
    # are stored as Int16.
    max_size = Int(typemax(Int16)) + 1
    if ws.width > max_size || ws.height > max_size
        throw(ArgumentError("world too large for Int16 offsets of octant sources, max. $max_size cells per side"))
    end

    s._seeds = Grid(ws.width, ws.height, ws.cell_size, 0.0)
    s._presence = Grid(ws.width, ws.height, ws.cell_size, false)
    s._sources = Grid(ws.width, ws.height, ws.cell_size, OctantSources())
    s._buffers = OctantBuffers(ws.height)
    s._density = DensitySeeding(s.density_weight, s.density_radius, ws)

    if s.damaged_trees
        add_resource!(w, DamagedTreeAttractionOctants(s._sources, s._presence))
    else
        add_resource!(w, HealthyTreeAttractionOctants(s._sources, s._presence))
    end
end

function update!(s::TreeAttractionOctants, w::World)
    toy = get_resource(w, Time).tick_of_year

    if toy != s.tick_of_year
        return
    end

    fill_from_query!(s, w)
    propagate_octants!(s._sources, s._seeds, s.half_distance, s._buffers)
    return nothing
end

# fill_from_query! marks every cell containing a matching tree in
# s._presence and sets its seed in s._seeds to the tree's local occupancy
# fraction raised to density_weight (see DensitySeeding), everything else to
# 0.
#
# The query is created in one of two branches, each with literal component
# types, like in TreeAttraction's fill_from_query!, so that _mark_trees! is
# specialized for both, without any dynamic dispatch.
function fill_from_query!(s::TreeAttractionOctants, w::World)
    fill!(s._presence, false)
    fill!(s._seeds, 0.0)

    if s.damaged_trees
        _mark_trees!(s, Query(w, (Position,); with=(Damaged,)))
    else
        _mark_trees!(s, Query(w, (Position,); without=(Damaged,)))
    end

    seed_density!(s._density, s._presence, s._seeds)
end

# _mark_trees! marks the cells of the trees matched by query as present, and
# seeds them at 1.
function _mark_trees!(s::TreeAttractionOctants, query::Query)
    for (_, positions) in query
        for pos in positions
            s._presence[pos.x, pos.y] = true
            s._seeds[pos.x, pos.y] = 1.0
        end
    end
end
