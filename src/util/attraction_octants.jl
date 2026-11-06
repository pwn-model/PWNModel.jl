# OctantBuffers holds the reused scratch columns of propagate_octants!. See
# there.
struct OctantBuffers
    # values and offsets hold, in this order, the previous and current
    # column of the x-major octant, then the previous and current column of
    # the y-major octant of the quadrant being swept. Each has length
    # height+2: entry y+1 is grid row y, entries 1 and height+2 are padding
    # that always stays empty, standing in for rows outside the grid.
    values::NTuple{4,Vector{Float64}}
    offsets::NTuple{4,Vector{NTuple{2,Int16}}}
end

OctantBuffers(height::Int) = OctantBuffers(
    ntuple(_ -> zeros(Float64, height + 2), Val(4)),
    ntuple(_ -> fill((Int16(0), Int16(0)), height + 2), Val(4)),
)

# propagate_octants! computes, for every cell and each of its 8 half-open
# octants (see OctantSources), the most attractive source in that octant,
# and stores its offset and attraction value in sources.
#
# A source's attraction, as seen from a cell, is its seed (from seeds; 0
# for cells without a source) decayed over the chamfer distance between
# both: multiplied by decay per orthogonal step and decay^sqrt(2) per
# diagonal step, with decay = exp(-cell_size*log(2) / half_distance), just
# like propagate_attraction!.
#
# Propagation works on closed octants, each spanned by an axis step and a
# diagonal step: e.g. the closed octant 0 <= dy <= dx by (1, 0) and (1, 1).
# Every cell of the closed octant is reached from its tip by some sequence
# of these two steps, and no other cell is, and the shortest chamfer path
# to an octant cell only uses these two steps. Propagating seeds backwards
# along the two steps, with max-relaxation, is thus exact: a cell's closed
# value V (which includes the cell's own seed) is the max over its own seed
# and the values V of its two step neighbours, each multiplied by its step's
# decay. Since the decay per step is a constant factor, this never drops a
# source that would win farther on, i.e. a nearer but weaker source never
# shadows a farther but stronger one.
#
# The value published for a half-open octant uses only one of the two step
# neighbours: an octant without its diagonal ray (e.g. octant 1,
# 0 <= dy < dx) is exactly the closed octant of the neighbour one axis step
# away, shifted by that step, since every cell not on the diagonal ray has
# a shortest path starting with an axis step. Likewise, an octant without
# its axis ray (e.g. octant 2, 0 < dx <= dy) is exactly the closed octant of
# the neighbour one diagonal step away. With the starting ray included in
# each octant, odd octants exclude their diagonal ray and publish the axis
# step neighbour's value, even octants exclude their axis ray and publish
# the diagonal step neighbour's value. This also excludes the cell itself
# as its own source.
#
# The two octants of each quadrant are computed in one sweep, so there are
# four sweeps. Both steps of an octant advance by one column (the axis step
# of a y-major octant by one row instead), so each sweep only needs the
# previous and the current column of propagated values, kept in buf instead
# of full grids.
#
# On ties in the propagated values V, the cell's own seed wins over a step
# neighbour's value, and the axis step wins over the diagonal step.
function propagate_octants!(
    sources::Grid{OctantSources}, seeds::Grid{Float64}, half_distance::Float64, buf::OctantBuffers,
)
    decay = exp(-seeds.cell_size * log(2) / half_distance)
    diagonal_decay = decay^sqrt(2.0)

    # Quadrant (sx, sy) contains octants with offsets of signs (sx, sy), and
    # its x-major octant (|dy| <= |dx|) and y-major octant (|dx| <= |dy|)
    # are kx and ky.
    _propagate_quadrant!(sources, seeds, buf, 1, 1, 1, 2, decay, diagonal_decay)
    _propagate_quadrant!(sources, seeds, buf, -1, 1, 4, 3, decay, diagonal_decay)
    _propagate_quadrant!(sources, seeds, buf, -1, -1, 5, 6, decay, diagonal_decay)
    _propagate_quadrant!(sources, seeds, buf, 1, -1, 8, 7, decay, diagonal_decay)
    return sources
end

