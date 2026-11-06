# DensitySeeding scales the seeds of attraction sources by their local
# density: each source cell's seed is set to its local occupancy fraction
# (the number of source cells within density_radius, divided by the number
# of cells that fit in that radius -- so always in (0, 1]) raised to
# density_weight. Shared by the systems computing attraction fields from
# trees (TreeAttraction, TreeAttractionOctants); see their docs for the
# meaning of density_radius and density_weight.
struct DensitySeeding
    density_weight::Float64

    # radius_cells is density_radius expressed in grid cells. Left at 0
    # when density_weight is 0.
    radius_cells::Int

    # max_count is the number of cells in a full (2*radius_cells+1) square
    # window, i.e. the largest local_count can ever be. Dividing by it turns
    # a raw neighbour count into an occupancy fraction in (0, 1]. Left at 0
    # when density_weight is 0.
    max_count::Float64

    # sat is a reused (width+1)*(height+1) summed-area-table buffer for
    # counting each source's local density. Left empty when density_weight
    # is 0, since seed_density! never touches it then.
    sat::Vector{Float64}
end

# DensitySeeding creates a DensitySeeding for a world of size ws.
#
# At density_weight 0, occupancy^0 is 1 regardless of local density, so
# density_radius is never consulted: it is not required to be valid, and
# the buffer that only the density count needs is not allocated.
function DensitySeeding(density_weight::Float64, density_radius::Int, ws::WorldSize)
    if density_weight == 0
        return DensitySeeding(density_weight, 0, 0.0, Float64[])
    end
    if density_radius % ws.cell_size != 0
        throw(
            ArgumentError(
                "density_radius of the dispersal submodel must be a multiple of the world's base cell size.",
            ),
        )
    end
    radius_cells = density_radius ÷ ws.cell_size
    max_count = Float64((2 * radius_cells + 1)^2)
    sat = zeros(Float64, (ws.width + 1) * (ws.height + 1))
    return DensitySeeding(density_weight, radius_cells, max_count, sat)
end

# seed_density! sets the seed of every source cell (marked in presence) in
# seeds to its local occupancy fraction raised to density_weight. Leaves
# seeds untouched at density_weight 0, where every seed is final at 1
# already (occupancy^0 is 1 for any occupancy).
#
# Computes a summed-area table of presence (counting each occupied cell as
# 1) into d.sat, so that local_count can answer a windowed count in O(1)
# instead of O(radius^2) per source, and sets the seed of every source
# from it. Both happen in the same pass over the grid: a source's
# local_count only needs the table up to column x+radius_cells, so the
# sources of each column are seeded as soon as that table column is
# complete, lagging radius_cells columns behind, plus all remaining columns
# once the last table column is done. Mirrors the sibling Go
# implementation's seedDensity, whose lag is one more column only because
# its grid columns are 0-based while the table's are shifted by one.
function seed_density!(d::DensitySeeding, presence::Grid{Bool}, seeds::Grid{Float64})
    if d.density_weight == 0
        return
    end

    w, h = presence.width, presence.height
    stride = h + 1
    idx(x, y) = x * stride + y + 1

    sat = d.sat
    for x in 0:w
        sat[idx(x, 0)] = 0.0
    end
    for y in 0:h
        sat[idx(0, y)] = 0.0
    end

    r = d.radius_cells
    next = 1 # next grid column to seed
    for x in 1:w
        for y in 1:h
            v = presence[x, y] ? 1.0 : 0.0
            sat[idx(x, y)] = v + sat[idx(x - 1, y)] + sat[idx(x, y - 1)] - sat[idx(x - 1, y - 1)]
        end

        last = x == w ? w : x - r
        while next <= last
            for y in 1:h
                if presence[next, y]
                    occupancy = local_count(d, presence, next, y) / d.max_count
                    seeds[next, y] = occupancy^d.density_weight
                end
            end
            next += 1
        end
    end
end

# local_count returns the number of source cells within density_radius of
# (x, y), inclusive of (x, y) itself (so the result is always >= 1 when
# called on an actual source cell), via the summed-area table built by
# seed_density!.
function local_count(d::DensitySeeding, presence::Grid{Bool}, x::Int, y::Int)
    w, h = presence.width, presence.height
    stride = h + 1
    idx(xx, yy) = xx * stride + yy + 1

    r = d.radius_cells
    x1, x2 = max(x - r, 1), min(x + r, w)
    y1, y2 = max(y - r, 1), min(y + r, h)

    sat = d.sat
    return sat[idx(x2, y2)] - sat[idx(x1 - 1, y2)] - sat[idx(x2, y1 - 1)] + sat[idx(x1 - 1, y1 - 1)]
end
