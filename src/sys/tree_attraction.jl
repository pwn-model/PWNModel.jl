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
# Each source tree seeds fill_grid! with its own local occupancy fraction
# (see fill_from_query!), raised to density_weight, instead of a uniform
# value: a denser cluster starts from a taller seed, so it can out-reach and
# win cells that a closer but sparser source would otherwise have claimed by
# max-relaxation. Applying a density term *after* propagation instead (a
# uniform, strictly increasing transform of the finished field) could never
# achieve this: such a transform can never change a gradient's direction,
# nor which of several candidate cells has the highest value -- it only ever
# rescales the numbers, never a decision made from them. Seeding density in
# before propagation, rather than rescaling it after, is what gives
# density_weight real effect here.
#
# fill_grid! propagates these seeds outward via max-relaxation, decaying
# multiplicatively per step rather than subtracting a fixed cost: unlike
# subtraction, multiplication never drives a reachable cell to exactly zero,
# so there's no hard attraction radius. And unlike summing contributions
# together, max can never exceed the largest seed anywhere in the grid
# (multiplying by a factor in (0,1) only ever shrinks a value), so the field
# stays stable and bounded for any half_distance.
mutable struct TreeAttraction <: System
    # tick_of_year when tree attraction is calculated.
    const tick_of_year::Int

    # damaged_trees selects which trees this instance computes attraction
    # from and which resource it publishes to: false (the default) uses
    # healthy trees and publishes HealthyTreeAttraction, true uses damaged
    # trees and publishes DamagedTreeAttraction.
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
    # when density_weight is 0 -- see density_weight and fill_from_query!.
    const density_radius::Int

    # density_weight is the exponent applied to a source's local occupancy
    # fraction (its same-type neighbour count within density_radius,
    # divided by the number of cells that fit in that radius -- so always
    # in (0, 1]) to scale its seed: 0 makes every source seed at 1
    # regardless of clustering (a plain single-nearest/strongest-source
    # decay field), 1 makes the seed scale linearly with local occupancy,
    # and >1 makes denser clusters reach disproportionately farther than the
    # same trees spread out. Since occupancy is normalized to (0, 1], every
    # seed -- and so, by fill_grid!'s max-relaxation, the whole resulting
    # field -- stays within (0, 1] regardless of density_radius or how
    # densely populated the world is.
    const density_weight::Float64

    # _decay is the per-orthogonal-cell-step decay factor derived from
    # half_distance; a diagonal step uses decay^sqrt(2).
    _decay::Float64

    # _density_radius_cells is density_radius expressed in grid cells. Left
    # at its zero value when density_weight is 0.
    _density_radius_cells::Int

    # _max_count is the number of cells in a full
    # (2*_density_radius_cells+1) square window, i.e. the largest
    # local_count can ever be. Dividing by it turns a raw neighbour count
    # into an occupancy fraction in (0, 1]. Left at its zero value when
    # density_weight is 0.
    _max_count::Float64

    _attraction::Grid{Float64}

    # _presence is a reused 0/1 scratch grid for seeding. Left undefined
    # when density_weight is 0, since fill_from_query!'s fast path never
    # touches it.
    _presence::Grid{Float64}

    # _sat is a reused (width+1)*(height+1) summed-area-table buffer for
    # counting each source's local density. Left undefined when
    # density_weight is 0, since fill_from_query!'s fast path never touches
    # it.
    _sat::Vector{Float64}

    _filter::Filter

    function TreeAttraction(
        tick_of_year::Int, damaged_trees::Bool, half_distance::Float64, density_radius::Int, density_weight::Float64,
    )
        return new(
            tick_of_year, damaged_trees, half_distance, density_radius, density_weight,
            0.0, 0, 0.0,
            Grid(0, 0, 1, 0.0),
        )
    end
end

TreeAttraction(;
    tick_of_year::Int, damaged_trees::Bool=false, half_distance::Float64, density_radius::Int,
    density_weight::Float64,
) = TreeAttraction(tick_of_year, damaged_trees, half_distance, density_radius, density_weight)

function initialize!(s::TreeAttraction, w::World)
    ws = get_resource(w, WorldSize)
    s._decay = exp(-ws.cell_size * log(2) / s.half_distance)

    s._attraction = Grid(ws.width, ws.height, ws.cell_size, 0.0)
    if s.damaged_trees
        add_resource!(w, DamagedTreeAttraction(s._attraction))
    else
        add_resource!(w, HealthyTreeAttraction(s._attraction))
    end

    # At density_weight 0, occupancy^0 is 1 regardless of local density (see
    # fill_from_query!'s fast path), so density_radius is never consulted:
    # don't require it to be valid, and don't allocate the buffers that only
    # the density count needs.
    if s.density_weight != 0
        if s.density_radius % ws.cell_size != 0
            throw(
                ArgumentError(
                    "density_radius of the dispersal submodel must be a multiple of the world's base cell size.",
                ),
            )
        end
        s._density_radius_cells = s.density_radius ÷ ws.cell_size
        s._max_count = Float64((2 * s._density_radius_cells + 1)^2)

        s._presence = Grid(ws.width, ws.height, ws.cell_size, 0.0)
        s._sat = zeros(Float64, (ws.width + 1) * (ws.height + 1))
    end

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

    calc_attraction!(s)