# _propagate_quadrant! performs the sweep of propagate_octants! for the
# octants kx (x-major) and ky (y-major) of quadrant (sx, sy).
#
# A cell's sources lie in direction (sx, sy), so the sweep starts at the
# opposite corner of the grid and processes columns, and rows within a
# column, against that direction: both steps of the x-major octant, (sx, 0)
# and (sx, sy), lead into the previous column; the y-major octant's axis
# step (0, sy) leads to the previous row of the current column, its
# diagonal step (sx, sy) into the previous column.
function _propagate_quadrant!(
    sources::Grid{OctantSources}, seeds::Grid{Float64}, buf::OctantBuffers,
    sx::Int, sy::Int, kx::Int, ky::Int, decay::Float64, diagonal_decay::Float64,
)
    w, h = seeds.width, seeds.height
    seed_values = seeds._values
    out = sources._values

    no_offset = (Int16(0), Int16(0))
    x_step = (Int16(sx), Int16(0))
    y_step = (Int16(0), Int16(sy))
    diagonal_step = (Int16(sx), Int16(sy))

    # Odd octants publish their axis step candidate, even octants their
    # diagonal step candidate (see propagate_octants!).
    kx_axis = isodd(kx)
    ky_axis = isodd(ky)

    prev_x_values, cur_x_values, prev_y_values, cur_y_values = buf.values
    prev_x_offsets, cur_x_offsets, prev_y_offsets, cur_y_offsets = buf.offsets
    for v in buf.values
        fill!(v, 0.0)
    end
    for o in buf.offsets
        fill!(o, no_offset)
    end

    xs = sx > 0 ? (w:-1:1) : (1:1:w)
    ys = sy > 0 ? (h:-1:1) : (1:1:h)

    @inbounds for x in xs
        for y in ys
            i = y + 1      # buffer index of row y
            j = y + sy + 1 # buffer index of the row a y-step leads to
            seed = seed_values[y, x]

            ax = _candidate(prev_x_values[i] * decay, prev_x_offsets[i], x_step)
            dx = _candidate(prev_x_values[j] * diagonal_decay, prev_x_offsets[j], diagonal_step)
            cur_x_values[i], cur_x_offsets[i] = _propagated(seed, ax, dx)
            vx, ox = kx_axis ? ax : dx

            ay = _candidate(cur_y_values[j] * decay, cur_y_offsets[j], y_step)
            dy = _candidate(prev_y_values[j] * diagonal_decay, prev_y_offsets[j], diagonal_step)
            cur_y_values[i], cur_y_offsets[i] = _propagated(seed, ay, dy)
            vy, oy = ky_axis ? ay : dy

            out[y, x] = _set_octants(out[y, x], kx, ox, Float32(vx), ky, oy, Float32(vy))
        end
        prev_x_values, cur_x_values = cur_x_values, prev_x_values
        prev_x_offsets, cur_x_offsets = cur_x_offsets, prev_x_offsets
        prev_y_values, cur_y_values = cur_y_values, prev_y_values
        prev_y_offsets, cur_y_offsets = cur_y_offsets, prev_y_offsets
    end
end

# _candidate returns the value v propagated to the current cell via a step
# s from a step neighbour, with its source offset relative to the current
# cell, i.e. the neighbour's offset o plus the step. Returns value 0 and
# offset (0, 0) if v is not positive, i.e. if there is no source.
@inline function _candidate(v::Float64, o::NTuple{2,Int16}, s::NTuple{2,Int16})
    return v > 0 ? (v, (o[1] + s[1], o[2] + s[2])) : (0.0, (Int16(0), Int16(0)))
end

# _propagated returns the closed value V of the current cell, and its source
# offset: the max over the cell's own seed (offset (0, 0)) and the axis and
# diagonal step candidates a and d. On ties, the seed wins over the steps,
# and the axis step over the diagonal step.
@inline function _propagated(
    seed::Float64, a::Tuple{Float64,NTuple{2,Int16}}, d::Tuple{Float64,NTuple{2,Int16}},
)
    best = a[1] >= d[1] ? a : d
    return seed >= best[1] ? (seed, (Int16(0), Int16(0))) : best
end

# _set_octants returns a copy of r with octants k1 and k2 replaced.
@inline function _set_octants(
    r::OctantSources, k1::Int, o1::NTuple{2,Int16}, v1::Float32, k2::Int, o2::NTuple{2,Int16}, v2::Float32,
)
    offsets = ntuple(k -> k == k1 ? o1 : (k == k2 ? o2 : r.offsets[k]), Val(8))
    attraction = ntuple(k -> k == k1 ? v1 : (k == k2 ? v2 : r.attraction[k]), Val(8))
    return OctantSources(offsets, attraction)
end
