# propagate_attraction! turns the seeded values of grid into a smooth
# attraction field by propagating each source's value outward, multiplying
# by decay per orthogonal step and decay^sqrt(2) per diagonal step, and
# keeping the best (max) value reaching each cell from any source. decay is
# derived from half_distance (in meters) and the grid's own cell size, as
# decay = exp(-cell_size*log(2) / half_distance), so the field decays to half
# its source value at half_distance meters regardless of grid resolution.
# Mirrors the sibling Go implementation's `sys.propagateAttraction`.
#
# This is an in-place, single-grid Gauss-Seidel relaxation (a discrete
# fast-sweeping method): two passes in opposite raster directions suffice,
# because the grid has no obstacles, so any shortest path from a source can
# be split into one forward-monotone and one backward-monotone segment, each
# fully resolved by one of the two passes.
function propagate_attraction!(grid::Grid{Float64}, half_distance::Float64)
    w, h = grid.width, grid.height
    decay = exp(-grid.cell_size * log(2) / half_distance)

    # Offsets of the already-updated neighbours seen by a sweep moving in
    # increasing (forward) resp. decreasing (backward) x/y, paired with
    # their step decay factor.
    forward = ((-1, -1), (-1, 0), (-1, 1), (0, -1))
    backward = ((1, 1), (1, 0), (1, -1), (0, 1))
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
