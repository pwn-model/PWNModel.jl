const _NO_OFFSET = (Int16(0), Int16(0))

# _in_octant reports whether offset (dx, dy) lies in the half-open octant k
# (see PWNModel.OctantSources).
function _in_octant(k::Int, dx::Int, dy::Int)
    k == 1 && return 0 <= dy < dx
    k == 2 && return 0 < dx <= dy
    k == 3 && return 0 <= -dx < dy
    k == 4 && return 0 < dy <= -dx
    k == 5 && return 0 <= -dy < -dx
    k == 6 && return 0 < -dx <= -dy
    k == 7 && return 0 <= dx < -dy
    k == 8 && return 0 < -dy <= dx
    error("invalid octant $k")
end

# _octant_of returns the half-open octant of offset (dx, dy) from its angle,
# independently of _in_octant.
function _octant_of(dx::Int, dy::Int)
    a = mod(atan(dy, dx), 2π)
    return floor(Int, a / (π / 4)) + 1
end

@testset "half-open octants partition the plane" begin
    for dx in (-6):6, dy in (-6):6
        n = count(k -> _in_octant(k, dx, dy), 1:8)
        if (dx, dy) == (0, 0)
            @test n == 0
        else
            @test n == 1
            # Rays exactly on a multiple of 45° are the only cases where
            # floating-point atan could round across a boundary; check them
            # by construction instead.
            if dx == 0 || dy == 0 || abs(dx) == abs(dy)
                continue
            end
            @test _in_octant(_octant_of(dx, dy), dx, dy)
        end
    end
end

# _octant_attraction is the attraction of a source with the given seed at
# offset (dx, dy), evaluated directly from the chamfer path: max(|dx|, |dy|)
# - min(|dx|, |dy|) axis steps and min(|dx|, |dy|) diagonal steps.
function _octant_attraction(seed::Float64, dx::Int, dy::Int, decay::Float64)
    lo, hi = minmax(abs(dx), abs(dy))
    return seed * decay^(hi - lo) * (decay^sqrt(2.0))^lo
end

function _run_octants(seeds::PWNModel.Grid{Float64}, half_distance::Float64)
    sources = PWNModel.Grid(seeds.width, seeds.height, seeds.cell_size, PWNModel.OctantSources())
    buf = PWNModel.OctantBuffers(seeds.height)
    PWNModel.propagate_octants!(sources, seeds, half_distance, buf)
    return sources
end

@testset "OctantSources is one cache line" begin
    @test sizeof(PWNModel.OctantSources) == 64
    @test isbitstype(PWNModel.OctantSources)
end

@testset "propagate_octants! single tree" begin
    seeds = PWNModel.Grid(30, 20, 10, 0.0)
    seeds[15, 10] = 1.0
    half_distance = 50.0
    sources = _run_octants(seeds, half_distance)
    decay = exp(-10.0 * log(2) / half_distance)

    # The tree's own cell has no source in any octant.
    r = sources[15, 10]
    @test all(==(_NO_OFFSET), r.offsets)
    @test all(==(0.0f0), r.attraction)

    # West of the tree, it lies on the +x axis, which belongs to octant 1
    # only; all other octants are empty.
    r = sources[5, 10]
    for k in 1:8
        if k == 1
            @test r.offsets[k] == (Int16(10), Int16(0))
            @test r.attraction[k] == Float32(decay^10)
        else
            @test r.offsets[k] == _NO_OFFSET
            @test r.attraction[k] == 0.0f0
        end
    end

    # At offset (3, 7) from the cell, the tree lies strictly inside octant 2.
    r = sources[12, 3]
    for k in 1:8
        if k == 2
            @test r.offsets[k] == (Int16(3), Int16(7))
            @test r.attraction[k] ≈ Float32(_octant_attraction(1.0, 3, 7, decay))
        else
            @test r.offsets[k] == _NO_OFFSET
        end
    end
end

@testset "propagate_octants! boundary rays belong to the octant they start" begin
    # The ray at 45°*(k-1) belongs to octant k only.
    directions = ((1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1))
    for (k, (ux, uy)) in enumerate(directions)
        seeds = PWNModel.Grid(30, 20, 10, 0.0)
        seeds[15+3*ux, 10+3*uy] = 1.0
        r = _run_octants(seeds, 50.0)[15, 10]
        for kk in 1:8
            if kk == k
                @test r.offsets[kk] == (Int16(3 * ux), Int16(3 * uy))
                @test r.attraction[kk] > 0
            else
                @test r.offsets[kk] == _NO_OFFSET
                @test r.attraction[kk] == 0.0f0
            end
        end
    end
end

@testset "propagate_octants! farther stronger source is not shadowed" begin
    # A weak tree right in front of a strong one, on the same ray: the
    # strong tree must win where it is more attractive, although every path
    # from it passes the weak tree.
    seeds = PWNModel.Grid(60, 5, 10, 0.0)
    seeds[20, 3] = 0.1
    seeds[30, 3] = 1.0
    half_distance = 100.0 # factor 2 per 10 cells
    sources = _run_octants(seeds, half_distance)

    # From x=10, the weak tree is 10 cells away (0.1 / 2), the strong one
    # 20 cells (1.0 / 4).
    r = sources[10, 3]
    @test r.offsets[1] == (Int16(20), Int16(0))
    # Right next to the weak tree, it wins (0.1 * 0.93 vs. 1.0 / 2.1).
    r = sources[19, 3]
    @test r.offsets[1] == (Int16(11), Int16(0))
    # From the weak tree's own cell, the strong tree is the source.
    r = sources[20, 3]
    @test r.offsets[1] == (Int16(10), Int16(0))
end

@testset "propagate_octants! matches brute force" begin
    rng = Xoshiro(42)
    for (w, h) in ((23, 17), (1, 9), (9, 1), (16, 16))
        seeds = PWNModel.Grid(w, h, 10, 0.0)
        trees = Tuple{Int,Int}[]
        for x in 1:w, y in 1:h
            if rand(rng) < 0.08 || (x, y) in ((1, 1), (w, h), (1, h), (w, 1))
                seeds[x, y] = 0.05 + 0.95 * rand(rng)
                push!(trees, (x, y))
            end
        end
        half_distance = 40.0
        decay = exp(-10.0 * log(2) / half_distance)
        sources = _run_octants(seeds, half_distance)

        for x in 1:w, y in 1:h, k in 1:8
            best = 0.0
            for (tx, ty) in trees
                dx, dy = tx - x, ty - y
                _in_octant(k, dx, dy) || continue
                best = max(best, _octant_attraction(seeds[tx, ty], dx, dy, decay))
            end

            r = sources[x, y]
            ox, oy = Int(r.offsets[k][1]), Int(r.offsets[k][2])
            if best == 0.0
                @test (ox, oy) == (0, 0)
                @test r.attraction[k] == 0.0f0
            else
                # The source is a tree in the octant, and as attractive as
                # the best one (up to rounding of the different evaluation
                # order; random seeds make exact ties practically impossible).
                @test _in_octant(k, ox, oy)
                @test seeds[x+ox, y+oy] > 0
                @test _octant_attraction(seeds[x+ox, y+oy], ox, oy, decay) ≈ best rtol = 1e-12
                @test r.attraction[k] ≈ Float32(best) rtol = 1e-6
            end
        end
    end
end