end

function calc_attraction!(s::TreeAttraction)
    fill_from_query!(s, s._attraction, s._filter)
    fill_grid!(s, s._attraction)
end

# fill_from_query! seeds the attraction grid: every cell containing a
# matching tree is set to that source's own local occupancy fraction
# (local_count divided by _max_count, always in (0, 1]) raised to
# density_weight, everything else to 0. fill_grid! then propagates these
# seeds outward.
#
# Takes a pre-built Filter (see the field docstring on TreeAttraction)
# rather than `with`/`without` tuples, so that Query(filt) below hits Ark's
# fast, specialized path instead of re-deriving a filter from tuples whose
# element types aren't compile-time constants here.
function fill_from_query!(s::TreeAttraction, grid::Grid{Float64}, filt::Filter)
    fill!(grid, 0.0)

    if s.density_weight == 0
        # occupancy^0 is 1 for any occupancy, so every source's seed is 1
        # regardless of local density: skip counting it altogether.
        for (_, positions) in Query(filt)
            for pos in positions
                grid[pos.x, pos.y] = 1.0
            end
        end
        return
    end

    fill!(s._presence, 0.0)
    for (_, positions) in Query(filt)
        for pos in positions
            s._presence[pos.x, pos.y] = 1.0
        end
    end

    build_sat!(s)

    for (_, positions) in Query(filt)
        for pos in positions
            occupancy = local_count(s, pos.x, pos.y) / s._max_count
            grid[pos.x, pos.y] = occupancy^s.density_weight
        end
    end
end

# build_sat! computes a summed-area table of s._presence into s._sat, so
# that local_count can answer a windowed tree count in O(1) instead of
# O(radius^2) per source.
function build_sat!(s::TreeAttraction)
    w, h = s._presence.width, s._presence.height
    stride = h + 1
    idx(x, y) = x * stride + y + 1

    sat = s._sat
    for x in 0:w
        sat[idx(x, 0)] = 0.0
    end
    for y in 0:h
        sat[idx(0, y)] = 0.0
    end
    for x in 1:w, y in 1:h
        sat[idx(x, y)] = s._presence[x, y] + sat[idx(x - 1, y)] + sat[idx(x, y - 1)] - sat[idx(x - 1, y - 1)]
    end
end

# local_count returns the number of same-type trees within density_radius
# of (x, y), inclusive of the tree at (x, y) itself (so the result is
# always >= 1 when called on an actual source cell), via the summed-area
# table built by build_sat!.
function local_count(s::TreeAttraction, x::Int, y::Int)
    w, h = s._presence.width, s._presence.height
    stride = h + 1
    idx(xx, yy) = xx * stride + yy + 1

    r = s._density_radius_cells
    x1, x2 = max(x - r, 1), min(x + r, w)
    y1, y2 = max(y - r, 1), min(y + r, h)

    sat = s._sat
    return sat[idx(x2, y2)] - sat[idx(x1 - 1, y2)] - sat[idx(x2, y1 - 1)] + sat[idx(x1 - 1, y1 - 1)]
end

# fill_grid! turns the seeded values into a smooth attraction field by
# propagating each source's value outward, multiplying by decay per
# orthogonal step and decay^sqrt(2) per diagonal step, and keeping the best
# (max) value reaching each cell from any source. This is an in-place,
# single-grid Gauss-Seidel relaxation (a discrete fast-sweeping method):
# two passes in opposite raster directions suffice, because the grid has no
# obstacles, so any shortest path from a source can be split into one
# forward-monotone and one backward-monotone segment, each fully resolved
# by one of the two passes.
function fill_grid!(s::TreeAttraction, grid::Grid{Float64})
    w, h = grid.width, grid.height

    # Offsets of the already-updated neighbours seen by a sweep moving in
    # increasing (forward) resp. decreasing (backward) x/y, paired with
    # their step decay factor.
    forward = ((-1, -1), (-1, 0), (-1, 1), (0, -1))
    backward = ((1, 1), (1, 0), (1, -1), (0, 1))
    decay = s._decay
    diagonal_decay = decay^sqrt(2.0)
    decays = (diagonal_decay, decay, diagonal_decay, decay)

    function relax!(x, y, offsets)
        best = grid[x, y]
        for i in eachindex(offsets)
            dx, dy = offsets[i]
            nx, ny = x + dx, y + dy
            if nx < 1 || nx > w || ny < 1 || ny > h
                continue
            end
            v = grid[nx, ny] * decays[i]
            if v > best
                best = v
            end
        end
        grid[x, y] = best
    end

    for x in 1:w, y in 1:h
        relax!(x, y, forward)
    end
    for x in w:-1:1, y in h:-1:1
        relax!(x, y, backward)
    end
end
