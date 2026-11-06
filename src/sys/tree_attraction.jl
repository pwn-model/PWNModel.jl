# TreeAttraction computes one attraction field, meant to bias where
# dispersing beetles fly, for a deterministic consumer that always moves
# towards whichever neighbouring cell has the highest attraction value. It
# computes healthy- or damaged-tree attraction, never both: add it to the
# scheduler twice, once with damaged_trees=false and once true, to get both
# fields -- each instance can use entirely different half_distance/
# density_radius/density_weight values, since healthy and damaged trees
# plausibly attract vectors differently. Mirrors the sibling Go
# implementation's `sys.TreeAttraction`.
#
# Each source tree seeds propagate_attraction! with its own local occupancy
# fraction (see fill_from_query!), raised to density_weight, instead of a
# uniform value: a denser cluster starts from a taller seed, so it can out-reach and
# win cells that a closer but sparser source would otherwise have claimed by
# max-relaxation. Applying a density term *after* propagation instead (a
# uniform, strictly increasing transform of the finished field) could never
# achieve this: such a transform can never change a gradient's direction,
# nor which of several candidate cells has the highest value -- it only ever
# rescales the numbers, never a decision made from them. Seeding density in
# before propagation, rather than rescaling it after, is what gives
# density_weight real effect here.
#
# propagate_attraction! propagates these seeds outward via max-relaxation,
# decaying multiplicatively per step rather than subtracting a fixed cost: unlike
# subtraction, multiplication never drives a reachable cell to exactly zero,
# so there's no hard attraction radius. And unlike summing contributions
# together, max can never exceed the largest seed anywhere in the grid
# (multiplying by a factor in (0,1) only ever shrinks a value), so the field
# stays stable and bounded for any half_distance.
#
# Along with the field, propagate_attraction! traces each cell's source: the
# tree cell its value was propagated from. This is not necessarily the
# nearest tree: a cell won by a farther but denser cluster gets a cell of
# that cluster as its source. With density_weight > 0, even a tree's own
# cell can get another source, if a neighbouring dense cluster out-reaches
# its own seed.
mutable struct TreeAttraction <: System
    # tick_of_year when tree attraction is calculated.
    const tick_of_year::Int

    # damaged_trees selects which trees this instance computes attraction
    # from and which resource it publishes to: false uses healthy trees and
    # publishes HealthyTreeAttraction, true uses damaged trees and publishes
    # DamagedTreeAttraction.
    const damaged_trees::Bool

    # half_distance is the distance, in meters, at which a source's
    # contribution has decayed to half its value at the source cell -- i.e.
    # a beetle is half as attracted to a cell this far from a tree as to the
    # tree's own cell. Internally, decay = exp(-cell_size*log(2) /
    # half_distance), so a cell chamfer_distance(cell, source) cells from a
    # source ends up with decay^chamfer_distance(cell, source) of that
    # source's seed value.
    #
    # half_distance also sets the exchange rate between distance and
    # density: a source whose seed is k times another's can out-compete it
    # up to half_distance*log2(k) meters farther away (see density_weight).
    # A larger half_distance both spreads attraction farther and lets
    # density matter over a longer range; a small one makes density_weight
    # nearly irrelevant, since almost nothing can outweigh raw proximity.
    const half_distance::Float64

    # density_radius is the radius, in meters, within which a source tree's
    # own same-type neighbours are counted towards its local density.
    # Independent of half_distance: this is the "how clustered is this
    # source" scale, not the "how far does its seed reach" scale. Must be a
    # multiple of the world's base cell size. Unused, and not validated,
    # when density_weight is 0 -- see density_weight and DensitySeeding.
    const density_radius::Int

    # density_weight is the exponent applied to a source's local occupancy
    # fraction (its same-type neighbour count within density_radius,
    # divided by the number of cells that fit in that radius -- so always
    # in (0, 1]) to scale its seed: 0 makes every source seed at 1
    # regardless of clustering (a plain single-nearest/strongest-source
    # decay field), 1 makes the seed scale linearly with local occupancy,
    # and >1 makes denser clusters reach disproportionately farther than the
    # same trees spread out. Since occupancy is normalized to (0, 1], every
    # seed -- and so, by propagate_attraction!'s max-relaxation, the whole
    # resulting field -- stays within (0, 1] regardless of density_radius
    # or how densely populated the world is.
    const density_weight::Float64

    _attraction::Grid{Float64}

    # _presence marks the cells containing a matching tree. Recalculated
    # together with the attraction field, and published along with it for
    # other systems (e.g. BeetleMovementByField).
    _presence::Grid{Bool}

    # _source is the index (see cell_index) of the tree cell each cell's
    # attraction value was propagated from, NO_CELL where there is none.
    # Recalculated together with the attraction field, and published along
    # with it.
    _source::Grid{UInt32}

    # _density scales each source's seed by its local density.
    _density::DensitySeeding

    _filter::Filter

    function TreeAttraction(
        tick_of_year::Int, damaged_trees::Bool, half_distance::Float64, density_radius::Int, density_weight::Float64,
    )
        return new(
            tick_of_year, damaged_trees, half_distance, density_radius, density_weight,
            Grid(0, 0, 1, 0.0), Grid(0, 0, 1, false), Grid(0, 0, 1, NO_CELL),
        )
    end
end

TreeAttraction(;
    tick_of_year::Int, damaged_trees::Bool, half_distance::Float64, density_radius::Int,
    density_weight::Float64,
) = TreeAttraction(tick_of_year, damaged_trees, half_distance, density_radius, density_weight)

function initialize!(s::TreeAttraction, w::World)
    ws = get_resource(w, WorldSize)

    s._attraction = Grid(ws.width, ws.height, ws.cell_size, 0.0)
    s._presence = Grid(ws.width, ws.height, ws.cell_size, false)
    if ws.width * ws.height >= NO_CELL
        throw(ArgumentError("world too large for UInt32 cell indices of attraction sources"))
    end
    s._source = Grid(ws.width, ws.height, ws.cell_size, NO_CELL)
    if s.damaged_trees
        add_resource!(w, DamagedTreeAttraction(s._attraction, s._presence, s._source))
    else
        add_resource!(w, HealthyTreeAttraction(s._attraction, s._presence, s._source))
    end

    s._density = DensitySeeding(s.density_weight, s.density_radius, ws)

    s._filter = if s.damaged_trees
        Filter(w, (Position,); with=(Damaged,))
    else
        Filter(w, (Position,); without=(Damaged,))
    end
end

function update!(s::TreeAttraction, w::World)
    toy = get_resource(w, Time).tick_of_year

    if toy != s.tick_of_year
        return
    end

    fill_from_query!(s, s._filter)
    propagate_attraction!(s._attraction, s._source, s.half_distance)
end

# fill_from_query! marks every cell containing a matching tree in
# s._presence and seeds the attraction grid: every such cell is set to that
# source's own local occupancy fraction raised to density_weight (see
# DensitySeeding), everything else to 0. Every such cell is its own source,
# every other cell has none (NO_CELL). propagate_attraction! then
# propagates these seeds and sources outward.
#
# This is the only pass over the trees. It seeds every source at 1, which
# is final for density_weight 0 (occupancy^0 is 1 for any occupancy);
# otherwise, seed_density! rescales the seeds in a single pass over the
# grid.
#
# Takes a pre-built Filter (see the field docstring on TreeAttraction)
# rather than `with`/`without` tuples, so that Query(filt) below hits Ark's
# fast, specialized path instead of re-deriving a filter from tuples whose
# element types aren't compile-time constants here.
#
# TODO: can we do better here and get rid of the dynamic dispatch?
function fill_from_query!(s::TreeAttraction, filt::Filter)
    fill!(s._presence, false)
    fill!(s._attraction, 0.0)
    fill!(s._source, NO_CELL)

    for (_, positions) in Query(filt)
        for pos in positions
            s._presence[pos.x, pos.y] = true
            s._attraction[pos.x, pos.y] = 1.0
            s._source[pos.x, pos.y] = cell_index(s._source, pos.x, pos.y)
        end
    end

    seed_density!(s._density, s._presence, s._attraction)
end
